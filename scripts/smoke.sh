#!/bin/bash
# 冒烟：构建 → 单元测试 → 启动检查（状态项/快捷键/进程存活）→ 清理
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== 1/3 build =="
./scripts/build-app.sh

echo "== 2/3 unit tests =="
swift test 2>&1 | grep -E "Executed [0-9]+ tests" | tail -1

echo "== 3/3 launch smoke =="
BIN="$ROOT/.local-build/Stoic.app/Contents/MacOS/Stoic"
rm -f "$HOME/Library/Application Support/default.store"*
defaults delete com.zhizhi.stoic 2>/dev/null || true

STOIC_DEBUG_STORE=/tmp/stoic-smoke.store STOIC_DEBUG_OPEN_PANEL=1 STOIC_SKIP_RESTORE_PROMPT=1 "$BIN" >/tmp/stoic-smoke.log 2>&1 &
PID=$!
sleep 3

if ! kill -0 "$PID" 2>/dev/null; then
    echo "FAIL: app exited early"
    cat /tmp/stoic-smoke.log
    exit 1
fi

grep -q "statusItem=true" /tmp/stoic-status.log || { echo "FAIL: status item missing"; exit 1; }
grep -q "shortcuts=toggle=0 skip=0" /tmp/stoic-status.log || { echo "FAIL: shortcuts not registered"; exit 1; }
grep -q "store=true" /tmp/stoic-status.log || { echo "FAIL: store not created"; exit 1; }

kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true
rm -f "$HOME/Library/Application Support/default.store"*
defaults delete com.zhizhi.stoic 2>/dev/null || true

echo "SMOKE OK"
