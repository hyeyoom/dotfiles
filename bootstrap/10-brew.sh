#!/bin/sh
set -eu
if ! command -v brew >/dev/null 2>&1; then
  if [ -x /opt/homebrew/bin/brew ] || [ -x /usr/local/bin/brew ]; then :; else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  # Apple Silicon → Intel 순으로 탐지
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  else eval "$(/usr/local/bin/brew shellenv)"; fi
fi
brew bundle check --file "$DOTFILES/Brewfile" >/dev/null 2>&1 || \
  brew bundle --file "$DOTFILES/Brewfile"
echo "brew: ok"
