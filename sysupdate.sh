#!/bin/bash
sudo bash -c "which reflector && reflector -c fr -n 10 > /etc/pacman.d/mirrorlist"
sudo pacman -Syyu
yay

pacman -Qe | cut -d' ' -f1 > installed-packages.txt
echo "System updated! You may want to reboot"
