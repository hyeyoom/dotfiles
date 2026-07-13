#!/bin/sh
set -eu
if ! command -v brew >/dev/null 2>&1; then
  if [ -x /opt/homebrew/bin/brew ]; then :; else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
brew bundle check --file "$DOTFILES/Brewfile" >/dev/null 2>&1 || \
  brew bundle --file "$DOTFILES/Brewfile"
echo "brew: ok"
