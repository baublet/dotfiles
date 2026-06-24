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
  local extra=()
  if [ -d "$HOME/wt-tooling" ]; then
    extra=(--add-dir "$HOME/wt-tooling")
  elif git clone https://github.com/KazooHR/wt-tooling "$HOME/wt-tooling" 2>/dev/null; then
    extra=(--add-dir "$HOME/wt-tooling")
  fi
  claude --dangerously-skip-permissions "${extra[@]}" "$@"
}
unalias dc 2>/dev/null
dc() {
  if ! command -v opencode &>/dev/null; then
    curl -fsSL https://opencode.ai/install | bash
    export PATH="$HOME/.opencode/bin:$PATH"
  fi
  GOOGLE_VERTEX_LOCATION="${GOOGLE_VERTEX_LOCATION:-global}" \
  GOOGLE_VERTEX_PROJECT="${GOOGLE_VERTEX_PROJECT:-kazoo-engineering}" \
  OPENCODE_CONFIG_CONTENT='{"permission":"allow"}' opencode "$@"
}
unalias sc 2>/dev/null
sc() {
  if ! command -v maki &>/dev/null; then
    # Install into ~/.local/bin (already on PATH) so no sudo is needed — the
    # installer's /usr/local/bin default would prompt for a password on fresh envs.
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://maki.sh/install.sh | MAKI_INSTALL_DIR="$HOME/.local/bin" sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
  if ! command -v maki &>/dev/null; then
    echo "sc: 'maki' isn't installed and the auto-install failed." >&2
    echo "  Install it manually:  curl -fsSL https://maki.sh/install.sh | sh" >&2
    echo "  Docs:                 https://maki.sh/docs/" >&2
    return 1
  fi
  # The Vertex provider mints a token from gcloud/ADC — no API key needed. Check the
  # prerequisites up front and tell the user exactly how to get whatever's missing.
  if ! command -v gcloud &>/dev/null; then
    echo "sc: needs the Google Cloud CLI ('gcloud'), which isn't installed." >&2
    echo "  Install it:  curl https://sdk.cloud.google.com | bash && exec -l \"\$SHELL\"" >&2
    echo "  Or see:      https://cloud.google.com/sdk/docs/install" >&2
    echo "  Then run:    gcloud auth application-default login" >&2
    return 1
  fi
  # Cheap, network-free credential check (mirrors what the provider actually uses):
  # an explicit service-account JSON, an ADC file, or any active gcloud account.
  if [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] \
     && [ ! -f "$HOME/.config/gcloud/application_default_credentials.json" ] \
     && ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
    echo "sc: no Google Cloud credentials found for Vertex." >&2
    echo "  Sign in:  gcloud auth application-default login" >&2
    echo "  Or use a service-account key:  export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json" >&2
    return 1
  fi
  # Link the Vertex (Gemini) dynamic provider so no API key is needed — it mints a
  # short-lived token from gcloud/ADC. Re-link each run so repo updates take effect.
  mkdir -p "$HOME/.config/maki/providers"
  chmod +x "$DIR/maki/providers/vertex" 2>/dev/null
  ln -sf "$DIR/maki/providers/vertex" "$HOME/.config/maki/providers/vertex"
  # Seed a default config (Vertex Gemini 3.5 Flash, YOLO) on first run; user edits persist.
  local cfg="$HOME/.config/maki/init.lua"
  if [ ! -f "$cfg" ]; then
    cat > "$cfg" <<'EOF'
maki.setup({
    always_yolo = true,
    provider = {
        default_model = "vertex/gemini-3.5-flash",
    },
})
EOF
  fi
  local proj="${GOOGLE_VERTEX_PROJECT:-kazoo-engineering}"
  local loc="${GOOGLE_VERTEX_LOCATION:-global}"

  # Gemini 3.x requires a thoughtSignature echoed back on every multi-turn tool
  # call, which Maki doesn't carry across turns. Run a tiny local proxy that caches
  # and re-injects those signatures so tool use works. Scoped to this session.
  local proxy_pid=""
  if command -v python3 &>/dev/null; then
    local proxy_port
    proxy_port=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()' 2>/dev/null)
    if [ -n "$proxy_port" ]; then
      GOOGLE_VERTEX_LOCATION="$loc" python3 "$DIR/maki/providers/vertex-proxy.py" "$proxy_port" >/dev/null 2>&1 &
      proxy_pid=$!
      export VERTEX_PROXY_PORT="$proxy_port"
      # Block until the proxy accepts connections (avoids a startup race).
      python3 -c "import socket,time
for _ in range(100):
    try:
        socket.create_connection(('127.0.0.1',$proxy_port),0.1).close(); break
    except OSError: time.sleep(0.05)" 2>/dev/null
    fi
  else
    echo "sc: python3 not found — Gemini 3.x tool calls need the proxy. Install python3," >&2
    echo "    or set default_model to a 2.5 model in ~/.config/maki/init.lua." >&2
  fi

  GOOGLE_VERTEX_PROJECT="$proj" GOOGLE_VERTEX_LOCATION="$loc" maki "$@"
  local rc=$?

  [ -n "$proxy_pid" ] && kill "$proxy_pid" 2>/dev/null
  unset VERTEX_PROXY_PORT
  return $rc
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

  # Background maintenance uses setsid so there is no controlling tty (/dev/tty prompts).

  # Auto-update dotfiles in the background
  setsid env GIT_TERMINAL_PROMPT=0 git -C "$DIR" pull --ff-only </dev/null >/dev/null 2>&1 & disown

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
      setsid bash -c "
        RTK_LOCK=\"\$HOME/.rtk-install.lock\"
        date +%s > \"\$RTK_LOCK\"
        if ! command -v cargo &>/dev/null; then
          curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
          . \"\$HOME/.cargo/env\"
        fi
        cargo install --git https://github.com/rtk-ai/rtk
        rm -f \"\$RTK_LOCK\"
        if [ ! -f \"\$HOME/.rtk-init.done\" ]; then
          \"\$HOME/.cargo/bin/rtk\" init --global --auto-patch
          touch \"\$HOME/.rtk-init.done\"
        fi
      " </dev/null >/dev/null 2>&1 & disown
    fi
    unset RTK_LOCK RTK_LOCK_TIME RTK_NOW RTK_STALE
  fi

  # RTK hook needs real jq — remove Node.js imposter and install system jq
  if command -v jq &>/dev/null && jq --version 2>&1 | grep -q 'Cannot find module'; then
    npm uninstall -g jq >/dev/null 2>&1
  fi
  if ! command -v jq &>/dev/null; then
    setsid env DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -qq jq </dev/null >/dev/null 2>&1 & disown
  fi
fi

# Load environment secrets if they're specified
[[ -f "$DIR/.secrets" ]] && source "$DIR/.secrets"
