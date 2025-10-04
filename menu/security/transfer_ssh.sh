#!/bin/bash
DESCRIPTION="Transfer SSH & Git Config"
DESTRUCTIVE=true
DEPENDENCIES=()
LONG_DESCRIPTION="Securely transfer Git config and SSH files to another machine"

run() {
    transfer-ssh.sh --menu
}