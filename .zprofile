[[ -f ~/.zshrc ]] && . ~/.zshrc

if [[ -n "$SSH_CONNECTION" ]]; then
    return

elif [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 2 ]; then
    return #exec Hyprland

elif [ -z "$DISPLAY" ]; then
    ~/dotfiles/colorize-tty.sh # change tty colors
    clear
fi


