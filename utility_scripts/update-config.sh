#!/bin/bash
# update-config.sh
# Update mechanism for bash configuration
# Handles version checking, selective updates, and change management

set -e

# Configuration
REPO_URL="https://raw.githubusercontent.com/mdmattsson/bash-config/main"
REPO_API_URL="https://api.github.com/repos/mdmattsson/bash-config"
CONFIG_DIR="$HOME/.config/bash"
TEMP_DIR="/tmp/bash-config-update-$$"
CURRENT_VERSION_FILE="$CONFIG_DIR/local.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

header() {
    echo -e "\n${CYAN}=== $1 ===${NC}"
}

# ============================================================================
# VERSION MANAGEMENT
# ============================================================================

get_current_version() {
    if [[ -f "$CURRENT_VERSION_FILE" ]]; then
        grep "BASH_CONFIG_VERSION=" "$CURRENT_VERSION_FILE" 2>/dev/null | cut -d'"' -f2 || echo "unknown"
    else
        echo "unknown"
    fi
}

get_latest_version() {
    # Try to get version from GitHub API
    if command -v curl &>/dev/null; then
        local latest_tag=$(curl -s "$REPO_API_URL/releases/latest" 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4)
        if [[ -n "$latest_tag" ]]; then
            echo "$latest_tag"
            return 0
        fi
    fi

    # Fallback: try to get version from raw file
    local remote_version=$(curl -s "$REPO_URL/VERSION" 2>/dev/null || echo "")
    if [[ -n "$remote_version" ]]; then
        echo "$remote_version"
    else
        echo "unknown"
    fi
}

compare_versions() {
    local current="$1"
    local latest="$2"

    if [[ "$current" == "unknown" || "$latest" == "unknown" ]]; then
        echo "unknown"
        return 0
    fi

    # Simple version comparison (assumes semantic versioning)
    if [[ "$current" == "$latest" ]]; then
        echo "same"
    elif printf '%s\n%s\n' "$current" "$latest" | sort -V | head -1 | grep -q "^$current$"; then
        echo "older"
    else
        echo "newer"
    fi
}

# ============================================================================
# CHANGE DETECTION AND DISPLAY
# ============================================================================

download_file() {
    local file_path="$1"
    local local_path="$2"

    mkdir -p "$(dirname "$local_path")"
    if curl -fsSL "$REPO_URL/$file_path" -o "$local_path" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

get_changelog() {
    local temp_changelog="$TEMP_DIR/CHANGELOG.md"

    if download_file "CHANGELOG.md" "$temp_changelog"; then
        echo "$temp_changelog"
    else
        echo ""
    fi
}

show_changes() {
    local current_version="$1"
    local latest_version="$2"

    header "Changes Since Your Version ($current_version)"

    local changelog=$(get_changelog)
    if [[ -n "$changelog" && -f "$changelog" ]]; then
        # Try to extract relevant changes
        local in_relevant_section=false
        while IFS= read -r line; do
            if [[ "$line" =~ ^##[[:space:]]*\[?$latest_version ]]; then
                in_relevant_section=true
                echo -e "${CYAN}$line${NC}"
                continue
            elif [[ "$line" =~ ^##[[:space:]]*\[?$current_version ]] && [[ "$in_relevant_section" == true ]]; then
                break
            elif [[ "$line" =~ ^##[[:space:]] ]] && [[ "$in_relevant_section" == true ]]; then
                echo -e "${CYAN}$line${NC}"
                continue
            fi

            if [[ "$in_relevant_section" == true ]]; then
                echo "$line"
            fi
        done < "$changelog"
    else
        warn "Could not retrieve changelog"
        info "Visit https://github.com/mdmattsson/bash-config/releases for release notes"
    fi
}

detect_local_changes() {
    header "Detecting Local Modifications"

    local has_changes=false

    # Check for modified core files
    local core_files=(
        ".bashrc"
        "config/bash/essential/core.sh"
        "config/bash/essential/environment.sh"
        "config/bash/essential/platform.sh"
        "config/bash/essential/navigation.sh"
    )

    mkdir -p "$TEMP_DIR/original"

    for file in "${core_files[@]}"; do
        local current_file="$HOME/$file"
        local original_file="$TEMP_DIR/original/$file"

        if download_file "$file" "$original_file" 2>/dev/null; then
            if [[ -f "$current_file" ]]; then
                if ! diff -q "$current_file" "$original_file" >/dev/null 2>&1; then
                    warn "Modified: $file"
                    has_changes=true
                fi
            fi
        fi
    done

    # Check local.sh for substantial customization
    if [[ -f "$CONFIG_DIR/local.sh" ]]; then
        local lines=$(wc -l < "$CONFIG_DIR/local.sh")
        if [[ $lines -gt 20 ]]; then
            info "local.sh has $lines lines of customization"
        fi
    fi

    if [[ "$has_changes" == false ]]; then
        log "No modifications detected in core files"
    fi

    return 0
}

# ============================================================================
# SELECTIVE UPDATE FUNCTIONALITY
# ============================================================================

list_updateable_components() {
    header "Available Components for Update"

    echo "Core Components:"
    echo "  bashrc           - Main .bashrc file"
    echo "  essential        - Essential layer (core, environment, platform, navigation)"
    echo "  development      - Development layer (git, docker, cmake, languages, tools)"
    echo "  productivity     - Productivity layer (work, system utilities)"
    echo "  platform         - Platform-specific optimizations"
    echo "  scripts          - Utility scripts (install, fix-permissions, transfer-ssh)"
    echo ""
    echo "Individual Files:"
    echo "  git              - Git aliases and functions"
    echo "  docker           - Docker and container management"
    echo "  cmake            - CMake build system integration"
    echo "  languages        - Multi-language development tools"
    echo "  work             - Work environment shortcuts"
    echo "  windows          - Windows-specific features"
    echo "  linux            - Linux-specific features"
    echo "  macos            - macOS-specific features"
}

update_component() {
    local component="$1"
    local backup_name="pre_update_$(date +%Y%m%d_%H%M%S)"

    # Create backup before updating
    log "Creating backup before update..."
    if command -v backup-manager.sh &>/dev/null; then
        backup-manager.sh create "$backup_name" "Backup before updating $component" >/dev/null 2>&1
    fi

    case "$component" in
        bashrc)
            update_bashrc
            ;;
        essential)
            update_layer "essential"
            ;;
        development)
            update_layer "development"
            ;;
        productivity)
            update_layer "productivity"
            ;;
        platform)
            update_layer "platform"
            ;;
        scripts)
            update_scripts
            ;;
        git)
            update_single_file "development/git.sh"
            ;;
        docker)
            update_single_file "development/docker.sh"
            ;;
        cmake)
            update_single_file "development/cmake.sh"
            ;;
        languages)
            update_single_file "development/languages.sh"
            ;;
        work)
            update_single_file "productivity/work.sh"
            ;;
        windows)
            update_single_file "platform/windows.sh"
            ;;
        linux)
            update_single_file "platform/linux.sh"
            ;;
        macos)
            update_single_file "platform/macos.sh"
            ;;
        *)
            error "Unknown component: $component"
            return 1
            ;;
    esac
}

update_bashrc() {
    log "Updating .bashrc..."

    local temp_bashrc="$TEMP_DIR/.bashrc"
    if download_file ".bashrc" "$temp_bashrc"; then
        # Check for local modifications
        if [[ -f ~/.bashrc ]] && ! diff -q ~/.bashrc "$temp_bashrc" >/dev/null 2>&1; then
            warn ".bashrc has local modifications"
            show_diff ~/.bashrc "$temp_bashrc"

            read -p "Overwrite local .bashrc? [y/N]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "Skipping .bashrc update"
                return 0
            fi
        fi

        cp "$temp_bashrc" ~/.bashrc
        log "Updated .bashrc"
    else
        error "Failed to download .bashrc"
        return 1
    fi
}

update_layer() {
    local layer="$1"
    log "Updating $layer layer..."

    local layer_dir="$CONFIG_DIR/$layer"
    local temp_layer_dir="$TEMP_DIR/config/bash/$layer"

    # Download all files in the layer
    mkdir -p "$temp_layer_dir"

    local files_to_update=()
    case "$layer" in
        essential)
            files_to_update=("core.sh" "environment.sh" "platform.sh" "navigation.sh" "motd.sh")
            ;;
        development)
            files_to_update=("git.sh" "docker.sh" "cmake.sh" "languages.sh" "tools.sh")
            ;;
        productivity)
            files_to_update=("work.sh" "system.sh")
            ;;
        platform)
            files_to_update=("windows.sh" "linux.sh" "macos.sh")
            ;;
    esac

    local updated_count=0
    for file in "${files_to_update[@]}"; do
        local remote_file="config/bash/$layer/$file"
        local temp_file="$temp_layer_dir/$file"
        local current_file="$layer_dir/$file"

        if download_file "$remote_file" "$temp_file"; then
            if [[ -f "$current_file" ]] && ! diff -q "$current_file" "$temp_file" >/dev/null 2>&1; then
                cp "$temp_file" "$current_file"
                log "Updated $layer/$file"
                ((updated_count++))
            elif [[ ! -f "$current_file" ]]; then
                mkdir -p "$layer_dir"
                cp "$temp_file" "$current_file"
                log "Added $layer/$file"
                ((updated_count++))
            fi
        else
            warn "Failed to download $remote_file"
        fi
    done

    if [[ $updated_count -eq 0 ]]; then
        log "$layer layer is already up to date"
    else
        log "Updated $updated_count files in $layer layer"
    fi
}

update_single_file() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    log "Updating $filename..."

    local remote_file="config/bash/$file_path"
    local temp_file="$TEMP_DIR/$file_path"
    local current_file="$CONFIG_DIR/$file_path"

    if download_file "$remote_file" "$temp_file"; then
        if [[ -f "$current_file" ]] && ! diff -q "$current_file" "$temp_file" >/dev/null 2>&1; then
            show_diff "$current_file" "$temp_file"

            read -p "Update $filename? [y/N]: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                mkdir -p "$(dirname "$current_file")"
                cp "$temp_file" "$current_file"
                log "Updated $filename"
            else
                log "Skipping $filename"
            fi
        elif [[ ! -f "$current_file" ]]; then
            mkdir -p "$(dirname "$current_file")"
            cp "$temp_file" "$current_file"
            log "Added $filename"
        else
            log "$filename is already up to date"
        fi
    else
        error "Failed to download $remote_file"
        return 1
    fi
}

update_scripts() {
    log "Updating utility scripts..."

    local scripts=("install.sh" "fix-permissions.sh" "transfer-ssh.sh" "validate-config.sh" "backup-manager.sh" "update-config.sh")
    local script_dir="$HOME/.local/bin"

    mkdir -p "$script_dir"

    for script in "${scripts[@]}"; do
        local temp_script="$TEMP_DIR/$script"
        local current_script="$script_dir/$script"

        if download_file "$script" "$temp_script"; then
            if [[ -f "$current_script" ]] && ! diff -q "$current_script" "$temp_script" >/dev/null 2>&1; then
                cp "$temp_script" "$current_script"
                chmod +x "$current_script"
                log "Updated $script"
            elif [[ ! -f "$current_script" ]]; then
                cp "$temp_script" "$current_script"
                chmod +x "$current_script"
                log "Added $script"
            fi
        else
            warn "Failed to download $script"
        fi
    done
}

show_diff() {
    local file1="$1"
    local file2="$2"

    echo
    info "Changes in $(basename "$file1"):"
    if command -v colordiff &>/dev/null; then
        colordiff -u "$file1" "$file2" | head -20
    else
        diff -u "$file1" "$file2" | head -20
    fi

    local line_count=$(diff -u "$file1" "$file2" | wc -l)
    if [[ $line_count -gt 20 ]]; then
        echo "... (showing first 20 lines of $line_count total)"
    fi
    echo
}

# ============================================================================
# FULL UPDATE PROCESS
# ============================================================================

full_update() {
    local current_version=$(get_current_version)
    local latest_version=$(get_latest_version)
    local version_comparison=$(compare_versions "$current_version" "$latest_version")

    header "Full Configuration Update"

    info "Current version: $current_version"
    info "Latest version: $latest_version"

    case "$version_comparison" in
        same)
            log "You are running the latest version"
            read -p "Force update anyway? [y/N]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return 0
            fi
            ;;
        newer)
            warn "Your version appears newer than the latest release"
            warn "You may be running a development version"
            read -p "Continue with update? [y/N]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return 0
            fi
            ;;
        older)
            log "Update available: $current_version -> $latest_version"
            ;;
        unknown)
            warn "Could not determine version information"
            read -p "Continue with update? [y/N]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return 0
            fi
            ;;
    esac

    # Show changes
    if [[ "$version_comparison" == "older" ]]; then
        show_changes "$current_version" "$latest_version"
        echo
    fi

    # Detect local changes
    detect_local_changes
    echo

    # Confirm update
    warn "This will update your bash configuration"
    read -p "Proceed with full update? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Update cancelled"
        return 0
    fi

    # Create backup
    local backup_name="pre_full_update_$(date +%Y%m%d_%H%M%S)"
    log "Creating backup before update..."
    if command -v backup-manager.sh &>/dev/null; then
        backup-manager.sh create "$backup_name" "Backup before full update to $latest_version" >/dev/null 2>&1
    fi

    # Update all components
    update_component "bashrc"
    update_component "essential"
    update_component "development"
    update_component "productivity"
    update_component "platform"
    update_component "scripts"

    # Update version info
    if [[ "$latest_version" != "unknown" ]]; then
        if [[ -f "$CONFIG_DIR/local.sh" ]]; then
            # Update version in local.sh
            if grep -q "BASH_CONFIG_VERSION=" "$CONFIG_DIR/local.sh"; then
                sed -i.bak "s/BASH_CONFIG_VERSION=.*/BASH_CONFIG_VERSION=\"$latest_version\"/" "$CONFIG_DIR/local.sh"
                rm -f "$CONFIG_DIR/local.sh.bak"
            else
                echo "BASH_CONFIG_VERSION=\"$latest_version\"" >> "$CONFIG_DIR/local.sh"
            fi

            # Update install date
            if grep -q "BASH_CONFIG_INSTALL_DATE=" "$CONFIG_DIR/local.sh"; then
                sed -i.bak "s/BASH_CONFIG_INSTALL_DATE=.*/BASH_CONFIG_INSTALL_DATE=\"$(date)\"/" "$CONFIG_DIR/local.sh"
                rm -f "$CONFIG_DIR/local.sh.bak"
            else
                echo "BASH_CONFIG_INSTALL_DATE=\"$(date)\"" >> "$CONFIG_DIR/local.sh"
            fi
        fi
    fi

    # Fix permissions
    log "Fixing permissions..."
    if command -v fix-permissions.sh &>/dev/null; then
        fix-permissions.sh >/dev/null 2>&1
    fi

    log "Update completed successfully!"
    warn "You may need to restart your shell or run 'source ~/.bashrc'"
}

# ============================================================================
# CLEANUP
# ============================================================================

cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# ============================================================================
# USAGE AND HELP
# ============================================================================

show_help() {
    echo "update-config.sh - Bash configuration update mechanism"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  check                        Check for available updates"
    echo "  update [component]           Update all or specific component"
    echo "  list                         List available components"
    echo "  changelog                    Show recent changes"
    echo "  diff <component>             Show differences for component"
    echo "  help                         Show this help"
    echo
    echo "Update Examples:"
    echo "  $0 check                     # Check for updates"
    echo "  $0 update                    # Full update (interactive)"
    echo "  $0 update git                # Update only git module"
    echo "  $0 update essential          # Update essential layer"
    echo "  $0 list                      # Show available components"
    echo
    echo "Components: bashrc, essential, development, productivity, platform, scripts"
    echo "Individual: git, docker, cmake, languages, work, windows, linux, macos"
}

# ============================================================================
# MAIN COMMAND PROCESSING
# ============================================================================

main() {
    local command="$1"
    shift 2>/dev/null || true

    # Setup temp directory
    mkdir -p "$TEMP_DIR"

    case "$command" in
        check)
            local current_version=$(get_current_version)
            local latest_version=$(get_latest_version)
            local version_comparison=$(compare_versions "$current_version" "$latest_version")

            info "Current version: $current_version"
            info "Latest version: $latest_version"

            case "$version_comparison" in
                same)
                    log "You are running the latest version"
                    ;;
                older)
                    warn "Update available: $current_version -> $latest_version"
                    echo "Run '$0 update' to update"
                    ;;
                newer)
                    info "Your version appears newer (development version?)"
                    ;;
                unknown)
                    warn "Could not determine version information"
                    ;;
            esac
            ;;
        update)
            if [[ -n "$1" ]]; then
                update_component "$1"
            else
                full_update
            fi
            ;;
        list)
            list_updateable_components
            ;;
        changelog)
            local current_version=$(get_current_version)
            local latest_version=$(get_latest_version)
            show_changes "$current_version" "$latest_version"
            ;;
        diff)
            if [[ -z "$1" ]]; then
                error "Component name required for diff"
                exit 1
            fi
            detect_local_changes
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
    echo "1) Check for updates"
    echo "2) Full update (all components)"
    echo "3) Update specific component"
    echo "4) Show changelog"
    echo "5) List available components"
    echo "6) Show component differences"
    echo "0) Exit"
    echo
    read -p "Enter choice: " choice
    handle_menu_choice "$choice"
}

handle_menu_choice() {
    local choice="$1"
    
    case $choice in
        1) 
            run check
            ;;
        2) 
            run update
            ;;
        3)
            echo
            run list
            echo
            read -p "Component name: " comp
            [[ -z "$comp" ]] && { echo "Component required"; sleep 1; show_menu; return; }
            run update "$comp"
            ;;
        4)
            run changelog
            ;;
        5)
            run list
            ;;
        6)
            echo
            run list
            echo
            read -p "Component name: " comp
            [[ -z "$comp" ]] && { echo "Component required"; sleep 1; show_menu; return; }
            run diff "$comp"
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