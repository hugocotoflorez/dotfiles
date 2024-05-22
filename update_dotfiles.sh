#!/bin/bash

ZSH=".zshrc .zprofile"
CONFIG=".config/yay/  .config/rofi/ .config/bspwm/ .config/picom/ .config/sxhkd/ .config/polybar/ .config/gtk-2.0/ .config/gtk-3.0/  .config/alacritty/alacritty.toml"
CFORMAT=".clang-format"
SHELL=".shell/*"
OTHERS2=".fehbg .gtkrc-2.0"
OTHERS=".bash_profile .xinitrc README.md .screenlayout/* .scripts/* update_dotfiles.sh"
NVIM="nvim/"
FILES="${NVIM} ${ZSH} ${CONFIG} ${CFORMAT} ${OTHERS} ${OTHERS2} ${SHELL}"


case "$1" in
    'f') echo $FILES
    ;;
    'a') git add $FILES
    ;;
    'c') git commit -m "Updating by update_dotfiles"
    ;;
    'p') git push origin main
    ;;
    *)
        git add $FILES
        git commit -m "Update by update_dotfiles"
        git push origin main
    ;;
esac

