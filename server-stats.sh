#!/bin/bash

# =============================================================================
# server-stats.sh — Server Performance Analyser
# Author: [Your Name]
# Description: Displays key server performance metrics for quick diagnostics.
#
# Usage:
#   chmod +x server-stats.sh   # Make it executable (only needed once)
#   ./server-stats.sh          # Run it
# =============================================================================


# -----------------------------------------------------------------------------
# STYLING HELPERS
# These are ANSI escape codes. The terminal interprets them as color/style
# instructions rather than printing them literally.
# \e[1m = bold, \e[0m = reset all styles back to default
# \e[36m = cyan, \e[32m = green, \e[33m = yellow, \e[31m = red
# -----------------------------------------------------------------------------
BOLD="\e[1m"
RESET="\e[0m"
CYAN="\e[36m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
DIM="\e[2m"
LINE="${DIM}$(printf '%.0s─' {1..60})${RESET}"

# A reusable function to print section headers
# Functions in bash: defined with `name() { ... }`, called by just writing `name`
print_header() {
    echo ""
    echo -e "$LINE"
    echo -e "  ${CYAN}${BOLD}$1${RESET}"
    echo -e "$LINE"
}


# =============================================================================
# SECTION 0: BANNER + TIMESTAMP
# =============================================================================

echo ""
echo -e "${BOLD}${CYAN}"
echo "  ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗"
echo "  ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗"
echo "  ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝"
echo "  ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗"
echo "  ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║"
echo "  ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝"
echo -e "${RESET}"
echo -e "  ${DIM}Server Performance Stats — $(date '+%A, %d %B %Y %H:%M:%S %Z')${RESET}"


# =============================================================================
# SECTION 1: SYSTEM OVERVIEW (Stretch Goal)
# =============================================================================
# `uname` = "Unix Name" — prints system info
#   -s: kernel name (e.g., Linux)
#   -r: kernel release (e.g., 5.15.0-91-generic)
#   -m: machine hardware (e.g., x86_64)
#
# `hostname` = the server's name
#
# `uptime -p` = human-readable uptime like "up 3 hours, 20 minutes"
#   without -p it shows raw format like " 10:23:01 up 3:20, 2 users"
#
# `uptime -s` = when the system started (boot time)
# =============================================================================

print_header "⚙  SYSTEM OVERVIEW"

OS_NAME=$(grep '^PRETTY_NAME' /etc/os-release 2>/dev/null | cut -d'"' -f2)
# /etc/os-release is a standard file all modern Linux distros have.
# `grep '^PRETTY_NAME'` finds the line starting with PRETTY_NAME.
# `cut -d'"' -f2` splits by double-quote and grabs the 2nd field (the value).
# `2>/dev/null` silences errors if the file doesn't exist.

[ -z "$OS_NAME" ] && OS_NAME="$(uname -s) $(uname -r)"
# [ -z "$VAR" ] = true if VAR is empty. This is a fallback.
# `&&` = run the next command only if the previous one succeeded (was true).

KERNEL=$(uname -r)
HOSTNAME=$(hostname)
ARCH=$(uname -m)
UPTIME=$(uptime -p 2>/dev/null || uptime | awk '{print $3, $4}' | tr -d ',')
BOOT_TIME=$(uptime -s 2>/dev/null || echo "N/A")
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
# /proc/loadavg has 5 fields: 1-min, 5-min, 15-min averages, then running/total tasks, then last PID.
# We grab just the first 3 (the load averages over 1, 5, and 15 minutes).
# Load average = average number of processes waiting for CPU. Healthy = below number of CPU cores.

CPU_CORES=$(nproc)
# `nproc` = number of processing units available. This is what we compare load average against.

LOGGED_USERS=$(who | wc -l)
# `who` lists each currently logged-in user, one per line.
# `wc -l` counts lines. So this = number of active sessions.

printf "  ${BOLD}%-20s${RESET} %s\n" "OS:" "$OS_NAME"
printf "  ${BOLD}%-20s${RESET} %s\n" "Kernel:" "$KERNEL"
printf "  ${BOLD}%-20s${RESET} %s\n" "Hostname:" "$HOSTNAME"
printf "  ${BOLD}%-20s${RESET} %s\n" "Architecture:" "$ARCH"
printf "  ${BOLD}%-20s${RESET} %s\n" "Uptime:" "$UPTIME"
printf "  ${BOLD}%-20s${RESET} %s\n" "Boot Time:" "$BOOT_TIME"
printf "  ${BOLD}%-20s${RESET} %s (cores: $CPU_CORES)\n" "Load Average:" "$LOAD_AVG"
printf "  ${BOLD}%-20s${RESET} %s\n" "Logged-in Users:" "$LOGGED_USERS"
# `printf` is like a more powerful `echo`. 
# %-20s = left-aligned string in a 20-character wide field. This lines up the values nicely.


# =============================================================================
# SECTION 2: CPU USAGE
# =============================================================================
# How CPU % is calculated:
#   `top -bn1` = run top in batch mode (-b), just 1 iteration (-n1), non-interactive.
#   We grep for the "Cpu(s)" line which looks like:
#   %Cpu(s): 12.3 us, 3.4 sy, 0.0 ni, 81.2 id, 2.1 wa, 0.0 hi, 1.0 si
#   "id" = idle percentage. CPU usage = 100 - idle.
#   `awk` extracts the idle value, then calculates usage.
# =============================================================================

print_header "🖥  CPU USAGE"

CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%,')
# If the above doesn't work on all distros, this alternative is more portable:
# CPU_IDLE=$(top -bn1 | grep -E "^(%Cpu|Cpu)" | awk -F',' '{for(i=1;i<=NF;i++) if($i~/id/) print $i}' | tr -dc '0-9.')

CPU_USAGE=$(awk "BEGIN {printf \"%.1f\", 100 - $CPU_IDLE}")
# `awk BEGIN {...}` runs before processing any input — great for pure math.
# `printf "%.1f"` = format as float with 1 decimal place.
# We use awk for floating point because bash only does integer arithmetic.

# Color the output based on severity — this is a useful pattern!
if (( $(echo "$CPU_USAGE > 85" | bc -l) )); then
    COLOR=$RED
elif (( $(echo "$CPU_USAGE > 60" | bc -l) )); then
    COLOR=$YELLOW
else
    COLOR=$GREEN
fi
# `bc -l` = basic calculator with math library. Handles decimals bash can't.
# `echo "12.3 > 60" | bc -l` outputs 0 (false) or 1 (true).
# (( ... )) = arithmetic evaluation in bash. (( 1 )) = true, (( 0 )) = false.

echo -e "  Total CPU Usage: ${COLOR}${BOLD}${CPU_USAGE}%${RESET}"

# Visual bar — a fun way to show percentages
BAR_FILLED=$(awk "BEGIN {printf \"%d\", $CPU_USAGE / 5}")
BAR_EMPTY=$((20 - BAR_FILLED))
printf "  ["
printf "${COLOR}%0.s█${RESET}" $(seq 1 $BAR_FILLED) 2>/dev/null
printf "%0.s░" $(seq 1 $BAR_EMPTY) 2>/dev/null
printf "] ${COLOR}${CPU_USAGE}%%${RESET}\n"
# `seq 1 N` generates numbers 1 to N. `%0.s` prints nothing per argument — 
# so this loop just prints the character N times. A neat bash trick!


# =============================================================================
# SECTION 3: MEMORY USAGE
# =============================================================================
# `free -m` outputs memory in megabytes. The output looks like:
#              total        used        free      shared  buff/cache   available
#  Mem:         7976        1234        3210         112        3532        6388
#  Swap:        2047           0        2047
#
# We use `awk 'NR==2'` to get the 2nd row (Mem), then extract columns.
# NR = Number of Records (line number in awk).
# $1=label $2=total $3=used $4=free $7=available
# =============================================================================

print_header "🧠  MEMORY USAGE"

read TOTAL USED FREE AVAILABLE <<< $(free -m | awk 'NR==2 {print $2, $3, $4, $7}')
# `read A B C <<< "x y z"` assigns x→A, y→B, z→C. A clean way to unpack values.

USED_PCT=$(awk "BEGIN {printf \"%.1f\", ($USED/$TOTAL)*100}")
FREE_PCT=$(awk "BEGIN {printf \"%.1f\", ($FREE/$TOTAL)*100}")
AVAIL_PCT=$(awk "BEGIN {printf \"%.1f\", ($AVAILABLE/$TOTAL)*100}")

if (( $(echo "$USED_PCT > 90" | bc -l) )); then
    MEM_COLOR=$RED
elif (( $(echo "$USED_PCT > 70" | bc -l) )); then
    MEM_COLOR=$YELLOW
else
    MEM_COLOR=$GREEN
fi

printf "  ${BOLD}%-20s${RESET} %s MB\n"   "Total RAM:"     "$TOTAL"
printf "  ${BOLD}%-20s${RESET} ${MEM_COLOR}%s MB (${USED_PCT}%%)${RESET}\n" "Used:" "$USED"
printf "  ${BOLD}%-20s${RESET} %s MB (${FREE_PCT}%%)\n"   "Free:"      "$FREE"
printf "  ${BOLD}%-20s${RESET} ${GREEN}%s MB (${AVAIL_PCT}%%)${RESET}\n" "Available:" "$AVAILABLE"

# Bar
MEM_FILLED=$(awk "BEGIN {printf \"%d\", $USED_PCT / 5}")
MEM_EMPTY=$((20 - MEM_FILLED))
printf "\n  ["
printf "${MEM_COLOR}%0.s█${RESET}" $(seq 1 $MEM_FILLED) 2>/dev/null
printf "%0.s░" $(seq 1 $MEM_EMPTY) 2>/dev/null
printf "] ${MEM_COLOR}${USED_PCT}%% used${RESET}\n"

# Swap memory
read SWAP_TOTAL SWAP_USED SWAP_FREE <<< $(free -m | awk 'NR==3 {print $2, $3, $4}')
if [ "$SWAP_TOTAL" -gt 0 ] 2>/dev/null; then
    SWAP_PCT=$(awk "BEGIN {printf \"%.1f\", ($SWAP_USED/$SWAP_TOTAL)*100}")
    echo ""
    printf "  ${DIM}Swap: ${SWAP_USED}/${SWAP_TOTAL} MB used (${SWAP_PCT}%%)${RESET}\n"
fi


# =============================================================================
# SECTION 4: DISK USAGE
# =============================================================================
# `df -h` = disk free, human-readable (shows GB/MB instead of bytes)
# `df -hT` also shows filesystem Type (ext4, tmpfs, etc.)
# We skip tmpfs/devtmpfs/squashfs — these are virtual/system filesystems,
# not real disks. We only want actual mounted partitions.
# =============================================================================

print_header "💾  DISK USAGE"

echo ""
printf "  ${BOLD}%-25s %-10s %-10s %-10s %-6s${RESET}\n" "Mount Point" "Total" "Used" "Free" "Use%"
printf "  ${DIM}%-25s %-10s %-10s %-10s %-6s${RESET}\n" "─────────────────────" "─────────" "─────────" "─────────" "─────"

df -hT | awk 'NR>1 && $2!~/tmpfs|devtmpfs|squashfs|overlay|udev/ {print $7, $3, $4, $5, $6}' | \
while read MOUNT TOTAL USED FREE PCT; do
    # Strip the % from PCT for numeric comparison
    PCT_NUM=${PCT/\%/}
    
    if [ "$PCT_NUM" -gt 89 ] 2>/dev/null; then
        DISK_COLOR=$RED
    elif [ "$PCT_NUM" -gt 70 ] 2>/dev/null; then
        DISK_COLOR=$YELLOW
    else
        DISK_COLOR=$GREEN
    fi
    
    printf "  %-25s %-10s ${DISK_COLOR}%-10s${RESET} %-10s ${DISK_COLOR}%-6s${RESET}\n" \
        "$MOUNT" "$TOTAL" "$USED" "$FREE" "$PCT"
done
# This is a pipeline into a while loop — a key bash pattern.
# `while read VAR1 VAR2...` reads each line from stdin, splitting by whitespace.


# =============================================================================
# SECTION 5: TOP 5 PROCESSES BY CPU
# =============================================================================
# `ps aux` = list all processes with:
#   a = all users, u = user-oriented format, x = include processes without terminal
# Output columns: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND
# We sort by %CPU (column 3), take top 5 (skip header), format nicely.
#
# `sort -rn -k3` = sort in reverse (-r) numerically (-n) by column 3 (-k3)
# `head -6` = first 6 lines (1 header + 5 results)
# =============================================================================

print_header "⚡  TOP 5 PROCESSES BY CPU"

echo ""
printf "  ${BOLD}%-8s %-12s %-8s %-8s %s${RESET}\n" "PID" "USER" "%CPU" "%MEM" "COMMAND"
printf "  ${DIM}%-8s %-12s %-8s %-8s %s${RESET}\n" "───────" "───────────" "───────" "───────" "───────────────────"

ps aux --sort=-%cpu | awk 'NR>1 {printf "  %-8s %-12s %-8s %-8s %s\n", $2, $1, $3, $4, $11}' | head -5
# `--sort=-%cpu` = sort by CPU descending (- means descending)
# NR>1 skips the header row
# $11 = the command name (first word). We use $11 not $0 to avoid super long lines.


# =============================================================================
# SECTION 6: TOP 5 PROCESSES BY MEMORY
# =============================================================================
# Same as above but sorted by %MEM (column 4).
# =============================================================================

print_header "🧬  TOP 5 PROCESSES BY MEMORY"

echo ""
printf "  ${BOLD}%-8s %-12s %-8s %-8s %s${RESET}\n" "PID" "USER" "%MEM" "%CPU" "COMMAND"
printf "  ${DIM}%-8s %-12s %-8s %-8s %s${RESET}\n" "───────" "───────────" "───────" "───────" "───────────────────"

ps aux --sort=-%mem | awk 'NR>1 {printf "  %-8s %-12s %-8s %-8s %s\n", $2, $1, $4, $3, $11}' | head -5


# =============================================================================
# SECTION 7: NETWORK STATS (Stretch Goal)
# =============================================================================
# /proc/net/dev contains per-interface receive/transmit byte counters.
# We skip 'lo' (loopback — the 127.0.0.1 interface, for internal communication).
# =============================================================================

print_header "🌐  NETWORK INTERFACES"

echo ""
printf "  ${BOLD}%-12s %-20s %-20s${RESET}\n" "Interface" "RX (received)" "TX (transmitted)"
printf "  ${DIM}%-12s %-20s %-20s${RESET}\n" "───────────" "───────────────────" "───────────────────"

awk 'NR>2 && !/lo:/ {
    gsub(/:/, "", $1)   # remove colon from interface name
    rx = $2/1024/1024   # bytes → MB
    tx = $10/1024/1024
    printf "  %-12s %-20s %-20s\n", $1, sprintf("%.2f MB", rx), sprintf("%.2f MB", tx)
}' /proc/net/dev


# =============================================================================
# SECTION 8: FAILED LOGIN ATTEMPTS (Stretch Goal)
# =============================================================================
# Auth logs are in different places depending on distro:
#   Debian/Ubuntu: /var/log/auth.log
#   RHEL/CentOS/Fedora: /var/log/secure
# We check which one exists.
# `journalctl` is the modern systemd-based alternative that works everywhere.
# =============================================================================

print_header "🔐  FAILED LOGIN ATTEMPTS (last 24h)"

FAILED=0

if [ -f /var/log/auth.log ]; then
    # `grep -c` counts matching lines instead of printing them
    FAILED=$(grep "Failed password" /var/log/auth.log 2>/dev/null | \
             awk -v date="$(date '+%b %e')" '$0 ~ date' | wc -l)
elif [ -f /var/log/secure ]; then
    FAILED=$(grep "Failed password" /var/log/secure 2>/dev/null | \
             awk -v date="$(date '+%b %e')" '$0 ~ date' | wc -l)
else
    # Try journalctl as fallback (available on systemd-based systems)
    FAILED=$(journalctl _SYSTEMD_UNIT=sshd.service --since "24 hours ago" 2>/dev/null | \
             grep -c "Failed password" || echo "0")
fi

if [ "$FAILED" -gt 50 ] 2>/dev/null; then
    echo -e "  ${RED}${BOLD}⚠  $FAILED failed SSH login attempts detected! Investigate immediately.${RESET}"
elif [ "$FAILED" -gt 10 ] 2>/dev/null; then
    echo -e "  ${YELLOW}⚠  $FAILED failed login attempts in the last 24 hours.${RESET}"
else
    echo -e "  ${GREEN}✓  $FAILED failed login attempts in the last 24 hours.${RESET}"
fi

# Show top attacking IPs if there were failures
if [ "$FAILED" -gt 0 ] && [ -f /var/log/auth.log ]; then
    echo ""
    echo -e "  ${DIM}Top source IPs:${RESET}"
    grep "Failed password" /var/log/auth.log 2>/dev/null | \
        grep -oP 'from \K[\d.]+' | \
        sort | uniq -c | sort -rn | head -3 | \
        awk '{printf "  %-6s attempts from %s\n", $1, $2}'
    # `grep -oP 'from \K[\d.]+'` uses Perl regex (-P) to extract just the IP
    # after "from ". \K = "forget what came before" (lookbehind shortcut).
    # `sort | uniq -c | sort -rn` = classic "count occurrences" pattern
fi


# =============================================================================
# FOOTER
# =============================================================================
echo ""
echo -e "$LINE"
echo -e "  ${DIM}Script completed at $(date '+%H:%M:%S') | Run as: $(whoami)${RESET}"
echo -e "$LINE"
echo ""

exit 0
# Always exit 0 to signal success to the calling shell or any automation tools.
