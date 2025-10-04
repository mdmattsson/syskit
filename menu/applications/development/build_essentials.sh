#!/bin/bash
DESCRIPTION="Install Build Tools"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install essential build tools (gcc, make, etc.)"

run() {
    echo "Installing build essentials..."
    
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y build-essential
        echo "Installed: gcc, g++, make, and other build tools"
    elif command -v dnf &>/dev/null; then
        sudo dnf groupinstall -y "Development Tools"
        echo "Installed Development Tools group"
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm base-devel
        echo "Installed base-devel group"
    elif command -v brew &>/dev/null; then
        xcode-select --install
        echo "Installing Xcode Command Line Tools..."
        echo "Follow the prompts to complete installation."
    else
        echo "Package manager not supported."
        return 1
    fi
    
    echo ""
    echo "Build tools installed successfully!"
    gcc --version 2>/dev/null | head -1
    make --version 2>/dev/null | head -1
}