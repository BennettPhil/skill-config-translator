#!/usr/bin/env python3
"""Convert configuration files between JSON, YAML, TOML, INI, and .env formats."""

import argparse
import configparser
import json
import os
import sys
from io import StringIO

try:
    import yaml
except ImportError:
    yaml = None

try:
    import toml
except ImportError:
    toml = None


EXTENSION_MAP = {
    ".json": "json",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".toml": "toml",
    ".ini": "ini",
    ".cfg": "ini",
    ".env": "env",
}


def detect_format(filepath):
    """Detect format from file extension."""
    _, ext = os.path.splitext(filepath)
    ext = ext.lower()
    return EXTENSION_MAP.get(ext, "")


def parse_env(content):
    """Parse .env file content into a dict."""
    result = {}
    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        # Remove surrounding quotes
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
            value = value[1:-1]
        result[key] = value
    return result


def read_input(filepath, fmt):
    """Read and parse input file."""
    with open(filepath, "r") as f:
        content = f.read()

    if fmt == "json":
        return json.loads(content)
    elif fmt == "yaml":
        if yaml is None:
            print("Error: pyyaml is required for YAML support. Install with: pip install pyyaml", file=sys.stderr)
            sys.exit(1)
        return yaml.safe_load(content) or {}
    elif fmt == "toml":
        if toml is None:
            print("Error: toml is required for TOML support. Install with: pip install toml", file=sys.stderr)
            sys.exit(1)
        return toml.loads(content)
    elif fmt == "ini":
        parser = configparser.ConfigParser()
        parser.read_string(content)
        result = {}
        for section in parser.sections():
            result[section] = dict(parser.items(section))
        # Include DEFAULT section items if any
        if parser.defaults():
            for key, value in parser.defaults().items():
                if key not in result:
                    result[key] = value
        return result
    elif fmt == "env":
        return parse_env(content)
    else:
        print(f"Error: Unsupported input format: {fmt}", file=sys.stderr)
        sys.exit(1)


def flatten(data, prefix="", sep="."):
    """Flatten nested dict into dot-notation keys."""
    items = {}
    if isinstance(data, dict):
        for key, value in data.items():
            new_key = f"{prefix}{sep}{key}" if prefix else key
            if isinstance(value, dict):
                items.update(flatten(value, new_key, sep))
            elif isinstance(value, list):
                items[new_key] = json.dumps(value)
            else:
                items[new_key] = value
    return items


def warn_lossy(target_fmt, data):
    """Warn about lossy conversions."""
    has_nested = False
    has_arrays = False

    def check(obj, depth=0):
        nonlocal has_nested, has_arrays
        if isinstance(obj, dict):
            for v in obj.values():
                if isinstance(v, dict):
                    has_nested = True
                elif isinstance(v, list):
                    has_arrays = True
                check(v, depth + 1)
        elif isinstance(obj, list):
            has_arrays = True
            for item in obj:
                check(item, depth + 1)

    check(data)

    if target_fmt in ("ini", "env"):
        if has_nested:
            print(f"Warning: Nested structures will be flattened to dot-notation for {target_fmt.upper()} format.", file=sys.stderr)
        if has_arrays:
            print(f"Warning: Arrays will be serialized as JSON strings in {target_fmt.upper()} format.", file=sys.stderr)

    if target_fmt == "env":
        print("Warning: All values will be converted to strings in .env format. Type information is lost.", file=sys.stderr)


def write_output(data, fmt):
    """Convert data to target format and return as string."""
    if fmt == "json":
        return json.dumps(data, indent=2, default=str) + "\n"
    elif fmt == "yaml":
        if yaml is None:
            print("Error: pyyaml is required for YAML support. Install with: pip install pyyaml", file=sys.stderr)
            sys.exit(1)
        return yaml.dump(data, default_flow_style=False, sort_keys=False, allow_unicode=True)
    elif fmt == "toml":
        if toml is None:
            print("Error: toml is required for TOML support. Install with: pip install toml", file=sys.stderr)
            sys.exit(1)
        return toml.dumps(data)
    elif fmt == "ini":
        flat = {}
        sections = {}
        for key, value in data.items():
            if isinstance(value, dict):
                sections[key] = flatten(value)
            else:
                if "DEFAULT" not in sections:
                    sections["DEFAULT"] = {}
                sections["DEFAULT"][key] = str(value)

        if not sections:
            sections["DEFAULT"] = flatten(data)

        parser = configparser.ConfigParser()
        for section, items in sections.items():
            if section == "DEFAULT":
                for k, v in items.items():
                    parser.defaults()[k] = str(v)
            else:
                parser.add_section(section)
                for k, v in items.items():
                    parser.set(section, k, str(v))

        output = StringIO()
        parser.write(output)
        return output.getvalue()
    elif fmt == "env":
        flat = flatten(data)
        lines = []
        for key, value in flat.items():
            # Convert key to ENV_STYLE
            env_key = key.upper().replace(".", "_").replace("-", "_")
            str_value = str(value)
            # Quote if value contains spaces or special characters
            if " " in str_value or "=" in str_value or '"' in str_value:
                str_value = '"' + str_value.replace('"', '\\"') + '"'
            lines.append(f"{env_key}={str_value}")
        return "\n".join(lines) + "\n"
    else:
        print(f"Error: Unsupported output format: {fmt}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Convert between config formats")
    parser.add_argument("input", help="Input file path")
    parser.add_argument("--from", dest="from_fmt", default="", help="Source format")
    parser.add_argument("--to", dest="to_fmt", required=True, help="Target format")
    parser.add_argument("--output", default="", help="Output file path")
    args = parser.parse_args()

    # Detect or validate source format
    from_fmt = args.from_fmt or detect_format(args.input)
    if not from_fmt:
        print("Error: Cannot detect input format. Use --from to specify.", file=sys.stderr)
        sys.exit(1)

    to_fmt = args.to_fmt
    valid_formats = {"json", "yaml", "toml", "ini", "env"}
    if from_fmt not in valid_formats:
        print(f"Error: Unsupported source format: {from_fmt}", file=sys.stderr)
        sys.exit(1)
    if to_fmt not in valid_formats:
        print(f"Error: Unsupported target format: {to_fmt}", file=sys.stderr)
        sys.exit(1)

    # Read input
    data = read_input(args.input, from_fmt)

    # Warn about lossy conversions
    warn_lossy(to_fmt, data)

    # Convert and output
    result = write_output(data, to_fmt)

    if args.output:
        with open(args.output, "w") as f:
            f.write(result)
    else:
        sys.stdout.write(result)


if __name__ == "__main__":
    main()
