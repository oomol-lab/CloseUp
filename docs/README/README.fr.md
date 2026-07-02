# CloseUp

[English](../../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · **Français** · [Deutsch](README.de.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

**Remettez les contrôles dans Mission Control.** CloseUp superpose des contrôles de fenêtre sur Mission Control natif de macOS — fermez, réduisez, agrandissez, masquez ou quittez n’importe quelle fenêtre sans quitter l’aperçu — et ajoute un contrôle complet au clavier. Gratuit, natif et open source.

## Captures d’écran

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/overlay-dark.png">
    <img alt="Contrôles de fenêtre superposés sur une vignette de Mission Control" src="../images/overlay-light.png" width="48%">
  </picture>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-general-en-dark.png">
    <img alt="Réglages généraux" src="../images/settings-general-en-light.png" width="49%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-shortcuts-en-dark.png">
    <img alt="Raccourcis clavier" src="../images/settings-shortcuts-en-light.png" width="49%">
  </picture>
</p>

## Fonctionnalités

- **Fermeture depuis l’aperçu** — survolez la miniature d’une fenêtre dans Mission Control et cliquez sur le × rouge pour la fermer instantanément, sans avoir à y basculer au préalable.
- **Tous les verbes de fenêtre** — réduisez, agrandissez, masquez l’app ou quittez l’app. Fermer, réduire et agrandir sont des boutons optionnels que vous pouvez activer ou désactiver dans les réglages ; masquer et quitter sont toujours affichés lorsque la fenêtre le permet.
- **Contrôle au clavier** — agissez sur la fenêtre située sous le pointeur avec des verbes natifs : ⌘W fermer, ⌘M réduire, ⌘F agrandir, ⌘H masquer, ⌘Q quitter — tous remappables.
- **Actions par lot** — ⌥⌘W tout fermer, ⌥⌘M tout réduire, ⌥⌘H tout masquer sauf la fenêtre sous le pointeur.
- **Neuf langues** — English, 简体中文, 繁體中文, 日本語, Français, Deutsch, Español, Português, Русский, permutables dans l’app et appliquées en direct.
- **Natif et discret** — une superposition passive qui n’interfère jamais avec la gestion clavier propre à Mission Control ; uniquement dans la barre des menus, sans icône dans le Dock.
- **Mise à jour automatique** — versions signées et notarisées via Sparkle, avec un canal bêta optionnel.

## Comparatif

CloseUp se concentre sur une seule chose : agir sur les fenêtres directement dans la vue **native** de Mission Control. Voici comment il se compare aux alternatives les plus proches qui font la même chose (vérifié le 2026-07-02 sur le site/dépôt officiel de chaque projet — voir les liens pour les sources ; les champs non documentés par l’éditeur sont marqués « Non documenté » plutôt que devinés) :

| | CloseUp | [Mission Control Close](https://missioncontrolclose.com/) | [Open Mission Control](https://github.com/nohackjustnoobb/OpenMissionControl) | [Mission Control Plus](https://www.fadel.io/missioncontrolplus) |
|---|---|---|---|---|
| Prix | Gratuit | 5 £ à vie (essai de 7 jours) | Gratuit | Payant, prix non publié (essai de 10 jours) |
| Licence | Open source (GPL-3.0) | Source fermée | Open source (GPL-3.0) | Source fermée |
| Actions sur la fenêtre sous le curseur | Fermer, réduire, agrandir, masquer, quitter | Fermer uniquement | Fermer, réduire, agrandir | Fermer, réduire, quitter (+ ouvrir) |
| Actions par lot | Tout fermer, tout réduire, tout masquer sauf une | Tout fermer | Non documenté | Non documenté |
| Raccourcis clavier remappables | Toutes les actions | A des raccourcis ; remappage non documenté | Fixes (⌘Q/⌘W/⌘M/⌘F) | Fixes (⌘W/⌘M/⌘Q/⏎) |
| Localisation | 9 langues, changeables dans l’app | Non documenté | Non documenté | Non documenté |
| macOS requis | 14.0+ | 26.0 (Tahoe)+ | Non documenté | 10.13+ |
| Architecture CPU | Apple Silicon et Intel, builds signés séparément | Apple Silicon uniquement | Non documenté | Non documenté |
| Distribution | Téléchargement direct + Homebrew, notarisé, mise à jour auto via Sparkle | Téléchargement direct, paiement via LemonSqueezy | GitHub + Homebrew (non signé — retrait manuel de la quarantaine) | Téléchargement direct |

D’autres outils de gestion de fenêtres macOS — [AltTab](https://github.com/lwouis/alt-tab-macos), [DockDoor](https://github.com/ejbills/DockDoor), [HyperDock](https://bahoom.com/hyperdock), [Contexts](https://contexts.co/) — proposent des actions de fenêtre proches (fermer, masquer, changer de fenêtre), mais via leur propre interface de switcher ou de survol du Dock plutôt que la vue native de Mission Control ; ils résolvent donc un problème connexe mais différent, et ne figurent pas dans le tableau ci-dessus.

## Configuration requise

- macOS 14.0 ou version ultérieure
- Apple Silicon (arm64) ou Intel (x86_64) — CloseUp fournit un build signé séparément pour chaque architecture ; téléchargez celui qui correspond à votre Mac
- Autorisation d’accessibilité (CloseUp lit les fenêtres et agit sur elles via l’API d’accessibilité ; il n’enregistre jamais votre écran)

## Installation

Téléchargez la version correspondant à la puce de votre Mac depuis [Releases](https://github.com/oomol-lab/CloseUp/releases) — `CloseUp-*-arm64.dmg` pour Apple Silicon, `CloseUp-*-x86_64.dmg` pour Intel — ouvrez-le, puis faites glisser CloseUp dans Applications. Vous pouvez aussi l’installer via Homebrew (l’architecture est détectée automatiquement) :

```bash
brew install --cask oomol-lab/tap/closeup
```

Au premier lancement, accordez l’accès à l’accessibilité dans Réglages Système → Confidentialité et sécurité → Accessibilité — CloseUp ouvre le bon volet pour vous.

## Utilisation

Ouvrez Mission Control comme d’habitude (balayez vers le haut avec trois ou quatre doigts, ou utilisez la touche Mission Control). Survolez n’importe quelle fenêtre pour faire apparaître son groupe de contrôles, ou utilisez le clavier :

| Action | Raccourci | Agit sur |
|---|---|---|
| Fermer la fenêtre | ⌘W | la fenêtre sous le pointeur |
| Réduire la fenêtre | ⌘M | la fenêtre sous le pointeur |
| Agrandir la fenêtre | ⌘F | la fenêtre sous le pointeur |
| Masquer l’app | ⌘H | la fenêtre sous le pointeur |
| Quitter l’app | ⌘Q | la fenêtre sous le pointeur |
| Fermer toutes les fenêtres | ⌥⌘W | toutes les fenêtres |
| Réduire toutes les fenêtres | ⌥⌘M | toutes les fenêtres |
| Tout masquer sauf celle-ci | ⌥⌘H | toutes les apps sauf celle sous le pointeur |

Chaque raccourci est remappable dans Réglages → Raccourcis. Activez ou désactivez CloseUp à tout moment depuis l’icône de la barre des menus ou Réglages → Général.

## Réglages

- **Général** — activation/désactivation, ouverture à la connexion, masquer l’icône de la barre des menus, état de l’accessibilité avec octroi en un clic, boutons de contrôle affichés, et langue de l’app.
- **Raccourcis** — remappez chaque action.
- **Mises à jour** — vérifications automatiques (canal Stable ou Bêta) et bouton manuel « Rechercher les mises à jour ».
- **À propos** — version, licence, lien vers le dépôt GitHub, et remerciements.

## Compiler depuis les sources

```bash
brew install xcodegen
make build      # Compilation Debug (une identité « CloseUp Dev » distincte)
make dev-cert   # optionnel : identité de signature locale stable, pour que
                # l’autorisation Accessibilité survive aux recompilations
make test       # tests unitaires + garde-fous i18n
make run        # compiler et lancer
make dmg        # créer un .dmg à installer par glisser-déposer
```

Le projet Xcode est généré à partir de `project.yml` par XcodeGen et n’est pas versionné. Consultez [../DESIGN.md](../DESIGN.md) pour l’architecture et [../RUNBOOK.md](../RUNBOOK.md) pour le processus de publication.

## Licence

[GPL-3.0](../../LICENSE).

## Remerciements

Merci à [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl), [DockDoor](https://github.com/ejbills/DockDoor) et [alt-tab-macos](https://github.com/lwouis/alt-tab-macos) : l’utilisation par CloseUp des API privées de Mission Control s’inspire de la manière dont ces projets les emploient.
