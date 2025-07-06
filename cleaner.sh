#!/bin/sh

yay -Sc # uninstalled packages cache
yay -Scc # installed packages cache
rm -rf ~/.cache/* # remove cache in home
yay -Rns $(yay -Qtdq) # remove unused packages
rmlint /home/hugo # remove duplicates
echo "rmlint.sh generated"

