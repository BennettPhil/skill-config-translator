#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: run.sh [INPUT_FILE] --to FORMAT [OPTIONS]

Converts between config formats: json, yaml, toml, ini, env

Options:
  --from FMT       Input format (auto-detected from file extension if omitted)
  --to FMT         Output format (required): json, yaml, toml, ini, env
  --output FILE    Write to file instead of stdout
  --flatten SEP    Separator for flattening nested keys (default: _)
  --help           Show this help message

Formats: json, yaml, toml, ini, env
EOF
  exit 0
}

FROM_FMT=""
TO_FMT=""
INPUT_FILE=""
OUTPUT_FILE=""
FLATTEN_SEP="_"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) usage ;;
    --from) FROM_FMT="$2"; shift 2 ;;
    --to) TO_FMT="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --flatten) FLATTEN_SEP="$2"; shift 2 ;;
    -*)
      echo "Error: Unknown option '$1'" >&2
      exit 1
      ;;
    *)
      INPUT_FILE="$1"
      shift
      ;;
  esac
done

if [[ -z "$TO_FMT" ]]; then
  echo "Error: --to is required. Use --help for usage." >&2
  exit 1
fi

# Auto-detect format from file extension
if [[ -n "$INPUT_FILE" && -z "$FROM_FMT" ]]; then
  case "$INPUT_FILE" in
    *.json) FROM_FMT="json" ;;
    *.yaml|*.yml) FROM_FMT="yaml" ;;
    *.toml) FROM_FMT="toml" ;;
    *.ini|*.cfg) FROM_FMT="ini" ;;
    *.env) FROM_FMT="env" ;;
    *) echo "Error: Cannot detect format from '$INPUT_FILE'. Use --from." >&2; exit 1 ;;
  esac
fi

if [[ -z "$INPUT_FILE" && -z "$FROM_FMT" ]]; then
  echo "Error: --from is required when reading from stdin" >&2
  exit 1
fi

# Read input
if [[ -n "$INPUT_FILE" ]]; then
  if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: File not found: $INPUT_FILE" >&2
    exit 1
  fi
  INPUT=$(cat "$INPUT_FILE")
else
  INPUT=$(cat)
fi

# The actual conversion is done in Python for robust parsing
RESULT=$(python3 -c "
import sys, json, os

input_data = sys.stdin.read()
from_fmt = '$FROM_FMT'
to_fmt = '$TO_FMT'
flatten_sep = '$FLATTEN_SEP'

def parse_env(text):
    result = {}
    for line in text.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if '=' in line:
            key, _, val = line.partition('=')
            key = key.strip()
            val = val.strip()
            if val and val[0] in ('\"', \"'\") and val[-1] == val[0]:
                val = val[1:-1]
            result[key] = val
    return result

def parse_ini(text):
    result = {}
    section = None
    for line in text.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith(('#', ';')):
            continue
        if line.startswith('[') and line.endswith(']'):
            section = line[1:-1]
            result[section] = {}
        elif '=' in line:
            key, _, val = line.partition('=')
            key = key.strip()
            val = val.strip()
            if section:
                result[section][key] = val
            else:
                result[key] = val
    return result

def parse_toml_simple(text):
    result = {}
    section = None
    for line in text.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('[') and line.endswith(']'):
            section = line[1:-1]
            result[section] = {}
        elif '=' in line:
            key, _, val = line.partition('=')
            key = key.strip()
            val = val.strip()
            # Type coercion
            if val.startswith('\"') and val.endswith('\"'):
                val = val[1:-1]
            elif val == 'true':
                val = True
            elif val == 'false':
                val = False
            else:
                try:
                    val = int(val)
                except ValueError:
                    try:
                        val = float(val)
                    except ValueError:
                        pass
            if section:
                result[section][key] = val
            else:
                result[key] = val
    return result

def flatten(d, parent_key='', sep='_'):
    items = []
    for k, v in d.items():
        new_key = f'{parent_key}{sep}{k}' if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten(v, new_key, sep).items())
        else:
            items.append((new_key, v))
    return dict(items)

def to_env(data, sep):
    flat = flatten(data, sep=sep)
    warned = any(isinstance(v, dict) for v in data.values())
    if warned:
        print('# Warning: Nested structures flattened with underscore separator', file=sys.stderr)
    lines = []
    for k, v in flat.items():
        lines.append(f'{k}={v}')
    return '\n'.join(lines)

def to_ini(data):
    lines = []
    top_level = {}
    sections = {}
    for k, v in data.items():
        if isinstance(v, dict):
            sections[k] = v
        else:
            top_level[k] = v
    for k, v in top_level.items():
        lines.append(f'{k} = {v}')
    for section, vals in sections.items():
        lines.append(f'[{section}]')
        for k, v in vals.items():
            if isinstance(v, dict):
                print(f'# Warning: Cannot represent nested section {section}.{k} in INI', file=sys.stderr)
            else:
                lines.append(f'{k} = {v}')
    return '\n'.join(lines)

def to_toml(data):
    lines = []
    top_level = {}
    sections = {}
    for k, v in data.items():
        if isinstance(v, dict):
            sections[k] = v
        else:
            top_level[k] = v
    for k, v in top_level.items():
        if isinstance(v, str):
            lines.append(f'{k} = \"{v}\"')
        elif isinstance(v, bool):
            lines.append(f'{k} = {str(v).lower()}')
        else:
            lines.append(f'{k} = {v}')
    for section, vals in sections.items():
        lines.append(f'[{section}]')
        for k, v in vals.items():
            if isinstance(v, str):
                lines.append(f'{k} = \"{v}\"')
            elif isinstance(v, bool):
                lines.append(f'{k} = {str(v).lower()}')
            else:
                lines.append(f'{k} = {v}')
    return '\n'.join(lines)

def to_yaml(data, indent=0):
    lines = []
    prefix = '  ' * indent
    for k, v in data.items():
        if isinstance(v, dict):
            lines.append(f'{prefix}{k}:')
            lines.append(to_yaml(v, indent + 1))
        elif isinstance(v, list):
            lines.append(f'{prefix}{k}:')
            for item in v:
                lines.append(f'{prefix}  - {item}')
        elif isinstance(v, bool):
            lines.append(f'{prefix}{k}: {str(v).lower()}')
        else:
            lines.append(f'{prefix}{k}: {v}')
    return '\n'.join(lines)

# Parse input
try:
    if from_fmt == 'json':
        data = json.loads(input_data)
    elif from_fmt == 'yaml':
        # Simple YAML parser for common cases
        data = {}
        stack = [(data, -1)]
        for line in input_data.strip().split('\n'):
            stripped = line.lstrip()
            if not stripped or stripped.startswith('#'):
                continue
            indent = len(line) - len(stripped)
            if ':' in stripped:
                key, _, val = stripped.partition(':')
                key = key.strip()
                val = val.strip()
                while len(stack) > 1 and stack[-1][1] >= indent:
                    stack.pop()
                if val:
                    # Try type coercion
                    if val == 'true': val = True
                    elif val == 'false': val = False
                    else:
                        try: val = int(val)
                        except ValueError:
                            try: val = float(val)
                            except ValueError: pass
                    stack[-1][0][key] = val
                else:
                    new_dict = {}
                    stack[-1][0][key] = new_dict
                    stack.append((new_dict, indent))
    elif from_fmt == 'toml':
        data = parse_toml_simple(input_data)
    elif from_fmt == 'ini':
        data = parse_ini(input_data)
    elif from_fmt == 'env':
        data = parse_env(input_data)
    else:
        print(f'Error: Unknown input format: {from_fmt}', file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f'Error: Failed to parse input as {from_fmt}: {e}', file=sys.stderr)
    sys.exit(2)

# Convert output
try:
    if to_fmt == 'json':
        print(json.dumps(data, indent=2))
    elif to_fmt == 'yaml':
        print(to_yaml(data))
    elif to_fmt == 'toml':
        print(to_toml(data))
    elif to_fmt == 'ini':
        print(to_ini(data))
    elif to_fmt == 'env':
        print(to_env(data, flatten_sep))
    else:
        print(f'Error: Unknown output format: {to_fmt}', file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f'Error: Conversion failed: {e}', file=sys.stderr)
    sys.exit(3)
" <<< "$INPUT")

if [[ -n "$OUTPUT_FILE" ]]; then
  echo "$RESULT" > "$OUTPUT_FILE"
  echo "Written to $OUTPUT_FILE" >&2
else
  echo "$RESULT"
fi
