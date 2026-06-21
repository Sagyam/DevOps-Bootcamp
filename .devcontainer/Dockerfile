# ============================================================================
#  Linux Fundamentals — teaching devcontainer
#  Base: Ubuntu 24.04 LTS
#
#  CHANGE LOG (Omarchy Neovim support):
#   * Omarchy's "Neovim" is LazyVim (a Neovim distribution) themed Tokyo Night.
#   * Ubuntu's apt neovim is 0.9.5 — LazyVim now requires Neovim >= 0.11.2, so
#     we DROP apt's neovim and install the official stable tarball instead.
#   * Added the deps LazyVim needs: a C toolchain (treesitter), Node/npm
#     (Mason LSP servers + tree-sitter CLI), lazygit, and tree-sitter-cli.
#   * Install the LazyVim starter for the student user + Omarchy's defaults,
#     then pre-sync all plugins at build so every container is identical.
# ============================================================================
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=student
ARG USER_UID=1000
ARG USER_GID=1000
# Pin Neovim if you want byte-for-byte reproducibility (e.g. v0.11.4).
# "stable" always tracks the latest stable release.
ARG NVIM_VERSION=stable

# Make sure universe + multiverse are on (multiverse is needed for unrar).
RUN sed -i 's/^Components: .*/Components: main restricted universe multiverse/' \
    /etc/apt/sources.list.d/ubuntu.sources

# ----------------------------------------------------------------------------
#  Everything available straight from apt (one layer)
# ----------------------------------------------------------------------------
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    # --- shell + the comfort layer ---
    zsh \
    zsh-autosuggestions \
    zsh-syntax-highlighting \
    # --- core CLI you asked for ---
    git \
    btop \
    gzip unrar \
    vim \
    # (neovim REMOVED from apt — it's 0.9.5 here, too old for LazyVim.
    #  We install Neovim >= 0.11.2 from the official tarball further down.)
    curl wget \
    iputils-ping \
    ufw \
    grep sed gawk coreutils \
    jq \
    # --- creature comforts (apt-provided) ---
    bat \
    eza \
    duf \
    zoxide \
    fzf \
    tealdeer \
    git-delta \
    # --- additions for a fundamentals class ---
    man-db manpages \
    less nano \
    tree tmux \
    zip unzip tar \
    file lsof \
    procps psmisc \
    iproute2 net-tools dnsutils traceroute mtr-tiny netcat-openbsd \
    ripgrep fd-find \
    # --- LazyVim build/runtime deps (NEW) ---
    #   build-essential -> gcc/g++/make, required to compile treesitter parsers
    #   nodejs + npm    -> Mason LSP servers (bash/yaml/json/...) + tree-sitter CLI
    build-essential \
    nodejs npm \
    # --- needed to add the gh repo + locale for unicode glyphs ---
    ca-certificates gnupg sudo locales \
    && rm -rf /var/lib/apt/lists/*

# UTF-8 locale so eza icons / starship glyphs render correctly
RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ----------------------------------------------------------------------------
#  GitHub CLI (gh) — official apt repo
# ----------------------------------------------------------------------------
RUN install -m 0755 -d /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------------------------------------------------------
#  yq — the Go (mikefarah) build, NOT apt's python yq. jq-like syntax.
# ----------------------------------------------------------------------------
RUN ARCH="$(dpkg --print-architecture)" \
    && wget -qO /usr/local/bin/yq \
    "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" \
    && chmod +x /usr/local/bin/yq

# ----------------------------------------------------------------------------
#  Neovim >= 0.11.2 — official stable tarball (apt's 0.9.5 is too old for LazyVim)
# ----------------------------------------------------------------------------
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
    x86_64)  NVIM_PKG=nvim-linux-x86_64 ;; \
    aarch64) NVIM_PKG=nvim-linux-arm64  ;; \
    *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/nvim.tar.gz \
    "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${NVIM_PKG}.tar.gz"; \
    tar -C /opt -xzf /tmp/nvim.tar.gz; \
    ln -sf "/opt/${NVIM_PKG}/bin/nvim" /usr/local/bin/nvim; \
    rm /tmp/nvim.tar.gz; \
    nvim --version | head -1

# ----------------------------------------------------------------------------
#  lazygit — LazyVim's <leader>gg git UI (not in Ubuntu apt). From GitHub release.
# ----------------------------------------------------------------------------
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
    x86_64)  LG_ARCH=Linux_x86_64 ;; \
    aarch64) LG_ARCH=Linux_arm64  ;; \
    *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;; \
    esac; \
    LG_VER="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
    | grep -Po '"tag_name":\s*"v\K[^"]*')"; \
    curl -fsSL -o /tmp/lazygit.tar.gz \
    "https://github.com/jesseduffield/lazygit/releases/download/v${LG_VER}/lazygit_${LG_VER}_${LG_ARCH}.tar.gz"; \
    tar -C /usr/local/bin -xzf /tmp/lazygit.tar.gz lazygit; \
    rm /tmp/lazygit.tar.gz; \
    lazygit --version

# tree-sitter CLI — LazyVim's treesitter (main branch) uses it to build parsers.
# Ubuntu's global npm prefix is /usr/local, so the binary lands on PATH.
RUN npm install -g tree-sitter-cli && tree-sitter --version

# ----------------------------------------------------------------------------
#  starship prompt — not in apt, use the official installer
# ----------------------------------------------------------------------------
RUN curl -fsSL https://starship.rs/install.sh | sh -s -- -y

# ----------------------------------------------------------------------------
#  Non-root user.
# ----------------------------------------------------------------------------
RUN if id -u ubuntu >/dev/null 2>&1; then userdel -r ubuntu 2>/dev/null || true; fi \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /usr/bin/zsh $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Drop in the shell config (kept as readable files so students can inspect them)
COPY --chown=$USERNAME:$USERNAME .zshrc /home/$USERNAME/.zshrc
COPY --chown=$USERNAME:$USERNAME starship.toml /home/$USERNAME/.config/starship.toml

USER $USERNAME
ENV SHELL=/usr/bin/zsh
# Make Neovim the default editor, like Omarchy
ENV EDITOR=nvim VISUAL=nvim
WORKDIR /home/$USERNAME

# ----------------------------------------------------------------------------
#  Omarchy-style Neovim = LazyVim. Install the LazyVim starter, overlay
#  Omarchy's defaults (Tokyo Night + no news popup + Nerd Font), and pre-sync
#  every plugin at build time so all containers are byte-for-byte identical
#  and open instantly with no first-run downloads.
# ----------------------------------------------------------------------------
RUN git clone --depth 1 https://github.com/LazyVim/starter /home/$USERNAME/.config/nvim \
    && rm -rf /home/$USERNAME/.config/nvim/.git

COPY --chown=$USERNAME:$USERNAME nvim/lua/plugins/theme.lua              /home/$USERNAME/.config/nvim/lua/plugins/theme.lua
COPY --chown=$USERNAME:$USERNAME nvim/lua/plugins/disable-news-alert.lua /home/$USERNAME/.config/nvim/lua/plugins/disable-news-alert.lua
COPY --chown=$USERNAME:$USERNAME nvim/lua/config/options.lua             /home/$USERNAME/.config/nvim/lua/config/options.lua

# Install + lock all plugins. The generated lazy-lock.json is baked into the
# image, so every student gets the exact same plugin versions.
RUN nvim --headless "+Lazy! sync" +qa

# Add Omarchy's `n` alias (n = nvim, opens the current dir / a file).
RUN printf '\n# Omarchy-style Neovim\nalias n="nvim"\n' >> /home/$USERNAME/.zshrc

# OPTIONAL — fully offline classroom: uncomment to bake treesitter parsers and
# the common LSP servers into the image (needs network AT BUILD time). Without
# this, parsers/servers install on first use (a quick one-time download).
# RUN nvim --headless \
#       -c "lua require('nvim-treesitter').install({'bash','lua','vim','vimdoc','markdown','markdown_inline','json','yaml','regex','query'})" \
#       -c "qa" || true
# RUN nvim --headless \
#       -c "MasonInstall lua-language-server bash-language-server yaml-language-server json-lsp" \
#       -c "qa" || true

CMD ["zsh"]