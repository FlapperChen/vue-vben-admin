# 数据展示模块分析

## 一、概述

数据展示模块是AI_Data项目的重要组成部分，位于`playground/src/views/data-display/`目录下。该模块提供了丰富的数据可视化功能，包括GPU统计、VLLM统计、AnythingLLM统计、Gerrit统计等多个专业领域的监控和展示。

## 二、功能模块清单

### 2.1 当前菜单结构

数据展示模块包含7个子菜单（详见 `playground/src/router/routes/modules/data-display.ts`）：

```
数据展示/
├── 总览 (DataDashboard)      - /data-display/dashboard
├── GPU 统计 (GpuStats)       - /data-display/gpu-stats
├── 使用率 (UsageRate)        - /data-display/usage-rate
├── VLLM 统计 (VllmStats)     - /data-display/vllm-stats
├── API 用户 (ApiUsers)       - /data-display/api-users
├── AnythingLLM (AnythingllmStats) - /data-display/anythingllm-stats
└── Gerrit 统计 (GerritStats) - /data-display/gerrit-stats
```

### 2.2 各模块功能说明

| 模块 | 位置 | 功能描述 |
| --- | --- | --- |
| **总览** | `dashboard/index.vue` | 综合数据概览、日期范围选择、版本控制、统计卡片 |
| **GPU统计** | `gpu-stats/index.vue` | GPU使用率、温度、功耗监控，支持多GPU选择和日期范围 |
| **使用率** | `usage-rate/index.vue` | 资源使用率统计分析 |
| **VLLM统计** | `vllm-stats/index.vue` | TPU使用、缓存命中率、请求队列监控 |
| **API用户** | `api-users/index.vue` | API用户数据展示和分析 |
| **AnythingLLM** | `anythingllm-stats/index.vue` | 用户使用、Token消耗、文件类型分布(玫瑰图) |
| **Gerrit统计** | `gerrit-stats/index.vue` | 代码评审统计、评论占比分析 |

## 三、Git提交历史分析

### 3.1 提交记录总览

数据展示模块共有9次提交（按时间倒序）：

| 提交哈希 | 提交信息 | 日期 | 主要改动 |
| --- | --- | --- | --- |
| `b5de6221` | fix: 优化token消耗总量计算方式 | 2026-04-17 | 修复Token计算逻辑 |
| `ae48f893` | feat: 优化 AnythingLLM 每日统计的文件类型分布饼图为南丁格尔玫瑰图 | 2026-04-16 | 图表优化 |
| `dd93be4e` | fix: 修复AI 评论占比图标显示异常的问题 | 2026-04-16 | Bug修复 |
| `b5afd1e0` | fix: 修正数据更新问题，修复统计总数据的问题 | 2026-04-16 | 数据修复 |
| `669f52f2` | fix: 新增两个菜单卡片：AnythingLLM和Gerrit 统计 | 2026-04-15 | 功能新增 |
| `90850d50` | fix: 修改时间格式为8位 | 2026-04-14 | 格式统一 |
| `d8dad971` | feat: 增加文件同步功能 | 2026-04-14 | 功能新增 |
| `57bf8f91` | 新增AI展示页面 | 2026-04-14 | 初始版本 |
| `2864a57e` | AI_Data | 项目初始化 | - |

### 3.2 详细改动点

#### 3.2.1 功能模块新增/删除

**新增菜单卡片** (`669f52f2`)

- 新增 AnythingLLM统计页面 (526行代码)
- 新增 Gerrit统计页面 (493行代码)
- 路由配置更新：`data-display.ts` 新增2个路由项

#### 3.2.2 功能优化/修复

| 提交 | 改动内容 | 涉及文件 |
| --- | --- | --- |
| `b5de6221` | 优化Token消耗总量计算方式 | `anythingllm-stats/index.vue` |
| `ae48f893` | 饼图优化为南丁格尔玫瑰图 | `anythingllm-stats/index.vue` (+45/-10行) |
| `dd93be4e` | 修复Gerrit评论占比图标显示 | `gerrit-stats/index.vue` (1行修复) |
| `b5afd1e0` | 修正数据更新和统计总数据问题 | 多文件更新 |
| `90850d50` | 时间格式改为8位(YYYYMMDD) | 5个展示页面各+2行 |

#### 3.2.3 数据同步功能

**文件同步系统** (`d8dad971`)

新增脚本：

- `playground/scripts/config.sh` - 配置文件
- `playground/scripts/download-data.sh` - 数据下载脚本 (244行)
- `playground/scripts/setup-cron.sh` - 定时任务设置

页面更新：

- `dashboard/index.vue` - 258行改动
- `gpu-stats/index.vue` - 158行改动
- `vllm-stats/index.vue` - 367行改动
- `usage-rate/index.vue` - 283行改动
- `api-users/index.vue` - 227行改动

#### 3.2.4 初始版本

**AI展示页面** (`57bf8f91`)

- 5个展示页面初始版本
- 共265行新增代码

### 3.3 代码改动统计

| 提交       | 代码行变化      | 主要类型            |
| ---------- | --------------- | ------------------- |
| `b5de6221` | +3721 / -1023   | 数据文件更新        |
| `b5afd1e0` | +13564 / -60159 | 数据清理 + 功能修复 |
| `669f52f2` | +77656 / -9     | **新增2个完整页面** |
| `d8dad971` | +143299 / -345  | **文件同步系统**    |

## 四、数据文件格式变更

### 4.1 时间格式演进

| 阶段 | 格式    | 示例                            | 状态     |
| ---- | ------- | ------------------------------- | -------- |
| 早期 | 6位日期 | `gpu_daily_stats-260411.json`   | 已清理   |
| 中期 | 8位日期 | `gpu_daily_stats-20260413.json` | 当前使用 |
| 备份 | 分目录  | `backup/20260415_083001/`       | 保留     |

### 4.2 数据文件位置

- **当前数据**: `playground/src/assets/data-display/`
- **备份数据**: `playground/src/assets/data-display/backup/`
- **版本控制**: `latest.json` 管理当前版本

## 五、技术栈

- **图表库**: ECharts + vue-echarts
- **UI框架**: Vue 3 + Naive UI / Ant Design
- **路由**: Vue Router
- **数据加载**: 自动化下载脚本 + 定时任务

## 六、关键文件路径

### 6.1 页面组件

```
playground/src/views/data-display/
├── dashboard/index.vue          # 总览页面
├── gpu-stats/index.vue          # GPU统计
├── usage-rate/index.vue         # 使用率统计
├── vllm-stats/index.vue         # VLLM统计
├── api-users/index.vue          # API用户
├── anythingllm-stats/index.vue  # AnythingLLM统计
└── gerrit-stats/index.vue       # Gerrit统计
```

### 6.2 路由配置

```
playground/src/router/routes/modules/data-display.ts
```

### 6.3 数据脚本

```
playground/scripts/
├── config.sh            # 配置文件
├── download-data.sh     # 数据下载脚本
└── setup-cron.sh        # 定时任务配置
```

### 6.4 数据文件

```
playground/src/assets/data-display/
├── latest.json                    # 当前版本信息
├── merged-260417.json             # 合并数据
├── gpu_daily_stats-20260416.json  # GPU日常统计
├── vllm_daily_stats-20260416.json # VLLM日常统计
├── anythingllm_daily_stats-20260416.json # AnythingLLM统计
├── usagerate-20260416.json        # 使用率数据
├── openapi_users-20260416.json    # API用户数据
└── gerrit_metrics-20260416.json   # Gerrit度量数据
```

## 七、功能演进历程

```
时间线:
─────────────────────────────────────────────────────────────►

04-14          04-14          04-14          04-15          04-16          04-17
  │              │              │              │              │              │
  ▼              ▼              ▼              ▼              ▼              ▼
┌─────┐      ┌─────┐      ┌─────┐      ┌─────┐      ┌─────┐      ┌─────┐
│初始 │      │文件 │      │时间 │      │新增 │      │图表 │      │Token│
│版本 │ ───► │同步 │ ───► │格式 │ ───► │菜单 │ ───► │优化 │ ───► │计算 │
│     │      │系统 │      │8位  │      │卡片 │      │玫瑰图│     │优化 │
└─────┘      └─────┘      └─────┘      └─────┘      └─────┘      └─────┘

关键里程碑:
• 57bf8f91: 初始AI展示页面(5个模块)
• d8dad971: 文件同步系统上线
• 669f52f2: AnythingLLM和Gerrit统计上线
• ae48f893: 南丁格尔玫瑰图优化
• b5de6221: Token计算优化
```

## 八、注意事项

1. **数据版本管理**: 通过 `latest.json` 追踪当前数据版本
2. **时间格式**: 所有数据文件统一使用8位日期格式 (YYYYMMDD)
3. **备份策略**: 历史数据保存在 `backup/` 目录
4. **自动同步**: 通过crontab定时执行数据同步任务

## 九、相关文档

- [路由配置](playground/src/router/routes/modules/data-display.ts)
- [GPU统计页面](playground/src/views/data-display/gpu-stats/index.vue)
- [AnythingLLM统计](playground/src/views/data-display/anythingllm-stats/index.vue)
- [数据下载脚本](playground/scripts/download-data.sh)
