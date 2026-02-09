#!/usr/bin/env bash
set -euo pipefail

WARN="${CONFIG_TRANSLATOR_WARN:-1}"
STRICT="${CONFIG_TRANSLATOR_STRICT:-0}"

usage() {
  echo "Usage: from-json.sh --to FORMAT [FILE]"
  echo "Convert JSON to a target config format."
  echo ""
  echo "Formats: json, yaml, toml, ini, env"
  echo "Reads from stdin if no file is given."
}

TO=""
FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --to) TO="$2"; shift 2 ;;
    *) FILE="$1"; shift ;;
  esac
done

if [ -z "$TO" ]; then
  echo "Error: --to FORMAT is required" >&2
  exit 1
fi

if [ -n "$FILE" ] && [ "$FILE" != "-" ]; then
  INPUT=$(cat "$FILE")
else
  INPUT=$(cat)
fi

python3 -c "
import sys, json, os

content = sys.stdin.read()
fmt = '$TO'
warn = $WARN
strict = $STRICT

data = json.loads(content)

def flatten(d, prefix=''):
    items = {}
    for k, v in d.items():
        key = f'{prefix}{k}' if not prefix else f'{prefix}.{k}'
        if isinstance(v, dict):
            items.update(flatten(v, key))
        elif isinstance(v, list):
            items[key] = json.dumps(v)
            if warn:
                print(f'Warning: array value at \"{key}\" serialized as JSON string', file=sys.stderr)
        else:
            items[key] = str(v) if v is not None else ''
    return items

if fmt == 'json':
    print(json.dumps(data, indent=2))

elif fmt == 'yaml':
    import yaml
    print(yaml.dump(data, default_flow_style=False, sort_keys=False).rstrip())

elif fmt == 'toml':
    try:
        import tomli_w
        print(tomli_w.dumps(data).rstrip())
    except ImportError:
        # Manual TOML output for simple cases
        def to_toml(d, prefix=''):
            lines = []
            tables = []
            for k, v in d.items():
                if isinstance(v, dict):
                    tables.append((k, v))
                elif isinstance(v, bool):
                    lines.append(f'{k} = {str(v).lower()}')
                elif isinstance(v, (int, float)):
                    lines.append(f'{k} = {v}')
                elif isinstance(v, list):
                    items = ', '.join(json.dumps(i) for i in v)
                    lines.append(f'{k} = [{items}]')
                else:
                    lines.append(f'{k} = {json.dumps(str(v))}')
            for table_name, table_data in tables:
                full_name = f'{prefix}.{table_name}' if prefix else table_name
                lines.append(f'')
                lines.append(f'[{full_name}]')
                lines.extend(to_toml(table_data, full_name).split('\n'))
            return '\n'.join(l for l in lines if l is not None)
        print(to_toml(data).strip())

elif fmt == 'ini':
    import configparser, io
    if warn and any(isinstance(v, dict) and any(isinstance(vv, dict) for vv in v.values()) for v in data.values() if isinstance(v, dict)):
        print('Warning: nested structures deeper than 2 levels will be flattened for INI format', file=sys.stderr)
        if strict:
            print('Error: lossy conversion rejected (strict mode)', file=sys.stderr)
            sys.exit(1)
    parser = configparser.ConfigParser()
    for key, value in data.items():
        if isinstance(value, dict):
            parser[key] = {}
            for k, v in value.items():
                if isinstance(v, dict):
                    for kk, vv in flatten(v, k).items():
                        parser[key][kk] = str(vv)
                else:
                    parser[key][k] = str(v)
        else:
            if 'DEFAULT' not in parser:
                parser['general'] = {}
            parser['general'][key] = str(value)
    out = io.StringIO()
    parser.write(out)
    print(out.getvalue().rstrip())

elif fmt == 'env':
    if warn and any(isinstance(v, dict) for v in data.values()):
        print('Warning: nested structures will be flattened with dot-notation for .env format', file=sys.stderr)
        if strict:
            print('Error: lossy conversion rejected (strict mode)', file=sys.stderr)
            sys.exit(1)
    flat = flatten(data) if any(isinstance(v, dict) for v in data.values()) else {k: str(v) if v is not None else '' for k, v in data.items()}
    for k, v in flat.items():
        key = k.upper().replace('.', '_').replace('-', '_')
        if ' ' in str(v) or '\"' in str(v) or not v:
            print(f'{key}=\"{v}\"')
        else:
            print(f'{key}={v}')

else:
    print(f'Error: unsupported format: {fmt}', file=sys.stderr)
    sys.exit(1)
" <<< "$INPUT"
