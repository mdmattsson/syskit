#!/bin/bash
# Transfer Git config and SSH files between machines, WSL, and Windows
# Supports local and remote Windows, WSL, and Linux systems
# Usage: ./transfer-ssh.sh --from SOURCE --to DESTINATION [options]

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
    echo "Local Source/Destination:"
    echo "  linux                    Current Linux machine"
    echo "  wsl                      Current WSL instance"
    echo "  wsl:DISTRO               Specific WSL distribution"
    echo "  windows                  Current Windows user"
    echo "  windows:USERNAME         Specific Windows user"
    echo ""
    echo "Remote Source/Destination:"
    echo "  user@host                Remote Linux via SSH"
    echo "  user@host:windows        Remote Windows via SSH (OpenSSH)"
    echo "  user@host:windows:USER   Remote Windows, specific user"
    echo "  user@host:wsl            Remote WSL default distro"
    echo "  user@host:wsl:DISTRO     Remote WSL specific distro"
    echo ""
    echo "Options:"
    echo "  --dry-run           Show what would be transferred"
    echo "  --git-only          Transfer only Git configuration"
    echo "  --ssh-only          Transfer only SSH files"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Local to remote Linux"
    echo "  $0 --to user@server.com"
    echo ""
    echo "  # Local Linux to remote Windows"
    echo "  $0 --to user@windows-host:windows"
    echo ""
    echo "  # Local Linux to remote WSL"
    echo "  $0 --to user@windows-host:wsl:Ubuntu"
    echo ""
    echo "  # WSL to local Windows"
    echo "  $0 --from wsl --to windows"
    echo ""
    echo "  # Remote Linux to local"
    echo "  $0 --from user@server.com --to linux"
    echo ""
    echo "  # Windows to remote Windows"
    echo "  $0 --from windows --to user@other-windows:windows"
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
        FROM_SPEC="wsl"
        log "Defaulting to current WSL distribution as source"
    elif is_linux; then
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
# Handles: linux, wsl, wsl:distro, windows, windows:user, 
#          user@host, user@host:windows, user@host:windows:user,
#          user@host:wsl, user@host:wsl:distro
parse_location() {
    local spec="$1"
    local var_prefix="$2"
    
    # Check if it contains @, indicating SSH
    if [[ "$spec" == *@* ]]; then
        local ssh_part="${spec%%:*}"  # user@host
        local suffix="${spec#*:}"      # everything after first :
        
        eval "${var_prefix}_SSH_HOST=$ssh_part"
        
        # Check what comes after the @
        if [[ "$suffix" == "$ssh_part" ]]; then
            # No colon, just user@host → remote Linux
            eval "${var_prefix}_TYPE=remote-linux"
        elif [[ "$suffix" == windows:* ]]; then
            # user@host:windows:Username
            eval "${var_prefix}_TYPE=remote-windows"
            eval "${var_prefix}_WIN_USER=${suffix#windows:}"
        elif [[ "$suffix" == "windows" ]]; then
            # user@host:windows
            eval "${var_prefix}_TYPE=remote-windows"
            eval "${var_prefix}_WIN_USER="
        elif [[ "$suffix" == wsl:* ]]; then
            # user@host:wsl:DistroName
            eval "${var_prefix}_TYPE=remote-wsl"
            eval "${var_prefix}_DISTRO=${suffix#wsl:}"
        elif [[ "$suffix" == "wsl" ]]; then
            # user@host:wsl
            eval "${var_prefix}_TYPE=remote-wsl"
            eval "${var_prefix}_DISTRO="
        else
            error "Invalid remote specification: $spec"
            usage
            exit 1
        fi
    elif [[ "$spec" == "linux" ]]; then
        eval "${var_prefix}_TYPE=linux"
    elif [[ "$spec" == windows:* ]]; then
        eval "${var_prefix}_TYPE=windows"
        eval "${var_prefix}_WIN_USER=${spec#*:}"
    elif [[ "$spec" == "windows" ]]; then
        eval "${var_prefix}_TYPE=windows"
        eval "${var_prefix}_WIN_USER="
    elif [[ "$spec" == wsl:* ]]; then
        eval "${var_prefix}_TYPE=wsl"
        eval "${var_prefix}_DISTRO=${spec#*:}"
    elif [[ "$spec" == "wsl" ]]; then
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
    # Check if we're in WSL when needed for local WSL
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
    
    # Local Windows operations require WSL or wsl.exe available
    if [[ "$FROM_TYPE" == "windows" || "$TO_TYPE" == "windows" ]]; then
        if ! is_wsl && ! command -v wsl.exe &>/dev/null; then
            error "Local Windows transfers require running from WSL or having wsl.exe available"
            exit 1
        fi
    fi
}

validate_transfer

# Detect Windows username for local Windows
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

# Detect Windows username on remote Windows via SSH
detect_remote_windows_user() {
    local ssh_host="$1"
    local user_var="$2"
    local ssh_opts_type="$3"  # "from" or "to"
    local current_user
    
    eval "current_user=\$$user_var"
    
    if [[ -n "$current_user" ]]; then
        log "Using specified Windows user: $current_user"
        return
    fi
    
    # Try to get username from remote Windows (works with both PowerShell and cmd.exe)
    current_user=$(ssh $(get_ssh_opts "$ssh_opts_type") "$ssh_host" "echo \$env:USERNAME" | tr -d '\r\n' || true)
    
    if [[ -z "$current_user" || "$current_user" == '$env:USERNAME' ]]; then
        # Fallback to cmd.exe style
        current_user=$(ssh $(get_ssh_opts "$ssh_opts_type") "$ssh_host" "echo %USERNAME%" | tr -d '\r\n' || true)
    fi
    
    if [[ -n "$current_user" && "$current_user" != "%USERNAME%" && "$current_user" != '$env:USERNAME' ]]; then
        eval "$user_var='$current_user'"
        log "Auto-detected remote Windows user: $current_user"
        return
    fi
    
    error "Could not auto-detect remote Windows username"
    error "Please specify: user@host:windows:USERNAME"
    exit 1
}

# Get Windows paths for local Windows
get_local_windows_paths() {
    local user="$1"
    local prefix="$2"
    
    if is_wsl; then
        eval "${prefix}_SSH=\"/mnt/c/Users/$user/.ssh\""
        eval "${prefix}_GITCONFIG=\"/mnt/c/Users/$user/.gitconfig\""
        eval "${prefix}_GITIGNORE=\"/mnt/c/Users/$user/.gitignore_global\""
    else
        error "Cannot access local Windows paths from non-WSL environment"
        exit 1
    fi
}

# Setup paths
setup_paths() {
    case "$FROM_TYPE" in
        windows)
            detect_windows_user "FROM_WIN_USER"
            get_local_windows_paths "$FROM_WIN_USER" "SRC"
            ;;
        wsl)
            [[ -n "$FROM_DISTRO" ]] && log "Using WSL distribution: $FROM_DISTRO"
            SRC_SSH="$HOME/.ssh"
            SRC_GITCONFIG="$HOME/.gitconfig"
            SRC_GITIGNORE="$HOME/.gitignore_global"
            ;;
        linux)
            SRC_SSH="$HOME/.ssh"
            SRC_GITCONFIG="$HOME/.gitconfig"
            SRC_GITIGNORE="$HOME/.gitignore_global"
            ;;
        remote-linux)
            SRC_SSH="\$HOME/.ssh"
            SRC_GITCONFIG="\$HOME/.gitconfig"
            SRC_GITIGNORE="\$HOME/.gitignore_global"
            ;;
        remote-windows)
            detect_remote_windows_user "$FROM_SSH_HOST" "FROM_WIN_USER" "from"
            # Windows OpenSSH uses forward slashes
            SRC_SSH="C:/Users/$FROM_WIN_USER/.ssh"
            SRC_GITCONFIG="C:/Users/$FROM_WIN_USER/.gitconfig"
            SRC_GITIGNORE="C:/Users/$FROM_WIN_USER/.gitignore_global"
            ;;
        remote-wsl)
            # WSL paths accessed via wsl.exe on remote Windows
            [[ -n "$FROM_DISTRO" ]] && log "Using remote WSL distribution: $FROM_DISTRO"
            SRC_SSH="\$HOME/.ssh"
            SRC_GITCONFIG="\$HOME/.gitconfig"
            SRC_GITIGNORE="\$HOME/.gitignore_global"
            ;;
    esac
    
    case "$TO_TYPE" in
        windows)
            detect_windows_user "TO_WIN_USER"
            get_local_windows_paths "$TO_WIN_USER" "DST"
            ;;
        wsl)
            [[ -n "$TO_DISTRO" ]] && log "Using WSL distribution: $TO_DISTRO"
            DST_SSH="$HOME/.ssh"
            DST_GITCONFIG="$HOME/.gitconfig"
            DST_GITIGNORE="$HOME/.gitignore_global"
            ;;
        linux)
            DST_SSH="$HOME/.ssh"
            DST_GITCONFIG="$HOME/.gitconfig"
            DST_GITIGNORE="$HOME/.gitignore_global"
            ;;
        remote-linux)
            DST_SSH="\$HOME/.ssh"
            DST_GITCONFIG="\$HOME/.gitconfig"
            DST_GITIGNORE="\$HOME/.gitignore_global"
            ;;
        remote-windows)
            detect_remote_windows_user "$TO_SSH_HOST" "TO_WIN_USER" "to"
            # Windows OpenSSH uses forward slashes
            DST_SSH="C:/Users/$TO_WIN_USER/.ssh"
            DST_GITCONFIG="C:/Users/$TO_WIN_USER/.gitconfig"
            DST_GITIGNORE="C:/Users/$TO_WIN_USER/.gitignore_global"
            ;;
        remote-wsl)
            # WSL paths accessed via wsl.exe on remote Windows
            [[ -n "$TO_DISTRO" ]] && log "Using remote WSL distribution: $TO_DISTRO"
            DST_SSH="\$HOME/.ssh"
            DST_GITCONFIG="\$HOME/.gitconfig"
            DST_GITIGNORE="\$HOME/.gitignore_global"
            ;;
    esac
}

# SSH connection management
SSH_CONTROL_SOCKET=""
SSH_FROM_CONTROL_PATH="/tmp/ssh-transfer-from-$$"
SSH_TO_CONTROL_PATH="/tmp/ssh-transfer-to-$$"

setup_ssh_connection() {
    local host="$1"
    local control_path="$2"
    
    log "Setting up persistent SSH connection to $host..."
    info "This will allow reusing the connection for multiple transfers"
    
    mkdir -p "$(dirname "$control_path")"
    
    # Start master connection (may prompt for password if not using keys)
    # Don't suppress stderr so password prompts are visible
    if ssh -o ControlMaster=yes \
        -o ControlPath="$control_path" \
        -o ControlPersist=10m \
        -fN "$host"; then
        log "Persistent SSH connection established (will reuse for all transfers)"
        return 0
    else
        warn "Could not establish SSH master connection (multiplexing disabled)"
        warn "Each file may prompt for authentication separately"
        return 1
    fi
}

cleanup_ssh() {
    if [[ -n "$SSH_FROM_CONTROL_PATH" && -S "$SSH_FROM_CONTROL_PATH" ]]; then
        ssh -O exit -o ControlPath="$SSH_FROM_CONTROL_PATH" "$FROM_SSH_HOST" 2>/dev/null || true
        rm -f "$SSH_FROM_CONTROL_PATH"
    fi
    if [[ -n "$SSH_TO_CONTROL_PATH" && -S "$SSH_TO_CONTROL_PATH" ]]; then
        ssh -O exit -o ControlPath="$SSH_TO_CONTROL_PATH" "$TO_SSH_HOST" 2>/dev/null || true
        rm -f "$SSH_TO_CONTROL_PATH"
    fi
}

get_ssh_opts() {
    local host_type="$1"  # "from" or "to"
    
    if [[ "$host_type" == "from" && -S "$SSH_FROM_CONTROL_PATH" ]]; then
        echo "-o ControlPath=$SSH_FROM_CONTROL_PATH"
    elif [[ "$host_type" == "to" && -S "$SSH_TO_CONTROL_PATH" ]]; then
        echo "-o ControlPath=$SSH_TO_CONTROL_PATH"
    fi
}

check_ssh_connection() {
    local host="$1"
    local control_path="$2"
    
    log "Setting up SSH connection to $host..."
    info "This establishes a persistent connection for all file transfers"
    
    mkdir -p "$(dirname "$control_path")"
    
    # Start master connection - this will prompt for password once if needed
    # The -f backgrounds it, -N means no command, ControlMaster creates the socket
    if ssh -o ControlMaster=yes \
           -o ControlPath="$control_path" \
           -o ControlPersist=10m \
           -o ConnectTimeout=10 \
           -fN "$host"; then
        log "Persistent SSH connection established successfully"
        log "All file transfers will reuse this connection (no more password prompts)"
        return 0
    else
        error "Cannot establish SSH connection to $host"
        error "Please check:"
        echo "  1. Host is reachable"
        echo "  2. SSH credentials are correct (password or keys)"
        echo "  3. SSH daemon is running on target"
        exit 1
    fi
}

# Execute command on remote host
remote_exec() {
    local location_type="$1"
    local ssh_host="$2"
    local distro="$3"
    local command="$4"
    local ssh_opts_type="$5"  # "from" or "to"
    
    case "$location_type" in
        remote-linux)
            ssh $(get_ssh_opts "$ssh_opts_type") "$ssh_host" "$command"
            ;;
        remote-windows)
            # Execute on Windows via SSH using PowerShell
            # Convert Unix commands to PowerShell equivalents
            local ps_command="$command"
            
            # Convert common Unix commands to PowerShell
            # cat file -> Get-Content file
            if [[ "$command" =~ ^cat[[:space:]] ]]; then
                local filepath="${command#cat }"
                ps_command="Get-Content -Raw '$filepath'"
            # test -f file -> Test-Path file
            elif [[ "$command" =~ ^test[[:space:]]+-f[[:space:]] ]]; then
                local filepath="${command#test -f }"
                ps_command="Test-Path -PathType Leaf '$filepath'"
            # test -d dir -> Test-Path dir
            elif [[ "$command" =~ ^test[[:space:]]+-d[[:space:]] ]]; then
                local dirpath="${command#test -d }"
                ps_command="Test-Path -PathType Container '$dirpath'"
            # find dir -type f -> Get-ChildItem -File -Recurse
            elif [[ "$command" =~ ^find[[:space:]] ]]; then
                local dirpath=$(echo "$command" | awk '{print $2}')
                ps_command="Get-ChildItem -Path '$dirpath' -File -Recurse | ForEach-Object { \$_.FullName.Replace('$dirpath\\', '').Replace('\\', '/') }"
            # mkdir -p dir -> New-Item -ItemType Directory -Force
            elif [[ "$command" =~ ^mkdir[[:space:]]+-p[[:space:]] ]]; then
                local dirpath="${command#mkdir -p }"
                ps_command="New-Item -ItemType Directory -Force -Path '$dirpath' | Out-Null"
            fi
            
            ssh $(get_ssh_opts "$ssh_opts_type") "$ssh_host" "powershell.exe -Command \"$ps_command\""
            ;;
        remote-wsl)
            # Execute in WSL on remote Windows
            if [[ -n "$distro" ]]; then
                ssh $(get_ssh_opts "$ssh_opts_type") "$ssh_host" "wsl.exe -d $distro bash -c '$command'"
            else
                ssh $(get_ssh_opts "$ssh_opts_type") "$ssh_host" "wsl.exe bash -c '$command'"
            fi
            ;;
    esac
}

# Check if file exists
file_exists() {
    local location_type="$1"
    local filepath="$2"
    local ssh_host="$3"
    local distro="$4"
    local ssh_opts_type="$5"
    
    case "$location_type" in
        linux|wsl)
            [[ -f "$filepath" ]]
            ;;
        windows)
            [[ -f "$filepath" ]]
            ;;
        remote-linux)
            remote_exec "$location_type" "$ssh_host" "" "test -f $filepath" "$ssh_opts_type" 2>/dev/null
            ;;
        remote-windows)
            # Windows OpenSSH test
            remote_exec "$location_type" "$ssh_host" "" "test -f $filepath" "$ssh_opts_type" 2>/dev/null
            ;;
        remote-wsl)
            remote_exec "$location_type" "$ssh_host" "$distro" "test -f $filepath" "$ssh_opts_type" 2>/dev/null
            ;;
    esac
}

# Check if directory exists
dir_exists() {
    local location_type="$1"
    local dirpath="$2"
    local ssh_host="$3"
    local distro="$4"
    local ssh_opts_type="$5"
    
    case "$location_type" in
        linux|wsl)
            [[ -d "$dirpath" ]]
            ;;
        windows)
            [[ -d "$dirpath" ]]
            ;;
        remote-linux)
            remote_exec "$location_type" "$ssh_host" "" "test -d $dirpath" "$ssh_opts_type" 2>/dev/null
            ;;
        remote-windows)
            remote_exec "$location_type" "$ssh_host" "" "test -d $dirpath" "$ssh_opts_type" 2>/dev/null
            ;;
        remote-wsl)
            remote_exec "$location_type" "$ssh_host" "$distro" "test -d $dirpath" "$ssh_opts_type" 2>/dev/null
            ;;
    esac
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
        remote-linux)
            case "$file" in
                gitconfig) remote_exec "$FROM_TYPE" "$FROM_SSH_HOST" "" "cat $SRC_GITCONFIG" "from" 2>/dev/null ;;
                gitignore) remote_exec "$FROM_TYPE" "$FROM_SSH_HOST" "" "cat $SRC_GITIGNORE" "from" 2>/dev/null ;;
                *) remote_exec "$FROM_TYPE" "$FROM_SSH_HOST" "" "cat $SRC_SSH/$file" "from" 2>/dev/null ;;
            esac
            ;;
        remote-windows)
            case "$file" in
                gitconfig) remote_exec "$FROM_TYPE" "$FROM_SSH_HOST" "" "cat $SRC_GITCONFIG" "from" 2>/dev/null ;;
                gitignore) remote_exec "$FROM_TYPE" "$FROM_SSH_HOST" "" "cat $SRC_GITIGNORE" "from" 2>/dev/null ;;
                *) remote_exec "$FROM_TYPE" "$FROM_SSH_HOST" "" "cat $SRC_SSH/$file" "from" 2>/dev/null ;;
            esac
            ;;
        remote-wsl)
            case "$file" in
                gitconfig) remote_exec "$FROM_TYPE" "$FROM_SSH_HOST" "$FROM_DISTRO" "cat ~/.gitconfig" "from" 2>/dev/null ;;
                gitignore) remote_exec "$FROM_TYPE" "$FROM_SSH_HOST" "$FROM_DISTRO" "cat ~/.gitignore_global" "from" 2>/dev/null ;;
                *) remote_exec "$FROM_TYPE" "$FROM_SSH_HOST" "$FROM_DISTRO" "cat ~/.ssh/$file" "from" 2>/dev/null ;;
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
        remote-linux)
            case "$file" in
                gitconfig) echo "$content" | remote_exec "$TO_TYPE" "$TO_SSH_HOST" "" "cat > $DST_GITCONFIG" "to" ;;
                gitignore) echo "$content" | remote_exec "$TO_TYPE" "$TO_SSH_HOST" "" "cat > $DST_GITIGNORE" "to" ;;
                *) echo "$content" | remote_exec "$TO_TYPE" "$TO_SSH_HOST" "" "cat > $DST_SSH/$file" "to" ;;
            esac
            ;;
        remote-windows)
            # For Windows, use PowerShell's Console.In to read from stdin
            # This avoids complex quoting issues with $input variable
            case "$file" in
                gitconfig) 
                    echo "$content" | ssh $(get_ssh_opts "to") "$TO_SSH_HOST" \
                        "powershell.exe -Command \"[Console]::In.ReadToEnd() | Set-Content -Path '$DST_GITCONFIG' -NoNewline\""
                    ;;
                gitignore) 
                    echo "$content" | ssh $(get_ssh_opts "to") "$TO_SSH_HOST" \
                        "powershell.exe -Command \"[Console]::In.ReadToEnd() | Set-Content -Path '$DST_GITIGNORE' -NoNewline\""
                    ;;
                *) 
                    echo "$content" | ssh $(get_ssh_opts "to") "$TO_SSH_HOST" \
                        "powershell.exe -Command \"[Console]::In.ReadToEnd() | Set-Content -Path '$DST_SSH/$file' -NoNewline\""
                    ;;
            esac
            ;;
        remote-wsl)
            case "$file" in
                gitconfig) echo "$content" | remote_exec "$TO_TYPE" "$TO_SSH_HOST" "$TO_DISTRO" "cat > ~/.gitconfig" "to" ;;
                gitignore) echo "$content" | remote_exec "$TO_TYPE" "$TO_SSH_HOST" "$TO_DISTRO" "cat > ~/.gitignore_global" "to" ;;
                *) echo "$content" | remote_exec "$TO_TYPE" "$TO_SSH_HOST" "$TO_DISTRO" "cat > ~/.ssh/$file" "to" ;;
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
    
    local backup_cmd="
        [[ -f ~/.gitconfig ]] && cp ~/.gitconfig ~/.gitconfig$backup_suffix 2>/dev/null || true
        [[ -f ~/.gitignore_global ]] && cp ~/.gitignore_global ~/.gitignore_global$backup_suffix 2>/dev/null || true
        [[ -d ~/.ssh ]] && cp -r ~/.ssh ~/.ssh$backup_suffix 2>/dev/null || true
    "
    
    local win_backup_cmd="
        if exist C:\\Users\\%USERNAME%\\.gitconfig copy C:\\Users\\%USERNAME%\\.gitconfig C:\\Users\\%USERNAME%\\.gitconfig$backup_suffix
        if exist C:\\Users\\%USERNAME%\\.ssh xcopy C:\\Users\\%USERNAME%\\.ssh C:\\Users\\%USERNAME%\\.ssh$backup_suffix /E /I /Q
    "
    
    case "$TO_TYPE" in
        remote-linux)
            remote_exec "$TO_TYPE" "$TO_SSH_HOST" "" "$backup_cmd" "to" || true
            ;;
        remote-windows)
            # Windows doesn't handle bash commands well, skip backup or use PowerShell
            warn "Skipping backup on remote Windows (implement PowerShell commands if needed)"
            ;;
        remote-wsl)
            remote_exec "$TO_TYPE" "$TO_SSH_HOST" "$TO_DISTRO" "$backup_cmd" "to" || true
            ;;
        wsl)
            if [[ -n "$TO_DISTRO" ]]; then
                wsl.exe -d "$TO_DISTRO" bash -c "$backup_cmd" || true
            else
                eval "$backup_cmd" || true
            fi
            ;;
        linux)
            eval "$backup_cmd" || true
            ;;
        windows)
            [[ -f "$DST_GITCONFIG" ]] && cp "$DST_GITCONFIG" "$DST_GITCONFIG$backup_suffix" 2>/dev/null || true
            [[ -f "$DST_GITIGNORE" ]] && cp "$DST_GITIGNORE" "$DST_GITIGNORE$backup_suffix" 2>/dev/null || true
            [[ -d "$DST_SSH" ]] && cp -r "$DST_SSH" "$DST_SSH$backup_suffix" 2>/dev/null || true
            ;;
    esac
    
    log "Backup attempt completed"
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
        linux|wsl)
            file_exists "$FROM_TYPE" "$SRC_GITCONFIG" "" "" "" && has_gitconfig=true
            ;;
        windows)
            [[ -f "$SRC_GITCONFIG" ]] && has_gitconfig=true
            ;;
        remote-*)
            file_exists "$FROM_TYPE" "$SRC_GITCONFIG" "$FROM_SSH_HOST" "$FROM_DISTRO" "from" && has_gitconfig=true
            ;;
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
    local content=$(read_from_source "gitconfig")
    if [[ -n "$content" ]]; then
        write_to_destination "gitconfig" "$content"
        log "Transferred .gitconfig"
    fi
    
    # Transfer .gitignore_global if it exists
    local has_gitignore=false
    
    case "$FROM_TYPE" in
        linux|wsl)
            file_exists "$FROM_TYPE" "$SRC_GITIGNORE" "" "" "" && has_gitignore=true
            ;;
        windows)
            [[ -f "$SRC_GITIGNORE" ]] && has_gitignore=true
            ;;
        remote-*)
            file_exists "$FROM_TYPE" "$SRC_GITIGNORE" "$FROM_SSH_HOST" "$FROM_DISTRO" "from" && has_gitignore=true
            ;;
    esac
    
    if [[ "$has_gitignore" == true ]]; then
        content=$(read_from_source "gitignore")
        if [[ -n "$content" ]]; then
            write_to_destination "gitignore" "$content"
            log "Transferred .gitignore_global"
        fi
    fi
}

# Get list of SSH files from source
get_ssh_files() {
    case "$FROM_TYPE" in
        windows)
            find "$SRC_SSH" -type f 2>/dev/null | sed "s|$SRC_SSH/||" | sed 's|\\|/|g'
            ;;
        wsl)
            if [[ -n "$FROM_DISTRO" ]]; then
                wsl.exe -d "$FROM_DISTRO" bash -c "find ~/.ssh -type f 2>/dev/null | sed 's|^.*/\.ssh/||'"
            else
                find ~/.ssh -type f 2>/dev/null | sed 's|^.*/\.ssh/||'
            fi
            ;;
        linux)
            find ~/.ssh -type f 2>/dev/null | sed 's|^.*/\.ssh/||'
            ;;
        remote-linux|remote-windows)
            remote_exec "$FROM_TYPE" "$FROM_SSH_HOST" "" "find $SRC_SSH -type f 2>/dev/null | sed 's|^.*/\.ssh/||'" "from"
            ;;
        remote-wsl)
            remote_exec "$FROM_TYPE" "$FROM_SSH_HOST" "$FROM_DISTRO" "find ~/.ssh -type f 2>/dev/null | sed 's|^.*/\.ssh/||'" "from"
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
        linux|wsl)
            dir_exists "$FROM_TYPE" "$SRC_SSH" "" "" "" && has_ssh=true
            ;;
        windows)
            [[ -d "$SRC_SSH" ]] && has_ssh=true
            ;;
        remote-*)
            dir_exists "$FROM_TYPE" "$SRC_SSH" "$FROM_SSH_HOST" "$FROM_DISTRO" "from" && has_ssh=true
            ;;
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
        remote-linux|remote-windows)
            remote_exec "$TO_TYPE" "$TO_SSH_HOST" "" "mkdir -p $DST_SSH" "to"
            ;;
        remote-wsl)
            remote_exec "$TO_TYPE" "$TO_SSH_HOST" "$TO_DISTRO" "mkdir -p ~/.ssh" "to"
            ;;
        wsl)
            if [[ -n "$TO_DISTRO" ]]; then
                wsl.exe -d "$TO_DISTRO" bash -c "mkdir -p ~/.ssh"
            else
                mkdir -p ~/.ssh
            fi
            ;;
        linux)
            mkdir -p ~/.ssh
            ;;
        windows)
            mkdir -p "$DST_SSH"
            ;;
    esac
    
    # Transfer SSH files
    get_ssh_files | while read file; do
        [[ -z "$file" ]] && continue
        local content=$(read_from_source "$file")
        if [[ -n "$content" ]]; then
            write_to_destination "$file" "$content"
            info "Transferred: $file"
        fi
    done
    
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
        [[ -f ~/.gitconfig ]] && chmod 644 ~/.gitconfig 2>/dev/null || true
        [[ -f ~/.gitignore_global ]] && chmod 644 ~/.gitignore_global 2>/dev/null || true
        if [[ -d ~/.ssh ]]; then
            chmod 700 ~/.ssh 2>/dev/null || true
            find ~/.ssh -type f -name 'id_*' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true
            find ~/.ssh -type f -name '*_rsa' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true
            find ~/.ssh -type f -name '*_ed25519' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true
            find ~/.ssh -type f -name '*_ecdsa' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true
            find ~/.ssh -type f -name '*.pub' -exec chmod 644 {} \; 2>/dev/null || true
            [[ -f ~/.ssh/config ]] && chmod 600 ~/.ssh/config 2>/dev/null || true
            [[ -f ~/.ssh/known_hosts ]] && chmod 644 ~/.ssh/known_hosts 2>/dev/null || true
            [[ -f ~/.ssh/authorized_keys ]] && chmod 600 ~/.ssh/authorized_keys 2>/dev/null || true
        fi
    "
    
    case "$TO_TYPE" in
        remote-linux)
            remote_exec "$TO_TYPE" "$TO_SSH_HOST" "" "$perm_cmd" "to"
            ;;
        remote-windows)
            warn "Windows permissions handling not implemented for OpenSSH"
            warn "You may need to set proper ACLs manually"
            ;;
        remote-wsl)
            remote_exec "$TO_TYPE" "$TO_SSH_HOST" "$TO_DISTRO" "$perm_cmd" "to"
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
            warn "You may need to set proper ACLs from PowerShell"
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
    fi
}

# Main execution
main() {
    trap cleanup_ssh EXIT
    
    log "Starting transfer from $FROM_SPEC to $TO_SPEC"
    
    if [[ "$DRY_RUN" == true ]]; then
        warn "DRY RUN MODE - No files will be transferred"
    fi
    
    # Check SSH connectivity FIRST and set up multiplexing
    # This way setup_paths can reuse the connection
    case "$FROM_TYPE" in
        remote-*) check_ssh_connection "$FROM_SSH_HOST" "$SSH_FROM_CONTROL_PATH" ;;
    esac
    
    case "$TO_TYPE" in
        remote-*) check_ssh_connection "$TO_SSH_HOST" "$SSH_TO_CONTROL_PATH" ;;
    esac
    
    # Now setup paths (this may SSH to detect Windows username, but will use multiplexed connection)
    setup_paths
    
    create_backup
    transfer_git_config
    transfer_ssh_files
    set_permissions
    
    show_summary
    show_next_steps
    
    cleanup_ssh
}

main "$@"