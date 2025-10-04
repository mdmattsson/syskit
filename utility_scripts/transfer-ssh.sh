#!/bin/bash
# Secure transfer of Git config and SSH files to another machine
# Usage: ./transfer-config.sh user@hostname [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage
usage() {
    echo "Usage: $0 user@hostname [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run    Show what would be transferred without actually doing it"
    echo "  --git-only   Transfer only Git configuration"
    echo "  --ssh-only   Transfer only SSH files"
    echo "  --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 michael@newserver"
    echo "  $0 user@192.168.1.100 --dry-run"
    echo "  $0 user@workstation --ssh-only"
}

# Parse command line arguments
REMOTE_HOST=""
DRY_RUN=false
GIT_ONLY=false
SSH_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --git-only)
            GIT_ONLY=true
            shift
            ;;
        --ssh-only)
            SSH_ONLY=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        -*)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [[ -z "$REMOTE_HOST" ]]; then
                REMOTE_HOST="$1"
            else
                error "Multiple hostnames specified"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ -z "$REMOTE_HOST" ]]; then
    error "Remote host not specified"
    usage
    exit 1
fi

if [[ "$GIT_ONLY" == true && "$SSH_ONLY" == true ]]; then
    error "Cannot specify both --git-only and --ssh-only"
    exit 1
fi

# Check if remote host is reachable
check_connectivity() {
    log "Testing connection to $REMOTE_HOST..."
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_HOST" "echo 'Connection successful'" &>/dev/null; then
        error "Cannot connect to $REMOTE_HOST"
        error "Make sure SSH keys are set up and the host is reachable"
        exit 1
    fi
    log "Connection to $REMOTE_HOST successful"
}

# Create backup on remote machine
create_remote_backup() {
    log "Creating backups on remote machine..."

    local backup_timestamp=$(date +%Y%m%d_%H%M%S)

    if [[ "$SSH_ONLY" != true ]]; then
        ssh "$REMOTE_HOST" "
            if [[ -f ~/.gitconfig ]]; then
                cp ~/.gitconfig ~/.gitconfig.backup.$backup_timestamp
                echo 'Backed up ~/.gitconfig'
            fi
        "
    fi

    if [[ "$GIT_ONLY" != true ]]; then
        ssh "$REMOTE_HOST" "
            if [[ -d ~/.ssh ]]; then
                cp -r ~/.ssh ~/.ssh.backup.$backup_timestamp
                echo 'Backed up ~/.ssh directory'
            fi
        "
    fi
}

# Transfer Git configuration
transfer_git_config() {
    log "Transferring Git configuration..."

    if [[ ! -f ~/.gitconfig ]]; then
        warn "~/.gitconfig not found - skipping"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would transfer: ~/.gitconfig"
        return
    fi

    scp ~/.gitconfig "$REMOTE_HOST":~/
    log "Transferred ~/.gitconfig"

    # Also transfer global gitignore if it exists
    if [[ -f ~/.gitignore_global ]]; then
        scp ~/.gitignore_global "$REMOTE_HOST":~/
        log "Transferred ~/.gitignore_global"
    fi
}

# Transfer SSH files
transfer_ssh_files() {
    log "Transferring SSH files..."

    if [[ ! -d ~/.ssh ]]; then
        warn "~/.ssh directory not found - skipping"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would transfer:"
        find ~/.ssh -type f | while read file; do
            echo "  $file"
        done
        return
    fi

    # Create SSH directory on remote machine
    ssh "$REMOTE_HOST" "mkdir -p ~/.ssh"

    # Transfer all SSH files
    rsync -av --progress ~/.ssh/ "$REMOTE_HOST":~/.ssh/
    log "Transferred SSH directory contents"
}

# Set proper permissions on remote machine
set_remote_permissions() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would set proper permissions on remote machine"
        return
    fi

    log "Setting proper permissions on remote machine..."

    ssh "$REMOTE_HOST" "
        # Git config permissions
        [[ -f ~/.gitconfig ]] && chmod 644 ~/.gitconfig
        [[ -f ~/.gitignore_global ]] && chmod 644 ~/.gitignore_global

        # SSH permissions
        if [[ -d ~/.ssh ]]; then
            chmod 700 ~/.ssh

            # Private keys
            find ~/.ssh -type f -name 'id_*' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true
            find ~/.ssh -type f -name '*_rsa' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true
            find ~/.ssh -type f -name '*_ed25519' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true
            find ~/.ssh -type f -name '*_ecdsa' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true

            # Public keys
            find ~/.ssh -type f -name '*.pub' -exec chmod 644 {} \; 2>/dev/null || true

            # SSH config files
            [[ -f ~/.ssh/config ]] && chmod 600 ~/.ssh/config
            [[ -f ~/.ssh/known_hosts ]] && chmod 644 ~/.ssh/known_hosts
            [[ -f ~/.ssh/authorized_keys ]] && chmod 600 ~/.ssh/authorized_keys

            # SSH config_files directory
            if [[ -d ~/.ssh/config_files ]]; then
                chmod 700 ~/.ssh/config_files
                find ~/.ssh/config_files -type f -exec chmod 600 {} \;
            fi

            echo 'Set SSH permissions'
        fi

        echo 'Permission setup complete'
    "

    log "Remote permissions set successfully"
}

# Show transfer summary
show_summary() {
    echo ""
    log "Transfer Summary:"

    if [[ "$SSH_ONLY" != true ]]; then
        echo "  Git Configuration:"
        [[ -f ~/.gitconfig ]] && echo "    ✓ ~/.gitconfig" || echo "    ✗ ~/.gitconfig (not found)"
        [[ -f ~/.gitignore_global ]] && echo "    ✓ ~/.gitignore_global" || echo "    - ~/.gitignore_global (not found)"
    fi

    if [[ "$GIT_ONLY" != true ]]; then
        echo "  SSH Files:"
        if [[ -d ~/.ssh ]]; then
            local ssh_files=$(find ~/.ssh -type f | wc -l)
            echo "    ✓ ~/.ssh directory ($ssh_files files)"

            # Count different types of keys
            local private_keys=$(find ~/.ssh -type f -name 'id_*' ! -name '*.pub' | wc -l)
            local public_keys=$(find ~/.ssh -type f -name '*.pub' | wc -l)
            [[ $private_keys -gt 0 ]] && echo "    ✓ $private_keys private key(s)"
            [[ $public_keys -gt 0 ]] && echo "    ✓ $public_keys public key(s)"

            [[ -f ~/.ssh/config ]] && echo "    ✓ SSH config file"
            [[ -d ~/.ssh/config_files ]] && echo "    ✓ SSH config_files directory"
        else
            echo "    ✗ ~/.ssh directory (not found)"
        fi
    fi

    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        warn "This was a dry run - no files were actually transferred"
    else
        log "All files transferred successfully to $REMOTE_HOST"
        log "Backups created on remote machine with timestamp"
    fi
}

# Main execution
main() {
    log "Starting transfer to $REMOTE_HOST"

    if [[ "$DRY_RUN" == true ]]; then
        warn "DRY RUN MODE - No files will be transferred"
    fi

    check_connectivity

    if [[ "$DRY_RUN" != true ]]; then
        create_remote_backup
    fi

    if [[ "$SSH_ONLY" != true ]]; then
        transfer_git_config
    fi

    if [[ "$GIT_ONLY" != true ]]; then
        transfer_ssh_files
    fi

    set_remote_permissions
    show_summary

    if [[ "$DRY_RUN" != true ]]; then
        echo ""
        log "Next steps on $REMOTE_HOST:"
        echo "  1. Test SSH connections to verify keys work"
        echo "  2. Test Git operations to verify config is correct"
        echo "  3. Remove backup files when confirmed working:"
        echo "     rm ~/.gitconfig.backup.* ~/.ssh.backup.* 2>/dev/null"
    fi
}

show_menu() {
    clear
    echo "=== $DESCRIPTION ==="
    echo
    echo "Select an option:"
    echo
    echo "1) Transfer to remote host"
    echo "2) Dry run (show what would transfer)"
    echo "3) Transfer Git configuration only"
    echo "4) Transfer SSH files only"
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
            read -p "Remote host (user@hostname): " host
            [[ -z "$host" ]] && { echo "Host required"; sleep 1; show_menu; return; }
            run "$host"
            ;;
        2)
            echo
            read -p "Remote host (user@hostname): " host
            [[ -z "$host" ]] && { echo "Host required"; sleep 1; show_menu; return; }
            run "$host" --dry-run
            ;;
        3)
            echo
            read -p "Remote host (user@hostname): " host
            [[ -z "$host" ]] && { echo "Host required"; sleep 1; show_menu; return; }
            run "$host" --git-only
            ;;
        4)
            echo
            read -p "Remote host (user@hostname): " host
            [[ -z "$host" ]] && { echo "Host required"; sleep 1; show_menu; return; }
            run "$host" --ssh-only
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