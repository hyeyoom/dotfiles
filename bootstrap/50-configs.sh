#!/bin/sh
set -eu
link() {
  if [ -e "$2" ] && [ ! -L "$2" ]; then
    mv "$2" "$2.bak"
    echo "backed up: $2 -> $2.bak"
  fi
  ln -sfn "$1" "$2"
}
link "$DOTFILES/config/p10k.zsh"  "$HOME/.p10k.zsh"
link "$DOTFILES/config/gitconfig" "$HOME/.gitconfig"

seed() {
  if [ ! -e "$2" ]; then
    cp "$1" "$2"
    chmod 600 "$2"
    echo "created: $2 — fill in your secrets"
  fi
}
seed "$DOTFILES/config/zshrc.local.example"     "$HOME/.zshrc.local"
seed "$DOTFILES/config/gitconfig.local.example" "$HOME/.gitconfig.local"
echo "configs: ok"
