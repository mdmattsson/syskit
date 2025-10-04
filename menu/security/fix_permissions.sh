#!/bin/bash
DESCRIPTION="Fix Permissions"
DESTRUCTIVE=false
DEPENDENCIES=()
LONG_DESCRIPTION="Fix file permissions for bash config and SSH"

run() {
    fix-permissions.sh --menu
}