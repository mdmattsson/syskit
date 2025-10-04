#!/bin/bash
# backup-manager.sh
# Comprehensive backup management for bash configuration
# Handles creation, restoration, cleanup, and verification of backups

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
BACKUP_DIR="$HOME/.config/bash-backups"
MAX_BACKUPS=10
BACKUP_TIMESTAMP_FORMAT="%Y%m%d_%H%M%S"

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

header() {
    echo -e "\n${CYAN}=== $1 ===${NC}"
}

# ============================================================================
# BACKUP CREATION
# ============================================================================

create_backup() {
    local backup_name="$1"
    local description="$2"

    if [[ -z "$backup_name" ]]; then
        backup_name="manual_$(date +$BACKUP_TIMESTAMP_FORMAT)"
    fi

    local backup_path="$BACKUP_DIR/$backup_name"

    header "Creating Backup: $backup_name"

    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"

    # Check if backup already exists
    if [[ -d "$backup_path" ]]; then
        error "Backup '$backup_name' already exists"
        return 1
    fi

    # Create backup structure
    mkdir -p "$backup_path"

    # Backup .bashrc
    if [[ -f ~/.bashrc ]]; then
        cp ~/.bashrc "$backup_path/bashrc"
        log "Backed up ~/.bashrc"
    else
        warn "~/.bashrc not found"
    fi

    # Backup entire bash config directory
    if [[ -d ~/.config/bash ]]; then
        cp -r ~/.config/bash "$backup_path/bash-config"
        log "Backed up ~/.config/bash directory"
    else
        warn "~/.config/bash directory not found"
    fi

    # Backup SSH config if it exists
    if [[ -d ~/.ssh ]]; then
        mkdir -p "$backup_path/ssh"

        # Copy SSH config files (not private keys for security)
        [[ -f ~/.ssh/config ]] && cp ~/.ssh/config "$backup_path/ssh/"
        [[ -f ~/.ssh/known_hosts ]] && cp ~/.ssh/known_hosts "$backup_path/ssh/"
        [[ -f ~/.ssh/authorized_keys ]] && cp ~/.ssh/authorized_keys "$backup_path/ssh/"

        # Copy public keys only
        find ~/.ssh -name "*.pub" -exec cp {} "$backup_path/ssh/" \; 2>/dev/null || true

        # Copy SSH config_files directory if it exists
        if [[ -d ~/.ssh/config_files ]]; then
            cp -r ~/.ssh/config_files "$backup_path/ssh/"
        fi

        log "Backed up SSH configuration (public keys and config files only)"
    fi

    # Backup Git global config
    if [[ -f ~/.gitconfig ]]; then
        cp ~/.gitconfig "$backup_path/gitconfig"
        log "Backed up ~/.gitconfig"
    fi

    if [[ -f ~/.gitignore_global ]]; then
        cp ~/.gitignore_global "$backup_path/gitignore_global"
        log "Backed up ~/.gitignore_global"
    fi

    # Create backup metadata
    cat > "$backup_path/backup_info.txt" << EOF
Backup Name: $backup_name
Created: $(date)
Description: ${description:-Manual backup}
System: $(uname -a)
Bash Version: $BASH_VERSION
User: $USER
Hostname: $(hostname)

Files included:
$(find "$backup_path" -type f | sed 's|^'"$backup_path"'/|  |' | sort)

Directory sizes:
$(du -sh "$backup_path"/* 2>/dev/null | sed 's/^/  /')
EOF

    log "Created backup metadata"

    # Calculate backup size
    local backup_size=$(du -sh "$backup_path" | cut -f1)
    log "Backup completed: $backup_name ($backup_size)"

    # Cleanup old backups
    cleanup_old_backups

    return 0
}

# ============================================================================
# BACKUP RESTORATION
# ============================================================================

restore_backup() {
    local backup_name="$1"
    local backup_path="$BACKUP_DIR/$backup_name"

    if [[ -z "$backup_name" ]]; then
        error "Backup name required"
        list_backups
        return 1
    fi

    if [[ ! -d "$backup_path" ]]; then
        error "Backup '$backup_name' not found"
        list_backups
        return 1
    fi

    header "Restoring Backup: $backup_name"

    # Show backup info
    if [[ -f "$backup_path/backup_info.txt" ]]; then
        info "Backup information:"
        cat "$backup_path/backup_info.txt" | head -10
        echo
    fi

    # Confirm restoration
    warn "This will overwrite your current bash configuration!"
    read -p "Are you sure you want to restore this backup? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Restoration cancelled"
        return 0
    fi

    # Create safety backup before restoration
    local safety_backup="pre_restore_$(date +$BACKUP_TIMESTAMP_FORMAT)"
    log "Creating safety backup before restoration..."
    create_backup "$safety_backup" "Safety backup before restoring $backup_name" >/dev/null

    # Restore .bashrc
    if [[ -f "$backup_path/bashrc" ]]; then
        cp "$backup_path/bashrc" ~/.bashrc
        log "Restored ~/.bashrc"
    fi

    # Restore bash config directory
    if [[ -d "$backup_path/bash-config" ]]; then
        # Remove existing config
        rm -rf ~/.config/bash

        # Restore from backup
        mkdir -p ~/.config
        cp -r "$backup_path/bash-config" ~/.config/bash
        log "Restored ~/.config/bash directory"
    fi

    # Restore SSH config (prompt for each file for security)
    if [[ -d "$backup_path/ssh" ]]; then
        warn "SSH configuration found in backup"
        read -p "Restore SSH configuration files? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p ~/.ssh

            # Restore SSH config files
            [[ -f "$backup_path/ssh/config" ]] && cp "$backup_path/ssh/config" ~/.ssh/
            [[ -f "$backup_path/ssh/known_hosts" ]] && cp "$backup_path/ssh/known_hosts" ~/.ssh/
            [[ -f "$backup_path/ssh/authorized_keys" ]] && cp "$backup_path/ssh/authorized_keys" ~/.ssh/

            # Restore public keys
            find "$backup_path/ssh" -name "*.pub" -exec cp {} ~/.ssh/ \; 2>/dev/null || true

            # Restore config_files directory
            if [[ -d "$backup_path/ssh/config_files" ]]; then
                cp -r "$backup_path/ssh/config_files" ~/.ssh/
            fi

            log "Restored SSH configuration"
        fi
    fi

    # Restore Git config
    if [[ -f "$backup_path/gitconfig" ]]; then
        read -p "Restore Git configuration? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp "$backup_path/gitconfig" ~/.gitconfig
            log "Restored ~/.gitconfig"
        fi
    fi

    if [[ -f "$backup_path/gitignore_global" ]]; then
        [[ -f ~/.gitconfig ]] && cp "$backup_path/gitignore_global" ~/.gitignore_global
    fi

    # Fix permissions after restoration
    log "Fixing permissions after restoration..."
    if [[ -x "./fix-permissions.sh" ]]; then
        ./fix-permissions.sh >/dev/null 2>&1
    elif [[ -x "$HOME/.local/bin/fix-permissions.sh" ]]; then
        "$HOME/.local/bin/fix-permissions.sh" >/dev/null 2>&1
    else
        # Basic permission fixing
        chmod 644 ~/.bashrc 2>/dev/null || true
        chmod 755 ~/.config/bash 2>/dev/null || true
        find ~/.config/bash -type f -name "*.sh" -exec chmod 644 {} \; 2>/dev/null || true
        [[ -f ~/.config/bash/local.sh ]] && chmod 600 ~/.config/bash/local.sh 2>/dev/null || true
    fi

    log "Backup restored successfully!"
    warn "You may need to restart your shell or run 'source ~/.bashrc'"

    return 0
}

# ============================================================================
# BACKUP LISTING AND INFORMATION
# ============================================================================

list_backups() {
    header "Available Backups"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        warn "No backup directory found at $BACKUP_DIR"
        return 1
    fi

    local backups=($(ls -1 "$BACKUP_DIR" 2>/dev/null | sort -r))

    if [[ ${#backups[@]} -eq 0 ]]; then
        warn "No backups found"
        return 1
    fi

    printf "%-25s %-12s %-20s %s\n" "Backup Name" "Size" "Created" "Description"
    printf "%-25s %-12s %-20s %s\n" "$(printf '=%.0s' {1..25})" "$(printf '=%.0s' {1..12})" "$(printf '=%.0s' {1..20})" "$(printf '=%.0s' {1..30})"

    for backup in "${backups[@]}"; do
        local backup_path="$BACKUP_DIR/$backup"
        local size=$(du -sh "$backup_path" 2>/dev/null | cut -f1)
        local created="N/A"
        local description="N/A"

        if [[ -f "$backup_path/backup_info.txt" ]]; then
            created=$(grep "Created:" "$backup_path/backup_info.txt" 2>/dev/null | cut -d: -f2- | sed 's/^ *//' | cut -d' ' -f1-3)
            description=$(grep "Description:" "$backup_path/backup_info.txt" 2>/dev/null | cut -d: -f2- | sed 's/^ *//')
        fi

        printf "%-25s %-12s %-20s %s\n" "$backup" "$size" "$created" "$description"
    done

    echo
    info "Total backups: ${#backups[@]}"
    info "Backup directory: $BACKUP_DIR"

    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    info "Total backup size: $total_size"
}

show_backup_info() {
    local backup_name="$1"
    local backup_path="$BACKUP_DIR/$backup_name"

    if [[ -z "$backup_name" ]]; then
        error "Backup name required"
        return 1
    fi

    if [[ ! -d "$backup_path" ]]; then
        error "Backup '$backup_name' not found"
        return 1
    fi

    header "Backup Information: $backup_name"

    if [[ -f "$backup_path/backup_info.txt" ]]; then
        cat "$backup_path/backup_info.txt"
    else
        warn "No backup information file found"

        # Show basic information
        echo "Backup path: $backup_path"
        echo "Size: $(du -sh "$backup_path" | cut -f1)"
        echo "Modified: $(stat -c %y "$backup_path" 2>/dev/null || stat -f %Sm "$backup_path" 2>/dev/null)"
        echo
        echo "Contents:"
        find "$backup_path" -type f | sed 's|^'"$backup_path"'/|  |' | sort
    fi
}

# ============================================================================
# BACKUP VERIFICATION
# ============================================================================

verify_backup() {
    local backup_name="$1"
    local backup_path="$BACKUP_DIR/$backup_name"

    if [[ -z "$backup_name" ]]; then
        error "Backup name required"
        return 1
    fi

    if [[ ! -d "$backup_path" ]]; then
        error "Backup '$backup_name' not found"
        return 1
    fi

    header "Verifying Backup: $backup_name"

    local issues=0

    # Check backup structure
    if [[ ! -f "$backup_path/backup_info.txt" ]]; then
        warn "Missing backup metadata file"
        ((issues++))
    fi

    # Verify essential files
    if [[ -f "$backup_path/bashrc" ]]; then
        if bash -n "$backup_path/bashrc" 2>/dev/null; then
            log "bashrc syntax is valid"
        else
            error "bashrc has syntax errors"
            ((issues++))
        fi
    else
        warn "No bashrc in backup"
    fi

    # Verify bash config files
    if [[ -d "$backup_path/bash-config" ]]; then
        local config_files=$(find "$backup_path/bash-config" -name "*.sh" -type f)
        local syntax_errors=0

        while IFS= read -r file; do
            if [[ -n "$file" ]]; then
                if bash -n "$file" 2>/dev/null; then
                    log "$(basename "$file") syntax is valid"
                else
                    error "$(basename "$file") has syntax errors"
                    ((syntax_errors++))
                    ((issues++))
                fi
            fi
        done <<< "$config_files"

        if [[ $syntax_errors -eq 0 && -n "$config_files" ]]; then
            log "All configuration files have valid syntax"
        fi
    else
        warn "No bash configuration directory in backup"
    fi

    # Check SSH files
    if [[ -d "$backup_path/ssh" ]]; then
        if [[ -f "$backup_path/ssh/config" ]]; then
            # Basic SSH config validation
            if ssh -F "$backup_path/ssh/config" -T git@github.com &>/dev/null; then
                log "SSH config appears valid"
            else
                warn "SSH config may have issues (test failed)"
            fi
        fi

        # Check for public keys
        local pub_keys=$(find "$backup_path/ssh" -name "*.pub" | wc -l)
        if [[ $pub_keys -gt 0 ]]; then
            log "Found $pub_keys public key(s)"
        fi
    fi

    # Check Git config
    if [[ -f "$backup_path/gitconfig" ]]; then
        # Basic git config validation
        if git config -f "$backup_path/gitconfig" --list >/dev/null 2>&1; then
            log "Git config is valid"
        else
            error "Git config has syntax errors"
            ((issues++))
        fi
    fi

    # Calculate and verify integrity
    local backup_size=$(du -sh "$backup_path" | cut -f1)
    log "Backup size: $backup_size"

    if [[ $issues -eq 0 ]]; then
        log "Backup verification completed successfully"
        return 0
    else
        error "Backup verification found $issues issue(s)"
        return 1
    fi
}

# ============================================================================
# BACKUP CLEANUP
# ============================================================================

cleanup_old_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        return 0
    fi

    local backups=($(ls -1t "$BACKUP_DIR" 2>/dev/null))
    local backup_count=${#backups[@]}

    if [[ $backup_count -le $MAX_BACKUPS ]]; then
        return 0
    fi

    log "Found $backup_count backups, keeping newest $MAX_BACKUPS"

    # Remove oldest backups
    local to_remove=$((backup_count - MAX_BACKUPS))
    for ((i=MAX_BACKUPS; i<backup_count; i++)); do
        local old_backup="${backups[$i]}"
        warn "Removing old backup: $old_backup"
        rm -rf "$BACKUP_DIR/$old_backup"
    done

    log "Cleanup completed"
}

delete_backup() {
    local backup_name="$1"
    local backup_path="$BACKUP_DIR/$backup_name"

    if [[ -z "$backup_name" ]]; then
        error "Backup name required"
        return 1
    fi

    if [[ ! -d "$backup_path" ]]; then
        error "Backup '$backup_name' not found"
        return 1
    fi

    # Show backup info before deletion
    show_backup_info "$backup_name"
    echo

    warn "This will permanently delete the backup '$backup_name'"
    read -p "Are you sure? Type 'DELETE' to confirm: " confirm

    if [[ "$confirm" == "DELETE" ]]; then
        rm -rf "$backup_path"
        log "Backup '$backup_name' deleted successfully"
    else
        log "Deletion cancelled"
    fi
}

# ============================================================================
# AUTOMATIC BACKUP SCHEDULING
# ============================================================================

setup_auto_backup() {
    header "Setting up automatic backups"

    # Create auto-backup script
    local auto_script="$HOME/.local/bin/auto-backup-bash-config.sh"
    mkdir -p "$(dirname "$auto_script")"

    cat > "$auto_script" << 'EOF'
#!/bin/bash
# Auto-generated backup script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_MANAGER="$SCRIPT_DIR/backup-manager.sh"

if [[ -x "$BACKUP_MANAGER" ]]; then
    "$BACKUP_MANAGER" create "auto_$(date +%Y%m%d_%H%M%S)" "Automatic backup"
else
    echo "Warning: backup-manager.sh not found"
fi
EOF

    chmod +x "$auto_script"
    log "Created auto-backup script: $auto_script"

    # Suggest cron setup
    info "To enable automatic backups, add this to your crontab:"
    echo "  # Daily backup at 2 AM"
    echo "  0 2 * * * $auto_script >/dev/null 2>&1"
    echo
    echo "Run 'crontab -e' to edit your crontab"
}

# ============================================================================
# USAGE AND HELP
# ============================================================================

show_help() {
    echo "backup-manager.sh - Bash configuration backup management"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  create [name] [description]  Create a new backup"
    echo "  restore <name>               Restore from backup"
    echo "  list                         List all backups"
    echo "  info <name>                  Show backup information"
    echo "  verify <name>                Verify backup integrity"
    echo "  delete <name>                Delete a backup"
    echo "  cleanup                      Remove old backups (keep $MAX_BACKUPS)"
    echo "  auto-setup                   Setup automatic backups"
    echo "  help                         Show this help"
    echo
    echo "Examples:"
    echo "  $0 create                           # Create backup with auto name"
    echo "  $0 create my_backup 'Before update' # Create named backup"
    echo "  $0 restore my_backup                # Restore specific backup"
    echo "  $0 list                             # List all backups"
    echo "  $0 verify my_backup                 # Verify backup integrity"
    echo
    echo "Configuration:"
    echo "  Backup directory: $BACKUP_DIR"
    echo "  Max backups kept: $MAX_BACKUPS"
}

# ============================================================================
# MAIN COMMAND PROCESSING
# ============================================================================

main() {
    local command="$1"
    shift 2>/dev/null || true

    case "$command" in
        create)
            create_backup "$1" "$2"
            ;;
        restore)
            restore_backup "$1"
            ;;
        list)
            list_backups
            ;;
        info)
            show_backup_info "$1"
            ;;
        verify)
            verify_backup "$1"
            ;;
        delete)
            delete_backup "$1"
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        auto-setup)
            setup_auto_backup
            ;;
        help|--help|-h|"")
            show_help
            ;;
        *)
            error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}


show_menu() {
    clear
    echo "=== $DESCRIPTION ==="
    echo
    echo "Select an option:"
    echo
    echo "1) Create new backup"
    echo "2) List all backups"
    echo "3) Restore from backup"
    echo "4) Verify backup integrity"
    echo "5) Delete a backup"
    echo "6) Cleanup old backups"
    echo "7) Setup automatic backups"
    echo "8) Show backup information"
    echo "0) Exit"
    echo
    read -p "Enter choice: " choice
    handle_menu_choice "$choice"
}

handle_menu_choice() {
    local choice="$1"
    
    case $choice in
        1) 
            echo
            read -p "Backup name (leave empty for auto): " name
            read -p "Description: " desc
            create_backup "$name" "$desc"
            ;;
        2) 
            list_backups
            ;;
        3) 
            echo
            list_backups
            echo
            read -p "Backup name to restore: " name
            restore_backup "$name"
            ;;
        4)
            echo
            list_backups
            echo
            read -p "Backup name to verify: " name
            verify_backup "$name"
            ;;
        5)
            echo
            list_backups
            echo
            read -p "Backup name to delete: " name
            delete_backup "$name"
            ;;
        6)
            cleanup_old_backups
            ;;
        7)
            setup_auto_backup
            ;;
        8)
            echo
            list_backups
            echo
            read -p "Backup name: " name
            show_backup_info "$name"
            ;;
        0) 
            exit 0
            ;;
        *) 
            echo "Invalid choice"
            sleep 1
            show_menu
            ;;
    esac
    
    echo
    read -p "Press Enter to continue or 'q' to quit: " cont
    [[ "$cont" == "q" ]] && exit 0
    show_menu
}


if [[ "$1" == "--menu" ]]; then
    show_menu
else
    main "$@"
fi
