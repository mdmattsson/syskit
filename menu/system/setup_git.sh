#!/bin/bash

DESCRIPTION="Configure Git"
DESTRUCTIVE=false              # Triggers confirmation
DEPENDENCIES=("git")           # Required commands ex: ("cmd1" "cmd2")
LONG_DESCRIPTION="Configure Git"


run() {
    echo -e "\n${PURPLE}Git Configuration Setup${RESET}"

    if ! command -v git &> /dev/null; then
        echo "Git is not installed. Please install git first."
        echo "Press any key to continue..."
        read -n 1
        return
    fi

    echo "Current Git configuration:"
    git config --global --list | grep -E "(user.name|user.email)" || echo "No user configuration found"

    echo -e "\nEnter your Git configuration:"
    read -p "Name: " git_name
    read -p "Email: " git_email

    if [[ -n "$git_name" && -n "$git_email" ]]; then
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        echo -e "\n${GREEN}Git configuration updated!${RESET}"
    else
        echo -e "\n${RED}Configuration cancelled.${RESET}"
    fi
}
