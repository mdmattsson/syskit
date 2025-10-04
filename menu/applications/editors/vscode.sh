#!/bin/bash
DESCRIPTION="Install Visual Studio Code"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Microsoft Visual Studio Code editor"

run() {
    echo "Installing Visual Studio Code..."
    
    if command -v code &>/dev/null; then
        echo "VS Code is already installed!"
        code --version
    else
        if command -v apt &>/dev/null; then
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
            sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
            echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
            sudo apt update && sudo apt install -y code
            rm /tmp/packages.microsoft.gpg
        elif command -v dnf &>/dev/null; then
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo
            sudo dnf install -y code
        elif command -v brew &>/dev/null; then
            brew install --cask visual-studio-code
        else
            echo "Package manager not supported."
            echo "Download from: https://code.visualstudio.com/"
            return 1
        fi
        echo "VS Code installed successfully!"
    fi
}