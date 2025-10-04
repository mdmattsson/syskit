#!/bin/bash
DESCRIPTION="Install Thunderbird"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Mozilla Thunderbird email client"

run() {
    echo "Installing Thunderbird..."
    
    if command -v thunderbird &>/dev/null; then
        echo "Thunderbird is already installed!"
        thunderbird --version
    else
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y thunderbird
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y thunderbird
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm thunderbird
        elif command -v brew &>/dev/null; then
            brew install --cask thunderbird
        else
            echo "Package manager not supported."
            echo "Download from: https://www.thunderbird.net/"
            return 1
        fi
        echo "Thunderbird installed successfully!"
    fi
}