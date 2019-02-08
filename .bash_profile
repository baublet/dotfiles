alias dev="cd ~/Desktop/Development"
alias ds="dt"
alias gs="git status"
alias mp="git checkout master && git pull"
alias mpi="git checkout intl-master && git pull"
alias gc="git add . && git stash"
alias flushdns="dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
alias dt="dev && cd dm-vagrant && vagrant reload && cd source/ee && gc && mp && cd ../ee-intl && gc && mpi && cd ../ee-intl-sd && gc && mpi && cd ../magento && gc && mp && dev && sublime /Users/rscdm/Desktop/Development/dm-vagrant && dev"
alias cca="gulp && git commit -am \"Commit compiled assets\" && git push"

PATH=$PATH:~/.composer/vendor/bin/
export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/local/opt/openssl/bin:$PATH"
export PATH="$PATH:$HOME/.composer/vendor/bin"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
