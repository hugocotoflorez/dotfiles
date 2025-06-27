#!/bin/bash

exist() { command -v "$1" >/dev/null 2>&1; }

if ! exist yay; then
        sudo pacman -S --needed git base-devel
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si
fi

sudo ./sysupdate.sh

yay -S --noconfirm --needed `cat ./installed-packages.txt`

./deploy.sh ./MANIFEST
sudo ./deploy.sh ./MANIFEST

function clone_install() {
        if ! exist "$1" && ! [ -d "$1" ]; then
                git clone "https://github.com/hugocotoflorez/$1"
                cd "$1"
                make install
                cd ..
                rm -rf "$1"
        fi
}

# TODO: check that this work
clone_install tetris
clone_install hfetch

