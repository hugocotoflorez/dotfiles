[[ -f ~/.zshrc ]] && . ~/.zshrc

mkdir -p /tmp/Downloads
ln -sf /tmp/Downloads -t ~/.

if [[ -n "$SSH_CONNECTION" ]]; then
    return

elif [ -z "$DISPLAY" ]; then
    ~/dotfiles/colorize-tty.sh # change tty colors
    clear
fi


