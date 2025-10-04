#!/bin/bash
# validate-config.sh
# Comprehensive validation and health check for bash configuration
# Verifies installation integrity, tests lazy loading, and reports issues


set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Validation counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
WARNINGS=0

# Test results storage
declare -a FAILED_TESTS=()
declare -a WARNING_MESSAGES=()

log() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARNING_MESSAGES+=("$1")
    ((WARNINGS++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED_TESTS+=("$1")
    ((TESTS_FAILED++))
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

header() {
    echo -e "\n${CYAN}=== $1 ===${NC}"
}

# Run a test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"

    ((TESTS_RUN++))
    
    if eval "$test_command" &>/dev/null; then
        log "$test_name"
    else
        fail "$test_name"
    fi
}

# ============================================================================
# CORE INSTALLATION VALIDATION
# ============================================================================

validate_core_installation() {
    header "Core Installation Validation"

    # Check main .bashrc file
    if [[ -f ~/.bashrc ]]; then
        if grep -q "bash-config" ~/.bashrc 2>/dev/null; then
            log ".bashrc contains bash-config integration"
        else
            fail ".bashrc exists but doesn't contain bash-config integration"
        fi
    else
        fail ".bashrc file not found"
    fi

    # Check config directory structure
    local required_dirs=(
        ~/.config/bash
        ~/.config/bash/essential
        ~/.config/bash/development
        ~/.config/bash/productivity
        ~/.config/bash/platform
    )

    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log "Directory exists: $dir"
        else
            fail "Missing directory: $dir"
        fi
    done

    # Check essential files
    local essential_files=(
        ~/.config/bash/essential/core.sh
        ~/.config/bash/essential/environment.sh
        ~/.config/bash/essential/platform.sh
        ~/.config/bash/essential/navigation.sh
    )

    for file in "${essential_files[@]}"; do
        if [[ -f "$file" ]]; then
            log "Essential file exists: $(basename "$file")"
        else
            fail "Missing essential file: $(basename "$file")"
        fi
    done
}

# ============================================================================
# PERMISSION VALIDATION
# ============================================================================

validate_permissions() {
    header "Permission Validation"

    # Check .bashrc permissions
    if [[ -f ~/.bashrc ]]; then
        local perm=$(stat -c %a ~/.bashrc 2>/dev/null || stat -f %A ~/.bashrc 2>/dev/null)
        if [[ "$perm" == "644" || "$perm" == "755" ]]; then
            log ".bashrc has correct permissions ($perm)"
        else
            warn ".bashrc permissions ($perm) might be too restrictive or too open"
        fi
    fi

    # Check config directory permissions
    if [[ -d ~/.config/bash ]]; then
        local perm=$(stat -c %a ~/.config/bash 2>/dev/null || stat -f %A ~/.config/bash 2>/dev/null)
        if [[ "$perm" == "755" ]]; then
            log "Config directory has correct permissions ($perm)"
        else
            warn "Config directory permissions ($perm) should be 755"
        fi
    fi

    # Check for overly permissive files
    local overly_permissive=$(find ~/.config/bash -type f -perm /o+w 2>/dev/null || true)
    if [[ -n "$overly_permissive" ]]; then
        warn "Found world-writable files in config directory"
        echo "$overly_permissive" | while read -r file; do
            warn "  $file"
        done
    else
        log "No world-writable files found"
    fi

    # Check local.sh permissions (should be restrictive)
    if [[ -f ~/.config/bash/local.sh ]]; then
        local perm=$(stat -c %a ~/.config/bash/local.sh 2>/dev/null || stat -f %A ~/.config/bash/local.sh 2>/dev/null)
        if [[ "$perm" == "600" ]]; then
            log "local.sh has secure permissions ($perm)"
        else
            warn "local.sh permissions ($perm) should be 600 for security"
        fi
    fi
}

# ============================================================================
# SYNTAX VALIDATION
# ============================================================================

validate_syntax() {
    header "Syntax Validation"

    # Check .bashrc syntax
    if bash -n ~/.bashrc 2>/dev/null; then
        log ".bashrc syntax is valid"
    else
        fail ".bashrc has syntax errors"
    fi

    # Check all bash configuration files
    local syntax_errors=0
    find ~/.config/bash -name "*.sh" -type f | while read -r file; do
        if bash -n "$file" 2>/dev/null; then
            log "$(basename "$file") syntax is valid"
        else
            fail "$(basename "$file") has syntax errors"
            ((syntax_errors++))
        fi
    done

    if [[ $syntax_errors -eq 0 ]]; then
        log "All configuration files have valid syntax"
    fi
}

# ============================================================================
# LAZY LOADING VALIDATION
# ============================================================================

validate_lazy_loading() {
    header "Lazy Loading System Validation"

    # Source the bashrc in a subshell to test loading
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
source ~/.bashrc &>/dev/null
declare -p LOADED_LAYERS &>/dev/null && echo "LOADED_LAYERS_EXISTS=1"
declare -p LOADED_FILES &>/dev/null && echo "LOADED_FILES_EXISTS=1"
declare -F load_layer &>/dev/null && echo "LOAD_LAYER_FUNCTION_EXISTS=1"
declare -F load_file &>/dev/null && echo "LOAD_FILE_FUNCTION_EXISTS=1"
declare -F smart_cd &>/dev/null && echo "SMART_CD_FUNCTION_EXISTS=1"
EOF

    local results=$(bash "$temp_script" 2>/dev/null)

    if echo "$results" | grep -q "LOADED_LAYERS_EXISTS=1"; then
        log "LOADED_LAYERS array is properly initialized"
    else
        fail "LOADED_LAYERS array not found"
    fi

    if echo "$results" | grep -q "LOADED_FILES_EXISTS=1"; then
        log "LOADED_FILES array is properly initialized"
    else
        fail "LOADED_FILES array not found"
    fi

    if echo "$results" | grep -q "LOAD_LAYER_FUNCTION_EXISTS=1"; then
        log "load_layer function is available"
    else
        fail "load_layer function not found"
    fi

    if echo "$results" | grep -q "LOAD_FILE_FUNCTION_EXISTS=1"; then
        log "load_file function is available"
    else
        fail "load_file function not found"
    fi

    if echo "$results" | grep -q "SMART_CD_FUNCTION_EXISTS=1"; then
        log "smart_cd function is available"
    else
        fail "smart_cd function not found"
    fi

    rm -f "$temp_script"
}

# ============================================================================
# MODULE AVAILABILITY VALIDATION
# ============================================================================

validate_modules() {
    header "Module Availability Validation"

    # Test each layer can be loaded
    local layers=("essential" "development" "productivity" "platform")

    for layer in "${layers[@]}"; do
        local layer_dir="$HOME/.config/bash/$layer"
        if [[ -d "$layer_dir" ]]; then
            local file_count=$(find "$layer_dir" -name "*.sh" -type f | wc -l)
            if [[ $file_count -gt 0 ]]; then
                log "$layer layer has $file_count module files"
            else
                warn "$layer layer directory exists but contains no .sh files"
            fi
        else
            fail "$layer layer directory not found"
        fi
    done

    # Test essential modules load without errors
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
source ~/.bashrc &>/dev/null
load_layer essential &>/dev/null && echo "ESSENTIAL_LOADED=1"
load_layer platform &>/dev/null && echo "PLATFORM_LOADED=1"
EOF

    local results=$(bash "$temp_script" 2>/dev/null)

    if echo "$results" | grep -q "ESSENTIAL_LOADED=1"; then
        log "Essential layer loads without errors"
    else
        fail "Essential layer failed to load"
    fi

    if echo "$results" | grep -q "PLATFORM_LOADED=1"; then
        log "Platform layer loads without errors"
    else
        fail "Platform layer failed to load"
    fi

    rm -f "$temp_script"
}

# ============================================================================
# COMMAND TRIGGER VALIDATION
# ============================================================================

validate_command_triggers() {
    header "Command Trigger Validation"

    # Test command_not_found_handle function
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
source ~/.bashrc &>/dev/null
declare -F command_not_found_handle &>/dev/null && echo "COMMAND_NOT_FOUND_EXISTS=1"
EOF

    local results=$(bash "$temp_script" 2>/dev/null)

    if echo "$results" | grep -q "COMMAND_NOT_FOUND_EXISTS=1"; then
        log "command_not_found_handle function is properly set up"
    else
        fail "command_not_found_handle function not found"
    fi

    # Test some known trigger commands exist in the handler
    if grep -q "git\|docker\|cmake" ~/.bashrc; then
        log "Command triggers are configured in .bashrc"
    else
        warn "Command triggers might not be properly configured"
    fi

    rm -f "$temp_script"
}

# ============================================================================
# DEPENDENCY VALIDATION
# ============================================================================

validate_dependencies() {
    header "External Dependency Validation"

    # Check for common tools used by the configuration
    local tools=(
        "git:development features"
        "docker:container management"
        "curl:remote operations"
        "ssh:secure connections"
        "nano:default editor"
    )

    for tool_info in "${tools[@]}"; do
        local tool="${tool_info%%:*}"
        local purpose="${tool_info##*:}"

        if command -v "$tool" &>/dev/null; then
            log "$tool is available ($purpose)"
        else
            warn "$tool not found - some $purpose may not work"
        fi
    done

    # Check for platform-specific tools
    case "$(uname -s)" in
        Darwin)
            if command -v brew &>/dev/null; then
                log "Homebrew package manager available"
            else
                warn "Homebrew not found - macOS package management features disabled"
            fi
            ;;
        Linux)
            local pkg_managers=("apt" "pacman" "dnf" "zypper")
            local found_pm=false
            for pm in "${pkg_managers[@]}"; do
                if command -v "$pm" &>/dev/null; then
                    log "$pm package manager available"
                    found_pm=true
                    break
                fi
            done
            if [[ "$found_pm" == false ]]; then
                warn "No recognized package manager found"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            if command -v choco &>/dev/null || command -v scoop &>/dev/null || command -v winget &>/dev/null; then
                log "Windows package manager available"
            else
                warn "No Windows package manager found (choco/scoop/winget)"
            fi
            ;;
    esac
}

# ============================================================================
# CONFIGURATION DRIFT DETECTION
# ============================================================================

validate_configuration_drift() {
    header "Configuration Drift Detection"

    # Check for version information
    if [[ -f ~/.config/bash/local.sh ]]; then
        if grep -q "BASH_CONFIG_VERSION" ~/.config/bash/local.sh; then
            local version=$(grep "BASH_CONFIG_VERSION" ~/.config/bash/local.sh | cut -d'"' -f2)
            log "Configuration version: $version"
        else
            warn "No version information found - configuration may be outdated"
        fi

        if grep -q "BASH_CONFIG_INSTALL_DATE" ~/.config/bash/local.sh; then
            local install_date=$(grep "BASH_CONFIG_INSTALL_DATE" ~/.config/bash/local.sh | cut -d'"' -f2)
            log "Installation date: $install_date"
        fi
    fi

    # Check for common customization signs
    if [[ -f ~/.config/bash/local.sh ]]; then
        local lines=$(wc -l < ~/.config/bash/local.sh)
        if [[ $lines -gt 50 ]]; then
            log "local.sh has $lines lines (well customized)"
        elif [[ $lines -gt 10 ]]; then
            log "local.sh has $lines lines (some customization)"
        else
            warn "local.sh has only $lines lines (minimal customization)"
        fi
    fi

    # Check for broken symlinks
    local broken_links=$(find ~/.config/bash -type l ! -exec test -e {} \; -print 2>/dev/null)
    if [[ -n "$broken_links" ]]; then
        warn "Found broken symlinks:"
        echo "$broken_links" | while read -r link; do
            warn "  $link"
        done
    else
        log "No broken symlinks found"
    fi
}

# ============================================================================
# PERFORMANCE VALIDATION
# ============================================================================

validate_performance() {
    header "Performance Validation"

    # Measure bash startup time
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
start_time=$(date +%s%3N)
source ~/.bashrc &>/dev/null
end_time=$(date +%s%3N)
echo $((end_time - start_time))
EOF

    local startup_time=$(bash "$temp_script" 2>/dev/null)
    rm -f "$temp_script"

    if [[ -n "$startup_time" ]]; then
        if [[ $startup_time -lt 100 ]]; then
            log "Startup time: ${startup_time}ms (excellent)"
        elif [[ $startup_time -lt 200 ]]; then
            log "Startup time: ${startup_time}ms (good)"
        elif [[ $startup_time -lt 500 ]]; then
            warn "Startup time: ${startup_time}ms (acceptable but could be improved)"
        else
            warn "Startup time: ${startup_time}ms (slow - consider optimization)"
        fi
    else
        warn "Could not measure startup time"
    fi

    # Check for large files that might slow loading
    local large_files=$(find ~/.config/bash -name "*.sh" -size +50k 2>/dev/null)
    if [[ -n "$large_files" ]]; then
        warn "Found large configuration files (>50KB):"
        echo "$large_files" | while read -r file; do
            local size=$(du -h "$file" | cut -f1)
            warn "  $file ($size)"
        done
    else
        log "No unusually large configuration files found"
    fi
}

# ============================================================================
# INTEGRATION VALIDATION
# ============================================================================

validate_integration() {
    header "Integration Validation"

    # Check if starship is configured and working
    if command -v starship &>/dev/null; then
        if grep -q "starship init" ~/.bashrc; then
            log "Starship prompt integration configured"
        else
            warn "Starship available but not integrated in .bashrc"
        fi
    fi

    # Check tmux integration
    if command -v tmux &>/dev/null; then
        if [[ -f ~/.config/tmux/tmux.conf ]]; then
            log "Custom tmux configuration found"
        else
            info "Tmux available but no custom config found"
        fi
    fi

    # Check for SSH configuration
    if [[ -d ~/.ssh ]]; then
        local key_count=$(find ~/.ssh -name "id_*" -not -name "*.pub" 2>/dev/null | wc -l)
        if [[ $key_count -gt 0 ]]; then
            log "SSH keys configured ($key_count private keys found)"
        else
            warn "SSH directory exists but no private keys found"
        fi

        if [[ -f ~/.ssh/config ]]; then
            log "SSH config file exists"
        else
            info "No SSH config file found"
        fi
    else
        warn "No SSH directory found"
    fi
}

# ============================================================================
# MAIN VALIDATION RUNNER
# ============================================================================

show_summary() {
    echo
    echo -e "${CYAN}=== VALIDATION SUMMARY ===${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo
        echo -e "${RED}Failed tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗${NC} $test"
        done
    fi

    if [[ $WARNINGS -gt 0 ]]; then
        echo
        echo -e "${YELLOW}Warnings:${NC}"
        for warning in "${WARNING_MESSAGES[@]}"; do
            echo -e "  ${YELLOW}⚠${NC} $warning"
        done
    fi

    echo
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ Configuration validation completed successfully!${NC}"
        if [[ $WARNINGS -gt 0 ]]; then
            echo -e "${YELLOW}  Note: Some warnings were found but don't affect functionality${NC}"
        fi
        exit 0
    else
        echo -e "${RED}✗ Configuration validation failed with $TESTS_FAILED error(s)${NC}"
        echo -e "${YELLOW}  Run the installer or fix-permissions script to resolve issues${NC}"
        exit 1
    fi
}

# ============================================================================
# COMMAND LINE OPTIONS
# ============================================================================

show_help() {
    echo "validate-config.sh - Bash configuration validation tool"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --quick     Run only essential validations (faster)"
    echo "  --verbose   Show detailed output during validation"
    echo "  --fix       Attempt to fix common issues automatically"
    echo "  --help      Show this help message"
    echo
    echo "Exit codes:"
    echo "  0  All validations passed"
    echo "  1  One or more validations failed"
}

# Parse command line options
QUICK_MODE=false
VERBOSE_MODE=false
FIX_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --verbose)
            VERBOSE_MODE=true
            shift
            ;;
        --fix)
            FIX_MODE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    info "Bash Configuration Validation Tool"
    info "Starting comprehensive validation..."

    # Always run core validations
    validate_core_installation
    validate_permissions
    validate_syntax
    validate_lazy_loading

    if [[ "$QUICK_MODE" == false ]]; then
        validate_modules
        validate_command_triggers
        validate_dependencies
        validate_configuration_drift
        validate_performance
        validate_integration
    fi

    show_summary
}

show_menu() {
    clear
    echo "=== $DESCRIPTION ==="
    echo
    echo "Select an option:"
    echo
    echo "1) Full validation"
    echo "2) Quick validation (essential checks only)"
    echo "3) Performance check only"
    echo "4) Syntax validation only"
    echo "5) Permission validation only"
    echo "6) Fix common issues automatically"
    echo "0) Exit"
    echo
    read -p "Enter choice: " choice
    handle_menu_choice "$choice"
}

handle_menu_choice() {
    local choice="$1"
    
    case $choice in
        1) 
            run
            ;;
        2) 
            run --quick
            ;;
        3)
            validate_performance
            ;;
        4)
            validate_syntax
            ;;
        5)
            validate_permissions
            ;;
        6)
            run --fix
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