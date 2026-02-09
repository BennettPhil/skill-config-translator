#!/usr/bin/env bash
set -euo pipefail

echo "Checking dependencies for config-translator..."

MISSING=0

check_cmd() {
  if command -v "$1" &>/dev/null; then
    echo "  [OK] $1"
  else
    echo "  [MISSING] $1 — $2"
    MISSING=1
  fi
}

check_cmd python3 "Required for format parsing. Install via your package manager."
check_cmd jq "Required for JSON processing. Install: brew install jq / apt install jq"

# Check Python modules
for mod in json yaml; do
  if python3 -c "import $mod" 2>/dev/null; then
    echo "  [OK] python3 module: $mod"
  else
    echo "  [MISSING] python3 module: $mod — pip install pyyaml"
    MISSING=1
  fi
done

# Check tomllib (Python 3.11+) or tomli fallback
if python3 -c "import tomllib" 2>/dev/null || python3 -c "import tomli" 2>/dev/null; then
  echo "  [OK] python3 TOML support"
else
  echo "  [MISSING] python3 TOML support — pip install tomli (for Python < 3.11)"
  MISSING=1
fi

if [ "$MISSING" -eq 1 ]; then
  echo ""
  echo "Some dependencies are missing. Install them and re-run this script."
  exit 1
fi

echo ""
echo "All dependencies satisfied."
