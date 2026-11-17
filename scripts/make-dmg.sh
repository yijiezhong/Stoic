#!/bin/bash
# 打包 DMG。设置了 DEVELOPER_ID 时签名；同时设置 NOTARY_PROFILE 时尝试公证并装订。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '\n' < "$ROOT/VERSION")"
APP="$ROOT/.local-build/Stoic.app"
OUT="$ROOT/.dist/Stoic-$VERSION.dmg"

cd "$ROOT"
SKIP_INSTALL=1 ./scripts/build-app.sh

if [ -n "${DEVELOPER_ID:-}" ]; then
    echo "== signing with $DEVELOPER_ID =="
    codesign --force --options runtime --deep --sign "$DEVELOPER_ID" "$APP"
    codesign --verify --strict --verbose=2 "$APP"

    if [ -n "${NOTARY_PROFILE:-}" ]; then
        echo "== notarizing =="
        mkdir -p "$ROOT/.dist"
        ditto -c -k --keepParent "$APP" "$ROOT/.dist/Stoic.zip"
        xcrun notarytool submit "$ROOT/.dist/Stoic.zip" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$APP"
        rm -f "$ROOT/.dist/Stoic.zip"
    fi
else
    echo "== 未设置 DEVELOPER_ID：生成未签名 DMG（仅本地验证）=="
fi

STAGE=$(mktemp -d /tmp/stoic-dmg.XXXXXX)
rm -rf "$OUT"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "知止 Stoic" -srcfolder "$STAGE" -ov -format UDZO "$OUT"
rm -rf "$STAGE"

echo "built: $OUT"
