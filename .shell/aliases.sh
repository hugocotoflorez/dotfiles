#!/bin/zsh
# apply color schemes
alias grep='grep --color=auto'
alias pacman='pacman --color=auto'
alias yay='yay --color=auto'
alias bat="bat --theme=OneHalfDark"
alias printc='for C in {30..37}; do echo -en "\e[${C}m${C} "; done; echo;'

# eza (ls with icons) and ls
alias tree='eza -T'
alias ls='ls --color=auto -X'
alias la='ls -A'
alias laa='ls -Alh'
alias lg='ls -A | grep'

# cd
alias cd..='cd ..' # best remap ever created
alias dw='cd ~/Downloads/'
alias ..='cd ..'
alias ....='cd ../..'
alias ......='cd ../../..'

# app launchers
alias open='firefox $(fzf) &! exit'
# alias logisim="wmname compiz && logisim-evolution &! exit" # bspwm error solved
alias logisim="logisim-evolution &! exit"
alias snvim='sudo -E -s nvim' # perserve env (colors and this stuff)
alias clock="kitty -e tty-clock -SDcn &!"
alias mips='java -Dswing.plaf.metal.controlFont=Consolas-15 -Dswing.plaf.metal.userFont=Consolas-30 -jar ~/Documents/fundcomp/Simula3MSv4_12.jar'
alias ss='sudo pacman -S'
alias zzz="systemctl suspend"

# tools launchers
alias bluetooth="~/.config/wofi/bluetooth.sh"

# shorteners
alias gp="git push"
alias ga="git add ."
alias wifi="nmcli device wifi connect" # wifi <tab>
alias icat="kitten icat"
alias ffind='find -type f -name'
alias za='zathura --fork '
alias so='source ~/.zshrc'
alias q='exit' # i use vim btw
alias py=python3
alias vim=nvim

# others
alias aliases='$EDITOR ~/.shell/aliases.sh'
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'

alias dveaber="GDK_BACKEND=x11 dbeaver"
alias dbeaber="GDK_BACKEND=x11 dbeaver"
alias dbeaver="GDK_BACKEND=x11 dbeaver"

alias snus='sudo ~/.local/bin/snx -s secure.cesga.es -u cursoc52'
alias snusd='sudo ~/.local/bin/snx -d'
alias cesga='TERM=xterm ssh cursoc52@ft3.cesga.es'

