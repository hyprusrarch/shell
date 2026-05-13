# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

fastfetch
alias cowsay='fortune | cowsay -f $(ls /usr/share/cowsay/cows/ | shuf -n1)'
alias bashconf='nano ~/.bashrc'
alias hyprconf='nano ~/.config/hypr/hyprland.conf'
alias grubconf='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias matrix='unimatrix -n -s 96 -l o'
alias i='sudo pacman -Syu'
alias r='sudo pacman -Rns'
alias y='yay -S'
alias f='flatpak install'
export PATH="$PATH: ~/.local/bin"

export WINETRICKS_USE_ARIA2=1
export ARIA2_OPTS="--max-connection-per-server=16 --min-split-size=1M --split=16 --timeout=5"

export WINETRICKS_DOWNLOAD_LIB=curl

export MOZ_ENABLE_WAYLAND=1
export MALLOC_ARENA_MAX=2
export PATH="$HOME/.local/bin:$PATH"
