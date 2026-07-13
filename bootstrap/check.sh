#!/bin/sh
set -u
DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0

chk() {
  if eval "$2" >/dev/null 2>&1; then echo "  o $1"; else echo "  x $1"; fail=1; fi
}

echo "commands:"
for c in brew bat nvim fzf gh jenv gpg terminal-notifier claude; do
  chk "$c" "command -v $c"
done

echo "zsh env:"
chk "oh-my-zsh"               "[ -d \"\$HOME/.oh-my-zsh\" ]"
chk "powerlevel10k"           "[ -d \"\$HOME/.oh-my-zsh/custom/themes/powerlevel10k\" ]"
chk "zsh-autosuggestions"     "[ -d \"\$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions\" ]"
chk "zsh-syntax-highlighting" "[ -d \"\$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting\" ]"
chk "zsh-completions"         "[ -d \"\$HOME/.oh-my-zsh/custom/plugins/zsh-completions\" ]"
chk "zshrc loader block"      "grep -qF '# >>> dotfiles >>>' \"\$HOME/.zshrc\""

echo "runtimes:"
chk "nvm"         "[ -s \"\$HOME/.nvm/nvm.sh\" ]"
chk "cargo"       "[ -f \"\$HOME/.cargo/env\" ]"
chk "nvim config" "[ -f \"\$HOME/.config/nvim/init.lua\" ]"

echo "links & local files:"
chk "~/.p10k.zsh -> repo"             "[ -L \"\$HOME/.p10k.zsh\" ]"
chk "~/.gitconfig -> repo"            "[ -L \"\$HOME/.gitconfig\" ]"
chk "~/.claude/settings.json -> repo" "[ -L \"\$HOME/.claude/settings.json\" ]"
chk "~/.zshrc.local"                  "[ -f \"\$HOME/.zshrc.local\" ]"
chk "~/.gitconfig.local"              "[ -f \"\$HOME/.gitconfig.local\" ]"

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
