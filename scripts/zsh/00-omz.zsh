# oh-my-zsh + powerlevel10k. 로더가 알파벳순으로 읽으므로 00- 프리픽스로 최우선 로드.

# p10k instant prompt — 콘솔 입력이 필요한 초기화는 이보다 위에 와야 한다
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*:default' menu select=2

plugins=(
  git
  fzf
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
)

autoload -Uz compinit
compinit
source "$ZSH/oh-my-zsh.sh"

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
