#!/bin/bash

DESCRIPTION="Update System Packages"
DESTRUCTIVE=true              # Triggers confirmation
#DEPENDENCIES=("cmd1" "cmd2")  # Required commands
LONG_DESCRIPTION="Update Linux Distro packages"



run() {
    echo -e "\n${YELLOW}Updating system packages...${RESET}"

    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt upgrade -y
    elif command -v yum &> /dev/null; then
        sudo yum update -y
    elif command -v pacman &> /dev/null; then
        sudo pacman -Syu
    elif command -v brew &> /dev/null; then
        brew update && brew upgrade
    else
        echo "Package manager not found or not supported."
    fi

    echo -e "\n${GREEN}Update completed!${RESET}"
}
