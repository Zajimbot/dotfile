pokemon-colorscripts -r
set fish_greeting 
set -x ANDROID_SDK_ROOT $HOME/Android/Sdk
set -x ANDROID_HOME $HOME/Android/Sdk
set -x PATH $PATH $ANDROID_SDK_ROOT/emulator
set -x PATH $PATH $ANDROID_SDK_ROOT/platform-tools
set -x PATH $PATH $HOME/Android/Sdk/cmdline-tools/latest/bin

zoxide init fish | source
zoxide init fish --cmd cd | source
alias n='nvim'
alias f='fastfetch'
alias up='docker-compose up -d'
alias down='docker-compose down'
alias св='cd'
