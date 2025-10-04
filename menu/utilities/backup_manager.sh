#!/bin/bash
DESCRIPTION="Backup Manager"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Interactive backup management for bash configuration"

run() {
    backup-manager.sh --menu
}