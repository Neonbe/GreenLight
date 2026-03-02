#!/bin/bash
# GreenLight — 构建并运行 .app Bundle
# 用法: ./run.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/arm64-apple-macosx/debug"
APP_BUNDLE="$PROJECT_DIR/.build/GreenLight.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"

echo "🚦 GreenLight — 构建中..."

# Step 1: 构建
cd "$PROJECT_DIR"
swift build 2>&1

echo "📦 打包 .app Bundle..."

# Step 2: 创建 .app Bundle 结构
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"

# Step 3: 复制二进制
cp "$BUILD_DIR/GreenLight" "$MACOS/GreenLight"

# Step 4: 复制 Info.plist
cp "$PROJECT_DIR/GreenLight/Info.plist" "$CONTENTS/Info.plist"

# Step 5: 复制 Resources（App 图标等）
mkdir -p "$CONTENTS/Resources"
if [ -f "$PROJECT_DIR/GreenLight/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/GreenLight/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi

# Step 6: 杀死旧进程（如果有）
pkill -f "GreenLight.app" 2>/dev/null || true
sleep 0.5

# Step 7: 清除 UserDefaults（重置 Onboarding 等状态）
defaults delete com.greenlight.app 2>/dev/null || true

echo "🚀 启动 GreenLight..."
echo "   📍 请查看屏幕右上角菜单栏 — 你会看到一个绿色圆点 🟢"
echo "   （这是一个 Menu Bar App，没有主窗口）"
echo ""

# Step 6: 启动
open "$APP_BUNDLE"

echo "✅ GreenLight 已启动！"
echo "   点击菜单栏的 🟢 图标即可看到主面板"
echo "   按 Ctrl+C 不会关闭 App（它在后台运行）"
echo "   要关闭: pkill -f 'GreenLight.app'"
