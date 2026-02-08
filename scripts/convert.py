#!/usr/bin/env python3
"""Configuration file format converter."""

import argparse
import json
import sys
import os
import configparser
import io
import re

def check_dependencies():
    missing = []
    try:
        import yaml  # noqa: F401
    except ImportError:
        missing.append("pyyaml")
    try:
        import tomli  # noqa: F401
    except ImportError:
        try:
            import tomllib  # noqa: F401
        except ImportError:
            missing.append("tomli")
    if missing:
        print(f"Missing dependencies: {', '.join(missing)}", file=sys.stderr)
        print(f"Install with: pip install {' '.join(missing)}", file=sys.stderr)
        sys.exit(2)

def detect_format(filename):
    ext_map = {
        ".json": "json",
        ".yaml": "yaml",
        ".yml": "yaml",
        ".toml": "toml",
        ".ini": "ini",
        ".cfg": "ini",
        ".env": "env",
    }
    if filename:
        _, ext = os.path.splitext(filename)
        fmt = ext_map.get(ext.lower())
        if fmt:
            return fmt
        base = os.path.basename(filename).lower()
        if base.startswith(".env"):
            return "env"
    return None

def parse_env(text):
    data = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        match = re.match(r'^([A-Za-z_][A-Za-z0-9_.]*)\s*=\s*(.*)', line)
        if match:
            key = match.group(1)
            val = match.group(2).strip()
            if (val.startswith('"') and val.endswith('"')) or \
               (val.startswith("'") and val.endswith("'")):
                val = val[1:-1]
            data[key] = val
    return data

def flatten(data, prefix=""):
    flat = {}
    for k, v in data.items():
        key = f"{prefix}{k}" if not prefix else f"{prefix}.{k}"
        if isinstance(v, dict):
            flat.update(flatten(v, key))
        elif isinstance(v, list):
            flat[key] = json.dumps(v)
        else:
            flat[key] = str(v) if v is not None else ""
    return flat

def unflatten(data):
    result = {}
    for key, val in data.items():
        parts = key.split(".")
        d = result
        for part in parts[:-1]:
            d = d.setdefault(part, {})
        d[parts[-1]] = val
    return result

def read_input(text, fmt):
    if fmt == "json":
        return json.loads(text)
    elif fmt == "yaml":
        import yaml
        return yaml.safe_load(text) or {}
    elif fmt == "toml":
        try:
            import tomllib
            return tomllib.loads(text)
        except ImportError:
            import tomli
            return tomli.loads(text)
    elif fmt == "ini":
        cp = configparser.ConfigParser()
        cp.read_string(text)
        data = {}
        for section in cp.sections():
            data[section] = dict(cp[section])
        if cp.defaults():
            data.update(dict(cp.defaults()))
        return data
    elif fmt == "env":
        return parse_env(text)
    else:
        print(f"Unknown input format: {fmt}", file=sys.stderr)
        sys.exit(1)

def write_output(data, fmt):
    if fmt == "json":
        return json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    elif fmt == "yaml":
        import yaml
        return yaml.dump(data, default_flow_style=False, allow_unicode=True, sort_keys=False)
    elif fmt == "toml":
        try:
            import tomli_w
            return tomli_w.dumps(data)
        except ImportError:
            # Manual TOML generation for simple structures
            lines = []
            tables = {}
            scalars = {}
            for k, v in data.items():
                if isinstance(v, dict):
                    tables[k] = v
                else:
                    scalars[k] = v
            for k, v in scalars.items():
                lines.append(f"{k} = {_toml_value(v)}")
            for table, values in tables.items():
                lines.append(f"\n[{table}]")
                for k, v in values.items():
                    lines.append(f"{k} = {_toml_value(v)}")
            return "\n".join(lines) + "\n"
    elif fmt == "ini":
        has_nested = any(isinstance(v, dict) for v in data.values())
        if not has_nested:
            data = {"DEFAULT": data}
            print("Warning: flat data wrapped in [DEFAULT] section for INI output", file=sys.stderr)
        cp = configparser.ConfigParser()
        for section, values in data.items():
            if isinstance(values, dict):
                cp[section] = {k: str(v) for k, v in values.items()}
            else:
                cp.setdefault("DEFAULT", {})[section] = str(values)
        buf = io.StringIO()
        cp.write(buf)
        return buf.getvalue()
    elif fmt == "env":
        flat = flatten(data) if any(isinstance(v, dict) for v in data.values()) else data
        if any(isinstance(v, dict) for v in data.values()):
            print("Warning: nested data flattened with dot notation for .env output", file=sys.stderr)
        lines = []
        for k, v in flat.items():
            v_str = str(v)
            if " " in v_str or "=" in v_str or '"' in v_str:
                v_str = f'"{v_str}"'
            lines.append(f"{k}={v_str}")
        return "\n".join(lines) + "\n"
    else:
        print(f"Unknown output format: {fmt}", file=sys.stderr)
        sys.exit(1)

def _toml_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    elif isinstance(v, (int, float)):
        return str(v)
    elif isinstance(v, str):
        return json.dumps(v)
    elif isinstance(v, list):
        items = ", ".join(_toml_value(i) for i in v)
        return f"[{items}]"
    else:
        return json.dumps(str(v))

def main():
    parser = argparse.ArgumentParser(description="Convert between config formats")
    parser.add_argument("--from", dest="from_fmt", help="Source format")
    parser.add_argument("--to", dest="to_fmt", required=True, help="Target format")
    parser.add_argument("file", nargs="?", help="Input file (reads stdin if omitted)")
    args = parser.parse_args()

    check_dependencies()

    if args.file:
        with open(args.file) as f:
            text = f.read()
        from_fmt = args.from_fmt or detect_format(args.file)
    else:
        text = sys.stdin.read()
        from_fmt = args.from_fmt

    if not from_fmt:
        print("Error: cannot detect format; use --from to specify", file=sys.stderr)
        sys.exit(1)

    data = read_input(text, from_fmt)
    output = write_output(data, args.to_fmt)
    sys.stdout.write(output)

if __name__ == "__main__":
    main()
