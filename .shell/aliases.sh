#!/bin/bash

# apply color schemes
alias grep='grep --color=auto'
alias bat="bat --theme=1337"
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

# cope (colorized tools)
alias make='${COPE}/make'
alias gcc='${COPE}/gcc'
alias xrandr='${COPE}/xrandr'

# keyboard layouts (x11, bspwm)
alias es='setxkbmap es'
alias en='~/.config/bspwm/keymaps.sh'

# app launchers
alias open='firefox $(fzf) && exit'
alias logisim="wmname compiz && logisim-evolution &! exit" # bspwm error solved
alias snvim='sudo -E -s nvim' # perserve env
alias clock="alacritty -e tty-clock -SDcn &!"
alias macc="alacritty --hold --command=\"macchina\" &!"
alias mips='java -Dswing.plaf.metal.controlFont=Consolas-15 -Dswing.plaf.metal.userFont=Consolas-30 -jar ~/Documents/fundcomp/Simula3MSv4_12.jar'
alias ss='sudo pacman -S'
alias zzz="systemctl suspend"

# tools launchers
alias bluetooth="~/.config/wofi/bluetooth.sh"
alias batt="~/.scripts/battery.sh"
alias fetch="alacritty --hold -e ~/code/hfetch/hfetch &!"

# shorteners
alias n=nvim
alias c="clear"
alias gc="git commit -m"
alias wifi="nmcli device wifi connect" # wifi <tab>

# others
alias aliases='$EDITOR ~/.shell/aliases.sh'
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias usc="firefox cv.usc.es/my/courses.php &! exit"

