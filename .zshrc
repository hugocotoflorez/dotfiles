PROMPT=$'%{\e[0;37m%}%B┌─[%b%{\e[1;32m%}%n%{\e[1;34m%}@%{\e[1;32m%}%m%{\e[0;37m%}%B]%b%{\e[0m%} - %b%{\e[0;37m%}%B[%b%{\e[1;34m%}%~%{\e[0;37m%}%B]%b%{\e[0m%}%{\e[0;37m%}%b %{\e[0;37m%}%B\n└──%B[%{\e[1;34m%}%#%{\e[0;37m%}%B]%{\e[0m%}%b '

HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory

source ~/.zsh/zsh-vi-mode/zsh-vi-mode.plugin.zsh
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

export ZSH_AUTOSUGGEST_STRATEGY=(completion history)

autoload -U compinit; compinit
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/.zcompcache"
zstyle ':completion:*' menu select
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

export LS_COLORS="*.c=04;32:*.h=04;36"
export LANG=en_US.UTF-8
export EDITOR='nvim'

alias grep='grep --color=auto'
alias ls='ls --color=auto'
alias la='ls -Alhog'
alias lc='ls -Ac'
alias lg='la | grep'
alias dw='cd ~/Downloads/'
alias dc='cd ~/Documents/'
alias open='xdg-open $*'
alias :w='source ~/.zshrc'
alias :q='exit'
alias cd..='cd ..'
alias zshrc='nvim ~/.zshrc'
alias wifi="~/.scripts/wifi.sh $@"
alias printc='for C in {30..37}; do echo -en "\e[${C}m${C} "; done; echo;'
alias make="make $@; make clean"
alias lr="ranger $1"
alias spotify='spotify && exit'
alias code='code && exit'

function command_not_found_handler(){
    echo -e "\e[31m$1??"
}

function search(){
    firefox --search "$*" &
}


