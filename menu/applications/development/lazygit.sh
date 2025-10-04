#!/bin/bash
DESCRIPTION="Install Lazygit"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Lazygit - simple terminal UI for git commands"

run() {
    echo "Installing Lazygit..."
    
    if command -v lazygit &>/dev/null; then
        echo "Lazygit is already installed!"
        lazygit --version
    else
        if command -v apt &>/dev/null; then
            # Ubuntu/Debian
            LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
            curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
            tar xf /tmp/lazygit.tar.gz -C /tmp/
            sudo install /tmp/lazygit /usr/local/bin
            rm /tmp/lazygit /tmp/lazygit.tar.gz
        elif command -v dnf &>/dev/null; then
            # Fedora
            sudo dnf copr enable atim/lazygit -y
            sudo dnf install -y lazygit
        elif command -v pacman &>/dev/null; then
            # Arch Linux
            sudo pacman -S --noconfirm lazygit
        elif command -v brew &>/dev/null; then
            # macOS
            brew install lazygit
        else
            echo "Attempting manual installation from GitHub..."
            LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
            curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
            tar xf /tmp/lazygit.tar.gz -C /tmp/
            sudo install /tmp/lazygit /usr/local/bin
            rm /tmp/lazygit /tmp/lazygit.tar.gz
        fi
        
        echo ""
        echo "Lazygit installed successfully!"
        lazygit --version
        echo ""
        echo "Run 'lazygit' in any git repository to use it"
    fi
}