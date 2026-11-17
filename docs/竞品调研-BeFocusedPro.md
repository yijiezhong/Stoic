# 知止 Stoic · 竞品调研报告：Be Focused Pro 2.6

报告日期：2026-11-16

调研对象：/Applications/Be Focused Pro.app（Be Focused Pro 2.6，Build 109，Xwavesoft）

调研方法：REA 工具链（open_binary / inspect_macho / inspect_signature / list_architectures / decode_interface_builder / inspect_analysis_view / open_bundle_resources）＋ 本地资源与数据结构静态取证

调研目的：为「知止 Stoic」番茄钟产品的功能取舍、数据模型与技术选型提供可追溯的依据

估算口径：AI 工时（按 2026-11-16 全局规则），人工动作与日历等待单列，不按人类开发者速度估算

结论一句话：它是一个把「菜单栏计时器 + 任务清单 + 提醒事项同步」做到极致的十年老产品；功能很全，但真实用户只用了核心 20%，这正是知止的机会。

---

## 一、结论摘要

1. **产品形态**：纯原生 AppKit 菜单栏应用（`LSUIElement = true`），没有 Dock 图标；主窗口是「任务列表 + 计时器 + 报告 + 设置」的多标签结构，常驻菜单栏显示剩余时间与快捷操作。
2. **功能广度**：计时（工作/短休/长休/轮次）、任务（截止日、提醒、重复、四象限、预计番茄数、备注、标签、分区）、报告（7 种周期、小时/番茄两种单位、柱状/饼图、CSV 导出）、活动类型（Activity Types，按任务覆盖默认时长）、通知与 50+ 提示音、全局快捷键、7 个事件钩子的 Shortcuts 自动化、网站/应用屏蔽、多设备同步、Pro 订阅。
3. **技术栈偏老但稳**：Objective-C 为主（474 个 PM/EM/XW/TT 前缀类），NIB 驱动 UI，自研 `XWTreeItem` 对象树序列化（`groupStorage.plist`，单文件 plist），AWS C++ SDK（S3 + Cognito）做同步，StoreKit 1 做订阅，WidgetKit 扩展 + LoginItem 助手 + App Intents（11 个动作）。
4. **真实使用数据**（本机聚合，未记录任务名/账号）：3749 条 interval，其中工作 2264 条 × 25 分钟 ≈ 943 小时；时间跨度 2017-11 至 2026-08；32 个任务全部在 Inbox、全部开启「提醒事项同步」；标签、活动类型、筛选模板、报告模板的使用量为 0。
5. **核心洞察**：重度用户九年间只反复使用「开始计时 → 选任务 → 看今天完成了几个」这条主循环。标签、筛选、活动类型、自动化、报告模板等高级能力在这台机器上几乎零使用——**功能多不等于被使用**，知止的 MVP 应把这条主循环做到零摩擦，再把高级能力做成「需要时才发现」。
6. **迁移机会**：Be Focused 的数据是单文件对象树 + 自定义字段，且没有公开导出格式（只有 CSV 导出），新产品的「一键从 Be Focused 导入」是可落地的差异化钩子（见 Backlog P0-09）。

---

## 二、调研对象与方法

### 2.1 制品身份

| 项目 | 值 |
|---|---|
| Bundle ID | `com.xwavesoft.pomodoromac` |
| 版本 / 构建 | 2.6 (109) |
| 最低系统 | macOS 12.0（SDK 26.4 编译） |
| 架构 | Universal 2：x86_64 + arm64 |
| 主二进制 | 15,027,376 字节，SHA-256 `95cd6b33…4c13` |
| 签名 | Apple Mac App Store 签名，Team `85GN4K4XWZ`，硬编码运行时 = false |
| 沙盒 | `com.apple.security.app-sandbox` = true，网络客户端 = true |
| 特殊权限 | Apple Events 临时例外：Safari / Chrome / Edge / Opera / Brave（用于网站屏蔽） |
| App Group | `85GN4K4XWZ.group.com.xwavesoft.pomodoromac`（主 App 与 Widget 共享数据） |
| 分发 | Mac App Store（存在 `_MASReceipt`） |

### 2.2 组件构成

- `Contents/MacOS/Be Focused Pro`：主程序。
- `Contents/PlugIns/Be Focused WidgetExtension.appex`：WidgetKit 桌面小组件。
- `Contents/Library/LoginItems/LaunchAtLoginHelperApp.app`：开机自启助手（ServiceManagement）。
- `Contents/Resources/Metadata.appintents/`：11 个 App Intents 动作（Shortcuts / Siri）。
- `Contents/Resources/*.nib`：约 70 个 NIB，全部界面以 XIB/NIB 搭建（非 Storyboard、非 SwiftUI）。
- `Contents/Resources/*.wav / M4A.zip`：7 组提示音（Alarm clock、Bottles、Chimes、Circles、Complete、Crystal、Grig、Jungle、Mechanical、Old telephone…）各 5 个音量/变体。

### 2.3 使用的 REA 证据

| 操作 | 证据 ID | 用途 |
|---|---|---|
| open_binary | 制品 SHA-256 `95cd6b33…` | 锁定分析对象 |
| inspect_macho（summary） | `ev_a09e9d2170d9778e2a8a71bdf9c193b93fb500f625d334bfc23e5498441d883b` | 结构、69 条 load command、50 个依赖 |
| inspect_analysis_view（dependencies） | `ev_dc1a5a9002d5adfae07dfc3cd269ee9bb309cfd0fdbb87e21ad1938b522f2459` | 依赖清单 |
| inspect_signature | `ev_17d71bd3f263eb866bdb0d4c42cb451a04719df36ac2bc48478f2f3bc3998634` | 权限、沙盒、Team |
| list_architectures | `ev_a81b1704f83ab9a56c7a0e389a85d0b51137d2e27a1061d68262c629fd643ffd` | Universal 2 布局 |
| decode_interface_builder | `ev_77e9324892132b1e8f04c0fcfc98717ec81f0a938b6ac5f9036893e634b8afb1` | 6934 个 IB 对象、11 个文档省略 |
| inspect_analysis_view（nodes） | `ev_4c50135c1574a12ed12e7f0e2ec07a25be4e9006f8e8b3454998bfe126b220a7` | NIB 控件、菜单项、本地化串 |

> 说明：本次 REA 会话只加载了 macOS 原生检查与制品图两类引擎，没有 Ghidra/IDA 类反编译引擎，因此**没有伪代码级证据**。所有结论来自制品结构、符号、资源、序列化数据与本地化文案；推断项已单独标注。

---

## 三、产品定位与商业模型

### 3.1 定位

「菜单栏里的番茄钟 + 轻量任务清单」。它不试图做项目管理工具，而是做**工作节奏的外部节拍器**：点一下开始，25 分钟后提醒你休息，一整天自动循环，晚上看报告。

### 3.2 免费版 vs Pro 版（从文案与代码双重验证）

| 能力 | 免费（Lite） | Pro |
|---|---|---|
| 计时、任务、通知 | 有 | 有 |
| 广告横幅 | 有（`AdvertisingPackage.zip`） | 无 |
| 网站 / 应用屏蔽 | 无（文案：Upgrade to Pro version to block…） | 有 |
| Shortcuts 自动化 | 无（文案：Upgrade to Pro version to run shortcuts…） | 有 |
| CSV 导出 | 无（Pro 权益列表） | 有 |
| 多设备同步 | 无 | 有（需 iOS 版另购） |
| 标签与筛选 | 无（Pro 权益列表） | 有 |
| 每日自动备份 | 无 | 有 |

### 3.3 商业判断

- 订阅制（月 / 年 / 年订阅三档，StoreKit 1 实现），另有「恢复购买」。
- 变现点设计得很「克制」：核心计时永远免费，付费买的是**自动化、屏蔽、同步、导出**——即「从个人工具变成工作流基础设施」的那部分。
- 独立开发者（Xwavesoft）产品，九年持续更新，靠 App Store 自然流量与 iOS 版交叉引流。

---

## 四、技术架构

### 4.1 分层

```
┌────────────────────────────────────────────┐
│ UI 层：AppKit + NIB（约 70 个 nib）          │
│  PMRootController / PMTasksViewController   │
│  PMPomodorosView / PMTimerViewController    │
│  PMSettingsViewController / PMReports…      │
├────────────────────────────────────────────┤
│ 控制器层：PMTabBarController / Navigation    │
│  PMRoundManager（轮次）/ PMPomodoroTimer     │
├────────────────────────────────────────────┤
│ 领域模型：PMTask / PMPomodoro / PMScript     │
│  PMAppSettings / EMTag / PMWorkType         │
│  （全部继承自 XWTreeItem 对象树）             │
├────────────────────────────────────────────┤
│ 持久化：groupStorage.plist（单文件 plist）    │
│  UserDefaults（设置、凭据、埋点）             │
│  syncStatus.plist（扩展同步状态）             │
├────────────────────────────────────────────┤
│ 同步：AWS S3 + Cognito Identity（C++ SDK）    │
│  iCloud KVStore（辅助）                       │
│  自建埋点：xwavesoft.com/aws/account/track*.php│
└────────────────────────────────────────────┘
```

### 4.2 关键依赖（REA 取证）

Cocoa / AppKit / Foundation、AVFoundation + AVFAudio + AudioToolbox（提示音）、ServiceManagement（登录项）、AppIntents、CoreLocation（时区/地区判断）、Security、CFNetwork + libcurl（网络）、libsqlite3（可能用于报告或缓存）、Accelerate、QuartzCore、**AWS C++ SDK（S3、Cognito Identity）**。

没有第三方 UI 框架、没有 Electron、没有 Sparkle（走 App Store 更新）。

### 4.3 值得注意的实现选择

| 选择 | 观察 | 对知止的启示 |
|---|---|---|
| 单文件 plist 存全量数据 | 723 KB，含 3749 条 interval | 简单、可整体同步；但随时间线性膨胀，写放大明显。知止应用 SQLite/SwiftData 分表 |
| 对象树 + `className` 字段 | 每个对象带 `className/isGroup/isExpanded` | 便于通用序列化与撤销；但 schema 演进靠 `versionNumber`（当前 6）+ 迁移代码 |
| 计时状态存时间戳而非倒计时 | `startTimeStamp / pauseTimeStamp / resumeTimeStamp / skipTimeStamp` + `duration` | 抗休眠、抗重启、可恢复；知止应照抄这个设计 |
| NIB 驱动 UI | 70 个 nib、6634 个 IB 对象 | 老派但可控；知止用 SwiftUI 可在同等功能下减少 70% 代码 |
| AWS 自建同步 | S3 对象 + Cognito 登录 | 成本与账号体系都要自己扛；知止优先 CloudKit |

### 4.4 数据结构（可直接复用的字段级模型）

**PMTask（任务）**——32 个字段，覆盖了主流 GTD 需求：

```
id, title, note, creationTime, completionTime, completionState,
dueDate, remindMeDate, allDayTask, allDayTaskRemindTime,
repeatType, repeatInterval, repeatIntervalUnits, repeatDaysOfWeek, endRepeatDate,
isImportant, isUrgent, moveToUrgentTimeinterval,
expectedIntervals, workTypeID, calendarID, isSyncingWithCalendar,
isSyncingWithReminders, isSyncingWithPomodoro, isInbox, creationApproach,
creationInterval, creationIntervalUnits
```

**PMPomodoro（番茄记录）**——13 个字段：

```
id, parentTaskID, parentPomodoroID, isRest, startTimeStamp, resumeTimeStamp,
commonTimeInterval（秒）, roundIndex, completionState
```

**PMPomodoroTimer（运行中的计时器）**——在 `PMSettings` 同级单独持久化：

```
duration, startTimeStamp, pauseTimeStamp, resumeTimeStamp, skipTimeStamp,
isRest, roundIndex, parentPomodoroID, completionState
```

> 这两者的分离是关键设计：**记录**（已完成的历史）与 **运行态**（当前计时器）分开存，应用崩溃/重启后能接着跑。

**PMAppSettings（计时设置）**——44 个字段，核心项与默认值：

| 字段 | 默认 | 含义 |
|---|---|---|
| `pomodoroLenght`（原文拼写如此） | 25 | 工作段分钟数 |
| `restTime` | 5 | 短休分钟数 |
| `bigRestTime` | 5（建议默认 15/30） | 长休分钟数 |
| `pomodorosInPeriodCount` | 8 | 每轮几个工作段后长休 |
| `pomodorosPerDay` | 24 | 每日目标番茄数 |
| `isAutorepeatEnabled` | true | 自动开始下一段 |
| `autorepeatMode` | 0 | 自动重复模式（工作/休息是否都自动） |
| `notifyAboutFinishOnOSX` | true | 系统通知 |
| `showTimerInStatusBarOSX` | true | 菜单栏显示计时 |
| `nonSleepModeEnabled` | false | 计时期间防休眠 |
| `maxPauseTimeInterval` | UINT64_MAX | 暂停上限（无限制） |
| `chronometrOnBreakEnabled` | false | 休息段用正计时 |
| `runOnStart` | false | 启动即开始计时 |
| `soundPomodoroFinishedIndex` 等 | 101 | 提示音索引 |

**EMAppSettings（任务区设置）**——分区、默认创建方式、与提醒事项/日历同步开关。

**PMScript（自动化）**——`{ type, title, script, enabled }`，按事件绑定一个「快捷指令名称」。

**其他容器**：`PMTasksList`、`EMTagsContainer`、`PMWorkTypesManager`、`EMFilterTemplateManager`、`PMUIColorSetsManager`、`PMSyncStatusItem`。

---

## 五、信息架构与核心交互

### 5.1 主窗口

从类名与 NIB 结构可确定四个一级区域：

1. **任务列表（Task list）**：`PMTasksViewController` + `PMTasksTableView` + 搜索框 + 分段控件（列表/筛选）+ 同步控件；支持拖拽排序（`NSPanGestureRecognizer`）、右键菜单、行内编辑。
2. **计时器（Timer）**：`PMTimerViewController` + `PMPomodorosView`（当天的 interval 列表）+ 圆环进度（`PMRoundedProgressView`）+ 浮动面板（`PMFloatingPanelView`）。
3. **报告（Reports）**：`PMReportsWindowController`，含周期选择、单位切换（Hours / Intervals）、柱状图 `PMBarChartView`、饼图 `PMPieChartView`、图例 `PMLegendView`、CSV 导出。
4. **设置（Settings）**：`PMSettingsViewController`，表格式设置行（`PMSettingsRowObject` 驱动），分区为：General、Intervals、Notifications & Sounds、Automation、Appearance、Blocking、Account、Shortcuts、About。

### 5.2 菜单栏交互

- 菜单栏常驻显示剩余时间（`showTimerInStatusBarOSX`）。
- 左键点开主窗口；右键（或 Ctrl+点击）弹出快捷菜单：开始/暂停、跳过、选择任务、报告、设置、退出（文案明确写了这个操作提示）。
- 全局快捷键通过 `MASShortcut` 实现，本机默认值解码为：**⌘⇧R 开始/暂停**、**⌘⇧B 停止/跳过**。

### 5.3 任务详情

`Task details` 是独立面板，包含：任务名、备注（富文本 `EMNotesTextView`）、截止日（`PMDatePicker` / 日历弹出 `XWCPullDownCalendar`）、提醒时间、重复规则、重要/紧急、预计番茄数、活动类型、标签、日历/提醒事项同步开关。

### 5.4 首次使用与引导

- 帮助提示卡片（`PMHelpTipsViewController`）。
- What's New 窗口（`XWWhatsNewWindow`，`WhatsNewLastShownVersion` 记录版本）。
- 权限引导（Apple Events 授权失败时提示去「系统设置 → 隐私 → 自动化」）。

---

## 六、功能矩阵

评级：● 完整 ／ ◐ 部分 ／ ○ 无。

| 模块 | 能力 | Be Focused Pro | 备注（证据） |
|---|---|---|---|
| 计时 | 工作 25 / 短休 5 / 长休 5-30 | ● | 设置项齐全 |
| 计时 | 每轮番茄数（默认 8）后长休 | ● | `pomodorosInPeriodCount` |
| 计时 | 自动开始下一段 / 多种自动模式 | ● | `isAutorepeatEnabled`、`autorepeatMode` |
| 计时 | 暂停、跳过、重置、手动改时长 | ● | 跳过有确认提示 |
| 计时 | 计时中防休眠 | ● | `nonSleepModeEnabled` |
| 计时 | 休息段正计时（chronometer） | ● | `chronometrOnBreakEnabled` |
| 计时 | 跨重启恢复 | ● | `PMPomodoroTimer` 持久化 |
| 计时 | 退出时「保留计时继续跑」 | ● | 文案：Quit and leave timer running |
| 任务 | 增删改、完成、拖拽排序 | ● | |
| 任务 | 截止日 / 提醒 / 全天任务 | ● | |
| 任务 | 重复（日周月年 + 间隔） | ● | `repeatType/Interval/Units/DaysOfWeek` |
| 任务 | 重要 / 紧急四象限 | ● | |
| 任务 | 预计番茄数 vs 实际 | ● | `expectedIntervals` + 报告差值 |
| 任务 | 备注（富文本） | ● | `EMNotesTextView` |
| 任务 | 标签与筛选 | ● | `EMTag`、`EMFilterTemplate`、`EMTasksFilter` |
| 任务 | 搜索 | ● | `PMSearchField` |
| 任务 | 分区（Inbox / Today / Urgent…） | ● | `EMAppSettings` 的 `*SectionColor/Title` |
| 任务 | 与「提醒事项」同步 | ● | 双向，`isSyncingWithReminders` |
| 任务 | 与「日历」同步 | ● | `EMCalendarSyncManager` |
| 记录 | 每个 interval 的起止、时长、轮次 | ● | `PMPomodoro` |
| 记录 | 可编辑 / 补录 / 删除单条 | ● | 文案：interval 编辑、交叉校验提示 |
| 报告 | 今天/昨天/本周/本月/今年/自定义 | ● | |
| 报告 | 小时 或 番茄数 两种口径 | ● | |
| 报告 | 柱状图 / 饼图 / 图例 | ● | `PMBarChartView`、`PMPieChartView` |
| 报告 | 按任务 / 标签 / 活动类型汇总 | ● | 依据类名与控件，推断（附录 B） |
| 报告 | 预计 vs 实际差值 | ● | |
| 报告 | CSV 导出 | ● | Pro |
| 活动类型 | 自定义每类任务的计时参数 | ● | Activity Types，按任务覆盖默认 |
| 通知 | 系统通知（banner）+ 自定义提示音 | ● | 50+ 音效 |
| 通知 | 结束前提醒（work/rest 各两个提醒点） | ● | `*SoonFinishNotificationInterval1/2` |
| 通知 | 音量独立控制 | ● | |
| 快捷键 | 全局开始/暂停、停止 | ● | ⌘⇧R / ⌘⇧B |
| 自动化 | 7 个事件钩子 → 运行快捷指令 | ● | 事件：Work Started/Paused/Ended、Rest Started/Ended、Task Completed、Task Selected |
| 系统集成 | WidgetKit 小组件 | ● | |
| 系统集成 | 11 个 App Intents（Shortcuts/Siri） | ● | Add/Delete/Complete/Select Task、Start/Pause/Skip、Timer Status/Duration/Type |
| 系统集成 | URL Scheme | ● | `pomodoromac://`（与 iOS 版互通） |
| 专注 | 屏蔽指定网站（黑白名单） | ● | Apple Events 控制 5 个浏览器 |
| 专注 | 屏蔽指定应用 | ● | 检测到运行则提示/退出 |
| 数据 | 多设备同步（Mac + iOS，需另购） | ● | AWS S3 + Cognito |
| 数据 | 本地/服务器数据二选一 + 冲突选择 | ● | 有明确文案与流程 |
| 数据 | 每日自动备份 | ● | Pro |
| 数据 | CSV 导出 | ● | Pro |
| 账号 | 注册 / 登录 / 忘记密码 / 恢复购买 | ● | `TTLoginViewController` 等 |
| 商业化 | 订阅 + 广告（免费版） | ● | StoreKit 1 |
| 外观 | 浅色/深色、主题色集 | ● | 601 个颜色资产、`PMUIColorSetsManager` |
| 本地化 | 中/英等 | ◐ | 只有 `en.lproj` 与 `Base.lproj`（调研包为英文版；是否支持中文未验证） |

**明显缺口**（即知止的机会）：

- 没有「专注时长段」概念（如 90 分钟深度工作块）；只有番茄。
- 没有「中断记录」（被打断几次、原因）。
- 没有「周复盘 / 趋势洞察」的叙事化输出，只有静态图表。
- 屏蔽依赖 Apple Events，权限脆弱、只覆盖 5 个浏览器；不支持 Arc/Chromium 分支。
- 同步依赖自建 AWS 账号，迁移与隐私成本高。
- 无公开数据导入格式（只有 CSV 导出），迁移到别家或从别家迁入都难。
- 全英文 UI（调研包），中文用户需要汉化。

---

## 七、关键机制拆解

### 7.1 计时状态机（可直接照搬）

```
idle ──start──▶ running ──pause──▶ paused ──resume──▶ running
                  │  │                                  │
                  │  └──skip / 到时──▶ completed ──▶ 下一段（work ⇄ rest）
                  └──quit（保留）──▶ running（进程退出，时间戳仍在）
```

要点：

- 状态以**时间戳**表达，而不是内存里的倒计时。恢复时用 `now - resumeTimeStamp` 重算，天然抗休眠、抗时钟漂移（需注意系统时间被手动修改的情况）。
- `roundIndex` 记录当前是第几轮，长休由 `roundIndex % pomodorosInPeriodCount` 决定。
- 跳过与完成用不同 `completionState`（本机数据 3 = 完成，4 = 跳过；此为推断，见附录 B）。

### 7.2 通知与声音

- 本地通知（`PMLocalPushNotificationConfigurator`），banner 样式（Info.plist `NSUserNotificationAlertStyle`）。
- 提示音分「工作结束 / 休息结束 / 结束前提醒 ×2 / 背景音」多路，音量独立。
- 计时中每段结束都有通知；休息结束前可再提醒一次。

### 7.3 网站与应用屏蔽

- 实现：通过 Apple Events 控制浏览器（Safari/Chrome/Edge/Opera/Brave）打开或关闭指定 URL；对应用则检测进程并提示退出。
- 模式：黑名单（屏蔽列表）与白名单（只允许列表）。
- 权限脆弱点：需要「自动化」授权，系统升级后常失效，文案里专门解释了如何重新授权。
- **对知止的启示**：这条路在 macOS 上体验差且审核风险高。更好的选择是浏览器扩展（Manifest V3 + native messaging）+ 可选 Hosts 代理；MVP 先做「应用屏蔽 + 站点提醒」而不是硬屏蔽。

### 7.4 自动化（Shortcuts）

- 7 个事件各绑定一个「快捷指令名」；事件发生时调用 `shortcuts run`。
- 用途举例（官方文案）：开始计时时打开专注模式、运行自定义脚本、触发其他动作。
- 免费版禁用，是 Pro 的核心卖点之一。

### 7.5 同步

- 账号：AWS Cognito（`XWAWSCredentials*`，含 refresh token）。
- 存储：S3 上的用户数据对象（`-aws-sync-queue`、`XWSyncDataCache` 做本地缓存与冲突处理）。
- 冲突：本地与服务端不一致时弹窗让用户选「用本地」或「用服务器」。
- 扩展同步：`syncStatus.plist` 记录 `needUpdateWidget` / `needUpdateWatchApp`，通过 App Group 通知 Widget。
- 另有 iCloud KVStore 标识（`85GN4K4XWZ.com.xwavesoft.pomodoro`），作为轻量同步/迁移通道。

### 7.6 报告

- 周期：Today / Yesterday / This week / This month / This year / Custom。
- 单位：Hours / Intervals。
- 维度：任务、标签、活动类型；图表 + 图例 + 表格。
- 导出：CSV（Pro）。
- 本机 `reports_period_idx = 8`，推测为「今年」或自定义周期（未验证）。

### 7.7 订阅与账号

- StoreKit 1：`XWSMProduct` / `XWSMPurchase` / `XWSMPurchases`，月/年/年订阅三档。
- 账号体系与同步账号合一（同一套 Cognito 凭据），登录后可「从服务器恢复」或「用本地覆盖服务器」。
- 恢复购买、忘记密码、改密码均有独立界面。

---

## 八、视觉与设计资产

- 主色：绿 `#62C6A6`（`app_green_color`），红 `#FD8F86`（`app_red_color`），中性灰系 `#F3F3F3 / #F5F5F7 / #7B7B7B`。
- 完整的浅色 + 深色两套颜色资产（601 条），命名语义化（`about_back_color`、`check_done_color`、`date_header_back_color`…）。
- 内置 3 个 SF UI Display 字重（常规/中/粗），说明它在系统字体之外做了视觉统一。
- 版式：任务行左对齐 + 右侧番茄数胶囊；计时器页以圆环 + 大号数字为主视觉；报告页柱状图 + 图例 + 表格。
- 图标：`AppIcon.icns`（43 KB）+ Assets.car 中的多尺寸图标；Widget 有独立背景色资产（`WidgetBackground`）。

对知止的建议：不要复刻这套「iOS 6 时代」的拟物灰调。知止的视觉主张应是「安静、留白、少颜色」——黑白灰 + 一个强调色（建议暖橙或青），圆环 + 大数字 + 极简任务行，与「知止而后有定」的气质一致。

---

## 九、优势、短板与机会窗

### 9.1 它做对了什么

1. **零摩擦启动**：菜单栏一点即开始，不打断当前工作。
2. **主循环极短**：开始 → 完成 → 自动进入休息 → 继续，几乎不需要鼠标。
3. **抗中断**：时间戳持久化，重启、休眠、崩溃都能接上。
4. **任务与提醒事项同步**：用户可以在系统「提醒事项」里管理任务，App 只负责计时。这降低了它的输入负担。
5. **克制的付费墙**：核心永远免费，付费买自动化与同步。

### 9.2 它的结构性短板

1. **功能债**：70 个 NIB、474 个类、9 年叠加，新功能成本高，UI 一致性差。
2. **同步自建**：账号、S3、Cognito 全自扛，隐私与合规成本高，跨平台扩展难。
3. **屏蔽实现脆弱**：Apple Events 权限随时失效，浏览器覆盖有限。
4. **报告只有「看」没有「懂」**：图表齐全，但没有结论、没有建议、没有周复盘。
5. **数据锁定**：单文件 plist + 只有 CSV 导出，迁移成本高。
6. **中文体验**：调研包无中文本地化（只有 en/Base），中文用户靠系统级英文界面。

### 9.3 机会窗（知止可以赢的地方）

| 机会 | 依据 | 知止做法 |
|---|---|---|
| 迁移友好 | 无公开导入格式 | 一键导入 Be Focused 的 groupStorage.plist（只读解析）+ CSV |
| 本地优先 + 可携带 | 同步绑定 AWS 账号 | SwiftData + CloudKit 可选，数据随时导出 JSON/CSV/SQLite |
| 真正的「专注块」 | 只有 25 分钟番茄 | 支持 25/50/90 分钟专注块 + 番茄混合模式 |
| 中断与复盘 | 无中断记录 | 记录被打断次数/原因，周报给出「你的高效时段」 |
| 系统级专注 | 只做浏览器屏蔽 | 接入 macOS 专注模式（Focus Filter）+ 应用屏蔽白名单 |
| 中文优先 | 无中文本地化 | 中文文案打磨（「知止」「入定」「出定」），英文并列 |
| 隐私叙事 | 埋点上报设备 ID | 默认零遥测，可选匿名统计，隐私政策可读 |

---

## 十、知止的定位与设计原则

### 10.1 一句话定位

**知止 = 会复盘的番茄钟。** 它不只计时，还帮你看见「什么时候最容易进入状态、什么时候总被打断」。

- 中文名：知止（《大学》「知止而后有定，定而后能静」）。
- 英文名：Stoic（斯多葛学派：只关注可控之事，把注意力当成最稀缺的资源）。
- 目标用户：知识工作者、独立开发者、备考学生——已经在用番茄钟，但对「只有计时没有洞察」不满的人。
- 平台：macOS 优先（菜单栏），后续 iOS（同一套 SwiftData + CloudKit）。

### 10.2 五条设计原则

1. **主循环三步以内**：开始 → 专注 → 休息，任何时候不超过两次点击。
2. **默认安静**：没有广告、没有红点、没有弹窗营销；通知只在段落结束时出现。
3. **数据是你的**：本地优先、可导出、可删除、可迁移；默认不上传。
4. **只加会用的功能**：新功能必须能在「周复盘」里产生价值，否则不进 M1。
5. **中文不是翻译，是重写**：「知止」「入定」「出定」「一炷香」等词建立品牌记忆。

### 10.3 建议的技术选型

| 层 | 建议 | 理由 |
|---|---|---|
| UI | SwiftUI（macOS 14+） | NIB 方案维护成本高；SwiftUI 做菜单栏 + 圆环 + 列表最省 |
| 菜单栏 | `MenuBarExtra` | 原生、支持自定义标签 |
| 数据 | SwiftData（或 Core Data 兜底） | 分表存储、支持迁移、与 CloudKit 集成 |
| 计时 | 时间戳状态机（照抄 Be Focused） | 抗休眠/重启，已验证 |
| 通知 | UserNotifications + Focus Filter | 系统级专注联动 |
| 自动化 | App Intents（Shortcuts/Siri） | 直接对标 11 个动作 |
| 同步 | CloudKit（M3 再考虑自建） | 零服务器成本、隐私叙事友好 |
| 屏蔽 | 浏览器扩展 + 原生消息（可选） | Apple Events 方案体验差、审核风险高 |
| 支付 | StoreKit 2 | 订阅管理、退款处理更现代 |
| 导出 | JSON + CSV + SQLite 快照 | 可携带性即卖点 |

---

## 十一、Backlog 待办清单

> 估算口径（按本机 2026-11-16 新规则）：**AI 工时** = agent 实际执行时间（读码、写码、构建、跑测试、修错），已含约 30% 返工余量；**人工** = 必须由人完成的动作（授权、登录、付款、主观验收），单独标注；**日历时间** = 不可压缩的外部等待（App Store 审核、外部测试）。
> 假设：需求明确、本机可构建、无网络/账号阻塞；人类独立开发的参考值另列，不作排期基准。
> 同口径下本项目合计：**约 58 AI 工时（7–8 个专注工作日）**，人类独立开发参考约 14 周（70 个工作日）。

### M0 · 地基（目标：能在菜单栏跑起来并计时）

| ID | 条目 | 验收标准 | AI 工时 | 人工 / 外部 |
|---|---|---|---|---|
| P0-01 | 建立 macOS 工程（SwiftUI，macOS 14+），配置 `LSUIElement` 菜单栏应用与 App Sandbox | 启动后无 Dock 图标，菜单栏出现图标，点击弹出计时面板 | 0.5 h | — |
| P0-02 | 计时状态机：`idle / running / paused / completed`，以时间戳表达状态 | 手动改系统时间 ±1 小时后仍按真实流逝秒数计时；强杀进程重启后剩余时间误差 ≤1 秒 | 1.5 h | — |
| P0-03 | 计时数据持久化（工作段/休息段/轮次/关联任务） | 关闭 App 再打开，运行中的计时器自动恢复且不重复计一段 | 1 h | — |
| P0-04 | 主界面：圆环进度 + 剩余时间 + 开始/暂停/跳过 三个按钮 | 1920×1080 与 1440×900 下布局不破；深色模式可读 | 1.5 h | 人工验收 10 min（视觉判断） |
| P0-05 | 段落结束的本地通知 + 声音 | 段落结束时 1 秒内出现 banner；静音/免打扰下不响但记录完成 | 0.5 h | 人工 5 min（首次通知授权） |
| P0-06 | 全局快捷键：开始/暂停、跳过 | 任意前台应用下 ⌘⇧R / ⌘⇧B 生效；与系统冲突时给出可换绑入口 | 1 h | 人工 2 min（键盘组合确认） |
| P0-07 | 菜单栏快捷菜单（右键）：开始、暂停、跳过、选择任务、退出 | 右键菜单项状态随计时器状态实时变化 | 1 h | — |
| P0-08 | SwiftData schema：Task / Interval / Settings / DaySummary | 迁移脚本能在旧库上执行；schema 版本号写入 | 1 h | — |
| P0-09 | Be Focused 只读导入器（解析 `groupStorage.plist` 的 PMTask / PMPomodoro） | 用本机 723 KB 真实数据跑一遍：3749 条 interval 全部落库，任务数 32 一致，抽样 10 条时间戳完全吻合 | 2 h | — |
| P0-10 | 崩溃与异常恢复：记录最后已知状态，启动时校验 | 计时中强制退出 3 次，每次重启都能给出「继续 / 作废」选择 | 0.5 h | — |

**M0 合计：约 10.5 AI 工时（约 1.5 个专注日）。出口标准**：能连续完成 4 个番茄 + 1 次长休，退出重启不丢状态，数据导入无损。

### M1 · 可用 MVP（目标：可以替代 Be Focused 日常使用）

| ID | 条目 | 验收标准 | AI 工时 | 人工 / 外部 |
|---|---|---|---|---|
| P1-01 | 任务列表：增删改、完成、拖拽排序 | 100 个任务下滚动 60fps；排序结果持久化 | 2 h | — |
| P1-02 | 任务详情面板：标题、备注、截止日、提醒、重复、重要/紧急、预计番茄数 | 每个字段可改可清空；空标题拒绝保存并提示 | 2 h | — |
| P1-03 | 选择任务后开始计时，interval 归属该任务 | 计时结束的记录能在任务下聚合；切换任务不影响已开始的段 | 1 h | — |
| P1-04 | 当天 interval 列表：时间、时长、任务、状态，可编辑与删除 | 编辑时长后当日统计同步刷新；交错时间给出提示 | 1.5 h | — |
| P1-05 | 自动轮次：每 N 个工作段后长休，可选自动开始 | 设置 N=8 时，第 8 段后自动进入长休；关闭自动开始后停在待开始 | 0.5 h | — |
| P1-06 | 设置页：计时参数、通知与声音、外观、开机自启 | 所有设置立即生效（无需重启）；有「恢复默认」 | 2 h | — |
| P1-07 | 与「提醒事项」双向同步（EventKit） | 在提醒事项里改标题/完成，App 内 2 秒内可见；反向亦然 | 3 h | 人工 5 min（EventKit 首次授权） |
| P1-08 | 中文本地化（简中 + 英文） | 所有用户可见文案走 String Catalog；无硬编码中文/英文 | 1.5 h | 人工 15 min（中文用词定稿） |
| P1-09 | 首次启动引导：3 步内完成「选一个任务 → 开始第一个番茄」 | 新用户从打开到开始计时 ≤30 秒 | 0.5 h | — |
| P1-10 | 单元测试与 UI 冒烟：状态机、迁移、导入、同步 | 状态机覆盖 12 条路径；CI 上 5 分钟内跑完 | 1.5 h | — |

**M1 合计：约 15.5 AI 工时（约 2 个专注日）。出口标准**：连续用一周不需要打开 Be Focused；数据不丢；中文界面无残留英文。

### M2 · 差异化（目标：做出「会复盘」的独特性）

| ID | 条目 | 验收标准 | AI 工时 | 人工 / 外部 |
|---|---|---|---|---|
| P2-01 | 今日概览卡：完成番茄、专注时长、被打断次数、当前连续天数 | 与 interval 明细逐条对得上，误差为 0 | 1 h | — |
| P2-02 | 中断记录：暂停次数/原因（打扰/切换任务/主动休息） | 每段区间内可记录 0–N 次中断；统计页可按原因聚合 | 1.5 h | — |
| P2-03 | 周复盘：自动生成一段可读结论（高峰时段、任务分布、对比上周） | 结论中的每个数字都能点开看到原始记录 | 3 h | 人工 10 min（读一遍是否像人话） |
| P2-04 | 专注块模式：25 / 50 / 90 分钟可选，与番茄模式共存 | 切换模式不影响历史记录；不同模式的统计分开呈现 | 1 h | — |
| P2-05 | 聚焦模式联动（Focus Filter） | 开始专注时自动进入系统「工作」专注；结束后恢复 | 1.5 h | 人工 5 min（专注模式授权） |
| P2-06 | WidgetKit 小组件：今日进度 + 快速开始 | 小/中/大三种尺寸；点击能直接开始下一段 | 2 h | — |
| P2-07 | App Intents：开始/暂停/跳过、加任务、完成任务、查询状态 | 在「快捷指令」App 中可见 11 个动作并全部可执行 | 2 h | — |
| P2-08 | 数据导出：JSON + CSV + SQLite 快照 | 导出的 JSON 可被重新导入且数据一致（往返测试） | 1 h | — |
| P2-09 | 应用屏蔽（白名单/黑名单） | 计时中切到黑名单应用时给出一次提醒；白名单模式只允许清单内应用 | 2.5 h | — |
| P2-10 | 浏览器扩展（可选安装）：站点屏蔽 | 扩展安装后，黑名单站点在专注期间被拦截；未安装时 App 不报错 | 3 h | 人工 15 min（装扩展实测） |

**M2 合计：约 18.5 AI 工时（约 2.5 个专注日）。出口标准**：周复盘能让人愿意每周打开一次；Widget + 快捷指令让「不开 App 也能用」。

### M3 · 商业化与发布

| ID | 条目 | 验收标准 | AI 工时 | 人工 / 外部 |
|---|---|---|---|---|
| P3-01 | StoreKit 2 订阅：月 / 年，含免费试用 | 沙盒账号能完成购买、续订、取消、恢复；状态实时反映到 UI | 2.5 h | 人工 10 min（沙盒账号登录） |
| P3-02 | 免费版边界：核心计时免费，屏蔽/自动化/导出/同步为 Pro | 每处付费墙都有明确的「为什么值得」文案与恢复入口 | 1 h | — |
| P3-03 | 数据同步（CloudKit 或自建，二选一） | 两台 Mac 登录同一 Apple ID，5 秒内同步一致；冲突有明确选择 | 4 h | 人工 10 min（双机登录） |
| P3-04 | 匿名遥测（默认关闭，可开） | 开关关闭时抓包无任何上报；开启时只上报聚合指标 | 1 h | — |
| P3-05 | 崩溃收集与符号化（MetricKit / Sentry） | 能定位到具体函数与行号 | 1 h | — |
| P3-06 | 隐私政策、服务条款、App Store 素材与截图 | 审核一次通过；隐私标签与实际行为一致 | 2 h | 人工 1 h（素材过目、隐私标签核对） |
| P3-07 | 灰度发布与回滚方案（TestFlight + 分阶段发布） | 10 个外部测试者使用 1 周无 P0 缺陷 | 0.5 h | 日历 1 周（外部测试者真实使用） |
| P3-08 | 官网/落地页 + 迁移指南（从 Be Focused 导入） | 落地页转化路径可追踪；迁移指南步骤 ≤5 步 | 1.5 h | 人工 20 min（文案确认） |

**M3 合计：约 13.5 AI 工时 + 人工约 2 h + 外部等待 1 周（外部测试）与 1–3 天（App Store 审核）。**

### 11.1 时间口径说明

- **为什么不是「人日」**：写代码、跑测试、调试、写文档这些动作由 AI 主导时，单条 backlog 的实际执行时间是分钟到小时级，不是天级。用「人日」排期会把项目放大 8–12 倍。
- **哪些时间压不掉**：App Store 审核（1–3 天）、外部测试者真实使用（1 周）、人工授权与账号登录（每次 2–15 分钟）、主观视觉验收（每次 10–60 分钟）。这些是日历时间，不是 AI 工时。
- **估算的不确定性来自环境**：Xcode 版本、签名配置、EventKit/StoreKit 沙盒账号、网络上限。建议排期时在 AI 工时上再加 30% 阻塞预算。
- **人类参考值**（仅对照，不作基准）：同样的 38 条，一个人独立做约 14 周（含设计、调试、上架）。

### 11.2 明确不做（防止范围膨胀）

- 不做团队协作 / 共享看板。
- 不做跨平台（Windows/Android）首版；先把 macOS 做透。
- 不做「任务优先级算法/AI 排序」，除非周复盘证明用户需要。
- 不做系统级网络拦截（`/etc/hosts` 需 root、Mac App Store 审核风险高）。
- 不做富文本笔记编辑器（纯文本 + Markdown 足够）。

### 11.3 风险登记

| 风险 | 影响 | 缓解 |
|---|---|---|
| EventKit 权限被拒 | 任务同步不可用 | 降级为纯本地，并在设置页解释如何开启 |
| 屏蔽功能审核被拒 | Pro 卖点缺失 | 首版不上架屏蔽，用「应用提醒」替代；扩展单独分发 |
| Be Focused 升级改数据结构 | 导入器失效 | 导入器按 schema 版本号分支，失败时给出明确提示而非崩溃 |
| CloudKit 冲突 | 数据错乱 | 首版只做「单设备 + 手动导出」，同步放 M3 |
| 订阅定价失误 | 收入不足 | 先做 3 档价格实验，观察转化与退款率 |
| 环境阻塞（签名/沙盒账号/Xcode） | AI 工时失真 | 每个里程碑预留 30% 阻塞预算；阻塞项当天上报 |

### 11.4 里程碑（AI 工时 + 日历时间）

| 里程碑 | AI 工时 | 日历时间（含人工/外部等待） | 成功指标 |
|---|---|---|---|
| M0 | 10.5 h | 1–2 天 | 能连续跑 4+1 轮，重启不丢状态 |
| M1 | 15.5 h | 3 天 | 自用一周替代 Be Focused |
| M2 | 18.5 h | 3–4 天 | 周复盘打开率 ≥40%，Widget 使用率 ≥30% |
| M3 | 13.5 h | 5–7 天（含审核与外部测试） | 上架，首月 100 个付费用户，退款率 <5% |
| 合计 | 约 58 h | 约 3 周日历时间 | — |

---

## 附录 A · 证据台账（可复现）

### A.1 制品身份与结构

| 检查项 | 值 | 证据 |
|---|---|---|
| 主二进制 SHA-256 | `95cd6b33f75d162b5321c8d4d908e00995ef1cc1f83266c91bd0266800054c13` | open_binary |
| 格式 | mach-o-universal（x86_64 + arm64） | `ev_a81b1704…` |
| Load commands | 69 条；依赖 50 个；导出 91 个；导入 1510 个 | `ev_a09e9d21…` |
| 签名 | Apple Mac App Store，Team `85GN4K4XWZ`，hardened runtime = false | `ev_17d71bd3…` |
| 沙盒 | app-sandbox = true；network.client = true；5 个浏览器的 Apple Events 例外 | `ev_17d71bd3…` |
| NIB 解码 | 6934 个 IB 对象，约 70 个 nib，11 个文档因上限省略 | `ev_77e93248…` |
| NIB 节点 | 4305 个节点，含菜单项、控件、本地化串 | `ev_4c50135c…` |

### A.2 复现命令（不含 REA 的静态取证）

```bash
# 版本与权限
plutil -p "/Applications/Be Focused Pro.app/Contents/Info.plist"
codesign -d --entitlements - "/Applications/Be Focused Pro.app"

# 依赖与架构
otool -L "/Applications/Be Focused Pro.app/Contents/MacOS/Be Focused Pro"
lipo -detailed_info "/Applications/Be Focused Pro.app/Contents/MacOS/Be Focused Pro"

# 类名与符号
strings -a "…/Be Focused Pro" | grep -E '^(PM|EM|XW|TT)[A-Za-z]+$' | sort -u

# 功能文案（最完整的功能清单来源）
plutil -convert json -o - \
  "/Applications/Be Focused Pro.app/Contents/Resources/Base.lproj/Localizable.strings"

# 数据结构（只读）
plutil -p "~/Library/Group Containers/85GN4K4XWZ.group.com.xwavesoft.pomodoromac/groupStorage.plist"
```

### A.3 证据与结论映射

| 结论 | 支撑证据 |
|---|---|
| 菜单栏应用（无 Dock 图标） | Info.plist `LSUIElement = true` |
| 使用 AWS S3 + Cognito 同步 | Mach-O 依赖中的 `Aws::S3::S3Client`、`Aws::CognitoIdentity` 符号；UserDefaults 的 `XWAWSCredentials*` |
| 计时以时间戳持久化 | `PMPomodoroTimer` 对象的 `start/pause/resume/skipTimeStamp` 字段 |
| 有 7 个自动化事件钩子 | 本机 `PMScriptsManager` 下 8 个 `PMScript`，标题为 7 个事件名 + 1 个空配置 |
| 11 个 Shortcuts/Siri 动作 | `Metadata.appintents/extract.actionsdata` 解析结果 |
| 网站屏蔽依赖 Apple Events | entitlements 的 `com.apple.security.temporary-exception.apple-events` 列了 5 个浏览器 |
| 付费墙在屏蔽/自动化/导出/同步 | `Localizable.strings` 的 Lite 提示与 Pro 权益列表 |
| 配色与深浅色体系 | `Assets.car` 601 条颜色资产（`app_green_color`、`app_red_color`…） |

---

## 附录 B · 未验证项与推断（不当作事实使用）

| 项 | 状态 | 说明 |
|---|---|---|
| `completionState` 的枚举含义（3=完成、4=跳过） | 推断 | 依据：3749 条中 3 占 3419、4 占 330，且跳过有独立确认文案；未拿到枚举定义 |
| `reports_period_idx = 8` 对应哪个周期 | 未验证 | 只知道有 6 种周期文案，索引映射未取证 |
| `PMScript.type` 的取值 | 未验证 | 本机 8 条记录的 `type` 均为空串，无法确认事件类型编码 |
| 报告是否支持按标签/活动类型筛选 | 推断 | 依据：`EMReportFilter`、`PMReportData` 类名与报告窗口控件，未跑通界面 |
| Widget 的具体布局 | 未验证 | 只确认 WidgetKit 扩展存在、背景色资产存在，未解码 SwiftUI 视图 |
| iCloud KVStore 的实际用途 | 推断 | 有 kvstore 标识与 `SyncedPreferences` 目录，但主同步走 AWS |
| 是否支持 macOS 专注模式 | 未发现 | 二进制里没有 `FocusFilter` 相关字符串，判断为不支持 |
| 中文界面 | 未发现 | 调研包只有 `en.lproj` 与 `Base.lproj` |

> 另：本次 REA 会话没有加载 Ghidra/IDA 引擎，未做函数级反编译。若后续需要确认筛选、报告、屏蔽的具体实现路径，需要在 REA 中启用原生反编译 provider 后补做，或改用 Hopper/Cutter 会话。

---

## 附录 C · 给知止的直接可复制资产

1. **字段清单**：直接采用第四节的 `PMTask` / `PMPomodoro` / `PMPomodoroTimer` 字段，改名为 Swift 命名（`TaskItem`、`Interval`、`RunningTimer`）。
2. **计时状态机**：照抄「时间戳 + duration」的做法，不要用内存倒计时。
3. **默认参数**：25 / 5 / 8 轮 / 每轮长休 15–30 分钟 / 每日目标 8–12 个（比 Be Focused 的 24 更现实）。
4. **快捷键**：默认 ⌘⇧R 开始暂停、⌘⇧B 跳过，并允许改绑。
5. **通知节奏**：段落结束通知 + 长休前额外提醒一次，不做营销通知。
6. **报告口径**：同时支持「小时」与「番茄数」，因为不同用户心智不同。
7. **导入映射**：`PMPomodoro.commonTimeInterval` → `Interval.duration`；`parentTaskID` → `TaskItem.legacyID`；`completionState` 只区分「完成/跳过/未完成」。

