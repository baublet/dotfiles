DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ -n "$ZSH_VERSION" ]; then
  export SHELL="/bin/zsh"
else
  export SHELL="/bin/bash"
fi

export BASH_SILENCE_DEPRECATION_WARNING=1

# Handy aliases
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
unalias ac 2>/dev/null
ac() {
  if ! command -v claude &>/dev/null; then
    curl -fsSL https://claude.ai/install.sh | bash
  fi
  claude --dangerously-skip-permissions "$@"
}
unalias dc 2>/dev/null
dc() {
  if ! command -v opencode &>/dev/null; then
    curl -fsSL https://opencode.ai/install | bash
    export PATH="$HOME/.opencode/bin:$PATH"
  fi
  OPENCODE_CONFIG_CONTENT='{"permission":"allow"}' opencode "$@"
}
unalias gh 2>/dev/null
gh() {
  if ! command gh --version &>/dev/null; then
    curl -sS https://webi.sh/gh | bash
  fi
  command gh "$@"
}
# Git aliases
alias gs="git status"
alias gp="git pull"
alias mp="git checkout master && git pull"
alias gc="git add . && git stash"
alias gco="git commit --no-verify"
alias gip="git push"
alias mainBranchName='git remote show origin | grep "HEAD branch" | cut -d ":" -f 2 | tr -d " "'
alias rebase="git checkout \$(mainBranchName) && git pull && git checkout @{-1} && git rebase \$(mainBranchName)"
alias squash="git reset \$(git merge-base \$(mainBranchName) \$(git rev-parse --abbrev-ref HEAD))"
alias wip="git add . && git commit -am 'wip'; git push"
alias pnpx="pnpm dlx"

# NVM — lazy-loaded so the shell starts instantly
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# fnm — add to PATH always, but only auto-install interactively
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell bash 2>/dev/null)"
fi

# Paths needed in all contexts
export PATH="$HOME/.local/bin:$PATH"

# Interactive-only setup (completions, prompt, auto-installs)
if [[ $- == *i* ]]; then
  # Tab completion
  if which brew &>/dev/null && [ -f "$(brew --prefix)/share/bash-completion/bash_completion" ]; then
    source "$(brew --prefix)/share/bash-completion/bash_completion"
  elif [ -f /etc/bash_completion ]; then
    source /etc/bash_completion
  fi

  if type _git &>/dev/null && [ -f "$DIR/.git-completion.bash" ]; then
    complete -o default -o nospace -F _git g
  fi

  [ -f "$DIR/.git-completion.bash" ] && source "$DIR/.git-completion.bash"

  # Auto-install fnm if missing
  if ! command -v fnm &>/dev/null; then
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
    [ -d "$FNM_PATH" ] && export PATH="$FNM_PATH:$PATH" && eval "$(fnm env 2>/dev/null)"
  fi

  # Starship prompt
  export STARSHIP_CONFIG="$DIR/starship.toml"
  if ! command -v starship &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" >/dev/null 2>&1
  fi
  if ! type starship_precmd &>/dev/null; then
    eval "$(starship init bash)"
  fi

  # Auto-update dotfiles in the background
  GIT_TERMINAL_PROMPT=0 git -C "$DIR" pull --ff-only </dev/null >/dev/null 2>&1 & disown

  # Auto-install RTK (from source) in the background
  if ! command -v rtk &>/dev/null; then
    RTK_LOCK="$HOME/.rtk-install.lock"
    RTK_STALE=false
    if [ -f "$RTK_LOCK" ]; then
      RTK_LOCK_TIME=$(cat "$RTK_LOCK" 2>/dev/null)
      RTK_NOW=$(date +%s)
      if [ $(( RTK_NOW - RTK_LOCK_TIME )) -gt 600 ]; then
        RTK_STALE=true
      fi
    fi
    if [ ! -f "$RTK_LOCK" ] || [ "$RTK_STALE" = true ]; then
      (
        date +%s > "$RTK_LOCK"
        if ! command -v cargo &>/dev/null; then
          curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
          . "$HOME/.cargo/env"
        fi
        cargo install --git https://github.com/rtk-ai/rtk
        rm -f "$RTK_LOCK"
        if [ ! -f "$HOME/.rtk-init.done" ]; then
          "$HOME/.cargo/bin/rtk" init --global --auto-patch
          touch "$HOME/.rtk-init.done"
        fi
      ) </dev/null >/dev/null 2>&1 & disown
    fi
    unset RTK_LOCK RTK_LOCK_TIME RTK_NOW RTK_STALE
  fi

  # RTK hook needs real jq — remove Node.js imposter and install system jq
  if command -v jq &>/dev/null && jq --version 2>&1 | grep -q 'Cannot find module'; then
    npm uninstall -g jq >/dev/null 2>&1
  fi
  if ! command -v jq &>/dev/null; then
    sudo apt-get install -y -qq jq >/dev/null 2>&1 & disown
  fi
fi

# Load environment secrets if they're specified
[[ -f "$DIR/.secrets" ]] && source "$DIR/.secrets"
