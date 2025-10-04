#!/bin/bash
DESCRIPTION="Install C++ Development Tools"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install C++ debugging and profiling tools: GDB, Valgrind, ccache"

run() {
    echo "=== C++ Development Tools Installer ==="
    echo ""
    echo "This will install:"
    echo "  1. GDB - GNU Debugger"
    echo "  2. Valgrind - Memory debugging and profiling"
    echo "  3. ccache - Compiler cache for faster rebuilds"
    echo ""
    read -p "Continue? [Y/n]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Nn]$ ]] && return 0
    
    # GDB
    echo ""
    echo "--- Installing GDB ---"
    if command -v gdb &>/dev/null; then
        echo "Already installed: $(gdb --version | head -1)"
    else
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y gdb
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y gdb
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm gdb
        elif command -v brew &>/dev/null; then
            brew install gdb
        fi
        echo "Installed: $(gdb --version | head -1)"
    fi
    
    # Valgrind
    echo ""
    echo "--- Installing Valgrind ---"
    if command -v valgrind &>/dev/null; then
        echo "Already installed: $(valgrind --version)"
    else
        if command -v apt &>/dev/null; then
            sudo apt install -y valgrind
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y valgrind
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm valgrind
        elif command -v brew &>/dev/null; then
            brew install valgrind
        fi
        echo "Installed: $(valgrind --version)"
    fi
    
    # ccache
    echo ""
    echo "--- Installing ccache ---"
    if command -v ccache &>/dev/null; then
        echo "Already installed: $(ccache --version | head -1)"
    else
        if command -v apt &>/dev/null; then
            sudo apt install -y ccache
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y ccache
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm ccache
        elif command -v brew &>/dev/null; then
            brew install ccache
        fi
        echo "Installed: $(ccache --version | head -1)"
    fi
    
    echo ""
    echo "=== C++ Development Tools Installation Complete ==="
    echo ""
    echo "Usage tips:"
    echo "  GDB: gdb ./your_program"
    echo "  Valgrind: valgrind --leak-check=full ./your_program"
    echo "  ccache: export CMAKE_CXX_COMPILER_LAUNCHER=ccache"
}