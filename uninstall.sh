#!/bin/sh
# uninstall.sh            — remove the dotfiles block from ~/.zshrc and skill
#                           symlinks from ~/.claude/skills (full unlink)
# uninstall.sh <tool>...  — disable specific tools: rename to *.disabled,
#                           remove skill symlink (re-enable with: install.sh <tool>)
set -eu

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER_BEGIN="# >>> dotfiles >>>"
MARKER_END="# <<< dotfiles <<<"
SKILLS_DIR="$HOME/.claude/skills"

if [ $# -eq 0 ]; then
  # skill symlinks pointing into this repo
  if [ -d "$SKILLS_DIR" ]; then
    for link in "$SKILLS_DIR"/*; do
      [ -L "$link" ] || continue
      case "$(readlink "$link")" in
        "$DOTFILES"/skills/*)
          rm "$link"
          echo "removed skill link: $link"
          ;;
      esac
    done
  fi

  if grep -qF "$MARKER_BEGIN" "$ZSHRC" 2>/dev/null; then
    cp "$ZSHRC" "$ZSHRC.bak"
    sed -i '' "/^$MARKER_BEGIN\$/,/^$MARKER_END\$/d" "$ZSHRC"
    echo "removed dotfiles block from $ZSHRC (backup: $ZSHRC.bak)"
  else
    echo "no dotfiles block in $ZSHRC"
  fi
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
  if [ -d "$DOTFILES/skills/$name" ] && [ -L "$SKILLS_DIR/$name" ]; then
    rm "$SKILLS_DIR/$name"
    echo "disabled: skill $name (removed $SKILLS_DIR/$name)"
    found=1
  fi
  [ $found -eq 1 ] || echo "no such tool: $name (looked for scripts/zsh/$name.zsh, scripts/bin/$name, skills/$name)"
done
echo "restart your shell (or 'source $ZSHRC') to apply"
