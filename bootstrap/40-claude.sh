#!/bin/sh
set -eu
[ -f "$HOME/.config/dotfiles/profile" ] && . "$HOME/.config/dotfiles/profile"
skip_link() { case " ${DOTFILES_SKIP_LINKS:-} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash

if skip_link claude; then
  echo "claude: settings.json link skipped (profile) — 기존 설정 유지"
else
  mkdir -p "$HOME/.claude"
  target="$HOME/.claude/settings.json"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mv "$target" "$target.bak"
    echo "backed up: $target -> $target.bak"
  fi
  ln -sfn "$DOTFILES/config/claude/settings.json" "$target"
fi
echo "claude: ok"
