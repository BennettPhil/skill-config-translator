---
name: config-translator
description: Convert configuration files between JSON, YAML, TOML, INI, and .env formats
version: 0.1.0
license: Apache-2.0
---

# Config Translator

## Purpose

A tool that converts configuration files between common formats: JSON, YAML, TOML, INI, and environment files (.env). It handles nested structures, arrays, and type coercion between formats, warning when a conversion is lossy (e.g., nested objects flattened to INI or .env).

## Instructions

When the user wants to convert a configuration file:

1. Run `scripts/run.sh` with the input file and desired output format.
2. The tool reads the input file, detects its format (or uses `--from` to override), and converts to the target format specified by `--to`.
3. Output is written to stdout by default, or to a file with `--output`.

## Inputs

- **Positional argument**: Path to the input configuration file. Required.
- `--from <format>`: Source format (`json`, `yaml`, `toml`, `ini`, `env`). Auto-detected from file extension if omitted.
- `--to <format>`: Target format (`json`, `yaml`, `toml`, `ini`, `env`). Required.
- `--output <path>`: Write output to a file instead of stdout. Optional.
- `--help`: Show usage information.

## Outputs

- The converted configuration content, written to stdout or the specified output file.
- Warnings printed to stderr when the conversion is lossy (e.g., nested objects cannot be represented in INI or .env format).

## Constraints

- Requires Python 3.7+ with `pyyaml` and `toml` packages.
- INI and .env formats do not support nested structures or arrays. Nested keys are flattened using dot notation with a warning.
- Comments from the source file are not preserved during conversion.
- .env format only supports string key=value pairs; type information is lost.
