alias dev="cd ~/Desktop/Development"
alias ds="dt"
alias gs="git status"
alias mp="git checkout master && git pull"
alias mpi="git checkout intl-master && git pull"
alias gc="git add . && git stash"
alias flushdns="dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
alias dt="dev && cd dm-vagrant && vagrant reload && cd source/ee && gc && mp && cd ../ee-intl && gc && mpi && cd ../ee-intl-sd && gc && mpi && cd ../magento && gc && mp && dev && sublime /Users/rscdm/Desktop/Development/dm-vagrant && dev"
alias cca="gulp && git commit -am \"Commit compiled assets\" && git push"
alias ee="dev && cd dm-vagrant/source/ee"
alias magento="dev && cd dm-vagrant/source/magento"
alias ee-intl="dev && cd dm-vagrant/source/ee-intl"
alias ee-intl-sd="dev && cd dm-vagrant/source/ee-intl-sd"

PATH=$PATH:~/.composer/vendor/bin/
export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/local/opt/openssl/bin:$PATH"
export PATH="$PATH:$HOME/.composer/vendor/bin"

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
if type _git &>/dev/null && [ -f /usr/local/etc/bash_completion.d/git-completion.bash ]; then
  complete -o default -o nospace -F _git g
fi
