command -v nvim >/dev/null && export EDITOR="$(command -v nvim)"

[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

if [ -d "$HOME/.jenv" ] || command -v jenv >/dev/null; then
  export PATH="$HOME/.jenv/bin:$PATH"
  eval "$(jenv init -)"
fi
_jdk=/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home
[ -d "$_jdk" ] && { export JAVA_HOME="$_jdk"; export PATH="$PATH:$JAVA_HOME/bin"; }
unset _jdk

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

if [ -d "$HOME/Library/Android/sdk" ]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"
fi

export BUN_INSTALL="$HOME/.bun"
[ -d "$BUN_INSTALL/bin" ] && export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

[ -d "$HOME/.bin" ] && export PATH="$PATH:$HOME/.bin"
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
[ -d "$HOME/.antigravity/antigravity/bin" ] && export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
[ -d /opt/homebrew/opt/qemu/bin ] && export PATH="$PATH:/opt/homebrew/opt/qemu/bin"

[[ -f "$HOME/.dart-cli-completion/zsh-config.zsh" ]] && . "$HOME/.dart-cli-completion/zsh-config.zsh" || true

export GPG_TTY=$(tty)
