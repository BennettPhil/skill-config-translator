---
name: config-translator
description: Converts between config formats (JSON, YAML, TOML, INI, dotenv) with lossy conversion warnings.
version: 0.1.0
license: Apache-2.0
---

# Config Translator

## Purpose

Convert configuration files between JSON, YAML, TOML, INI, and .env formats. Handles nested structures, arrays, and type coercion. Warns when a conversion is lossy (e.g., YAML comments lost in JSON, nested objects flattened in .env).

## Quick Start

```bash
$ ./scripts/run.sh input.json --to yaml
# Outputs YAML to stdout
database:
  host: localhost
  port: 5432
  name: myapp
```

### Example: JSON to YAML

```bash
$ echo '{"server": {"host": "0.0.0.0", "port": 8080}}' | ./scripts/run.sh --from json --to yaml
server:
  host: 0.0.0.0
  port: 8080
```

### Example: YAML to TOML

```bash
$ echo -e "database:\n  host: localhost\n  port: 5432" | ./scripts/run.sh --from yaml --to toml
[database]
host = "localhost"
port = 5432
```

### Example: JSON to .env (Flat)

```bash
$ echo '{"DB_HOST": "localhost", "DB_PORT": "5432"}' | ./scripts/run.sh --from json --to env
DB_HOST=localhost
DB_PORT=5432
```

### Example: .env to JSON

```bash
$ echo -e "APP_NAME=myapp\nDEBUG=true\nPORT=3000" | ./scripts/run.sh --from env --to json
{
  "APP_NAME": "myapp",
  "DEBUG": "true",
  "PORT": "3000"
}
```

### Example: Lossy Conversion Warning

```bash
$ echo '{"a": {"b": {"c": "deep"}}}' | ./scripts/run.sh --from json --to env
# Warning: Nested structures flattened with underscore separator
A_B_C=deep
```

## Smoke Tests

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT="./scripts/run.sh"
PASS=0; FAIL=0
check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    ((PASS++)); echo "PASS: $desc"
  else
    ((FAIL++)); echo "FAIL: $desc"
    echo "  expected: $expected"
    echo "  actual:   $actual"
  fi
}

# Test JSON to env
actual=$(echo '{"FOO": "bar"}' | $SCRIPT --from json --to env 2>/dev/null)
check "json to env" "FOO=bar" "$actual"

# Test env to json
actual=$(echo "FOO=bar" | $SCRIPT --from env --to json 2>/dev/null)
expected='{"FOO":"bar"}'
# Normalize whitespace for comparison
actual_norm=$(echo "$actual" | tr -d ' \n')
check "env to json" "$expected" "$actual_norm"

# Test missing --from with stdin
actual=$($SCRIPT --to json 2>&1 || true)
check "error without --from on stdin" "Error: --from is required when reading from stdin" "$actual"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

## Options Reference

| Flag         | Default | Description                                        |
|--------------|---------|----------------------------------------------------|
| `--from FMT` | auto    | Input format: json, yaml, toml, ini, env. Auto-detected from file extension |
| `--to FMT`   | (required) | Output format: json, yaml, toml, ini, env       |
| `--output FILE` | stdout | Write to file instead of stdout                 |
| `--flatten SEP` | `_`  | Separator for flattening nested keys (env/ini)   |
| `--help`     |         | Show usage information                            |

## Error Handling

| Exit Code | Meaning                                |
|-----------|----------------------------------------|
| 0         | Success                                |
| 1         | Usage error (missing flags, bad format)|
| 2         | Parse error (invalid input)            |
| 3         | Conversion error (unsupported feature) |
