#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: detect.sh [FILE]"
  echo "Auto-detect the format of a configuration file."
  echo "Reads from stdin if no file is given."
  echo "Outputs one of: json, yaml, toml, ini, env, unknown"
}

if [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ $# -ge 1 ] && [ "$1" != "-" ]; then
  INPUT=$(cat "$1")
else
  INPUT=$(cat)
fi

echo "$INPUT" | python3 -c "
import sys, json

content = sys.stdin.read().strip()
if not content:
    print('unknown')
    sys.exit(0)

# Try JSON
try:
    json.loads(content)
    print('json')
    sys.exit(0)
except Exception:
    pass

lines = content.split('\n')
has_brackets = any(l.strip().startswith('[') and l.strip().endswith(']') and '=' not in l.split('[')[0] for l in lines)
has_equals = any('=' in l and not l.strip().startswith('#') and not l.strip().startswith(';') for l in lines)
has_colon_space = any(': ' in l or l.endswith(':') for l in lines if not l.strip().startswith('#'))
has_yaml_doc = content.startswith('---')
has_yaml_list = any(l.strip().startswith('- ') for l in lines)

# .env format: KEY=VALUE with optional export prefix
env_lines = [l for l in lines if l.strip() and not l.strip().startswith('#')]
is_env = all(
    ('=' in l and l.split('=')[0].strip().replace('export ', '').replace('export\t', '').replace(' ', '_').isidentifier())
    for l in env_lines
) if env_lines else False

if is_env and not has_brackets:
    print('env')
elif has_brackets and has_equals and not has_colon_space:
    has_toml_array = any('[[' in l for l in lines)
    has_toml_inline = any('{' in l and '}' in l and '=' in l for l in lines)
    if has_toml_array or has_toml_inline:
        print('toml')
    else:
        print('ini')
elif has_yaml_doc or (has_colon_space and not has_equals) or has_yaml_list:
    print('yaml')
elif has_colon_space and has_equals:
    if has_yaml_doc or has_yaml_list:
        print('yaml')
    else:
        print('toml')
else:
    print('unknown')
"
