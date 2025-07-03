#!/bin/bash

exist() { command -v "$1" >/dev/null 2>&1; }

if ! exist yay; then
        sudo pacman -S --needed git base-devel
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si
fi

git submodule update --init nvim
sudo ./sysupdate.sh

yay -S --noconfirm --needed `cat ./installed-packages.txt`

rm ~/.config -rf
mkdir ~/.config

sudo pacman -S git

./deploy.sh ./MANIFEST
sudo ./deploy.sh ./MANIFEST

function clone_install() {
        if [ -d "$1" ]; then
                rm -rf "$1"
        fi
        if ! exist "$1"; then
                git clone "https://github.com/hugocotoflorez/$1"
                cd "$1"
                make install
                cd ..
        fi
}

mkdir -p .local/bin

clone_install tetris
clone_install todo
clone_install hfetch

