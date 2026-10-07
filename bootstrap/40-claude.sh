#!/bin/sh
set -eu
[ -f "$HOME/.config/dotfiles/profile" ] && . "$HOME/.config/dotfiles/profile"
skip_link() { case " ${DOTFILES_SKIP_LINKS:-} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash

# $3 = profile 상의 링크 이름 — DOTFILES_SKIP_LINKS에 있으면 기존 파일 불가침
link() {
  if skip_link "$3"; then
    echo "link skipped (profile): $2"
    return 0
  fi
  if [ -e "$2" ] && [ ! -L "$2" ]; then
    mv "$2" "$2.bak"
    echo "backed up: $2 -> $2.bak"
  fi
  ln -sfn "$1" "$2"
}
mkdir -p "$HOME/.claude"
link "$DOTFILES/config/claude/settings.json" "$HOME/.claude/settings.json" claude
link "$DOTFILES/config/claude/CLAUDE.md"     "$HOME/.claude/CLAUDE.md"     claude
link "$DOTFILES/config/claude/output-styles" "$HOME/.claude/output-styles" claude

# 개인 정보(이름, 슬랙 표시명)는 레포 밖 ~/.claude/CLAUDE.local.md에 — 없으면 템플릿 생성
seed() {
  if [ ! -e "$2" ]; then
    cp "$1" "$2"
    chmod 600 "$2"
    echo "created: $2 — fill in your name / slack display name"
  fi
}
seed "$DOTFILES/config/claude/CLAUDE.local.md.example" "$HOME/.claude/CLAUDE.local.md"
echo "claude: ok"
