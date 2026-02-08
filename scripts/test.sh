#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        echo "    expected: $(echo "$expected" | head -3)"
        echo "    actual:   $(echo "$actual" | head -3)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== config-translator tests ==="

# Test 1: JSON to YAML (command substitution strips trailing newline)
json_input='{"name": "myapp", "port": 3000}'
actual=$(echo "$json_input" | python3 "$SCRIPT_DIR/convert.py" --from json --to yaml)
expected="name: myapp
port: 3000"
check "JSON to YAML" "$expected" "$actual"

# Test 2: JSON to env
actual=$(echo "$json_input" | python3 "$SCRIPT_DIR/convert.py" --from json --to env)
expected="name=myapp
port=3000"
check "JSON to env" "$expected" "$actual"

# Test 3: env to JSON
env_input="HOST=localhost
PORT=8080"
actual=$(echo "$env_input" | python3 "$SCRIPT_DIR/convert.py" --from env --to json)
expected='{
  "HOST": "localhost",
  "PORT": "8080"
}'
check "env to JSON" "$expected" "$actual"

# Test 4: --help flag exits 0
bash "$SCRIPT_DIR/run.sh" --help >/dev/null 2>&1 && help_code=0 || help_code=$?
check "--help exits 0" "0" "$help_code"

# Test 5: missing --to exits non-zero
set +e
bash "$SCRIPT_DIR/run.sh" </dev/null >/dev/null 2>&1
no_to_code=$?
set -e
check "missing --to exits non-zero" "1" "$((no_to_code > 0 ? 1 : 0))"

echo ""
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
