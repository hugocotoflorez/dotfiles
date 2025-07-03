# Installation guide

1. Get an arch iso and start the installer.
2. Set up the wifi if needed.
3. Run `archinstall` and set as this:

| Option | Field | Value |
| :--- | :--- | :--- |
| Mirrors | Select regions | France |
| Disk conf | Your choice |  |
| Root password |  |  |
| User account | Add a user  | password, name, Yes  |
| Profile | Type | Minimal |
| Audio |  | Pipewire |
| Kernels | | I prefer the LTS |
| Network | | NetworkManager |
| Timezone |  | Madrid |
| Additional packages |  | git |

enable multilib

Then press Install, yes, reboot system.

4. Login with your user name and password.
5. `git clone https://github.com/hugocotoflorez/dotfiles`.
6. `cd dotfiles` and `./install.sh`

