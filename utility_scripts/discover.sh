#!/bin/bash
# discover.sh - Intelligent Tool Discovery and Alias Suggestion System
#
# This system analyzes the current environment to discover installed tools,
# programming languages, and development environments, then suggests relevant
# aliases and configuration modules that would enhance productivity.

# Add to ~/.config/bash/essential/core.sh or load as standalone script

# ============================================================================
# DISCOVERY SYSTEM ARCHITECTURE
# ============================================================================
#
# DISCOVERY METHODOLOGY:
# 1. Tool Detection: Scan PATH and common installation locations
# 2. Project Analysis: Examine current directory for project indicators
# 3. Usage Pattern Analysis: Check command history for usage patterns
# 4. Context Awareness: Consider platform, environment, and user preferences
# 5. Intelligent Suggestions: Provide relevant aliases and module recommendations
#
# SUGGESTION CATEGORIES:
# - Development Tools: IDEs, compilers, interpreters, build systems
# - Version Control: Git workflows, repository management
# - Container Systems: Docker, Podman, container orchestration
# - Package Managers: Language-specific and system package managers
# - System Administration: Process management, network tools, monitoring
# - Productivity: File management, text processing, automation

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Discovery state tracking
declare -A DISCOVERED_TOOLS
declare -A SUGGESTED_ALIASES
declare -A AVAILABLE_MODULES
declare -A PROJECT_INDICATORS

# ============================================================================
# CORE DISCOVERY ENGINE
# ============================================================================

# Tool detection with comprehensive path scanning
discover_tools() {
    local category="$1"
    shift
    local tools=("$@")

    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            DISCOVERED_TOOLS["$tool"]="$category"

            # Get version information where possible
            local version=""
            case "$tool" in
                git|docker|node|python*|go|rustc|java|gcc|clang)
                    version=$($tool --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
                    ;;
                npm|yarn|pip*|cargo)
                    version=$($tool --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
                    ;;
                vim|nvim)
                    version=$($tool --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
                    ;;
            esac

            if [[ -n "$version" ]]; then
                DISCOVERED_TOOLS["$tool"]="$category:$version"
            fi
        fi
    done
}

# Comprehensive tool discovery across all categories
perform_tool_discovery() {
    echo -e "${CYAN}Discovering installed tools...${NC}"

    # DEVELOPMENT ENVIRONMENTS
    discover_tools "editors" vim nvim nano emacs code subl atom
    discover_tools "ides" idea pycharm webstorm phpstorm clion goland

    # PROGRAMMING LANGUAGES
    discover_tools "languages" python python3 python2 node npm yarn go rustc cargo java javac scala kotlin swift
    discover_tools "languages" ruby gem php composer perl lua julia r Rscript
    discover_tools "compiled" gcc g++ clang clang++ make cmake ninja meson

    # VERSION CONTROL
    discover_tools "vcs" git svn hg bzr
    discover_tools "git-tools" gh glab git-flow git-lfs tig gitk

    # CONTAINER AND VIRTUALIZATION
    discover_tools "containers" docker podman docker-compose kubectl helm
    discover_tools "virtualization" vagrant vboxmanage qemu-system-x86_64

    # DATABASE TOOLS
    discover_tools "databases" mysql psql sqlite3 redis-cli mongo
    discover_tools "db-tools" mycli pgcli sqlite-utils

    # CLOUD AND DEVOPS
    discover_tools "cloud" aws gcloud az terraform ansible
    discover_tools "monitoring" htop btop iotop nethogs

    # PACKAGE MANAGERS
    case "$(uname -s)" in
        Darwin)
            discover_tools "package-managers" brew port mas
            ;;
        Linux)
            discover_tools "package-managers" apt yum dnf pacman zypper snap flatpak
            ;;
        MINGW*|MSYS*|CYGWIN*)
            discover_tools "package-managers" choco scoop winget
            ;;
    esac

    # NETWORK AND SYSTEM TOOLS
    discover_tools "network" curl wget ssh scp rsync
    discover_tools "system" tmux screen tree fzf fd rg bat exa
    discover_tools "archives" tar zip unzip 7z

    # TEXT PROCESSING
    discover_tools "text" sed awk grep rg ag jq yq

    # MULTIMEDIA
    discover_tools "multimedia" ffmpeg imagemagick convert

    echo -e "${GREEN}Discovery complete: ${#DISCOVERED_TOOLS[@]} tools found${NC}"
}

# ============================================================================
# PROJECT CONTEXT ANALYSIS
# ============================================================================

# Analyze current directory for project type indicators
analyze_project_context() {
    echo -e "${CYAN}Analyzing project context...${NC}"

    local context_score=0

    # GIT REPOSITORY ANALYSIS
    if [[ -d ".git" ]]; then
        PROJECT_INDICATORS["git"]="Git repository detected"
        ((context_score++))

        # Check for specific Git workflows
        if git remote -v 2>/dev/null | grep -q "github.com"; then
            PROJECT_INDICATORS["github"]="GitHub repository"
        elif git remote -v 2>/dev/null | grep -q "gitlab.com"; then
            PROJECT_INDICATORS["gitlab"]="GitLab repository"
        fi

        # Check for Git hooks or advanced Git usage
        if [[ -d ".git/hooks" ]] && ls .git/hooks/*.sample &>/dev/null; then
            PROJECT_INDICATORS["git-hooks"]="Git hooks available"
        fi
    fi

    # PROGRAMMING LANGUAGE DETECTION
    if [[ -f "package.json" ]]; then
        PROJECT_INDICATORS["nodejs"]="Node.js project (package.json found)"
        ((context_score++))

        # Check for specific Node.js frameworks
        if grep -q "react" package.json 2>/dev/null; then
            PROJECT_INDICATORS["react"]="React project"
        elif grep -q "vue" package.json 2>/dev/null; then
            PROJECT_INDICATORS["vue"]="Vue.js project"
        elif grep -q "angular" package.json 2>/dev/null; then
            PROJECT_INDICATORS["angular"]="Angular project"
        elif grep -q "express" package.json 2>/dev/null; then
            PROJECT_INDICATORS["express"]="Express.js backend"
        fi
    fi

    if [[ -f "requirements.txt" || -f "pyproject.toml" || -f "setup.py" || -f "Pipfile" ]]; then
        PROJECT_INDICATORS["python"]="Python project detected"
        ((context_score++))

        # Check for Python frameworks
        if [[ -f "manage.py" ]] || grep -q "django" requirements.txt 2>/dev/null; then
            PROJECT_INDICATORS["django"]="Django project"
        elif grep -q "flask" requirements.txt 2>/dev/null; then
            PROJECT_INDICATORS["flask"]="Flask project"
        elif grep -q "fastapi" requirements.txt 2>/dev/null; then
            PROJECT_INDICATORS["fastapi"]="FastAPI project"
        fi
    fi

    if [[ -f "Cargo.toml" ]]; then
        PROJECT_INDICATORS["rust"]="Rust project (Cargo.toml found)"
        ((context_score++))
    fi

    if [[ -f "go.mod" ]]; then
        PROJECT_INDICATORS["golang"]="Go project (go.mod found)"
        ((context_score++))
    fi

    if [[ -f "pom.xml" || -f "build.gradle" || -f "build.sbt" ]]; then
        PROJECT_INDICATORS["jvm"]="JVM project detected"
        ((context_score++))
    fi

    # BUILD SYSTEM DETECTION
    if [[ -f "CMakeLists.txt" ]]; then
        PROJECT_INDICATORS["cmake"]="CMake build system"
        ((context_score++))
    fi

    if [[ -f "Makefile" ]]; then
        PROJECT_INDICATORS["make"]="Make build system"
        ((context_score++))
    fi

    # CONTAINER DETECTION
    if [[ -f "Dockerfile" ]]; then
        PROJECT_INDICATORS["docker"]="Docker containerization"
        ((context_score++))
    fi

    if [[ -f "docker-compose.yml" || -f "docker-compose.yaml" ]]; then
        PROJECT_INDICATORS["docker-compose"]="Docker Compose orchestration"
        ((context_score++))
    fi

    # INFRASTRUCTURE AS CODE
    if [[ -f "terraform.tf" ]] || ls *.tf &>/dev/null 2>&1; then
        PROJECT_INDICATORS["terraform"]="Terraform infrastructure"
        ((context_score++))
    fi

    if [[ -f "ansible.cfg" ]] || [[ -d "roles" ]]; then
        PROJECT_INDICATORS["ansible"]="Ansible automation"
        ((context_score++))
    fi

    # WEB DEVELOPMENT
    if [[ -f "index.html" ]] || [[ -f "index.php" ]]; then
        PROJECT_INDICATORS["web"]="Web project detected"
        ((context_score++))
    fi

    echo -e "${GREEN}Project analysis complete: $context_score indicators found${NC}"
}

# ============================================================================
# USAGE PATTERN ANALYSIS
# ============================================================================

# Analyze command history for usage patterns
analyze_usage_patterns() {
    echo -e "${CYAN}Analyzing command usage patterns...${NC}"

    if [[ ! -f ~/.bash_history ]]; then
        echo -e "${YELLOW}No bash history found - skipping usage analysis${NC}"
        return
    fi

    # Get recent commands (last 500 entries)
    local recent_commands=$(tail -500 ~/.bash_history 2>/dev/null)

    # Analyze common command patterns
    local git_usage=$(echo "$recent_commands" | grep -c "^git " || echo 0)
    local docker_usage=$(echo "$recent_commands" | grep -c "^docker " || echo 0)
    local npm_usage=$(echo "$recent_commands" | grep -c "^npm " || echo 0)
    local python_usage=$(echo "$recent_commands" | grep -c "^python" || echo 0)
    local ssh_usage=$(echo "$recent_commands" | grep -c "^ssh " || echo 0)

    # Generate insights based on usage patterns
    if [[ $git_usage -gt 10 ]]; then
        PROJECT_INDICATORS["heavy-git-user"]="Frequent Git usage detected ($git_usage recent commands)"
    fi

    if [[ $docker_usage -gt 5 ]]; then
        PROJECT_INDICATORS["docker-user"]="Active Docker usage ($docker_usage recent commands)"
    fi

    if [[ $npm_usage -gt 5 ]]; then
        PROJECT_INDICATORS["npm-user"]="Regular npm usage ($npm_usage recent commands)"
    fi

    if [[ $ssh_usage -gt 5 ]]; then
        PROJECT_INDICATORS["ssh-user"]="Frequent SSH usage ($ssh_usage recent commands)"
    fi

    echo -e "${GREEN}Usage pattern analysis complete${NC}"
}

# ============================================================================
# INTELLIGENT SUGGESTION ENGINE
# ============================================================================

# Generate contextual alias suggestions
generate_alias_suggestions() {
    echo -e "\n${BOLD}=== INTELLIGENT ALIAS SUGGESTIONS ===${NC}"

    # GIT SUGGESTIONS
    if [[ -n "${DISCOVERED_TOOLS[git]}" ]]; then
        echo -e "\n${CYAN}Git Workflow Enhancements:${NC}"

        if [[ -n "${PROJECT_INDICATORS[heavy-git-user]}" ]] || [[ -n "${PROJECT_INDICATORS[git]}" ]]; then
            suggest_alias "g" "git" "Ultimate Git shortcut"
            suggest_alias "gs" "git status" "Quick status check"
            suggest_alias "ga" "git add" "Stage files"
            suggest_alias "gc" "git commit" "Commit changes"
            suggest_alias "gp" "git push" "Push to remote"
            suggest_alias "gpl" "git pull" "Pull from remote"
            suggest_alias "gb" "git branch" "List branches"
            suggest_alias "gco" "git checkout" "Switch branches"
            suggest_alias "gd" "git diff" "Show differences"
            suggest_alias "gl" "git log --oneline" "Compact log"

            if [[ -n "${DISCOVERED_TOOLS[gh]}" ]]; then
                suggest_alias "ghpr" "gh pr create" "Create pull request"
                suggest_alias "ghprs" "gh pr status" "PR status"
            fi
        fi

        echo -e "  ${GREEN}Load with:${NC} load_file development git"
    fi

    # DOCKER SUGGESTIONS
    if [[ -n "${DISCOVERED_TOOLS[docker]}" ]]; then
        echo -e "\n${CYAN}Docker Container Management:${NC}"

        suggest_alias "d" "docker" "Docker shortcut"
        suggest_alias "dps" "docker ps" "List containers"
        suggest_alias "di" "docker images" "List images"
        suggest_alias "dex" "docker exec -it" "Execute in container"
        suggest_alias "dlog" "docker logs" "Container logs"

        if [[ -n "${DISCOVERED_TOOLS[docker-compose]}" ]] || [[ -n "${PROJECT_INDICATORS[docker-compose]}" ]]; then
            suggest_alias "dc" "docker-compose" "Compose shortcut"
            suggest_alias "dcup" "docker-compose up" "Start services"
            suggest_alias "dcdown" "docker-compose down" "Stop services"
            suggest_alias "dclogs" "docker-compose logs" "Service logs"
        fi

        echo -e "  ${GREEN}Load with:${NC} load_file development docker"
    fi

    # PYTHON SUGGESTIONS
    if [[ -n "${DISCOVERED_TOOLS[python]}" ]] || [[ -n "${DISCOVERED_TOOLS[python3]}" ]]; then
        echo -e "\n${CYAN}Python Development:${NC}"

        suggest_alias "py" "python3" "Python interpreter"
        suggest_alias "pip" "pip3" "Package installer"
        suggest_alias "venv" "python3 -m venv" "Create virtual environment"
        suggest_alias "activate" "source venv/bin/activate" "Activate venv"

        if [[ -n "${PROJECT_INDICATORS[django]}" ]]; then
            suggest_alias "djrun" "python manage.py runserver" "Django dev server"
            suggest_alias "djmig" "python manage.py migrate" "Apply migrations"
            suggest_alias "djshell" "python manage.py shell" "Django shell"
        fi

        echo -e "  ${GREEN}Load with:${NC} load_file development languages"
    fi

    # NODE.JS SUGGESTIONS
    if [[ -n "${DISCOVERED_TOOLS[node]}" ]] || [[ -n "${DISCOVERED_TOOLS[npm]}" ]]; then
        echo -e "\n${CYAN}Node.js Development:${NC}"

        suggest_alias "npi" "npm install" "Install packages"
        suggest_alias "nps" "npm start" "Start application"
        suggest_alias "npd" "npm run dev" "Development mode"
        suggest_alias "npt" "npm test" "Run tests"
        suggest_alias "npb" "npm run build" "Build project"

        if [[ -n "${DISCOVERED_TOOLS[yarn]}" ]]; then
            suggest_alias "y" "yarn" "Yarn package manager"
            suggest_alias "ya" "yarn add" "Add dependency"
            suggest_alias "ys" "yarn start" "Start with Yarn"
        fi

        echo -e "  ${GREEN}Load with:${NC} load_file development languages"
    fi

    # CMAKE SUGGESTIONS
    if [[ -n "${DISCOVERED_TOOLS[cmake]}" ]] || [[ -n "${PROJECT_INDICATORS[cmake]}" ]]; then
        echo -e "\n${CYAN}CMake Build System:${NC}"

        suggest_alias "mkbuild" "mkdir -p build && cd build" "Create build directory"
        suggest_alias "cm" "cmake" "CMake shortcut"
        suggest_alias "cmb" "cmake --build" "Build project"
        suggest_alias "cmt" "cmake --build . --target test" "Run tests"

        echo -e "  ${GREEN}Load with:${NC} load_file development cmake"
    fi

    # SYSTEM ADMINISTRATION
    if [[ -n "${DISCOVERED_TOOLS[htop]}" ]] || [[ -n "${DISCOVERED_TOOLS[btop]}" ]]; then
        echo -e "\n${CYAN}System Monitoring:${NC}"

        if [[ -n "${DISCOVERED_TOOLS[htop]}" ]]; then
            suggest_alias "top" "htop" "Better process viewer"
        fi

        suggest_alias "ports" "netstat -tuln" "Show open ports"
        suggest_alias "listening" "netstat -tln" "Show listening ports"
    fi

    # TEXT PROCESSING
    if [[ -n "${DISCOVERED_TOOLS[rg]}" ]]; then
        suggest_alias "grep" "rg" "Faster grep with ripgrep"
    fi

    if [[ -n "${DISCOVERED_TOOLS[bat]}" ]]; then
        suggest_alias "cat" "bat" "Better cat with syntax highlighting"
    fi

    if [[ -n "${DISCOVERED_TOOLS[exa]}" ]]; then
        suggest_alias "ls" "exa" "Modern ls replacement"
        suggest_alias "ll" "exa -l" "Long listing with exa"
        suggest_alias "la" "exa -la" "All files with exa"
    fi

    # PACKAGE MANAGERS
    suggest_package_manager_aliases
}

# Package manager specific suggestions
suggest_package_manager_aliases() {
    echo -e "\n${CYAN}Package Management:${NC}"

    case "$(uname -s)" in
        Darwin)
            if [[ -n "${DISCOVERED_TOOLS[brew]}" ]]; then
                suggest_alias "br" "brew" "Homebrew shortcut"
                suggest_alias "bri" "brew install" "Install package"
                suggest_alias "bru" "brew uninstall" "Remove package"
                suggest_alias "brs" "brew search" "Search packages"
                suggest_alias "brupdate" "brew update && brew upgrade" "Update all"
            fi
            ;;
        Linux)
            if [[ -n "${DISCOVERED_TOOLS[apt]}" ]]; then
                suggest_alias "update" "sudo apt update && sudo apt upgrade" "Update system"
                suggest_alias "install" "sudo apt install" "Install package"
                suggest_alias "search" "apt search" "Search packages"
            elif [[ -n "${DISCOVERED_TOOLS[pacman]}" ]]; then
                suggest_alias "update" "sudo pacman -Syu" "Update system"
                suggest_alias "install" "sudo pacman -S" "Install package"
                suggest_alias "search" "pacman -Ss" "Search packages"
            elif [[ -n "${DISCOVERED_TOOLS[dnf]}" ]]; then
                suggest_alias "update" "sudo dnf update" "Update system"
                suggest_alias "install" "sudo dnf install" "Install package"
                suggest_alias "search" "dnf search" "Search packages"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            if [[ -n "${DISCOVERED_TOOLS[choco]}" ]]; then
                suggest_alias "update" "choco upgrade all -y" "Update all packages"
                suggest_alias "install" "choco install" "Install package"
                suggest_alias "search" "choco search" "Search packages"
            elif [[ -n "${DISCOVERED_TOOLS[scoop]}" ]]; then
                suggest_alias "update" "scoop update *" "Update all packages"
                suggest_alias "install" "scoop install" "Install package"
                suggest_alias "search" "scoop search" "Search packages"
            fi
            ;;
    esac
}

# Helper function to suggest an alias
suggest_alias() {
    local alias_name="$1"
    local command="$2"
    local description="$3"

    echo -e "  ${YELLOW}$alias_name${NC} -> ${GREEN}$command${NC} ${BLUE}($description)${NC}"
    SUGGESTED_ALIASES["$alias_name"]="$command"
}

# ============================================================================
# MODULE RECOMMENDATIONS
# ============================================================================

# Suggest bash configuration modules to load
suggest_modules() {
    echo -e "\n${BOLD}=== MODULE RECOMMENDATIONS ===${NC}"

    local modules_to_suggest=()

    # Suggest modules based on discovered tools and project context
    if [[ -n "${DISCOVERED_TOOLS[git]}" ]] || [[ -n "${PROJECT_INDICATORS[git]}" ]]; then
        modules_to_suggest+=("development/git")
    fi

    if [[ -n "${DISCOVERED_TOOLS[docker]}" ]] || [[ -n "${PROJECT_INDICATORS[docker]}" ]]; then
        modules_to_suggest+=("development/docker")
    fi

    if [[ -n "${DISCOVERED_TOOLS[cmake]}" ]] || [[ -n "${PROJECT_INDICATORS[cmake]}" ]]; then
        modules_to_suggest+=("development/cmake")
    fi

    if [[ -n "${DISCOVERED_TOOLS[python]}" ]] || [[ -n "${PROJECT_INDICATORS[python]}" ]] || [[ -n "${DISCOVERED_TOOLS[node]}" ]] || [[ -n "${PROJECT_INDICATORS[nodejs]}" ]]; then
        modules_to_suggest+=("development/languages")
    fi

    # Suggest productivity modules
    modules_to_suggest+=("productivity/work")

    echo -e "${CYAN}Recommended modules for your environment:${NC}"
    for module in "${modules_to_suggest[@]}"; do
        echo -e "  ${GREEN}load_file ${module}${NC} - Load $(basename "$module") functionality"
    done

    echo -e "\n${CYAN}Quick load commands:${NC}"
    echo -e "  ${GREEN}dev${NC}      - Load all development tools"
    echo -e "  ${GREEN}work${NC}     - Load productivity features"
    echo -e "  ${GREEN}load_all${NC} - Load everything available"
}

# ============================================================================
# PERSONALIZED RECOMMENDATIONS
# ============================================================================

# Generate personalized suggestions based on user patterns
generate_personalized_suggestions() {
    echo -e "\n${BOLD}=== PERSONALIZED RECOMMENDATIONS ===${NC}"

    # Suggest based on heavy usage patterns
    if [[ -n "${PROJECT_INDICATORS[heavy-git-user]}" ]]; then
        echo -e "\n${CYAN}Since you're a heavy Git user:${NC}"
        echo -e "  ${GREEN}Consider:${NC} Setting up git aliases in ~/.gitconfig"
        echo -e "  ${GREEN}Tool tip:${NC} Use 'git config --global alias.st status' for permanent aliases"

        if [[ -z "${DISCOVERED_TOOLS[gh]}" ]] && [[ -z "${DISCOVERED_TOOLS[glab]}" ]]; then
            echo -e "  ${YELLOW}Suggestion:${NC} Install GitHub CLI (gh) or GitLab CLI (glab) for enhanced workflow"
        fi
    fi

    if [[ -n "${PROJECT_INDICATORS[docker-user]}" ]]; then
        echo -e "\n${CYAN}Docker power user detected:${NC}"
        echo -e "  ${GREEN}Consider:${NC} Docker cleanup aliases for container management"
        echo -e "  ${GREEN}Tool tip:${NC} Use 'docker system prune' regularly to clean up resources"

        if [[ -z "${DISCOVERED_TOOLS[dive]}" ]]; then
            echo -e "  ${YELLOW}Suggestion:${NC} Install 'dive' for Docker image analysis"
        fi
    fi

    # Suggest improvements based on missing tools
    if [[ -n "${PROJECT_INDICATORS[nodejs]}" ]] && [[ -z "${DISCOVERED_TOOLS[yarn]}" ]]; then
        echo -e "\n${CYAN}Node.js project detected:${NC}"
        echo -e "  ${YELLOW}Consider:${NC} Installing Yarn as an alternative package manager"
    fi

    if [[ -n "${PROJECT_INDICATORS[python]}" ]] && [[ -z "${DISCOVERED_TOOLS[pipenv]}" ]]; then
        echo -e "\n${CYAN}Python project detected:${NC}"
        echo -e "  ${YELLOW}Consider:${NC} Installing pipenv or poetry for better dependency management"
    fi

    # Suggest modern alternatives
    suggest_modern_alternatives
}

# Suggest modern tool alternatives
suggest_modern_alternatives() {
    echo -e "\n${CYAN}Modern Tool Suggestions:${NC}"

    local suggestions_made=false

    if [[ -n "${DISCOVERED_TOOLS[cat]}" ]] && [[ -z "${DISCOVERED_TOOLS[bat]}" ]]; then
        echo -e "  ${YELLOW}Upgrade:${NC} Install 'bat' as a better 'cat' with syntax highlighting"
        suggestions_made=true
    fi

    if [[ -n "${DISCOVERED_TOOLS[ls]}" ]] && [[ -z "${DISCOVERED_TOOLS[exa]}" ]]; then
        echo -e "  ${YELLOW}Upgrade:${NC} Install 'exa' as a modern 'ls' replacement"
        suggestions_made=true
    fi

    if [[ -n "${DISCOVERED_TOOLS[grep]}" ]] && [[ -z "${DISCOVERED_TOOLS[rg]}" ]]; then
        echo -e "  ${YELLOW}Upgrade:${NC} Install 'ripgrep' (rg) for faster searching"
        suggestions_made=true
    fi

    if [[ -n "${DISCOVERED_TOOLS[find]}" ]] && [[ -z "${DISCOVERED_TOOLS[fd]}" ]]; then
        echo -e "  ${YELLOW}Upgrade:${NC} Install 'fd' as a user-friendly 'find' alternative"
        suggestions_made=true
    fi

    if [[ -z "${DISCOVERED_TOOLS[fzf]}" ]]; then
        echo -e "  ${YELLOW}Productivity:${NC} Install 'fzf' for fuzzy finding in terminal"
        suggestions_made=true
    fi

    if [[ -z "${DISCOVERED_TOOLS[tmux]}" ]] && [[ -z "${DISCOVERED_TOOLS[screen]}" ]]; then
        echo -e "  ${YELLOW}Productivity:${NC} Install 'tmux' for terminal multiplexing"
        suggestions_made=true
    fi

    if [[ "$suggestions_made" == false ]]; then
        echo -e "  ${GREEN}Great!${NC} You have modern tools installed"
    fi
}

# ============================================================================
# DISCOVERY SUMMARY AND ACTIONS
# ============================================================================

# Display comprehensive discovery summary
show_discovery_summary() {
    echo -e "\n${BOLD}=== DISCOVERY SUMMARY ===${NC}"

    echo -e "\n${CYAN}Environment Overview:${NC}"
    echo -e "  Tools discovered: ${GREEN}${#DISCOVERED_TOOLS[@]}${NC}"
    echo -e "  Project indicators: ${GREEN}${#PROJECT_INDICATORS[@]}${NC}"
    echo -e "  Alias suggestions: ${GREEN}${#SUGGESTED_ALIASES[@]}${NC}"

    if [[ ${#PROJECT_INDICATORS[@]} -gt 0 ]]; then
        echo -e "\n${CYAN}Project Context:${NC}"
        for indicator in "${!PROJECT_INDICATORS[@]}"; do
            echo -e "  ${GREEN}✓${NC} ${PROJECT_INDICATORS[$indicator]}"
        done
    fi

    echo -e "\n${CYAN}Quick Actions:${NC}"
    echo -e "  ${GREEN}discover --setup${NC}   - Apply suggested aliases to current session"
    echo -e "  ${GREEN}discover --save${NC}    - Save suggestions to local.sh"
    echo -e "  ${GREEN}discover --tools${NC}   - Show detailed tool information"
    echo -e "  ${GREEN}discover --install${NC} - Show installation commands for missing tools"
}

# ============================================================================
# DISCOVERY ACTIONS
# ============================================================================

# Apply suggested aliases to current session
apply_suggestions() {
    echo -e "${CYAN}Applying suggested aliases to current session...${NC}"

    local applied_count=0
    for alias_name in "${!SUGGESTED_ALIASES[@]}"; do
        local command="${SUGGESTED_ALIASES[$alias_name]}"
        alias "$alias_name"="$command"
        ((applied_count++))
    done

    echo -e "${GREEN}Applied $applied_count aliases to current session${NC}"
    echo -e "${YELLOW}Note: These aliases will be lost when you close the terminal${NC}"
    echo -e "${YELLOW}Use 'discover --save' to make them permanent${NC}"
}

# Save suggestions to local configuration
save_suggestions() {
    local config_file="$HOME/.config/bash/local.sh"

    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}Error: $config_file not found${NC}"
        echo -e "${YELLOW}Please ensure bash-config is properly installed${NC}"
        return 1
    fi

    echo -e "${CYAN}Saving suggestions to $config_file...${NC}"

    # Create backup
    cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"

    # Add header for discovered aliases
    echo "" >> "$config_file"
    echo "# Aliases suggested by discover system on $(date)" >> "$config_file"
    echo "# Remove or modify these as needed" >> "$config_file"

    local saved_count=0
    for alias_name in "${!SUGGESTED_ALIASES[@]}"; do
        local command="${SUGGESTED_ALIASES[$alias_name]}"
        echo "alias $alias_name='$command'" >> "$config_file"
        ((saved_count++))
    done

    echo -e "${GREEN}Saved $saved_count aliases to $config_file${NC}"
    echo -e "${YELLOW}Run 'source ~/.bashrc' or open a new terminal to use them${NC}"
}

# Show detailed tool information
show_tool_details() {
    echo -e "\n${BOLD}=== DETAILED TOOL INFORMATION ===${NC}"

    local categories=("editors" "ides" "languages" "compiled" "vcs" "git-tools" "containers" "databases" "cloud" "package-managers" "network" "system" "text")

    for category in "${categories[@]}"; do
        local tools_in_category=()
        for tool in "${!DISCOVERED_TOOLS[@]}"; do
            if [[ "${DISCOVERED_TOOLS[$tool]}" == "$category"* ]]; then
                tools_in_category+=("$tool")
            fi
        done

        if [[ ${#tools_in_category[@]} -gt 0 ]]; then
            echo -e "\n${CYAN}${category^}:${NC}"
            for tool in "${tools_in_category[@]}"; do
                local info="${DISCOVERED_TOOLS[$tool]}"
                if [[ "$info" == *":"* ]]; then
                    local version="${info#*:}"
                    echo -e "  ${GREEN}✓${NC} $tool ${BLUE}(v$version)${NC}"
                else
                    echo -e "  ${GREEN}✓${NC} $tool"
                fi
            done
        fi
    done
}

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

show_help() {
    echo "discover - Intelligent tool discovery and alias suggestion system"
    echo
    echo "Usage: discover [options]"
    echo
    echo "Options:"
    echo "  --setup      Apply suggested aliases to current session"
    echo "  --save       Save suggestions to ~/.config/bash/local.sh"
    echo "  --tools      Show detailed information about discovered tools"
    echo "  --install    Show installation commands for suggested tools"
    echo "  --project    Show only project-specific suggestions"
    echo "  --help       Show this help message"
    echo
    echo "Examples:"
    echo "  discover              # Full discovery and suggestions"
    echo "  discover --project    # Project-specific recommendations"
    echo "  discover --setup      # Apply suggestions to current session"
    echo "  discover --save       # Make suggestions permanent"
}

# Main discover function
discover() {
    local option="${1:-}"

    case "$option" in
        --setup)
            perform_tool_discovery >/dev/null 2>&1
            analyze_project_context >/dev/null 2>&1
            generate_alias_suggestions >/dev/null 2>&1
            apply_suggestions
            ;;
        --save)
            perform_tool_discovery >/dev/null 2>&1
            analyze_project_context >/dev/null 2>&1
            generate_alias_suggestions >/dev/null 2>&1
            save_suggestions
            ;;
        --tools)
            perform_tool_discovery >/dev/null 2>&1
            show_tool_details
            ;;
        --project)
            analyze_project_context
            echo -e "\n${CYAN}Project-specific suggestions will be shown above${NC}"
            ;;
        --install)
            echo -e "${CYAN}Installation commands for suggested modern tools:${NC}"
            echo "# Package managers (install first):"
            echo "curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh  # Docker"
            echo "brew install bat exa ripgrep fd fzf tmux  # macOS with Homebrew"
            echo "sudo apt install bat exa ripgrep fd-find fzf tmux  # Ubuntu/Debian"
            echo "sudo pacman -S bat exa ripgrep fd fzf tmux  # Arch Linux"
            ;;
        --help)
            show_help
            ;;
        ""|*)
            # Full discovery process
            perform_tool_discovery
            analyze_project_context
            analyze_usage_patterns
            generate_alias_suggestions
            suggest_modules
            generate_personalized_suggestions
            show_discovery_summary
            ;;
    esac
}

show_menu() {
    clear
    echo "=== $DESCRIPTION ==="
    echo
    echo "Select an option:"
    echo
    echo "1) Full discovery and suggestions"
    echo "2) Project analysis only"
    echo "3) Apply suggestions to current session"
    echo "4) Save suggestions to local.sh"
    echo "5) Show detailed tool information"
    echo "6) Show installation commands"
    echo "0) Exit"
    echo
    read -p "Enter choice: " choice
    handle_menu_choice "$choice"
}

handle_menu_choice() {
    local choice="$1"
    
    case $choice in
        1) 
            discover
            ;;
        2) 
            discover --project
            ;;
        3)
            discover --setup
            ;;
        4)
            discover --save
            ;;
        5)
            discover --tools
            ;;
        6)
            discover --install
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


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "--menu" ]]; then
        show_menu
    else
        discover "$@"
    fi
fi