#!/bin/bash
# 将 MetricKit 诊断里的调用栈偏移符号化为函数与行号。
# 用法：scripts/symbolicate.sh <diagnostics-*.json> <dSYM 或 .app>
set -euo pipefail
JSON="${1:?usage: symbolicate.sh <diagnostics.json> <dSYM-or-app>}"
BINARY="${2:?usage: symbolicate.sh <diagnostics.json> <dSYM-or-app>}"

if [ -d "$BINARY" ]; then
    BINARY="$BINARY/Contents/MacOS/Stoic"
fi

if [ ! -f "$BINARY" ]; then
    echo "cannot find executable: $BINARY" >&2
    exit 1
fi

python3 - "$JSON" "$BINARY" <<'PY'
import json, subprocess, sys

path, binary = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path, encoding='utf-8'))
except Exception as error:
    print(f"cannot parse json: {error}")
    sys.exit(1)

frames = []

def walk(node):
    if isinstance(node, dict):
        if "binaryUUID" in node or "address" in node:
            frames.append(node)
        for value in node.values():
            walk(value)
    elif isinstance(node, list):
        for item in node:
            walk(item)

walk(data)

if not frames:
    print("no stack frames found (payload may only contain CPU/memory diagnostics)")
    sys.exit(0)

for frame in frames:
    address = frame.get("address") or frame.get("offset")
    if address is None:
        continue
    addr = hex(address) if isinstance(address, int) else str(address)
    try:
        out = subprocess.run(["atos", "-o", binary, "-arch", "arm64", addr],
                             capture_output=True, text=True, check=False)
        print(f"{addr}  {out.stdout.strip() or out.stderr.strip()}")
    except FileNotFoundError:
        print("atos missing (install Xcode Command Line Tools)")
        sys.exit(1)
PY
