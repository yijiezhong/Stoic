#!/usr/bin/env python3
"""知止 native messaging host：读取主应用写的状态文件，返回聚焦状态与屏蔽站点。"""
import json
import os
import struct
import sys

STATE_PATH = os.path.expanduser("~/Library/Application Support/StoicState.json")


def read_message():
    raw = sys.stdin.buffer.read(4)
    if len(raw) < 4:
        return None
    (length,) = struct.unpack("<I", raw)
    payload = sys.stdin.buffer.read(length)
    try:
        return json.loads(payload.decode("utf-8"))
    except Exception:
        return None


def send_message(obj):
    data = json.dumps(obj).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("<I", len(data)))
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()


def load_state():
    if not os.path.exists(STATE_PATH):
        return {}
    try:
        with open(STATE_PATH, encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return {}


def main():
    read_message()
    state = load_state()
    send_message({
        "focusing": bool(state.get("focusing", False)),
        "remaining": state.get("remaining", ""),
        "blockedHosts": state.get("blockedHosts", []),
        "available": bool(state),
    })


if __name__ == "__main__":
    main()
