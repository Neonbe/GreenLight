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

# Step 5.1: 编译 .xcstrings → .lproj/*.strings（SPM swift build 不做此步骤）
echo "🌐 编译本地化资源..."
python3 "$PROJECT_DIR/scripts/compile_xcstrings.py" \
    "$CONTENTS/Resources" \
    "$PROJECT_DIR/GreenLight/Resources/Localizable.xcstrings" \
    "$PROJECT_DIR/GreenLight/Resources/InfoPlist.xcstrings"

# Step 5.2: 拷贝 SPM 资源 bundle（包含未编译资源的备用）
RESOURCE_BUNDLE="$BUILD_DIR/GreenLight_GreenLight.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$CONTENTS/Resources/"
fi

# Step 5.5: 嵌入 Sparkle.framework（自动更新）
SPARKLE_FRAMEWORK=""
# SPM artifacts 下的 Sparkle.xcframework
SPARKLE_XCFW=$(find "$PROJECT_DIR/.build/artifacts" -name "Sparkle.xcframework" -type d 2>/dev/null | head -1)
if [ -n "$SPARKLE_XCFW" ]; then
    SPARKLE_FRAMEWORK="$SPARKLE_XCFW/macos-arm64_x86_64/Sparkle.framework"
fi

if [ -d "$SPARKLE_FRAMEWORK" ]; then
    echo "🔄 嵌入 Sparkle.framework..."
    mkdir -p "$CONTENTS/Frameworks"
    cp -R "$SPARKLE_FRAMEWORK" "$CONTENTS/Frameworks/"
    # 修正 rpath，确保运行时能找到动态库
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS/GreenLight" 2>/dev/null || true
else
    echo "⚠️ 未找到 Sparkle.framework，跳过嵌入（自动更新功能不可用）"
fi

# Step 5.6: 重新签名（嵌入 framework 后签名失效，必须重签）
codesign --force --deep --sign - "$APP_BUNDLE"

# Step 6: 杀死旧进程（如果有）
pkill -f "GreenLight.app" 2>/dev/null || true
sleep 0.5

# Step 7: 清除 UserDefaults（重置 Onboarding 等状态）
defaults delete com.greenlight.app 2>/dev/null || true

echo "🚀 启动 GreenLight..."
echo ""

# Step 6: 启动
open "$APP_BUNDLE"

echo "✅ GreenLight 已启动！"
echo "   按 Ctrl+C 退出日志监听（App 仍在后台运行）"
echo "   要关闭 App: pkill -f 'GreenLight.app'"
echo ""
echo "📋 开始监听日志..."
echo ""

# Step 8: 自动监听应用日志
log stream --predicate 'subsystem == "com.greenlight.app"' --style compact --level debug
