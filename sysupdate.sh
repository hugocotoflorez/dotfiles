#!/bin/bash
sudo bash -c "reflector > /etc/pacman.d/mirrorlist"
sudo pacman -Syyu
yay
echo "System updated! You should reboot"
