# Ryan's Dotfiles

Personal shell configuration for bash/zsh, managed by sourcing from `~/dotfiles/.bash_profile`.

## Repository Structure

```
.bash_profile          # Main entry point: aliases, PATH, tool init, prompt
.bash_aliases          # Just sources .bash_profile
.git-completion.bash   # Git tab completion for bash/zsh
.gitconfig             # Git user config, colors, push defaults
.gitexcludes           # Global gitignore (OS junk, IDE files, compiled artifacts)
.secrets.example       # Template for local env secrets (not tracked)
iterm/                 # iTerm2 preferences plist
```

## How It Works

Everything is sourced from `.bash_profile`, which is the single entry point. The user's `~/.bashrc` (or `~/.zshrc`) just has `source ~/dotfiles/.bash_profile`.

The `.gitignore` uses a **whitelist approach**: everything is ignored by default (`*`), and tracked files are explicitly un-ignored.

Secrets go in `.secrets` (git-ignored). See `.secrets.example` for the template.

## Key Aliases

- **Navigation**: `..`, `...`, `....`
- **Git**: `gs` (status), `gp` (pull), `gip` (push), `gco` (commit --no-verify), `gc` (add + stash), `mp` (checkout master + pull)
- **Git workflows**: `rebase` (rebase current branch on main), `squash` (squash branch commits), `wip` (commit all + push)
- **Tools**: `pnpx` (pnpm dlx), `ac` (Claude Code)

`mainBranchName` dynamically detects the default branch from the remote (works with master/main/develop/etc).

## Tools & Integrations

- **NVM** for Node.js version management
- **Git completion** script for tab completion
- **Bash completion** via brew or system package

## Shell Compatibility

Detects zsh vs bash at runtime. Works with both, though primarily used with bash-style config sourcing.

## Installation

```sh
cd ~ && git clone git@github.com:baublet/dotfiles.git
echo "source ~/dotfiles/.bash_profile" >> ~/.bashrc
source ~/.bashrc
```

## Making Changes

- Keep aliases and PATH modifications in `.bash_profile`
- Never commit `.secrets` — only `.secrets.example`
- The `.gitignore` whitelist means new files must be explicitly un-ignored to be tracked
- Test changes with `source ~/dotfiles/.bash_profile` before committing
