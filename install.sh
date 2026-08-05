#!/bin/sh
# install.sh            — idempotent installer: wire this repo into ~/.zshrc + ~/.claude/skills
#                         (기존 로더 블록이 구버전이면 백업 후 자동 교체)
# install.sh <tool>...  — re-enable tools disabled by uninstall.sh <tool>
#                         (~/.config/dotfiles/profile 의 DOTFILES_DISABLED_TOOLS 편집)
set -eu

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER="# >>> dotfiles >>>"
MARKER_END="# <<< dotfiles <<<"
SKILLS_DIR="$HOME/.claude/skills"
PROFILE="$HOME/.config/dotfiles/profile"

link_skill() {
  mkdir -p "$SKILLS_DIR"
  ln -sfn "$1" "$SKILLS_DIR/$(basename "$1")"
}

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

list_remove() {  # $1=list $2=word -> stdout
  out=""
  for w in $1; do
    [ "$w" = "$2" ] || out="$out $w"
  done
  echo "${out# }"
}

# --- install.sh <tool>: profile에서 제거 + 스킬 재링크 (+ 레거시 .disabled 복원) ---
if [ $# -gt 0 ]; then
  disabled="$(profile_disabled)"
  for name in "$@"; do
    found=0
    for f in "$DOTFILES/scripts/zsh/$name.zsh" "$DOTFILES/scripts/bin/$name"; do
      if [ -e "$f.disabled" ]; then
        mv "$f.disabled" "$f"
        echo "restored: $f"
        found=1
      fi
      [ -e "$f" ] && found=1
    done
    if [ -d "$DOTFILES/skills/$name" ]; then
      link_skill "$DOTFILES/skills/$name"
      echo "enabled: skill $name -> $SKILLS_DIR/$name"
      found=1
    fi
    if [ $found -eq 1 ]; then
      case " $disabled " in
        *" $name "*)
          disabled="$(list_remove "$disabled" "$name")"
          echo "enabled: $name (profile에서 제거)"
          ;;
        *) echo "already enabled: $name" ;;
      esac
    else
      echo "no such tool: $name"
    fi
  done
  profile_set_disabled "$disabled"
  echo "restart your shell (or 'source $ZSHRC') to apply"
  exit 0
fi

# --- 레거시 마이그레이션: *.disabled rename → profile 방식 ---
disabled="$(profile_disabled)"
migrated=0
for f in "$DOTFILES"/scripts/zsh/*.zsh.disabled; do
  [ -e "$f" ] || continue
  plain="${f%.disabled}"
  name="$(basename "$plain" .zsh)"
  mv "$f" "$plain"
  case " $disabled " in *" $name "*) ;; *) disabled="${disabled:+$disabled }$name" ;; esac
  echo "migrated: $name (.disabled rename → profile DOTFILES_DISABLED_TOOLS)"
  migrated=1
done
for f in "$DOTFILES"/scripts/bin/*.disabled; do
  [ -e "$f" ] || continue
  mv "$f" "${f%.disabled}"
  echo "migrated: ${f%.disabled} 복원 — bin 스크립트는 profile 비활성화 미지원 (PATH가 디렉터리 단위)"
done
[ $migrated -eq 1 ] && profile_set_disabled "$disabled"

# skills: symlink every skills/<name>/ — runs on every install,
# independent of the zshrc block below (profile에서 disabled면 생략)
for d in "$DOTFILES"/skills/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  case " $(profile_disabled) " in *" $name "*) continue ;; esac
  link_skill "${d%/}"
  echo "skill linked: $SKILLS_DIR/$name"
done

# --- zshrc 로더 블록: 생성 → 기존과 비교 → 다르면 백업 후 교체 ---
block_file="$(mktemp)"
trap 'rm -f "$block_file"' EXIT
cat > "$block_file" <<EOF
$MARKER
export DOTFILES="$DOTFILES"
[ -f "\$HOME/.config/dotfiles/profile" ] && source "\$HOME/.config/dotfiles/profile"
for f in "\$DOTFILES"/scripts/zsh/*.zsh(N); do
  case " \${DOTFILES_DISABLED_TOOLS:-} " in
    (*" \${\${f:t}%.zsh} "*) ;;
    (*) source "\$f" ;;
  esac
done
export PATH="\$DOTFILES/scripts/bin:\$PATH"
[ -f "\$HOME/.zshrc.local" ] && source "\$HOME/.zshrc.local"
$MARKER_END
EOF

if grep -qF "$MARKER" "$ZSHRC" 2>/dev/null; then
  current="$(sed -n "/^$MARKER\$/,/^$MARKER_END\$/p" "$ZSHRC")"
  if [ "$current" = "$(cat "$block_file")" ]; then
    echo "already installed in $ZSHRC (loader up to date)"
    exit 0
  fi
  cp "$ZSHRC" "$ZSHRC.bak"
  awk -v begin="$MARKER" -v end="$MARKER_END" -v repl="$block_file" '
    $0 == begin { while ((getline line < repl) > 0) print line; skip=1; next }
    $0 == end   { skip=0; next }
    !skip
  ' "$ZSHRC" > "$ZSHRC.tmp" && mv "$ZSHRC.tmp" "$ZSHRC"
  echo "updated loader block in $ZSHRC (backup: $ZSHRC.bak)"
else
  { echo ""; cat "$block_file"; } >> "$ZSHRC"
  echo "installed: $ZSHRC now sources $DOTFILES/scripts/zsh/*.zsh"
fi
echo "restart your shell or run: source $ZSHRC"
