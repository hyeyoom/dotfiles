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

# sealed secrets가 있고 GPG 개인키가 import돼 있으면 복호화, 아니면 빈 템플릿 생성
unseal() {
  if [ ! -e "$2" ] && [ -f "$1" ] && gpg --quiet --batch --decrypt -o "$2" "$1" 2>/dev/null; then
    chmod 600 "$2"
    echo "unsealed: $2"
  fi
}
unseal "$DOTFILES/secrets/zshrc.local.asc"     "$HOME/.zshrc.local"
unseal "$DOTFILES/secrets/gitconfig.local.asc" "$HOME/.gitconfig.local"

seed() {
  if [ ! -e "$2" ]; then
    cp "$1" "$2"
    chmod 600 "$2"
    echo "created: $2 — fill in your secrets (or import GPG key, delete this file, rerun)"
  fi
}
seed "$DOTFILES/config/zshrc.local.example"     "$HOME/.zshrc.local"
seed "$DOTFILES/config/gitconfig.local.example" "$HOME/.gitconfig.local"
echo "configs: ok"
