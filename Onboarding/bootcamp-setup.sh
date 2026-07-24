#!/usr/bin/env bash
#
# DevOps Bootcamp — Student Workstation Setup
# ------------------------------------------------------------------
# Installs the full bootcamp toolchain on Debian/Ubuntu, Fedora/RHEL/
# Rocky/Alma, Arch/Manjaro and openSUSE. Safe to re-run: anything that
# is already installed is skipped unless you pass --force.
#
#   ./bootcamp-setup.sh                  # install everything
#   ./bootcamp-setup.sh --list           # show tool names
#   ./bootcamp-setup.sh --only docker,k9s
#   ./bootcamp-setup.sh --skip vscode,ghostty
#   ./bootcamp-setup.sh --force git      # reinstall/upgrade one tool
#
# Run as your normal user (NOT as root) — it calls sudo when needed so
# that the docker group and per-user config land on the right account.
# ------------------------------------------------------------------

set -Eeuo pipefail

readonly SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/bootcamp-setup-$(date +%Y%m%d-%H%M%S).log"
readonly LOG_FILE

# Tool order matters: core deps first, docker before minikube, etc.
readonly ALL_TOOLS=(
  core git make python node go btop jq yq httpie bat eza dnsutils
  nvim lazyvim docker kubectl minikube k9s lazydocker lazygit
  ansible terraform awscli gh nerdfonts vscode ghostty aliases
)

# Pointless on a headless lab VM — auto-skipped unless --gui or --only.
readonly GUI_TOOLS=(vscode ghostty nerdfonts)

# ------------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_BLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''; C_DIM=''; C_BLD=''; C_OFF=''
fi

log()   { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
info()  { log "${C_BLU}::${C_OFF} $*"; }
ok()    { log "${C_GRN}✓${C_OFF}  $*"; }
warn()  { log "${C_YEL}!${C_OFF}  $*"; }
err()   { log "${C_RED}✗${C_OFF}  $*"; }
step()  { log ""; log "${C_BLD}${C_BLU}━━━ $* ━━━${C_OFF}"; }
die()   { err "$*"; log "Log file: $LOG_FILE"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# Run a command, streaming output to the log but keeping the terminal quiet.
quiet() {
  if ! "$@" >>"$LOG_FILE" 2>&1; then
    err "command failed: $*  (see $LOG_FILE)"
    return 1
  fi
}

trap 'err "Unexpected error on line $LINENO. See $LOG_FILE"' ERR

# ------------------------------------------------------------------
# Environment detection
# ------------------------------------------------------------------
detect_user() {
  if [[ ${EUID} -eq 0 ]]; then
    TARGET_USER="${SUDO_USER:-root}"
    SUDO=""
    if [[ "$TARGET_USER" == "root" ]]; then
      warn "Running as root with no SUDO_USER — user-level config will apply to root."
    fi
  else
    TARGET_USER="${USER:-$(id -un)}"
    have sudo || die "sudo is required. Install it, or re-run this script as root."
    SUDO="sudo"
  fi
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  : "${TARGET_HOME:=$HOME}"
}

detect_os() {
  [[ -r /etc/os-release ]] || die "/etc/os-release not found — unsupported system."
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_LIKE="${ID_LIKE:-}"
  OS_NAME="${PRETTY_NAME:-$OS_ID}"
  OS_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  # shellcheck disable=SC2034  # kept for per-release tweaks students may add
  OS_VERSION_ID="${VERSION_ID:-}"

  case " ${OS_ID} ${OS_LIKE} " in
    *" ubuntu "*|*" debian "*)                 FAMILY="debian" ;;
    *" fedora "*|*" rhel "*|*" centos "*)      FAMILY="rhel"   ;;
    *" arch "*|*" archlinux "*)                FAMILY="arch"   ;;
    *" suse "*|*" opensuse "*|*" sles "*)      FAMILY="suse"   ;;
    *) die "Unsupported distribution: ${OS_NAME}. Supported: Debian/Ubuntu, Fedora/RHEL, Arch, openSUSE." ;;
  esac

  case "$FAMILY" in
    debian) PM="apt" ;;
    rhel)   PM="$(have dnf && echo dnf || echo yum)" ;;
    arch)   PM="pacman" ;;
    suse)   PM="zypper" ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64)  ARCH="amd64"; ARCH_ALT="x86_64"  ;;
    aarch64|arm64) ARCH="arm64"; ARCH_ALT="aarch64" ;;
    *) die "Unsupported CPU architecture: $(uname -m). This script handles x86_64 and aarch64." ;;
  esac

  IS_WSL="no"
  if grep -qi microsoft /proc/version 2>/dev/null; then IS_WSL="yes"; fi

  HAS_SYSTEMD="no"
  if [[ -d /run/systemd/system ]]; then HAS_SYSTEMD="yes"; fi

  HAS_GUI="no"
  if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] \
     || [[ -d /usr/share/xsessions ]] || [[ -d /usr/share/wayland-sessions ]]; then
    HAS_GUI="yes"
  fi
}

# ------------------------------------------------------------------
# Package manager abstraction
# ------------------------------------------------------------------
PKG_REFRESHED="no"

pkg_refresh() {
  if [[ "$PKG_REFRESHED" == "yes" ]]; then return 0; fi
  info "Refreshing package metadata (${PM})…"
  local rc=0
  case "$PM" in
    apt)    quiet env DEBIAN_FRONTEND=noninteractive $SUDO apt-get update -y || rc=1 ;;
    dnf)    quiet $SUDO dnf makecache -y    || rc=1 ;;
    yum)    quiet $SUDO yum makecache -y    || rc=1 ;;
    pacman) quiet $SUDO pacman -Sy --noconfirm || rc=1 ;;
    zypper) quiet $SUDO zypper --non-interactive refresh || rc=1 ;;
  esac
  # A partial failure (one unreachable repo) shouldn't block the whole run,
  # and shouldn't cause a retry before every single package either.
  [[ $rc -eq 0 ]] || warn "metadata refresh reported errors — continuing anyway"
  PKG_REFRESHED="yes"
  return 0
}

# Force a metadata refresh after adding a third-party repo.
pkg_invalidate() { PKG_REFRESHED="no"; }

pkg_install() {
  if [[ $# -eq 0 ]]; then return 0; fi
  pkg_refresh
  case "$PM" in
    apt)    quiet env DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y --no-install-recommends "$@" ;;
    dnf)    quiet $SUDO dnf install -y "$@" ;;
    yum)    quiet $SUDO yum install -y "$@" ;;
    pacman) quiet $SUDO pacman -S --needed --noconfirm "$@" ;;
    zypper) quiet $SUDO zypper --non-interactive install --auto-agree-with-licenses "$@" ;;
  esac
}

# Install packages one at a time; a missing package warns instead of aborting.
pkg_install_soft() {
  local p
  for p in "$@"; do
    pkg_install "$p" || warn "package '$p' not available on ${OS_NAME} — skipping"
  done
}

pkg_exists() {
  case "$PM" in
    apt)    apt-cache show "$1" >/dev/null 2>&1 ;;
    dnf)    dnf info "$1" >/dev/null 2>&1 ;;
    yum)    yum info "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
    zypper) zypper --non-interactive info "$1" 2>/dev/null | grep -q '^Version' ;;
  esac
}

# ------------------------------------------------------------------
# Download helpers
# ------------------------------------------------------------------
TMP_DIR=""
SUDO_KEEPALIVE_PID=""

cleanup() {
  [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  [[ -n "$TMP_DIR" ]] && rm -rf "$TMP_DIR" || true
  return 0
}
trap cleanup EXIT

tmpdir() {
  [[ -n "$TMP_DIR" ]] || TMP_DIR="$(mktemp -d)"
  printf '%s' "$TMP_DIR"
}

fetch() { curl -fsSL --retry 3 --retry-delay 2 "$1" -o "$2"; }

# Latest release tag for a GitHub repo, e.g. "v0.32.7".
# Falls back to the /releases/latest redirect, which has no API rate limit —
# important when a whole classroom shares one public IP.
gh_latest_tag() {
  local repo="$1" tag=""
  tag="$(curl -fsSL --retry 2 "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1 || true)"
  if [[ -z "$tag" ]]; then
    tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
            "https://github.com/${repo}/releases/latest" 2>/dev/null | sed 's#.*/tag/##' || true)"
  fi
  [[ -n "$tag" && "$tag" != *"github.com"* ]] || { err "could not resolve latest release for ${repo}"; return 1; }
  printf '%s' "$tag"
}

install_bin() {   # install_bin <src-file> <name>
  $SUDO install -m 0755 "$1" "/usr/local/bin/$2"
}

# Run a command as the student's account, whatever context we're in:
# normal user -> run directly; root/sudo -> drop privileges to TARGET_USER.
as_user() {
  if [[ "$(id -un)" == "$TARGET_USER" ]]; then
    bash -lc "$*"
  elif have sudo; then
    sudo -u "$TARGET_USER" -H bash -lc "$*"
  else
    su -l "$TARGET_USER" -c "$*"
  fi
}

# ------------------------------------------------------------------
# Installers
# ------------------------------------------------------------------

install_core() {
  local want=()
  have curl  || want+=(curl)
  have tar   || want+=(tar)
  have unzip || want+=(unzip)
  have gpg   || case "$FAMILY" in
                  debian|arch) want+=(gnupg) ;;
                  rhel|suse)   want+=(gnupg2) ;;
                esac
  case "$FAMILY" in
    debian) want+=(ca-certificates apt-transport-https) ;;
    rhel)   want+=(ca-certificates) ;;
    suse)   want+=(ca-certificates) ;;
    arch)   want+=(ca-certificates base-devel) ;;
  esac
  pkg_install_soft "${want[@]}"
  have curl || die "curl is required and could not be installed."
  ok "Base utilities ready"
}

install_git() {
  if have git && [[ "$FORCE_ALL" != "yes" ]]; then
    ok "git already present ($(git --version | awk '{print $3}'))"; return 0
  fi
  pkg_install git
  ok "git $(git --version | awk '{print $3}')"
}

install_python() {
  local pkgs=()
  case "$FAMILY" in
    debian) pkgs=(python3 python3-pip python3-venv python3-dev pipx) ;;
    rhel)   pkgs=(python3 python3-pip python3-devel pipx) ;;
    arch)   pkgs=(python python-pip python-pipx) ;;
    suse)   pkgs=(python3 python3-pip python3-devel python3-pipx) ;;
  esac
  pkg_install_soft "${pkgs[@]}"

  if ! have pipx; then
    warn "pipx not in repos — installing via pip --user"
    as_user "python3 -m pip install --user --break-system-packages pipx" 2>/dev/null \
      || as_user "python3 -m pip install --user pipx" || true
  fi
  have pipx && as_user "pipx ensurepath >/dev/null 2>&1" || true
  ok "Python $(python3 --version 2>&1 | awk '{print $2}')"
}

install_node() {
  if have node && [[ "$FORCE_ALL" != "yes" ]]; then
    ok "node already present ($(node --version))"; return 0
  fi
  case "$FAMILY" in
    debian)
      info "Adding NodeSource LTS repository…"
      quiet bash -c "curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO -E bash -" \
        || warn "NodeSource setup failed — falling back to distro packages"
      pkg_invalidate
      pkg_install nodejs || pkg_install_soft nodejs npm
      ;;
    rhel)
      quiet bash -c "curl -fsSL https://rpm.nodesource.com/setup_lts.x | $SUDO -E bash -" \
        || warn "NodeSource setup failed — falling back to distro packages"
      pkg_invalidate
      pkg_install nodejs || pkg_install_soft nodejs npm
      ;;
    arch) pkg_install nodejs npm ;;
    suse) pkg_install_soft nodejs22 npm22 || pkg_install_soft nodejs npm ;;
  esac
  have node || return 1
  ok "node $(node --version) / npm $(npm --version 2>/dev/null || echo n/a)"
}

install_go() {
  if have go && [[ "$FORCE_ALL" != "yes" ]]; then
    ok "go already present ($(go version | awk '{print $3}'))"; return 0
  fi
  local ver tmp
  tmp="$(tmpdir)"
  ver="$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)"
  [[ -n "$ver" ]] || { warn "Could not reach go.dev — using distro package"; pkg_install go || pkg_install golang; return 0; }

  info "Installing ${ver} to /usr/local/go…"
  fetch "https://go.dev/dl/${ver}.linux-${ARCH}.tar.gz" "$tmp/go.tgz"
  $SUDO rm -rf /usr/local/go
  quiet $SUDO tar -C /usr/local -xzf "$tmp/go.tgz"

  printf 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin\n' \
    | $SUDO tee /etc/profile.d/go.sh >/dev/null
  $SUDO chmod 0644 /etc/profile.d/go.sh
  export PATH="$PATH:/usr/local/go/bin"
  ok "$(go version)"
}

install_btop() {
  if have btop && [[ "$FORCE_ALL" != "yes" ]]; then ok "btop already present"; return 0; fi
  if pkg_exists btop; then
    pkg_install btop
  else
    warn "btop not in repos — installing static binary from GitHub"
    local tmp tag; tmp="$(tmpdir)"; tag="$(gh_latest_tag aristocratos/btop)"
    fetch "https://github.com/aristocratos/btop/releases/download/${tag}/btop-${ARCH_ALT}-unknown-linux-musl.tar.gz" "$tmp/btop.tar.gz"
    quiet tar -xzf "$tmp/btop.tar.gz" -C "$tmp"
    install_bin "$tmp/btop/bin/btop" btop
  fi
  ok "btop $(btop --version 2>/dev/null | head -n1 || echo installed)"
}

install_docker() {
  if have docker && [[ "$FORCE_ALL" != "yes" ]]; then
    ok "docker already present ($(docker --version | awk '{print $3}' | tr -d ,))"
  else
    step_docker_packages
  fi
  post_docker
}

step_docker_packages() {
  case "$FAMILY" in
    debian)
      local repo_distro="debian"
      case " ${OS_ID} ${OS_LIKE} " in *" ubuntu "*) repo_distro="ubuntu" ;; esac
      [[ -n "$OS_CODENAME" ]] || die "Could not determine release codename for Docker repo."
      info "Adding Docker apt repository (${repo_distro}/${OS_CODENAME})…"
      $SUDO install -m 0755 -d /etc/apt/keyrings
      quiet bash -c "curl -fsSL https://download.docker.com/linux/${repo_distro}/gpg | $SUDO gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg"
      $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${repo_distro} ${OS_CODENAME} stable" \
        | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
      pkg_invalidate
      pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
        || docker_fallback
      ;;
    rhel)
      local repo_path="centos"
      case " ${OS_ID} ${OS_LIKE} " in *" fedora "*) repo_path="fedora" ;; esac
      info "Adding Docker ${repo_path} repository…"
      quiet $SUDO curl -fsSL "https://download.docker.com/linux/${repo_path}/docker-ce.repo" -o /etc/yum.repos.d/docker-ce.repo
      pkg_invalidate
      pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
        || docker_fallback
      ;;
    arch)
      pkg_install docker docker-buildx docker-compose
      ;;
    suse)
      pkg_install_soft docker docker-compose docker-buildx
      ;;
  esac
}

docker_fallback() {
  warn "Repository install failed — trying Docker's convenience script"
  quiet bash -c "curl -fsSL https://get.docker.com | $SUDO sh"
}

post_docker() {
  have docker || return 1

  if [[ "$HAS_SYSTEMD" == "yes" ]]; then
    quiet $SUDO systemctl enable --now docker || warn "Could not start the docker service"
    quiet $SUDO systemctl enable --now containerd 2>/dev/null || true
  elif [[ "$IS_WSL" == "yes" ]]; then
    warn "WSL without systemd — start the daemon with: sudo service docker start"
    $SUDO service docker start >/dev/null 2>&1 || true
  else
    warn "systemd not detected — start the docker daemon manually."
  fi

  getent group docker >/dev/null || $SUDO groupadd docker
  if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx docker; then
    ok "user '$TARGET_USER' already in the docker group"
  else
    $SUDO usermod -aG docker "$TARGET_USER"
    NEEDS_RELOGIN="yes"
    ok "added '$TARGET_USER' to the docker group"
  fi

  # docker compose v2 shim for distros that only ship the standalone binary
  if ! docker compose version >/dev/null 2>&1 && ! have docker-compose; then
    warn "docker compose plugin missing — installing it manually"
    local tag plugin_dir; tag="$(gh_latest_tag docker/compose)"
    plugin_dir="/usr/local/lib/docker/cli-plugins"
    $SUDO mkdir -p "$plugin_dir"
    $SUDO curl -fsSL "https://github.com/docker/compose/releases/download/${tag}/docker-compose-linux-${ARCH_ALT}" \
      -o "$plugin_dir/docker-compose"
    $SUDO chmod +x "$plugin_dir/docker-compose"
  fi
  ok "docker $(docker --version | awk '{print $3}' | tr -d ,), compose $(docker compose version --short 2>/dev/null || echo n/a)"
}

install_kubectl() {
  if have kubectl && [[ "$FORCE_ALL" != "yes" ]]; then ok "kubectl already present"; return 0; fi
  local tmp ver; tmp="$(tmpdir)"
  ver="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  fetch "https://dl.k8s.io/release/${ver}/bin/linux/${ARCH}/kubectl" "$tmp/kubectl"
  install_bin "$tmp/kubectl" kubectl
  # shell completion for bash + zsh
  kubectl completion bash | $SUDO tee /etc/bash_completion.d/kubectl >/dev/null 2>&1 || true
  ok "kubectl ${ver}"
}

install_minikube() {
  if have minikube && [[ "$FORCE_ALL" != "yes" ]]; then ok "minikube already present"; return 0; fi
  local tmp; tmp="$(tmpdir)"
  fetch "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${ARCH}" "$tmp/minikube"
  install_bin "$tmp/minikube" minikube
  as_user "minikube config set driver docker >/dev/null 2>&1" || true
  ok "minikube $(minikube version --short 2>/dev/null || echo installed)"
}

install_k9s() {
  if have k9s && [[ "$FORCE_ALL" != "yes" ]]; then ok "k9s already present"; return 0; fi
  local tmp tag; tmp="$(tmpdir)"; tag="$(gh_latest_tag derailed/k9s)"
  [[ -n "$tag" ]] || return 1
  fetch "https://github.com/derailed/k9s/releases/download/${tag}/k9s_Linux_${ARCH}.tar.gz" "$tmp/k9s.tgz"
  quiet tar -xzf "$tmp/k9s.tgz" -C "$tmp" k9s
  install_bin "$tmp/k9s" k9s
  ok "k9s ${tag}"
}

install_lazydocker() {
  if have lazydocker && [[ "$FORCE_ALL" != "yes" ]]; then ok "lazydocker already present"; return 0; fi
  local tmp tag ver; tmp="$(tmpdir)"; tag="$(gh_latest_tag jesseduffield/lazydocker)"
  [[ -n "$tag" ]] || return 1
  ver="${tag#v}"
  fetch "https://github.com/jesseduffield/lazydocker/releases/download/${tag}/lazydocker_${ver}_Linux_${ARCH_ALT}.tar.gz" "$tmp/ld.tgz"
  quiet tar -xzf "$tmp/ld.tgz" -C "$tmp" lazydocker
  install_bin "$tmp/lazydocker" lazydocker
  ok "lazydocker ${tag}"
}

install_lazygit() {
  if have lazygit && [[ "$FORCE_ALL" != "yes" ]]; then ok "lazygit already present"; return 0; fi
  local tmp tag ver; tmp="$(tmpdir)"; tag="$(gh_latest_tag jesseduffield/lazygit)"
  [[ -n "$tag" ]] || return 1
  ver="${tag#v}"
  fetch "https://github.com/jesseduffield/lazygit/releases/download/${tag}/lazygit_${ver}_Linux_${ARCH_ALT}.tar.gz" "$tmp/lg.tgz"
  quiet tar -xzf "$tmp/lg.tgz" -C "$tmp" lazygit
  install_bin "$tmp/lazygit" lazygit
  ok "lazygit ${tag}"
}

install_ansible() {
  if have ansible && [[ "$FORCE_ALL" != "yes" ]]; then
    ok "ansible already present ($(ansible --version | head -n1))"; return 0
  fi
  case "$FAMILY" in
    arch|rhel|suse) pkg_install ansible || true ;;
    debian)         pkg_install ansible || true ;;
  esac
  if ! have ansible && have pipx; then
    info "Installing Ansible via pipx (distro package unavailable)…"
    as_user "pipx install --include-deps ansible" || true
  fi
  have ansible || have ansible-playbook || return 1
  ok "$(ansible --version 2>/dev/null | head -n1 || echo 'ansible installed (restart your shell for PATH)')"
}

install_awscli() {
  if have aws && [[ "$FORCE_ALL" != "yes" ]]; then
    ok "aws cli already present ($(aws --version 2>&1 | awk '{print $1}'))"; return 0
  fi
  have unzip || pkg_install unzip
  local tmp; tmp="$(tmpdir)"
  info "Downloading AWS CLI v2 (${ARCH_ALT})…"
  fetch "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH_ALT}.zip" "$tmp/awscliv2.zip"
  quiet unzip -qo "$tmp/awscliv2.zip" -d "$tmp"
  if [[ -x /usr/local/bin/aws ]]; then
    quiet $SUDO "$tmp/aws/install" --update
  else
    quiet $SUDO "$tmp/aws/install"
  fi
  ok "$(aws --version 2>&1)"
}

install_gh() {
  if have gh && [[ "$FORCE_ALL" != "yes" ]]; then ok "gh already present ($(gh --version | head -n1))"; return 0; fi
  case "$FAMILY" in
    debian)
      info "Adding GitHub CLI apt repository…"
      $SUDO install -m 0755 -d /etc/apt/keyrings
      quiet bash -c "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null"
      $SUDO chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      pkg_invalidate
      pkg_install gh || gh_binary_fallback
      ;;
    rhel)  pkg_install gh || gh_binary_fallback ;;
    arch)  pkg_install github-cli ;;
    suse)  pkg_install gh || gh_binary_fallback ;;
  esac
  have gh || return 1
  ok "$(gh --version | head -n1)"
}

gh_binary_fallback() {
  warn "gh package unavailable — installing release binary"
  local tmp tag ver; tmp="$(tmpdir)"; tag="$(gh_latest_tag cli/cli)"; ver="${tag#v}"
  fetch "https://github.com/cli/cli/releases/download/${tag}/gh_${ver}_linux_${ARCH}.tar.gz" "$tmp/gh.tgz"
  quiet tar -xzf "$tmp/gh.tgz" -C "$tmp"
  install_bin "$tmp/gh_${ver}_linux_${ARCH}/bin/gh" gh
}

install_vscode() {
  if have code && [[ "$FORCE_ALL" != "yes" ]]; then ok "VS Code already present"; return 0; fi
  case "$FAMILY" in
    debian)
      info "Adding Microsoft VS Code apt repository…"
      $SUDO install -m 0755 -d /etc/apt/keyrings
      quiet bash -c "curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | $SUDO tee /etc/apt/keyrings/microsoft.gpg >/dev/null"
      $SUDO chmod a+r /etc/apt/keyrings/microsoft.gpg
      echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        | $SUDO tee /etc/apt/sources.list.d/vscode.list >/dev/null
      pkg_invalidate
      pkg_install code
      ;;
    rhel)
      quiet $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc
      printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
        | $SUDO tee /etc/yum.repos.d/vscode.repo >/dev/null
      pkg_invalidate
      pkg_install code
      ;;
    suse)
      quiet $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc
      quiet $SUDO zypper --non-interactive addrepo -f https://packages.microsoft.com/yumrepos/vscode vscode || true
      pkg_invalidate
      pkg_install code
      ;;
    arch)
      # Official Microsoft build lives in the AUR; Code-OSS is in the official repos.
      if have yay; then
        as_user "yay -S --needed --noconfirm visual-studio-code-bin"
      elif have paru; then
        as_user "paru -S --needed --noconfirm visual-studio-code-bin"
      else
        warn "No AUR helper found — installing open-source 'code' (Code-OSS) instead."
        warn "For the Microsoft build: yay -S visual-studio-code-bin"
        pkg_install code
      fi
      ;;
  esac
  have code || return 1
  ok "VS Code $(code --version 2>/dev/null | head -n1 || echo installed)"
}


install_make() {
  case "$FAMILY" in
    debian) pkg_install build-essential ;;
    rhel)   pkg_install_soft make gcc gcc-c++ ;;
    arch)   pkg_install_soft base-devel ;;
    suse)   pkg_install_soft make gcc gcc-c++ ;;
  esac
  have make || return 1
  ok "$(make --version | head -n1)"
}

install_jq() {
  if have jq && [[ "$FORCE_ALL" != "yes" ]]; then ok "jq already present"; return 0; fi
  pkg_install jq
  ok "jq $(jq --version)"
}

install_yq() {
  # mikefarah/yq (Go) — the one that mirrors jq's syntax, not the Python wrapper.
  if have yq && [[ "$FORCE_ALL" != "yes" ]]; then ok "yq already present"; return 0; fi
  local tmp tag; tmp="$(tmpdir)"; tag="$(gh_latest_tag mikefarah/yq)" || return 1
  fetch "https://github.com/mikefarah/yq/releases/download/${tag}/yq_linux_${ARCH}" "$tmp/yq"
  install_bin "$tmp/yq" yq
  ok "yq ${tag}"
}

install_httpie() {
  if have http && [[ "$FORCE_ALL" != "yes" ]]; then ok "httpie already present"; return 0; fi
  pkg_install httpie || true
  if ! have http && have pipx; then
    info "httpie not in repos — installing via pipx"
    as_user "pipx install httpie" || true
  fi
  have http || have httpie || return 1
  ok "httpie installed"
}

install_bat() {
  if have bat && [[ "$FORCE_ALL" != "yes" ]]; then ok "bat already present"; return 0; fi
  pkg_install bat || {
    warn "bat not in repos — installing release binary"
    local tmp tag ver; tmp="$(tmpdir)"; tag="$(gh_latest_tag sharkdp/bat)" || return 1; ver="${tag#v}"
    fetch "https://github.com/sharkdp/bat/releases/download/${tag}/bat-${tag}-${ARCH_ALT}-unknown-linux-gnu.tar.gz" "$tmp/bat.tgz"
    quiet tar -xzf "$tmp/bat.tgz" -C "$tmp"
    install_bin "$tmp/bat-${tag}-${ARCH_ALT}-unknown-linux-gnu/bat" bat
  }
  # Debian/Ubuntu ship the binary as 'batcat' (the name 'bat' is taken by
  # another package). Give students a real 'bat' command, not just an alias.
  if ! have bat && have batcat; then
    $SUDO ln -sf "$(command -v batcat)" /usr/local/bin/bat
    ok "linked batcat -> /usr/local/bin/bat"
  fi
  ok "bat $(bat --version 2>/dev/null | head -n1 || echo installed)"
}

install_eza() {
  if have eza && [[ "$FORCE_ALL" != "yes" ]]; then ok "eza already present"; return 0; fi
  if pkg_exists eza; then
    pkg_install eza
  else
    warn "eza not in repos — installing release binary"
    local tmp tag; tmp="$(tmpdir)"; tag="$(gh_latest_tag eza-community/eza)" || return 1
    fetch "https://github.com/eza-community/eza/releases/download/${tag}/eza_${ARCH_ALT}-unknown-linux-gnu.tar.gz" "$tmp/eza.tgz"
    quiet tar -xzf "$tmp/eza.tgz" -C "$tmp"
    install_bin "$tmp/eza" eza
  fi
  ok "eza $(eza --version 2>/dev/null | sed -n 2p || echo installed)"
}

install_dnsutils() {
  # nslookup, dig, host — the DNS troubleshooting trio.
  if have nslookup && have dig && [[ "$FORCE_ALL" != "yes" ]]; then
    ok "nslookup/dig already present"; return 0
  fi
  case "$FAMILY" in
    debian) pkg_install dnsutils || pkg_install bind9-dnsutils ;;
    rhel)   pkg_install bind-utils ;;
    suse)   pkg_install bind-utils ;;
    arch)   if pkg_exists bind; then pkg_install bind; else pkg_install bind-tools; fi ;;
  esac
  have nslookup || return 1
  ok "nslookup + dig ready"
}

install_nvim() {
  if have nvim && [[ "$FORCE_ALL" != "yes" ]]; then
    ok "neovim already present ($(nvim --version | head -n1))"; return 0
  fi
  # Distro packages lag badly (Ubuntu 24.04 ships 0.9.x) and LazyVim needs a
  # recent build, so take the upstream tarball.
  local tmp tag nvarch dir
  tmp="$(tmpdir)"; tag="$(gh_latest_tag neovim/neovim)" || return 1
  [[ "$ARCH" == "amd64" ]] && nvarch="x86_64" || nvarch="arm64"
  dir="nvim-linux-${nvarch}"
  fetch "https://github.com/neovim/neovim/releases/download/${tag}/${dir}.tar.gz" "$tmp/nvim.tgz"
  quiet tar -xzf "$tmp/nvim.tgz" -C "$tmp"
  $SUDO rm -rf "/opt/${dir}"
  $SUDO mv "$tmp/${dir}" /opt/
  $SUDO ln -sf "/opt/${dir}/bin/nvim" /usr/local/bin/nvim
  ok "neovim ${tag}"
}

install_lazyvim() {
  have nvim || { err "neovim must be installed before LazyVim"; return 1; }
  # LazyVim's own prerequisites — without these, telescope and fuzzy find break.
  pkg_install_soft ripgrep fd-find fzf 2>/dev/null || true
  if [[ "$FAMILY" == "debian" ]] && have fdfind && ! have fd; then
    $SUDO ln -sf "$(command -v fdfind)" /usr/local/bin/fd
  fi

  local cfg="${TARGET_HOME}/.config/nvim"
  if [[ -d "$cfg" && "$FORCE_ALL" != "yes" ]]; then
    ok "nvim config already exists at ${cfg} — leaving it alone"
    return 0
  fi
  if [[ -d "$cfg" ]]; then
    local backup; backup="${cfg}.bak.$(date +%s)"
    warn "backing up existing config to ${backup}"
    as_user "mv '$cfg' '$backup'"
  fi
  info "Cloning the LazyVim starter…"
  as_user "git clone --depth 1 https://github.com/LazyVim/starter '$cfg'"
  as_user "rm -rf '$cfg/.git'"
  ok "LazyVim installed — first 'nvim' launch will bootstrap plugins"
}

install_terraform() {
  if have terraform && [[ "$FORCE_ALL" != "yes" ]]; then
    ok "terraform already present ($(terraform version | head -n1))"; return 0
  fi
  case "$FAMILY" in
    debian)
      info "Adding the HashiCorp apt repository…"
      $SUDO install -m 0755 -d /etc/apt/keyrings
      quiet bash -c "curl -fsSL https://apt.releases.hashicorp.com/gpg | $SUDO gpg --dearmor --yes -o /etc/apt/keyrings/hashicorp.gpg"
      $SUDO chmod a+r /etc/apt/keyrings/hashicorp.gpg
      echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com ${OS_CODENAME} main" \
        | $SUDO tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
      pkg_invalidate
      pkg_install terraform || terraform_binary
      ;;
    rhel)
      local hc="RHEL"; case " ${OS_ID} ${OS_LIKE} " in *" fedora "*) hc="fedora" ;; esac
      quiet $SUDO curl -fsSL "https://rpm.releases.hashicorp.com/${hc}/hashicorp.repo" -o /etc/yum.repos.d/hashicorp.repo
      pkg_invalidate
      pkg_install terraform || terraform_binary
      ;;
    arch) pkg_install terraform || terraform_binary ;;
    suse) terraform_binary ;;
  esac
  have terraform || return 1
  ok "$(terraform version | head -n1)"
}

terraform_binary() {
  warn "Falling back to the Terraform release zip"
  local tmp ver; tmp="$(tmpdir)"
  ver="$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform \
        | sed -n 's/.*"current_version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  [[ -n "$ver" ]] || { err "could not determine the latest Terraform version"; return 1; }
  have unzip || pkg_install unzip
  fetch "https://releases.hashicorp.com/terraform/${ver}/terraform_${ver}_linux_${ARCH}.zip" "$tmp/tf.zip"
  quiet unzip -qo "$tmp/tf.zip" -d "$tmp"
  install_bin "$tmp/terraform" terraform
}

install_nerdfonts() {
  local dest="/usr/local/share/fonts/NerdFonts"
  if [[ -d "$dest" && "$FORCE_ALL" != "yes" ]]; then ok "Nerd Fonts already installed"; return 0; fi
  have unzip || pkg_install unzip
  case "$FAMILY" in
    debian|suse) pkg_install_soft fontconfig ;;
    rhel)        pkg_install_soft fontconfig ;;
    arch)        pkg_install_soft fontconfig ;;
  esac
  local tmp tag f; tmp="$(tmpdir)"; tag="$(gh_latest_tag ryanoasis/nerd-fonts)" || return 1
  $SUDO mkdir -p "$dest"
  for f in JetBrainsMono FiraCode; do
    info "Installing ${f} Nerd Font…"
    fetch "https://github.com/ryanoasis/nerd-fonts/releases/download/${tag}/${f}.zip" "$tmp/${f}.zip" || {
      warn "could not download ${f}"; continue; }
    quiet unzip -qo "$tmp/${f}.zip" -d "$tmp/${f}" -x "*.txt" "*.md"
    $SUDO find "$tmp/${f}" -name '*.ttf' -exec install -m 0644 {} "$dest/" \;
  done
  quiet $SUDO fc-cache -f "$dest" || true
  ok "Nerd Fonts ${tag} (JetBrainsMono, FiraCode)"
}

install_ghostty() {
  if have ghostty && [[ "$FORCE_ALL" != "yes" ]]; then ok "ghostty already present"; return 0; fi
  case "$FAMILY" in
    arch) pkg_install ghostty ;;
    suse) pkg_install ghostty ;;
    rhel)
      if [[ "$OS_ID" == "fedora" ]]; then
        pkg_install ghostty || {
          info "Enabling the pgdev/ghostty COPR…"
          pkg_install_soft dnf-plugins-core
          quiet $SUDO dnf copr enable -y pgdev/ghostty
          pkg_invalidate
          pkg_install ghostty
        }
      else
        warn "No Ghostty build for RHEL derivatives — see https://ghostty.org/download"
        return 1
      fi
      ;;
    debian) ghostty_deb ;;
  esac
  have ghostty || return 1
  ok "ghostty $(ghostty --version 2>/dev/null | head -n1 || echo installed)"
}

ghostty_deb() {
  # Ghostty has no official .deb; this is the community build used by most
  # Ubuntu/Debian users. Assets are named per-release, e.g. _amd64_24.04.deb
  local tag suffix assets file tmp
  tmp="$(tmpdir)"
  tag="$(gh_latest_tag mkasberg/ghostty-ubuntu)" || return 1
  case "$OS_ID" in
    ubuntu|pop|linuxmint|elementary|zorin) suffix="${OS_VERSION_ID}" ;;
    debian)                                suffix="${OS_CODENAME}"   ;;
    *)                                     suffix=""                 ;;
  esac
  assets="$(curl -fsSL "https://github.com/mkasberg/ghostty-ubuntu/releases/expanded_assets/${tag}" \
            | grep -o '[A-Za-z0-9._-]*\.deb' | sort -u)"
  file="$(printf '%s\n' "$assets" | grep "_${ARCH}_" | grep -- "_${suffix}\.deb\$" | head -n1 || true)"
  if [[ -z "$file" ]]; then
    file="$(printf '%s\n' "$assets" | grep "_${ARCH}_" | sort -V | tail -n1 || true)"
    [[ -n "$file" ]] && warn "no exact build for ${OS_ID} ${suffix} — trying ${file}"
  fi
  [[ -n "$file" ]] || { err "no Ghostty .deb for ${ARCH}"; return 1; }
  fetch "https://github.com/mkasberg/ghostty-ubuntu/releases/download/${tag}/${file}" "$tmp/ghostty.deb"
  quiet env DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$tmp/ghostty.deb"
}

install_aliases() {
  # Managed block, rewritten on every run so it stays idempotent.
  local marker_start="# >>> devops-bootcamp aliases >>>"
  local marker_end="# <<< devops-bootcamp aliases <<<"
  local block rc
  block="$(cat <<'ALIASES'
# >>> devops-bootcamp aliases >>>
command -v batcat >/dev/null 2>&1 && alias bat='batcat'
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lahg --git --group-directories-first'
  alias la='eza -a --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
fi
command -v nvim  >/dev/null 2>&1 && alias vim='nvim'
command -v lazygit    >/dev/null 2>&1 && alias lg='lazygit'
command -v lazydocker >/dev/null 2>&1 && alias lzd='lazydocker'
command -v kubectl >/dev/null 2>&1 && alias k='kubectl'
command -v terraform >/dev/null 2>&1 && alias tf='terraform'
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
# <<< devops-bootcamp aliases <<<
ALIASES
)"
  for rc in "${TARGET_HOME}/.bashrc" "${TARGET_HOME}/.zshrc"; do
    [[ -f "$rc" ]] || continue
    if grep -qF "$marker_start" "$rc"; then
      as_user "sed -i '/${marker_start//\//\\/}/,/${marker_end//\//\\/}/d' '$rc'"
    fi
    printf '\n%s\n' "$block" | $SUDO tee -a "$rc" >/dev/null
    $SUDO chown "$TARGET_USER" "$rc"
    ok "aliases written to $(basename "$rc")"
  done
  ok "run 'exec \$SHELL -l' to pick them up"
}

# ------------------------------------------------------------------
# CLI parsing
# ------------------------------------------------------------------
usage() {
  cat <<EOF
${C_BLD}DevOps Bootcamp Workstation Setup${C_OFF} v${SCRIPT_VERSION}

Usage: $(basename "$0") [options]

  --only  a,b,c   Install only these tools
  --skip  a,b,c   Install everything except these
  --force [a,b]   Reinstall/upgrade even if already present (all tools if no list)
  --gui           Install desktop tools (vscode, ghostty, nerdfonts) even when
                  no graphical session is detected
  --list          List available tool names
  -h, --help      Show this help

Examples:
  ./bootcamp-setup.sh --skip ghostty,vscode      # headless lab VM
  ./bootcamp-setup.sh --only docker,kubectl,k9s  # Kubernetes week
  ./bootcamp-setup.sh --force nvim,lazyvim       # rebuild an editor setup

Supported: Debian/Ubuntu (+Mint, Pop!_OS), Fedora/RHEL/Rocky/Alma,
           Arch/Manjaro/CachyOS, openSUSE.  x86_64 and aarch64.
EOF
}

SELECTED=()
SKIP_LIST=()
FORCE_ALL="no"
FORCE_LIST=()
FORCE_GUI="no"
NEEDS_RELOGIN="no"

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --only)  IFS=',' read -r -a SELECTED   <<< "${2:-}"; shift 2 ;;
      --skip)  IFS=',' read -r -a SKIP_LIST  <<< "${2:-}"; shift 2 ;;
      --force)
        if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
          IFS=',' read -r -a FORCE_LIST <<< "$2"; shift 2
        else
          FORCE_ALL="yes"; shift
        fi ;;
      --gui)   FORCE_GUI="yes"; shift ;;
      --list)  printf '%s\n' "${ALL_TOOLS[@]}"; exit 0 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown option: $1  (try --help)" ;;
    esac
  done
}

in_list() {
  local needle="$1"; shift
  local x; for x in "$@"; do if [[ "$x" == "$needle" ]]; then return 0; fi; done
  return 1
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
declare -A STATUS

main() {
  parse_args "$@"
  : >"$LOG_FILE"

  detect_user
  detect_os

  log ""
  log "${C_BLD}DevOps Bootcamp Setup v${SCRIPT_VERSION}${C_OFF}"
  log "${C_DIM}Distro : ${OS_NAME} (family: ${FAMILY}, pm: ${PM})${C_OFF}"
  log "${C_DIM}Arch   : ${ARCH} | User: ${TARGET_USER} | systemd: ${HAS_SYSTEMD} | WSL: ${IS_WSL}${C_OFF}"
  log "${C_DIM}Log    : ${LOG_FILE}${C_OFF}"

  # Cache sudo credentials up front, then keep them warm.
  if [[ -n "$SUDO" ]]; then
    info "Requesting sudo access…"
    sudo -v || die "sudo authentication failed."
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
  fi

  local queue=()
  if [[ ${#SELECTED[@]} -gt 0 ]]; then
    queue=(core)
    local t
    for t in "${ALL_TOOLS[@]}"; do
      [[ "$t" == "core" ]] && continue
      if in_list "$t" "${SELECTED[@]}"; then queue+=("$t"); fi
    done
    for t in "${SELECTED[@]}"; do
      in_list "$t" "${ALL_TOOLS[@]}" || warn "unknown tool name: '$t' (see --list)"
    done
  else
    queue=("${ALL_TOOLS[@]}")
  fi

  local tool
  for tool in "${queue[@]}"; do
    if [[ ${#SKIP_LIST[@]} -gt 0 ]] && in_list "$tool" "${SKIP_LIST[@]}"; then
      STATUS[$tool]="skipped"; continue
    fi
    # Desktop apps on a headless box are just wasted bandwidth. Asking for one
    # by name with --only (or --gui) overrides this.
    if in_list "$tool" "${GUI_TOOLS[@]}" && [[ "$HAS_GUI" == "no" && "$FORCE_GUI" == "no" ]] \
       && { [[ ${#SELECTED[@]} -eq 0 ]] || ! in_list "$tool" "${SELECTED[@]}"; }; then
      STATUS[$tool]="skipped (no GUI — use --gui)"; continue
    fi
    if [[ ${#FORCE_LIST[@]} -gt 0 ]] && in_list "$tool" "${FORCE_LIST[@]}"; then
      FORCE_ALL="yes"
    fi

    step "$tool"
    if "install_${tool}"; then
      STATUS[$tool]="ok"
    else
      STATUS[$tool]="FAILED"
      err "${tool} did not install cleanly — details in ${LOG_FILE}"
    fi

    if [[ ${#FORCE_LIST[@]} -gt 0 ]]; then FORCE_ALL="no"; fi
  done

  summary
}

# Not every tool answers to --version (k9s wants "version", kubectl wants
# "version --client"), so try the common spellings and never fail the run.
probe_version() {
  local c="$1" out=""
  out="$( { "$c" --version 2>/dev/null \
         || "$c" version --client 2>/dev/null \
         || "$c" version --short 2>/dev/null \
         || "$c" version 2>/dev/null \
         || echo "installed"; } | grep -v '^[[:space:]]*$' \
         | { grep -m1 -E '[0-9]+\.[0-9]+' || head -n1; } )" || out="installed"
  printf '%s' "${out:-installed}" | cut -c1-70
}

summary() {
  local failed=0 tool state
  log ""
  log "${C_BLD}━━━ Summary ━━━${C_OFF}"
  for tool in "${queue[@]:-${ALL_TOOLS[@]}}"; do
    state="${STATUS[$tool]:-not run}"
    case "$state" in
      ok)      printf '  %s✓%s %-12s installed\n' "$C_GRN" "$C_OFF" "$tool" | tee -a "$LOG_FILE" ;;
      skipped*) printf '  %s–%s %-12s %s\n' "$C_DIM" "$C_OFF" "$tool" "$state" | tee -a "$LOG_FILE" ;;
      *)       printf '  %s✗%s %-12s %s\n' "$C_RED" "$C_OFF" "$tool" "$state" | tee -a "$LOG_FILE"; failed=1 ;;
    esac
  done

  log ""
  log "${C_BLD}Versions${C_OFF}"
  local c
  for c in git make python3 node go docker kubectl minikube k9s btop \
           lazygit lazydocker ansible terraform aws gh nvim jq yq eza bat \
           http nslookup ghostty code; do
    if have "$c"; then
      printf '  %-11s %s\n' "$c" "$(probe_version "$c")" | tee -a "$LOG_FILE"
    fi
  done

  log ""
  if [[ "$NEEDS_RELOGIN" == "yes" ]]; then
    warn "Log out and back in (or run: newgrp docker) before using docker without sudo."
  fi
  log "${C_DIM}Reload your shell for PATH + aliases:  exec \$SHELL -l${C_OFF}"
  log "${C_DIM}Verify the cluster with:  minikube start && kubectl get nodes${C_OFF}"
  log "${C_DIM}First 'nvim' launch bootstraps LazyVim — let it finish before quitting.${C_OFF}"
  log "${C_DIM}Set your terminal font to 'JetBrainsMono Nerd Font' for icons.${C_OFF}"
  log "${C_DIM}Full log: ${LOG_FILE}${C_OFF}"

  [[ $failed -eq 0 ]] || exit 1
}

main "$@"
