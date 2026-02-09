#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    ((PASS++))
    echo "  PASS: $desc"
  else
    ((FAIL++))
    echo "  FAIL: $desc"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

check_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    ((PASS++))
    echo "  PASS: $desc"
  else
    ((FAIL++))
    echo "  FAIL: $desc — output does not contain '$needle'"
    echo "    output: $haystack"
  fi
}

echo "Running tests for: config-translator"
echo "======================================"

# --- Format detection ---
echo ""
echo "Format detection:"

RESULT=$(echo '{"key": "value"}' | "$SCRIPT_DIR/detect.sh")
check "detects JSON" "json" "$RESULT"

RESULT=$(echo -e "key: value\nlist:\n  - item1" | "$SCRIPT_DIR/detect.sh")
check "detects YAML" "yaml" "$RESULT"

RESULT=$(printf 'DATABASE_URL=postgres://localhost\nPORT=3000' | "$SCRIPT_DIR/detect.sh")
check "detects .env" "env" "$RESULT"

RESULT=$(printf '[section]\nkey = value' | "$SCRIPT_DIR/detect.sh")
check "detects INI" "ini" "$RESULT"

# --- JSON round-trip ---
echo ""
echo "JSON conversions:"

RESULT=$(echo '{"name":"test","port":8080}' | "$SCRIPT_DIR/run.sh" --from json --to yaml)
check_contains "JSON to YAML has key" "name: test" "$RESULT"
check_contains "JSON to YAML has port" "port: 8080" "$RESULT"

RESULT=$(printf "name: test\nport: 8080" | "$SCRIPT_DIR/run.sh" --from yaml --to json)
check_contains "YAML to JSON has name" '"name": "test"' "$RESULT"

# --- .env conversion ---
echo ""
echo "Env conversions:"

RESULT=$(echo '{"DB_HOST":"localhost","DB_PORT":"5432"}' | "$SCRIPT_DIR/run.sh" --from json --to env)
check_contains "JSON to env has DB_HOST" "DB_HOST=localhost" "$RESULT"
check_contains "JSON to env has DB_PORT" "DB_PORT=5432" "$RESULT"

RESULT=$(printf 'DB_HOST=localhost\nDB_PORT=5432' | "$SCRIPT_DIR/run.sh" --from env --to json)
check_contains "env to JSON" '"DB_HOST": "localhost"' "$RESULT"

# --- INI conversion ---
echo ""
echo "INI conversions:"

RESULT=$(echo '{"database":{"host":"localhost","port":"5432"}}' | "$SCRIPT_DIR/run.sh" --from json --to ini)
check_contains "JSON to INI has section" "[database]" "$RESULT"
check_contains "JSON to INI has host" "host = localhost" "$RESULT"

# --- Lossy warning ---
echo ""
echo "Warnings:"

RESULT=$(echo '{"app":{"db":{"host":"localhost"}}}' | "$SCRIPT_DIR/run.sh" --from json --to env 2>&1 >/dev/null || true)
check_contains "warns on nested to env" "Warning" "$RESULT"

# --- Error cases ---
echo ""
echo "Error cases:"

RESULT=$("$SCRIPT_DIR/run.sh" --to json 2>&1 <<< "" || true)
# Empty input should either produce {} or an error
if echo "$RESULT" | grep -qF "Error" || echo "$RESULT" | grep -qF "{}"; then
  ((PASS++))
  echo "  PASS: handles empty input"
else
  ((FAIL++))
  echo "  FAIL: handles empty input — got: $RESULT"
fi

# --- Help flag ---
echo ""
echo "Help flags:"

RESULT=$("$SCRIPT_DIR/run.sh" --help 2>&1)
check_contains "run.sh --help works" "Usage" "$RESULT"

RESULT=$("$SCRIPT_DIR/detect.sh" --help 2>&1)
check_contains "detect.sh --help works" "Usage" "$RESULT"

echo ""
echo "======================================"
echo "Results: $PASS passed, $FAIL failed, $((PASS + FAIL)) total"
[ "$FAIL" -eq 0 ] || exit 1
