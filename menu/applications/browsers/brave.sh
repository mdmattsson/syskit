#!/bin/bash
DESCRIPTION="Install Brave Browser"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Brave privacy-focused web browser"

run() {
    echo "Installing Brave Browser..."
    
    if command -v brave-browser &>/dev/null; then
        echo "Brave is already installed!"
        brave-browser --version
    else
        if command -v apt &>/dev/null; then
            sudo apt install -y curl
            sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
            sudo apt update && sudo apt install -y brave-browser
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y dnf-plugins-core
            sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
            sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
            sudo dnf install -y brave-browser
        elif command -v brew &>/dev/null; then
            brew install --cask brave-browser
        else
            echo "Package manager not supported."
            echo "Download from: https://brave.com/download/"
            return 1
        fi
        echo "Brave Browser installed successfully!"
    fi
}