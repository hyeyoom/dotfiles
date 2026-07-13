alias python=python3
alias pip=pip3
alias cls=clear
alias finhi="cat ~/.zsh_history | fzf | pbcopy"

command -v bat  >/dev/null && alias cat="bat"
command -v nvim >/dev/null && { alias vim="nvim"; alias vi="nvim"; alias vimdiff="nvim -d"; }
command -v task-master >/dev/null && { alias tm="task-master"; alias taskmaster="task-master"; }
