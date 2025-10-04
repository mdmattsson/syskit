#!/bin/bash
DESCRIPTION="Install Docker"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Install Docker container platform"

run() {
    echo "Installing Docker..."
    
    if command -v docker &>/dev/null; then
        echo "Docker is already installed!"
        docker --version
    else
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "Installing Docker using official script..."
            curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
            sudo sh /tmp/get-docker.sh
            rm /tmp/get-docker.sh
            
            echo "Adding current user to docker group..."
            sudo usermod -aG docker $USER
            
            echo ""
            echo "Docker installed successfully!"
            echo "IMPORTANT: Log out and back in for group changes to take effect."
        elif command -v brew &>/dev/null; then
            brew install --cask docker
            echo "Docker Desktop installed. Please start it from Applications."
        else
            echo "Automatic installation not supported."
            echo "Visit: https://docs.docker.com/get-docker/"
            return 1
        fi
    fi
}