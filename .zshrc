# PROMPT=$'%{\e[0;37m%}%B┌─[%b%{\e[1;32m%}%n%{\e[1;34m%}@%{\e[1;32m%}%m%{\e[0;37m%}%B]%b%{\e[0m%} - %b%{\e[0;37m%}%B[%b%{\e[1;34m%}%~%{\e[0;37m%}%B]%b%{\e[0m%}%{\e[0;37m%}%b %{\e[0;37m%}%B\n└──%B[%{\e[1;34m%}%#%{\e[0;37m%}%B]%{\e[0m%}%b '
PROMPT=$'%{\e[1;90m%}%~%{\e[0m%} '


# custom config
source ~/.shell/aliases.sh
source ~/.shell/functions.sh
source ~/.shell/export.sh
source ~/.shell/options.sh

# if [[ "$XDG_SESSION_TYPE" != "tty" ]]; then
#     source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# fi

todo -week -quiet
