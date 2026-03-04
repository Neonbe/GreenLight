#!/bin/bash
# release.sh — GreenLight 一键发版（签名 + 公证 + DMG + Sparkle appcast）
# 用法: ./release.sh <version> <build>
# 例: ./release.sh 1.0.0 1
set -e

VERSION="$1"
BUILD="$2"
IDENTITY="Developer ID Application: liangze Niu (9ZTK564Y9L)"
NOTARY_PROFILE="GreenLight-Notary"

if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
    echo "❌ 用法: ./release.sh <version> <build>"
    echo "   例: ./release.sh 1.1.0 2"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPARKLE_BIN="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/bin"
RELEASE_DIR="$PROJECT_DIR/.build/release"
ENTITLEMENTS="$PROJECT_DIR/GreenLight/GreenLight.entitlements"

echo ""
echo "🚦 GreenLight v${VERSION} (build ${BUILD}) — 开始发版"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ========== Step 1: 更新版本号 ==========
echo ""
echo "📝 Step 1/12: 更新版本号..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PROJECT_DIR/GreenLight/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PROJECT_DIR/GreenLight/Info.plist"
echo "   → CFBundleShortVersionString = $VERSION"
echo "   → CFBundleVersion = $BUILD"

# ========== Step 2: Release 构建 ==========
echo ""
echo "🔨 Step 2/12: Release 构建..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

# ========== Step 3: 组装 .app Bundle ==========
echo ""
echo "📦 Step 3/12: 组装 .app Bundle..."
APP_BUNDLE="$RELEASE_DIR/GreenLight.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$CONTENTS/Resources" "$CONTENTS/Frameworks"

# 二进制
cp "$PROJECT_DIR/.build/arm64-apple-macosx/release/GreenLight" "$MACOS/GreenLight"

# Info.plist
cp "$PROJECT_DIR/GreenLight/Info.plist" "$CONTENTS/Info.plist"

# App 图标
if [ -f "$PROJECT_DIR/GreenLight/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/GreenLight/Resources/AppIcon.icns" "$CONTENTS/Resources/"
fi

# 本地化
echo "   🌐 编译本地化资源..."
python3 "$PROJECT_DIR/scripts/compile_xcstrings.py" \
    "$CONTENTS/Resources" \
    "$PROJECT_DIR/GreenLight/Resources/Localizable.xcstrings" \
    "$PROJECT_DIR/GreenLight/Resources/InfoPlist.xcstrings"

# SPM 资源 bundle
RESOURCE_BUNDLE="$PROJECT_DIR/.build/arm64-apple-macosx/release/GreenLight_GreenLight.bundle"
[ -d "$RESOURCE_BUNDLE" ] && cp -R "$RESOURCE_BUNDLE" "$CONTENTS/Resources/"

# Sparkle.framework
SPARKLE_XCFW=$(find "$PROJECT_DIR/.build/artifacts" -name "Sparkle.xcframework" -type d 2>/dev/null | head -1)
if [ -n "$SPARKLE_XCFW" ]; then
    SPARKLE_FW="$SPARKLE_XCFW/macos-arm64_x86_64/Sparkle.framework"
    if [ -d "$SPARKLE_FW" ]; then
        echo "   🔄 嵌入 Sparkle.framework..."
        cp -R "$SPARKLE_FW" "$CONTENTS/Frameworks/"
        install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS/GreenLight" 2>/dev/null || true
    fi
fi

echo "   ✅ .app Bundle 组装完成"

# ========== Step 4: 代码签名 ==========
echo ""
echo "🔏 Step 4/12: 代码签名 (Developer ID)..."

# 4a. 签 Sparkle.framework 内部组件（由内到外）
if [ -d "$CONTENTS/Frameworks/Sparkle.framework" ]; then
    echo "   → 签名 Sparkle.framework 内部组件..."
    
    # 查找并签名所有 XPC 服务
    find "$CONTENTS/Frameworks/Sparkle.framework" -name "*.xpc" -type d | while read xpc; do
        codesign --force --options runtime --timestamp --sign "$IDENTITY" "$xpc" 2>/dev/null || true
    done
    
    # 签名 Autoupdate
    [ -f "$CONTENTS/Frameworks/Sparkle.framework/Versions/B/Autoupdate" ] && \
        codesign --force --options runtime --timestamp --sign "$IDENTITY" \
        "$CONTENTS/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
    
    # 签名 Updater.app
    [ -d "$CONTENTS/Frameworks/Sparkle.framework/Versions/B/Updater.app" ] && \
        codesign --force --options runtime --timestamp --sign "$IDENTITY" \
        "$CONTENTS/Frameworks/Sparkle.framework/Versions/B/Updater.app"
    
    # 签名 Sparkle.framework 整体
    codesign --force --options runtime --timestamp --sign "$IDENTITY" \
        "$CONTENTS/Frameworks/Sparkle.framework"
    echo "   ✅ Sparkle.framework 签名完成"
fi

# 4b. 签名主 App
echo "   → 签名 GreenLight.app..."
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" \
    "$APP_BUNDLE"

# 验证
echo "   → 验证签名..."
codesign -dvvv "$APP_BUNDLE" 2>&1 | grep -E "Authority|Signature"
echo "   ✅ 代码签名完成"

# ========== Step 5: 公证 ==========
echo ""
echo "📤 Step 5/12: 提交公证 (Apple Notarization)..."
echo "   ⏳ 通常需要 2~10 分钟，请耐心等待..."
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" /tmp/GreenLight-notarize.zip
xcrun notarytool submit /tmp/GreenLight-notarize.zip \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
rm -f /tmp/GreenLight-notarize.zip

# ========== Step 6: 钉合 ==========
echo ""
echo "📌 Step 6/12: 钉合 (Staple)..."
xcrun stapler staple "$APP_BUNDLE"

# 验证公证
echo "   → 验证公证..."
spctl --assess --type exec --verbose "$APP_BUNDLE" 2>&1 || true
echo "   ✅ 公证 + 钉合完成"

# ========== Step 7: 打 ZIP（Sparkle 更新包） ==========
echo ""
echo "📦 Step 7/12: 打 Sparkle ZIP..."
cd "$RELEASE_DIR"
ZIP_NAME="GreenLight_${VERSION}.zip"
rm -f "$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent GreenLight.app "$ZIP_NAME"
ZIP_SIZE=$(stat -f%z "$ZIP_NAME")
echo "   → $ZIP_NAME ($ZIP_SIZE bytes)"

# ========== Step 8: 打 DMG ==========
echo ""
echo "💿 Step 8/12: 打 DMG..."
DMG_NAME="GreenLight_${VERSION}.dmg"
rm -f "$DMG_NAME"
create-dmg \
    --volname "GreenLight ${VERSION}" \
    --volicon "$PROJECT_DIR/GreenLight/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 128 \
    --icon "GreenLight.app" 180 170 \
    --app-drop-link 480 170 \
    --hide-extension "GreenLight.app" \
    --no-internet-enable \
    "$DMG_NAME" \
    "$APP_BUNDLE" || true  # create-dmg 有时返回非零但 DMG 已生成

if [ ! -f "$DMG_NAME" ]; then
    echo "   ❌ DMG 生成失败"
    exit 1
fi
echo "   → $DMG_NAME ($(stat -f%z "$DMG_NAME") bytes)"

# ========== Step 9: DMG 签名 + 公证 + 钉合 ==========
echo ""
echo "🔏 Step 9/12: DMG 签名 + 公证..."
codesign --force --sign "$IDENTITY" "$DMG_NAME"

echo "   ⏳ 提交 DMG 公证..."
xcrun notarytool submit "$DMG_NAME" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

xcrun stapler staple "$DMG_NAME"
echo "   ✅ DMG 签名 + 公证 + 钉合完成"

# ========== Step 10: Sparkle EdDSA 签名 + appcast ==========
echo ""
echo "✍️  Step 10/12: Sparkle 签名 + appcast.xml..."
mkdir -p "$PROJECT_DIR/releases"
cp "$ZIP_NAME" "$PROJECT_DIR/releases/"

"$SPARKLE_BIN/generate_appcast" \
    --download-url-prefix "https://github.com/Neonbe/GreenLight/releases/download/v${VERSION}/" \
    "$PROJECT_DIR/releases/"

# 复制到 website 目录
cp "$PROJECT_DIR/releases/appcast.xml" "$PROJECT_DIR/website/appcast.xml"
echo "   ✅ appcast.xml 已生成并复制到 website/"

# ========== Step 11: 输出摘要 ==========
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ GreenLight v${VERSION} (build ${BUILD}) 发版完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📂 产物位置:"
echo "   ZIP: $RELEASE_DIR/$ZIP_NAME"
echo "   DMG: $RELEASE_DIR/$DMG_NAME"
echo "   appcast: $PROJECT_DIR/website/appcast.xml"
echo ""
echo "📋 Step 11/12: 上传到 GitHub Release (手动):"
echo "   1. 前往 https://github.com/Neonbe/GreenLight/releases/new"
echo "   2. Tag: v${VERSION} | Target: main"
echo "   3. 附件上传: $ZIP_NAME + $DMG_NAME"
echo ""
echo "📋 Step 12/12: 推送 appcast.xml (手动):"
echo "   git add website/appcast.xml"
echo "   git commit -m 'release: update appcast.xml for v${VERSION}'"
echo "   git push"
echo ""
