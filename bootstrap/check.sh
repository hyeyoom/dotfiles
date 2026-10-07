#!/bin/sh
set -u
DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0

[ -f "$HOME/.config/dotfiles/profile" ] && . "$HOME/.config/dotfiles/profile"
skip_step() {
  for _s in ${DOTFILES_SKIP_STEPS:-}; do
    if [ "$_s" = "$1" ] || [ "$_s" = "${1#*-}" ]; then return 0; fi
  done
  return 1
}
skip_link() { case " ${DOTFILES_SKIP_LINKS:-} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

chk() {
  if eval "$2" >/dev/null 2>&1; then echo "  o $1"; else echo "  x $1"; fail=1; fi
}
skp() { echo "  - $1 (skip: profile)"; }

echo "commands:"
for c in brew bat nvim fzf gh jenv gpg terminal-notifier; do
  chk "$c" "command -v $c"
done
if skip_step 40-claude; then skp claude; else chk claude "command -v claude"; fi

echo "zsh env:"
if skip_step 20-zsh; then
  skp "oh-my-zsh / powerlevel10k / plugins"
else
  chk "oh-my-zsh"               "[ -d \"\$HOME/.oh-my-zsh\" ]"
  chk "powerlevel10k"           "[ -d \"\$HOME/.oh-my-zsh/custom/themes/powerlevel10k\" ]"
  chk "zsh-autosuggestions"     "[ -d \"\$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions\" ]"
  chk "zsh-syntax-highlighting" "[ -d \"\$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting\" ]"
  chk "zsh-completions"         "[ -d \"\$HOME/.oh-my-zsh/custom/plugins/zsh-completions\" ]"
fi
chk "zshrc loader block" "grep -qF '# >>> dotfiles >>>' \"\$HOME/.zshrc\""

echo "runtimes:"
if skip_step 30-runtimes; then
  skp "nvm / cargo / nvim config"
else
  chk "nvm"         "[ -s \"\$HOME/.nvm/nvm.sh\" ]"
  chk "cargo"       "[ -f \"\$HOME/.cargo/env\" ]"
  chk "nvim config" "[ -f \"\$HOME/.config/nvim/init.lua\" ]"
fi

echo "links & local files:"
if skip_link p10k;      then skp "~/.p10k.zsh";  else chk "~/.p10k.zsh -> repo"  "[ -L \"\$HOME/.p10k.zsh\" ]"; fi
if skip_link gitconfig; then skp "~/.gitconfig"; else chk "~/.gitconfig -> repo" "[ -L \"\$HOME/.gitconfig\" ]"; fi
if skip_link claude || skip_step 40-claude; then
  skp "~/.claude/settings.json / CLAUDE.md / output-styles"
else
  chk "~/.claude/settings.json -> repo" "[ -L \"\$HOME/.claude/settings.json\" ]"
  chk "~/.claude/CLAUDE.md -> repo"     "[ -L \"\$HOME/.claude/CLAUDE.md\" ]"
  chk "~/.claude/output-styles -> repo" "[ -L \"\$HOME/.claude/output-styles\" ]"
fi
chk "~/.zshrc.local"                  "[ -f \"\$HOME/.zshrc.local\" ]"
chk "~/.gitconfig.local"              "[ -f \"\$HOME/.gitconfig.local\" ]"
chk "~/.claude/CLAUDE.local.md"       "[ -f \"\$HOME/.claude/CLAUDE.local.md\" ]"

echo "sealed secrets:"
for name in zshrc.local gitconfig.local; do
  sealed="$DOTFILES/secrets/$name.asc"
  plain="$HOME/.$name"
  if [ ! -f "$sealed" ]; then
    echo "  x $name not sealed (run ./colonize.sh --seal)"; fail=1
  elif [ -f "$plain" ] && [ "$plain" -nt "$sealed" ]; then
    echo "  x $name sealed copy is stale (run ./colonize.sh --seal)"; fail=1
  else
    echo "  o $name sealed"
  fi
done

echo "secret scan (tracked files):"
leaks="$(cd "$DOTFILES" && git ls-files -z | xargs -0 grep -lIE \
  '(ghp|gho|ntn)_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9-]{20,}|xox[bap]-[A-Za-z0-9-]{10,}|BEGIN [A-Z ]*PRIVATE KEY' \
  2>/dev/null || true)"
if [ -n "$leaks" ]; then
  echo "  x SECRETS FOUND IN REPO:"
  echo "$leaks" | sed 's/^/      /'
  fail=1
else
  echo "  o no secrets in tracked files"
fi

exit $fail
