#!/bin/bash
# 安装 Chrome native messaging host。参数：Chrome 扩展 ID（在 chrome://extensions 查看）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXT_ID="${1:?usage: install-native-host.sh <chrome-extension-id>}"
DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
HOST="$ROOT/tools/native-host/stoic-host.py"

mkdir -p "$DIR"
cat > "$DIR/com.zhizhi.stoic.host.json" <<JSON
{
  "name": "com.zhizhi.stoic.host",
  "description": "知止 native messaging host",
  "path": "$HOST",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXT_ID/"]
}
JSON
echo "installed: $DIR/com.zhizhi.stoic.host.json"
