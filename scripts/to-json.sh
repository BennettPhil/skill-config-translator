#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: to-json.sh --from FORMAT [FILE]"
  echo "Convert a config file to JSON (canonical intermediate format)."
  echo ""
  echo "Formats: json, yaml, toml, ini, env"
  echo "Reads from stdin if no file is given."
}

FROM=""
FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --from) FROM="$2"; shift 2 ;;
    *) FILE="$1"; shift ;;
  esac
done

if [ -z "$FROM" ]; then
  echo "Error: --from FORMAT is required" >&2
  exit 1
fi

if [ -n "$FILE" ] && [ "$FILE" != "-" ]; then
  INPUT=$(cat "$FILE")
else
  INPUT=$(cat)
fi

python3 -c "
import sys, json

content = sys.stdin.read()
fmt = '$FROM'

if fmt == 'json':
    data = json.loads(content)
    print(json.dumps(data, indent=2))

elif fmt == 'yaml':
    import yaml
    data = yaml.safe_load(content)
    if data is None:
        data = {}
    print(json.dumps(data, indent=2))

elif fmt == 'toml':
    try:
        import tomllib
    except ImportError:
        import tomli as tomllib
    data = tomllib.loads(content)
    print(json.dumps(data, indent=2))

elif fmt == 'ini':
    import configparser, io
    parser = configparser.ConfigParser()
    parser.read_string(content)
    data = {}
    for section in parser.sections():
        data[section] = dict(parser[section])
    if parser.defaults():
        data['DEFAULT'] = dict(parser.defaults())
    print(json.dumps(data, indent=2))

elif fmt == 'env':
    data = {}
    for line in content.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        line = line.removeprefix('export').strip()
        if '=' in line:
            key, _, value = line.partition('=')
            key = key.strip()
            value = value.strip().strip('\"').strip(\"'\")
            data[key] = value
    print(json.dumps(data, indent=2))

else:
    print(f'Error: unsupported format: {fmt}', file=sys.stderr)
    sys.exit(1)
" <<< "$INPUT"
