#!/bin/bash
# Enhanced Permission Management for Bash Configuration
# 
# This script provides comprehensive permission setting for bash configuration,
# SSH keys, and Git config with platform-aware security practices. It implements
# security best practices while handling the complexities of different operating
# systems, file systems, and execution environments.


set -e  # Exit on any error

# ============================================================================
# PERMISSION SECURITY FRAMEWORK
# ============================================================================
#
# SECURITY PRINCIPLES IMPLEMENTED:
# 1. Principle of Least Privilege: Grant minimum necessary permissions
# 2. Defense in Depth: Multiple layers of security validation
# 3. Platform Awareness: Respect OS-specific security models
# 4. Auditability: Log all permission changes for security review
# 5. Fail-Safe Defaults: Secure permissions when in doubt
#
# PERMISSION STRATEGY:
# - Configuration files: Readable by owner and group (644)
# - Sensitive files: Owner-only access (600)
# - Directories: Executable for traversal (755/700 based on sensitivity)
# - SSH keys: Strict permissions following OpenSSH requirements
# - Scripts: Executable with appropriate access controls
#
# THREAT MODEL CONSIDERATIONS:
# - Unauthorized local access to configuration files
# - SSH key compromise through file system permissions
# - Information disclosure through overly permissive files
# - Cross-platform permission model differences

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Permission operation tracking
OPERATIONS_PERFORMED=0
SECURITY_ISSUES_FOUND=0
PERMISSION_ERRORS=0

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
    ((OPERATIONS_PERFORMED++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((SECURITY_ISSUES_FOUND++))
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((PERMISSION_ERRORS++))
}

# ============================================================================
# PLATFORM DETECTION FOR PERMISSION STRATEGY
# ============================================================================

# Platform-aware permission handling
# Different operating systems have varying support for Unix permissions
detect_platform_permissions() {
    # WINDOWS PLATFORM DETECTION
    # Windows has limited POSIX permission support, especially in different environments
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$MSYSTEM" ]]; then
        PLATFORM="windows"
        
        # Determine Windows environment capabilities
        if [[ -n "$WSL_DISTRO_NAME" ]]; then
            # WSL has full POSIX permission support
            PERMISSION_SUPPORT="full"
            PLATFORM_VARIANT="wsl"
        elif [[ "$OSTYPE" == "cygwin" ]]; then
            # Cygwin has partial permission support
            PERMISSION_SUPPORT="partial"
            PLATFORM_VARIANT="cygwin"
        else
            # Git Bash/MSYS2 has limited permission support
            PERMISSION_SUPPORT="limited"
            PLATFORM_VARIANT="msys"
        fi
        
    # MACOS PLATFORM DETECTION
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        PLATFORM="macos"
        PERMISSION_SUPPORT="full"
        
        # macOS-specific permission considerations
        # Extended attributes and ACLs may affect permission behavior
        MACOS_VERSION=$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)
        
    # LINUX/UNIX PLATFORM DETECTION
    else
        PLATFORM="linux"
        PERMISSION_SUPPORT="full"
        
        # Linux-specific permission features
        # Check for extended attributes and SELinux
        if command -v getenforce &>/dev/null && getenforce 2>/dev/null | grep -q "Enforcing"; then
            SELINUX_ENABLED=true
        else
            SELINUX_ENABLED=false
        fi
    fi
    
    log "Detected platform: $PLATFORM ($PLATFORM_VARIANT) with $PERMISSION_SUPPORT permission support"
}

# ============================================================================
# PERMISSION VALIDATION AND ANALYSIS
# ============================================================================

# Analyze current permissions and identify security issues
analyze_current_permissions() {
    log "Analyzing current permission state..."
    
    local security_issues=0
    
    # BASH CONFIGURATION ANALYSIS
    if [[ -f ~/.bashrc ]]; then
        local bashrc_perms=$(stat -c %a ~/.bashrc 2>/dev/null || stat -f %A ~/.bashrc 2>/dev/null)
        
        # Check for overly permissive .bashrc
        if [[ "$bashrc_perms" == *7 ]] || [[ "$bashrc_perms" == *6 ]]; then
            warn "~/.bashrc is world-writable (current: $bashrc_perms)"
            ((security_issues++))
        fi
        
        # Check for overly restrictive .bashrc
        if [[ "$bashrc_perms" == "600" ]]; then
            warn "~/.bashrc may be too restrictive for some systems (current: $bashrc_perms)"
        fi
    fi
    
    # SSH DIRECTORY ANALYSIS
    if [[ -d ~/.ssh ]]; then
        local ssh_dir_perms=$(stat -c %a ~/.ssh 2>/dev/null || stat -f %A ~/.ssh 2>/dev/null)
        
        # SSH directory must be 700 for OpenSSH to function
        if [[ "$ssh_dir_perms" != "700" ]]; then
            warn "SSH directory permissions incorrect (current: $ssh_dir_perms, should be: 700)"
            ((security_issues++))
        fi
        
        # Analyze SSH keys
        analyze_ssh_key_permissions
    fi
    
    # BASH CONFIG DIRECTORY ANALYSIS
    if [[ -d ~/.config/bash ]]; then
        analyze_bash_config_permissions
    fi
    
    log "Permission analysis complete: $security_issues security issues found"
    return $security_issues
}

# SSH key permission analysis with security assessment
analyze_ssh_key_permissions() {
    log "Analyzing SSH key permissions..."
    
    # PRIVATE KEY ANALYSIS
    # Private keys must be 600 or SSH will reject them
    local private_key_patterns=("id_*" "*_rsa" "*_ed25519" "*_ecdsa")
    
    for pattern in "${private_key_patterns[@]}"; do
        while IFS= read -r -d '' key_file; do
            # Skip public keys
            [[ "$key_file" == *.pub ]] && continue
            
            local key_perms=$(stat -c %a "$key_file" 2>/dev/null || stat -f %A "$key_file" 2>/dev/null)
            
            if [[ "$key_perms" != "600" ]]; then
                if [[ "$key_perms" == *7 ]] || [[ "$key_perms" == *6 ]] || [[ "$key_perms" == *5 ]] || [[ "$key_perms" == *4 ]]; then
                    error "CRITICAL: Private key $key_file has insecure permissions ($key_perms)"
                    error "SSH will refuse to use this key!"
                    ((SECURITY_ISSUES_FOUND++))
                else
                    warn "Private key $key_file permissions could be more restrictive ($key_perms)"
                fi
            fi
        done < <(find ~/.ssh -name "$pattern" -type f -print0 2>/dev/null)
    done
    
    # PUBLIC KEY ANALYSIS
    # Public keys should be readable but not writable by others
    while IFS= read -r -d '' pub_key; do
        local pub_perms=$(stat -c %a "$pub_key" 2>/dev/null || stat -f %A "$pub_key" 2>/dev/null)
        
        if [[ "$pub_perms" == *2 ]] || [[ "$pub_perms" == *3 ]] || [[ "$pub_perms" == *6 ]] || [[ "$pub_perms" == *7 ]]; then
            warn "Public key $pub_key is writable by others ($pub_perms)"
            ((SECURITY_ISSUES_FOUND++))
        fi
    done < <(find ~/.ssh -name "*.pub" -type f -print0 2>/dev/null)
    
    # SSH CONFIG FILE ANALYSIS
    if [[ -f ~/.ssh/config ]]; then
        local config_perms=$(stat -c %a ~/.ssh/config 2>/dev/null || stat -f %A ~/.ssh/config 2>/dev/null)
        
        if [[ "$config_perms" != "600" ]]; then
            warn "SSH config file should have 600 permissions (current: $config_perms)"
            ((SECURITY_ISSUES_FOUND++))
        fi
    fi
}

# Bash configuration directory permission analysis
analyze_bash_config_permissions() {
    log "Analyzing bash configuration permissions..."
    
    # Check directory structure permissions
    local config_dirs=("~/.config" "~/.config/bash")
    for dir in "${config_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local dir_perms=$(stat -c %a "$dir" 2>/dev/null || stat -f %A "$dir" 2>/dev/null)
            
            if [[ "$dir_perms" != "755" ]]; then
                warn "Config directory $dir permissions should be 755 (current: $dir_perms)"
            fi
        fi
    done
    
    # Check for world-writable configuration files
    if find ~/.config/bash -type f -perm /o+w 2>/dev/null | grep -q .; then
        error "Found world-writable files in bash configuration"
        find ~/.config/bash -type f -perm /o+w 2>/dev/null | while read -r file; do
            error "  World-writable: $file"
        done
        ((SECURITY_ISSUES_FOUND++))
    fi
    
    # Check local.sh security
    if [[ -f ~/.config/bash/local.sh ]]; then
        local local_perms=$(stat -c %a ~/.config/bash/local.sh 2>/dev/null || stat -f %A ~/.config/bash/local.sh 2>/dev/null)
        
        if [[ "$local_perms" != "600" ]]; then
            warn "local.sh contains sensitive information and should have 600 permissions (current: $local_perms)"
            ((SECURITY_ISSUES_FOUND++))
        fi
    fi
}

# ============================================================================
# INTELLIGENT PERMISSION SETTING
# ============================================================================

# Set bash configuration permissions with platform awareness
set_bash_permissions() {
    log "Setting bash configuration permissions..."
    
    # BASHRC PERMISSION SETTING
    # .bashrc needs to be readable by the shell but should not be writable by others
    if [[ -f ~/.bashrc ]]; then
        case "$PERMISSION_SUPPORT" in
            full)
                # Full permission support: use secure 644 permissions
                chmod 644 ~/.bashrc
                log "Set ~/.bashrc permissions to 644 (owner: rw, group: r, others: r)"
                ;;
            partial|limited)
                # Limited permission support: ensure basic readability
                chmod 644 ~/.bashrc 2>/dev/null || {
                    warn "Limited permission support on this platform"
                    # Fallback for Windows environments
                    attrib -r ~/.bashrc 2>/dev/null || true
                }
                ;;
        esac
    fi
    
    # BASH CONFIG DIRECTORY STRUCTURE
    if [[ -d ~/.config/bash ]]; then
        case "$PERMISSION_SUPPORT" in
            full)
                # Set directory permissions for proper traversal
                chmod 755 ~/.config 2>/dev/null || true
                chmod 755 ~/.config/bash
                
                # Set permissions on subdirectories
                find ~/.config/bash -type d -exec chmod 755 {} \; 2>/dev/null || true
                log "Set bash config directory permissions to 755"
                
                # CONFIGURATION FILE PERMISSIONS
                # Most config files should be readable by owner and group
                find ~/.config/bash -type f -name "*.sh" -exec chmod 644 {} \; 2>/dev/null || true
                log "Set configuration file permissions to 644"
                
                # SENSITIVE FILE HANDLING
                # local.sh contains sensitive information and should be owner-only
                if [[ -f ~/.config/bash/local.sh ]]; then
                    chmod 600 ~/.config/bash/local.sh
                    log "Set restrictive permissions on local.sh (600 - owner only)"
                fi
                
                # Handle backup files securely
                find ~/.config/bash -name "*.backup.*" -exec chmod 600 {} \; 2>/dev/null || true
                ;;
            partial|limited)
                # Best effort on limited platforms
                find ~/.config/bash -type f -name "*.sh" -exec chmod 644 {} \; 2>/dev/null || true
                [[ -f ~/.config/bash/local.sh ]] && chmod 600 ~/.config/bash/local.sh 2>/dev/null || true
                warn "Applied basic permissions - full security not available on this platform"
                ;;
        esac
    else
        warn "~/.config/bash directory not found - skipping bash config permissions"
    fi
}

# Set SSH permissions with OpenSSH compliance
set_ssh_permissions() {
    log "Setting SSH permissions with OpenSSH compliance..."
    
    if [[ ! -d ~/.ssh ]]; then
        warn "~/.ssh directory not found - skipping SSH permissions"
        return 0
    fi
    
    case "$PERMISSION_SUPPORT" in
        full)
            # SSH DIRECTORY PERMISSIONS
            # OpenSSH requires 700 permissions on .ssh directory
            chmod 700 ~/.ssh
            log "Set ~/.ssh directory permissions to 700 (owner-only access)"
            
            # PRIVATE KEY PERMISSIONS
            # Private keys must be 600 or SSH will refuse to use them
            local private_key_count=0
            local key_patterns=("id_*" "*_rsa" "*_ed25519" "*_ecdsa" "*_dsa")
            
            for pattern in "${key_patterns[@]}"; do
                while IFS= read -r -d '' key_file; do
                    # Skip public keys and known_hosts
                    [[ "$key_file" == *.pub ]] && continue
                    [[ "$(basename "$key_file")" == "known_hosts" ]] && continue
                    [[ "$(basename "$key_file")" == "authorized_keys" ]] && continue
                    [[ "$(basename "$key_file")" == "config" ]] && continue
                    
                    chmod 600 "$key_file"
                    ((private_key_count++))
                done < <(find ~/.ssh -name "$pattern" -type f -print0 2>/dev/null)
            done
            
            if [[ $private_key_count -gt 0 ]]; then
                log "Set permissions on $private_key_count private key(s) to 600"
            fi
            
            # PUBLIC KEY PERMISSIONS
            # Public keys should be readable but not writable by others
            local public_key_count=0
            while IFS= read -r -d '' pub_key; do
                chmod 644 "$pub_key"
                ((public_key_count++))
            done < <(find ~/.ssh -name "*.pub" -type f -print0 2>/dev/null)
            
            if [[ $public_key_count -gt 0 ]]; then
                log "Set permissions on $public_key_count public key(s) to 644"
            fi
            
            # SSH CONFIGURATION FILES
            # SSH config and authorized_keys should be owner-only
            [[ -f ~/.ssh/config ]] && chmod 600 ~/.ssh/config && log "Set SSH config permissions to 600"
            [[ -f ~/.ssh/authorized_keys ]] && chmod 600 ~/.ssh/authorized_keys && log "Set authorized_keys permissions to 600"
            
            # known_hosts can be group-readable
            [[ -f ~/.ssh/known_hosts ]] && chmod 644 ~/.ssh/known_hosts && log "Set known_hosts permissions to 644"
            
            # SSH CONFIG_FILES DIRECTORY
            # Some setups use a config_files directory for modular SSH config
            if [[ -d ~/.ssh/config_files ]]; then
                chmod 700 ~/.ssh/config_files
                find ~/.ssh/config_files -type f -exec chmod 600 {} \;
                log "Set permissions on SSH config_files directory and contents"
            fi
            ;;
        partial|limited)
            # Best effort on platforms with limited permission support
            chmod 700 ~/.ssh 2>/dev/null || true
            find ~/.ssh -name "id_*" ! -name "*.pub" -exec chmod 600 {} \; 2>/dev/null || true
            find ~/.ssh -name "*.pub" -exec chmod 644 {} \; 2>/dev/null || true
            [[ -f ~/.ssh/config ]] && chmod 600 ~/.ssh/config 2>/dev/null || true
            warn "Applied basic SSH permissions - limited platform support"
            ;;
    esac
}

# Set Git configuration permissions
set_git_permissions() {
    log "Setting Git configuration permissions..."
    
    # GIT GLOBAL CONFIG
    # Git config files don't contain sensitive information but should not be writable by others
    if [[ -f ~/.gitconfig ]]; then
        case "$PERMISSION_SUPPORT" in
            full)
                chmod 644 ~/.gitconfig
                log "Set ~/.gitconfig permissions to 644"
                ;;
            partial|limited)
                chmod 644 ~/.gitconfig 2>/dev/null || true
                ;;
        esac
    else
        warn "~/.gitconfig not found"
    fi
    
    # GLOBAL GITIGNORE FILE
    if [[ -f ~/.gitignore_global ]]; then
        case "$PERMISSION_SUPPORT" in
            full)
                chmod 644 ~/.gitignore_global
                log "Set ~/.gitignore_global permissions to 644"
                ;;
            partial|limited)
                chmod 644 ~/.gitignore_global 2>/dev/null || true
                ;;
        esac
    fi
}

# ============================================================================
# OWNERSHIP MANAGEMENT
# ============================================================================

# Set proper ownership on configuration files
set_ownership() {
    if [[ "$PLATFORM" == "windows" ]]; then
        log "Skipping ownership changes on Windows platform"
        return 0
    fi
    
    if [[ "$PERMISSION_SUPPORT" != "full" ]]; then
        warn "Limited ownership support on this platform"
        return 0
    fi
    
    log "Setting ownership to $USER..."
    
    # OWNERSHIP SETTING WITH ERROR HANDLING
    # Some systems may not allow ownership changes or user may not have permission
    
    local ownership_errors=0
    
    # Bash configuration ownership
    if [[ -f ~/.bashrc ]]; then
        if chown "$USER:$USER" ~/.bashrc 2>/dev/null; then
            log "Set ownership on ~/.bashrc"
        else
            warn "Could not set ownership on ~/.bashrc (may require sudo)"
            ((ownership_errors++))
        fi
    fi
    
    if [[ -d ~/.config/bash ]]; then
        if chown -R "$USER:$USER" ~/.config/bash 2>/dev/null; then
            log "Set recursive ownership on ~/.config/bash"
        else
            warn "Could not set ownership on ~/.config/bash (may require sudo)"
            ((ownership_errors++))
        fi
    fi
    
    # SSH configuration ownership
    if [[ -d ~/.ssh ]]; then
        if chown -R "$USER:$USER" ~/.ssh 2>/dev/null; then
            log "Set recursive ownership on ~/.ssh"
        else
            warn "Could not set ownership on ~/.ssh (may require sudo)"
            ((ownership_errors++))
        fi
    fi
    
    # Git configuration ownership
    [[ -f ~/.gitconfig ]] && chown "$USER:$USER" ~/.gitconfig 2>/dev/null || true
    [[ -f ~/.gitignore_global ]] && chown "$USER:$USER" ~/.gitignore_global 2>/dev/null || true
    
    if [[ $ownership_errors -eq 0 ]]; then
        log "Ownership set successfully on all configuration files"
    else
        warn "Some ownership changes failed - this may be normal on certain systems"
    fi
}

# ============================================================================
# CRITICAL SECURITY VERIFICATION
# ============================================================================

# Verify critical SSH permissions that affect functionality
verify_critical_ssh_permissions() {
    if [[ ! -d ~/.ssh ]]; then
        return 0
    fi
    
    log "Verifying critical SSH security requirements..."
    
    local critical_failures=0
    
    # VERIFY SSH DIRECTORY PERMISSIONS
    # OpenSSH will refuse to work if .ssh directory is not 700
    local ssh_dir_perms=$(stat -c %a ~/.ssh 2>/dev/null || stat -f %A ~/.ssh 2>/dev/null)
    if [[ "$ssh_dir_perms" != "700" ]] && [[ "$PERMISSION_SUPPORT" == "full" ]]; then
        error "CRITICAL: SSH directory permissions are $ssh_dir_perms (must be 700)"
        error "OpenSSH will refuse to use SSH keys with incorrect directory permissions"
        ((critical_failures++))
    fi
    
    # VERIFY PRIVATE KEY PERMISSIONS
    # SSH will refuse to use private keys that are readable by others
    local private_key_failures=0
    local key_patterns=("id_*" "*_rsa" "*_ed25519" "*_ecdsa")
    
    for pattern in "${key_patterns[@]}"; do
        while IFS= read -r -d '' key_file; do
            [[ "$key_file" == *.pub ]] && continue
            
            local key_perms=$(stat -c %a "$key_file" 2>/dev/null || stat -f %A "$key_file" 2>/dev/null)
            if [[ "$key_perms" != "600" ]] && [[ "$PERMISSION_SUPPORT" == "full" ]]; then
                # Check if key is readable by group or others
                if [[ "$key_perms" =~ [4567][4567]? ]] || [[ "$key_perms" =~ ..[4567] ]]; then
                    error "CRITICAL: Private key $(basename "$key_file") has insecure permissions ($key_perms)"
                    error "SSH will refuse to use this key - run this script again to fix"
                    ((private_key_failures++))
                fi
            fi
        done < <(find ~/.ssh -name "$pattern" -type f -print0 2>/dev/null)
    done
    
    critical_failures=$((critical_failures + private_key_failures))
    
    if [[ $critical_failures -eq 0 ]]; then
        log "All critical SSH security requirements verified"
    else
        error "Found $critical_failures critical SSH security issues that may prevent SSH from working"
        return 1
    fi
    
    return 0
}

# Verify that all permissions are set correctly
verify_all_permissions() {
    log "Performing comprehensive permission verification..."
    
    local verification_failures=0
    
    # Re-run permission analysis to check our work
    local issues_before=$SECURITY_ISSUES_FOUND
    analyze_current_permissions >/dev/null 2>&1
    local issues_after=$SECURITY_ISSUES_FOUND
    
    # Calculate how many issues we fixed
    local issues_fixed=$((issues_before - issues_after))
    
    if [[ $issues_after -eq $issues_before ]]; then
        log "Permission verification complete - no new issues found"
    elif [[ $issues_after -lt $issues_before ]]; then
        log "Fixed $issues_fixed permission issues during this run"
    else
        warn "Some permission issues may still exist"
        ((verification_failures++))
    fi
    
    # Verify critical SSH functionality
    if ! verify_critical_ssh_permissions; then
        ((verification_failures++))
    fi
    
    return $verification_failures
}

# ============================================================================
# PERMISSION REPORTING AND SUMMARY
# ============================================================================

# Generate detailed permission report
generate_permission_report() {
    echo
    log "=== PERMISSION MANAGEMENT SUMMARY ==="
    echo "Platform: $PLATFORM ($PLATFORM_VARIANT)"
    echo "Permission Support: $PERMISSION_SUPPORT"
    echo "Operations Performed: $OPERATIONS_PERFORMED"
    echo "Security Issues Found: $SECURITY_ISSUES_FOUND"
    echo "Permission Errors: $PERMISSION_ERRORS"
    echo
    
    log "Applied Permission Schema:"
    echo "  ~/.bashrc                    644 (readable by owner/group)"
    echo "  ~/.config/bash/*.sh          644 (readable by owner/group)"
    echo "  ~/.config/bash/local.sh      600 (owner only - contains sensitive data)"
    echo "  ~/.ssh/                      700 (owner only directory)"
    echo "  ~/.ssh/id_* (private keys)   600 (owner only - SSH requirement)"
    echo "  ~/.ssh/*.pub (public keys)   644 (readable by others)"
    echo "  ~/.ssh/config                600 (owner only - may contain sensitive data)"
    echo "  ~/.ssh/authorized_keys       600 (owner only - SSH requirement)"
    echo "  ~/.ssh/known_hosts           644 (readable by others)"
    echo "  ~/.gitconfig                 644 (readable by owner/group)"
    echo
    
    if [[ $SECURITY_ISSUES_FOUND -gt 0 ]]; then
        warn "Security recommendations:"
        echo "  - Review any remaining permission warnings above"
        echo "  - Consider enabling additional security measures if available"
        if [[ "$SELINUX_ENABLED" == true ]]; then
            echo "  - Verify SELinux contexts are appropriate for SSH keys"
        fi
    fi
    
    if [[ $PERMISSION_ERRORS -gt 0 ]]; then
        warn "Some permission operations failed:"
        echo "  - This may be normal on certain platforms or file systems"
        echo "  - Verify that SSH and bash functionality work as expected"
        echo "  - Consider running with elevated privileges if issues persist"
    fi
}

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

show_help() {
    echo "fix-permissions.sh - Comprehensive permission management for bash configuration"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --analyze      Analyze current permissions without making changes"
    echo "  --ssh-only     Fix only SSH-related permissions"
    echo "  --bash-only    Fix only bash configuration permissions"
    echo "  --verify       Verify permissions after setting them"
    echo "  --report       Generate detailed permission report"
    echo "  --help         Show this help message"
    echo
    echo "Security Features:"
    echo "  - Platform-aware permission handling"
    echo "  - OpenSSH compliance for SSH keys"
    echo "  - Sensitive file protection (local.sh, private keys)"
    echo "  - Comprehensive security analysis and verification"
    echo
    echo "Examples:"
    echo "  $0                    # Fix all permissions"
    echo "  $0 --analyze          # Analyze without changes"
    echo "  $0 --ssh-only         # Fix only SSH permissions"
    echo "  $0 --verify --report  # Fix, verify, and report"
}

# ============================================================================
# MAIN EXECUTION LOGIC
# ============================================================================

main() {
    local analyze_only=false
    local ssh_only=false
    local bash_only=false
    local verify_after=false
    local generate_report=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --analyze)
                analyze_only=true
                shift
                ;;
            --ssh-only)
                ssh_only=true
                shift
                ;;
            --bash-only)
                bash_only=true
                shift
                ;;
            --verify)
                verify_after=true
                shift
                ;;
            --report)
                generate_report=true
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
    
    # Initialize platform detection
    detect_platform_permissions
    
    # Perform initial analysis
    log "Starting permission management process..."
    analyze_current_permissions
    
    # Exit early if only analyzing
    if [[ "$analyze_only" == true ]]; then
        log "Analysis complete - no changes made"
        generate_permission_report
        exit 0
    fi
    
    # Apply permission fixes based on options
    if [[ "$ssh_only" != true ]]; then
        set_bash_permissions
        set_git_permissions
        [[ "$PERMISSION_SUPPORT" == "full" ]] && set_ownership
    fi
    
    if [[ "$bash_only" != true ]]; then
        set_ssh_permissions
    fi
    
    # Verify permissions if requested or if critical issues were found
    if [[ "$verify_after" == true ]] || [[ $SECURITY_ISSUES_FOUND -gt 5 ]]; then
        verify_all_permissions
    fi
    
    # Generate report
    if [[ "$generate_report" == true ]] || [[ $SECURITY_ISSUES_FOUND -gt 0 ]] || [[ $PERMISSION_ERRORS -gt 0 ]]; then
        generate_permission_report
    fi
    
    # Final status
    if [[ $PERMISSION_ERRORS -eq 0 ]]; then
        log "Permission management completed successfully"
        exit 0
    else
        warn "Permission management completed with $PERMISSION_ERRORS errors"
        exit 1
    fi
}

show_menu() {
    clear
    echo "=== $DESCRIPTION ==="
    echo
    echo "Select an option:"
    echo
    echo "1) Fix all permissions"
    echo "2) Analyze current permissions (no changes)"
    echo "3) Fix SSH permissions only"
    echo "4) Fix bash configuration only"
    echo "5) Generate permission report"
    echo "6) Verify permissions"
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
            run --analyze
            ;;
        3)
            run --ssh-only
            ;;
        4)
            run --bash-only
            ;;
        5)
            run --report
            ;;
        6)
            run --verify
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
