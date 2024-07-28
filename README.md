# About

Dotfiles from my Arch Linux - Laptop setup! Updated weekly.

# [Hyprland]

<img src="https://raw.githubusercontent.com/hugocotoflorez/dotfiles/main/.img/image1.png" align="center" alt="picture">
<img src="https://raw.githubusercontent.com/hugocotoflorez/dotfiles/main/.img/image2.png" align="center" alt="picture">
<img src="https://raw.githubusercontent.com/hugocotoflorez/dotfiles/main/.img/image3.png" align="center" alt="picture">


# nvim quick setup

clone this repo
```shell
git clone https://github.com/hugocotoflorez/dotfiles
```

create a simlink (nvim folder in .config must not exist)
```shell
ln -s <repo path>/nvim ~/.config/nvim.config/nvim
```

install packer
```shell
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim
```

errors at first start must be ignored and overpassed pressing enter key
then,
`:so`
`:PackerSync`
`:PackerCompile`


# Remaps & languages

 - `caps lock (hold)` -> control
 - `caps lock (tap)` -> escape


### How to set Caps as Esc and Control

Using `caps2esc`, follow this steps:

- Install it (Arch) `pacman -S interception-caps2lock`
- Edit `/etc/interception/udevmon.d/caps2esc.yaml`
- Write this :
``` yaml
- JOB: intercept -g $DEVNODE | caps2esc | uinput -d $DEVNODE
  DEVICE:
    EVENTS:
      EV_KEY: [KEY_CAPSLOCK, KEY_ESC]
```
- Make sure udevmon is enabled and running


### Cursor theme
- Install volantes
- Run `gsettings set org.gnome.desktop.interface cursor-theme 'volantes_cursors'`

