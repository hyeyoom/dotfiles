#!/bin/sh
# colonize.sh          — 새 macOS 머신에 전체 환경 설치 (멱등)
# colonize.sh --check  — 설치 없이 상태 점검 + 레포 시크릿 스캔
# colonize.sh --seal   — ~/.*.local 시크릿을 GPG로 암호화해 secrets/에 보관
# colonize.sh --reveal — secrets/*.asc 복호화해 콘솔 출력 (검증용)
set -eu

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
export DOTFILES

[ "$(uname -s)" = "Darwin" ] || { echo "colonize.sh supports macOS only" >&2; exit 1; }

if [ "${1:-}" = "--check" ]; then
  exec sh "$DOTFILES/bootstrap/check.sh"
fi

if [ "${1:-}" = "--seal" ]; then
  exec sh "$DOTFILES/bootstrap/seal.sh"
fi

if [ "${1:-}" = "--reveal" ]; then
  exec sh "$DOTFILES/bootstrap/reveal.sh"
fi

# 머신 프로필 — 없으면 전부 설치 (config/dotfiles-profile.example 참조)
PROFILE="$HOME/.config/dotfiles/profile"
if [ -f "$PROFILE" ]; then
  . "$PROFILE"
else
  echo "profile 없음 ($PROFILE) — 전체 설치. 선별하려면 config/dotfiles-profile.example 참조"
fi

skip_step() {
  _name=$1 _short=${1#*-}
  for _s in ${DOTFILES_SKIP_STEPS:-}; do
    if [ "$_s" = "$_name" ] || [ "$_s" = "$_short" ]; then return 0; fi
  done
  return 1
}

for step in "$DOTFILES"/bootstrap/[0-9]*.sh; do
  name=$(basename "$step" .sh)
  if skip_step "$name"; then
    echo "==> $name (skip: profile)"
    continue
  fi
  echo "==> $name"
  sh "$step"
done

echo "==> install.sh"
sh "$DOTFILES/install.sh"

echo ""
echo "colonize complete. restart your shell (or: exec zsh)"
echo "manual next steps:"
echo "  - ~/.zshrc.local / ~/.gitconfig.local 에 시크릿·개인 정보 채우기"
echo "  - claude 첫 실행 후 플러그인 설치: superpowers, claude-hud"
