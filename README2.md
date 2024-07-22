# Pictures (hyprland)

<img src="https://raw.githubusercontent.com/hugocotoflorez/dotfiles/main/syspictures/picture1.png" align="center" alt="picture">
<img src="https://raw.githubusercontent.com/hugocotoflorez/dotfiles/main/syspictures/picture2.png" align="center" alt="picture">
<img src="https://raw.githubusercontent.com/hugocotoflorez/dotfiles/main/syspictures/picture3.png" align="center" alt="picture">
<img src="https://raw.githubusercontent.com/hugocotoflorez/dotfiles/main/syspictures/picture4.png" align="center" alt="picture">
<img src="https://raw.githubusercontent.com/hugocotoflorez/dotfiles/main/syspictures/picture5.png" align="center" alt="picture">

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

SF (San Francisco) mono font (not patched with Nerd Font patcher)

### Cursor theme
- Install volantes
- Run `gsettings set org.gnome.desktop.interface cursor-theme 'volantes_cursors'`

