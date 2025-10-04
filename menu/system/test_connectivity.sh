#!/bin/bash

DESCRIPTION="Test Internet Connectivity"
DESTRUCTIVE=false              # Triggers confirmation
DEPENDENCIES=()                # Required commands ex: ("cmd1" "cmd2")
LONG_DESCRIPTION="Test Internet Connectivity"


run() {
    echo -e "\n${YELLOW}Testing connectivity...${RESET}"

    test_sites=("google.com" "github.com" "8.8.8.8")

    for site in "${test_sites[@]}"; do
        echo -n "Testing $site... "
        if ping -c 1 -W 2 "$site" &>/dev/null; then
            echo -e "${GREEN}OK${RESET}"
        else
            echo -e "${RED}FAILED${RESET}"
        fi
    done

    echo -e "\nDNS Test:"
    echo -n "Resolving google.com... "
    if nslookup google.com &>/dev/null; then
        echo -e "${GREEN}OK${RESET}"
    else
        echo -e "${RED}FAILED${RESET}"
    fi
}
