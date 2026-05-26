#!/usr/bin/env bash
set -euo pipefail

cpu_usage() {
  local cpu_line1 cpu_line2
  local -a fields1 fields2
  local idle1 total1 idle2 total2 idle_delta total_delta usage

  cpu_line1=$(grep '^cpu ' /proc/stat)
  read -r -a fields1 <<< "$cpu_line1"
  sleep 1
  cpu_line2=$(grep '^cpu ' /proc/stat)
  read -r -a fields2 <<< "$cpu_line2"

  idle1=$((fields1[4] + fields1[5]))
  total1=0
  for value in "${fields1[@]:1}"; do
    total1=$((total1 + value))
  done

  idle2=$((fields2[4] + fields2[5]))
  total2=0
  for value in "${fields2[@]:1}"; do
    total2=$((total2 + value))
  done

  idle_delta=$((idle2 - idle1))
  total_delta=$((total2 - total1))

  if [ "$total_delta" -le 0 ]; then
    usage=0
  else
    usage=$(awk -v i="$idle_delta" -v t="$total_delta" 'BEGIN { printf "%.2f", (1 - i / t) * 100 }')
  fi

  echo "$usage"
}

memory_stats() {
  free -m | awk 'NR==2 {
    used=$3
    free=$4
    total=$2
    pct=(used/total)*100
    printf "Used: %sMB | Free: %sMB | Usage: %.2f%%\n", used, free, pct
  }'
}

disk_stats() {
  df -h / | awk 'NR==2 {
    used=$3
    free=$4
    pct=$5
    printf "Used: %s | Free: %s | Usage: %s\n", used, free, pct
  }'
}

echo "===== Server Performance Stats ====="
echo "Timestamp: $(date)"
echo

echo "Total CPU Usage: $(cpu_usage)%"
echo "Total Memory Usage: $(memory_stats)"
echo "Total Disk Usage: $(disk_stats)"
echo

echo "Top 5 Processes by CPU Usage:"
ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6
echo

echo "Top 5 Processes by Memory Usage:"
ps -eo pid,comm,%mem --sort=-%mem | head -n 6
