#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "$BASH_SOURCE[0]" )" && pwd )"

function exist() { command -v "$1" >/dev/null 2>&1; }

function clone_install() {
        if [ ! -d "$1" ]; then
                git clone "https://github.com/hugocotoflorez/$1"
        fi
                cd "$1"
                make install
                echo "$1" >> .gitignore
        cd $SCRIPT_DIR
}

# if ! exist yay; then
#         sudo pacman -S --needed git base-devel
#         git clone https://aur.archlinux.org/yay.git
#         cd yay
#         makepkg -si
# fi
#
# sudo mkdir -p /etc/keyd
# sudo mkdir -p /etc/ly
# sudo ln -sf $SCRIPT_DIR/default.conf /etc/keyd/default.conf
# sudo ln -sf $SCRIPT_DIR/pacman.conf /etc/pacman.conf
# sudo ln -sf $SCRIPT_DIR/config.ini /etc/ly/config.ini
#
# cd $SCRIPT_DIR
# [ -d "nvim" ] || git submodule update --init nvim
# sudo pacman -Syyu --noconfirm
#
# # rm ~/.* -rf
#
# mkdir -p ~/.config
# mkdir -p ~/.local
# mkdir -p ~/.local/bin
# mkdir -p ~/.local/share/applications
# mkdir -p /tmp/Downloads/
# ln -sfn /tmp/Downloads/ "$HOME/Downloads"
#
# cd $SCRIPT_DIR
# ./deploy.sh MANIFEST

cd $SCRIPT_DIR
clone_install tetris
clone_install todo
clone_install hfetch
clone_install fl

# cd $SCRIPT_DIR
# yay -S --needed --noconfirm `cat ./installed-packages.txt`

chsh -s "/bin/zsh"
sudo systemctl enable ly
sudo systemctl enable keyd
sudo systemctl start ly
sudo systemctl start keyd

# hyprland &!
