---
name: config-translator
description: Translate configuration files between JSON, YAML, TOML, INI, and .env formats with lossy conversion warnings.
version: 0.1.0
license: Apache-2.0
---

# Config Translator

A composable set of shell scripts that convert between common configuration file formats: JSON, YAML, TOML, INI, and .env files.

## Purpose

Configuration files come in many formats. Moving between projects, tools, or deployment targets often requires converting config from one format to another. This skill provides a Unix-friendly pipeline for translating between JSON, YAML, TOML, INI, and .env formats while warning about lossy conversions (e.g., nested structures flattened to .env).

## Scripts Overview

| Script | Description |
|--------|-------------|
| `scripts/run.sh` | Main entry point — detects input format and converts to target |
| `scripts/detect.sh` | Auto-detects the format of a config file |
| `scripts/to-json.sh` | Converts any supported format to JSON (canonical intermediate) |
| `scripts/from-json.sh` | Converts JSON to any supported target format |
| `scripts/validate.sh` | Validates that a file is well-formed for its format |
| `scripts/install.sh` | Checks and installs required dependencies |
| `scripts/test.sh` | Runs tests with sample configs |

## Pipeline Examples

```bash
# Convert YAML to TOML
cat config.yaml | ./scripts/to-json.sh --from yaml | ./scripts/from-json.sh --to toml

# Auto-detect and convert
./scripts/run.sh --to env config.yaml

# Validate before converting
./scripts/validate.sh config.toml && ./scripts/run.sh --to json config.toml

# Chain: detect format, then convert
FORMAT=$(./scripts/detect.sh config.txt)
./scripts/run.sh --from "$FORMAT" --to yaml config.txt
```

## Inputs and Outputs

All scripts read from stdin or accept a file path as the last argument. Output goes to stdout. Errors and warnings go to stderr.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONFIG_TRANSLATOR_WARN` | `1` | Set to `0` to suppress lossy conversion warnings |
| `CONFIG_TRANSLATOR_STRICT` | `0` | Set to `1` to fail on lossy conversions instead of warning |

## Constraints

- Nested structures deeper than 3 levels are flattened with dot-notation for INI and .env
- Comments are preserved only when converting between formats that both support them
- Binary values are not supported
- Requires Python 3.6+ (for TOML/YAML parsing)
