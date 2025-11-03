#!/bin/bash
# Transfer Git config and SSH files between machines, WSL, and Windows
# Usage: ./transfer-config.sh --from SOURCE --to DESTINATION [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Show usage
usage() {
    echo "Usage: $0 [--from SOURCE] --to DESTINATION [options]"
    echo ""
    echo "If --from is not specified, defaults to current machine"
    echo ""
    echo "Source/Destination can be:"
    echo "  windows              Current Windows user home"
    echo "  windows:USERNAME     Specific Windows user"
    echo "  wsl                  Current WSL instance"
    echo "  wsl:DISTRO           Specific WSL distribution"
    echo "  user@hostname        Remote machine via SSH"
    echo ""
    echo "Options:"
    echo "  --dry-run           Show what would be transferred without actually doing it"
    echo "  --git-only          Transfer only Git configuration"
    echo "  --ssh-only          Transfer only SSH files"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  # From current machine to remote"
    echo "  $0 --to user@server.com"
    echo "  $0 --to michael@192.168.1.100"
    echo ""
    echo "  # Windows to WSL"
    echo "  $0 --from windows --to wsl"
    echo "  $0 --from windows:Michael --to wsl:Rocky"
    echo ""
    echo "  # WSL to Windows"
    echo "  $0 --from wsl --to windows:Michael"
    echo ""
    echo "  # Remote transfers"
    echo "  $0 --from wsl --to user@server.com"
    echo "  $0 --from windows --to michael@192.168.1.100"
    echo ""
    echo "  # Between WSL distributions"
    echo "  $0 --from wsl:Ubuntu --to wsl:Rocky"
    echo ""
    echo "  # With options"
    echo "  $0 --from windows --to wsl:Rocky --dry-run"
    echo "  $0 --from wsl --to windows --ssh-only"
}

# Parse command line arguments
FROM_SPEC=""
TO_SPEC=""
DRY_RUN=false
GIT_ONLY=false
SSH_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --from)
            FROM_SPEC="$2"
            shift 2
            ;;
        --to)
            TO_SPEC="$2"
            shift 2
            ;;
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
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Detect if running in WSL
is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

# Validate arguments
if [[ -z "$TO_SPEC" ]]; then
    error "--to must be specified"
    usage
    exit 1
fi

# Default --from to current machine if not specified
if [[ -z "$FROM_SPEC" ]]; then
    if is_wsl; then
        # Get current WSL distribution name
        FROM_SPEC="wsl"
        log "Defaulting to current WSL distribution as source"
    else
        error "Could not auto-detect source machine type"
        error "Please specify --from parameter"
        exit 1
    fi
fi

if [[ "$GIT_ONLY" == true && "$SSH_ONLY" == true ]]; then
    error "Cannot specify both --git-only and --ssh-only"
    exit 1
fi

# Parse location specification
parse_location() {
    local spec="$1"
    local var_prefix="$2"
    
    if [[ "$spec" == *@* ]]; then
        # SSH: user@hostname
        eval "${var_prefix}_TYPE=ssh"
        eval "${var_prefix}_HOST=$spec"
    elif [[ "$spec" == windows:* ]]; then
        # Windows with specific user
        eval "${var_prefix}_TYPE=windows"
        eval "${var_prefix}_USER=${spec#*:}"
    elif [[ "$spec" == "windows" ]]; then
        # Windows with auto-detect user
        eval "${var_prefix}_TYPE=windows"
        eval "${var_prefix}_USER="
    elif [[ "$spec" == wsl:* ]]; then
        # Specific WSL distribution
        eval "${var_prefix}_TYPE=wsl"
        eval "${var_prefix}_DISTRO=${spec#*:}"
    elif [[ "$spec" == "wsl" ]]; then
        # Current WSL
        eval "${var_prefix}_TYPE=wsl"
        eval "${var_prefix}_DISTRO="
    else
        error "Invalid location specification: $spec"
        usage
        exit 1
    fi
}

# Parse FROM and TO specifications
parse_location "$FROM_SPEC" "FROM"
parse_location "$TO_SPEC" "TO"

# Validate combination
validate_transfer() {
    # Check if we're in WSL when needed
    if [[ "$FROM_TYPE" == "wsl" && -z "$FROM_DISTRO" ]]; then
        if ! is_wsl; then
            error "--from wsl requires running from within WSL"
            error "Or specify a distribution: --from wsl:DISTRO"
            exit 1
        fi
    fi
    
    if [[ "$TO_TYPE" == "wsl" && -z "$TO_DISTRO" ]]; then
        if ! is_wsl; then
            error "--to wsl requires running from within WSL"
            error "Or specify a distribution: --to wsl:DISTRO"
            exit 1
        fi
    fi
    
    # Windows operations require WSL or specific handling
    if [[ "$FROM_TYPE" == "windows" || "$TO_TYPE" == "windows" ]]; then
        if ! is_wsl && ! command -v wsl.exe &>/dev/null; then
            error "Windows transfers require running from WSL or having wsl.exe available"
            exit 1
        fi
    fi
}

validate_transfer

# Detect Windows username if needed
detect_windows_user() {
    local user_var="$1"
    local current_user
    
    eval "current_user=\$$user_var"
    
    if [[ -n "$current_user" ]]; then
        log "Using specified Windows user: $current_user"
        return
    fi
    
    # Try to auto-detect
    if is_wsl; then
        local win_home=$(wslpath "$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')" 2>/dev/null)
        if [[ -n "$win_home" ]]; then
            current_user=$(basename "$win_home")
            eval "$user_var='$current_user'"
            log "Auto-detected Windows user: $current_user"
            return
        fi
    fi
    
    # Try from /mnt/c/Users
    if [[ -d /mnt/c/Users ]]; then
        local users=($(ls -1 /mnt/c/Users 2>/dev/null | grep -v "^Public$" | grep -v "^Default" | grep -v "^All Users"))
        if [[ ${#users[@]} -eq 1 ]]; then
            current_user="${users[0]}"
            eval "$user_var='$current_user'"
            log "Auto-detected Windows user: $current_user"
            return
        elif [[ ${#users[@]} -gt 1 ]]; then
            warn "Multiple Windows users found:"
            for user in "${users[@]}"; do
                echo "  - $user"
            done
            echo ""
            read -p "Enter Windows username: " current_user
            eval "$user_var='$current_user'"
            return
        fi
    fi
    
    error "Could not auto-detect Windows username"
    error "Please specify: --from windows:USERNAME or --to windows:USERNAME"
    exit 1
}

# Get Windows paths for a user
get_windows_paths() {
    local user="$1"
    local prefix="$2"
    
    eval "${prefix}_HOME=/mnt/c/Users/$user"
    eval "${prefix}_GITCONFIG=/mnt/c/Users/$user/.gitconfig"
    eval "${prefix}_GITIGNORE=/mnt/c/Users/$user/.gitignore_global"
    eval "${prefix}_SSH=/mnt/c/Users/$user/.ssh"
    
    local home_path
    eval "home_path=\$${prefix}_HOME"
    
    if [[ ! -d "$home_path" ]]; then
        error "Windows home directory not found: $home_path"
        exit 1
    fi
}

# Get WSL paths
get_wsl_paths() {
    local distro="$1"
    local prefix="$2"
    
    if [[ -n "$distro" ]]; then
        # Verify distribution exists
        if command -v wsl.exe &>/dev/null; then
            # Get list of distributions and clean up encoding issues
            local distros_raw=$(wsl.exe -l -q 2>/dev/null)
            local distros_clean
            
            # Try to convert from UTF-16LE to UTF-8, fall back to just removing \r if that fails
            if distros_clean=$(echo "$distros_raw" | iconv -f UTF-16LE -t UTF-8 2>/dev/null); then
                distros_clean=$(echo "$distros_clean" | tr -d '\r\n' | sed 's/  */\n/g')
            else
                distros_clean=$(echo "$distros_raw" | tr -d '\r')
            fi
            
            # Case-insensitive search for the distribution
            if ! echo "$distros_clean" | grep -qi "^${distro}$"; then
                error "WSL distribution '$distro' not found"
                echo ""
                echo "Available distributions:"
                echo "$distros_clean"
                exit 1
            fi
        fi
        eval "${prefix}_DISTRO=$distro"
    else
        eval "${prefix}_DISTRO="
    fi
    
    eval "${prefix}_GITCONFIG=~/.gitconfig"
    eval "${prefix}_GITIGNORE=~/.gitignore_global"
    eval "${prefix}_SSH=~/.ssh"
}

# Setup paths based on source and destination types
setup_paths() {
    log "Setting up transfer paths..."
    
    case "$FROM_TYPE" in
        windows)
            detect_windows_user FROM_USER
            get_windows_paths "$FROM_USER" "SRC"
            ;;
        wsl)
            get_wsl_paths "$FROM_DISTRO" "SRC"
            ;;
        ssh)
            log "Using SSH source: $FROM_HOST"
            ;;
    esac
    
    case "$TO_TYPE" in
        windows)
            detect_windows_user TO_USER
            get_windows_paths "$TO_USER" "DST"
            ;;
        wsl)
            get_wsl_paths "$TO_DISTRO" "DST"
            ;;
        ssh)
            log "Using SSH destination: $TO_HOST"
            DST_HOST="$TO_HOST"
            ;;
    esac
}

# Check SSH connectivity
check_ssh_connection() {
    local host="$1"
    log "Testing SSH connection to $host..."
    
    # Set up SSH ControlMaster for connection reuse
    export SSH_CONTROL_PATH="/tmp/ssh-transfer-$$"
    mkdir -p "$SSH_CONTROL_PATH"
    export SSH_CONTROL_SOCKET="$SSH_CONTROL_PATH/%r@%h:%p"
    
    # Start master connection
    ssh -o ControlMaster=yes -o ControlPath="$SSH_CONTROL_SOCKET" -o ControlPersist=300 -fN "$host" 2>/dev/null
    local ssh_result=$?
    
    if [[ $ssh_result -ne 0 ]]; then
        warn "Cannot connect to $host or passwordless SSH not set up"
        warn "You may be prompted for your password multiple times"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        # Clear the control socket since connection failed
        unset SSH_CONTROL_SOCKET
    else
        log "SSH connection established (will be reused for all transfers)"
    fi
}

# Clean up SSH control socket
cleanup_ssh() {
    if [[ -n "$SSH_CONTROL_SOCKET" ]] && [[ -S "$SSH_CONTROL_SOCKET" ]]; then
        ssh -O exit -o ControlPath="$SSH_CONTROL_SOCKET" "$DST_HOST" 2>/dev/null
    fi
    if [[ -n "$SSH_CONTROL_PATH" ]] && [[ -d "$SSH_CONTROL_PATH" ]]; then
        rm -rf "$SSH_CONTROL_PATH"
    fi
}

# Helper function to get SSH options
get_ssh_opts() {
    if [[ -n "$SSH_CONTROL_SOCKET" ]]; then
        echo "-o ControlPath=$SSH_CONTROL_SOCKET"
    fi
}

# Backup existing files on destination
create_backup() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would backup existing files"
        return
    fi
    
    log "Creating backup of existing files..."
    
    local backup_suffix=".backup.$(date +%Y%m%d_%H%M%S)"
    local backup_cmd="
        [[ -f ~/.gitconfig ]] && cp ~/.gitconfig ~/.gitconfig$backup_suffix
        [[ -f ~/.gitignore_global ]] && cp ~/.gitignore_global ~/.gitignore_global$backup_suffix
        [[ -d ~/.ssh ]] && cp -r ~/.ssh ~/.ssh$backup_suffix
    "
    
    case "$TO_TYPE" in
        ssh)
            ssh $(get_ssh_opts) "$DST_HOST" "$backup_cmd"
            ;;
        wsl)
            if [[ -n "$TO_DISTRO" ]]; then
                wsl.exe -d "$TO_DISTRO" bash -c "$backup_cmd"
            else
                eval "$backup_cmd"
            fi
            ;;
        windows)
            cd "$DST_HOME"
            [[ -f .gitconfig ]] && cp .gitconfig ".gitconfig$backup_suffix"
            [[ -f .gitignore_global ]] && cp .gitignore_global ".gitignore_global$backup_suffix"
            [[ -d .ssh ]] && cp -r .ssh ".ssh$backup_suffix"
            ;;
    esac
    
    log "Backup created with suffix: $backup_suffix"
}

# Read content from source
read_from_source() {
    local file="$1"
    
    case "$FROM_TYPE" in
        windows)
            if [[ "$file" == "gitconfig" ]]; then
                cat "$SRC_GITCONFIG"
            elif [[ "$file" == "gitignore" ]]; then
                cat "$SRC_GITIGNORE"
            else
                cat "$SRC_SSH/$file"
            fi
            ;;
        wsl)
            if [[ -n "$FROM_DISTRO" ]]; then
                if [[ "$file" == "gitconfig" ]]; then
                    wsl.exe -d "$FROM_DISTRO" bash -c "cat ~/.gitconfig"
                elif [[ "$file" == "gitignore" ]]; then
                    wsl.exe -d "$FROM_DISTRO" bash -c "cat ~/.gitignore_global"
                else
                    wsl.exe -d "$FROM_DISTRO" bash -c "cat ~/.ssh/$file"
                fi
            else
                if [[ "$file" == "gitconfig" ]]; then
                    cat ~/.gitconfig
                elif [[ "$file" == "gitignore" ]]; then
                    cat ~/.gitignore_global
                else
                    cat ~/.ssh/"$file"
                fi
            fi
            ;;
        ssh)
            if [[ "$file" == "gitconfig" ]]; then
                cat ~/.gitconfig
            elif [[ "$file" == "gitignore" ]]; then
                cat ~/.gitignore_global
            else
                cat ~/.ssh/"$file"
            fi
            ;;
    esac
}

# Write content to destination
write_to_destination() {
    local file="$1"
    local content="$2"
    
    case "$TO_TYPE" in
        windows)
            if [[ "$file" == "gitconfig" ]]; then
                echo "$content" > "$DST_GITCONFIG"
            elif [[ "$file" == "gitignore" ]]; then
                echo "$content" > "$DST_GITIGNORE"
            else
                echo "$content" > "$DST_SSH/$file"
            fi
            ;;
        wsl)
            if [[ -n "$TO_DISTRO" ]]; then
                if [[ "$file" == "gitconfig" ]]; then
                    echo "$content" | wsl.exe -d "$TO_DISTRO" bash -c "cat > ~/.gitconfig"
                elif [[ "$file" == "gitignore" ]]; then
                    echo "$content" | wsl.exe -d "$TO_DISTRO" bash -c "cat > ~/.gitignore_global"
                else
                    echo "$content" | wsl.exe -d "$TO_DISTRO" bash -c "cat > ~/.ssh/$file"
                fi
            else
                if [[ "$file" == "gitconfig" ]]; then
                    echo "$content" > ~/.gitconfig
                elif [[ "$file" == "gitignore" ]]; then
                    echo "$content" > ~/.gitignore_global
                else
                    echo "$content" > ~/.ssh/"$file"
                fi
            fi
            ;;
        ssh)
            if [[ "$file" == "gitconfig" ]]; then
                echo "$content" | ssh $(get_ssh_opts) "$DST_HOST" "cat > ~/.gitconfig"
            elif [[ "$file" == "gitignore" ]]; then
                echo "$content" | ssh $(get_ssh_opts) "$DST_HOST" "cat > ~/.gitignore_global"
            else
                echo "$content" | ssh $(get_ssh_opts) "$DST_HOST" "cat > ~/.ssh/$file"
            fi
            ;;
    esac
}

# Transfer Git config files
transfer_git_config() {
    if [[ "$SSH_ONLY" == true ]]; then
        return
    fi
    
    log "Transferring Git configuration..."
    
    # Check if source gitconfig exists
    local has_gitconfig=false
    case "$FROM_TYPE" in
        windows) [[ -f "$SRC_GITCONFIG" ]] && has_gitconfig=true ;;
        wsl)
            if [[ -n "$FROM_DISTRO" ]]; then
                wsl.exe -d "$FROM_DISTRO" bash -c "[[ -f ~/.gitconfig ]]" 2>/dev/null && has_gitconfig=true
            else
                [[ -f ~/.gitconfig ]] && has_gitconfig=true
            fi
            ;;
        ssh) [[ -f ~/.gitconfig ]] && has_gitconfig=true ;;
    esac
    
    if [[ "$has_gitconfig" == false ]]; then
        warn "Source .gitconfig not found - skipping"
        return
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would transfer .gitconfig"
        return
    fi
    
    # Transfer based on type
    if [[ "$FROM_TYPE" == "ssh" ]]; then
        scp $(get_ssh_opts) ~/.gitconfig "$DST_HOST":~/
    elif [[ "$TO_TYPE" == "ssh" ]]; then
        case "$FROM_TYPE" in
            windows) scp $(get_ssh_opts) "$SRC_GITCONFIG" "$DST_HOST":~/.gitconfig ;;
            wsl) 
                if [[ -n "$FROM_DISTRO" ]]; then
                    local content=$(wsl.exe -d "$FROM_DISTRO" bash -c "cat ~/.gitconfig")
                    echo "$content" | ssh $(get_ssh_opts) "$DST_HOST" "cat > ~/.gitconfig"
                else
                    scp $(get_ssh_opts) ~/.gitconfig "$DST_HOST":~/
                fi
                ;;
        esac
    else
        local content=$(read_from_source "gitconfig")
        write_to_destination "gitconfig" "$content"
    fi
    
    log "Transferred .gitconfig"
    
    # Also try gitignore_global
    local has_gitignore=false
    case "$FROM_TYPE" in
        windows) [[ -f "$SRC_GITIGNORE" ]] && has_gitignore=true ;;
        wsl) 
            if [[ -n "$FROM_DISTRO" ]]; then
                wsl.exe -d "$FROM_DISTRO" bash -c "[[ -f ~/.gitignore_global ]]" 2>/dev/null && has_gitignore=true
            else
                [[ -f ~/.gitignore_global ]] && has_gitignore=true
            fi
            ;;
        ssh) [[ -f ~/.gitignore_global ]] && has_gitignore=true ;;
    esac
    
    if [[ "$has_gitignore" == true ]] && [[ "$DRY_RUN" != true ]]; then
        if [[ "$FROM_TYPE" == "ssh" ]]; then
            scp $(get_ssh_opts) ~/.gitignore_global "$DST_HOST":~/
        elif [[ "$TO_TYPE" == "ssh" ]]; then
            case "$FROM_TYPE" in
                windows) scp $(get_ssh_opts) "$SRC_GITIGNORE" "$DST_HOST":~/.gitignore_global ;;
                wsl)
                    if [[ -n "$FROM_DISTRO" ]]; then
                        local content=$(wsl.exe -d "$FROM_DISTRO" bash -c "cat ~/.gitignore_global")
                        echo "$content" | ssh $(get_ssh_opts) "$DST_HOST" "cat > ~/.gitignore_global"
                    else
                        scp $(get_ssh_opts) ~/.gitignore_global "$DST_HOST":~/
                    fi
                    ;;
            esac
        else
            local content=$(read_from_source "gitignore")
            write_to_destination "gitignore" "$content"
        fi
        log "Transferred .gitignore_global"
    fi
}

# Get list of SSH files from source
get_ssh_files() {
    case "$FROM_TYPE" in
        windows)
            find "$SRC_SSH" -type f 2>/dev/null | sed "s|$SRC_SSH/||"
            ;;
        wsl)
            if [[ -n "$FROM_DISTRO" ]]; then
                wsl.exe -d "$FROM_DISTRO" bash -c "find ~/.ssh -type f 2>/dev/null | sed 's|$HOME/.ssh/||'"
            else
                find ~/.ssh -type f 2>/dev/null | sed 's|^.*/\.ssh/||'
            fi
            ;;
        ssh)
            find ~/.ssh -type f 2>/dev/null | sed 's|^.*/\.ssh/||'
            ;;
    esac
}

# Transfer SSH files
transfer_ssh_files() {
    if [[ "$GIT_ONLY" == true ]]; then
        return
    fi
    
    log "Transferring SSH files..."
    
    # Check if source SSH directory exists
    local has_ssh=false
    case "$FROM_TYPE" in
        windows) [[ -d "$SRC_SSH" ]] && has_ssh=true ;;
        wsl)
            if [[ -n "$FROM_DISTRO" ]]; then
                wsl.exe -d "$FROM_DISTRO" bash -c "[[ -d ~/.ssh ]]" 2>/dev/null && has_ssh=true
            else
                [[ -d ~/.ssh ]] && has_ssh=true
            fi
            ;;
        ssh) [[ -d ~/.ssh ]] && has_ssh=true ;;
    esac
    
    if [[ "$has_ssh" == false ]]; then
        warn "Source .ssh directory not found - skipping"
        return
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would transfer SSH files:"
        get_ssh_files | while read file; do
            echo "  $file"
        done
        return
    fi
    
    # Create destination SSH directory
    case "$TO_TYPE" in
        ssh) ssh $(get_ssh_opts) "$DST_HOST" "mkdir -p ~/.ssh" ;;
        wsl)
            if [[ -n "$TO_DISTRO" ]]; then
                wsl.exe -d "$TO_DISTRO" bash -c "mkdir -p ~/.ssh"
            else
                mkdir -p ~/.ssh
            fi
            ;;
        windows) mkdir -p "$DST_SSH" ;;
    esac
    
    # Transfer using rsync for SSH, or file-by-file for others
    if [[ "$FROM_TYPE" == "ssh" && "$TO_TYPE" != "ssh" ]]; then
        # Can't easily rsync from local to remote in this direction
        warn "SSH source with non-SSH destination not fully optimized"
    elif [[ "$TO_TYPE" == "ssh" ]]; then
        local rsync_opts="-av --progress"
        if [[ -n "$SSH_CONTROL_SOCKET" ]]; then
            rsync_opts="$rsync_opts -e ssh -o ControlPath=$SSH_CONTROL_SOCKET"
        fi
        case "$FROM_TYPE" in
            windows) 
                if [[ -n "$SSH_CONTROL_SOCKET" ]]; then
                    rsync -av --progress -e "ssh -o ControlPath=$SSH_CONTROL_SOCKET" "$SRC_SSH/" "$DST_HOST":~/.ssh/
                else
                    rsync -av --progress "$SRC_SSH/" "$DST_HOST":~/.ssh/
                fi
                ;;
            wsl)
                if [[ -n "$FROM_DISTRO" ]]; then
                    # File by file for cross-WSL
                    get_ssh_files | while read file; do
                        local content=$(wsl.exe -d "$FROM_DISTRO" bash -c "cat ~/.ssh/$file" 2>/dev/null)
                        echo "$content" | ssh $(get_ssh_opts) "$DST_HOST" "cat > ~/.ssh/$file"
                    done
                else
                    if [[ -n "$SSH_CONTROL_SOCKET" ]]; then
                        rsync -av --progress -e "ssh -o ControlPath=$SSH_CONTROL_SOCKET" ~/.ssh/ "$DST_HOST":~/.ssh/
                    else
                        rsync -av --progress ~/.ssh/ "$DST_HOST":~/.ssh/
                    fi
                fi
                ;;
            ssh) 
                if [[ -n "$SSH_CONTROL_SOCKET" ]]; then
                    rsync -av --progress -e "ssh -o ControlPath=$SSH_CONTROL_SOCKET" ~/.ssh/ "$DST_HOST":~/.ssh/
                else
                    rsync -av --progress ~/.ssh/ "$DST_HOST":~/.ssh/
                fi
                ;;
        esac
    else
        # Transfer file by file for Windows/WSL combinations
        get_ssh_files | while read file; do
            [[ -z "$file" ]] && continue
            local content=$(read_from_source "$file")
            write_to_destination "$file" "$content"
        done
    fi
    
    log "Transferred SSH directory contents"
}

# Set permissions on destination
set_permissions() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would set proper permissions"
        return
    fi
    
    log "Setting proper permissions..."
    
    local perm_cmd="
        [[ -f ~/.gitconfig ]] && chmod 644 ~/.gitconfig
        [[ -f ~/.gitignore_global ]] && chmod 644 ~/.gitignore_global
        if [[ -d ~/.ssh ]]; then
            chmod 700 ~/.ssh
            find ~/.ssh -type f -name 'id_*' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true
            find ~/.ssh -type f -name '*_rsa' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true
            find ~/.ssh -type f -name '*_ed25519' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true
            find ~/.ssh -type f -name '*_ecdsa' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true
            find ~/.ssh -type f -name '*.pub' -exec chmod 644 {} \; 2>/dev/null || true
            [[ -f ~/.ssh/config ]] && chmod 600 ~/.ssh/config
            [[ -f ~/.ssh/known_hosts ]] && chmod 644 ~/.ssh/known_hosts
            [[ -f ~/.ssh/authorized_keys ]] && chmod 600 ~/.ssh/authorized_keys
        fi
    "
    
    case "$TO_TYPE" in
        ssh)
            ssh $(get_ssh_opts) "$DST_HOST" "$perm_cmd"
            ;;
        wsl)
            if [[ -n "$TO_DISTRO" ]]; then
                wsl.exe -d "$TO_DISTRO" bash -c "$perm_cmd"
            else
                eval "$perm_cmd"
            fi
            ;;
        windows)
            warn "Windows permissions are different from Unix"
            warn "You may need to set proper ACLs from PowerShell:"
            echo "  icacls \"C:\\Users\\$TO_USER\\.ssh\" /inheritance:r /grant:r \"%USERNAME%:(F)\""
            ;;
    esac
    
    log "Permissions set successfully"
}

# Show summary
show_summary() {
    echo ""
    log "Transfer Summary:"
    echo "  From: $FROM_SPEC"
    echo "  To: $TO_SPEC"
    echo ""
    
    if [[ "$DRY_RUN" == true ]]; then
        warn "This was a dry run - no files were actually transferred"
    else
        log "Transfer completed successfully"
    fi
}

# Show next steps
show_next_steps() {
    if [[ "$DRY_RUN" != true ]]; then
        echo ""
        log "Next steps:"
        echo "  1. Test SSH: ssh -T git@github.com"
        echo "  2. Verify Git: git config --list"
        echo "  3. Remove backups when confirmed working"
        
        if [[ "$TO_TYPE" == "windows" ]]; then
            echo ""
            warn "IMPORTANT: Set Windows SSH permissions from PowerShell:"
            echo "  icacls \"C:\\Users\\$TO_USER\\.ssh\" /inheritance:r"
            echo "  icacls \"C:\\Users\\$TO_USER\\.ssh\" /grant:r \"%USERNAME%:(F)\""
        fi
    fi
}

# Main execution
main() {
    # Set up cleanup trap
    trap cleanup_ssh EXIT
    
    log "Starting transfer from $FROM_SPEC to $TO_SPEC"
    
    if [[ "$DRY_RUN" == true ]]; then
        warn "DRY RUN MODE - No files will be transferred"
    fi
    
    setup_paths
    
    # Check SSH connectivity if needed
    [[ "$TO_TYPE" == "ssh" ]] && check_ssh_connection "$DST_HOST"
    
    create_backup
    transfer_git_config
    transfer_ssh_files
    set_permissions
    
    show_summary
    show_next_steps
    
    # Clean up SSH connection
    cleanup_ssh
}

main "$@"