alias dev="cd ~/projects"
alias ds="dev"

# Git aliases
alias gs="git status"
alias gp="git pull"
alias mp="git checkout master && git pull"
alias gc="git add . && git stash"
alias gip="git push"
alias rebase="git checkout master && git pull && git checkout @{-1} && git rebase master"

alias flushdns="dscacheutil -flushcache && sudo killall -HUP mDNSResponder"

export SHELL="/bin/bash"
export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/local/opt/openssl/bin:$PATH"

eval "$(rbenv init -)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# Add tab completion for many Bash commands
if which brew &>/dev/null && [ -f "$(brew --prefix)/share/bash-completion/bash_completion" ]; then
  source "$(brew --prefix)/share/bash-completion/bash_completion"
elif [ -f /etc/bash_completion ]; then
  source /etc/bash_completion
fi

# Enable tab completion for `g` by marking it as an alias for `git`
if type _git &>/dev/null && [ -f ~/git-completion.bash ]; then
  complete -o default -o nospace -F _git g
fi

source ~/git-completion.bash
source ~/git-prompt.sh
export GIT_PS1_SHOWDIRTYSTATE=true
export GIT_PS1_SHOWCOLORHINTS=true

git config --global core.excludesfile ~/.gitexcludes

# Only load Liquid Prompt in interactive shells, not from a script or from scp
LP_PATH_KEEP=2
LP_PATH_LENGTH=20
LP_USER_ALWAYS=0
LP_ENABLE_LOAD=0
[[ $- = *i* ]] && source ~/liquidprompt/liquidprompt
export PATH="/usr/local/opt/mongodb@3.6/bin:$PATH"

export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
