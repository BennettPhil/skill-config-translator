# config-translator

Convert configuration files between JSON, YAML, TOML, INI, and .env formats.

## Quick Start

```bash
# JSON to YAML
./scripts/run.sh config.json --to yaml

# YAML to TOML
./scripts/run.sh settings.yaml --to toml --output settings.toml

# JSON to .env
./scripts/run.sh config.json --to env
```

## Prerequisites

- Python 3.7+
- `pip install pyyaml toml`
