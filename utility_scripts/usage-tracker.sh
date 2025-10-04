#!/bin/bash
# usage-tracker.sh - Bash Configuration Usage Tracking and Analytics
#
# This system tracks module loading patterns, command usage, and performance
# metrics to help optimize the bash configuration and identify unused features.
# All tracking is local and privacy-focused.

# ============================================================================
# USAGE TRACKING ARCHITECTURE
# ============================================================================
#
# TRACKING PHILOSOPHY:
# - Privacy First: All data stays local, no external transmission
# - Performance Focus: Minimal overhead, async where possible
# - Actionable Insights: Data that helps optimize configuration
# - User Control: Easy to disable, inspect, or clear tracking data
#
# METRICS COLLECTED:
# - Module loading frequency and timing
# - Alias and function usage patterns
# - Startup time trends over time
# - Command execution patterns
# - Directory-based auto-loading effectiveness
# - Error rates and failure points
#
# DATA STORAGE:
# - ~/.local/share/bash-config/analytics/ (XDG compliant)
# - JSON format for easy parsing and analysis
# - Automatic rotation and cleanup of old data
# - Configurable retention periods


# Configuration
readonly ANALYTICS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-config/analytics"
readonly ANALYTICS_ENABLED_FILE="$ANALYTICS_DIR/.enabled"
readonly DAILY_STATS_FILE="$ANALYTICS_DIR/daily/$(date +%Y-%m-%d).json"
readonly WEEKLY_SUMMARY_FILE="$ANALYTICS_DIR/weekly/$(date +%Y-W%U).json"
readonly PERFORMANCE_LOG="$ANALYTICS_DIR/performance.log"
readonly USAGE_LOG="$ANALYTICS_DIR/usage.log"

# Retention settings (configurable)
readonly MAX_DAILY_FILES=30
readonly MAX_WEEKLY_FILES=12
readonly MAX_PERFORMANCE_ENTRIES=1000

# ============================================================================
# TRACKING INITIALIZATION
# ============================================================================

# Initialize analytics system
init_usage_tracking() {
    # Check if tracking is enabled
    if [[ ! -f "$ANALYTICS_ENABLED_FILE" ]]; then
        return 0  # Tracking disabled
    fi

    # Create directory structure
    mkdir -p "$ANALYTICS_DIR"/{daily,weekly,modules,commands}

    # Initialize today's stats file if it doesn't exist
    if [[ ! -f "$DAILY_STATS_FILE" ]]; then
        init_daily_stats_file
    fi

    # Set up tracking hooks in the current session
    setup_tracking_hooks
}

# Create initial daily stats structure
init_daily_stats_file() {
    mkdir -p "$(dirname "$DAILY_STATS_FILE")"

    cat > "$DAILY_STATS_FILE" << EOF
{
  "date": "$(date +%Y-%m-%d)",
  "session_count": 0,
  "total_startup_time_ms": 0,
  "modules_loaded": {},
  "aliases_used": {},
  "functions_used": {},
  "commands_executed": {},
  "directories_visited": {},
  "auto_loading_triggers": {},
  "errors": []
}
EOF
}

# ============================================================================
# PERFORMANCE TRACKING
# ============================================================================

# Track module loading time and frequency
track_module_load() {
    local module_name="$1"
    local load_time_ms="$2"
    local trigger_type="${3:-manual}"  # manual, auto, command

    [[ ! -f "$ANALYTICS_ENABLED_FILE" ]] && return 0

    # Update daily stats asynchronously
    (
        # Use a simple append format for performance
        echo "$(date +%s)|module_load|$module_name|$load_time_ms|$trigger_type" >> "$USAGE_LOG"

        # Update structured daily stats
        update_daily_stat "modules_loaded.$module_name.count" 1
        update_daily_stat "modules_loaded.$module_name.total_time_ms" "$load_time_ms"
        update_daily_stat "modules_loaded.$module_name.last_trigger" "$trigger_type"
    ) &
}

# Track startup time
track_startup_time() {
    local startup_time_ms="$1"

    [[ ! -f "$ANALYTICS_ENABLED_FILE" ]] && return 0

    (
        echo "$(date +%s)|startup|$startup_time_ms" >> "$PERFORMANCE_LOG"
        update_daily_stat "session_count" 1
        update_daily_stat "total_startup_time_ms" "$startup_time_ms"
    ) &
}

# Track alias usage
track_alias_usage() {
    local alias_name="$1"
    local actual_command="$2"

    [[ ! -f "$ANALYTICS_ENABLED_FILE" ]] && return 0

    (
        echo "$(date +%s)|alias|$alias_name|$actual_command" >> "$USAGE_LOG"
        update_daily_stat "aliases_used.$alias_name" 1
    ) &
}

# Track function usage
track_function_usage() {
    local function_name="$1"
    local args_count="${2:-0}"

    [[ ! -f "$ANALYTICS_ENABLED_FILE" ]] && return 0

    (
        echo "$(date +%s)|function|$function_name|$args_count" >> "$USAGE_LOG"
        update_daily_stat "functions_used.$function_name" 1
    ) &
}

# Track directory-based auto-loading
track_auto_loading() {
    local directory="$1"
    local modules_loaded="$2"
    local trigger_reason="$3"

    [[ ! -f "$ANALYTICS_ENABLED_FILE" ]] && return 0

    (
        echo "$(date +%s)|auto_load|$directory|$modules_loaded|$trigger_reason" >> "$USAGE_LOG"
        update_daily_stat "auto_loading_triggers.$trigger_reason" 1
        update_daily_stat "directories_visited.$(basename "$directory")" 1
    ) &
}

# Track command execution patterns
track_command_usage() {
    local command="$1"
    local success="${2:-true}"

    [[ ! -f "$ANALYTICS_ENABLED_FILE" ]] && return 0

    (
        echo "$(date +%s)|command|$command|$success" >> "$USAGE_LOG"
        update_daily_stat "commands_executed.$command.count" 1
        if [[ "$success" != "true" ]]; then
            update_daily_stat "commands_executed.$command.failures" 1
        fi
    ) &
}

# ============================================================================
# DATA MANAGEMENT UTILITIES
# ============================================================================

# Update a specific statistic in the daily stats file
update_daily_stat() {
    local stat_path="$1"
    local increment="$2"

    # Simple implementation using temporary file
    local temp_file=$(mktemp)

    if [[ -f "$DAILY_STATS_FILE" ]]; then
        # For simple stats, we'll use a basic approach
        # In a production system, you might want to use jq for JSON manipulation
        python3 -c "
import json, sys
try:
    with open('$DAILY_STATS_FILE', 'r') as f:
        data = json.load(f)
except:
    data = {}

# Navigate to the stat path and increment
path_parts = '$stat_path'.split('.')
current = data
for part in path_parts[:-1]:
    if part not in current:
        current[part] = {}
    current = current[part]

# Handle the final key
final_key = path_parts[-1]
if final_key not in current:
    current[final_key] = 0

# Increment the value
try:
    current[final_key] += int('$increment')
except:
    current[final_key] = int('$increment')

# Write back
with open('$temp_file', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null && mv "$temp_file" "$DAILY_STATS_FILE" || rm -f "$temp_file"
    fi
}

# ============================================================================
# TRACKING HOOKS INTEGRATION
# ============================================================================

# Set up hooks to integrate with the existing bash configuration
setup_tracking_hooks() {
    # Override the existing load_layer function to add tracking
    if declare -f load_layer >/dev/null 2>&1; then
        # Create a wrapper that adds tracking
        eval "
        original_load_layer() {
            $(declare -f load_layer | sed '1d')
        }

        load_layer() {
            local layer=\"\$1\"
            local start_time=\$(date +%s%3N)

            original_load_layer \"\$layer\"
            local result=\$?

            local end_time=\$(date +%s%3N)
            local duration=\$((end_time - start_time))

            track_module_load \"layer:\$layer\" \"\$duration\" \"manual\"

            return \$result
        }
        "
    fi

    # Override load_file function
    if declare -f load_file >/dev/null 2>&1; then
        eval "
        original_load_file() {
            $(declare -f load_file | sed '1d')
        }

        load_file() {
            local layer=\"\$1\"
            local filename=\"\$2\"
            local start_time=\$(date +%s%3N)

            original_load_file \"\$layer\" \"\$filename\"
            local result=\$?

            local end_time=\$(date +%s%3N)
            local duration=\$((end_time - start_time))

            track_module_load \"file:\$layer/\$filename\" \"\$duration\" \"manual\"

            return \$result
        }
        "
    fi

    # Set up command tracking through PROMPT_COMMAND
    if [[ -z "$PROMPT_COMMAND" ]]; then
        PROMPT_COMMAND="track_last_command"
    else
        PROMPT_COMMAND="track_last_command; $PROMPT_COMMAND"
    fi
}

# Track the last executed command
track_last_command() {
    [[ ! -f "$ANALYTICS_ENABLED_FILE" ]] && return 0

    local last_command=$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')
    local exit_code=$?

    if [[ -n "$last_command" && "$last_command" != "$TRACKED_LAST_COMMAND" ]]; then
        # Extract the base command (first word)
        local base_command=$(echo "$last_command" | awk '{print $1}')
        track_command_usage "$base_command" "$([[ $exit_code -eq 0 ]] && echo true || echo false)"
        TRACKED_LAST_COMMAND="$last_command"
    fi
}

# ============================================================================
# ANALYTICS AND REPORTING
# ============================================================================

# Generate usage analytics report
generate_usage_report() {
    local report_type="${1:-daily}"
    local days_back="${2:-7}"

    echo "Bash Configuration Usage Analytics Report"
    echo "========================================"
    echo "Generated: $(date)"
    echo "Report Type: $report_type"
    echo

    case "$report_type" in
        daily)
            generate_daily_report
            ;;
        weekly)
            generate_weekly_report "$days_back"
            ;;
        modules)
            generate_module_report "$days_back"
            ;;
        performance)
            generate_performance_report "$days_back"
            ;;
        cleanup)
            generate_cleanup_recommendations
            ;;
        *)
            echo "Unknown report type: $report_type"
            return 1
            ;;
    esac
}

# Daily usage report
generate_daily_report() {
    if [[ ! -f "$DAILY_STATS_FILE" ]]; then
        echo "No data available for today"
        return 1
    fi

    echo "Today's Usage Summary:"
    echo "====================="

    # Use Python to parse JSON and generate report
    python3 -c "
import json, sys
try:
    with open('$DAILY_STATS_FILE', 'r') as f:
        data = json.load(f)

    print(f\"Sessions started: {data.get('session_count', 0)}\")

    if data.get('session_count', 0) > 0:
        avg_startup = data.get('total_startup_time_ms', 0) / data.get('session_count', 1)
        print(f\"Average startup time: {avg_startup:.1f}ms\")

    modules = data.get('modules_loaded', {})
    if modules:
        print(f\"\nModules loaded today: {len(modules)}\")
        for module, stats in sorted(modules.items(), key=lambda x: x[1].get('count', 0), reverse=True)[:5]:
            count = stats.get('count', 0)
            total_time = stats.get('total_time_ms', 0)
            avg_time = total_time / count if count > 0 else 0
            print(f\"  {module}: {count} times, avg {avg_time:.1f}ms\")

    aliases = data.get('aliases_used', {})
    if aliases:
        print(f\"\nTop aliases used: {len(aliases)} total\")
        for alias, count in sorted(aliases.items(), key=lambda x: x[1], reverse=True)[:5]:
            print(f\"  {alias}: {count} times\")

    commands = data.get('commands_executed', {})
    if commands:
        print(f\"\nTop commands: {len(commands)} different commands\")
        for cmd, stats in sorted(commands.items(), key=lambda x: x[1].get('count', 0), reverse=True)[:5]:
            count = stats.get('count', 0)
            failures = stats.get('failures', 0)
            success_rate = ((count - failures) / count * 100) if count > 0 else 100
            print(f\"  {cmd}: {count} times, {success_rate:.1f}% success\")

except Exception as e:
    print(f'Error reading analytics data: {e}')
" 2>/dev/null || echo "Error generating daily report"
}

# Weekly trend analysis
generate_weekly_report() {
    local days_back="$1"

    echo "Weekly Usage Trends (last $days_back days):"
    echo "========================================="

    # Analyze trends across multiple days
    local daily_files=()
    for ((i=0; i<days_back; i++)); do
        local date=$(date -d "-$i days" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
        local file="$ANALYTICS_DIR/daily/$date.json"
        if [[ -f "$file" ]]; then
            daily_files+=("$file")
        fi
    done

    if [[ ${#daily_files[@]} -eq 0 ]]; then
        echo "No historical data available"
        return 1
    fi

    echo "Data available for ${#daily_files[@]} days"

    # Calculate trends
    python3 -c "
import json, sys
from collections import defaultdict

files = '${daily_files[*]}'.split()
total_sessions = 0
total_startup_time = 0
all_modules = defaultdict(int)
all_commands = defaultdict(int)

for file in files:
    try:
        with open(file, 'r') as f:
            data = json.load(f)

        sessions = data.get('session_count', 0)
        total_sessions += sessions
        total_startup_time += data.get('total_startup_time_ms', 0)

        for module, stats in data.get('modules_loaded', {}).items():
            all_modules[module] += stats.get('count', 0)

        for cmd, stats in data.get('commands_executed', {}).items():
            all_commands[cmd] += stats.get('count', 0)
    except:
        continue

if total_sessions > 0:
    avg_startup = total_startup_time / total_sessions
    print(f'Average sessions per day: {total_sessions / len(files):.1f}')
    print(f'Average startup time: {avg_startup:.1f}ms')

    print(f'\nMost used modules (last $days_back days):')
    for module, count in sorted(all_modules.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f'  {module}: {count} times')

    print(f'\nMost used commands (last $days_back days):')
    for cmd, count in sorted(all_commands.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f'  {cmd}: {count} times')
else:
    print('No usage data found')
" 2>/dev/null || echo "Error generating weekly report"
}

# Module usage analysis
generate_module_report() {
    local days_back="$1"

    echo "Module Usage Analysis:"
    echo "====================="

    # Find unused modules by comparing available vs used
    local available_modules=()
    if [[ -d "$HOME/.config/bash" ]]; then
        while IFS= read -r -d '' module; do
            local rel_path="${module#$HOME/.config/bash/}"
            available_modules+=("$rel_path")
        done < <(find "$HOME/.config/bash" -name "*.sh" -type f -print0)
    fi

    echo "Available modules: ${#available_modules[@]}"

    # Analyze usage patterns
    python3 -c "
import json, sys, os, glob
from collections import defaultdict

# Get available modules
available = '''${available_modules[*]}'''.split()
used_modules = defaultdict(int)

# Scan recent daily files
pattern = '$ANALYTICS_DIR/daily/*.json'
daily_files = sorted(glob.glob(pattern))[-$days_back:]

for file in daily_files:
    try:
        with open(file, 'r') as f:
            data = json.load(f)

        for module, stats in data.get('modules_loaded', {}).items():
            used_modules[module] += stats.get('count', 0)
    except:
        continue

print(f'Modules used in last $days_back days: {len(used_modules)}')

# Find unused modules
unused = []
for module in available:
    module_key = f'file:{module.replace(\".sh\", \"\")}'
    layer_key = f'layer:{module.split(\"/\")[0]}'
    if module_key not in used_modules and layer_key not in used_modules:
        unused.append(module)

if unused:
    print(f'\nUnused modules ({len(unused)}):')
    for module in sorted(unused):
        print(f'  {module}')
    print('\nConsider removing or reviewing these modules for cleanup')
else:
    print('\nAll available modules have been used recently')

print(f'\nMost frequently loaded modules:')
for module, count in sorted(used_modules.items(), key=lambda x: x[1], reverse=True)[:10]:
    print(f'  {module}: {count} times')
" 2>/dev/null || echo "Error generating module report"
}

# Performance analysis
generate_performance_report() {
    local days_back="$1"

    echo "Performance Analysis:"
    echo "===================="

    if [[ ! -f "$PERFORMANCE_LOG" ]]; then
        echo "No performance data available"
        return 1
    fi

    # Analyze startup times
    local recent_startups=$(tail -100 "$PERFORMANCE_LOG" | grep "|startup|" | cut -d'|' -f3)

    if [[ -n "$recent_startups" ]]; then
        python3 -c "
import sys
times = list(map(int, '''$recent_startups'''.split()))
if times:
    avg = sum(times) / len(times)
    min_time = min(times)
    max_time = max(times)
    print(f'Startup time analysis (last {len(times)} sessions):')
    print(f'  Average: {avg:.1f}ms')
    print(f'  Fastest: {min_time}ms')
    print(f'  Slowest: {max_time}ms')

    # Performance trend
    if len(times) >= 10:
        recent_avg = sum(times[-10:]) / 10
        older_avg = sum(times[:-10]) / len(times[:-10]) if len(times) > 10 else avg
        if recent_avg < older_avg:
            print(f'  Trend: Improving (recent avg: {recent_avg:.1f}ms)')
        elif recent_avg > older_avg:
            print(f'  Trend: Degrading (recent avg: {recent_avg:.1f}ms)')
        else:
            print(f'  Trend: Stable')
" 2>/dev/null
    else
        echo "Insufficient performance data"
    fi

    # Module loading performance
    echo
    echo "Module loading performance:"
    local module_times=$(tail -200 "$USAGE_LOG" | grep "|module_load|" | tail -50)
    if [[ -n "$module_times" ]]; then
        echo "$module_times" | python3 -c "
import sys
from collections import defaultdict

module_times = defaultdict(list)
for line in sys.stdin:
    parts = line.strip().split('|')
    if len(parts) >= 4:
        module = parts[2]
        time_ms = int(parts[3])
        module_times[module].append(time_ms)

for module, times in sorted(module_times.items(), key=lambda x: sum(x[1])/len(x[1]), reverse=True)[:5]:
    avg_time = sum(times) / len(times)
    print(f'  {module}: {avg_time:.1f}ms average ({len(times)} loads)')
" 2>/dev/null
    fi
}

# Generate cleanup recommendations
generate_cleanup_recommendations() {
    echo "Configuration Cleanup Recommendations:"
    echo "====================================="

    # Analyze for cleanup opportunities
    generate_module_report 30 | grep -A 20 "Unused modules" || echo "Module analysis unavailable"

    echo
    echo "General recommendations:"
    echo "- Review unused modules and consider removing or documenting them"
    echo "- Check for aliases with zero usage that could be removed"
    echo "- Consider lazy-loading modules that are rarely used"
    echo "- Monitor startup time trends and optimize slow-loading modules"
}

# ============================================================================
# USAGE TRACKING MANAGEMENT
# ============================================================================

# Enable usage tracking
enable_tracking() {
    mkdir -p "$ANALYTICS_DIR"
    touch "$ANALYTICS_ENABLED_FILE"
    echo "Usage tracking enabled"
    echo "Data will be stored in: $ANALYTICS_DIR"
    echo "Use 'usage-analytics --disable' to turn off tracking"
}

# Disable usage tracking
disable_tracking() {
    rm -f "$ANALYTICS_ENABLED_FILE"
    echo "Usage tracking disabled"
    echo "Existing data preserved in: $ANALYTICS_DIR"
    echo "Use 'usage-analytics --clear' to remove all data"
}

# Clear all tracking data
clear_tracking_data() {
    read -p "Are you sure you want to delete all usage tracking data? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$ANALYTICS_DIR"
        echo "All usage tracking data cleared"
    else
        echo "Data clearing cancelled"
    fi
}

# Cleanup old data files
cleanup_old_data() {
    echo "Cleaning up old analytics data..."

    # Clean daily files
    if [[ -d "$ANALYTICS_DIR/daily" ]]; then
        local daily_count=$(ls -1 "$ANALYTICS_DIR/daily"/*.json 2>/dev/null | wc -l)
        if [[ $daily_count -gt $MAX_DAILY_FILES ]]; then
            ls -1t "$ANALYTICS_DIR/daily"/*.json | tail -n +$((MAX_DAILY_FILES + 1)) | xargs rm -f
            echo "Removed $((daily_count - MAX_DAILY_FILES)) old daily files"
        fi
    fi

    # Clean performance log
    if [[ -f "$PERFORMANCE_LOG" ]]; then
        local line_count=$(wc -l < "$PERFORMANCE_LOG")
        if [[ $line_count -gt $MAX_PERFORMANCE_ENTRIES ]]; then
            tail -n "$MAX_PERFORMANCE_ENTRIES" "$PERFORMANCE_LOG" > "${PERFORMANCE_LOG}.tmp"
            mv "${PERFORMANCE_LOG}.tmp" "$PERFORMANCE_LOG"
            echo "Trimmed performance log to $MAX_PERFORMANCE_ENTRIES entries"
        fi
    fi
}

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

show_help() {
    echo "usage-tracker.sh - Bash configuration usage analytics"
    echo
    echo "Usage: usage-analytics [command] [options]"
    echo
    echo "Commands:"
    echo "  --enable         Enable usage tracking"
    echo "  --disable        Disable usage tracking"
    echo "  --status         Show tracking status and data summary"
    echo "  --report [type]  Generate usage report (daily|weekly|modules|performance|cleanup)"
    echo "  --clear          Clear all tracking data"
    echo "  --cleanup        Clean up old data files"
    echo "  --export         Export data for external analysis"
    echo "  --help           Show this help message"
    echo
    echo "Report Options:"
    echo "  daily            Today's usage summary"
    echo "  weekly [days]    Trend analysis over specified days (default: 7)"
    echo "  modules [days]   Module usage analysis and unused module detection"
    echo "  performance      Startup time and loading performance analysis"
    echo "  cleanup          Recommendations for configuration cleanup"
    echo
    echo "Examples:"
    echo "  usage-analytics --enable"
    echo "  usage-analytics --report daily"
    echo "  usage-analytics --report weekly 14"
    echo "  usage-analytics --report modules 30"
}

# Main command interface
usage_analytics() {
    local command="${1:---status}"
    local option="$2"

    case "$command" in
        --enable)
            enable_tracking
            ;;
        --disable)
            disable_tracking
            ;;
        --status)
            if [[ -f "$ANALYTICS_ENABLED_FILE" ]]; then
                echo "Usage tracking: ENABLED"
                echo "Data directory: $ANALYTICS_DIR"

                if [[ -d "$ANALYTICS_DIR/daily" ]]; then
                    local daily_count=$(ls -1 "$ANALYTICS_DIR/daily"/*.json 2>/dev/null | wc -l)
                    echo "Daily data files: $daily_count"
                fi

                if [[ -f "$PERFORMANCE_LOG" ]]; then
                    local perf_count=$(wc -l < "$PERFORMANCE_LOG")
                    echo "Performance entries: $perf_count"
                fi
            else
                echo "Usage tracking: DISABLED"
                echo "Use 'usage-analytics --enable' to start tracking"
            fi
            ;;
        --report)
            if [[ ! -f "$ANALYTICS_ENABLED_FILE" ]]; then
                echo "Usage tracking is disabled"
                return 1
            fi
            generate_usage_report "${option:-daily}" "$3"
            ;;
        --clear)
            clear_tracking_data
            ;;
        --cleanup)
            cleanup_old_data
            ;;
        --export)
            echo "Exporting data to: $ANALYTICS_DIR/export_$(date +%Y%m%d_%H%M%S).tar.gz"
            tar -czf "$ANALYTICS_DIR/export_$(date +%Y%m%d_%H%M%S).tar.gz" -C "$ANALYTICS_DIR" .
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Unknown command: $command"
            show_help
            return 1
            ;;
    esac
}


show_menu() {
    clear
    echo "=== $DESCRIPTION ==="
    echo
    echo "Select an option:"
    echo
    echo "1) Show tracking status"
    echo "2) Daily usage report"
    echo "3) Weekly trend analysis"
    echo "4) Module usage analysis"
    echo "5) Performance report"
    echo "6) Enable tracking"
    echo "7) Disable tracking"
    echo "8) Clear all tracking data"
    echo "9) Cleanup old data"
    echo "0) Exit"
    echo
    read -p "Enter choice: " choice
    handle_menu_choice "$choice"
}

handle_menu_choice() {
    local choice="$1"
    
    case $choice in
        1) 
            usage_analytics --status
            ;;
        2) 
            usage_analytics --report daily
            ;;
        3)
            echo
            read -p "Days back (default 7): " days
            usage_analytics --report weekly "${days:-7}"
            ;;
        4)
            echo
            read -p "Days back (default 30): " days
            usage_analytics --report modules "${days:-30}"
            ;;
        5)
            echo
            read -p "Days back (default 7): " days
            usage_analytics --report performance "${days:-7}"
            ;;
        6)
            usage_analytics --enable
            ;;
        7)
            usage_analytics --disable
            ;;
        8)
            usage_analytics --clear
            ;;
        9)
            usage_analytics --cleanup
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

# Integration with existing bash configuration
# Add to load_layer and load_file functions:
#
# track_module_load "$layer" "$duration" "auto"
# track_startup_time "$(($(date +%s%3N) - BASHRC_START))"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "--menu" ]]; then
        show_menu
    else
        usage_analytics "$@"
    fi
fi

