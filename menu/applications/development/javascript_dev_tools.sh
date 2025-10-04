#!/bin/bash
DESCRIPTION="Install JavaScript Development Tools"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Node.js ecosystem tools: Yarn, pnpm, NVM, TypeScript, ESLint"

run() {
    echo "=== JavaScript Development Tools Installer ==="
    echo ""
    echo "This will install:"
    echo "  1. Yarn - Alternative package manager"
    echo "  2. pnpm - Fast, disk-efficient package manager"
    echo "  3. NVM - Node Version Manager"
    echo "  4. TypeScript - TypeScript compiler"
    echo "  5. ESLint - JavaScript linter"
    echo ""
    read -p "Continue? [Y/n]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Nn]$ ]] && return 0
    
    # Check for Node.js
    if ! command -v node &>/dev/null && ! command -v npm &>/dev/null; then
        echo "WARNING: Node.js/npm not found. Install Node.js first."
        echo "Some tools will be skipped."
        echo ""
    fi
    
    # Yarn
    echo ""
    echo "--- Installing Yarn ---"
    if command -v yarn &>/dev/null; then
        echo "Already installed: Yarn $(yarn --version)"
    else
        if command -v npm &>/dev/null; then
            sudo npm install -g yarn
            echo "Installed: Yarn $(yarn --version)"
        elif command -v brew &>/dev/null; then
            brew install yarn
            echo "Installed: Yarn $(yarn --version)"
        else
            echo "Skipped: npm or Homebrew required"
        fi
    fi
    
    # pnpm
    echo ""
    echo "--- Installing pnpm ---"
    if command -v pnpm &>/dev/null; then
        echo "Already installed: pnpm $(pnpm --version)"
    else
        if command -v npm &>/dev/null; then
            curl -fsSL https://get.pnpm.io/install.sh | sh -
            echo "Installed: pnpm (restart shell to use)"
        elif command -v brew &>/dev/null; then
            brew install pnpm
            echo "Installed: pnpm $(pnpm --version)"
        else
            echo "Skipped: npm or Homebrew required"
        fi
    fi
    
    # NVM
    echo ""
    echo "--- Installing NVM ---"
    if [[ -d "$HOME/.nvm" ]]; then
        echo "Already installed: NVM"
    else
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        echo "Installed: NVM (restart shell to use)"
    fi
    
    # TypeScript
    echo ""
    echo "--- Installing TypeScript ---"
    if command -v tsc &>/dev/null; then
        echo "Already installed: $(tsc --version)"
    else
        if command -v npm &>/dev/null; then
            sudo npm install -g typescript
            echo "Installed: $(tsc --version)"
        else
            echo "Skipped: npm required"
        fi
    fi
    
    # ESLint
    echo ""
    echo "--- Installing ESLint ---"
    if command -v eslint &>/dev/null; then
        echo "Already installed: $(eslint --version)"
    else
        if command -v npm &>/dev/null; then
            sudo npm install -g eslint
            echo "Installed: $(eslint --version)"
        else
            echo "Skipped: npm required"
        fi
    fi
    
    echo ""
    echo "=== JavaScript Development Tools Installation Complete ==="
    echo ""
    echo "Usage tips:"
    echo "  NVM: nvm install node   # Install latest Node.js"
    echo "  NVM: nvm use 18         # Switch to Node 18"
    echo "  ESLint: eslint --init   # Initialize in project"
}