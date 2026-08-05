#!/bin/sh
# uninstall.sh            — remove the dotfiles block from ~/.zshrc and skill
#                           symlinks from ~/.claude/skills (full unlink)
# uninstall.sh <tool>...  — disable specific tools via ~/.config/dotfiles/profile
#                           (레포 파일은 건드리지 않음 — re-enable: install.sh <tool>)
set -eu

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER_BEGIN="# >>> dotfiles >>>"
MARKER_END="# <<< dotfiles <<<"
SKILLS_DIR="$HOME/.claude/skills"
PROFILE="$HOME/.config/dotfiles/profile"

# --- profile helpers: DOTFILES_DISABLED_TOOLS="a b c" 한 줄을 관리 ---
profile_disabled() {
  [ -f "$PROFILE" ] || { echo ""; return 0; }
  sed -n 's/^DOTFILES_DISABLED_TOOLS="\(.*\)"$/\1/p' "$PROFILE" | tail -1
}

profile_set_disabled() {
  mkdir -p "$(dirname "$PROFILE")"
  [ -f "$PROFILE" ] || cp "$DOTFILES/config/dotfiles-profile.example" "$PROFILE"
  if grep -q '^DOTFILES_DISABLED_TOOLS=' "$PROFILE"; then
    sed -i '' "s|^DOTFILES_DISABLED_TOOLS=.*|DOTFILES_DISABLED_TOOLS=\"$1\"|" "$PROFILE"
  else
    printf 'DOTFILES_DISABLED_TOOLS="%s"\n' "$1" >> "$PROFILE"
  fi
}

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

disabled="$(profile_disabled)"
for name in "$@"; do
  found=0
  [ -e "$DOTFILES/scripts/zsh/$name.zsh" ] && found=1
  if [ -d "$DOTFILES/skills/$name" ]; then
    found=1
    if [ -L "$SKILLS_DIR/$name" ]; then
      rm "$SKILLS_DIR/$name"
      echo "removed skill link: $SKILLS_DIR/$name"
    fi
  fi
  if [ -e "$DOTFILES/scripts/bin/$name" ] && [ $found -eq 0 ]; then
    echo "note: scripts/bin/$name 은 profile로 비활성화할 수 없다 (PATH가 디렉터리 단위) — 안 쓰면 됨"
    continue
  fi
  if [ $found -eq 0 ]; then
    echo "no such tool: $name (looked for scripts/zsh/$name.zsh, skills/$name)"
    continue
  fi
  case " $disabled " in
    *" $name "*) echo "already disabled: $name" ;;
    *)
      disabled="${disabled:+$disabled }$name"
      echo "disabled: $name (profile DOTFILES_DISABLED_TOOLS — 레포 파일은 그대로)"
      ;;
  esac
done
profile_set_disabled "$disabled"
echo "restart your shell (or 'source $ZSHRC') to apply"
