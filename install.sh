#!/bin/sh
# install.sh            — idempotent installer: wire this repo into ~/.zshrc + ~/.claude/skills
# install.sh <tool>...  — re-enable tools disabled by uninstall.sh <tool>
set -eu

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER="# >>> dotfiles >>>"
SKILLS_DIR="$HOME/.claude/skills"

link_skill() {
  mkdir -p "$SKILLS_DIR"
  ln -sfn "$1" "$SKILLS_DIR/$(basename "$1")"
}

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
    if [ -d "$DOTFILES/skills/$name" ]; then
      link_skill "$DOTFILES/skills/$name"
      echo "enabled: skill $name -> $SKILLS_DIR/$name"
      found=1
    fi
    [ $found -eq 1 ] || echo "nothing to enable for: $name"
  done
  echo "restart your shell (or 'source $ZSHRC') to apply"
  exit 0
fi

# skills: symlink every skills/<name>/ — runs on every install,
# independent of the zshrc block below
for d in "$DOTFILES"/skills/*/; do
  [ -d "$d" ] || continue
  link_skill "${d%/}"
  echo "skill linked: $SKILLS_DIR/$(basename "$d")"
done

if grep -qF "$MARKER" "$ZSHRC" 2>/dev/null; then
  echo "already installed in $ZSHRC"
  exit 0
fi

cat >> "$ZSHRC" <<EOF

$MARKER
export DOTFILES="$DOTFILES"
for f in "\$DOTFILES"/scripts/zsh/*.zsh(N); do source "\$f"; done
export PATH="\$DOTFILES/scripts/bin:\$PATH"
[ -f "\$HOME/.zshrc.local" ] && source "\$HOME/.zshrc.local"
# <<< dotfiles <<<
EOF

echo "installed: $ZSHRC now sources $DOTFILES/scripts/zsh/*.zsh"
echo "restart your shell or run: source $ZSHRC"
