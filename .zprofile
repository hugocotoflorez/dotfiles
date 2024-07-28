[[ -f ~/.zshrc ]] && . ~/.zshrc

elif [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
    exec Hyprland
fi


