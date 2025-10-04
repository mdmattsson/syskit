#!/bin/bash
DESCRIPTION="Install Modern CLI Tools"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install modern replacements: ripgrep, fd, bat, tmux, fzf, lazygit"

run() {
    echo "=== Modern CLI Tools Installer ==="
    echo ""
    echo "This will install:"
    echo "  1. ripgrep (rg) - Fast grep alternative"
    echo "  2. fd - Modern find alternative"
    echo "  3. bat - Cat with syntax highlighting"
    echo "  4. tmux - Terminal multiplexer"
    echo "  5. fzf - Fuzzy finder"
    echo "  6. lazygit - Terminal UI for git"
    echo ""
    read -p "Continue? [Y/n]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Nn]$ ]] && return 0
    
    # ripgrep
    echo ""
    echo "--- Installing ripgrep ---"
    if command -v rg &>/dev/null; then
        echo "Already installed: $(rg --version | head -1)"
    else
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y ripgrep
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y ripgrep
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm ripgrep
        elif command -v brew &>/dev/null; then
            brew install ripgrep
        fi
        echo "Installed: $(rg --version | head -1)"
    fi
    
    # fd
    echo ""
    echo "--- Installing fd ---"
    if command -v fd &>/dev/null || command -v fdfind &>/dev/null; then
        echo "Already installed: $(fd --version 2>/dev/null || fdfind --version)"
    else
        if command -v apt &>/dev/null; then
            sudo apt install -y fd-find
            echo "Installed (use 'fdfind' command)"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y fd-find
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm fd
        elif command -v brew &>/dev/null; then
            brew install fd
        fi
        echo "Installed: $(fd --version 2>/dev/null || fdfind --version)"
    fi
    
    # bat
    echo ""
    echo "--- Installing bat ---"
    if command -v bat &>/dev/null || command -v batcat &>/dev/null; then
        echo "Already installed: $(bat --version 2>/dev/null || batcat --version)"
    else
        if command -v apt &>/dev/null; then
            sudo apt install -y bat
            echo "Installed (use 'batcat' command)"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y bat
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm bat
        elif command -v brew &>/dev/null; then
            brew install bat
        fi
        echo "Installed: $(bat --version 2>/dev/null || batcat --version)"
    fi
    
    # tmux
    echo ""
    echo "--- Installing tmux ---"
    if command -v tmux &>/dev/null; then
        echo "Already installed: $(tmux -V)"
    else
        if command -v apt &>/dev/null; then
            sudo apt install -y tmux
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y tmux
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm tmux
        elif command -v brew &>/dev/null; then
            brew install tmux
        fi
        echo "Installed: $(tmux -V)"
    fi
    
    # fzf
    echo ""
    echo "--- Installing fzf ---"
    if command -v fzf &>/dev/null; then
        echo "Already installed: $(fzf --version)"
    else
        if command -v apt &>/dev/null; then
            sudo apt install -y fzf
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y fzf
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm fzf
        elif command -v brew &>/dev/null; then
            brew install fzf
            $(brew --prefix)/opt/fzf/install --all
        else
            git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
            ~/.fzf/install --all
        fi
        echo "Installed: $(fzf --version)"
    fi
    
    # lazygit
    echo ""
    echo "--- Installing lazygit ---"
    if command -v lazygit &>/dev/null; then
        echo "Already installed: $(lazygit --version)"
    else
        if command -v apt &>/dev/null; then
            LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
            curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
            tar xf /tmp/lazygit.tar.gz -C /tmp/
            sudo install /tmp/lazygit /usr/local/bin
            rm /tmp/lazygit /tmp/lazygit.tar.gz
        elif command -v dnf &>/dev/null; then
            sudo dnf copr enable atim/lazygit -y
            sudo dnf install -y lazygit
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm lazygit
        elif command -v brew &>/dev/null; then
            brew install lazygit
        fi
        echo "Installed: $(lazygit --version)"
    fi
    
    echo ""
    echo "=== Modern CLI Tools Installation Complete ==="
    echo ""
    echo "Usage tips:"
    echo "  rg 'pattern'           # Fast code search"
    echo "  fd 'filename'          # Fast file find"
    echo "  bat file.txt           # View with syntax highlighting"
    echo "  tmux                   # Start terminal multiplexer"
    echo "  Ctrl-R                 # fzf history search"
    echo "  lazygit                # Git UI in terminal"
}