
[[ -f ~/.zshrc ]] && . ~/.zshrc

if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
    exec startx 2>/dev/null
fi




