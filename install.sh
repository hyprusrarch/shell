#!/bin/bash
cd ~
confirm() {
    while true; do
        read -p "$1 (y/n): " choice
        case "$choice" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
        esac
    done
}

if confirm "Do you want to proceed with the installation?"; then
    echo "Proceeding..."

    if ! command -v yay &> /dev/null; then
        echo "yay not found. Installing yay..."
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
    fi

    sudo pacman -S --needed --noconfirm quickshell hypridle hyprlock foot cava \
    cowsay fortune-mod papirus-icon-theme fastfetch nautilus mpv \
    gpu-screen-recorder hyprshot wtype hyprland flatpak \
    hyprpolkitagent wl-clipboard cliphist cloudflare-warp-bin btop ttf-cascadia-code-nerd noto-fonts-emoji noto-fonts ttf-jetbrains-mono-nerd ttf-jetbrains-mono nwg-look awww

    yay -S --noconfirm matugen-bin

    sudo pacman -Rns --noconfirm gnu-free-fonts

    cp -r $HOME/.config youroldconfig
    cp -r $HOME/shell/.config/* $HOME/.config
    cp -r $HOME/shell/.scripts $HOME
    cp -r $HOME/shell/.wallpapers $HOME
    cp -r $HOME/.bashrc $HOME/.bashrc.bak
    cp -r $HOME/.bashrc $HOME
    sudo cp -r $HOME/shell/assets/gojo.cow /usr/share/cowsay/cows
    awww daemon
    awww img $HOME/shell/assets/chick.jpg
    echo "Installation completed, youroldconfig is your old config ;-;, and your old bash will be bashrc.bak"
else
    echo "cancelled by user"
    exit 1
fi
