pokemon-colorscripts -r
set fish_greeting 
set -x ANDROID_SDK_ROOT $HOME/Android/Sdk
set -x ANDROID_HOME $HOME/Android/Sdk
set -x PATH $PATH $ANDROID_SDK_ROOT/emulator
set -x PATH $PATH $ANDROID_SDK_ROOT/platform-tools
set -x PATH $PATH $HOME/Android/Sdk/cmdline-tools/latest/bin
set -g fish_color_autosuggestion 999999


zoxide init fish | source
zoxide init fish --cmd cd | source
# alias android='cd ~/Android/Sdk/emulator && QT_QPA_PLATFORM=xcb ./emulator -avd Pixel34 -gpu swiftshader -no-audio -no-snapshot'
alias n='nvim'
alias f='fastfetch'
# alias tetris='vitetris'
# alias speed='librespeed-cli --simple'
alias up='docker-compose up -d'
alias down='docker-compose down'
# alias cmd='kitty'
alias св='cd'
alias swww='bash ~/.config/niri/Script/WalpaperSelect.sh'
alias калькулятор='nasc'
