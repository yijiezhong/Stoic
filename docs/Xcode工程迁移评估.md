# Xcode 工程迁移评估（为 Widget / App Intents / Focus Filter）

日期：2026-11-16

结论一句话：能用 2–3 小时把构建从 SPM 迁到 xcodegen + xcodebuild，解锁 3 条被阻塞的 backlog；不迁则这 3 条永远无法交付。

> **已执行**（2026-11-16）：迁移完成，S2-05/06/07 全部交付。实际耗时约 1.2 h（迁移）+ 1.4 h（Widget）+ 1.2 h（Intents）+ 0.6 h（Focus Filter）。详见 Backlog 8.28–8.32。

## 一、为什么被阻塞

| 能力 | 依赖 | SPM 能否产出 |
|---|---|---|
| Widget | WidgetKit 扩展（独立 `.appex` target） | 不能 |
| App Intents / Shortcuts | `Metadata.appintents`（Xcode 的 `appintentsmetadataprocessor` 生成） | 不能 |
| Focus Filter | Focus Filter Intent，需 App Intents 注册 | 不能 |

`swift build` 只会编译可执行文件，不会做扩展打包与元数据提取。

## 二、方案 A：xcodegen + xcodebuild（推荐若需要系统集成）

### 步骤

1. `brew install xcodegen`。
2. 写 `project.yml`：
   - app target（`Stoic`），依赖本地 SPM 包 `StoicCore`；
   - widget extension target（`StoicWidget`）；
   - 保留 `Tests/StoicCoreTests` 的 test target。
3. `xcodegen generate` → `xcodebuild -scheme Stoic -configuration Release build`。
4. 打包脚本改为从 DerivedData 取 `.app`（替代 `.build/release`）。
5. Info.plist 增加 `NSExtension`（仅 widget target）。
6. 测试仍用 `swift test`（StoicCore 是纯 SPM 包，不受影响）。

### 影响面

| 文件 | 改动 |
|---|---|
| `scripts/build-app.sh` | 改用 xcodebuild，从 DerivedData 复制 .app |
| `scripts/make-dmg.sh` | 不变（只依赖 build/Stoic.app） |
| `scripts/smoke.sh` | 构建步骤换 xcodebuild；测试仍 swift test |
| `Package.swift` | 保留（StoicCore 仍作为本地包） |

### 工作量与风险

- 预估 2–3 h（含一次完整冒烟）。
- 风险：本地包引用路径、资源 bundle 位置（`Stoic_StoicCore.bundle`）、签名顺序。
- 回滚：保留当前 `build-app.sh` 为 `build-app-spm.sh`，随时切回。

## 三、方案 B：只做 Widget，不做 Intents（最简）

- 只加一个 widget extension target，不做 App Intents。
- 工作量 1.5–2 h；Focus Filter 与 Shortcuts 仍缺。
- 适合「首版只要桌面小组件」的定位。

## 四、方案 C：维持 SPM（当前）

- 0 h，无风险。
- 缺 Widget、Shortcuts、Focus Filter；「不开 App 也能用」的卖点没有。

## 五、建议

| 如果首版必须 | 选 |
|---|---|
| 要桌面小组件 + 快捷指令 | A |
| 只要小组件 | B |
| 先发纯应用、系统集成放 v1.1 | C |

我的建议：**A**。这 3 条是 M2 的唯一缺口，且 Widget 是独立分发产品最有效的「留存入口」。

## 六、不迁移的代价（量化）

- M2 完成度停在 7/11，剩余 3 条永远无法勾选。
- 「不开 App 也能用」的验收（S2-06 出口）无法达成。
