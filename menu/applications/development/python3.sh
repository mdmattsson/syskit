#!/bin/bash
DESCRIPTION="Install Python 3"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Python 3 programming language"

run() {
    echo "Installing Python 3..."
    
    if command -v python3 &>/dev/null; then
        echo "Python 3 is already installed!"
        python3 --version
    else
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y python3 python3-pip python3-venv
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y python3 python3-pip
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm python python-pip
        elif command -v brew &>/dev/null; then
            brew install python
        else
            echo "Package manager not supported."
            echo "Download from: https://www.python.org/"
            return 1
        fi
        echo "Python 3 installed successfully!"
        python3 --version
        pip3 --version
    fi
}