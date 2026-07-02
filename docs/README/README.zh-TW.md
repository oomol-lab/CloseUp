# CloseUp

[English](../../README.md) · [简体中文](README.zh-CN.md) · **繁體中文** · [日本語](README.ja.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

**將視窗控制項放回調度中心。** CloseUp 將視窗控制項疊加到原生的 macOS 調度中心上——無需離開總覽即可關閉、縮到最小、最大化、隱藏或結束任何視窗——並加入完整的鍵盤控制。免費、原生、開放原始碼。

## 螢幕截圖

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/overlay-dark.png">
    <img alt="疊加在調度中心縮圖上的視窗控制項" src="../images/overlay-light.png" width="48%">
  </picture>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-general-en-dark.png">
    <img alt="一般設定" src="../images/settings-general-en-light.png" width="49%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-shortcuts-en-dark.png">
    <img alt="鍵盤快捷鍵" src="../images/settings-shortcuts-en-light.png" width="49%">
  </picture>
</p>

## 功能

- **從總覽關閉** — 在調度中心將指標移到視窗縮覽圖上，點按紅色的 × 即可立即關閉，無需先切換到該視窗。
- **每一種視窗操作** — 縮到最小、最大化、隱藏 App 或結束 App。關閉、縮到最小、最大化是可以在設定中自由開啟或關閉的按鈕；隱藏與結束只要視窗支援就會一律顯示。
- **鍵盤控制** — 以原生操作對指標所指的視窗動作：⌘W 關閉、⌘M 縮到最小、⌘F 最大化、⌘H 隱藏、⌘Q 結束——全部皆可重新指定。
- **批次操作** — ⌥⌘W 全部關閉、⌥⌘M 全部縮到最小、⌥⌘H 隱藏除指標所指之外的所有視窗。
- **九種語言** — English、简体中文、繁體中文、日本語、Français、Deutsch、Español、Português、Русский，可在 App 內切換並即時套用。
- **原生且不打擾** — 一個被動的疊加層，絕不搶走調度中心本身的鍵盤處理；僅常駐選單列，沒有 Dock 圖像。
- **自動更新** — 透過 Sparkle 提供經簽署、公證的釋出版本，並可選擇測試版更新頻道。

## CloseUp 與同類產品比較

CloseUp 只專注做一件事 — 直接在**原生** Mission Control 畫面裡操作視窗。以下是它與幾款提供類似功能的同類產品的比較（核實於 2026-07-02，來源請見各產品官網／儲存庫連結；官方未公開的欄位標示為「未公開」，不做臆測）：

| | CloseUp | [Mission Control Close](https://missioncontrolclose.com/) | [Open Mission Control](https://github.com/nohackjustnoobb/OpenMissionControl) | [Mission Control Plus](https://www.fadel.io/missioncontrolplus) |
|---|---|---|---|---|
| 價格 | 免費 | 一次性 £5（7 天試用） | 免費 | 付費，價格未公開（10 天試用） |
| 授權條款 | 開放原始碼（GPL-3.0） | 閉源 | 開放原始碼（GPL-3.0） | 閉源 |
| 對指標所指視窗的操作 | 關閉、縮到最小、最大化、隱藏、結束 | 僅關閉 | 關閉、縮到最小、最大化 | 關閉、縮到最小、結束（+開啟） |
| 批次操作 | 全部關閉、全部縮到最小、隱藏除此之外全部 | 全部關閉 | 未公開 | 未公開 |
| 快速鍵可自訂 | 每個動作皆可 | 有快速鍵，是否可自訂未公開 | 固定（⌘Q/⌘W/⌘M/⌘F） | 固定（⌘W/⌘M/⌘Q/⏎） |
| 在地化 | 9 種語言，App 內即可切換 | 未公開 | 未公開 | 未公開 |
| macOS 版本需求 | 14.0+ | 26.0（Tahoe）+ | 未公開 | 10.13+ |
| CPU 架構 | Apple Silicon 與 Intel，各自獨立簽署建置 | 僅 Apple Silicon | 未公開 | 未公開 |
| 發佈方式 | 直接下載 + Homebrew，已公證，Sparkle 自動更新 | 直接下載，LemonSqueezy 結帳 | GitHub + Homebrew（未簽署 — 需手動移除隔離標記） | 直接下載 |

其他 macOS 視窗管理工具 — [AltTab](https://github.com/lwouis/alt-tab-macos)、[DockDoor](https://github.com/ejbills/DockDoor)、[HyperDock](https://bahoom.com/hyperdock)、[Contexts](https://contexts.co/) — 也提供相關的視窗操作（關閉、隱藏、切換），但都是透過各自的切換器或 Dock 懸停介面，而非原生 Mission Control 畫面，解決的是相關但不同的問題，因此未納入上方比較。

## 系統需求

- macOS 14.0 或以上版本
- Apple Silicon（arm64）或 Intel（x86_64）— CloseUp 針對每種架構各自打包獨立簽署的版本，請下載與你 Mac 晶片相符的版本
- 輔助使用權限（CloseUp 透過輔助使用 API 讀取視窗並對其動作；絕不會錄製你的螢幕）

## 安裝

從 [Releases](https://github.com/oomol-lab/CloseUp/releases) 下載與你 Mac 晶片相符的安裝檔 — Apple Silicon 請選 `CloseUp-*-arm64.dmg`，Intel 請選 `CloseUp-*-x86_64.dmg`，打開它並將 CloseUp 拖到「應用程式」中。也可以透過 Homebrew 安裝（會自動偵測你的晶片架構）：

```bash
brew install --cask oomol-lab/tap/closeup
```

首次啟動時，請在「系統設定」→「隱私權與安全性」→「輔助使用」中授予輔助使用權限——CloseUp 會為你打開正確的窗格。

## 用法

如常打開調度中心（以三指／四指向上滑動，或按調度中心鍵）。將指標移到任何視窗上以顯示其控制項組合，或使用鍵盤：

| 動作 | 快速鍵 | 作用對象 |
|---|---|---|
| 關閉視窗 | ⌘W | 指標所指的視窗 |
| 將視窗縮到最小 | ⌘M | 指標所指的視窗 |
| 將視窗最大化 | ⌘F | 指標所指的視窗 |
| 隱藏 App | ⌘H | 指標所指的視窗 |
| 結束 App | ⌘Q | 指標所指的視窗 |
| 關閉所有視窗 | ⌥⌘W | 所有視窗 |
| 將所有視窗縮到最小 | ⌥⌘M | 所有視窗 |
| 隱藏除此之外的全部 | ⌥⌘H | 除指標所指之外的每個 App |

每個快速鍵都可以在「設定」→「快速鍵」中重新指定。隨時都可以透過選單列圖示或「設定」→「一般」開啟或關閉 CloseUp。

## 設定

- **一般** — 啟用／停用、登入時啟動、隱藏選單列圖示、輔助使用狀態與一鍵授予、要顯示哪些控制按鈕，以及 App 內的語言。
- **快速鍵** — 重新指定每個動作。
- **更新** — 自動檢查（穩定版或測試版頻道）以及手動的「檢查更新項目」。
- **關於** — 版本號、授權條款、GitHub 儲存庫連結，以及致謝名單。

## 從原始碼建置

```bash
brew install xcodegen
make build      # Debug 建置（獨立的「CloseUp Dev」識別身分）
make dev-cert   # 選用：建立穩定的本機簽署身分，讓輔助使用授權在重新建置後依然有效
make test       # 單元測試 + i18n 防護
make run        # 建置並啟動
make dmg        # 封裝成可拖放安裝的 .dmg
```

Xcode 專案由 XcodeGen 從 `project.yml` 產生，並未納入版本控制。架構請參閱 [../DESIGN.md](../DESIGN.md)，釋出流程請參閱 [../RUNBOOK.md](../RUNBOOK.md)。

## 授權條款

[GPL-3.0](../../LICENSE)。

## 致謝

感謝 [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl)、[DockDoor](https://github.com/ejbills/DockDoor) 與 [alt-tab-macos](https://github.com/lwouis/alt-tab-macos)：CloseUp 對 Mission Control 私有 API 的用法，參考了這些專案的 API 用法。
