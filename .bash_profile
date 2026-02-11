DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if typeset -f zsh >/dev/null; then
  export SHELL="/bin/zsh"
else
  export SHELL="/bin/bash"
fi

export BASH_SILENCE_DEPRECATION_WARNING=1

# Handy aliases
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
ac() {
  if ! command -v claude &>/dev/null; then
    curl -fsSL https://claude.ai/install.sh | bash
  fi
  claude --dangerously-skip-permissions "$@"
}

# Git aliases
alias gs="git status"
alias gp="git pull"
alias mp="git checkout master && git pull"
alias gc="git add . && git stash"
alias gco="git commit --no-verify"
alias gip="git push"
alias mainBranchName='git remote show origin | grep "HEAD branch" | cut -d ":" -f 2 | tr -d " "'
# Rebases the current branch with master (only works if "master" is a branch that exists)
alias rebase="git checkout \$(mainBranchName) && git pull && git checkout @{-1} && git rebase \$(mainBranchName)"
# Squashes all commits on the current branch into one commit (only works if "master" is your main branch)
alias squash="git reset \$(git merge-base \$(mainBranchName) \$(git rev-parse --abbrev-ref HEAD))"
# Commits everything without verifications and pushes it (for a quick "crap, I need to switch branches!")
alias wip="git add . && git commit -am 'wip'; git push"
alias pnpx="pnpm dlx"

# NVM — lazy-loaded so the shell starts instantly
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Add tab completion for many Bash commands
if which brew &>/dev/null && [ -f "$(brew --prefix)/share/bash-completion/bash_completion" ]; then
  source "$(brew --prefix)/share/bash-completion/bash_completion"
elif [ -f /etc/bash_completion ]; then
  source /etc/bash_completion
fi

# Enable tab completion for `g` by marking it as an alias for `git`
if type _git &>/dev/null && [ -f $DIR/.git-completion.bash ]; then
  complete -o default -o nospace -F _git g
fi

source $DIR/.git-completion.bash

# fnm setup
if ! command -v fnm &>/dev/null; then
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fi
# fnm
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi

# Starship prompt — auto-install to ~/.local/bin if missing
export PATH="$HOME/.local/bin:$PATH"
export STARSHIP_CONFIG="$DIR/starship.toml"
if ! command -v starship &>/dev/null; then
  mkdir -p "$HOME/.local/bin"
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
fi
eval "$(starship init bash)"

# Load environment secrets if they're specified
[[ -f "$DIR/.secrets" ]] && source "$DIR/.secrets"
