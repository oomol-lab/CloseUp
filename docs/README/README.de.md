# CloseUp

[English](../../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Français](README.fr.md) · **Deutsch** · [Español](README.es.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

**Bringen Sie die Steuerelemente zurück in Mission Control.** CloseUp blendet
Fenstersteuerungen in das native macOS Mission Control ein — schließen,
minimieren, zoomen, ausblenden oder beenden Sie ein beliebiges Fenster, ohne die
Übersicht zu verlassen — und ergänzt sie um vollständige Tastatursteuerung.
Kostenlos, nativ und quelloffen.

## Funktionen

- **Schließen aus der Übersicht** — bewegen Sie den Zeiger über ein
  Fenster-Miniaturbild in Mission Control und klicken Sie auf das rote ×, um es
  sofort zu schließen, ohne vorher dorthin zu wechseln.
- **Jeder Fensterbefehl** — minimieren, zoomen, App ausblenden oder App beenden,
  jeweils als optionale Schaltfläche, die Sie ein- oder ausschalten können.
- **Tastatursteuerung** — wirken Sie mit nativen Befehlen auf das Fenster unter
  dem Zeiger: ⌘W schließen, ⌘M minimieren, ⌘F zoomen, ⌘H ausblenden, ⌘Q beenden
  — alle neu belegbar.
- **Sammelaktionen** — ⌥⌘W alle schließen, ⌥⌘M alle minimieren, ⌥⌘H alle bis auf
  das Fenster unter dem Zeiger ausblenden.
- **Neun Sprachen** — English, 简体中文, 繁體中文, 日本語, Français, Deutsch,
  Español, Português, Русский, in der App umschaltbar und sofort angewendet.
- **Nativ und unaufdringlich** — ein passives Overlay, das Mission Control nie
  die eigene Tastaturverarbeitung entzieht; nur in der Menüleiste, kein
  Dock-Symbol.
- **Automatische Updates** — signierte, notarisierte Versionen über Sparkle.

## Systemvoraussetzungen

- macOS 14.0 oder neuer
- Apple Silicon oder Intel (universelles Binärprogramm)
- Bedienungshilfen-Berechtigung (CloseUp liest Fenster über die
  Bedienungshilfen-API aus und wirkt darüber auf sie ein; es zeichnet niemals
  Ihren Bildschirm auf)

## Installation

Laden Sie die neueste `.dmg` von [Releases](https://github.com/oomol-lab/CloseUp/releases)
herunter, öffnen Sie sie und ziehen Sie CloseUp in den Programme-Ordner. Erteilen
Sie beim ersten Start den Zugriff auf die Bedienungshilfen unter
Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen — CloseUp
öffnet den richtigen Bereich für Sie.

## Verwendung

Öffnen Sie Mission Control wie gewohnt (mit drei/vier Fingern nach oben
streichen oder die Mission-Control-Taste). Bewegen Sie den Zeiger über ein
beliebiges Fenster, um sein Steuerelement-Cluster einzublenden, oder nutzen Sie
die Tastatur:

| Aktion | Tastenkürzel | Wirkt auf |
|---|---|---|
| Fenster schließen | ⌘W | Fenster unter dem Zeiger |
| Fenster minimieren | ⌘M | Fenster unter dem Zeiger |
| Fenster zoomen | ⌘F | Fenster unter dem Zeiger |
| App ausblenden | ⌘H | Fenster unter dem Zeiger |
| App beenden | ⌘Q | Fenster unter dem Zeiger |
| Alle Fenster schließen | ⌥⌘W | alle Fenster |
| Alle Fenster minimieren | ⌥⌘M | alle Fenster |
| Alle bis auf dieses ausblenden | ⌥⌘H | jede App außer der unter dem Zeiger |

Jedes Tastenkürzel ist unter Einstellungen → Tastenkürzel neu belegbar, und ein
globales Tastenkürzel kann CloseUp von überall aus ein- oder ausschalten.

## Einstellungen

- **Allgemein** — aktivieren/deaktivieren, beim Anmelden öffnen, welche
  Steuerschaltflächen erscheinen und die App-Sprache.
- **Tastenkürzel** — jede Aktion und den globalen Umschalter neu belegen.
- **Berechtigung** — Status der Bedienungshilfen und eine Erteilung mit einem
  Klick.
- **Updates** — automatische Prüfungen und ein manuelles „Nach Updates suchen“.

## Aus dem Quellcode erstellen

```bash
brew install xcodegen
make build      # Debug-Build (eine eigene Identität "CloseUp Dev")
make test       # Unit-Tests + i18n-Prüfungen
make run        # erstellen und starten
make dmg        # eine .dmg zum Installieren per Drag & Drop paketieren
```

Das Xcode-Projekt wird von XcodeGen aus `project.yml` generiert und ist nicht
eingecheckt. Siehe [docs/DESIGN.md](docs/DESIGN.md) für die Architektur und
[docs/RUNBOOK.md](docs/RUNBOOK.md) für den Release-Prozess.

## Lizenz

[GPL-3.0](LICENSE).

## Danksagung

Dank an [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl),
[DockDoor](https://github.com/ejbills/DockDoor) und
[alt-tab-macos](https://github.com/lwouis/alt-tab-macos): Die
Art, wie CloseUp die privaten Mission-Control-APIs verwendet, orientiert sich
daran, wie diese Projekte sie nutzen.
