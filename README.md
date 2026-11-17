# 知止 Stoic

会复盘的番茄钟（macOS 菜单栏应用）。

![面板](<docs/screenshot-panel.png>)

- 菜单栏常驻，不占 Dock
- 整点对齐：让每个番茄都在整点或半点开始
- 休息时全屏倒计时（会议 / 演示 / 微信时自动跳过）
- 任务、记录、周复盘，数据只存本机
- 11 个快捷指令动作、Widget、专注模式过滤
- Chrome 扩展可屏蔽分心网站

## 快速开始

```bash
xcodegen generate          # 生成 Stoic.xcodeproj（project.yml 变更后需要）
./scripts/build-app.sh      # xcodebuild 构建 → .local-build/Stoic.app → 自动安装到 /Applications/Stoic.app
./scripts/smoke.sh          # 构建 + 58 个单元测试 + 启动检查
./scripts/make-dmg.sh       # 生成 .dist/Stoic-<版本>.dmg（点开头，不进 Spotlight）
swift test                  # 只跑测试（StoicCore 仍是纯 SPM 包）
```

启动：`open -a /Applications/Stoic.app`（菜单栏会出现计时项，无 Dock 图标）。

> 构建脚本默认安装到 `/Applications/Stoic.app`（覆盖旧版本）；只想构建不安装时用 `SKIP_INSTALL=1 ./scripts/build-app.sh`。
>
> 构建产物放 `.local-build/`、安装包放 `.dist/`（都是点开头），Spotlight 不会索引，所以搜索里只会出现 `/Applications` 那个。

## 目录

```
Sources/StoicCore/     状态机、数据模型、导入、导出、复盘、遥测（可测试）
Sources/Stoic/         AppKit 壳：菜单栏、面板、任务窗口、诊断
Tests/StoicCoreTests/  58 个单元测试
scripts/               build-app / smoke / make-dmg / symbolicate
docs/                  调研报告、Backlog、隐私政策、发布流程、官网页
extension/             Chrome MV3 扩展骨架（手动配置站点）
```

## 数据位置

| 内容 | 路径 |
|---|---|
| 任务 / 记录 / 设置 | `~/Library/Application Support/default.store` |
| 计时运行态 | `UserDefaults`（`stoic.timer.snapshot`） |
| 崩溃诊断 | `~/Library/Application Support/StoicLogs/` |

## 已知限制

- 未签名 / 未公证：首次打开需右键「打开」（有 Developer ID 后跑 `make-dmg.sh` 一条命令补全）。
- CloudKit 同步：未实现（需要付费开发者账号建容器）。
- Widget 的 App Group 在 adhoc 签名下是否生效未实机确认；读不到数据时显示 0 与 25:00。
- Focus Filter 在系统设置里的显示名可能为空，需人工确认。
- 浏览器扩展需手动加载并安装 native host（`./scripts/install-native-host.sh <扩展 ID>`）。

## 待人工确认（需要鼠标/系统权限）

深色模式实际观感、通知授权、异常退出弹窗、⌘⇧R/⌘⇧B 按键、右键菜单、记录编辑与删除、设置保存生效、提醒事项双向同步、英文语言切换、扩展安装拦截。

## 文档

- [Backlog（含执行日志）](<docs/Backlog-知止Stoic-合并版.md>)
- [隐私政策](<docs/隐私政策.md>)
- [发布流程](<docs/发布流程.md>)
- [官网下载页](<docs/官网下载页.html>)
- 竞品调研：[REA 版](<docs/竞品调研-BeFocusedPro.md>)、[Craft Anything 版](<docs/调研报告-CraftAnything-BeFocusedPro.md>)

## 版本号

- 唯一来源：仓库根 VERSION（x.y.z）
- 每次构建自动 +1：scripts/bump-version.sh（z 满 9 进位到 y，y 满 9 进位到 x）
- 预演下一个版本：./scripts/bump-version.sh --dry-run
- 构建号：秒级时间戳 YYYYMMDDhhmmss，写入 CFBundleVersion
