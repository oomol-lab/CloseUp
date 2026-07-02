# CloseUp

[English](../../README.md) · [简体中文](README.zh-CN.md) · **繁體中文** · [日本語](README.ja.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

**將視窗控制項放回調度中心。** CloseUp 將視窗控制項疊加到原生的 macOS 調度中心上——無需離開總覽即可關閉、縮到最小、縮放、隱藏或結束任何視窗——並加入完整的鍵盤控制。免費、原生、開放原始碼。

## 功能

- **從總覽關閉** — 在調度中心將指標移到視窗縮覽圖上，點按紅色的 × 即可立即關閉，無需先切換到該視窗。
- **每一種視窗操作** — 縮到最小、縮放、隱藏 App 或結束 App，每一項都是可自由開啟或關閉的選用按鈕。
- **鍵盤控制** — 以原生操作對指標所指的視窗動作：⌘W 關閉、⌘M 縮到最小、⌘F 縮放、⌘H 隱藏、⌘Q 結束——全部皆可重新指定。
- **批次操作** — ⌥⌘W 全部關閉、⌥⌘M 全部縮到最小、⌥⌘H 隱藏除指標所指之外的所有視窗。
- **九種語言** — English、简体中文、繁體中文、日本語、Français、Deutsch、Español、Português、Русский，可在 App 內切換並即時套用。
- **原生且不打擾** — 一個被動的疊加層，絕不搶走調度中心本身的鍵盤處理；僅常駐選單列，沒有 Dock 圖像。
- **自動更新** — 透過 Sparkle 提供經簽署、公證的釋出版本。

## 系統需求

- macOS 14.0 或以上版本
- Apple Silicon 或 Intel（通用二進位檔）
- 輔助使用權限（CloseUp 透過輔助使用 API 讀取視窗並對其動作；絕不會錄製你的螢幕）

## 安裝

從 [Releases](https://github.com/oomol-lab/CloseUp/releases) 下載最新的 `.dmg`，打開它，並將 CloseUp 拖到「應用程式」中。首次啟動時，請在「系統設定」→「隱私權與安全性」→「輔助使用」中授予輔助使用權限——CloseUp 會為你打開正確的窗格。

## 用法

如常打開調度中心（以三指／四指向上滑動，或按調度中心鍵）。將指標移到任何視窗上以顯示其控制項組合，或使用鍵盤：

| 動作 | 快速鍵 | 作用對象 |
|---|---|---|
| 關閉視窗 | ⌘W | 指標所指的視窗 |
| 將視窗縮到最小 | ⌘M | 指標所指的視窗 |
| 縮放視窗 | ⌘F | 指標所指的視窗 |
| 隱藏 App | ⌘H | 指標所指的視窗 |
| 結束 App | ⌘Q | 指標所指的視窗 |
| 關閉所有視窗 | ⌥⌘W | 所有視窗 |
| 將所有視窗縮到最小 | ⌥⌘M | 所有視窗 |
| 隱藏除此之外的全部 | ⌥⌘H | 除指標所指之外的每個 App |

每個快速鍵都可以在「設定」→「快速鍵」中重新指定，而且一個全域快速鍵可以隨處將 CloseUp 開啟或關閉。

## 設定

- **一般** — 啟用／停用、登入時啟動、要顯示哪些控制按鈕，以及 App 內的語言。
- **快速鍵** — 重新指定每個動作以及全域開關。
- **權限** — 輔助使用狀態以及一鍵授予。
- **更新** — 自動檢查以及手動的「檢查更新項目」。

## 從原始碼建置

```bash
brew install xcodegen
make build      # Debug 建置（獨立的「CloseUp Dev」識別身分）
make test       # 單元測試 + i18n 防護
make run        # 建置並啟動
make dmg        # 封裝成可拖放安裝的 .dmg
```

Xcode 專案由 XcodeGen 從 `project.yml` 產生，並未納入版本控制。架構請參閱 [docs/DESIGN.md](docs/DESIGN.md)，釋出流程請參閱 [docs/RUNBOOK.md](docs/RUNBOOK.md)。

## 授權條款

[GPL-3.0](LICENSE)。

## 致謝

感謝 [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl)、[DockDoor](https://github.com/ejbills/DockDoor) 與 [alt-tab-macos](https://github.com/lwouis/alt-tab-macos)：CloseUp 對 Mission Control 私有 API 的用法，參考了這些專案的 API 用法。
