#!/bin/sh

alias grep='grep --color=auto'
alias tree='eza -T'
alias ls='eza --color=auto --icons=auto --sort=extension --group-directories-first'
alias la='ls -a'
alias laa='ls -Alh'
alias lg='ls -A | grep'
alias lr="ranger "
alias lt="eza --color=auto --sort=newest"
alias dw='cd ~/Downloads/'
alias open='firefox $(fzf) && exit'
alias :w='source ~/.zshrc'
alias :q='exit'
alias cd..='cd ..'
alias aliases='$EDITOR ~/.shell/aliases.sh'
alias wifi="nmcli device wifi connect"
alias printc='for C in {30..37}; do echo -en "\e[${C}m${C} "; done; echo;'
alias ss='sudo pacman -S'
alias es='setxkbmap es'
alias en='~/.config/bspwm/keymaps.sh'
alias hugo='~/.config/bspwm/hugo-keymap.sh'
alias snvim='sudo -E -s nvim' # perserve env
alias make='${COPE}/make'
alias gcc='${COPE}/gcc'
alias xrandr='${COPE}/xrandr'
alias mips='java -Dswing.plaf.metal.controlFont=Consolas-15 -Dswing.plaf.metal.userFont=Consolas-30 -jar ~/Documents/fundcomp/Simula3MSv4_12.jar'
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias qute="qutebrowser &! exit"
alias n=nvim
alias logisim="wmname compiz && logisim-evolution &! exit"
alias c="clear"
alias zzz="systemctl suspend"
alias clock="alacritty -e tty-clock -SDcn &!"
alias bat="bat --theme=1337"
alias usc="firefox cv.usc.es/my/courses.php &! exit"
alias gc="git commit -m"

alias estat="cd ~/Documents/estat/examenes/; ls"
alias e="mdless ~/examenes.md && date \"+ Today is %A %d\""

