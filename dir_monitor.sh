#!/usr/bin/env bash
# dir_monitor.sh - Simple directory change monitor using inotifywait
# Usage: ./dir_monitor.sh /path/to/watch [logfile]
# Example: ./dir_monitor.sh /home/varsha/Documents dir_changes.log

set -u
DIR_TO_WATCH="$1"
LOGFILE="${2:-dir_changes.log}"

# Validate directory
if [ -z "$DIR_TO_WATCH" ] || [ ! -d "$DIR_TO_WATCH" ]; then
  echo "Usage: $0 /path/to/watch [optional_logfile]"
  echo "Error: directory '$DIR_TO_WATCH' does not exist."
  exit 1
fi

# Ensure logfile exists and writable
touch "$LOGFILE" 2>/dev/null || { echo "Cannot create or write to $LOGFILE"; exit 2; }

echo "Monitoring: $DIR_TO_WATCH"
echo "Logging to: $LOGFILE"
echo "Press Ctrl+C to stop."

# inotifywait produces events like: "2025-11-21 12:34:56 MODIFY somefile.txt"
inotifywait -m -r -e create -e delete -e modify --format '%T %e %w%f' --timefmt '%Y-%m-%d %H:%M:%S' "$DIR_TO_WATCH" \
  | while IFS= read -r line; do
      # Normalize event name(s) (e.g. "MODIFY" "CREATE,ISDIR")
      timestamp=$(echo "$line" | awk '{printf $1 " " $2}')
      event_and_file=$(echo "$line" | cut -d' ' -f3-)
      # split event and path: last token is path, earlier token(s) are events
      # we assume format: "<timestamp> <EVENTS> <fullpath>"
      events=$(echo "$event_and_file" | awk '{print $1}')
      file=$(echo "$event_and_file" | cut -d' ' -f2-)
      # Simplify event type
      if echo "$events" | grep -q 'CREATE'; then
        event_type="CREATED"
      elif echo "$events" | grep -q 'DELETE'; then
        event_type="DELETED"
      elif echo "$events" | grep -q 'MODIFY'; then
        event_type="MODIFIED"
      else
        event_type="$events"
      fi
      echo "[$timestamp] $event_type: $file" >> "$LOGFILE"
  done
