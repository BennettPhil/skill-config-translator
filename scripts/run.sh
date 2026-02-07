#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: run.sh [OPTIONS] <input-file>

Convert configuration files between JSON, YAML, TOML, INI, and .env formats.

Arguments:
  <input-file>         Path to the input configuration file

Options:
  --from <format>      Source format (json, yaml, toml, ini, env)
                       Auto-detected from file extension if omitted
  --to <format>        Target format (json, yaml, toml, ini, env). Required.
  --output <path>      Write output to a file instead of stdout
  --help               Show this help message

Supported formats:
  json    JSON (.json)
  yaml    YAML (.yaml, .yml)
  toml    TOML (.toml)
  ini     INI  (.ini, .cfg)
  env     Environment file (.env)

Examples:
  run.sh config.json --to yaml
  run.sh settings.yaml --to toml --output settings.toml
  run.sh --from json --to env config.json
USAGE
}

FROM_FMT=""
TO_FMT=""
OUTPUT=""
INPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM_FMT="$2"; shift 2 ;;
    --to) TO_FMT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --help) usage; exit 0 ;;
    -*) echo "Error: Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *) INPUT="$1"; shift ;;
  esac
done

if [ -z "$INPUT" ]; then
  echo "Error: Input file is required." >&2
  usage >&2
  exit 1
fi

if [ ! -f "$INPUT" ]; then
  echo "Error: File not found: $INPUT" >&2
  exit 1
fi

if [ -z "$TO_FMT" ]; then
  echo "Error: --to format is required." >&2
  usage >&2
  exit 1
fi

exec python3 "$SCRIPT_DIR/convert.py" "$INPUT" --from "$FROM_FMT" --to "$TO_FMT" ${OUTPUT:+--output "$OUTPUT"}
