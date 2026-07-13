#!/bin/sh
# secrets/*.asc 를 복호화해 stdout으로 출력 (복호화 가능한지 검증용).
# 실행: ./colonize.sh --reveal
set -eu
DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"

found=0
for f in "$DOTFILES"/secrets/*.asc; do
  [ -f "$f" ] || continue
  found=1
  echo "===== $(basename "$f") ====="
  gpg --quiet --batch --decrypt "$f"
  echo ""
done
[ "$found" -eq 1 ] || { echo "no sealed secrets in $DOTFILES/secrets" >&2; exit 1; }
