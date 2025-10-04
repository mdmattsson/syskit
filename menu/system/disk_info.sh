#!/bin/bash

DESCRIPTION="Check Disk Space"
DESTRUCTIVE=false              # Triggers confirmation
DEPENDENCIES=()                # Required commands ex: ("cmd1" "cmd2")
LONG_DESCRIPTION="Check Disk Space"

run() {
    echo -e "\n${CYAN}Disk Space Report:${RESET}"
    echo "==================="

    df -h

    echo -e "\nLargest directories in /var/log:"
    du -sh /var/log/* 2>/dev/null | sort -hr | head -5
}