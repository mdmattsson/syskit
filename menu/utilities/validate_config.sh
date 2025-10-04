#!/bin/bash
DESCRIPTION="Validate Configuration"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Comprehensive validation and health check for bash configuration"

run() {
    validate-config.sh --menu
}