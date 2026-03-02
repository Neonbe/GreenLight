# GreenLight：UI 与交互设计规范

> **产品名称**：GreenLight  
> **核心隐喻**：🚦 红绿灯——为你的应用"放行"  
> **设计定稿日期**：2026-03-02  
> **关联文档**：[interaction_flow_spec.md](./interaction_flow_spec.md)

---

## 一、设计语言总览

### 1.1 视觉核心：具象红绿灯

GreenLight 的 UI 锚点是一个**写实的交通信号灯**，直接嵌入 Menu Bar Popover 左侧。

```
┌──────────────────────────────────────────┐
│  GREENLIGHT                    🔍  ⚙    │
│                                          │
│  ┌────┐  ┌─ Red Lane ──────────────┐     │
│  │ 🔴 │  │  BLOCKED  2  │ 🟦 🟧  │     │
│  │    │  └─────────────────────────┘     │
│  │ 🟡 │  ┌─ Amber Lane ───────────┐     │
│  │    │  │  SCANNING 1  │ 🟪     │     │
│  │    │  └─────────────────────────┘     │
│  │ 🟢 │  ┌─ Green Lane ───────────┐     │
│  │    │  │  CLEARED  7  │ 🟩🟦🟪… │     │
│  └──┬─┘  └─────────────────────────┘     │
│     │                                    │
│           ● System Protected             │
└──────────────────────────────────────────┘
```

**关键设计决策**：

| 决策 | 理由 |
|:---|:---|
| 红绿灯为 CSS 拟物风格，非扁平 | 强化品牌辨识度，一眼即懂 |
| 灯序遵循真实交通灯：红 → 黄 → 绿 | 用户无认知成本 |
| 信息条从灯体水平延伸 | 参考 Infographic 排版，灯色 = 分类锚点 |
| 点击应用图标才展开操作 | 主界面极简，操作按需暴露 |

### 1.2 信号灯语义

| 信号 | 颜色值 | 语义 | 说明 |
|:---|:---|:---|:---|
| 🔴 **红灯** | `#EF4444` | Blocked（被拦截） | 被 Gatekeeper 拦截、需要用户处理 |
| 🟡 **黄灯** | `#F59E0B` | Scanning（扫描中） | 刚检测到、正在分析或等待用户决策 |
| 🟢 **绿灯** | `#22C55E` | Cleared（已放行） | 已经由 GreenLight 修复过 |

---

## 二、视觉设计系统

### 2.1 色彩

| Token | 值 | 用途 |
|:---|:---|:---|
| `--bg` | `#0F172A` | 页面背景 |
| `--surface` | `rgba(30,41,59,0.55)` | Popover 面板 |
| `--glass` | `rgba(255,255,255,0.04)` | 毛玻璃控件底色 |
| `--glass-border` | `rgba(255,255,255,0.08)` | 玻璃边框 |
| `--text-primary` | `#F8FAFC` | 主文字 |
| `--text-secondary` | `rgba(248,250,252,0.45)` | 辅助文字 |
| `--text-muted` | `rgba(248,250,252,0.25)` | 最弱文字 |
| `--green` | `#22C55E` | 绿灯 / CTA |
| `--red` | `#EF4444` | 红灯 / 警告 |
| `--amber` | `#F59E0B` | 黄灯 / 扫描 |

### 2.2 字体

| 用途 | 字体 | 字重 | 字号 |
|:---|:---|:---|:---|
| 品牌名 | Inter | 700 | 11px，letter-spacing 4.5px |
| 分区标签 | Inter | 600 | 9px，letter-spacing 1.5px |
| 数字计数 | Inter | 800 | 22px |
| 气泡标题 | Inter | 600 | 14px |
| 气泡路径 | Inter | 400 | 10px |
| 按钮文字 | Inter | 500 | 13px |
| 状态文字 | Inter | 600 | 11px |

### 2.3 质感层次

```
┌─ Glass Layer Stack 从外到内 ─────────────────────┐
│                                                    │
│  1. 外阴影:  0 50px 120px rgba(0,0,0,0.4)        │
│  2. 内阴影:  0 20px 50px rgba(0,0,0,0.2)         │
│  3. 顶高光:  inset 0 1px 0 rgba(255,255,255,0.06)│
│  4. 底暗边:  inset 0 -1px 0 rgba(0,0,0,0.1)      │
│  5. 模糊:    backdrop-filter: blur(80px)          │
│             saturate(1.6)                          │
│  6. 圆角:    28px (Popover)                        │
│              12px (Lane)                           │
│              10px (App Icon)                       │
│                                                    │
└────────────────────────────────────────────────────┘
```

### 2.4 图标规范

| 图标类型 | 尺寸 | 圆角 | 说明 |
|:---|:---|:---|:---|
| 应用图标 | 40×40px | 10px | 实际使用 macOS App Icon |
| 头部按钮 | 30×30px | 8px | SVG 线条图标，16px stroke |
| 操作按钮图标 | 16×16px | — | SVG 内联，stroke-width 2 |

> [!IMPORTANT]
> 禁止使用 Emoji 作为图标（`no-emoji-icons` 规则）。全部使用 SVG 矢量图标。

---

## 三、核心组件规范

### 3.1 具象红绿灯 (Traffic Light)

左侧锚点元素。纯 CSS 拟物渲染，不使用图片。

**结构**：

```
TrafficLight
├── Housing (金属外壳, 圆角矩形, 76px 宽)
│   ├── LightCell[Red]    → Visor + Bulb
│   ├── LightCell[Amber]  → Visor + Bulb
│   └── LightCell[Green]  → Visor + Bulb
├── Pole (柱杆, 14px 宽)
└── Base (底座, 44px 宽)
```

**灯泡渲染要点**：

- 尺寸：50×50px 圆形
- 使用 `radial-gradient` 模拟球面光照（高光偏左上 40%/35%）
- `::before` 伪元素添加玻璃高光反射（模糊椭圆）
- `::after` 伪元素添加边缘暗环（inset border）
- 每个灯带 Visor 遮光罩（14px 高度上方突出）
- 外壳采用多方向线性渐变模拟金属质感

**动画**：

| 状态 | 动画 | 参数 |
|:---|:---|:---|
| 红灯 | 脉冲呼吸 `redPulse` | `box-shadow` 振幅变化，2.5s ease-in-out infinite |
| 黄灯 | 无（静态发光） | — |
| 绿灯 | 无（静态发光） | — |

### 3.2 信息条 (Lane)

从红绿灯灯位水平延伸的分类区域。

**布局**：`flex row`，圆角右侧 12px（左侧连接灯体无圆角）

**结构**：

```
Lane
├── ::before  (左侧 2.5px 竖向霓虹线，对应灯色 + box-shadow 发光)
├── ::after   (颜色光线渐变底色，opacity 3%→6% on hover)
├── LaneInfo
│   ├── Label  (BLOCKED / SCANNING / CLEARED, 9px)
│   └── Count  (数字, 22px 加粗, 灯色)
├── Separator  (1px 竖线分隔)
└── IconsArea  (flex-wrap, 7px gap)
    └── AppIcon × N
```

### 3.3 应用图标 (App Icon)

代表单个应用的可交互元素。

| 属性 | 值 |
|:---|:---|
| 尺寸 | 40×40px |
| 圆角 | 10px |
| 最小触控区域 | 44×44px（满足无障碍要求） |
| 边框 | 1px solid rgba(255,255,255,0.1) |

**交互状态**：

| 状态 | 效果 | 过渡 |
|:---|:---|:---|
| Default | 原始尺寸 | — |
| Hover | `scale(1.18) translateY(-3px)` + 阴影加深 + 边框变亮 | 350ms spring |
| Active | `scale(0.94)` | 150ms |
| Focus-visible | 2px green outline, 3px offset | — |

**入场动画**：交错入场 `iconIn`，每个图标 30ms 递增延迟。

```css
@keyframes iconIn {
  from { opacity: 0; transform: scale(0.7) translateY(8px); }
  to   { opacity: 1; transform: scale(1) translateY(0); }
}
```

**黄灯区特殊**：图标叠加 `scanPulse` 呼吸动画（opacity 1→0.5，2.5s 周期）。

### 3.4 操作气泡 (Action Bubble)

点击应用图标后弹出的浮层。

**视觉**：

- 背景：`rgba(22,28,45,0.97)` + `blur(40px)`
- 圆角：16px
- 左侧三角箭头指向触发图标
- 入场动画：`scale(0.85)→1` + `translateY(8px)→0`，300ms spring
- 最小宽度：220px

**结构**：

```
ActionBubble
├── Pointer (CSS 三角箭头, 14×14px 旋转 45°)
├── Header
│   ├── AppIcon (36×36px)
│   ├── AppName (14px, 600)
│   └── AppPath (10px, muted)
├── Divider (1px)
└── Actions
    ├── SecondaryButton  (灰底)
    └── PrimaryButton    (绿底 #22C55E)
```

**按钮动作映射**：

| 灯色 | 操作 1 | 操作 2 |
|:---|:---|:---|
| 🔴 Red | 🔓 Unlock | ▶ Unlock + Open |
| 🟡 Amber | ⏳ Scanning… (禁用态) | — |
| 🟢 Green | ℹ️ View Info | 📂 Show in Finder |

### 3.5 状态胶囊 (Status Pill)

底部居中的全局系统状态。

```
StatusPill
├── Dot  (6px, green, 呼吸闪烁 3s)
└── Text ("System Protected", 11px, 绿色 75% 透明)
```

---

## 四、交互流程（视觉化）

### 4.1 图标点击 → 操作气泡

```
用户鼠标悬停到应用图标
    ↓
图标放大 + 上浮 + 阴影加深 + Tooltip 浮现（应用名）
    ↓
用户点击
    ↓
弹出 Action Bubble（带箭头指向图标 + 弹跳入场动画）
    ↓
用户选择操作 / 点击空白区域关闭 / 按 ESC 关闭
```

### 4.2 Popover 入场

```
用户点击 Menu Bar 图标
    ↓
Popover 整体: scale(0.95)→1 + translateY(10px)→0, 500ms spring
    ↓
红绿灯立即可见
    ↓
应用图标交错入场 (每个延迟 30ms): scale(0.7)→1 + opacity 0→1
    ↓
状态胶囊最后显示
```

### 4.3 Menu Bar 图标状态

| 系统状态 | Menu Bar 图标 | 说明 |
|:---|:---|:---|
| 一切正常 | 🟢 静态绿色 | 所有应用已放行 |
| 检测到拦截 | 🔴 + 角标数字 | 有应用被 Gatekeeper 拦截 |
| 扫描中 | 🟡 + 旋转动画 | 正在执行全盘扫描 |

---

## 五、无障碍 (Accessibility)

| 规则 | 实现 |
|:---|:---|
| 键盘导航 | 所有 App Icon 和按钮可 Tab 聚焦 |
| Focus 可见 | `focus-visible` 绿色 outline 2px, offset 3px |
| Aria 标签 | 头部按钮带 `aria-label`（Search / Settings） |
| ESC 关闭 | 监听 `keydown` ESC 关闭 Action Bubble |
| 减弱动效 | `@media(prefers-reduced-motion: reduce)` 禁用所有动画 |
| 色彩对比 | 所有文字对比度 ≥ 4.5:1 |
| 触控目标 | 最小 44×44px |

---

## 六、设计资源

### 6.1 文件清单

| 文件 | 路径 | 说明 |
|:---|:---|:---|
| 最终版 HTML | [`v-final.html`](../design/v-final.html) | 可交互原型，双击用浏览器打开 |
| 主界面截图 | [`v-final-main.png`](../design/v-final-main.png) | 静态预览 |
| 交互截图 | [`v-final-popup.png`](../design/v-final-popup.png) | 操作气泡效果 |
| 交互录屏 | [`v-final-demo.webp`](../design/v-final-demo.webp) | 动画录屏 |

### 6.2 迭代演化

| 版本 | 方向 | 状态 |
|:---|:---|:---|
| V1（初版 Liquid Glass） | 列表式工具面板 | ❌ 太工具化，已废弃 |
| V2 Signal Tower | 横排灯球 + 图标网格 | 🔶 方向确认 |
| V3 Three Worlds | 三列并排星球 | ❌ 已废弃 |
| V4 Gravity | 竖向红绿灯 + 折叠区 | ❌ 已废弃 |
| V5 Street Light | 拟真红绿灯 + 信息条 | 🔶 灯体参考 |
| V6 Neon Signal | 霓虹线条灯 | ❌ 已废弃 |
| V7 Glass Pole | 毛玻璃灯 + 深蓝背景 | 🔶 质感确认 |
| **Final** | **V2 + V5 + V7 融合** | **✅ 定稿** |

---

## 七、后续待设计

> 以下页面待后续迭代补充到本文档：

- [ ] 通知横幅 (Notification Banner)
- [ ] Onboarding 首次引导流程
- [ ] 全盘扫描进度视图
- [ ] 设置面板
- [ ] Menu Bar 图标各状态资源
- [ ] 空状态（无应用被拦截时的界面）
