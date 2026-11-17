#!/bin/bash
# 版本号规则（全局统一）：
#   - 版本为 x.y.z，每位只能是 0-9 的个位数；
#   - 每次构建 z + 1；z 满 9 后归 0 并让 y + 1；y 满 9 后归 0 并让 x + 1；
#   - 构建号取 YYYYMMDDhhmmss，由 build-app.sh 写入 CFBundleVersion；
#   - 版本的唯一来源是仓库根 VERSION 文件，不手改别处。
# 用法：scripts/bump-version.sh [--dry-run]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

CURRENT="$(tr -d '\n' < "$ROOT/VERSION")"
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

PATCH=$((PATCH + 1))
if [ "$PATCH" -gt 9 ]; then PATCH=0; MINOR=$((MINOR + 1)); fi
if [ "$MINOR" -gt 9 ]; then MINOR=0; MAJOR=$((MAJOR + 1)); fi

if [ "$MAJOR" -gt 9 ]; then
    echo "error: major would become two digits ($MAJOR.$MINOR.$PATCH); confirm with the human how to proceed" >&2
    exit 1
fi

NEW="$MAJOR.$MINOR.$PATCH"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "$CURRENT -> $NEW (dry run)"
else
    printf '%s\n' "$NEW" > "$ROOT/VERSION"
    echo "$NEW"
fi
