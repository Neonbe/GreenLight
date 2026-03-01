# Gatekeeper Companion：竞品深度分析 + 日志监控实验方案

## 一、竞品深度分析

### 🏆 核心竞品：Sentinel（alienator88）

> [!CAUTION]
> **这是一个与 Gatekeeper Companion 替代方案高度重叠的、成熟的、活跃维护的竞品。**

#### 基本信息

| 维度 | 详情 |
|------|------|
| **GitHub** | [alienator88/Sentinel](https://github.com/alienator88/Sentinel) |
| **Stars** | **1,443** ⭐ |
| **Forks** | 43 |
| **Watchers** | 19 |
| **Open Issues** | 7 |
| **Contributors** | 4 人 |
| **技术栈** | 100% Swift + SwiftUI |
| **兼容性** | macOS 13.x (Ventura) / 14.x (Sonoma) / 15.x (Sequoia) / 26.x (Tahoe) |
| **安装方式** | `brew install alienator88-sentinel` 或 GitHub Releases |
| **签名状态** | 已 code sign + notarized |
| **许可证** | Apache 2.0 + **Commons Clause**（禁止任何形式的商业化） |
| **创建时间** | 2023-03-22 |
| **最后推送** | 2025-11-24 |

#### 版本发布历史与更新频率

| 版本 | 发布日期 | 主要更新 | 下载量（.zip） |
|------|----------|----------|----------------|
| v3.1.4 | 2025-11-24 | Dock 图标拖拽 | **204,252** |
| v3.1.3 | 2025-09-24 | Finder Extension 挂载卷显示 | 109,474 |
| v3.1.2 | 2025-09-16 | Xcode 26 / macOS Tahoe 适配 | 15,611 |
| v3.1.1 | 2025-08-19 | Finder 扩展支持外部卷 | 33,620 |
| v3.1.0 | 2025-07-29 | **Finder 右键扩展** + 批量拖拽 + UI 回退 | 17,199 |
| v3.0.0 | 2025-06-06 | **用 AuthServices 替换 AppleScript** + UI/UX 重做 | 5,445 |
| v2.2 | 2025-04-17 | 开发者签名选项 + 解除后自动打开 | 2,010 |
| v2.1 | 2025-01-07 | 调试控制台 + 空格路径修复 | 21,900 |
| v2.0 | 2024-12-19 | Sequoia 适配 | 5,966 |
| v1.9 | 2024-12-09 | 错误处理 + 特权提升 | 2,811 |

> **更新频率**：过去 12 个月发布了 **8 个版本**（约 1.5 月/版），非常活跃。
>
> **总下载量**：仅最新版 v3.1.4 的 .zip 就有 **20.4 万次**下载，全版本累计下载超 **40 万次**。

#### v3.0.0 关键技术演进

> [!NOTE]
> Sentinel 在 v3.0.0 中做了一个值得注意的技术决策：**用苹果的 AuthServices 框架替换了所有 AppleScript 调用**。这恰好验证了我们第一份评审报告中的发现4——NSAppleScript 方案不可持续，Sentinel 的开发者也走了同样的弯路并最终转向了原生授权框架。

#### 开发者生态

alienator88 是一个活跃的 macOS 开源工具开发者，旗下还有：
- [**Pearcleaner**](https://github.com/alienator88/Pearcleaner) — 开源 App 卸载清理工具（类似 AppCleaner）
- [**Viz**](https://github.com/alienator88/Viz) — 从图片/视频/二维码提取文字
- [**PearHID**](https://github.com/alienator88/PearHID) — macOS 键盘重映射

这说明 Sentinel 背后有一个**持续产出高质量 macOS 原生工具**的开发者，产品不太可能被弃坑。

#### 功能清单

1. ✅ **拖拽解除隔离**：将 .app 拖入窗口 / Dock 图标，自动 `xattr -rd com.apple.quarantine`
2. ✅ **解除后自动打开**：可选项，解除隔离后直接启动 app
3. ✅ **自签名（ad-hoc self-sign）**：拖入 .app 自动 `codesign --sign -`，支持开发者证书签名
4. ✅ **Finder Extension 右键菜单**：右键 → 解除隔离，支持外部卷和挂载卷
5. ✅ **批量拖拽处理**：支持同时拖入多个 .app
6. ✅ **自动更新器**：从 GitHub Releases 拉取最新版本
7. ✅ Homebrew 分发
8. ✅ 调试控制台（CMD+D）

#### Sentinel 没有做的事（潜在差异化空间）

- ❌ 没有后台自动监控/检测机制（纯手动触发）
- ❌ 没有 Menu Bar 常驻模式
- ❌ 没有通知提醒功能（检测到被隔离 app 时主动通知）
- ❌ 没有应用签名状态扫描/仪表盘
- ❌ Commons Clause **禁止商业化**（fork 也不行）

#### 对我们的影响

之前评审报告中建议的替代方案架构（拖拽 + Finder Extension + 自签名）与 Sentinel 的功能集**几乎完全一致**。如果我们走这条路，等同于重新造一个 Sentinel。差异化必须来自 Sentinel **没做到**的能力——即"自动检测 + 主动通知"。

---

### 其他竞品

#### macOS-GateKeeper-Helper

| 维度 | 详情 |
|------|------|
| **GitHub** | [wynioux/macOS-GateKeeper-Helper](https://github.com/wynioux/macOS-GateKeeper-Helper) |
| **Stars** | 265 |
| **Forks** | 31 |
| **Watchers** | 9 |
| **技术栈** | Shell 脚本 |
| **许可证** | MIT |
| **创建时间** | 2019-07-29 |
| **最后推送** | ⚠️ **2020-07-16**（接近 6 年未更新） |
| **Releases** | 5 个 |
| **Open Issues** | 0（非活跃，非无 bug） |
| **状态评估** | 🔴 **已废弃**。macOS Sequoia 下 `spctl --master-disable` 已失效，核心功能报废。Sentinel 的 README 致谢了 Wynioux，说明 Sentinel 就是它的精神继任者。 |

#### 其他工具一览

| 竞品 | 类型 | 状态 | 说明 |
|------|------|------|------|
| **[Xattr-remove](https://insanelymac.com)** | SwiftUI Droplet | 🟡 小众 | 拖拽移除 quarantine，完成后自动退出。功能极度单一，无社区热度数据。|
| **[antiQuarantine (aq)](https://github.com/jurek-zsl/antiQuarantine)** | Homebrew CLI | 🟢 可用 | `brew install aq` → `aq -r myapp.app`。面向终端用户，无 GUI，Stars 很少。|
| **[Remove Quarantine](https://sourceforge.net)** | SourceForge 工具 | 🟡 老旧 | Finder 右键菜单集成。SourceForge 分发，信任度低，年久失修。|
| **macOS 原生方案** | 系统内建 | 🟢 永远可用 | `系统设置 > 隐私与安全性 > "仍然打开"`，步骤多但 Apple 官方支持。|

---

### 竞品分析结论

> [!IMPORTANT]
> Sentinel 是这个赛道目前的**事实标准**。1400+ stars、活跃维护、功能完善、Homebrew 分发。
> 
> **如果 Gatekeeper Companion 要存在，必须做 Sentinel 做不到的事。** 最大差异化空间在于：
> 1. **自动检测 + 主动通知**（Sentinel 是纯手动工具）
> 2. **安全仪表盘**（全盘扫描、签名状态可视化）
> 3. **商业化路径**（Sentinel 的 Commons Clause 禁止商业化，这是它留给市场的缺口）

---

## 二、Gatekeeper 日志监控实验方案

### 实验目标

验证以下关键技术假设：
1. 当 Gatekeeper 拦截一个未签名 app 时，系统日志中**是否**有可检测的事件？
2. 日志中**是否包含**被拦截 app 的文件路径？
3. 不同监控通道（`log stream`、`FSEvents`、`NSWorkspace`）的检测效果如何？

### 前置准备

你需要准备一个**未签名的 .app**，用于触发 Gatekeeper 拦截。最简单的方式：

```bash
# 方法1：从网上下载一个未签名的开源 app（如 Sentinel 本身的 unsigned build）
# 方法2：自己编译一个最简 app 并打上 quarantine 属性
mkdir -p /tmp/TestApp.app/Contents/MacOS
cat > /tmp/TestApp.app/Contents/MacOS/TestApp << 'EOF'
#!/bin/bash
echo "Hello from TestApp"
EOF
chmod +x /tmp/TestApp.app/Contents/MacOS/TestApp

cat > /tmp/TestApp.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TestApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.test.gatekeepertest</string>
    <key>CFBundleName</key>
    <string>TestApp</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
</dict>
</plist>
EOF

# 手动打上 quarantine 属性（模拟从网络下载）
xattr -w com.apple.quarantine "0083;5f1b2c4e;Safari;8C29A693-C92D-4E1C-B249-12345ABCDE" /tmp/TestApp.app
```

### 实验步骤

---

#### 实验 A：`log stream` 监听 CoreServicesUIAgent

**目的**：验证 `log stream` 能否捕获 Gatekeeper 拦截事件，以及日志中是否包含 app 路径。

**步骤**：

1. **打开终端窗口 1**，启动日志监听：
```bash
log stream --predicate 'process == "CoreServicesUIAgent"' --style compact 2>&1 | tee /tmp/gatekeeper_log_coreservices.txt
```

2. **打开终端窗口 2**，启动另一个监听（监控 syspolicyd）：
```bash
log stream --predicate 'process == "syspolicyd"' --style compact 2>&1 | tee /tmp/gatekeeper_log_syspolicy.txt
```

3. **打开终端窗口 3**，启动广泛监听（关键词过滤）：
```bash
log stream --predicate 'eventMessage CONTAINS "quarantine" OR eventMessage CONTAINS "gatekeeper" OR eventMessage CONTAINS "GK" OR eventMessage CONTAINS "xprotect"' --style compact --info 2>&1 | tee /tmp/gatekeeper_log_broad.txt
```

4. **触发 Gatekeeper 拦截**：
   - 在 Finder 中双击 `/tmp/TestApp.app`（或你从网上下载的未签名 app）
   - 等待系统弹窗出现
   - **截图弹窗的样子**（确认是弹窗模式还是跳转系统设置模式）
   - 点击"取消"或"好的"关闭弹窗

5. **停止日志监听**（Ctrl+C），检查输出：
```bash
echo "=== CoreServicesUIAgent 日志 ==="
cat /tmp/gatekeeper_log_coreservices.txt

echo "=== syspolicyd 日志 ==="
cat /tmp/gatekeeper_log_syspolicy.txt

echo "=== 广泛关键词日志 ==="
cat /tmp/gatekeeper_log_broad.txt
```

**关注点**：
- [ ] 是否有日志输出？
- [ ] 日志中是否包含被拦截 app 的完整路径？
- [ ] 日志的延迟是多少（实时 vs 延迟数秒）？
- [ ] 日志格式是什么样的？（供正则解析参考）

---

#### 实验 B：`FSEvents` / 文件系统监控

**目的**：验证是否可以通过监控文件系统事件 + xattr 检查来发现被隔离的新 app。

**步骤**：

1. 将以下脚本保存为 `/tmp/watch_quarantine.sh`：
```bash
#!/bin/bash
# 监控 ~/Downloads 和 /Applications 目录中新出现的 .app
# 并检查它们是否有 quarantine 属性

echo "开始监控 quarantine 属性..."
echo "监控目录: ~/Downloads, /Applications"

fswatch -r ~/Downloads /Applications --event Created --event Renamed | while read -r path; do
    if [[ "$path" == *.app* ]]; then
        # 提取 .app 包路径
        app_path=$(echo "$path" | grep -oE '.*\.app')
        if [ -n "$app_path" ] && [ -d "$app_path" ]; then
            quarantine=$(xattr -p com.apple.quarantine "$app_path" 2>/dev/null)
            if [ -n "$quarantine" ]; then
                echo "🚨 检测到被隔离的应用: $app_path"
                echo "   quarantine 值: $quarantine"
                echo "   时间: $(date)"
            fi
        fi
    fi
done
```

2. 安装 `fswatch`（如果还没有）：
```bash
brew install fswatch
```

3. 运行监控脚本：
```bash
chmod +x /tmp/watch_quarantine.sh
/tmp/watch_quarantine.sh
```

4. 在另一个终端，将测试 app 复制到 Downloads 触发 FSEvents：
```bash
cp -R /tmp/TestApp.app ~/Downloads/
xattr -w com.apple.quarantine "0083;5f1b2c4e;Safari;8C29A693-C92D-4E1C-B249-12345ABCDE" ~/Downloads/TestApp.app
```

**关注点**：
- [ ] FSEvents 是否能检测到 .app 的创建/移动？
- [ ] 检测的延迟是多少？
- [ ] 是否能正确读取 quarantine 属性？

---

#### 实验 C：`xattr` 命令权限测试

**目的**：验证在**不使用 sudo** 的情况下，`xattr -rd` 是否能成功移除不同位置的 quarantine 属性。

**步骤**：

```bash
# 测试 1: ~/Downloads 目录（用户拥有的目录）
cp -R /tmp/TestApp.app ~/Downloads/TestApp_test1.app
xattr -w com.apple.quarantine "0083;5f1b2c4e;Safari;8C29A693" ~/Downloads/TestApp_test1.app
echo "Before: $(xattr -l ~/Downloads/TestApp_test1.app)"
xattr -rd com.apple.quarantine ~/Downloads/TestApp_test1.app
echo "After:  $(xattr -l ~/Downloads/TestApp_test1.app)"
echo "退出码: $?"

# 测试 2: /Applications 目录
cp -R /tmp/TestApp.app /Applications/TestApp_test2.app
xattr -w com.apple.quarantine "0083;5f1b2c4e;Safari;8C29A693" /Applications/TestApp_test2.app
echo "Before: $(xattr -l /Applications/TestApp_test2.app)"
xattr -rd com.apple.quarantine /Applications/TestApp_test2.app
echo "After:  $(xattr -l /Applications/TestApp_test2.app)"
echo "退出码: $?"

# 清理
rm -rf ~/Downloads/TestApp_test1.app /Applications/TestApp_test2.app
```

**关注点**：
- [ ] `~/Downloads` 下无 sudo 是否成功？（预期：是）
- [ ] `/Applications` 下无 sudo 是否成功？（预期：取决于文件所有者）

---

### 实验结果记录模板

完成实验后，请记录以下信息：

| 实验 | 结果 | 备注 |
|------|------|------|
| A1: CoreServicesUIAgent 有日志输出 | ✅/❌ | |
| A2: 日志包含 app 路径 | ✅/❌ | 路径格式: |
| A3: syspolicyd 有日志输出 | ✅/❌ | |
| A4: 广泛关键词有匹配 | ✅/❌ | 匹配的关键词: |
| A5: 弹窗行为（弹窗/跳设置） | 弹窗/设置 | macOS 版本: |
| B1: FSEvents 检测到 .app 创建 | ✅/❌ | |
| B2: 能读取 quarantine 属性 | ✅/❌ | |
| C1: ~/Downloads 无 sudo 移除成功 | ✅/❌ | |
| C2: /Applications 无 sudo 移除成功 | ✅/❌ | |
