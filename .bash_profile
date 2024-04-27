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

# Git aliases
alias gs="git status"
alias gp="git pull"
alias mp="git checkout master && git pull"
alias gc="git add . && git stash"
alias gco="git commit --no-verify"
alias gip="git push"
# Rebases the current branch with master (only works if "master" is a branch that exists)
alias rebase="git checkout master && git pull && git checkout @{-1} && git rebase master"
# Squashes all commits on the current branch into one commit (only works if "master" is your main branch)
alias squash="git reset \$(git merge-base master \$(git rev-parse --abbrev-ref HEAD))"
# Commits everything without verifications and pushes it (for a quick "crap, I need to switch branches!")
alias wip="git add . && git commit -am 'wip' && git push"

export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/local/opt/openssl/bin:$PATH"
export PATH="/usr/local/opt/mongodb@3.6/bin:$PATH"
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH:/Users/ryanpoe/Downloads/google-cloud-sdk/bin"

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
source $DIR/.git-prompt.sh
export GIT_PS1_SHOWDIRTYSTATE=true
export GIT_PS1_SHOWCOLORHINTS=true

## Note: these are set in `.gitexcludes`, but copied here for visibility. Avoid
## putting these here. It makes your terminals start slower.

# Global git includes
# git config --global core.excludesfile ~/.gitexcludes
# Automatically push remote branches to origin
# git config --global --add --bool push.autoSetupRemote true 

# Only load Liquid Prompt in interactive shells, not from a script or from scp
LP_PATH_KEEP=2
LP_PATH_LENGTH=20
LP_USER_ALWAYS=1
LP_ENABLE_LOAD=0
LP_HOSTNAME_ALWAYS=-1
[[ $- = *i* ]] && source $DIR/.liquidprompt

# Load environment secrets if they're specified
[[ -f "$DIR/.secrets" ]] && source "$DIR/.secrets"
