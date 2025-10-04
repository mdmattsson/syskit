#!/bin/bash

DESCRIPTION="Install Docker"
DESTRUCTIVE=false              # Triggers confirmation
DEPENDENCIES=()                # Required commands ex: ("cmd1" "cmd2")
LONG_DESCRIPTION="Install Docker"


run() {
    echo -e "\n${BLUE}Installing Docker...${RESET}"

    if command -v docker &> /dev/null; then
        echo "Docker is already installed!"
        docker --version
    else
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        echo -e "\n${GREEN}Docker installed successfully!${RESET}"
        echo "Please log out and back in for group changes to take effect."
    fi

}
