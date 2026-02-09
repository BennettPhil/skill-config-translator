# Config Translator

Translate configuration files between JSON, YAML, TOML, INI, and .env formats.

## Prerequisites

- Python 3.6+
- jq
- PyYAML (`pip install pyyaml`)
- tomli (`pip install tomli` for Python < 3.11)

## Install

```bash
./scripts/install.sh
```

## Usage

```bash
# Convert YAML to JSON
./scripts/run.sh --to json config.yaml

# Convert with explicit source format
./scripts/run.sh --from yaml --to toml config.yaml

# Pipe through stdin
cat config.yaml | ./scripts/run.sh --to env

# Use individual scripts in a pipeline
cat config.yaml | ./scripts/to-json.sh --from yaml | ./scripts/from-json.sh --to toml
```

## Test

```bash
./scripts/test.sh
```
