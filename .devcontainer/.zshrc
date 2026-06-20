# =============================================================================
#  .zshrc  —  Linux Fundamentals bootcamp
#  Deliberately kept readable. Open it, change it, break it, fix it.
#  ( run `bat ~/.zshrc` to see it with syntax highlighting )
# =============================================================================

# ---- History -----------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY          # share history across open shells
setopt HIST_IGNORE_ALL_DUPS   # don't store duplicate commands
setopt HIST_REDUCE_BLANKS

# ---- Sensible shell options --------------------------------------------------
setopt AUTO_CD                # type a dir name to cd into it
setopt INTERACTIVE_COMMENTS   # allow # comments at the prompt
setopt NO_BEEP

# ---- Completion --------------------------------------------------------------
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case-insensitive

# ---- Autosuggestions (type, then press → to accept the grey hint) -----------
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# ---- fzf : Ctrl-R fuzzy history, Ctrl-T fuzzy file search --------------------
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && \
    source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && \
    source /usr/share/doc/fzf/examples/completion.zsh

# ---- zoxide : a smarter cd. `z proj` jumps to your most-used "proj" dir ------
eval "$(zoxide init zsh)"

# ---- Prompt ------------------------------------------------------------------
eval "$(starship init zsh)"

# =============================================================================
#  Aliases — the "creature comfort" layer
# =============================================================================
# On Debian/Ubuntu the bat binary is installed as `batcat` (name clash).
alias bat='batcat'
alias cat='batcat'                                   # pretty cat (paged + highlighted)

# eza in place of ls.
# Icons are OFF by default so they don't render as black boxes for students
# whose terminal font isn't a Nerd Font (i.e. anyone on browser Codespaces).
# To turn icons ON: install a Nerd Font locally, then `export EZA_ICONS=1`
# (drop that line in ~/.zshrc to make it stick). The ${EZA_ICONS:+...} below
# expands to --icons=always only when EZA_ICONS is set.
alias ls='eza --group-directories-first --color=auto ${EZA_ICONS:+--icons=always}'
alias ll='eza -l  --group-directories-first --color=auto --git ${EZA_ICONS:+--icons=always}'
alias la='eza -la --group-directories-first --color=auto --git ${EZA_ICONS:+--icons=always}'
alias lt='eza --tree --level=2 ${EZA_ICONS:+--icons=always}'

# duf in place of df
alias df='duf'

# fd is installed as `fdfind` on Ubuntu — expose it under its real name
alias fd='fdfind'

# small quality-of-life
alias ..='cd ..'
alias ...='cd ../..'
alias please='sudo'

# git diffs through delta (configured globally below on first run)
export BAT_THEME="ansi"

# ---- Syntax highlighting MUST be sourced LAST -------------------------------
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh