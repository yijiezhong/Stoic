#!/bin/bash
# 构建知止 Stoic.app（Xcode 工程 + XcodeGen）。
# 版本号按全局规则自动进位（scripts/bump-version.sh），构建号取秒级时间戳。
# 只想看下一个版本号：scripts/bump-version.sh --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# 版本按全局规则进位（每次构建 z + 1）
VERSION="$(./scripts/bump-version.sh)"
BUILD="$(date +%Y%m%d%H%M%S)"
APP="$ROOT/.local-build/Stoic.app"

mkdir -p "$ROOT/.local-build" "$ROOT/.dist"

xcodegen generate >/dev/null

xcodebuild \
    -project "$ROOT/Stoic.xcodeproj" \
    -scheme Stoic \
    -configuration Release \
    -derivedDataPath "$ROOT/.local-build/DerivedData" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    build -quiet

rm -rf "$APP"
cp -R "$ROOT/.local-build/DerivedData/Build/Products/Release/Stoic.app" "$APP"

echo "built: $APP ($VERSION/$BUILD)"

# 默认安装到 /Applications；SKIP_INSTALL=1 可跳过
if [ "${SKIP_INSTALL:-0}" != "1" ]; then
    DEST="/Applications/Stoic.app"
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    echo "installed: $DEST"
fi
