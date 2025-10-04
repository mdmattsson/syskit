#!/bin/bash
# SysKit - Advanced Linux System Setup
# Version: 1.0.0.1
# Author: Michael Mattsson
# Repository: https://github.com/mdmattsson/syskit
# Website: https://www.syskit.org

# CRITICAL: Reset terminal state immediately (important after exec)
stty sane 2>/dev/null || true

set -e

# Only set error trap during installation, not normal operation
# This gets removed after installation completes
ERROR_LOG="/tmp/syskit-error-$$.log"


# Resolve symlinks to get actual script location
if [[ -L "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
else
    SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# Configuration
USERS_HOME=$HOME
EXPECTED_DIR="$USERS_HOME/.config/syskit"
MENU_DIR="$EXPECTED_DIR/menu"
CONFIG_DIR="$EXPECTED_DIR/cfg"
LOGS_DIR="$EXPECTED_DIR/logs"
VERSION="1.0.0.1"
AUTHOR="Michael Mattsson"
REPOSITORY="https://github.com/mdmattsson/syskit"



#
# AUTO INSTALL MODE:
#

# Check if running from proper installation
check_installation() {
    # If we're already in the expected directory, we're good
    if [[ "$SCRIPT_DIR" == "$EXPECTED_DIR" ]]; then
        return 0
    fi

    # Check if already installed but running from different location
    if [[ -d "$EXPECTED_DIR/.git" ]]; then
        echo "SysKit is installed at $EXPECTED_DIR"
        echo "Please run: syskit (or $HOME/.local/bin/syskit)"
        exit 0
    fi

    # Not installed - offer to install
    echo "SysKit is not installed."
    read -p "Would you like to install it now? [Y/n]: " -r < /dev/tty
    echo

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        install_syskit "$@" # Pass arguments through
    else
        echo "Installation cancelled."
        echo "To install later, run:"
        echo "  curl -fsSL https://raw.githubusercontent.com/mdmattsson/syskit/main/install.sh | bash"
        exit 0
    fi
}

# Installation function
install_syskit() {
    # Set up error handling ONLY for installation
    set -eE

    error_handler() {
        {
            echo "================================"
            echo "ERROR: Installation failed"
            echo "Line: $1"
            echo "Command: $BASH_COMMAND"
            echo "Time: $(date)"
            echo "================================"
        } | tee -a "$ERROR_LOG" >&2
        exit 1
    }

    trap 'error_handler $LINENO' ERR

    echo "Installing SysKit..."
    local REPO_URL="https://github.com/mdmattsson/syskit.git"

    # Determine bin directory
    if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
        BIN_DIR="$HOME/.local/bin"
    elif [[ ":$PATH:" == *":$HOME/bin:"* ]]; then
        BIN_DIR="$HOME/bin"
    else
        BIN_DIR="$HOME/.local/bin"
    fi

    # Check PATH and add to .bashrc if needed
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo ""
        echo "WARNING: $BIN_DIR is not in your PATH"
        read -p "Add $BIN_DIR to your PATH automatically? [Y/n]: " -r < /dev/tty
        echo

        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "" >> ~/.bashrc
            echo "# Added by SysKit installer" >> ~/.bashrc
            echo "export PATH=\"$BIN_DIR:\$PATH\"" >> ~/.bashrc
            echo "Added to ~/.bashrc"
            echo "Run 'source ~/.bashrc' or restart your shell"
            export PATH="$BIN_DIR:$PATH"  # Add to current session too
        else
            echo "You can manually add this to your ~/.bashrc:"
            echo "  export PATH=\"$BIN_DIR:\$PATH\""
        fi
        echo ""
    fi    

    # Check for git
    if ! command -v git &>/dev/null; then
        echo "Git is required but not installed."
        echo "Attempting to install git..."

        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt &>/dev/null; then
                sudo apt update && sudo apt install -y git
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y git
            elif command -v yum &>/dev/null; then
                sudo yum install -y git
            elif command -v pacman &>/dev/null; then
                sudo pacman -Sy --noconfirm git
            else
                echo "Could not install git automatically."
                echo "Please install git manually and run this installer again."
                exit 1
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &>/dev/null; then
                brew install git
            else
                echo "Please install Homebrew or git manually."
                exit 1
            fi
        else
            echo "Please install git manually for your platform."
            exit 1
        fi

        # Verify git installed
        if ! command -v git &>/dev/null; then
            echo "Git installation failed."
            exit 1
        fi
    fi

    # Handle existing installation directory
    if [[ -d "$EXPECTED_DIR" ]]; then
        if [[ -d "$EXPECTED_DIR/.git" ]]; then
            echo "Existing installation found. Updating..."
            cd "$EXPECTED_DIR"
            git pull origin main || {
                echo "ERROR: Git pull failed. Removing and reinstalling..."
                cd ~
                rm -rf "$EXPECTED_DIR"
            }
        else
            echo "Incomplete installation found. Removing..."
            rm -rf "$EXPECTED_DIR"
        fi
    fi

    # Clone repository only if directory doesn't exist or was removed
    if [[ ! -d "$EXPECTED_DIR" ]]; then
        echo "Cloning SysKit repository to $EXPECTED_DIR..."
        git clone "$REPO_URL" "$EXPECTED_DIR" || {
            echo "ERROR: Git clone failed!"
            exit 1
        }
    fi

    # Create bin directory
    mkdir -p "$BIN_DIR"

    # Create symlink for main script
    echo "Creating symlink at $BIN_DIR/syskit..."
    ln -sf "$EXPECTED_DIR/syskit.sh" "$BIN_DIR/syskit"
    chmod +x "$EXPECTED_DIR/syskit.sh"

    # Create symlinks for utility scripts
    if [[ -d "$EXPECTED_DIR/utility_scripts" ]]; then
        echo "Creating symlinks for utility scripts..."
        for script in "$EXPECTED_DIR/utility_scripts"/*.sh; do
            [[ -f "$script" ]] || continue
            name=$(basename "$script" .sh)
            ln -sf "$script" "$BIN_DIR/$name"
            chmod +x "$script"
        done
    fi

    # Check PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo ""
        echo "WARNING: $BIN_DIR is not in your PATH"
        echo "Add this to your ~/.bashrc or ~/.profile:"
        echo "  export PATH=\"$BIN_DIR:\$PATH\""
        echo ""
    fi

    echo ""
    echo "✓ SysKit installed successfully!"
    echo ""
    echo "Starting SysKit..."
    sleep 2

    # Re-exec from installed location with original arguments
    exec "$EXPECTED_DIR/syskit.sh" "$@"
}


# Uninstall function
uninstall_syskit() {
    echo "=== SysKit Uninstaller ==="
    echo ""
    echo "This will remove:"
    echo "  - $EXPECTED_DIR (configuration and scripts)"
    echo "  - Symlinks in ~/.local/bin and ~/bin"
    echo ""
    read -p "Are you sure you want to uninstall SysKit? [y/N]: " -r < /dev/tty
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled."
        return 0
    fi

    # Remove symlinks from both possible bin directories
    for bin_dir in "$HOME/.local/bin" "$HOME/bin"; do
        if [[ -d "$bin_dir" ]]; then
            echo "Checking for symlinks in $bin_dir..."
            
            # Remove main syskit symlink (check if it points to our installation)
            if [[ -L "$bin_dir/syskit" ]]; then
                local link_target=$(readlink "$bin_dir/syskit")
                if [[ "$link_target" == "$EXPECTED_DIR/syskit.sh" ]]; then
                    rm "$bin_dir/syskit"
                    echo "  Removed syskit"
                fi
            fi

            # Remove utility script symlinks (only if they point to our installation)
            if [[ -d "$EXPECTED_DIR/utility_scripts" ]]; then
                for script in "$EXPECTED_DIR/utility_scripts"/*.sh; do
                    [[ -f "$script" ]] || continue
                    local name=$(basename "$script" .sh)
                    if [[ -L "$bin_dir/$name" ]]; then
                        local link_target=$(readlink "$bin_dir/$name")
                        if [[ "$link_target" == "$script" ]]; then
                            rm "$bin_dir/$name"
                            echo "  Removed $name"
                        fi
                    fi
                done
            fi
        fi
    done

    # Ask about configuration backup
    if [[ -d "$CONFIG_DIR" ]]; then
        echo ""
        read -p "Backup configuration files before removing? [Y/n]: " -r < /dev/tty
        echo
        
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            local backup_file="$HOME/syskit-config-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
            tar -czf "$backup_file" -C "$EXPECTED_DIR" cfg 2>/dev/null || true
            if [[ -f "$backup_file" ]]; then
                echo "Configuration backed up to: $backup_file"
            fi
        fi
    fi

    # Remove installation directory
    echo ""
    echo "Removing $EXPECTED_DIR..."
    rm -rf "$EXPECTED_DIR"

    echo ""
    echo "SysKit uninstalled successfully!"
    echo ""
    echo "To reinstall, run:"
    echo "  curl -fsSL https://raw.githubusercontent.com/mdmattsson/syskit/main/syskit.sh | bash"

    exit 0
}

#
# MENU MODE:
#

# Create required directories
mkdir -p "$CONFIG_DIR" "$LOGS_DIR"

# Menu state variables
declare -A categories
declare -A category_folders
declare -a category_list
declare -a current_actions
declare -a favorites
declare -a recent_actions
declare -a search_results
current_category=""
current_folder=""
selected_category=0
selected_action=0
active_pane="categories"
current_theme="dark"
search_mode=false
scroll_pos=0


# Layout variables
CATEGORY_WIDTH=0
ACTIONS_COL=0

# Previous state for partial updates
prev_selected_category=-1
prev_selected_action=-1
prev_active_pane=""
interface_drawn=false

# Terminal control
cleanup() {
    # Only do terminal cleanup if we're running the interactive menu
    # Don't clear screen if we're in installation mode or had an error
    if [[ "${RUNNING_INTERACTIVE:-false}" == "true" ]]; then
        tput cnorm 2>/dev/null || true
        tput sgr0 2>/dev/null || true
        clear
    else
        # Just restore cursor visibility without clearing
        tput cnorm 2>/dev/null || true
        tput sgr0 2>/dev/null || true
    fi
}

trap cleanup EXIT


init_terminal() {
    tput civis
    tput clear
}

# Theme definitions
load_theme() {
    case "$current_theme" in
        "dark")
            RED='\033[0;31m'
            GREEN='\033[0;32m'
            YELLOW='\033[1;33m'
            BLUE='\033[0;34m'
            PURPLE='\033[0;35m'
            CYAN='\033[0;36m'
            WHITE='\033[1;37m'
            BOLD='\033[1m'
            DIM='\033[2m'
            RESET='\033[0m'
            HIGHLIGHT='\033[7m'
            ;;
        "light")
            RED='\033[0;91m'
            GREEN='\033[0;92m'
            YELLOW='\033[0;93m'
            BLUE='\033[0;94m'
            PURPLE='\033[0;95m'
            CYAN='\033[0;96m'
            WHITE='\033[0;30m'
            BOLD='\033[1;30m'
            DIM='\033[2;30m'
            RESET='\033[0m'
            HIGHLIGHT='\033[7m'
            ;;
        "high-contrast")
            RED='\033[1;31m'
            GREEN='\033[1;32m'
            YELLOW='\033[1;33m'
            BLUE='\033[1;34m'
            PURPLE='\033[1;35m'
            CYAN='\033[1;36m'
            WHITE='\033[1;37m'
            BOLD='\033[1m'
            DIM='\033[2m'
            RESET='\033[0m'
            HIGHLIGHT='\033[1;7m'
            ;;
    esac
}

# Check if terminal supports Unicode
check_unicode_support() {
    if [[ "${LANG:-}" =~ UTF-8 ]] || [[ "${LC_ALL:-}" =~ UTF-8 ]] || [[ "${LC_CTYPE:-}" =~ UTF-8 ]]; then
        return 0
    else
        return 1
    fi
}

# Get appropriate warning symbol
get_warning_symbol() {
    if check_unicode_support; then
        printf "${RED}!${RESET}"
    else
        printf "${RED}!${RESET}"
    fi
}

# Load configuration
load_config() {
    local config_file="$CONFIG_DIR/config.sh"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
    else
        cat > "$config_file" << EOF
# Configuration file
current_theme="dark"
category_width_override=0
confirmation_enabled=true
auto_save_logs=true
EOF
        source "$config_file"
    fi
}

# Load favorites
load_favorites() {
    local fav_file="$CONFIG_DIR/favorites"
    favorites=()
    if [[ -f "$fav_file" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && favorites+=("$line")
        done < "$fav_file"
    fi
}

# Save favorites
save_favorites() {
    local fav_file="$CONFIG_DIR/favorites"
    printf '%s\n' "${favorites[@]}" > "$fav_file"
}

# Load recent actions
load_recent_actions() {
    local recent_file="$CONFIG_DIR/recent"
    recent_actions=()
    if [[ -f "$recent_file" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && recent_actions+=("$line")
        done < "$recent_file"
    fi
}

# Add to recent actions
add_to_recent() {
    local action="$1"
    for i in "${!recent_actions[@]}"; do
        if [[ "${recent_actions[i]}" == "$action" ]]; then
            unset 'recent_actions[i]'
        fi
    done
    recent_actions=("$action" "${recent_actions[@]}")
    recent_actions=("${recent_actions[@]:0:10}")
    printf '%s\n' "${recent_actions[@]}" > "$CONFIG_DIR/recent"
}

# Calculate layout
calculate_layout() {
    local max_len=0

    for cat in "${category_list[@]}"; do
        if [[ ${#cat} -gt $max_len ]]; then
            max_len=${#cat}
        fi
    done

    if [[ $category_width_override -gt 0 ]]; then
        CATEGORY_WIDTH=$category_width_override
    else
        CATEGORY_WIDTH=$((max_len + 4))
        if [[ $CATEGORY_WIDTH -lt 16 ]]; then
            CATEGORY_WIDTH=16
        fi
    fi

    ACTIONS_COL=$((CATEGORY_WIDTH + 7))
}

# Create directory structure with enhanced samples
create_directory_structure() {
    mkdir -p "$MENU_DIR"/{system,applications,security,utilities}

    cat > "$MENU_DIR/info.sh" << 'EOF'
#!/bin/bash
CATEGORIES=(
    "System;system"
    "Applications;applications"
    "Security;security"
    "Utilities;utilities"
    "Favorites;favorites"
    "Recent;recent"
)
EOF

    # Enhanced system actions
    cat > "$MENU_DIR/system/system_info.sh" << 'EOF'
#!/bin/bash
DESCRIPTION="Show System Information"
DESTRUCTIVE=false
DEPENDENCIES=("uname" "hostname" "uptime")
LONG_DESCRIPTION="Display comprehensive system information including hostname, OS, kernel version, architecture, uptime, load average, memory usage, and disk usage."

run() {
    echo "System Information:"
    echo "==================="
    echo "Hostname: $(hostname)"
    echo "OS: $(uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Memory Usage: $(free -h 2>/dev/null | grep Mem || echo 'N/A')"
    echo "Disk Usage: $(df -h / | tail -1)"
    echo ""
    echo "System information collection completed."
}
EOF

    cat > "$MENU_DIR/system/disk_cleanup.sh" << 'EOF'
#!/bin/bash
DESCRIPTION="Clean System Disk Space"
DESTRUCTIVE=true
DEPENDENCIES=("rm" "find" "df")
LONG_DESCRIPTION="Clean temporary files, log files older than 7 days, and package caches. This action will permanently delete files and cannot be undone."

run() {
    echo "Cleaning system disk space..."
    echo "Before cleanup:"
    df -h / | tail -1

    echo ""
    echo "Cleaning temporary files..."
    sudo rm -rf /tmp/* 2>/dev/null || true
    sudo rm -rf /var/tmp/* 2>/dev/null || true

    echo "Cleaning old log files..."
    sudo find /var/log -type f -name "*.log" -mtime +7 -delete 2>/dev/null || true

    echo ""
    echo "After cleanup:"
    df -h / | tail -1
    echo ""
    echo "Disk cleanup completed successfully."
}
EOF

    chmod +x "$MENU_DIR"/*/*.sh
}

# Load categories and actions
load_categories() {
    categories=()
    category_folders=()
    category_list=()

    if [[ ! -d "$MENU_DIR" ]]; then
        create_directory_structure
    fi

    local info_file="$MENU_DIR/info.sh"
    if [[ ! -f "$info_file" ]]; then
        create_directory_structure
    fi

    if source "$info_file" 2>/dev/null; then
        for entry in "${CATEGORIES[@]}"; do
            IFS=';' read -r display_name folder_name <<< "$entry"
            if [[ -n "$display_name" && -n "$folder_name" ]]; then
                categories["$display_name"]=1
                category_folders["$display_name"]="$folder_name"
                category_list+=("$display_name")
            fi
        done
    fi

    if [[ ${#category_list[@]} -gt 0 ]]; then
        current_category="${category_list[0]}"
        current_folder="${category_folders[$current_category]}"
        load_actions_for_category "$current_category"
    fi
}

# Load actions for category
load_actions_for_category() {
    local category="$1"
    current_actions=()
    current_folder="${category_folders[$category]}"
    scroll_pos=0

    if [[ "$category" == "Favorites" ]]; then
        load_favorites_actions
        return
    elif [[ "$category" == "Recent" ]]; then
        load_recent_actions_display
        return
    fi

    local actions_dir="$MENU_DIR/$current_folder"
    if [[ ! -d "$actions_dir" ]]; then
        return
    fi

    for action_file in "$actions_dir"/*.sh; do
        [[ -f "$action_file" ]] || continue

        if source "$action_file" 2>/dev/null; then
            if [[ -n "$DESCRIPTION" ]]; then
                local filename=$(basename "$action_file")
                current_actions+=("$DESCRIPTION|$filename|${DESTRUCTIVE:-false}")
            fi
        fi
        unset DESCRIPTION DESTRUCTIVE DEPENDENCIES LONG_DESCRIPTION
    done

    selected_action=0
}

# Load favorites as actions
load_favorites_actions() {
    current_actions=()
    for fav in "${favorites[@]}"; do
        current_actions+=("$fav")
    done
    selected_action=0
}

# Load recent actions for display
load_recent_actions_display() {
    current_actions=()
    for recent in "${recent_actions[@]}"; do
        current_actions+=("$recent")
    done
    selected_action=0
}

# Check dependencies
check_dependencies() {
    local action_file="$1"
    source "$action_file" 2>/dev/null

    if [[ -n "${DEPENDENCIES:-}" ]]; then
        local missing=()
        for dep in "${DEPENDENCIES[@]}"; do
            if ! command -v "$dep" &> /dev/null; then
                missing+=("$dep")
            fi
        done

        if [[ ${#missing[@]} -gt 0 ]]; then
            echo "Missing dependencies: ${missing[*]}"
            return 1
        fi
    fi

    unset DEPENDENCIES
    return 0
}

# Show confirmation dialog for destructive actions
show_confirmation() {
    local desc="$1"
    local term_width=$(tput cols)
    local term_height=$(tput lines)
    local dialog_width=60
    local dialog_height=8
    local start_row=$(((term_height - dialog_height) / 2))
    local start_col=$(((term_width - dialog_width) / 2))

    tput cup $start_row $start_col
    printf "┌─ CONFIRMATION REQUIRED ─%*s─┐" $((dialog_width - 28)) ""

    for ((i=1; i<dialog_height-1; i++)); do
        tput cup $((start_row + i)) $start_col
        printf "│%*s│" $((dialog_width - 2)) ""
    done

    tput cup $((start_row + dialog_height - 1)) $start_col
    printf "└─%*s─┘" $((dialog_width - 4)) ""

    tput cup $((start_row + 2)) $((start_col + 2))
    printf "WARNING: This action is potentially destructive!"

    tput cup $((start_row + 4)) $((start_col + 2))
    printf "Action: %s" "$desc"

    tput cup $((start_row + 6)) $((start_col + 2))
    printf "Continue? [y/N]: "

    local response
    read -n 1 response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Show help overlay
show_help() {
    local term_width=$(tput cols)
    local term_height=$(tput lines)
    local help_width=$((term_width - 10))
    local help_height=$((term_height - 6))
    local start_row=3
    local start_col=5
    tput cup $start_row $start_col
    printf "┌─ HELP ─%*s─┐" $((help_width - 9)) ""

    for ((i=1; i<help_height-1; i++)); do
        tput cup $((start_row + i)) $start_col
        printf "│%*s│" $((help_width - 2)) ""
    done

    tput cup $((start_row + help_height - 1)) $start_col
    printf "└─%*s─┘" $((help_width - 2)) "" | tr ' ' '─'

    local help_text=(
        "Navigation:"
        "  ←→ - Switch between categories and actions"
        "  ↑↓ - Navigate within panes"
        "  Enter - Execute selected action"
        "  q - Quit application"
        ""
        "Features:"
        "  / - Search actions"
        "  * - Toggle favorite"
        "  t - Change theme"
        "  ? - Show this help"
        ""
        "Execution Overlay:"
        "  ↑↓ - Scroll output after completion"
        "  Ctrl-C - Stop running script"
        "  Enter - Close overlay"
        "  s - Save output to file"
        ""
        "Symbols:"
        "  ! - Potentially destructive action"
        "  ★ - Favorited action"
        ""
        "Press any key to close help..."
    )

    for i in "${!help_text[@]}"; do
        tput cup $((start_row + 2 + i)) $((start_col + 2))
        printf "%s" "${help_text[$i]}"
    done

    read -n 1
}

# Draw interface components
draw_interface() {
    if [[ "$interface_drawn" == false ]]; then
        calculate_layout
        draw_full_interface
        interface_drawn=true
        prev_selected_category=$selected_category
        prev_selected_action=$selected_action
        prev_active_pane="$active_pane"
        return
    fi

    local category_changed=false
    local action_changed=false
    local pane_changed=false

    [[ $prev_selected_category -ne $selected_category ]] && category_changed=true
    [[ $prev_selected_action -ne $selected_action ]] && action_changed=true
    [[ "$prev_active_pane" != "$active_pane" ]] && pane_changed=true

    if [[ "$category_changed" == true ]]; then
        update_category_highlight
        redraw_actions_smoothly
        update_status_line
    fi

    if [[ "$action_changed" == true ]]; then
        update_action_highlight
        update_preview_pane
    fi

    if [[ "$pane_changed" == true ]]; then
        update_headers
        update_category_highlight
        update_action_highlight
    fi

    prev_selected_category=$selected_category
    prev_selected_action=$selected_action
    prev_active_pane="$active_pane"
}

# Draw full interface
draw_full_interface() {
    clear
    local term_width=$(tput cols)
    local term_height=$(tput lines)

    # Header
    tput cup 0 0
    local title="syskit v$VERSION"
    local title_pos=$(((term_width - ${#title}) / 2))
    printf "%*s${BOLD}${CYAN}%s${RESET}%*s\n" $title_pos "" "$title" $title_pos ""

    local author_line="$AUTHOR | $REPOSITORY | Theme: $current_theme"
    local author_pos=$(((term_width - ${#author_line}) / 2))
    printf "%*s${DIM}%s${RESET}%*s\n" $author_pos "" "$author_line" $author_pos ""

    # Separators
    tput cup 2 0
    printf "${BLUE}%*s${RESET}\n" "$term_width" '' | tr ' ' '='

    tput cup $((term_height - 3)) 0
    printf "${BLUE}%*s${RESET}\n" "$term_width" '' | tr ' ' '='

    # Vertical separator
    for ((i=4; i<term_height-3; i++)); do
        tput cup $i $CATEGORY_WIDTH
        printf "${BLUE}│${RESET}"
    done

    update_headers
    draw_all_categories
    draw_all_actions
    update_status_line
    update_preview_pane
}

# Update headers
update_headers() {
    tput cup 3 0
    printf "%-${CATEGORY_WIDTH}s" ""
    tput cup 3 0

    if [[ "$active_pane" == "categories" ]]; then
        printf "${HIGHLIGHT}${BOLD}${WHITE}CATEGORIES${RESET}"
    else
        printf "${BOLD}${YELLOW}CATEGORIES${RESET}"
    fi

    tput cup 3 $CATEGORY_WIDTH
    printf "${BLUE}│${RESET} "

    if [[ "$active_pane" == "actions" ]]; then
        printf "${HIGHLIGHT}${BOLD}${WHITE}ACTIONS${RESET}"
    else
        printf "${BOLD}${YELLOW}ACTIONS${RESET}"
    fi
}

# Draw all categories
draw_all_categories() {
    for i in "${!category_list[@]}"; do
        local row=$((5 + i))
        tput cup $row 0

        local cat_display="${category_list[$i]}"
        if [[ "$cat_display" == "Favorites" ]]; then
            cat_display="★ Favorites"
        elif [[ "$cat_display" == "Recent" ]]; then
            cat_display="⟲ Recent"
        fi

        if [[ $i -eq $selected_category && "$active_pane" == "categories" ]]; then
            printf "${HIGHLIGHT}${BOLD}${WHITE}> %-$((CATEGORY_WIDTH-2))s${RESET}" "$cat_display"
        elif [[ $i -eq $selected_category ]]; then
            printf "${BOLD}${CYAN}> %-$((CATEGORY_WIDTH-2))s${RESET}" "$cat_display"
        else
            printf "${GREEN}  %-$((CATEGORY_WIDTH-2))s${RESET}" "$cat_display"
        fi
    done
}

# Update category highlight
update_category_highlight() {
    if [[ $prev_selected_category -ne -1 && $prev_selected_category -ne $selected_category ]]; then
        local prev_row=$((5 + prev_selected_category))
        tput cup $prev_row 0
        local cat_display="${category_list[$prev_selected_category]}"
        if [[ "$cat_display" == "Favorites" ]]; then
            cat_display="★ Favorites"
        elif [[ "$cat_display" == "Recent" ]]; then
            cat_display="⟲ Recent"
        fi
        printf "${GREEN}  %-$((CATEGORY_WIDTH-2))s${RESET}" "$cat_display"
    fi

    local curr_row=$((5 + selected_category))
    tput cup $curr_row 0
    local cat_display="${category_list[$selected_category]}"
    if [[ "$cat_display" == "Favorites" ]]; then
        cat_display="★ Favorites"
    elif [[ "$cat_display" == "Recent" ]]; then
        cat_display="⟲ Recent"
    fi

    if [[ "$active_pane" == "categories" ]]; then
        printf "${HIGHLIGHT}${BOLD}${WHITE}> %-$((CATEGORY_WIDTH-2))s${RESET}" "$cat_display"
    else
        printf "${BOLD}${CYAN}> %-$((CATEGORY_WIDTH-2))s${RESET}" "$cat_display"
    fi
}

# Draw all actions
draw_all_actions() {
    local actions_to_show=("${current_actions[@]}")
    if [[ "$search_mode" == true ]]; then
        actions_to_show=("${search_results[@]}")
    fi

    for i in "${!actions_to_show[@]}"; do
        local row=$((5 + i))

        local action_info="${actions_to_show[$i]}"
        local display_text filename is_destructive

        if [[ "$search_mode" == true ]]; then
            display_text="${action_info%%|*}"
            local folder="${action_info##*|}"
            filename="${action_info%|*}"
            filename="${filename##*|}"
            local action_file="$MENU_DIR/$folder/$filename"
            is_destructive="false"
            if [[ -f "$action_file" ]]; then
                source "$action_file" 2>/dev/null
                is_destructive="${DESTRUCTIVE:-false}"
                unset DESCRIPTION DESTRUCTIVE DEPENDENCIES LONG_DESCRIPTION
            fi
        else
            IFS='|' read -r display_text filename is_destructive <<< "$action_info"
        fi

        tput cup $row $((CATEGORY_WIDTH + 2))

        # Draw destructive warning icon (first column)
        local warning_icon=" "
        if [[ "$is_destructive" == "true" ]]; then
            warning_icon="$(get_warning_symbol)"
        fi
        printf "%s" "$warning_icon"

        # Draw favorite icon (second column)
        local favorite_icon=" "
        for fav in "${favorites[@]}"; do
            if [[ "$fav" =~ .*"$display_text".* ]]; then
                favorite_icon="★"
                break
            fi
        done
        printf "%s" "$favorite_icon"

        # Draw the action description
        if [[ $i -eq $selected_action && "$active_pane" == "actions" ]]; then
            printf " ${HIGHLIGHT}${BOLD}${WHITE}> %s${RESET}" "$display_text"
        elif [[ $i -eq $selected_action ]]; then
            printf " ${BOLD}${PURPLE}> %s${RESET}" "$display_text"
        else
            printf "   %s" "$display_text"
        fi
    done
}

# Redraw actions smoothly
redraw_actions_smoothly() {
    local actions_to_show=("${current_actions[@]}")
    if [[ "$search_mode" == true ]]; then
        actions_to_show=("${search_results[@]}")
    fi

    for i in "${!actions_to_show[@]}"; do
        local row=$((5 + i))

        tput cup $row $((CATEGORY_WIDTH + 2))
        printf "\033[K"

        local action_info="${actions_to_show[$i]}"
        local display_text filename is_destructive

        if [[ "$search_mode" == true ]]; then
            display_text="${action_info%%|*}"
            local folder="${action_info##*|}"
            filename="${action_info%|*}"
            filename="${filename##*|}"
            local action_file="$MENU_DIR/$folder/$filename"
            is_destructive="false"
            if [[ -f "$action_file" ]]; then
                source "$action_file" 2>/dev/null
                is_destructive="${DESTRUCTIVE:-false}"
                unset DESCRIPTION DESTRUCTIVE DEPENDENCIES LONG_DESCRIPTION
            fi
        else
            IFS='|' read -r display_text filename is_destructive <<< "$action_info"
        fi

        # Draw destructive warning icon (first column)
        local warning_icon=" "
        if [[ "$is_destructive" == "true" ]]; then
            warning_icon="$(get_warning_symbol)"
        fi
        printf "%s" "$warning_icon"

        # Draw favorite icon (second column)  
        local favorite_icon=" "
        for fav in "${favorites[@]}"; do
            if [[ "$fav" =~ .*"$display_text".* ]]; then
                favorite_icon="★"
                break
            fi
        done
        printf "%s" "$favorite_icon"

        # Draw the action description
        if [[ $i -eq $selected_action && "$active_pane" == "actions" ]]; then
            printf " ${HIGHLIGHT}${BOLD}${WHITE}> %s${RESET}" "$display_text"
        elif [[ $i -eq $selected_action ]]; then
            printf " ${BOLD}${PURPLE}> %s${RESET}" "$display_text"
        else
            printf "   %s" "$display_text"
        fi
    done

    # Clear remaining lines
    local term_height=$(tput lines)
    for ((i=${#actions_to_show[@]}; i<20; i++)); do
        local row=$((5 + i))
        if [[ $row -ge $((term_height - 4)) ]]; then
            break
        fi
        tput cup $row $((CATEGORY_WIDTH + 2))
        printf "\033[K"
    done
}

# Update action highlight
update_action_highlight() {
    local actions_to_show=("${current_actions[@]}")
    if [[ "$search_mode" == true ]]; then
        actions_to_show=("${search_results[@]}")
    fi

    # Clear old highlight
    if [[ $prev_selected_action -ne -1 && $prev_selected_action -ne $selected_action ]]; then
        local prev_row=$((5 + prev_selected_action))
        tput cup $prev_row $((CATEGORY_WIDTH + 2))
        printf "\033[K"

        if [[ $prev_selected_action -lt ${#actions_to_show[@]} ]]; then
            local action_info="${actions_to_show[$prev_selected_action]}"
            local display_text filename is_destructive

            if [[ "$search_mode" == true ]]; then
                display_text="${action_info%%|*}"
                local folder="${action_info##*|}"
                filename="${action_info%|*}"
                filename="${filename##*|}"
                local action_file="$MENU_DIR/$folder/$filename"
                is_destructive="false"
                if [[ -f "$action_file" ]]; then
                    source "$action_file" 2>/dev/null
                    is_destructive="${DESTRUCTIVE:-false}"
                    unset DESCRIPTION DESTRUCTIVE DEPENDENCIES LONG_DESCRIPTION
                fi
            else
                IFS='|' read -r display_text filename is_destructive <<< "$action_info"
            fi

            local warning_icon=" "
            if [[ "$is_destructive" == "true" ]]; then
                warning_icon="$(get_warning_symbol)"
            fi
            printf "%s" "$warning_icon"

            local favorite_icon=" "
            for fav in "${favorites[@]}"; do
                if [[ "$fav" =~ .*"$display_text".* ]]; then
                    favorite_icon="★"
                    break
                fi
            done
            printf "%s" "$favorite_icon"

            printf "   %s" "$display_text"
        fi
    fi

    # Set new highlight
    if [[ $selected_action -lt ${#actions_to_show[@]} ]]; then
        local curr_row=$((5 + selected_action))
        tput cup $curr_row $((CATEGORY_WIDTH + 2))
        printf "\033[K"

        local action_info="${actions_to_show[$selected_action]}"
        local display_text filename is_destructive

        if [[ "$search_mode" == true ]]; then
            display_text="${action_info%%|*}"
            local folder="${action_info##*|}"
            filename="${action_info%|*}"
            filename="${filename##*|}"
            local action_file="$MENU_DIR/$folder/$filename"
            is_destructive="false"
            if [[ -f "$action_file" ]]; then
                source "$action_file" 2>/dev/null
                is_destructive="${DESTRUCTIVE:-false}"
                unset DESCRIPTION DESTRUCTIVE DEPENDENCIES LONG_DESCRIPTION
            fi
        else
            IFS='|' read -r display_text filename is_destructive <<< "$action_info"
        fi

        local warning_icon=" "
        if [[ "$is_destructive" == "true" ]]; then
            warning_icon="$(get_warning_symbol)"
        fi
        printf "%s" "$warning_icon"

        local favorite_icon=" "
        for fav in "${favorites[@]}"; do
            if [[ "$fav" =~ .*"$display_text".* ]]; then
                favorite_icon="★"
                break
            fi
        done
        printf "%s" "$favorite_icon"

        if [[ "$active_pane" == "actions" ]]; then
            printf " ${HIGHLIGHT}${BOLD}${WHITE}> %s${RESET}" "$display_text"
        else
            printf " ${BOLD}${PURPLE}> %s${RESET}" "$display_text"
        fi
    fi
}

# Update preview pane
update_preview_pane() {
    local term_height=$(tput lines)
    local preview_row=$((term_height - 2))
    local actions_to_show=("${current_actions[@]}")

    if [[ "$search_mode" == true ]]; then
        actions_to_show=("${search_results[@]}")
    fi

    tput cup $preview_row $ACTIONS_COL
    printf "\033[K"

    if [[ $selected_action -lt ${#actions_to_show[@]} && "$active_pane" == "actions" ]]; then
        local action_info="${actions_to_show[$selected_action]}"
        local filename folder

        if [[ "$search_mode" == true ]]; then
            folder="${action_info##*|}"
            filename="${action_info%|*}"
            filename="${filename##*|}"
        else
            IFS='|' read -r _ filename _ <<< "$action_info"
            folder="$current_folder"
        fi

        local action_file="$MENU_DIR/$folder/$filename"
        if [[ -f "$action_file" ]]; then
            source "$action_file" 2>/dev/null
            if [[ -n "${LONG_DESCRIPTION:-}" ]]; then
                local term_width=$(tput cols)
                local available_width=$((term_width - ACTIONS_COL - 2))
                printf "${DIM}%s${RESET}" "${LONG_DESCRIPTION:0:$available_width}"
            fi
            unset LONG_DESCRIPTION DESCRIPTION DESTRUCTIVE DEPENDENCIES
        fi
    fi
}

# Update status line
update_status_line() {
    local term_width=$(tput cols)
    local term_height=$(tput lines)

    tput cup $((term_height - 1)) 0
    printf "\033[K"

    if [[ "$search_mode" == true ]]; then
        printf "${DIM}Search mode: ${RESET}${YELLOW}Type to search, Esc to exit${RESET}"
    else
        printf "${DIM}Navigation: ${RESET}${YELLOW}←→ panes, ↑↓ select, Enter run, / search, * favorite, ? help, q quit${RESET}${DIM} | ${RESET}${BOLD}${GREEN}%s${RESET}" "$current_folder"
    fi
}

# Toggle favorite
toggle_favorite() {
    if [[ ${#current_actions[@]} -eq 0 ]]; then
        return
    fi

    local action="${current_actions[$selected_action]}"
    local found=false

    for i in "${!favorites[@]}"; do
        if [[ "${favorites[$i]}" == "$action" ]]; then
            unset 'favorites[i]'
            found=true
            break
        fi
    done

    if [[ "$found" == false ]]; then
        favorites+=("$action")
    fi

    local temp_favorites=()
    for fav in "${favorites[@]}"; do
        [[ -n "$fav" ]] && temp_favorites+=("$fav")
    done
    favorites=("${temp_favorites[@]}")

    save_favorites
    interface_drawn=false
}

# Execute action
execute_action() {
    if [[ ${#current_actions[@]} -eq 0 ]]; then
        return
    fi

    local actions_to_show=("${current_actions[@]}")
    if [[ "$search_mode" == true ]]; then
        actions_to_show=("${search_results[@]}")
    fi

    local action_info="${actions_to_show[$selected_action]}"
    local desc filename folder

    if [[ "$search_mode" == true ]]; then
        desc="${action_info%%|*}"
        folder="${action_info##*|}"
        filename="${action_info%|*}"
        filename="${filename##*|}"
    else
        IFS='|' read -r desc filename _ <<< "$action_info"
        folder="$current_folder"
    fi

    local action_file="$MENU_DIR/$folder/$filename"

    if [[ -f "$action_file" ]]; then
        if ! check_dependencies "$action_file"; then
            echo "Dependencies check failed. Press any key to continue..."
            read -n 1
            interface_drawn=false
            return
        fi

        source "$action_file" 2>/dev/null
        if [[ "${DESTRUCTIVE:-false}" == "true" && "${confirmation_enabled:-true}" == "true" ]]; then
            if ! show_confirmation "$desc"; then
                interface_drawn=false
                return
            fi
        fi
        unset DESTRUCTIVE DESCRIPTION DEPENDENCIES LONG_DESCRIPTION

        add_to_recent "$action_info"
        show_execution_overlay "$desc" "$action_file"
        interface_drawn=false
    fi
}

# Show execution overlay
show_execution_overlay() {
    local desc="$1"
    local action_file="$2"
    local term_width=$(tput cols)
    local term_height=$(tput lines)
    local overlay_width=$((term_width - CATEGORY_WIDTH - 4))
    local overlay_height=$((term_height - 8))
    local overlay_start=$((CATEGORY_WIDTH + 2))
    local output_file=$(mktemp)

    # Save terminal state
    local orig_stty=$(stty -g)

    # Clear the overlay area first
    for ((i=4; i<$((4+overlay_height)); i++)); do
        tput cup $i $overlay_start
        printf "%*s" $overlay_width ""
    done

    # Draw initial overlay border
    tput cup 4 $overlay_start
    printf "┌─ ${GREEN}Executing: %s %*s${RESET}─┐" "$desc" $((overlay_width - 17 - ${#desc})) ""

    for ((i=5; i<$((4+overlay_height-1)); i++)); do
        tput cup $i $overlay_start
        printf "│%*s│" $((overlay_width-2)) ""
    done

    # Initial bottom border with running status
    tput cup $((4 + overlay_height - 1)) $overlay_start
    printf "└─ [Ctrl-C] Stop [Enter] Close %*s─┘" $((overlay_width-33)) ""

    local script_pid=""
    local execution_stopped=false

    # Improved signal handling
    trap 'handle_stop_signal' INT

    handle_stop_signal() {
        execution_stopped=true
        if [[ -n "$script_pid" ]]; then
            kill -TERM "$script_pid" 2>/dev/null || true
            wait "$script_pid" 2>/dev/null || true
        fi
        # Clear the output area
        for ((i=5; i<$((4+overlay_height-1)); i++)); do
            tput cup $i $((overlay_start + 1))
            printf "%*s" $((overlay_width-2)) ""
        done
        tput cup 7 $((overlay_start + 2))
        printf "${YELLOW}*** EXECUTION STOPPED BY USER ***${RESET}"

        # Update bottom border for stopped state
        tput cup $((4 + overlay_height - 1)) $overlay_start
        printf "└─ ${RED}STOPPED${RESET} - Press [Enter] to close %*s─┘" $((overlay_width-38)) ""
    }

    # Execute script in background
    {
        echo "=== Execution started at $(date) ==="
        echo "Action: $(basename "$action_file")"
        echo "======================================"
        echo ""

        source "$action_file"
        if declare -f run >/dev/null; then
            run
        else
            echo "Error: No 'run' function found"
        fi

        echo ""
        echo "======================================"
        echo "=== Execution completed at $(date) ==="
        unset -f run 2>/dev/null || true
    } > "$output_file" 2>&1 &

    script_pid=$!

    # Monitor execution and display output
    while kill -0 "$script_pid" 2>/dev/null; do
        display_output "$output_file" $overlay_start $overlay_width $overlay_height
        sleep 0.1
    done

    # Wait for script completion
    wait "$script_pid" 2>/dev/null || true

    # Display final output
    display_output "$output_file" $overlay_start $overlay_width $overlay_height

    # Only update to completion status if not stopped by user
    if [[ "$execution_stopped" == false ]]; then
        # Clear and redraw bottom border with completion status
        tput cup $((4 + overlay_height - 1)) $overlay_start
        printf "└─ ${GREEN}COMPLETED${RESET} - Press [Enter] to close %*s─┘" $((overlay_width-40)) ""
    fi

    # Disable terminal echo and wait for Enter key only
    stty -echo -icanon min 1 time 0

    stty -echo -icanon min 1 time 0
    while true; do
        key=$(dd bs=1 count=1 2>/dev/null)
        if [[ "$key" == $'\n' ]] || [[ "$key" == $'\r' ]] || [[ "$key" == "" ]]; then
            break
        fi
    done

    # Restore terminal settings
    stty "$orig_stty"

    # Clean up
    trap - INT
    rm -f "$output_file"
}

# Display output in overlay
display_output() {
    local output_file="$1"
    local start_col=$2
    local width=$3
    local height=$4
    local content_width=$((width - 4))  # Account for borders and padding
    local content_height=$((height - 3)) # Account for top and bottom borders

    local line_num=0

    # Read and display output line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $line_num -lt $content_height ]]; then
            local row=$((5 + line_num))
            tput cup $row $((start_col + 2))  # Position inside the border
            # Clear the line first, then write content
            printf "%-${content_width}s" "${line:0:$content_width}"
        fi
        ((line_num++))
    done < "$output_file"

    # Clear any remaining lines in the content area
    for ((i=line_num; i<content_height; i++)); do
        local row=$((5 + i))
        tput cup $row $((start_col + 2))
        printf "%-${content_width}s" ""
    done
}

# Change theme
change_theme() {
    case "$current_theme" in
        "dark") current_theme="light" ;;
        "light") current_theme="high-contrast" ;;
        "high-contrast") current_theme="dark" ;;
    esac

    sed -i "s/current_theme=.*/current_theme=\"$current_theme\"/" "$CONFIG_DIR/config.sh"
    load_theme
    interface_drawn=false
}

# Search functionality
search_actions() {
    local search_term="$1"
    search_results=()

    for category in "${category_list[@]}"; do
        [[ "$category" == "Favorites" || "$category" == "Recent" ]] && continue

        local folder="${category_folders[$category]}"
        local actions_dir="$MENU_DIR/$folder"
        [[ ! -d "$actions_dir" ]] && continue

        for action_file in "$actions_dir"/*.sh; do
            [[ -f "$action_file" ]] || continue

            if source "$action_file" 2>/dev/null; then
                if [[ -n "$DESCRIPTION" ]] && [[ "$DESCRIPTION" =~ .*"$search_term".* ]]; then
                    search_results+=("[$category] $DESCRIPTION|$(basename "$action_file")|$folder")
                fi
            fi
            unset DESCRIPTION DESTRUCTIVE DEPENDENCIES LONG_DESCRIPTION
        done
    done
}

# Handle search mode
handle_search() {
    local search_term=""
    search_mode=true
    update_status_line

    while true; do
        local key
        read -rsn1 key

        case "$key" in
            $'\x1b')
                search_mode=false
                search_results=()
                selected_action=0
                interface_drawn=false
                return
                ;;
            $'\x7f'|$'\x08')
                if [[ ${#search_term} -gt 0 ]]; then
                    search_term="${search_term%?}"
                    search_actions "$search_term"
                    selected_action=0
                    redraw_actions_smoothly
                fi
                ;;
            '')
                if [[ ${#search_results[@]} -gt 0 ]]; then
                    search_mode=false
                    execute_action
                    search_mode=true
                fi
                ;;
            *)
                if [[ ${#key} -eq 1 && "$key" =~ [[:print:]] ]]; then
                    search_term+="$key"
                    search_actions "$search_term"
                    selected_action=0
                    redraw_actions_smoothly
                fi
                ;;
        esac

        local term_height=$(tput lines)
        tput cup $((term_height - 1)) 0
        printf "\033[K${DIM}Search: ${RESET}${YELLOW}%s${RESET}${DIM} | Results: %d | Esc to exit${RESET}" "$search_term" "${#search_results[@]}"
    done
}

# Handle input
handle_input() {
    local key
    read -rsn1 key

    case "$key" in
        'q'|'Q')
            return 1
            ;;
        '/')
            if [[ "$search_mode" == false ]]; then
                handle_search
            fi
            ;;
        '*')
            if [[ "$active_pane" == "actions" ]]; then
                toggle_favorite
            fi
            ;;
        '?')
            show_help
            interface_drawn=false
            ;;
        't'|'T')
            change_theme
            ;;
        $'\x1b')
            read -rsn2 key
            case "$key" in
                '[A')
                    if [[ "$active_pane" == "categories" ]]; then
                        if [[ $selected_category -gt 0 ]]; then
                            ((selected_category--))
                            current_category="${category_list[$selected_category]}"
                            load_actions_for_category "$current_category"
                        fi
                    else
                        if [[ $selected_action -gt 0 ]]; then
                            ((selected_action--))
                        fi
                    fi
                    ;;
                '[B')
                    if [[ "$active_pane" == "categories" ]]; then
                        if [[ $selected_category -lt $((${#category_list[@]} - 1)) ]]; then
                            ((selected_category++))
                            current_category="${category_list[$selected_category]}"
                            load_actions_for_category "$current_category"
                        fi
                    else
                        local actions_to_show=("${current_actions[@]}")
                        if [[ "$search_mode" == true ]]; then
                            actions_to_show=("${search_results[@]}")
                        fi
                        if [[ $selected_action -lt $((${#actions_to_show[@]} - 1)) ]]; then
                            ((selected_action++))
                        fi
                    fi
                    ;;
                '[C')
                    if [[ "$active_pane" == "categories" ]]; then
                        local actions_to_show=("${current_actions[@]}")
                        if [[ "$search_mode" == true ]]; then
                            actions_to_show=("${search_results[@]}")
                        fi
                        if [[ ${#actions_to_show[@]} -gt 0 ]]; then
                            active_pane="actions"
                        fi
                    fi
                    ;;
                '[D')
                    if [[ "$active_pane" == "actions" ]]; then
                        active_pane="categories"
                    fi
                    ;;
            esac
            ;;
        '')
            if [[ "$active_pane" == "actions" ]]; then
                execute_action
            fi
            ;;
    esac

    return 0
}



# Main function
main() {

    # Handle command-line arguments
    case "${1:-}" in
        --uninstall)
            uninstall_syskit
            ;;
        --version)
            echo "SysKit v$VERSION"
            exit 0
            ;;
        --help)
            echo "SysKit - Advanced Linux System Setup"
            echo "Usage: syskit [options]"
            echo ""
            echo "Options:"
            echo "  --uninstall    Remove SysKit from system"
            echo "  --version      Show version information"
            echo "  --help         Show this help"
            exit 0
            ;;
    esac

    # check installation, passing all arguments
    check_installation "$@"

    load_config
    load_theme
    init_terminal
    load_categories
    load_favorites
    load_recent_actions

    if [[ ${#category_list[@]} -eq 0 ]]; then
        echo "No categories found. Please check the categories/info.sh file."
        exit 1
    fi

    while true; do
        draw_interface
        if ! handle_input; then
            break
        fi
    done

    cleanup
    echo "Goodbye!"
}

main "$@"
