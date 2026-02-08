---
name: config-translator
description: Converts configuration files between JSON, YAML, TOML, INI, and .env formats with comment preservation where supported.
version: 0.1.0
license: Apache-2.0
---

# Config Translator

Converts configuration files between common formats: JSON, YAML, TOML, INI, and .env files. Reads from stdin or a file, detects the source format automatically (or accepts it explicitly), and outputs the translated configuration to stdout.

## Usage

```bash
# Auto-detect input format, output as YAML
./scripts/run.sh --to yaml config.json

# Explicit source format, read from stdin
cat settings.toml | ./scripts/run.sh --from toml --to json

# Convert .env to JSON
./scripts/run.sh --to json .env.production
```

## Options

- `--from <format>` — Source format: `json`, `yaml`, `toml`, `ini`, `env`. Auto-detected if omitted.
- `--to <format>` — Target format (required): `json`, `yaml`, `toml`, `ini`, `env`.
- `--help` — Show usage information.

## Supported Conversions

All pairwise conversions are supported. Lossy conversions (e.g., nested JSON to flat .env) emit a warning to stderr. INI and .env formats only support flat or single-depth key-value structures; nested data is flattened using dot notation (e.g., `database.host=localhost`).

## Dependencies

- Python 3.8+ (uses only standard library for JSON/INI/env; requires `pyyaml` and `toml`/`tomli` for YAML/TOML)
- The script will check for required packages and print install instructions if missing.
