# ============================================================================
#  Linux Fundamentals — teaching devcontainer
#  Base: Ubuntu 24.04 LTS (the official image is already minimal; there is no
#  ubuntu:slim tag — "slim" is a Debian thing. 24.04 keeps it small + familiar.)
# ============================================================================
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=student
ARG USER_UID=1000
ARG USER_GID=1000

# Make sure universe + multiverse are on (multiverse is needed for unrar).
# The official image uses the deb822 ubuntu.sources file.
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
    neovim vim \
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
    # --- additions for a fundamentals class (see notes in chat) ---
    man-db manpages \
    less nano \
    tree tmux \
    zip unzip \
    file lsof \
    procps psmisc \
    iproute2 net-tools dnsutils traceroute mtr-tiny netcat-openbsd \
    ripgrep fd-find \
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
#  starship prompt — not in apt, use the official installer
# ----------------------------------------------------------------------------
RUN curl -fsSL https://starship.rs/install.sh | sh -s -- -y

# ----------------------------------------------------------------------------
#  Non-root user. The 24.04 image ships a default 'ubuntu' user at UID 1000,
#  so remove it before claiming 1000 for our 'student' user.
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
WORKDIR /home/$USERNAME

CMD ["zsh"]