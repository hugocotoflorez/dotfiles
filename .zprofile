[[ -f ~/.zshrc ]] && . ~/.zshrc

if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
    exec Hyprland
elif [ -z "$DISPLAY" ]; then
    ~/dotfiles/colorize-tty.sh # change tty colors
    clear
fi


