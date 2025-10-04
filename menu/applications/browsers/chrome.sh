#!/bin/bash
DESCRIPTION="Install Google Chrome"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Google Chrome web browser"

run() {
    echo "Installing Google Chrome..."
    
    if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null; then
        echo "Google Chrome is already installed!"
        google-chrome --version 2>/dev/null || google-chrome-stable --version
    else
        if command -v apt &>/dev/null; then
            wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
            sudo apt install -y /tmp/google-chrome.deb
            rm /tmp/google-chrome.deb
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
        elif command -v brew &>/dev/null; then
            brew install --cask google-chrome
        else
            echo "Package manager not supported."
            echo "Download from: https://www.google.com/chrome/"
            return 1
        fi
        echo "Google Chrome installed successfully!"
    fi
}