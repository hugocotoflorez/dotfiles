#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "$BASH_SOURCE[0]" )" && pwd )"

exist() { command -v "$1" >/dev/null 2>&1; }

function clone_install() {
        if [ -d "$1" ]; then
                rm -rf "$1"
        fi
        if ! exist "$1"; then
                git clone "https://github.com/hugocotoflorez/$1"
                cd "$1"
                make install
                echo "$1" >> .gitignore
        fi
        cd $SCRIPT_DIR
}

if ! exist yay; then
        sudo pacman -S --needed git base-devel
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si
fi

sudo mkdir -p /etc/keyd
sudo ln -sf $SCRIPT_DIR/default.conf /etc/keyd/default.conf
sudo ln -sf $SCRIPT_DIR/pacman.conf /etc/pacman.conf

cd $SCRIPT_DIR
git submodule update --init nvim
sudo pacman -Syyu --noconfirm

rm ~/.* -rf

mkdir -p ~/.config
mkdir -p ~/.local
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/applications

cd $SCRIPT_DIR
./deploy.sh MANIFEST

cd $SCRIPT_DIR
clone_install tetris
clone_install todo
clone_install hfetch

cd $SCRIPT_DIR
yay -S --needed --noconfirm `cat ./installed-packages.txt`

firefox --headless && sleep 5 && pkill firefox

firefox_path=$(grep -E 'Path=.*default-release' ~/.mozilla/firefox/profiles.ini | tail -n1 | cut -d= -f2)
if [ -z "$firefox_path" ]; then
        firefox_full_path="$HOME/.mozilla/firefox/$firefox_path"
        mkdir -p "$firefox_full_path/chrome"
        ln -s "$SCRIPT_DIR/userContent.css" "$firefox_full_path/chrome/userContent.css"
        ln -s "$SCRIPT_DIR/userChrome.css" "$firefox_full_path/chrome/userChrome.css"
fi

chsh -s $(which zsh)
systemctl enable ly
