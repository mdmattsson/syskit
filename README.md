# SysKit

A professional, layer-based bash configuration system with smart lazy loading, platform-specific optimizations, and extensive development tools integration.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Features](#features)
- [Directory Structure](#directory-structure)
- [Enhanced Lazy Loading System](#enhanced-lazy-loading-system)
- [Modules](#modules)
- [Essential Layer](#essential-layer-always-loaded)
- [Development Layer](#development-layer)
- [Productivity Layer](#productivity-layer)
- [Platform Layer](#platform-layer)
- [Configuration Management](#configuration-management)
- [Installation Scripts](#installation-scripts)
- [License](#license)

---

## Quick Start

### Remote Installation

Install directly from GitHub using curl:

```bash
curl -fsSL https://syskit.org/install | bash
```

### Local Installation

Clone and install locally:

```bash
git clone https://github.com/mdmattsson/syskit.git
cd syskit
chmod +x syskit.sh
./install.sh
```

### Additional Scripts

Fix permissions after installation:
```bash
./fix-permissions.sh
```

Transfer SSH keys and Git config to another machine:
```bash
./transfer-ssh.sh user@hostname
```

---

## Screenshot

Here's the configuration in action, showing the system information display and navigation features:

![Terminal Screenshot](screenshot.png)

*Example showing the welcome message with system stats, and the `goto exa` command navigating to a CMake project directory with automatic development layer loading.*

---

## Features

### Smart Lazy Loading System
- **Command-triggered loading**: Modules load automatically when related commands are used
- **Directory-based auto-loading**: Development tools load when entering project directories
- **Layer-based organization**: Essential, development, productivity, and platform-specific layers
- **Fast startup**: Only essential configuration loads immediately
- **Memory efficient**: Load only what you need, when you need it

### Development Environment
- **Git workflow optimization**: 20+ git aliases and functions
- **Docker integration**: Complete container management toolkit
- **CMake build system**: Automated C++ project workflow
- **Multi-language support**: Python, Node.js, C++, and more
- **IDE integration**: VS Code, Vim, and other editor shortcuts

### Platform Intelligence
- **Cross-platform compatibility**: Windows (Git Bash/WSL), Linux, and macOS
- **Package manager integration**: Automatic detection and unified interface
- **Platform-specific optimizations**: Native tools and conventions for each OS
- **Smart path management**: Automatic binary discovery and PATH optimization

### Productivity Tools
- **Enhanced navigation**: Bookmarks, quick goto shortcuts, directory stack management
- **Work environment integration**: Project-specific configurations and shortcuts
- **System monitoring**: Resource usage, process management, and health checks
- **Network utilities**: Port management, connectivity tools, and diagnostics

---

## Directory Structure

```
~/.config/bash/
â”œâ”€â”€ ðŸ“ essential/
â”‚   â”œâ”€â”€ ðŸ“„ core.sh              # File operations, navigation, basic shortcuts
â”‚   â”œâ”€â”€ ðŸ“„ environment.sh       # Environment variables, PATH, history
â”‚   â”œâ”€â”€ ðŸ“„ navigation.sh        # Advanced navigation, bookmarks
â”‚   â”œâ”€â”€ ðŸ“„ platform.sh          # Platform detection
â”‚   â””â”€â”€ ðŸ“„ motd.sh              # Message of the day
â”œâ”€â”€ ðŸ“ development/
â”‚   â”œâ”€â”€ ðŸ“„ git.sh               # Git aliases and functions
â”‚   â”œâ”€â”€ ðŸ“„ languages.sh         # Python, Node, C++, language tools
â”‚   â”œâ”€â”€ ðŸ“„ cmake.sh             # CMake workflow and build functions
â”‚   â”œâ”€â”€ ðŸ“„ docker.sh            # Docker and docker-compose
â”‚   â””â”€â”€ ðŸ“„ tools.sh             # IDEs, editors, code quality tools
â”œâ”€â”€ ðŸ“ productivity/
â”‚   â”œâ”€â”€ ðŸ“„ system.sh            # System utilities (non-package management)
â”‚   â””â”€â”€ ðŸ“„ work.sh              # Work-specific shortcuts
â”œâ”€â”€ ðŸ“ platform/
â”‚   â”œâ”€â”€ ðŸ“„ windows.sh           # Windows-specific tweaks and package managers
â”‚   â”œâ”€â”€ ðŸ“„ linux.sh             # Linux-specific tweaks and package managers
â”‚   â””â”€â”€ ðŸ“„ macos.sh             # macOS-specific tweaks and package managers
â””â”€â”€ ðŸ“„ local.sh                 # Machine-specific overrides (not in VCS)
```

---

## Enhanced Lazy Loading System

The configuration uses an intelligent lazy loading system that dramatically improves shell startup time while providing full functionality when needed.

### Loading Triggers

**Command-Based Loading**
```bash
# Git commands automatically load git.sh
g, gs, ga, gc, gp, glog â†’ development/git.sh

# Docker commands automatically load docker.sh  
d, dc, dps, dex, dlog â†’ development/docker.sh

# CMake commands automatically load cmake.sh
cmake_*, mkbuild, cm â†’ development/cmake.sh

# Language tools automatically load languages.sh
py, npm, node, pip â†’ development/languages.sh
```

**Directory-Based Loading**
```bash
cd ~/Projects/myapp     # Loads development layer
cd ~/Work/client-site   # Loads productivity layer
cd project-with-git/    # Loads development/git.sh
cd node-project/        # Loads development/languages.sh
cd cmake-project/       # Loads development/cmake.sh
```

**Manual Loading**
```bash
dev        # Load development layer
work       # Load productivity layer
platform   # Load platform-specific features
load_all   # Load everything
```

### Performance Benefits

- **Startup time**: ~50ms vs 200ms+ for full loading
- **Memory usage**: Minimal footprint until features are needed
- **Scalability**: Add more modules without impacting startup
- **Transparency**: Loading is automatic and seamless

---

## Modules

### Essential Layer (Always Loaded)

#### core.sh
Core file operations, navigation shortcuts, and system compatibility fixes.

**Key Aliases:**
- `ll`, `la`, `l` - Enhanced ls variants
- `..`, `...`, `....` - Directory navigation
- `cp`, `mv`, `rm` - Safety confirmations
- `reload` - Reload bash configuration
- `path` - Display PATH in readable format

#### environment.sh
Environment variables, PATH management, and shell behavior configuration.

**Features:**
- History optimization (10K entries, timestamps, deduplication)
- Development environment variables (Python, Node.js, C++)
- XDG Base Directory compliance
- Cross-platform color configuration

#### platform.sh
Platform detection and environment variable setup.

**Exports:**
- `$PLATFORM` - Detected platform (windows/linux/macos/distro)
- `$IS_WINDOWS`, `$IS_LINUX`, `$IS_MAC` - Boolean flags

#### navigation.sh
Advanced directory navigation with bookmarks and quick shortcuts.

**Functions:**
- `goto <shortcut>` - Quick directory navigation
- `bookmark <name>` - Bookmark current directory
- `find_project <name>` - Find and navigate to projects

**Aliases:**
- `gh`, `gp`, `gw` - Quick navigation shortcuts
- `bm`, `gbm` - Bookmark management

---

## Development Layer

#### git.sh
Comprehensive Git workflow integration with 25+ aliases and functions.

**Basic Operations:**
- `g` - git
- `gs` - git status
- `ga` - git add
- `gc` - git commit
- `gp` - git push

**Advanced Functions:**
- `gcom <message>` - Add all and commit with message
- `gpub` - Push current branch to origin
- `gnb <name>` - Create and switch to new branch
- `gdel <branch>` - Delete branch locally and remotely

#### docker.sh
Complete Docker and docker-compose management toolkit.

**Container Operations:**
- `d` - docker
- `dps` - docker ps
- `dex` - docker exec -it
- `dlog` - docker logs

**Compose Operations:**
- `dc` - docker-compose
- `dcup` - docker-compose up
- `dcdown` - docker-compose down

**Utility Functions:**
- `denter <container>` - Enter running container
- `dcleanup` - Complete Docker cleanup
- `ddiskusage` - Docker disk usage report

#### cmake.sh
Professional CMake and C++ build system integration.

**Build Functions:**
- `cmake_init [type]` - Initialize CMake project
- `cmake_debug` - Configure and build debug version
- `cmake_release` - Configure and build release version
- `cmake_test` - Run project tests

**Utility Functions:**
- `mkbuild` - Create and enter build directory
- `cmake_quickstart <name>` - New project template
- `cmake_clean` - Clean build artifacts

#### languages.sh
Multi-language development tools and shortcuts.

**Python:**
- `py`, `py3` - Python shortcuts
- `venv`, `activate` - Virtual environment management
- `pipi`, `pipu`, `pipr` - Package management

**Node.js:**
- `npi`, `nps`, `npd` - NPM shortcuts
- `ya`, `ys`, `yb` - Yarn alternatives

**C++:**
- `g++`, `gcc` - Compiler with helpful flags
- `make` - Parallel builds with all cores

#### tools.sh
Development environment and editor integration.

**Editor Shortcuts:**
- Auto-detection of nvim/vim
- IDE shortcuts (code, pycharm, idea)
- Environment utilities

---

## Productivity Layer

#### work.sh
Work environment and company-specific configurations.

**Navigation:**
- `wh` - Work home directory
- `wp` - Work projects directory
- `workenv` - Setup work environment

**Utilities:**
- `fwf <file>` - Find work files
- `wproc` - Work-related processes
- `workgit` - Switch to work git config

---

## Platform Layer

#### windows.sh
Windows-specific tools and package manager integration.

**Package Managers:**
- Chocolatey: `choco*` commands
- Scoop: `scoop*` commands  
- Winget: `winget*` commands

**System Tools:**
- Windows service shortcuts
- WSL integration helpers
- Development path management

#### linux.sh
Linux-specific optimizations and system management.

**System Management:**
- `start`, `stop`, `restart` - Systemd shortcuts
- `services`, `failed` - Service discovery
- Package manager integration (apt/pacman/dnf)

**Utilities:**
- `sysoverview` - System status summary
- `extract` - Universal archive extraction
- Desktop environment shortcuts

#### macos.sh
macOS-specific tools and Homebrew integration.

**System Tools:**
- `open`, `finder`, `preview` - Native app shortcuts
- `sysinfo`, `hardware` - System information
- Dock and Finder management

**Package Management:**
- Homebrew: `br*` commands and services
- MacPorts integration
- App Store command line tools

---

## Configuration Management

### Loading Control
```bash
show_loaded              # Display loaded modules
reload_file <layer> <file>  # Reload specific file
reload_layer <layer>     # Reload entire layer
```

### Customization
Edit `~/.config/bash/local.sh` for machine-specific settings:
- Work vs personal environment detection
- Custom paths and directories
- Personal aliases and functions
- Company-specific tools
- API keys and secrets

### Platform Detection
The system automatically detects your platform and loads appropriate optimizations:
- Windows: Git Bash, WSL, and native Windows tools
- Linux: Distribution-specific package managers and tools
- macOS: Homebrew, native applications, and system tools

---

## Installation Scripts

### install.sh
- Automated installation from GitHub or local files
- Backup existing configurations
- Platform-aware permission setting
- XDG Base Directory compliance

### fix-permissions.sh  
- Correct file permissions for bash, SSH, and Git
- Platform-specific permission handling
- Security verification for SSH keys

### transfer-ssh.sh
- Secure SSH key and Git config transfer
- Automatic backup creation
- Permission correction on target machine
- Dry-run support for testing

---

## License

This configuration falls under the LIT license, and is provided as-is for personal and professional use. Customize freely for your environment.
