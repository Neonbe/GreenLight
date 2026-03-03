#!/bin/bash
# 生成 4 种不同类型的 blocked test app，用于延迟实验
# 用法: ./create_test_apps.sh
# 生成位置: /Applications/ (需要 sudo)

set -e

echo "🧪 创建 4 种测试 blocked App..."
echo ""

SWIFT_SRC=$(mktemp /tmp/testapp.XXXXXX.swift)
cat > "$SWIFT_SRC" << 'EOF'
import Foundation
print("Hello from test app")
RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))
EOF

# --- Type A: 完全未签名 ---
APP_A="/Applications/TestUnsigned.app"
echo "📦 Type A: 完全未签名 (no signature)"
sudo rm -rf "$APP_A"
sudo mkdir -p "$APP_A/Contents/MacOS"
sudo swiftc -o "$APP_A/Contents/MacOS/TestUnsigned" "$SWIFT_SRC" 2>/dev/null
cat << PLIST | sudo tee "$APP_A/Contents/Info.plist" > /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TestUnsigned</string>
<key>CFBundleIdentifier</key><string>com.test.unsigned</string>
<key>CFBundleName</key><string>TestUnsigned</string>
</dict></plist>
PLIST
# 添加 quarantine 属性（模拟从互联网下载）
sudo xattr -w com.apple.quarantine "0083;66a5c3b5;Safari;AAAA-BBBB" "$APP_A"
echo "   ✅ $APP_A (预期: SecStaticCode CREATE/VALIDITY 失败 → 秒判)"

# --- Type B: Ad-hoc 签名（未公证） ---
APP_B="/Applications/TestAdHoc.app"
echo "📦 Type B: Ad-hoc 签名 (signed with '-', not notarized)"
sudo rm -rf "$APP_B"
sudo mkdir -p "$APP_B/Contents/MacOS"
sudo swiftc -o "$APP_B/Contents/MacOS/TestAdHoc" "$SWIFT_SRC" 2>/dev/null
cat << PLIST | sudo tee "$APP_B/Contents/Info.plist" > /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TestAdHoc</string>
<key>CFBundleIdentifier</key><string>com.test.adhoc</string>
<key>CFBundleName</key><string>TestAdHoc</string>
</dict></plist>
PLIST
sudo codesign -s - "$APP_B" --force 2>/dev/null
sudo xattr -w com.apple.quarantine "0083;66a5c3b5;Safari;AAAA-BBBB" "$APP_B"
echo "   ✅ $APP_B (预期: SecStaticCode 通过 → spctl rejected)"

# --- Type C: 签名后篡改（damaged signature） ---
APP_C="/Applications/TestDamaged.app"
echo "📦 Type C: 签名后篡改 (valid signature then corrupted)"
sudo rm -rf "$APP_C"
sudo mkdir -p "$APP_C/Contents/MacOS"
sudo swiftc -o "$APP_C/Contents/MacOS/TestDamaged" "$SWIFT_SRC" 2>/dev/null
cat << PLIST | sudo tee "$APP_C/Contents/Info.plist" > /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TestDamaged</string>
<key>CFBundleIdentifier</key><string>com.test.damaged</string>
<key>CFBundleName</key><string>TestDamaged</string>
</dict></plist>
PLIST
sudo codesign -s - "$APP_C" --force 2>/dev/null
# 篡改二进制（追加垃圾字节破坏签名）
echo "CORRUPTED" | sudo tee -a "$APP_C/Contents/MacOS/TestDamaged" > /dev/null
sudo xattr -w com.apple.quarantine "0083;66a5c3b5;Safari;AAAA-BBBB" "$APP_C"
echo "   ✅ $APP_C (预期: SecStaticCode VALIDITY 失败 → 秒判)"

# --- Type D: 无 quarantine 的正常 App（对照组） ---
APP_D="/Applications/TestNormal.app"
echo "📦 Type D: 正常签名 + 无 quarantine（对照组）"
sudo rm -rf "$APP_D"
sudo mkdir -p "$APP_D/Contents/MacOS"
sudo swiftc -o "$APP_D/Contents/MacOS/TestNormal" "$SWIFT_SRC" 2>/dev/null
cat << PLIST | sudo tee "$APP_D/Contents/Info.plist" > /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TestNormal</string>
<key>CFBundleIdentifier</key><string>com.test.normal</string>
<key>CFBundleName</key><string>TestNormal</string>
</dict></plist>
PLIST
sudo codesign -s - "$APP_D" --force 2>/dev/null
# 不添加 quarantine！
echo "   ✅ $APP_D (预期: 无 quarantine → FSEvents 跳过)"

rm -f "$SWIFT_SRC"

echo ""
echo "🎯 已创建 4 个测试 App:"
echo "   A. TestUnsigned.app   — 无签名 + quarantine"
echo "   B. TestAdHoc.app      — ad-hoc 签名 + quarantine"
echo "   C. TestDamaged.app    — 篡改签名 + quarantine"
echo "   D. TestNormal.app     — 正常签名，无 quarantine（对照）"
echo ""
echo "⚠️ 实验完成后清理: sudo rm -rf /Applications/Test{Unsigned,AdHoc,Damaged,Normal}.app"
