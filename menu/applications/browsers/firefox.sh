#!/bin/bash
DESCRIPTION="Install Firefox"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Mozilla Firefox web browser"

run() {
    echo "Installing Firefox..."
    
    if command -v firefox &>/dev/null; then
        echo "Firefox is already installed!"
        firefox --version
    else
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y firefox
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y firefox
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm firefox
        elif command -v brew &>/dev/null; then
            brew install --cask firefox
        else
            echo "Package manager not supported. Please install Firefox manually."
            return 1
        fi
        echo "Firefox installed successfully!"
    fi
}