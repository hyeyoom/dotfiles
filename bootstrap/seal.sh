#!/bin/sh
# ~/.zshrc.local, ~/.gitconfig.local 을 GPG 공개키로 암호화해 secrets/ 에 보관.
# 실행: ./colonize.sh --seal (시크릿 수정 후 재실행)
set -eu
DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"

recipient="$(git config user.signingkey || true)"
[ -n "$recipient" ] || { echo "git config user.signingkey is empty — cannot pick GPG recipient" >&2; exit 1; }

mkdir -p "$DOTFILES/secrets"
seal() {
  [ -f "$1" ] || { echo "skip (missing): $1"; return 0; }
  gpg --quiet --batch --yes --armor --encrypt --recipient "$recipient" -o "$2" "$1"
  echo "sealed: $2"
}
seal "$HOME/.zshrc.local"     "$DOTFILES/secrets/zshrc.local.asc"
seal "$HOME/.gitconfig.local" "$DOTFILES/secrets/gitconfig.local.asc"
echo "commit & push the secrets/ files to publish"
