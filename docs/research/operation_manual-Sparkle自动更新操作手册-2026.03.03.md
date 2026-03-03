# GreenLight 自动更新 — 小白操作手册

> **一句话总结**: Sparkle 就像一个"快递系统"。你（开发者）把新版本打包 → 签名 → 放到网上 → 用户的 App 自动发现并下载安装。

---

## 现在代码层面已经做完了什么？

以下文件**已经改好了**，你不需要再动它们：

```
GreenLight/
├── Package.swift                          ← 已添加 Sparkle 依赖
├── GreenLight/
│   ├── Info.plist                          ← 已添加更新配置（密钥待替换）
│   ├── GreenLightApp.swift                ← 已注入 UpdaterManager
│   ├── Utilities/
│   │   └── UpdaterManager.swift           ← 【新建】Sparkle 封装，已就位
│   └── Views/
│       ├── SettingsPageView.swift          ← 已添加"软件更新"区块
│       └── SettingsView.swift             ← 已添加更新设置
└── run.sh                                 ← 已添加 Sparkle.framework 嵌入
```

**你唯一还没做的事：生成密钥 + 选个地方放更新包。** 下面按场景一步步教你。

---

## 场景一：第一次发版前的准备（只做一次）

### 你要做两件事：生成密钥 + 选一个放文件的地方

**第 1 步：生成密钥**

打开终端，进入项目目录：

```bash
cd /Users/neobott/Desktop/GreenLight
```

运行：

```bash
# 找到工具
TOOL=$(find .build/artifacts -name "generate_keys" -type f | head -1)
# 生成密钥
$TOOL
```

屏幕会输出一段公钥，长得像这样：

```
0SPb0FtoXkv1C9PFAm3OxXqF1MG0BQAAAAAAAAAAAAA=
```

把这串字符复制下来，打开 `GreenLight/Info.plist`，找到：

```xml
<string>YOUR_EDDSA_PUBLIC_KEY_HERE</string>
```

替换为：

```xml
<string>你复制的那串公钥</string>
```

> 💡 密码（私钥）自动保存在你 Mac 的钥匙串里了，不用管它。

**第 2 步：选一个放更新文件的地方**

你需要一个能放文件的网址。最简单的方案：**用 GitHub Releases**。

假设你的 GitHub 仓库是 `https://github.com/你的用户名/GreenLight`，那把 `Info.plist` 里的 `SUFeedURL` 改成：

```xml
<string>https://raw.githubusercontent.com/你的用户名/GreenLight/main/appcast.xml</string>
```

> 意思是：appcast.xml 这个文件放在你仓库根目录，App 每次去这个地址检查有没有新版本。

**准备工作完成 ✅ 以后不需要重复做。**

---

## 场景二：我改了 Bug / 加了功能，要发一个新版本给用户

> 你坐在电脑前，代码已经改好了，想让用户收到更新。

**第 1 步：改版本号**

打开 `GreenLight/Info.plist`，改两个地方：

```xml
<!-- 用户看到的版本号，比如 1.0.0 → 1.1.0 -->
<key>CFBundleShortVersionString</key>
<string>1.1.0</string>

<!-- 构建号，每次发版 +1，比如 1 → 2 -->
<key>CFBundleVersion</key>
<string>2</string>
```

**第 2 步：构建正式包**

```bash
cd /Users/neobott/Desktop/GreenLight

# 正式构建（优化编译）
swift build -c release

# 用 run.sh 的逻辑打包 .app（但用 release 产物）
# 或者直接改 run.sh 里的 BUILD_DIR 指向 release，运行一次
./run.sh
```

**第 3 步：打成 zip**

```bash
cd .build
ditto -c -k --sequesterRsrc --keepParent GreenLight.app GreenLight-1.1.0.zip
cd ..
```

现在你有了 `.build/GreenLight-1.1.0.zip`，这就是要给用户的更新包。

**第 4 步：签名**

```bash
SIGN=$(find .build/artifacts -name "sign_update" -type f | head -1)
$SIGN .build/GreenLight-1.1.0.zip
```

屏幕输出：
```
sparkle:edSignature="一长串签名" length="12345"
```

**第 5 步：生成 appcast.xml**

```bash
mkdir -p releases
cp .build/GreenLight-1.1.0.zip releases/

APPCAST=$(find .build/artifacts -name "generate_appcast" -type f | head -1)
$APPCAST releases/
```

这会在 `releases/` 目录下自动生成 `appcast.xml`。

**第 6 步：上传**

把两个文件放到网上：

- `GreenLight-1.1.0.zip` → 上传到 GitHub Release（创建一个 v1.1.0 的 Release，附上这个 zip）
- `appcast.xml` → 放到你仓库根目录，push 到 main 分支

```bash
cp releases/appcast.xml ./appcast.xml
git add appcast.xml
git commit -m "Release v1.1.0"
git push
```

> 然后将 appcast.xml 里的 `<enclosure url="...">` 中的下载地址改为 GitHub Release 的真实下载链接。

**发布完成 ✅ 用户的 App 会在下次检查时发现新版本。**

---

## 场景三：用户侧会看到什么？

用户**什么都不用做**。Sparkle 全自动。

### 自动检查（默认开启）

1. 用户正常使用 GreenLight
2. Sparkle 在后台**每隔几小时**静默检查一次
3. 发现新版本 → 弹出一个原生对话框：

```
╔═══════════════════════════════════════╗
║  GreenLight 1.1.0 版本已可用           ║
║                                       ║
║  新功能：                              ║
║  • 优化检测速度                        ║
║  • 修复已知问题                        ║
║                                       ║
║  [跳过此版本]  [稍后提醒]  [安装更新]    ║
╚═══════════════════════════════════════╝
```

4. 用户点"安装更新" → 自动下载 → 退出旧版 → 安装 → 重启新版
5. 用户的数据（UserDefaults 等）**不会丢失**

### 手动检查

1. 用户打开 GreenLight → 点设置 ⚙️
2. 滚到"软件更新"区域
3. 点"检查"按钮
4. 有新版本 → 同上弹框；没有 → 提示"已是最新版本"

### 用户可选关闭

用户可以在设置里关掉"自动检查更新"开关，之后只能手动检查。

---

## 场景四：出问题了怎么办？

### ❌ "点检查更新没反应"

**原因**: 密钥没配置（还是占位符）  
**解决**: 回到「场景一」生成密钥并替换 Info.plist

### ❌ "检查更新说已是最新"但明明有新版本

**原因**: appcast.xml 没更新或版本号没改  
**解决**: 检查三件事：
1. `Info.plist` 里 `CFBundleVersion` 是否比用户当前的大？（必须数字递增）
2. `appcast.xml` 是否已 push 并在 `SUFeedURL` 指定的位置上？
3. 浏览器访问 `SUFeedURL` 那个地址，能看到 XML 内容吗？

### ❌ "下载失败"

**原因**: zip 文件链接不对  
**解决**: 打开 `appcast.xml`，找到 `<enclosure url="...">` 的地址，用浏览器试试能不能正常手动下载

### ❌ "安装后闪退 / 签名不对"

**原因**: zip 制作或签名有问题  
**解决**: 重新执行「场景二」的第 3~5 步（打包 → 签名 → 生成 appcast）

### ❌ "私钥丢了（换电脑 / 重装系统）"

**严重性**: 🔴 高 — 无法再签名任何更新  
**解决**: 必须生成新密钥对，发一个新版本给用户手动下载安装（这个版本包含新公钥）  
**预防**: 提前备份私钥：
```bash
TOOL=$(find .build/artifacts -name "generate_keys" -type f | head -1)
$TOOL -x  # 导出私钥，安全保存
```

---

## 场景五：我想先在本地测试一下，确认更新流程没问题

> 不需要真的上传到网上，用本地假服务器测试。

**第 1 步：准备一个"新版本"的 zip**

```bash
# 先用当前代码构建一个"新版本"
# 临时改 Info.plist: version → 1.1.0, build → 2
swift build
./run.sh

cd .build
ditto -c -k --sequesterRsrc --keepParent GreenLight.app GreenLight-1.1.0.zip
cd ..

# 签名 + 生成 appcast
SIGN=$(find .build/artifacts -name "sign_update" -type f | head -1)
$SIGN .build/GreenLight-1.1.0.zip

mkdir -p releases
cp .build/GreenLight-1.1.0.zip releases/
APPCAST=$(find .build/artifacts -name "generate_appcast" -type f | head -1)
$APPCAST releases/
```

**第 2 步：启动本地文件服务器**

```bash
cd releases
python3 -m http.server 8080
# 此终端不要关，服务器会一直跑
```

**第 3 步：改 Info.plist 指向本地**

```xml
<key>SUFeedURL</key>
<string>http://localhost:8080/appcast.xml</string>
```

**第 4 步：回退版本号，构建"旧版本"跑起来**

```bash
# 改 Info.plist: version → 1.0.0, build → 1
swift build
./run.sh
```

**第 5 步：打开 App → 设置 → 点"检查更新"**

能看到提示 1.1.0 可用就说明整个流程通了 🎉

> 测试完记得把 `SUFeedURL` 改回正式地址。
