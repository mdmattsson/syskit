#!/bin/bash
DESCRIPTION="Install Git"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Git version control system"

run() {
    echo "Installing Git..."
    
    if command -v git &>/dev/null; then
        echo "Git is already installed!"
        git --version
    else
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y git
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y git
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm git
        elif command -v brew &>/dev/null; then
            brew install git
        else
            echo "Package manager not supported."
            return 1
        fi
        echo "Git installed successfully!"
        echo ""
        echo "Configure git with:"
        echo "  git config --global user.name 'Your Name'"
        echo "  git config --global user.email 'your@email.com'"
    fi
}