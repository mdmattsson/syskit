#!/bin/bash

DESCRIPTION="Show System Information"
DESTRUCTIVE=false              # Triggers confirmation
DEPENDENCIES=()                # Required commands ex: ("cmd1" "cmd2")
LONG_DESCRIPTION="Show System Information"

run() {
    echo -e "\n${CYAN}System Information:${RESET}"
    echo "===================="
    echo "Hostname: $(hostname)"
    echo "OS: $(uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Memory Usage: $(free -h 2>/dev/null | grep Mem || echo 'N/A')"
    echo "Disk Usage: $(df -h / | tail -1)"
}
