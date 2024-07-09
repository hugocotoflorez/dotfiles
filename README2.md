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

### Font used for ui

SF (San Francisco) mono font pathed with Nerd Font patcher
`https://github.com/epk/SF-Mono-Nerd-Font`

```sh
git clone https://github.com/epk/SF-Mono-Nerd-Font
cd SF-Mono-Nerd-Font
sudo mkdir /usr/share/fonts/SF-Mono-Nerd-Font
sudo cp ./*.otf /usr/share/fonts/SF-Mono-Nerd-Font/
```

### Cursor theme
- Install volantes
- Run `gsettings set org.gnome.desktop.interface cursor-theme 'volantes_cursors'`

