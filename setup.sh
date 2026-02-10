#!/usr/bin/env bash
#
# Bootstrap a fresh VM for development.
#
# Run (pick one):
#
#   # Option 1: one-liner from a fresh machine (no git clone needed)
#   curl -fsSL https://raw.githubusercontent.com/baublet/dotfiles/master/setup.sh | bash
#
#   # Option 2: clone first, then run
#   git clone https://github.com/baublet/dotfiles.git ~/dotfiles && ~/dotfiles/setup.sh
#
#   # Option 3: already have the repo
#   ~/dotfiles/setup.sh
#
# After making changes, push:
#
#   cd ~/dotfiles
#   git add -A && git commit -m "update setup script"
#   git push
#
set -uo pipefail

WARNINGS=()

warn() {
  echo "⚠ $1"
  WARNINGS+=("$1")
}

echo "=== Dev Environment Setup ==="
echo "Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ── Dotfiles ──────────────────────────────────────────────────────────────────

if [ -d "$HOME/dotfiles/.git" ]; then
  echo "✓ dotfiles already cloned"
else
  echo "→ Cloning dotfiles..."
  git clone https://github.com/baublet/dotfiles.git "$HOME/dotfiles"
fi

# Source .bash_profile from .bashrc if not already configured
if ! grep -q "source ~/dotfiles/.bash_profile" "$HOME/.bashrc" 2>/dev/null; then
  echo "→ Wiring dotfiles into .bashrc..."
  echo 'source ~/dotfiles/.bash_profile' >> "$HOME/.bashrc"
fi

# Symlink gitconfig and gitexcludes
if [ ! -f "$HOME/.gitconfig" ] || ! grep -q "baublet" "$HOME/.gitconfig" 2>/dev/null; then
  echo "→ Linking .gitconfig..."
  ln -sf "$HOME/dotfiles/.gitconfig" "$HOME/.gitconfig"
fi

if [ ! -f "$HOME/.gitexcludes" ]; then
  echo "→ Linking .gitexcludes..."
  ln -sf "$HOME/dotfiles/.gitexcludes" "$HOME/.gitexcludes"
fi

# ── fnm (Fast Node Manager) ──────────────────────────────────────────────────

if command -v fnm &>/dev/null; then
  echo "✓ fnm already installed"
else
  echo "→ Installing fnm..."
  if curl -fsSL https://fnm.vercel.app/install | bash; then
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env)"
  else
    warn "fnm install failed (site may be down). Install later: curl -fsSL https://fnm.vercel.app/install | bash"
  fi
fi

# ── jq ────────────────────────────────────────────────────────────────────────

if command -v jq &>/dev/null; then
  echo "✓ jq already installed"
else
  echo "→ Installing jq..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq jq || warn "jq install via apt failed"
  elif command -v brew &>/dev/null; then
    brew install jq || warn "jq install via brew failed"
  else
    warn "Could not install jq — no apt-get or brew found. Install manually."
  fi
fi

# ── Claude Code ───────────────────────────────────────────────────────────────

if command -v claude &>/dev/null; then
  echo "✓ Claude Code already installed"
else
  echo "→ Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code || warn "Claude Code install failed. Install later: npm install -g @anthropic-ai/claude-code"
fi

# ── kazoo-web ─────────────────────────────────────────────────────────────────

if [ -d "$HOME/kazoo-web/.git" ]; then
  echo "✓ kazoo-web already cloned"
else
  echo "→ Cloning kazoo-web..."
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "⚠ GITHUB_TOKEN is not set. Set it and re-run, e.g.:"
    echo "  export GITHUB_TOKEN=ghp_..."
    echo "  ~/dotfiles/setup.sh"
  else
    git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/KazooHR/kazoo-web.git" "$HOME/kazoo-web"
  fi
fi

# Install Node via fnm if kazoo-web has a .node-version
if command -v fnm &>/dev/null && [ -f "$HOME/kazoo-web/.node-version" ]; then
  NODE_VERSION=$(cat "$HOME/kazoo-web/.node-version")
  echo "→ Ensuring Node $NODE_VERSION is installed..."
  fnm install "$NODE_VERSION" || warn "fnm install Node $NODE_VERSION failed"
  fnm use "$NODE_VERSION" 2>/dev/null || true
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "=== Setup complete (with warnings) ==="
  echo ""
  for w in "${WARNINGS[@]}"; do
    echo "  ⚠ $w"
  done
  echo ""
else
  echo "=== Setup complete! ==="
fi
echo ""
echo "Next steps:"
echo "  1. source ~/.bashrc"
echo "  2. cd ~/kazoo-web && yarn"
echo "  3. yarn coder:init    (first time only — sets up Postgres, Redis, .env)"
echo ""
