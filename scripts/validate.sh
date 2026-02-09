#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: validate.sh [--format FORMAT] [FILE]"
  echo "Validate that a config file is well-formed."
  echo "If --format is omitted, auto-detects the format."
  echo "Reads from stdin if no file is given."
}

FORMAT=""
FILE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --format) FORMAT="$2"; shift 2 ;;
    *) FILE="$1"; shift ;;
  esac
done

if [ -n "$FILE" ] && [ "$FILE" != "-" ]; then
  INPUT=$(cat "$FILE")
else
  INPUT=$(cat)
fi

if [ -z "$FORMAT" ]; then
  FORMAT=$(echo "$INPUT" | "$SCRIPT_DIR/detect.sh")
fi

echo "$INPUT" | "$SCRIPT_DIR/to-json.sh" --from "$FORMAT" >/dev/null 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "Valid $FORMAT"
else
  echo "Invalid $FORMAT" >&2
  exit 1
fi
