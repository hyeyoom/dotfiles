#!/bin/sh
# idempotent installer: wire this repo into ~/.zshrc
set -eu

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER="# >>> dotfiles >>>"

if grep -qF "$MARKER" "$ZSHRC" 2>/dev/null; then
  echo "already installed in $ZSHRC"
  exit 0
fi

cat >> "$ZSHRC" <<EOF

$MARKER
export DOTFILES="$DOTFILES"
for f in "\$DOTFILES"/scripts/zsh/*.zsh(N); do source "\$f"; done
export PATH="\$DOTFILES/scripts/bin:\$PATH"
# <<< dotfiles <<<
EOF

echo "installed: $ZSHRC now sources $DOTFILES/scripts/zsh/*.zsh"
echo "restart your shell or run: source $ZSHRC"
