#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat >&2 <<'EOF'
Usage: run.sh [--from FORMAT] --to FORMAT [FILE]

Convert configuration files between formats.

Formats: json, yaml, toml, ini, env

Options:
    --from FORMAT   Source format (auto-detected if omitted)
    --to FORMAT     Target format (required)
    -h, --help      Show this help message

Examples:
    run.sh --to yaml config.json
    cat .env | run.sh --from env --to json
EOF
    exit "${1:-0}"
}

FROM=""
TO=""
FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --from) FROM="$2"; shift 2 ;;
        --to)   TO="$2"; shift 2 ;;
        -h|--help) usage 0 ;;
        -*) echo "Unknown option: $1" >&2; usage 1 ;;
        *)  FILE="$1"; shift ;;
    esac
done

if [[ -z "$TO" ]]; then
    echo "Error: --to FORMAT is required" >&2
    usage 1
fi

exec python3 "$SCRIPT_DIR/convert.py" ${FROM:+--from "$FROM"} --to "$TO" ${FILE:+"$FILE"}
