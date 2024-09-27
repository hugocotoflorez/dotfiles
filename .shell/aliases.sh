#!/bin/zsh
# apply color schemes
alias grep='grep --color=auto'
alias bat="bat --theme=OneHalfDark"
alias printc='for C in {30..37}; do echo -en "\e[${C}m${C} "; done; echo;'

# eza (ls with colors), ls and ranger (cli file explorer)
alias tree='eza -T'
alias ls='eza --color=auto --icons=auto --sort=extension --group-directories-first'
alias la='ls -a'
alias laa='ls -Alh'
alias lg='ls -A | grep'
alias lt="eza --color=auto --sort=newest"
alias lr="ranger"

# cd
alias cd..='cd ..' # best remap ever created
alias dw='cd ~/Downloads/'
alias :w='source ~/.zshrc'
alias :q='exit' # i use vim btw
alias ..='cd ..'
alias ....='cd ../..'
alias ......='cd ../../..'

# app launchers
alias open='firefox $(fzf) && exit'
# alias logisim="wmname compiz && logisim-evolution &! exit" # bspwm error solved
alias logisim="logisim-evolution &! exit"
alias snvim='sudo -E -s nvim' # perserve env (colors and this stuff)
alias clock="alacritty -e tty-clock -SDcn &!"
alias mips='java -Dswing.plaf.metal.controlFont=Consolas-15 -Dswing.plaf.metal.userFont=Consolas-30 -jar ~/Documents/fundcomp/Simula3MSv4_12.jar'
alias ss='sudo pacman -S'
alias zzz="systemctl suspend"

# tools launchers
alias bluetooth="~/.config/wofi/bluetooth.sh"
alias batt="~/.scripts/battery.sh"
alias fetch="~/code/hfetch/hfetch &!"
alias bar="~/code/bar/hbar"

# shorteners
alias n=nvim
alias sn='sudo -E -s nvim' # perserve env (colors and this stuff)
alias c="clear"
alias gp="git push"
alias wifi="nmcli device wifi connect" # wifi <tab>
alias icat="kitten icat"
alias note='nvim -c "ObsidianSearch"'

# others
alias aliases='$EDITOR ~/.shell/aliases.sh'
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias usc="firefox cv.usc.es/my/courses.php &! exit"

