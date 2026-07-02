# CloseUp

[English](../../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Français](README.fr.md) · **Deutsch** · [Español](README.es.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

**Bringen Sie die Steuerelemente zurück in Mission Control.** CloseUp blendet
Fenstersteuerungen in das native macOS Mission Control ein — schließen,
im Dock ablegen, maximieren, ausblenden oder beenden Sie ein beliebiges Fenster,
ohne die Übersicht zu verlassen — und ergänzt sie um vollständige
Tastatursteuerung. Kostenlos, nativ und quelloffen.

## Screenshots

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/overlay-dark.png">
    <img alt="Fenstersteuerung über einer Mission-Control-Miniatur" src="../images/overlay-light.png" width="48%">
  </picture>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-general-en-dark.png">
    <img alt="Allgemeine Einstellungen" src="../images/settings-general-en-light.png" width="49%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-shortcuts-en-dark.png">
    <img alt="Tastaturkurzbefehle" src="../images/settings-shortcuts-en-light.png" width="49%">
  </picture>
</p>

## Funktionen

- **Schließen aus der Übersicht** — bewegen Sie den Zeiger über ein
  Fenster-Miniaturbild in Mission Control und klicken Sie auf das rote ×, um es
  sofort zu schließen, ohne vorher dorthin zu wechseln.
- **Jeder Fensterbefehl** — im Dock ablegen, maximieren, App ausblenden oder App
  beenden. Schließen, Im-Dock-Ablegen und Maximieren sind optionale
  Schaltflächen, die Sie in den Einstellungen ein- oder ausschalten können;
  Ausblenden und Beenden werden immer angezeigt, wenn das Fenster sie
  unterstützt.
- **Tastatursteuerung** — wirken Sie mit nativen Befehlen auf das Fenster unter
  dem Zeiger: ⌘W schließen, ⌘M im Dock ablegen, ⌘F maximieren, ⌘H ausblenden,
  ⌘Q beenden — alle neu belegbar.
- **Sammelaktionen** — ⌥⌘W alle schließen, ⌥⌘M alle im Dock ablegen, ⌥⌘H alle
  bis auf das Fenster unter dem Zeiger ausblenden.
- **Neun Sprachen** — English, 简体中文, 繁體中文, 日本語, Français, Deutsch,
  Español, Português, Русский, in der App umschaltbar und sofort angewendet.
- **Nativ und unaufdringlich** — ein passives Overlay, das Mission Control nie
  die eigene Tastaturverarbeitung entzieht; nur in der Menüleiste, kein
  Dock-Symbol.
- **Automatische Updates** — signierte, notarisierte Versionen über Sparkle, mit
  optionalem Beta-Kanal.

## Im Vergleich

CloseUp konzentriert sich auf eine Sache — Fenster direkt in der **nativen**
Mission-Control-Ansicht zu bedienen. So schneidet es im Vergleich zu den
nächstliegenden Alternativen ab, die dasselbe tun (Stand 2026-07-02, geprüft
anhand der jeweiligen offiziellen Website/Repo — Quellen siehe Links; vom
Anbieter nicht dokumentierte Felder sind als „nicht dokumentiert" markiert
statt geraten):

| | CloseUp | [Mission Control Close](https://missioncontrolclose.com/) | [Open Mission Control](https://github.com/nohackjustnoobb/OpenMissionControl) | [Mission Control Plus](https://www.fadel.io/missioncontrolplus) |
|---|---|---|---|---|
| Preis | Kostenlos | 5 £ einmalig (7 Tage Testphase) | Kostenlos | Kostenpflichtig, Preis nicht veröffentlicht (10 Tage Testphase) |
| Lizenz | Open Source (GPL-3.0) | Closed Source | Open Source (GPL-3.0) | Closed Source |
| Aktionen am Fenster unter dem Zeiger | Schließen, im Dock ablegen, maximieren, ausblenden, beenden | Nur Schließen | Schließen, im Dock ablegen, maximieren | Schließen, im Dock ablegen, beenden (+ öffnen) |
| Sammelaktionen | Alle schließen, alle im Dock ablegen, alle bis auf eines ausblenden | Alle schließen | Nicht dokumentiert | Nicht dokumentiert |
| Neu belegbare Tastenkürzel | Jede Aktion | Hat Tastenkürzel; Neubelegung nicht dokumentiert | Fest (⌘Q/⌘W/⌘M/⌘F) | Fest (⌘W/⌘M/⌘Q/⏎) |
| Lokalisierung | 9 Sprachen, in der App umschaltbar | Nicht dokumentiert | Nicht dokumentiert | Nicht dokumentiert |
| Erforderliches macOS | 14.0+ | 26.0 (Tahoe)+ | Nicht dokumentiert | 10.13+ |
| CPU-Architektur | Apple Silicon & Intel, getrennt signierte Builds | Nur Apple Silicon | Nicht dokumentiert | Nicht dokumentiert |
| Vertrieb | Direkter Download + Homebrew, notarisiert, automatisches Update über Sparkle | Direkter Download, Checkout über LemonSqueezy | GitHub + Homebrew (unsigniert — Quarantäne-Flag muss manuell entfernt werden) | Direkter Download |

Andere macOS-Fenstermanagement-Tools — [AltTab](https://github.com/lwouis/alt-tab-macos), [DockDoor](https://github.com/ejbills/DockDoor), [HyperDock](https://bahoom.com/hyperdock), [Contexts](https://contexts.co/) — bieten verwandte Fensteraktionen (Schließen, Ausblenden, Wechseln), allerdings über eine eigene Switcher- oder Dock-Hover-Oberfläche statt der nativen Mission-Control-Ansicht. Sie lösen also ein verwandtes, aber anderes Problem und sind daher nicht in der obigen Tabelle enthalten.

## Systemvoraussetzungen

- macOS 14.0 oder neuer
- Apple Silicon (arm64) oder Intel (x86_64) — CloseUp liefert für jede
  Architektur einen separat signierten Build; laden Sie den zu Ihrem Mac
  passenden herunter
- Bedienungshilfen-Berechtigung (CloseUp liest Fenster über die
  Bedienungshilfen-API aus und wirkt darüber auf sie ein; es zeichnet niemals
  Ihren Bildschirm auf)

## Installation

Laden Sie die zu Ihrem Mac-Chip passende Version von
[Releases](https://github.com/oomol-lab/CloseUp/releases) herunter —
`CloseUp-*-arm64.dmg` für Apple Silicon, `CloseUp-*-x86_64.dmg` für Intel —,
öffnen Sie sie und ziehen Sie CloseUp in den Programme-Ordner. Alternativ per
Homebrew installieren (die Architektur wird automatisch erkannt):

```bash
brew install --cask oomol-lab/tap/closeup
```

Erteilen Sie beim ersten Start den Zugriff auf die Bedienungshilfen unter
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
| Fenster im Dock ablegen | ⌘M | Fenster unter dem Zeiger |
| Fenster maximieren | ⌘F | Fenster unter dem Zeiger |
| App ausblenden | ⌘H | Fenster unter dem Zeiger |
| App beenden | ⌘Q | Fenster unter dem Zeiger |
| Alle Fenster schließen | ⌥⌘W | alle Fenster |
| Alle Fenster im Dock ablegen | ⌥⌘M | alle Fenster |
| Alle bis auf dieses ausblenden | ⌥⌘H | jede App außer der unter dem Zeiger |

Jedes Tastenkürzel ist unter Einstellungen → Tastenkürzel neu belegbar. CloseUp
lässt sich jederzeit über das Menüleistensymbol oder Einstellungen → Allgemein
ein- oder ausschalten.

## Einstellungen

- **Allgemein** — aktivieren/deaktivieren, beim Anmelden öffnen, Menüleistensymbol
  ausblenden, Status der Bedienungshilfen mit Erteilung per Klick, welche
  Steuerschaltflächen erscheinen, und die App-Sprache.
- **Tastenkürzel** — jede Aktion neu belegen.
- **Updates** — automatische Prüfungen (Stabil- oder Beta-Kanal) und ein
  manuelles „Nach Updates suchen“.
- **Info** — Version, Lizenz, Link zum GitHub-Repo und Danksagungen.

## Aus dem Quellcode erstellen

```bash
brew install xcodegen
make build      # Debug-Build (eine eigene Identität "CloseUp Dev")
make dev-cert   # optional: stabile lokale Signaturidentität, damit die
                # Bedienungshilfen-Berechtigung Rebuilds übersteht
make test       # Unit-Tests + i18n-Prüfungen
make run        # erstellen und starten
make dmg        # eine .dmg zum Installieren per Drag & Drop paketieren
```

Das Xcode-Projekt wird von XcodeGen aus `project.yml` generiert und ist nicht
eingecheckt. Siehe [../DESIGN.md](../DESIGN.md) für die Architektur und
[../RUNBOOK.md](../RUNBOOK.md) für den Release-Prozess.

## Lizenz

[GPL-3.0](../../LICENSE).

## Danksagung

Dank an [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl),
[DockDoor](https://github.com/ejbills/DockDoor) und
[alt-tab-macos](https://github.com/lwouis/alt-tab-macos): Die
Art, wie CloseUp die privaten Mission-Control-APIs verwendet, orientiert sich
daran, wie diese Projekte sie nutzen.
