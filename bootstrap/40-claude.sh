#!/bin/sh
set -eu
command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash

mkdir -p "$HOME/.claude"
target="$HOME/.claude/settings.json"
if [ -e "$target" ] && [ ! -L "$target" ]; then
  mv "$target" "$target.bak"
  echo "backed up: $target -> $target.bak"
fi
ln -sfn "$DOTFILES/config/claude/settings.json" "$target"
echo "claude: ok"
