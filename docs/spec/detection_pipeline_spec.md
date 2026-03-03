# GreenLight V1.0.0 — 检测管线规格文档（Detection Pipeline Spec）

> **文档类型**：spec（长期契约）  
> **最后更新**：2026-03-03  
> **覆盖范围**：预热扫描、主动扫描、确认态流程、过滤链、状态机、完整时序

---

## §1 管线架构总览

```
用户双击 unsigned app
       │
       ▼
 macOS Gatekeeper 拦截 ──→ syspolicyd 写日志
       │                         │
       │                  ┌──────┴──────┐
       │                  ▼              ▼
       │            Channel A       Channel C
       │          LogStreamMonitor  proactiveScan
       │          (精准 app 信息)   (全目录发现)
       │                  │              │
       │                  │         ┌────┘
       │                  │         ▼
       │                  │    确认态面板
       │                  │   "Checking..."
       ▼                  │         │
 FSEvents 检测文件变化     │         │
       │                  │         │
   Channel B              │         │
  FSEventsWatcher          │         │
  (quarantine + 验签)      │         │
       │                  │         │
       ▼                  ▼         │
  EventDeduplicator (1s 合并窗口)    │
       │                            │
       ▼                            ▼
  onEvent ──→ confirmWith() 或 show()
       │
       ▼
  AppState + 浮动面板 + 系统通知
```

### 三通道说明

| 通道 | 触发源 | 延迟 | 精度 | 用途 |
|------|--------|------|------|------|
| **A: LogStream** | syspolicyd 日志 | ~100ms | 高（含 app 路径、bundleId） | 精准检测 |
| **B: FSEvents** | 文件系统事件 | ~2-3s | 中（需验签确认） | 稳定兜底 |
| **C: ProactiveScan** | GK 活动信号 | ~30ms | 发现级（不确定是哪个 app） | 先弹确认态 |

---

## §2 预热扫描（Warmup Scan）

### 目的

启动时填充 L2 缓存（`knownSafePaths`），让后续 proactiveScan 跳过已知安全的 app，从 ~3-5s 降低到 ~30ms。

### 触发时机

| 场景 | 触发位置 | 时机 |
|------|---------|------|
| 非首次启动 | `setupPipeline()` | 管线启动后立即后台执行 |
| 首次启动 | `OnboardingView.onAppear` | Onboarding 界面加载时 |

### 执行逻辑

```
warmupScan()
  for app in /Applications/*.app:
    L1: hasQuarantine? — NO → skip
    L2: containsSafePath? — YES → skip
    SecStaticCode 完整校验:
      PASS → insertSafePath（缓存为 safe）
      FAIL → 不缓存（后续 proactiveScan 会检出）
```

> **关键约束**：warmupScan 的校验标准**必须**与 proactiveScan 完全一致（空 flags `[]`）。否则中间态签名的 app 会被轻量检查 pass → 错误缓存 → proactiveScan 跳过 → false negative。

### L2 缓存设计

| 属性 | 值 |
|------|-----|
| Key 格式 | `"app路径\|modDate时间戳"` |
| 线程安全 | `DispatchQueue(label: "com.greenlight.l2cache")` 串行队列 |
| 生命周期 | 进程内存储（App 退出即清空） |
| 访问方法 | `containsSafePath()` / `insertSafePath()` / `safeCacheCount` |

---

## §3 主动扫描（Proactive Scan — Channel C）

### 触发条件

`onGKActivity` 回调（LogStream 检测到 syspolicyd 的任何 GK 相关日志行）。

### 冷却机制

- **5 秒冷却**：两次 proactiveScan 间隔 ≥ 5s，否则跳过。

### 执行逻辑（三层过滤链）

```
proactiveScan(knownPaths: Set<String>)
  for app in 监控目录/*.app:
    L0: pathExtension == "app"
    L1: hasQuarantine? — NO → skip (纳秒级)
    L3: knownPaths.contains? — YES → skip (AppState 已知)
    L2: containsSafePath? — YES → skip (warmup 已验证)
    SecStaticCode 完整校验:
      PASS → insertSafePath, skip
      FAIL → 加入 results
  return results
```

### 过滤链全景

| 层级 | 名称 | 位置 | 条件 | 复杂度 |
|------|------|------|------|--------|
| L0 | .app 扩展名 | 遍历入口 | `pathExtension == "app"` | O(1) |
| L1 | quarantine xattr | `hasQuarantine()` | `getxattr("com.apple.quarantine")` | 纳秒级 |
| L2 | SecStaticCode 缓存 | `knownSafePaths` | `Key="路径\|modDate"` | O(1) 查表 |
| L3 | AppState 已知路径 | `knownPaths` 参数 | 已在列表中的 app | O(1) 查表 |
| 去重 | FSEvents 内部 | `recentPaths` | 3s 窗口 | O(1) |
| Dedup | EventDeduplicator | 管线层 | path + 1s 合并窗口 | O(1) |

---

## §4 确认态流程（Confirmation State）

### 问题背景

proactiveScan 可能发现多个 unsigned app，但无法确定用户正在操作的是哪个。需要先展示"正在确认"，等 Channel A/B 提供精确 app 信息后再替换。

### 状态时序图

```
GK 活动 ─────────────────────────────────────────→ 时间轴
   │
   ├─→ isScanning = true（Menu Bar 黄灯脉冲）
   │
   ├─→ proactiveScan()
   │     ├─→ 0 found → 5s 后恢复绿灯（无确认态）
   │     └─→ N found → showConfirming(N)
   │                     │
   │                     ▼
   │              ┌─────────────────┐
   │              │  确认态面板       │
   │              │  "Checking..."  │
   │              │  三点呼吸 + 进度 │
   │              └────────┬────────┘
   │                       │
   │     ┌─────────────────┼──────────────────┐
   │     ▼                 │                  ▼
   │  Channel A/B          │              5s 超时
   │  FSEvents 确认         │              兜底替换
   │     │                 │                  │
   │     ▼                 │                  ▼
   │  confirmWith(event)   │           用 proactiveScan
   │     │                 │           首个结果替换
   │     ▼                 │                  │
   │  ┌─────────────────┐  │                  │
   │  │  最终态面板       │ ←┼──────────────────┘
   │  │  "检测到 XXX"    │  │
   │  └──────────────────┘  │
   │                        │
   └── isScanning = false ──┘
```

### 关键方法

| 方法 | 职责 |
|------|------|
| `showConfirming(foundCount:)` | 弹出确认态面板（Loading 状态） |
| `confirmWith(event:)` | 无缝替换为最终态（更新面板内容，不重建窗口） |
| `show(event:)` | 直接弹最终态面板（确认态未触发时的降级路径） |

### 超时兜底

- **5 秒**后如果 `isConfirming == true`，用 proactiveScan 首个结果替换
- `DispatchWorkItem` 实现，Channel A/B 确认时 cancel 该 work item

---

## §5 状态机（Traffic Light Model）

### AppRecord.Status 枚举

| 状态 | 含义 | 灯色 | UI Lane |
|------|------|------|---------|
| `.detected` | 扫描/检测发现，待用户决策 | 🟡 黄灯 | DETECTED |
| `.rejected` | 用户主动丢到垃圾箱 | 🔴 红灯 | REJECTED |
| `.cleared`  | 已放行（quarantine 已移除） | 🟢 绿灯 | CLEARED |

### 状态转换

```
                   addDetectedApp()
(新 app) ───────────────────────→ .detected (🟡)
                                      │
                    ┌─────────────────┼───────────────────┐
                    ▼                 │                    ▼
              markAsCleared()         │            rejectApp()
                    │                 │                    │
                    ▼                 │                    ▼
              .cleared (🟢)           │            .rejected (🔴)
                    │                 │          (trashItem → 占位记录)
                    │                 │
                    ▼ (更新后重新隔离) │
              addDetectedApp()        │
              移回 .detected (🟡) ────┘
```

### 关键规则

1. **去重**：同一 path 已在 `blockedApps` → 不重复添加
2. **回退**：`.cleared` 的 app 如被重新检测 → 移回 `.detected`
3. **清理**：`.rejected` 记录保留 `rejectedDate`，30 天后可清理

---

## §6 Menu Bar 指示器

| 状态 | 显示 | 动画 |
|------|------|------|
| `isScanning == true` | 黄色脉冲 | `PulseModifier`（respects `reduceMotion`） |
| `detectedApps.count > 0` | 红色徽章 + 计数 | 静态 |
| 正常 | 绿色 "✓" | 静态 |

---

## §7 Fallback Scan

在 GK 活动后 500ms 触发的目标化补漏扫描，仅检查 `recentCandidates`（30s 内有 FS 活动的 .app 路径）。

| 属性 | 值 |
|------|-----|
| 触发延迟 | 500ms 去抖 |
| 冷却 | 120s（全局） |
| 验证方式 | GK Assessor（非 SecStaticCode） |
| 数据源 | `recentCandidates`（非全目录遍历） |

---

## §8 权限分级

| 级别 | 目录 | TCC 需求 | 触发时机 |
|------|------|---------|---------|
| Level 0 | `/Applications` | 无 | App 启动即生效 |
| Level 1 | `~/Downloads`, `~/Desktop` | TCC 授权 | 用户引导或场景驱动 |

### 恢复策略

`Persistence.level1Granted == true` 时，启动自动恢复 Level 1 监控（不触发 TCC 弹窗）。

---

## §9 完整时序（Happy Path）

```
T+0.0s   App 启动
T+0.0s   setupPipeline(): Channel A + B 启动
T+0.1s   warmupScan() 后台开始（填充 L2 缓存）
T+3.0s   warmupScan 完成, L2cache=N

... 用户双击了一个 unsigned app ...

T+X.0s     syspolicyd 写 GK 日志
T+X.0s     LogStream 捕获 → onGKActivity()
T+X.0s     isScanning = true（黄灯脉冲）
T+X.03s    proactiveScan() → 发现 M 个 unsigned app
T+X.03s    showConfirming(M)（确认态面板弹出）
T+X+2.5s   FSEvents 检测到文件变化 → 验签 → rejected
T+X+3.5s   Dedup flush → onEvent
T+X+3.5s   confirmWith(event)（无缝替换为最终态）
T+X+3.5s   isScanning = false（绿灯恢复）
T+X+13.5s  面板 10s 后自动关闭
```

### 降级路径

| 条件 | 行为 |
|------|------|
| proactiveScan 返回 0 | 不弹确认态，等 Channel A/B 直接 `show(event:)` |
| Channel A/B 在 5s 内未确认 | 超时兜底，用 proactiveScan 首个结果替换 |
| proactiveScan 被冷却跳过 | 依赖 Channel A/B 独立检出 |

---

## §10 模块清单

| 文件 | 职责 |
|------|------|
| `GreenLightApp.swift` | 管线编排（三通道接线 + 确认态流程 + fallback） |
| `FSEventsWatcher.swift` | Channel B + L2 缓存 + warmupScan + proactiveScan + fallback scan |
| `LogStreamMonitor.swift` | Channel A（syspolicyd 日志解析） |
| `EventDeduplicator.swift` | 1s 窗口合并去重 |
| `DetectionPanelController.swift` | 浮动面板生命周期（确认态 + 最终态） |
| `DetectionConfirmingView.swift` | 确认态 UI（三点呼吸 + 进度条） |
| `DetectionPanelView.swift` | 最终态 UI（app 信息 + 操作按钮） |
| `AppState.swift` | 状态管理 + 持久化 |
| `AppRecord.swift` | 数据模型（三状态枚举） |
| `GatekeeperAssessor.swift` | SecStaticCode 验签封装 |
| `QuarantineRemover.swift` | xattr 移除 + 打开 app |
| `NotificationManager.swift` | 系统通知（可选增强） |
