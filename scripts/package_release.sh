#!/bin/bash
# Screenwriter（编剧助手）Release 打包脚本
# 用法: ./scripts/package_release.sh [version]
#
# 【安全特性】原子替换，不中断正在运行的 app：
#   1. 构建到临时 bundle，绝不直接改正在运行的 /Applications/Screenwriter.app
#   2. 若 app 正在运行，先优雅退出（osascript quit），替换完成后自动重新拉起
#   3. 原子替换（旧 bundle 先改名备份，新 bundle mv 就位），失败可回滚

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/arm64-apple-macosx/release"
APP_NAME="Screenwriter"
APP_BUNDLE="/Applications/$APP_NAME.app"
STAGE_DIR="/tmp/${APP_NAME}_stage.app"             # 构建暂存目录
BACKUP_DIR="/Applications/${APP_NAME}_backup.app"  # 原子替换前的备份

# ---------- 1. 编译 Release 版 ----------
echo "🔨 Building release..."
cd "$PROJECT_DIR"
swift build -c release

# ---------- 2. 在暂存目录构建新 bundle（不碰正在运行的 .app）----------
echo "📦 Staging new bundle at $STAGE_DIR ..."
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/Contents/MacOS"
mkdir -p "$STAGE_DIR/Contents/Resources"

cp "$BUILD_DIR/Screenwriter" "$STAGE_DIR/Contents/MacOS/"
cp "$PROJECT_DIR/Sources/Screenwriter/Info.plist" "$STAGE_DIR/Contents/"

# 复制 App 图标（.icns，若存在）
if [ -f "$PROJECT_DIR/Sources/Screenwriter/AppIcon.icns" ]; then
  cp "$PROJECT_DIR/Sources/Screenwriter/AppIcon.icns" "$STAGE_DIR/Contents/Resources/"
  echo "   ✅ Copied AppIcon.icns to Resources"
else
  echo "   ⚠️  AppIcon.icns not found, skipping icon"
fi

# 设置版本号
if [ -n "$1" ]; then
  VERSION="$1"
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$STAGE_DIR/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "$VERSION" "$STAGE_DIR/Contents/Info.plist"
fi

chmod +x "$STAGE_DIR/Contents/MacOS/Screenwriter"

# ---------- 3. 处理正在运行的 app（优雅退出，不硬杀）----------
WAS_RUNNING=0
if pgrep -f "$APP_BUNDLE/Contents/MacOS/Screenwriter" >/dev/null 2>&1; then
  WAS_RUNNING=1
  echo "🔄 App is running. Gracefully quitting before swap..."
  osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
  for i in $(seq 1 20); do
    if ! pgrep -f "$APP_BUNDLE/Contents/MacOS/Screenwriter" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
  if pgrep -f "$APP_BUNDLE/Contents/MacOS/Screenwriter" >/dev/null 2>&1; then
    echo "⚠️  App didn't quit gracefully, force quitting..."
    pkill -f "$APP_BUNDLE/Contents/MacOS/Screenwriter" || true
    sleep 1
  fi
  echo "   ✅ App quit."
fi

# ---------- 4. 原子替换（旧的可回滚）----------
echo "🔁 Swapping bundle atomically..."
if [ -d "$APP_BUNDLE" ]; then
  rm -rf "$BACKUP_DIR"
  mv "$APP_BUNDLE" "$BACKUP_DIR"
  echo "   ✅ Backed up old bundle to $BACKUP_DIR"
fi
mv "$STAGE_DIR" "$APP_BUNDLE"
echo "   ✅ New bundle in place at $APP_BUNDLE"

# ---------- 5. 若之前运行中，重新拉起 app ----------
if [ "$WAS_RUNNING" = "1" ]; then
  echo "🚀 Relaunching app..."
  open "$APP_BUNDLE"
  echo "   ✅ App relaunched."
else
  echo "ℹ️  App was not running before, not auto-launching."
fi

echo ""
echo "✅ Release deployed safely to $APP_BUNDLE"
echo "   Size: $(du -sh "$APP_BUNDLE" | cut -f1)"
echo "   Binary: $(ls -lh "$APP_BUNDLE/Contents/MacOS/Screenwriter" | awk '{print $5, $6, $7, $8}')"
echo "   Backup kept at: $BACKUP_DIR (可回滚)"
