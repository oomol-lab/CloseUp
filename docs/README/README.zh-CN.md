# CloseUp

[English](../../README.md) · **简体中文** · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

**让控制按钮回归调度中心。**CloseUp 将窗口控制按钮叠加到 macOS 原生调度中心上——无需离开总览即可关闭、最小化、最大化、隐藏或退出任意窗口——并加入完整的键盘控制。免费、原生、开源。

## 功能特性

- **在总览中关闭** —— 在调度中心中将指针悬停到窗口缩略图上，点击红色的 × 即可立即关闭该窗口，无需先切换过去。
- **覆盖每个窗口操作** —— 最小化、最大化、隐藏 App 或退出 App。关闭、最小化、最大化是可以在设置中单独开启或关闭的按钮；隐藏和退出只要窗口支持就会一直显示。
- **键盘控制** —— 用原生操作处理指针所指的窗口：⌘W 关闭、⌘M 最小化、⌘F 最大化、⌘H 隐藏、⌘Q 退出——全部可重新映射。
- **批量操作** —— ⌥⌘W 全部关闭、⌥⌘M 全部最小化、⌥⌘H 除指针所指窗口外全部隐藏。
- **九种语言** —— English、简体中文、繁體中文、日本語、Français、Deutsch、Español、Português、Русский，可在 App 内切换并即时生效。
- **原生而不打扰** —— 一个被动式叠加层，绝不抢占调度中心自身的键盘处理；仅驻留菜单栏，无程序坞图标。
- **自动更新** —— 通过 Sparkle 提供经签名、已公证的版本更新，并可选择测试版更新通道。

## CloseUp 与同类产品对比

CloseUp 只专注做一件事——直接在**原生** Mission Control 界面里操作窗口。以下是它与几款提供类似功能的同类产品的对比（核实于 2026-07-02，核实来源见各产品官网/仓库链接；官方未公开的字段标注为“未公开”，不做猜测）：

| | CloseUp | [Mission Control Close](https://missioncontrolclose.com/) | [Open Mission Control](https://github.com/nohackjustnoobb/OpenMissionControl) | [Mission Control Plus](https://www.fadel.io/missioncontrolplus) |
|---|---|---|---|---|
| 价格 | 免费 | 一次性 £5（7 天试用） | 免费 | 付费，价格未公开（10 天试用） |
| 许可证 | 开源（GPL-3.0） | 闭源 | 开源（GPL-3.0） | 闭源 |
| 对指针所指窗口的操作 | 关闭、最小化、最大化、隐藏、退出 | 仅关闭 | 关闭、最小化、最大化 | 关闭、最小化、退出（+打开） |
| 批量操作 | 全部关闭、全部最小化、隐藏除此之外全部 | 全部关闭 | 未公开 | 未公开 |
| 快捷键可自定义 | 每个动作均可 | 有快捷键，是否可自定义未公开 | 固定（⌘Q/⌘W/⌘M/⌘F） | 固定（⌘W/⌘M/⌘Q/⏎） |
| 本地化 | 9 种语言，App 内切换 | 未公开 | 未公开 | 未公开 |
| macOS 版本要求 | 14.0+ | 26.0（Tahoe）+ | 未公开 | 10.13+ |
| CPU 架构 | Apple Silicon 与 Intel，各自独立签名构建 | 仅 Apple Silicon | 未公开 | 未公开 |
| 分发方式 | 直接下载 + Homebrew，已公证，Sparkle 自动更新 | 直接下载，LemonSqueezy 结账 | GitHub + Homebrew（未签名——需手动移除隔离标记） | 直接下载 |

其他 macOS 窗口管理工具——[AltTab](https://github.com/lwouis/alt-tab-macos)、[DockDoor](https://github.com/ejbills/DockDoor)、[HyperDock](https://bahoom.com/hyperdock)、[Contexts](https://contexts.co/)——也提供相关的窗口操作（关闭、隐藏、切换），但都是通过它们各自的切换器或程序坞悬停界面，而不是原生 Mission Control 界面，解决的是相关但不同的问题，因此未纳入上方对比。

## 系统要求

- macOS 14.0 或更高版本
- Apple Silicon（arm64）或 Intel（x86_64）—— CloseUp 为每种架构分别打包独立签名的版本，请下载与你 Mac 芯片匹配的版本
- 辅助功能权限（CloseUp 通过辅助功能 API 读取并操作窗口；它绝不会录制你的屏幕）

## 安装

从 [Releases](https://github.com/oomol-lab/CloseUp/releases) 下载与你 Mac 芯片匹配的安装包 —— Apple Silicon 对应 `CloseUp-*-arm64.dmg`，Intel 对应 `CloseUp-*-x86_64.dmg`，打开后将 CloseUp 拖入“应用程序”。也可以通过 Homebrew 安装（会自动识别你的芯片架构）：

```bash
brew install --cask oomol-lab/tap/closeup
```

首次启动时，请在“系统设置”→“隐私与安全性”→“辅助功能”中授予辅助功能访问权限——CloseUp 会为你打开相应的设置面板。

## 使用方法

像往常一样打开调度中心（用三指/四指向上轻扫，或按下调度中心键）。将指针悬停到任意窗口上即可显示其控制按钮组，或使用键盘：

| 操作 | 快捷键 | 作用对象 |
|---|---|---|
| 关闭窗口 | ⌘W | 指针所指的窗口 |
| 最小化窗口 | ⌘M | 指针所指的窗口 |
| 最大化窗口 | ⌘F | 指针所指的窗口 |
| 隐藏 App | ⌘H | 指针所指的窗口 |
| 退出 App | ⌘Q | 指针所指的窗口 |
| 关闭所有窗口 | ⌥⌘W | 所有窗口 |
| 最小化所有窗口 | ⌥⌘M | 所有窗口 |
| 除此之外全部隐藏 | ⌥⌘H | 除指针所指窗口外的所有 App |

每个快捷键都可在“设置”→“快捷键”中重新映射。随时可以从菜单栏图标或“设置”→“通用”中开启或关闭 CloseUp。

## 设置

- **通用** —— 启用/停用、开机时启动、隐藏菜单栏图标、辅助功能状态与一键授权、显示哪些控制按钮，以及 App 内语言。
- **快捷键** —— 重新映射每一项操作。
- **更新** —— 自动检查（稳定版或测试版通道）以及手动“检查更新”。
- **关于** —— 版本号、许可证、GitHub 仓库链接，以及致谢名单。

## 从源代码构建

```bash
brew install xcodegen
make build      # Debug 构建（使用独立的 “CloseUp Dev” 身份标识）
make dev-cert   # 可选：创建稳定的本地签名身份，让辅助功能授权在重新构建后依然有效
make test       # 单元测试 + 国际化校验
make run        # 构建并启动
make dmg        # 打包为可拖动安装的 .dmg
```

Xcode 工程由 XcodeGen 根据 `project.yml` 生成，不纳入版本管理。架构请参阅 [../DESIGN.md](../DESIGN.md)，发布流程请参阅 [../RUNBOOK.md](../RUNBOOK.md)。

## 许可证

[GPL-3.0](../../LICENSE)。

## 致谢

感谢 [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl)、[DockDoor](https://github.com/ejbills/DockDoor) 和 [alt-tab-macos](https://github.com/lwouis/alt-tab-macos)：CloseUp 对 Mission Control 私有 API 的用法，参考了这些项目使用这些 API 的方式。
