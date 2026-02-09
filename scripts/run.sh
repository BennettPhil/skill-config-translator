#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: run.sh [--from FORMAT] --to FORMAT [FILE]"
  echo ""
  echo "Convert a configuration file between formats."
  echo ""
  echo "Formats: json, yaml, toml, ini, env"
  echo ""
  echo "Options:"
  echo "  --from FORMAT   Source format (auto-detected if omitted)"
  echo "  --to FORMAT     Target format (required)"
  echo "  --help          Show this help"
  echo ""
  echo "Reads from stdin if no file is given."
  echo ""
  echo "Environment:"
  echo "  CONFIG_TRANSLATOR_WARN=0    Suppress lossy conversion warnings"
  echo "  CONFIG_TRANSLATOR_STRICT=1  Fail on lossy conversions"
}

FROM=""
TO=""
FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --from) FROM="$2"; shift 2 ;;
    --to) TO="$2"; shift 2 ;;
    *) FILE="$1"; shift ;;
  esac
done

if [ -z "$TO" ]; then
  echo "Error: --to FORMAT is required. Use --help for usage." >&2
  exit 1
fi

if [ -n "$FILE" ] && [ "$FILE" != "-" ]; then
  INPUT=$(cat "$FILE")
else
  INPUT=$(cat)
fi

if [ -z "$FROM" ]; then
  FROM=$(echo "$INPUT" | "$SCRIPT_DIR/detect.sh")
  if [ "$FROM" = "unknown" ]; then
    echo "Error: could not detect input format. Use --from to specify." >&2
    exit 1
  fi
fi

echo "$INPUT" | "$SCRIPT_DIR/to-json.sh" --from "$FROM" | "$SCRIPT_DIR/from-json.sh" --to "$TO"
