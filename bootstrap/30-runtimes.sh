#!/bin/sh
# jenv는 Brewfile 담당. nvm은 공식 인스톨러가 zshrc를 수정하므로 git clone 방식.
set -eu
[ -d "$HOME/.nvm" ] || git clone --depth=1 https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
[ -d "$HOME/.cargo" ] || \
  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path
echo "runtimes: ok"
