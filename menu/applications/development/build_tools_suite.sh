#!/bin/bash
DESCRIPTION="Install Build Tools Suite"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install essential build tools: CMake, Ninja, Clang/LLVM, and compiler toolchains"

run() {
    echo "=== Build Tools Suite Installer ==="
    echo ""
    echo "This will install:"
    echo "  1. CMake - Build system generator"
    echo "  2. Ninja - Fast build system"
    echo "  3. Clang/LLVM - Modern C/C++ compiler"
    echo "  4. Build essentials (gcc, g++, make)"
    echo ""
    read -p "Continue? [Y/n]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Nn]$ ]] && return 0
    
    # CMake
    echo ""
    echo "--- Installing CMake ---"
    if command -v cmake &>/dev/null; then
        echo "Already installed: $(cmake --version | head -1)"
    else
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y cmake
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y cmake
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm cmake
        elif command -v brew &>/dev/null; then
            brew install cmake
        fi
        echo "Installed: $(cmake --version | head -1)"
    fi
    
    # Ninja
    echo ""
    echo "--- Installing Ninja ---"
    if command -v ninja &>/dev/null; then
        echo "Already installed: Ninja $(ninja --version)"
    else
        if command -v apt &>/dev/null; then
            sudo apt install -y ninja-build
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y ninja-build
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm ninja
        elif command -v brew &>/dev/null; then
            brew install ninja
        fi
        echo "Installed: Ninja $(ninja --version)"
    fi
    
    # Clang/LLVM
    echo ""
    echo "--- Installing Clang/LLVM ---"
    if command -v clang &>/dev/null; then
        echo "Already installed: $(clang --version | head -1)"
    else
        if command -v apt &>/dev/null; then
            sudo apt install -y clang lldb lld
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y clang lldb compiler-rt
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm clang lldb lld
        elif command -v brew &>/dev/null; then
            brew install llvm
        fi
        echo "Installed: $(clang --version | head -1)"
    fi
    
    # Build Essentials
    echo ""
    echo "--- Installing Build Essentials ---"
    if command -v gcc &>/dev/null; then
        echo "Already installed: $(gcc --version | head -1)"
    else
        if command -v apt &>/dev/null; then
            sudo apt install -y build-essential
        elif command -v dnf &>/dev/null; then
            sudo dnf groupinstall -y "Development Tools"
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm base-devel
        elif command -v brew &>/dev/null; then
            xcode-select --install
        fi
        echo "Installed: $(gcc --version | head -1)"
    fi
    
    echo ""
    echo "=== Build Tools Suite Installation Complete ==="
    echo ""
    echo "Installed tools:"
    echo "  cmake: $(cmake --version 2>/dev/null | head -1 || echo 'not found')"
    echo "  ninja: $(ninja --version 2>/dev/null || echo 'not found')"
    echo "  clang: $(clang --version 2>/dev/null | head -1 || echo 'not found')"
    echo "  gcc: $(gcc --version 2>/dev/null | head -1 || echo 'not found')"
}