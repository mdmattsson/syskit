#!/bin/bash

DESCRIPTION="Show Network Configuration"
DESTRUCTIVE=false              # Triggers confirmation
DEPENDENCIES=()                # Required commands ex: ("cmd1" "cmd2")
LONG_DESCRIPTION="Show Network Configuration"


run() {
    echo -e "\n${CYAN}Network Information:${RESET}"
    echo "====================="

    echo "IP Addresses:"
    ip addr show 2>/dev/null | grep "inet " | awk '{print $2, $NF}' || ifconfig | grep "inet "

    echo -e "\nRouting Table:"
    ip route 2>/dev/null || route -n

    echo -e "\nDNS Servers:"
    cat /etc/resolv.conf | grep nameserver

    echo -e "\nActive Connections:"
    ss -tuln 2>/dev/null | head -10 || netstat -tuln | head -10

}
