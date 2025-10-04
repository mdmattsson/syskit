#!/bin/bash
DESCRIPTION="Install LibreOffice"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install LibreOffice office suite"

run() {
    echo "Installing LibreOffice..."
    
    if command -v libreoffice &>/dev/null; then
        echo "LibreOffice is already installed!"
        libreoffice --version
    else
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y libreoffice
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y libreoffice
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm libreoffice-fresh
        elif command -v brew &>/dev/null; then
            brew install --cask libreoffice
        else
            echo "Package manager not supported."
            echo "Download from: https://www.libreoffice.org/"
            return 1
        fi
        echo "LibreOffice installed successfully!"
    fi
}