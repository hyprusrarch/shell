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
        cd yay || exit
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
    fi

    sudo pacman -S --needed --noconfirm quickshell hypridle hyprlock foot cava \
    cowsay fortune-mod papirus-icon-theme fastfetch nautilus mpv \
    gpu-screen-recorder hyprshot wtype hyprland flatpak \
    hyprpolkitagent wl-clipboard cliphist btop ttf-cascadia-code-nerd noto-fonts-emoji noto-fonts ttf-jetbrains-mono-nerd ttf-jetbrains-mono nwg-look awww cloudflare-warp-bin

    yay -S --noconfirm matugen-bin

    sudo pacman -Rns --noconfirm gnu-free-fonts


    mv "$HOME/.config" "$HOME/youroldconfig"
    cp -r "$HOME/shell/.config/" "$HOME/.config"
    cp -r "$HOME/shell/.scripts" "$HOME"
    cp -r "$HOME/shell/.wallpapers" "$HOME"
    mv "$HOME/.bashrc" "$HOME/.bashrc.bak"
    cp "$HOME/shell/assets/.bashrc" "$HOME"

    sudo mkdir -p /usr/share/cowsay/cows
    sudo cp "$HOME/shell/assets/gojo.cow" /usr/share/cowsay/cows/

    awww daemon &
    sleep 1
    awww img "$HOME/shell/assets/chick.jpg"

    echo "Installation completed, youroldconfig is your old config ;-;, and your old bash will be bashrc.bak"
else
    echo "cancelled by user"
    exit 1
fi
