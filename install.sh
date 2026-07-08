#!/bin/sh
# install.sh            — idempotent installer: wire this repo into ~/.zshrc
# install.sh <tool>...  — re-enable tools disabled by uninstall.sh <tool>
set -eu

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER="# >>> dotfiles >>>"

if [ $# -gt 0 ]; then
  for name in "$@"; do
    found=0
    for f in "$DOTFILES/scripts/zsh/$name.zsh" "$DOTFILES/scripts/bin/$name"; do
      if [ -e "$f.disabled" ]; then
        mv "$f.disabled" "$f"
        echo "enabled: $f"
        found=1
      fi
    done
    [ $found -eq 1 ] || echo "nothing to enable for: $name"
  done
  echo "restart your shell (or 'source $ZSHRC') to apply"
  exit 0
fi

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
