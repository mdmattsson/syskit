#!/bin/bash
DESCRIPTION="Install Vim"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Vim text editor"

run() {
    echo "Installing Vim..."
    
    if command -v vim &>/dev/null; then
        echo "Vim is already installed!"
        vim --version | head -1
    else
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y vim
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y vim-enhanced
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm vim
        elif command -v brew &>/dev/null; then
            brew install vim
        else
            echo "Package manager not supported."
            return 1
        fi
        echo "Vim installed successfully!"
    fi
}