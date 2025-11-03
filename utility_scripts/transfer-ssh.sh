#!/bin/bash
# Transfer Git config and SSH files between machines, WSL, and Windows
# Usage: ./transfer-config.sh [--from SOURCE] --to DESTINATION [options]

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
    echo "  linux                Current Linux machine"
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
    echo "  # Linux to remote"
    echo "  $0 --from linux --to michael@192.168.1.100"
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

# Detect if running on native Linux
is_linux() {
    [[ -f /proc/version ]] && ! is_wsl
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
    elif is_linux; then
        # Native Linux system
        FROM_SPEC="linux"
        log "Defaulting to current Linux system as source"
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
    elif [[ "$spec" == "linux" ]]; then
        # Native Linux (treated like WSL without distro)
        eval "${var_prefix}_TYPE=linux"
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
    
    # Check if we're on Linux when needed
    if [[ "$FROM_TYPE" == "linux" ]]; then
        if ! is_linux; then
            error "--from linux requires running on a native Linux system"
            exit 1
        fi
    fi
    
    if [[ "$TO_TYPE" == "linux" ]]; then
        if ! is_linux; then
            error "--to linux requires running on a native Linux system"
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
    
    if is_wsl; then
        eval "${prefix}_SSH=\"/mnt/c/Users/$user/.ssh\""
        eval "${prefix}_GITCONFIG=\"/mnt/c/Users/$user/.gitconfig\""
        eval "${prefix}_GITIGNORE=\"/mnt/c/Users/$user/.gitignore_global\""
    else
        error "Cannot access Windows paths from non-WSL environment"
        exit 1
    fi
}

# Setup paths
setup_paths() {
    # Setup source paths
    case "$FROM_TYPE" in
        windows)
            detect_windows_user "FROM_USER"
            get_windows_paths "$FROM_USER" "SRC"
            ;;
        wsl)
            if [[ -n "$FROM_DISTRO" ]]; then
                log "Using WSL distribution: $FROM_DISTRO"
            fi
            SRC_SSH="$HOME/.ssh"
            SRC_GITCONFIG="$HOME/.gitconfig"
            SRC_GITIGNORE="$HOME/.gitignore_global"
            ;;
        linux)
            SRC_SSH="$HOME/.ssh"
            SRC_GITCONFIG="$HOME/.gitconfig"
            SRC_GITIGNORE="$HOME/.gitignore_global"
            ;;
        ssh)
            SRC_SSH="$HOME/.ssh"
            SRC_GITCONFIG="$HOME/.gitconfig"
            SRC_GITIGNORE="$HOME/.gitignore_global"
            DST_HOST="$FROM_HOST"
            ;;
    esac
    
    # Setup destination paths
    case "$TO_TYPE" in
        windows)
            detect_windows_user "TO_USER"
            get_windows_paths "$TO_USER" "DST"
            ;;
        wsl)
            if [[ -n "$TO_DISTRO" ]]; then
                log "Using WSL distribution: $TO_DISTRO"
            fi
            DST_SSH="$HOME/.ssh"
            DST_GITCONFIG="$HOME/.gitconfig"
            DST_GITIGNORE="$HOME/.gitignore_global"
            ;;
        linux)
            DST_SSH="$HOME/.ssh"
            DST_GITCONFIG="$HOME/.gitconfig"
            DST_GITIGNORE="$HOME/.gitignore_global"
            ;;
        ssh)
            DST_SSH="$HOME/.ssh"
            DST_GITCONFIG="$HOME/.gitconfig"
            DST_GITIGNORE="$HOME/.gitignore_global"
            DST_HOST="$TO_HOST"
            ;;
    esac
}

# SSH connection management
SSH_CONTROL_SOCKET=""
SSH_CONTROL_PATH="/tmp/ssh-transfer-$$"

setup_ssh_connection() {
    local host="$1"
    
    log "Setting up SSH connection to $host..."
    
    # Create control socket
    mkdir -p "$(dirname "$SSH_CONTROL_PATH")"
    
    # Start master connection
    ssh -o ControlMaster=yes \
        -o ControlPath="$SSH_CONTROL_PATH" \
        -o ControlPersist=10m \
        -fN "$host" 2>/dev/null || {
        warn "Could not establish SSH master connection"
        return 1
    }
    
    SSH_CONTROL_SOCKET="$SSH_CONTROL_PATH"
    log "SSH connection established"
}

cleanup_ssh() {
    if [[ -n "$SSH_CONTROL_SOCKET" && -S "$SSH_CONTROL_SOCKET" ]]; then
        log "Cleaning up SSH connection..."
        ssh -O exit -o ControlPath="$SSH_CONTROL_SOCKET" "$DST_HOST" 2>/dev/null || true
        rm -f "$SSH_CONTROL_SOCKET"
    fi
}

get_ssh_opts() {
    if [[ -n "$SSH_CONTROL_SOCKET" ]]; then
        echo "-o ControlPath=$SSH_CONTROL_SOCKET"
    fi
}

check_ssh_connection() {
    local host="$1"
    
    log "Testing SSH connection to $host..."
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$host" exit 2>/dev/null; then
        log "SSH connection successful"
        setup_ssh_connection "$host"
        return 0
    else
        error "Cannot connect to $host via SSH"
        error "Please check:"
        echo "  1. Host is reachable"
        echo "  2. SSH keys are set up"
        echo "  3. SSH daemon is running on target"
        exit 1
    fi
}

# Read file from source
read_from_source() {
    local file="$1"
    
    case "$FROM_TYPE" in
        windows)
            case "$file" in
                gitconfig) cat "$SRC_GITCONFIG" 2>/dev/null ;;
                gitignore) cat "$SRC_GITIGNORE" 2>/dev/null ;;
                *) cat "$SRC_SSH/$file" 2>/dev/null ;;
            esac
            ;;
        wsl)
            if [[ -n "$FROM_DISTRO" ]]; then
                case "$file" in
                    gitconfig) wsl.exe -d "$FROM_DISTRO" bash -c "cat ~/.gitconfig" 2>/dev/null ;;
                    gitignore) wsl.exe -d "$FROM_DISTRO" bash -c "cat ~/.gitignore_global" 2>/dev/null ;;
                    *) wsl.exe -d "$FROM_DISTRO" bash -c "cat ~/.ssh/$file" 2>/dev/null ;;
                esac
            else
                case "$file" in
                    gitconfig) cat ~/.gitconfig 2>/dev/null ;;
                    gitignore) cat ~/.gitignore_global 2>/dev/null ;;
                    *) cat ~/.ssh/"$file" 2>/dev/null ;;
                esac
            fi
            ;;
        linux)
            case "$file" in
                gitconfig) cat ~/.gitconfig 2>/dev/null ;;
                gitignore) cat ~/.gitignore_global 2>/dev/null ;;
                *) cat ~/.ssh/"$file" 2>/dev/null ;;
            esac
            ;;
        ssh)
            case "$file" in
                gitconfig) ssh $(get_ssh_opts) "$FROM_HOST" "cat ~/.gitconfig" 2>/dev/null ;;
                gitignore) ssh $(get_ssh_opts) "$FROM_HOST" "cat ~/.gitignore_global" 2>/dev/null ;;
                *) ssh $(get_ssh_opts) "$FROM_HOST" "cat ~/.ssh/$file" 2>/dev/null ;;
            esac
            ;;
    esac
}

# Write file to destination
write_to_destination() {
    local file="$1"
    local content="$2"
    
    case "$TO_TYPE" in
        windows)
            case "$file" in
                gitconfig) echo "$content" > "$DST_GITCONFIG" ;;
                gitignore) echo "$content" > "$DST_GITIGNORE" ;;
                *) echo "$content" > "$DST_SSH/$file" ;;
            esac
            ;;
        wsl)
            if [[ -n "$TO_DISTRO" ]]; then
                case "$file" in
                    gitconfig) echo "$content" | wsl.exe -d "$TO_DISTRO" bash -c "cat > ~/.gitconfig" ;;
                    gitignore) echo "$content" | wsl.exe -d "$TO_DISTRO" bash -c "cat > ~/.gitignore_global" ;;
                    *) echo "$content" | wsl.exe -d "$TO_DISTRO" bash -c "cat > ~/.ssh/$file" ;;
                esac
            else
                case "$file" in
                    gitconfig) echo "$content" > ~/.gitconfig ;;
                    gitignore) echo "$content" > ~/.gitignore_global ;;
                    *) echo "$content" > ~/.ssh/"$file" ;;
                esac
            fi
            ;;
        linux)
            case "$file" in
                gitconfig) echo "$content" > ~/.gitconfig ;;
                gitignore) echo "$content" > ~/.gitignore_global ;;
                *) echo "$content" > ~/.ssh/"$file" ;;
            esac
            ;;
        ssh)
            case "$file" in
                gitconfig) echo "$content" | ssh $(get_ssh_opts) "$TO_HOST" "cat > ~/.gitconfig" ;;
                gitignore) echo "$content" | ssh $(get_ssh_opts) "$TO_HOST" "cat > ~/.gitignore_global" ;;
                *) echo "$content" | ssh $(get_ssh_opts) "$TO_HOST" "cat > ~/.ssh/$file" ;;
            esac
            ;;
    esac
}

# Create backup
create_backup() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would create backups of existing files"
        return
    fi
    
    log "Creating backups of existing files..."
    
    local backup_suffix=".backup-$(date +%Y%m%d-%H%M%S)"
    
    case "$TO_TYPE" in
        ssh)
            ssh $(get_ssh_opts) "$DST_HOST" "
                [[ -f ~/.gitconfig ]] && cp ~/.gitconfig ~/.gitconfig$backup_suffix
                [[ -f ~/.gitignore_global ]] && cp ~/.gitignore_global ~/.gitignore_global$backup_suffix
                [[ -d ~/.ssh ]] && cp -r ~/.ssh ~/.ssh$backup_suffix
            " 2>/dev/null || true
            ;;
        wsl)
            if [[ -n "$TO_DISTRO" ]]; then
                wsl.exe -d "$TO_DISTRO" bash -c "
                    [[ -f ~/.gitconfig ]] && cp ~/.gitconfig ~/.gitconfig$backup_suffix
                    [[ -f ~/.gitignore_global ]] && cp ~/.gitignore_global ~/.gitignore_global$backup_suffix
                    [[ -d ~/.ssh ]] && cp -r ~/.ssh ~/.ssh$backup_suffix
                " 2>/dev/null || true
            else
                [[ -f ~/.gitconfig ]] && cp ~/.gitconfig ~/.gitconfig$backup_suffix
                [[ -f ~/.gitignore_global ]] && cp ~/.gitignore_global ~/.gitignore_global$backup_suffix
                [[ -d ~/.ssh ]] && cp -r ~/.ssh ~/.ssh$backup_suffix 2>/dev/null || true
            fi
            ;;
        linux)
            [[ -f ~/.gitconfig ]] && cp ~/.gitconfig ~/.gitconfig$backup_suffix
            [[ -f ~/.gitignore_global ]] && cp ~/.gitignore_global ~/.gitignore_global$backup_suffix
            [[ -d ~/.ssh ]] && cp -r ~/.ssh ~/.ssh$backup_suffix 2>/dev/null || true
            ;;
        windows)
            [[ -f "$DST_GITCONFIG" ]] && cp "$DST_GITCONFIG" "$DST_GITCONFIG$backup_suffix"
            [[ -f "$DST_GITIGNORE" ]] && cp "$DST_GITIGNORE" "$DST_GITIGNORE$backup_suffix"
            [[ -d "$DST_SSH" ]] && cp -r "$DST_SSH" "$DST_SSH$backup_suffix" 2>/dev/null || true
            ;;
    esac
    
    log "Backups created with suffix: $backup_suffix"
}

# Transfer Git config
transfer_git_config() {
    if [[ "$SSH_ONLY" == true ]]; then
        return
    fi
    
    log "Transferring Git configuration..."
    
    # Check if source .gitconfig exists
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
        linux) [[ -f ~/.gitconfig ]] && has_gitconfig=true ;;
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
    
    # Transfer .gitconfig
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
            linux) scp $(get_ssh_opts) ~/.gitconfig "$DST_HOST":~/ ;;
        esac
    else
        local content=$(read_from_source "gitconfig")
        write_to_destination "gitconfig" "$content"
    fi
    
    log "Transferred .gitconfig"
    
    # Transfer .gitignore_global if it exists
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
        linux) [[ -f ~/.gitignore_global ]] && has_gitignore=true ;;
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
                linux) scp $(get_ssh_opts) ~/.gitignore_global "$DST_HOST":~/ ;;
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
        linux)
            find ~/.ssh -type f 2>/dev/null | sed 's|^.*/\.ssh/||'
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
        linux) [[ -d ~/.ssh ]] && has_ssh=true ;;
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
        linux) mkdir -p ~/.ssh ;;
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
            linux)
                if [[ -n "$SSH_CONTROL_SOCKET" ]]; then
                    rsync -av --progress -e "ssh -o ControlPath=$SSH_CONTROL_SOCKET" ~/.ssh/ "$DST_HOST":~/.ssh/
                else
                    rsync -av --progress ~/.ssh/ "$DST_HOST":~/.ssh/
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
        linux)
            eval "$perm_cmd"
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