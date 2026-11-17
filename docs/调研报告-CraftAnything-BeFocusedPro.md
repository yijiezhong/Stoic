# 知止 Stoic · 第二份调研报告：Craft Anything 证据链下的 Be Focused Pro 2.6

报告日期：2026-11-16

调研对象：/Applications/Be Focused Pro.app（2.6，Build 109，Bundle ID com.xwavesoft.pomodoromac）

调研工具：Craft Anything MCP（core 工作记忆 + apple 工具集 + native 工具集，内建引擎 0.3.0，Deep 模式）

证据规模：21 条 evidence 记录、10 条 findings、4 个未决问题、402 条目制品清点

报告定位：与上一份 REA 报告互为交叉验证；本报告多了类清单、函数清单与引擎级统计，结论按「已见 / 推导 / 推断」分级。

---

## 一、一句话结论

Be Focused Pro 2.6 是一个 **29,058 个函数、443 个 Objective-C 类、9 年持续叠加** 的原生 AppKit 菜单栏应用：核心计时（状态机 + 轮次）设计干净、可照搬；数据层与同步层偏老（单文件 plist + AWS 自建账号），不建议复刻；图表甚至借了第三方 Core Plot。知止的机会不在功能数量，而在「把核心做轻、把数据做对、把复盘做出价值」。

---

## 二、制品身份（Craft Anything 取证）

| 项目 | 值 | 证据 |
|---|---|---|
| Bundle ID / 版本 | com.xwavesoft.pomodoromac / 2.6 (109) | ev_9c1e737… |
| 形态 | LSUIElement=true 的菜单栏应用；主窗口按需弹出 | ev_9c1e737… |
| 架构 | Universal 2：x86_64 + arm64，两切片均存在 | ev_5f50c5d… |
| 主二进制 | 15,027,376 字节，SHA-256 95cd6b33…4c13 | ev_6963b31… |
| 最低系统 / SDK | macOS 12.0 / macosx26.4（ld 1266.8.0） | ev_6963b31… |
| 签名 | Team 85GN4K4XWZ；CMS 签名校验通过并链到 Apple Root CA；1 个 CodeDirectory、10 项 entitlements | ev_89599e9… |
| 加壳/加密 | 未加密（encryption 为 null），可直接静态分析 | ev_6963b31… |
| 打包 | 402 条目 / 359 个文件：74 nib、223 binary、30 png、10 xml plist、2 zip | ev_ba932c4… |

> 注：签名证据的 CMS 校验未覆盖吊销（OCSP/CRL）与公证策略；只说明「签名结构与链完整」，不等同于「可信软件」。

### 2.1 组件构成

- `Contents/MacOS/Be Focused Pro`：主程序（29,058 函数）。
- `Contents/PlugIns/Be Focused WidgetExtension.appex`：WidgetKit 小组件。
- `Contents/Library/LoginItems/LaunchAtLoginHelperApp.app`：开机自启助手。
- `Contents/Resources/Metadata.appintents/`：Shortcuts/Siri 动作元数据（未解析，见未决问题）。
- `Contents/Resources/*.nib`：74 个 NIB，UI 全部由 Interface Builder 搭建。

---

## 三、技术架构（含引擎级数字）

### 3.1 总体分层

```
UI        AppKit + 74 个 NIB（PSettingsViewController / PTasksViewController / PReportsWindowController …）
控制       PRootController（104 方法）/ PTabBarController / PRoundManager / PPomodoroTimer
领域       PTask（172 方法）/ PAppSettings（114）/ PPomodoro / PMScript / EM… 全部继承 XWTreeItem
序列化     XWTreeItem（296 方法）：对象树 → 单文件 plist（groupStorage.plist）
同步       XWAWSStorage（106 方法）→ AWS S3 + Cognito（C++ SDK）
图表       Core Plot（CPTAxis / CPTPlot，CocoaPods 集成）
商业化     XWStoreManager / XWSMProduct / PUpsellManager（StoreKit 1）
```

### 3.2 体量数据（ev_a655c6e…）

| 指标 | 数值 | 解读 |
|---|---|---|
| 函数 | 29,058 | 中型桌面应用规模 |
| 机器指令 | 1,163,258 | 逻辑密度高，远超「番茄钟」直觉 |
| 字符串 | 21,971 | 文案与错误信息量大 |
| 导入 / 导出 | 1,457 / 91 | 依赖 50 个系统库 |
| 基础块 / 交叉引用 | 150,663 / 337,324 | 控制流复杂 |

### 3.3 类结构（ev_85d82468…，443 个类）

- 自研根类 `XWTreeItem` 有 **296 个方法**：所有领域对象都挂在它下面，实现「对象树 + 通用序列化 + 属性变更通知」。这是该产品最核心的架构决策。
- `PTask` 172 个方法、`PAppSettings` 114 个、`PTasksViewController` 157 个、`PReportsWindowController` 137 个——职责集中在少数巨类里，属于典型「早期设计 + 持续加方法」。
- 105 个 `PM` 前缀类、若干 `EM` 前缀（任务/标签域）、`XW` 前缀（基础设施）、`TT` 前缀（账号/登录）。

### 3.4 关键第三方依赖

| 依赖 | 证据 | 用途 |
|---|---|---|
| Core Plot（CocoaPods） | ev_6e5a94b…（4 条 CorePlot 字符串）、ev_85d82468…（CPTAxis/CPTPlot） | 报告柱状图/饼图 |
| AWS C++ SDK | ev_6963b31…（Aws::S3::S3Client、Aws::CognitoIdentity::CognitoIdentityClient） | 多设备同步 |
| MASShortcut | 字符串中出现 MASShortcut 类名 | 全局快捷键 |
| StoreKit 1 | XWSMProduct / XWSMPurchase | 订阅 |

### 3.5 与上一份 REA 报告的交叉验证

| 结论 | REA 报告 | Craft Anything | 判定 |
|---|---|---|---|
| 菜单栏 AppKit 应用 | 是 | 是（Info.plist） | 一致 |
| Universal 2 / 15 MB | 是 | 是 | 一致 |
| ObjC + NIB 架构 | 是（474 个类名） | 是（443 个类，含方法数） | 一致，本报告更细 |
| AWS S3 + Cognito 同步 | 是（符号推断） | 是（导出符号 + 类） | 一致 |
| 图表自研 | 未提及 | **否，用 Core Plot** | 本报告新增并纠正 |
| 计时用时间戳 | 是（数据字段） | 是（方法与字段） | 一致 |
| 单文件 plist 存储 | 是 | 是 | 一致 |

---

## 四、数据模型（可复用部分）

`groupStorage.plist`（ev_2c470eb…）是单棵对象树，根节点字段：`children / className / versionNumber(=6) / id / isExpanded / isGroup`。

### 4.1 任务（PTask，32 字段）

`id, title, note, creationTime, completionTime, completionState, dueDate, remindMeDate, allDayTask, repeatType, repeatInterval, repeatIntervalUnits, repeatDaysOfWeek, endRepeatDate, isImportant, isUrgent, moveToUrgentTimeinterval, expectedIntervals, workTypeID, calendarID, isSyncingWithCalendar, isSyncingWithReminders, isSyncingWithPomodoro, isInbox …`

### 4.2 番茄记录（PPomodoro，13 字段）

`id, parentTaskID, parentPomodoroID, isRest, startTimeStamp, resumeTimeStamp, commonTimeInterval, roundIndex, completionState …`

### 4.3 运行态计时器（PPomodoroTimer，独立持久化）

`duration, startTimeStamp, pauseTimeStamp, resumeTimeStamp, skipTimeStamp, isRest, roundIndex, parentPomodoroID, completionState`

> 设计要点：**历史记录与运行态分离**。记录只写一次，运行态每 1 秒可写；崩溃/重启时只恢复运行态，不会污染历史。

### 4.4 设置（PAppSettings，44 字段；本机值）

| 字段 | 本机值 | 说明 |
|---|---|---|
| pomodoroLenght | 25 | 工作段（原拼写如此） |
| restTime | 5 | 短休 |
| bigRestTime | 5 | 长休（默认建议 15–30） |
| pomodorosInPeriodCount | 8 | 每轮段数 |
| pomodorosPerDay | 24 | 每日目标 |
| isAutorepeatEnabled | true | 自动开始 |
| showTimerInStatusBarOSX | true | 菜单栏显示时间 |
| nonSleepModeEnabled | false | 防休眠 |

---

## 五、功能与商业化（证据分级）

### 5.1 功能矩阵（观察到的）

| 模块 | 能力 | 证据 |
|---|---|---|
| 计时 | 工作/短休/长休、轮次、自动开始、跳过、暂停、跨重启恢复 | ev_c1a8c51…、ev_2c470eb… |
| 轮次 | 第 N 轮配置、跳过休息、每轮本地通知 | ev_6777778…（19 个方法） |
| 任务 | 截止日、提醒、重复、重要/紧急、预计番茄、备注、标签、分区 | ev_85d82468…、ev_2c470eb… |
| 报告 | 周期汇总、柱状/饼图、小时/番茄两种口径、CSV 导出 | 类清单 + ev_6e5a94b… |
| 通知 | 本地通知 + 多组提示音 | ev_ba932c4…（M4A.zip） |
| 快捷键 | 全局开始/暂停、跳过 | MASShortcut 字符串 |
| 自动化 | 事件钩子 → 快捷指令 | 本机 8 条 PMScript |
| 同步 | S3 + Cognito 账号、扩展同步 | ev_6963b31… |
| 商业化 | StoreKit 1 订阅、免费版广告 | ev_9231cd8…、ev_ba932c4… |

### 5.2 商业模型

- 免费版：核心计时 + 任务，带广告（`AdvertisingPackage.zip`）。
- Pro：屏蔽、自动化、CSV 导出、多设备同步、标签筛选、每日备份。
- 订阅三档（月/年/年），StoreKit 1 实现，有「恢复购买」。

### 5.3 值得学 / 不值得学的

| 判断 | 内容 |
|---|---|
| 学 | 计时器「时间戳 + 运行态独立持久化」；轮次与跳过休息的集中编排；菜单栏右键快捷操作 |
| 学 | 免费版守核心、付费买工作流（屏蔽/自动化/同步/导出） |
| 不学 | 单文件 plist 全量序列化（写放大、迁移难） |
| 不学 | 自建 AWS 账号体系（成本、隐私、跨平台都难） |
| 不学 | 用第三方 Core Plot（知止直接用 Swift Charts） |
| 不学 | 74 个 NIB（用 SwiftUI 可省 70% 界面代码） |

---

## 六、对「知止 Stoic」的取舍建议

1. **核心循环照抄，界面重做**：状态机与轮次逻辑几乎可以按字段翻译；界面用 SwiftUI + 圆环，而不是 NIB 表格。
2. **数据换 SQLite/SwiftData**：分表（Task / Interval / Settings / DaySummary），保留「运行态单独一行」的设计。
3. **同步先不做**：首版 CloudKit 可选或纯本地；AWS 那套不碰。
4. **差异化只做三件事**：中断记录、周复盘、专注块（25/50/90）。其余功能一律排后。
5. **把「导入 Be Focused」做成按钮**：解析 groupStorage.plist，用户换机零成本。

---

## 七、Backlog 待办清单（AI 工时口径）

> 口径：AI 工时 = agent 实际执行时间（读码、写码、构建、测试、修错），含约 30% 返工余量；人工与日历等待单列。
> 合计：约 **55 AI 工时（7 个专注日）**；人类独立开发参考约 12–14 周，不作排期基准。

### M0 · 地基

| ID | 条目 | 验收标准 | AI 工时 | 人工/外部 |
|---|---|---|---|---|
| C0-01 | 工程骨架 + 菜单栏（LSUIElement） | 无 Dock 图标，点图标弹出面板 | 0.5 h | — |
| C0-02 | 计时状态机（idle/running/paused/completed，时间戳驱动） | 改系统时间不漂移；强杀重启误差 ≤1 s | 1.5 h | — |
| C0-03 | 运行态持久化（对应 PPomodoroTimer 的独立存法） | 重启后恢复当前段，不重复计 | 1 h | — |
| C0-04 | 轮次与长休（对应 PRoundManager） | 设 N=8 时第 8 段后长休；可跳过休息 | 1 h | — |
| C0-05 | 圆环主界面 + 三按钮 | 两种分辨率不破；深色模式可读 | 1.5 h | 人工验收 10 min |
| C0-06 | 通知与提示音 | 段落结束 1 s 内 banner；免打扰不响但记录 | 1 h | 人工 5 min（授权） |
| C0-07 | SwiftData 模型（Task/Interval/Settings/DaySummary） | 迁移脚本可执行；版本号写入 | 1.5 h | — |
| C0-08 | Be Focused 导入器 | 本机 3,749 条记录全部落库，抽 10 条时间戳一致 | 2 h | — |

**M0 合计 9.5 h。**

### M1 · 可用 MVP

| ID | 条目 | 验收标准 | AI 工时 | 人工/外部 |
|---|---|---|---|---|
| C1-01 | 任务列表（增删改、完成、拖拽） | 100 任务滚动 60 fps，排序持久化 | 2 h | — |
| C1-02 | 任务详情（截止/提醒/重复/四象限/预计番茄/备注） | 字段可改可清空，空标题拦截 | 2.5 h | — |
| C1-03 | 选任务计时与记录归属 | 结束记录聚合到任务；切任务不影响当前段 | 1 h | — |
| C1-04 | 当天记录列表可编辑 | 改时长后统计立即刷新；交错时间提示 | 1.5 h | — |
| C1-05 | 设置页（计时/通知/外观/自启） | 立即生效；有恢复默认 | 2 h | — |
| C1-06 | 全局快捷键 ⌘⇧R / ⌘⇧B | 任意前台应用生效；可换绑 | 1 h | 人工 2 min |
| C1-07 | 提醒事项双向同步（EventKit） | 双向 2 s 内可见 | 3 h | 人工 5 min（授权） |
| C1-08 | 中文本地化（String Catalog） | 无硬编码文案 | 1.5 h | 人工 15 min（用词） |
| C1-09 | 单元测试 + 冒烟 | 状态机 12 条路径；CI 5 min 内 | 1.5 h | — |

**M1 合计 16 h。**

### M2 · 差异化

| ID | 条目 | 验收标准 | AI 工时 | 人工/外部 |
|---|---|---|---|---|
| C2-01 | 今日概览卡 | 与明细逐条对得上，误差 0 | 1 h | — |
| C2-02 | 中断记录（次数 + 原因） | 每段可记录 0–N 次；按原因聚合 | 1.5 h | — |
| C2-03 | 周复盘（自动结论） | 每个数字可点开原始记录 | 3 h | 人工 10 min |
| C2-04 | 专注块 25/50/90 | 与番茄模式共存，统计分开 | 1 h | — |
| C2-05 | Focus Filter 联动 | 开始专注自动进「工作」专注 | 1.5 h | 人工 5 min |
| C2-06 | Widget（小/中/大） | 点击可直接开始下一段 | 2 h | — |
| C2-07 | App Intents（11 个动作） | 快捷指令中全部可见可执行 | 2 h | — |
| C2-08 | 报告图表（Swift Charts 替代 Core Plot） | 周期/任务/标签三种维度 | 2 h | — |
| C2-09 | 导出 JSON/CSV/SQLite | 导出后能重新导入且一致 | 1 h | — |
| C2-10 | 应用屏蔽（提醒优先，扩展可选） | 黑名单提醒一次；未装扩展不报错 | 2.5 h | 人工 15 min |

**M2 合计 17.5 h。**

### M3 · 商业化与发布

| ID | 条目 | 验收标准 | AI 工时 | 人工/外部 |
|---|---|---|---|---|
| C3-01 | StoreKit 2 订阅（月/年 + 试用） | 沙盒购买/续订/取消/恢复全部通过 | 2.5 h | 人工 10 min |
| C3-02 | 免费/Pro 边界 + upsell 文案 | 每处付费墙有理由与恢复入口 | 1 h | — |
| C3-03 | CloudKit 同步 | 两台 Mac 5 s 内一致，冲突可选 | 4 h | 人工 10 min |
| C3-04 | 匿名遥测（默认关） | 关闭时抓包无上报 | 1 h | — |
| C3-05 | 崩溃收集 | 可定位函数与行号 | 1 h | — |
| C3-06 | 隐私政策 + 上架素材 | 审核一次通过 | 2 h | 人工 1 h |
| C3-07 | 灰度发布 | 10 名测试者 1 周无 P0 | 0.5 h | 日历 1 周 |

**M3 合计 12 h + 人工约 1.5 h + 外部等待 1 周。**

### 7.1 里程碑与口径

| 里程碑 | AI 工时 | 日历时间 | 成功指标 |
|---|---|---|---|
| M0 | 9.5 h | 1–2 天 | 连续 4+1 轮，重启不丢 |
| M1 | 16 h | 3 天 | 自用一周替代 Be Focused |
| M2 | 17.5 h | 3–4 天 | 周复盘打开率 ≥40% |
| M3 | 12 h | 5–7 天（含审核） | 上架，首月 100 付费 |
| 合计 | 55 h | 约 3 周 | — |

### 7.2 明确不做

- 不做团队协作；不做 Windows/Android 首版。
- 不复刻 Core Plot、不复刻 AWS 同步、不复刻 NIB。
- 不做系统级网络拦截（审核与权限风险高）。

---

## 八、证据台账（Craft Anything）

| Evidence ID | 操作 | 摘要 | 证据等级 |
|---|---|---|---|
| ev_a193831d4c62e03c… | core_target_triage | app bundle 初判为目录 | 推断 |
| ev_9c1e7379669047e1… | apple_plist_show | Info.plist，35 个顶层键 | 已见 |
| ev_6963b3190b2a4b3… | apple_macho_show | 69 条 load command、50 库、1,457 导入 | 已见 |
| ev_89599e9cfa2e9398… | apple_signature_show | 签名有效，Team 85GN4K4XWZ，10 项权限 | 已见 |
| ev_5f50c5d67d12c3f7… | apple_slices_list | Universal 2（x86_64 + arm64） | 已见 |
| ev_ba932c4eac785342… | core_archive_show | 402 条目 / 359 文件 / 2 个 zip | 已见 |
| ev_a655c6e987b67c7a… | core_overview_show | 29,058 函数 / 1.16M 指令 | 推导 |
| ev_85d82468bde817f1… | apple_objc_classes_list | 421+22 个 ObjC 类与分类 | 已见 |
| ev_d7a7817378a3793e… | apple_objc_classes_list | 104 个 PM 前缀类 | 已见 |
| ev_659eedc41198dc0b… | apple_objc_classes_list | 2 个 PMRound 匹配（含父类） | 已见 |
| ev_2c470ebf231a532b… | apple_plist_show | groupStorage.plist 根结构（versionNumber=6） | 已见 |
| ev_6777778e819e37da… | native_functions_search | 19 个 PRoundManager 方法 | 推导 |
| ev_b2460233e75a645c… | native_functions_search | 36 个 PMRound 相关函数 | 推导 |
| ev_c1a8c51b8e524b7d… | native_functions_search | 32 个 PPomodoroTimer 方法 | 推导 |
| ev_b617656492913fae… | apple_nib_decode | 8 个 IB 文档 / 1,584 对象 / 225 连接 | 已见 |
| ev_9231cd80c06bbb4e… | native_strings_find | 2 条 Upgrade to Pro 文案 | 已见 |
| ev_6e5a94b29307d22b… | native_strings_find | 4 条 CorePlot 字符串（含 PodsDummy） | 已见 |
| ev_1ee60868ff93fd4f… | native_strings_find | 20 条 Work Interval 文案 | 已见 |
| ev_e6729e5546889fbc… | native_strings_find | 2 条 Skip interval 文案 | 已见 |
| ev_93d763c18d1b0c49… | native_function_pseudocode | 轮次配置函数 49 行伪代码（部分结构化） | 推断 |
| ev_8019c5ba8e34cba9… | native_strings_find | 0 条 Core Plot（带空格）——反证写法 | 已见 |

> 证据等级：「已见」= 字节/结构的直接观察；「推导」= 由观察计算或聚合；「推断」= 判断，可能错。

---

## 九、未决问题与限制

### 9.1 未决问题

| 问题 | 严重度 | 状态 | 下一步 |
|---|---|---|---|
| 轮次算法的函数级实现（反编译超时/部分结构化） | 中 | 未解 | 逐条读汇编或提高预算重试 |
| Shortcuts/Siri 的 11 个动作清单与参数 | 中 | 未解 | 解析 Metadata.appintents 的 actionsdata |
| Core Plot 的具体版本 | 低 | 未解 | 在 Pods 版本表字符串或 Info 里继续找 |
| 是否支持简体中文界面 | 低 | 未解 | 检查是否有 zh-Hans.lproj 或运行时切换 |

### 9.2 本次取证的限制

- 使用内建反编译器（Ghidra 未就绪），伪代码精度低于 Ghidra/IDA。
- 未运行目标：所有结论来自静态文件，不包含运行时行为。
- 报告里的类/函数计数来自内建引擎的发现结果，**缺失不等于不存在**（运行时动态注册的类不会被列出）。
- 签名只验证结构与证书链，不验证吊销与公证。
- 未读取个人数据内容（任务名、邮箱、token 均未写入本报告）。

---

## 十、方法与可复现步骤

```bash
# 1. 打开目标并判定格式
#    core_target_open(path: "/Applications/Be Focused Pro.app")
#    core_target_triage()

# 2. 制品清单与结构
#    core_archive_show(path: ".../Be Focused Pro.app")
#    apple_macho_show(path: ".../Contents/MacOS/Be Focused Pro")
#    apple_signature_show(...)   apple_slices_list(...)

# 3. 代码与资源
#    core_overview_show()
#    apple_objc_classes_list(pattern: "")
#    native_functions_search(pattern: "PMRoundManager")
#    apple_nib_decode(path: ".../Be Focused Pro.app", max_documents: 8)

# 4. 数据
#    apple_plist_show(path: ".../groupStorage.plist")
```

工作记忆（brief / plan / findings / hypotheses / handoff）保存在 Craft Anything 会话中，可用 `core_investigation_show` 复查。

---

## 十一、结论

1. 设计上值得抄的是「状态机 + 轮次 + 运行态独立持久化」，不是它的界面与存储。
2. 架构债已经很明显（巨类、单文件 plist、自有同步账号、第三方图表），这正是新产品可以在「轻、快、可携带」上赢的地方。
3. 55 AI 工时（7 个专注日）足以做出替代级 MVP；瓶颈在人工验收与 App Store 审核，不在写代码。
4. 两份独立工具链（REA 与 Craft Anything）在核心事实上一致，差异点（Core Plot、函数数、类方法数）由本报告补充，可作为后续开发的可靠输入。