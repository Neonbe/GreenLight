# GreenLight 文档索引

> **产品名称**: GreenLight（原 Gatekeeper Companion）  
> **核心定位**: macOS Gatekeeper 智能守卫 — 后台自动检测被拦截应用 + 一键修复 + 安全仪表盘  
> **核心隐喻**: 🚦 红绿灯——为你的应用"放行"

---

## 📁 文档分区

### 1. `docs/` 根目录 —— 工作区（进行中）

- **定位**：正在进行中、等待被开发的 PRD / 任务文档。
- **命名**：`Vx.x.x-rNN-{描述}-{YYYY.MM.DD}.md`
- **流转**：开发完毕后移入 `archive/`。

| 工作区文件 | 状态 |
|:---|:---|
| [`V1.0.0-r02-MVP需求与技术文档-2026.03.02.md`](./V1.0.0-r02-MVP需求与技术文档-2026.03.02.md) | 🟡 评审修订后 |

### 2. `docs/spec/` —— 规范区（长期契约）

- **定位**：长期稳定的架构设计、技术方案、交互规范。原地维护，不移动。
- **命名**：`{snake_case_主题}.md`

### 3. `docs/research/` —— 调研区（纯知识）

- **定位**：竞品分析、可行性评审、技术探索。
- **命名**：`{类型}-{描述}-{YYYY.MM.DD}.md`

### 4. `docs/archive/` —— 归档区（终态）

- **定位**：已完成上线或明确废弃的文档。

---

## 📋 Spec 索引

| spec 文件 | 核心职责 |
|:---|:---|
| [`experiment_results_and_tech_spec.md`](./spec/experiment_results_and_tech_spec.md) | 实验结果记录 + 修订版技术方案（架构、模块、数据流、MVP 范围） |
| [`interaction_flow_spec.md`](./spec/interaction_flow_spec.md) | 交互流程定稿（红绿灯设计语言、A+C 融合模型、完整用户旅程） |
| [`ui_design_spec.md`](./spec/ui_design_spec.md) | UI 视觉设计规范（具象红绿灯、色彩/字体/质感系统、组件规范、交互动画、无障碍） |

### 引用关系

```
V1.0.0 PRD (MVP 需求与技术文档)
    ↑ 综合产出
    ├─ ui_design_spec.md (视觉设计规范)
    │   ↑ 视觉落地基于
    │   └─ interaction_flow_spec.md (交互设计)
    │       ↑ 设计决策基于
    │       └─ experiment_results_and_tech_spec.md (技术方案)
    │              ↑ 实验验证 + 方案修订基于
    │              ├─ research/feasibility_review (可行性评审 8 项发现)
    │              └─ research/competitive_analysis (竞品分析 + 实验方案)
    └─ research/sentinel_deep_dive (Sentinel 拆解 + 复用清单)
```

---

## 🔬 Research 索引

| research 文件 | 核心内容 |
|:---|:---|
| [`feasibility_review-可行性评审报告-2026.03.01.md`](./research/feasibility_review-可行性评审报告-2026.03.01.md) | 产品可行性评审，8 项发现（Sequoia 策略冲突、权限矛盾、log stream 风险、Terminal 注入不可行、路径捕获假设、竞品差异化、Setapp 矛盾、术语问题） |
| [`competitive_analysis-竞品分析与实验方案-2026.03.01.md`](./research/competitive_analysis-竞品分析与实验方案-2026.03.01.md) | Sentinel 深度竞品分析 + Gatekeeper 日志监控三组实验方案（log stream / FSEvents / xattr 权限） |
| [`sentinel_deep_dive-Sentinel深度拆解与借鉴报告-2026.03.02.md`](./research/sentinel_deep_dive-Sentinel深度拆解与借鉴报告-2026.03.02.md) | Sentinel 源码级 repo-researcher 拆解：架构、依赖（AlinFoundation）、社区信号、GreenLight 可借鉴组件三级清单 |

---

## 🔗 权威性优先级

```
1. spec 文档 — 当前有效的设计契约
2. research 文档 — 决策依据，仅供追溯
3. 归档文档 — 历史参考
```

**冲突处理**：若 spec 之间有冲突 → 以后产出的为准，旧 spec 需更新。

---

## 🚀 文档演进路线

> 当前阶段：**Pre-MVP**（技术验证完成，尚未开始编码）

- [x] 可行性评审（8 项发现，全部已回应）
- [x] 竞品深度分析（Sentinel 为事实标准，明确差异化空间）
- [x] 核心技术实验（log stream / FSEvents / xattr 三组实验全部通过）
- [x] 修订版技术方案（基于实验结果重新设计架构）
- [x] 交互流程定稿（红绿灯设计语言 + A+C 融合模型）
- [x] UI 视觉设计定稿（具象红绿灯 + 毛玻璃质感 + 组件规范）
- [x] Sentinel 源码级深度拆解（AlinFoundation 复用 + 三级借鉴清单）
- [x] V1.0 MVP PRD（需求 + 技术 + 任务分解，待评审）
- [ ] 开发启动
