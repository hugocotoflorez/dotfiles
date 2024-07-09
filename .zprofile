[[ -f ~/.zshrc ]] && . ~/.zshrc


if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 2 ]; then
    exec startx

elif [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
    exec Hyprland
fi


