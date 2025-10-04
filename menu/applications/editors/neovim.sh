#!/bin/bash
DESCRIPTION="Install Neovim"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Neovim modern text editor"

run() {
    echo "Installing Neovim..."
    
    if command -v nvim &>/dev/null; then
        echo "Neovim is already installed!"
        nvim --version | head -1
    else
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y neovim
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y neovim
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm neovim
        elif command -v brew &>/dev/null; then
            brew install neovim
        else
            echo "Package manager not supported."
            echo "Visit: https://neovim.io/"
            return 1
        fi
        echo "Neovim installed successfully!"
    fi
}