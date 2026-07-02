# CloseUp

[English](../../README.md) · **简体中文** · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

**让控制按钮回归调度中心。**CloseUp 将窗口控制按钮叠加到 macOS 原生调度中心上——无需离开总览即可关闭、最小化、缩放、隐藏或退出任意窗口——并加入完整的键盘控制。免费、原生、开源。

## 功能特性

- **在总览中关闭** —— 在调度中心中将指针悬停到窗口缩略图上，点击红色的 × 即可立即关闭该窗口，无需先切换过去。
- **覆盖每个窗口操作** —— 最小化、缩放、隐藏 App 或退出 App，每一项都是可单独开启或关闭的按钮。
- **键盘控制** —— 用原生操作处理指针所指的窗口：⌘W 关闭、⌘M 最小化、⌘F 缩放、⌘H 隐藏、⌘Q 退出——全部可重新映射。
- **批量操作** —— ⌥⌘W 全部关闭、⌥⌘M 全部最小化、⌥⌘H 除指针所指窗口外全部隐藏。
- **九种语言** —— English、简体中文、繁體中文、日本語、Français、Deutsch、Español、Português、Русский，可在 App 内切换并即时生效。
- **原生而不打扰** —— 一个被动式叠加层，绝不抢占调度中心自身的键盘处理；仅驻留菜单栏，无程序坞图标。
- **自动更新** —— 通过 Sparkle 提供经签名、已公证的版本更新。

## 系统要求

- macOS 14.0 或更高版本
- Apple Silicon 或 Intel（通用二进制文件）
- 辅助功能权限（CloseUp 通过辅助功能 API 读取并操作窗口；它绝不会录制你的屏幕）

## 安装

从 [Releases](https://github.com/oomol-lab/CloseUp/releases) 下载最新的 `.dmg`，打开后将 CloseUp 拖入“应用程序”。首次启动时，请在“系统设置”→“隐私与安全性”→“辅助功能”中授予辅助功能访问权限——CloseUp 会为你打开相应的设置面板。

## 使用方法

像往常一样打开调度中心（用三指/四指向上轻扫，或按下调度中心键）。将指针悬停到任意窗口上即可显示其控制按钮组，或使用键盘：

| 操作 | 快捷键 | 作用对象 |
|---|---|---|
| 关闭窗口 | ⌘W | 指针所指的窗口 |
| 最小化窗口 | ⌘M | 指针所指的窗口 |
| 缩放窗口 | ⌘F | 指针所指的窗口 |
| 隐藏 App | ⌘H | 指针所指的窗口 |
| 退出 App | ⌘Q | 指针所指的窗口 |
| 关闭所有窗口 | ⌥⌘W | 所有窗口 |
| 最小化所有窗口 | ⌥⌘M | 所有窗口 |
| 除此之外全部隐藏 | ⌥⌘H | 除指针所指窗口外的所有 App |

每个快捷键都可在“设置”→“快捷键”中重新映射，还可设置一个全局热键，从任何位置开启或关闭 CloseUp。

## 设置

- **通用** —— 启用/停用、登录时启动、显示哪些控制按钮，以及 App 内语言。
- **快捷键** —— 重新映射每一项操作以及全局开关。
- **权限** —— 辅助功能状态以及一键授权。
- **更新** —— 自动检查以及手动“检查更新”。

## 从源代码构建

```bash
brew install xcodegen
make build      # Debug 构建（使用独立的 “CloseUp Dev” 身份标识）
make test       # 单元测试 + 国际化校验
make run        # 构建并启动
make dmg        # 打包为可拖动安装的 .dmg
```

Xcode 工程由 XcodeGen 根据 `project.yml` 生成，不纳入版本管理。架构请参阅 [docs/DESIGN.md](docs/DESIGN.md)，发布流程请参阅 [docs/RUNBOOK.md](docs/RUNBOOK.md)。

## 许可证

[GPL-3.0](LICENSE)。

## 致谢

感谢 [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl)、[DockDoor](https://github.com/ejbills/DockDoor) 和 [alt-tab-macos](https://github.com/lwouis/alt-tab-macos)：CloseUp 对 Mission Control 私有 API 的用法，参考了这些项目使用这些 API 的方式。
