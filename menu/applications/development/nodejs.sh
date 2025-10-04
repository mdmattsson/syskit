#!/bin/bash
DESCRIPTION="Install Node.js"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Node.js JavaScript runtime"

run() {
    echo "Installing Node.js..."
    
    if command -v node &>/dev/null; then
        echo "Node.js is already installed!"
        node --version
        npm --version
    else
        if command -v apt &>/dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt install -y nodejs
        elif command -v dnf &>/dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
            sudo dnf install -y nodejs
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm nodejs npm
        elif command -v brew &>/dev/null; then
            brew install node
        else
            echo "Package manager not supported."
            echo "Download from: https://nodejs.org/"
            return 1
        fi
        echo "Node.js installed successfully!"
        node --version
        npm --version
    fi
}