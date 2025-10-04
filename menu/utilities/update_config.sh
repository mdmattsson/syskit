#!/bin/bash
DESCRIPTION="Update Configuration"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Update bash configuration from repository"

run() {
    update-config.sh --menu
}