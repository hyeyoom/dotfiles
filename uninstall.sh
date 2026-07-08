#!/bin/sh
# uninstall.sh            — remove the dotfiles block from ~/.zshrc (full unlink)
# uninstall.sh <tool>...  — disable specific tools by renaming to *.disabled
#                           (re-enable with: install.sh <tool>)
set -eu

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER_BEGIN="# >>> dotfiles >>>"
MARKER_END="# <<< dotfiles <<<"

if [ $# -eq 0 ]; then
  if ! grep -qF "$MARKER_BEGIN" "$ZSHRC" 2>/dev/null; then
    echo "not installed in $ZSHRC"
    exit 0
  fi
  cp "$ZSHRC" "$ZSHRC.bak"
  sed -i '' "/^$MARKER_BEGIN\$/,/^$MARKER_END\$/d" "$ZSHRC"
  echo "removed dotfiles block from $ZSHRC (backup: $ZSHRC.bak)"
  echo "files under $DOTFILES are untouched"
  exit 0
fi

for name in "$@"; do
  found=0
  for f in "$DOTFILES/scripts/zsh/$name.zsh" "$DOTFILES/scripts/bin/$name"; do
    if [ -e "$f" ]; then
      mv "$f" "$f.disabled"
      echo "disabled: $f -> $f.disabled"
      found=1
    fi
  done
  [ $found -eq 1 ] || echo "no such tool: $name (looked for scripts/zsh/$name.zsh, scripts/bin/$name)"
done
echo "restart your shell (or 'source $ZSHRC') to apply"
