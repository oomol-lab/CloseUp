# CloseUp

[English](../../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · **Français** · [Deutsch](README.de.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

**Remettez les contrôles dans Mission Control.** CloseUp superpose des contrôles de fenêtre sur Mission Control natif de macOS — fermez, réduisez, agrandissez, masquez ou quittez n’importe quelle fenêtre sans quitter l’aperçu — et ajoute un contrôle complet au clavier. Gratuit, natif et open source.

## Fonctionnalités

- **Fermeture depuis l’aperçu** — survolez la miniature d’une fenêtre dans Mission Control et cliquez sur le × rouge pour la fermer instantanément, sans avoir à y basculer au préalable.
- **Tous les verbes de fenêtre** — réduisez, agrandissez, masquez l’app ou quittez l’app, chacun sous la forme d’un bouton optionnel que vous pouvez activer ou désactiver.
- **Contrôle au clavier** — agissez sur la fenêtre située sous le pointeur avec des verbes natifs : ⌘W fermer, ⌘M réduire, ⌘F agrandir, ⌘H masquer, ⌘Q quitter — tous remappables.
- **Actions par lot** — ⌥⌘W tout fermer, ⌥⌘M tout réduire, ⌥⌘H tout masquer sauf la fenêtre sous le pointeur.
- **Neuf langues** — English, 简体中文, 繁體中文, 日本語, Français, Deutsch, Español, Português, Русский, permutables dans l’app et appliquées en direct.
- **Natif et discret** — une superposition passive qui n’interfère jamais avec la gestion clavier propre à Mission Control ; uniquement dans la barre des menus, sans icône dans le Dock.
- **Mise à jour automatique** — versions signées et notarisées via Sparkle.

## Configuration requise

- macOS 14.0 ou version ultérieure
- Apple Silicon ou Intel (binaire universel)
- Autorisation d’accessibilité (CloseUp lit les fenêtres et agit sur elles via l’API d’accessibilité ; il n’enregistre jamais votre écran)

## Installation

Téléchargez le dernier fichier `.dmg` depuis [Releases](https://github.com/oomol-lab/CloseUp/releases), ouvrez-le, puis faites glisser CloseUp dans Applications. Au premier lancement, accordez l’accès à l’accessibilité dans Réglages Système → Confidentialité et sécurité → Accessibilité — CloseUp ouvre le bon volet pour vous.

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

Chaque raccourci est remappable dans Réglages → Raccourcis, et un raccourci clavier global permet d’activer ou de désactiver CloseUp depuis n’importe où.

## Réglages

- **Général** — activation/désactivation, ouverture à la connexion, boutons de contrôle affichés et langue de l’app.
- **Raccourcis** — remappez chaque action ainsi que le basculement global.
- **Autorisation** — état de l’accessibilité et octroi en un clic.
- **Mises à jour** — vérifications automatiques et bouton manuel « Rechercher les mises à jour ».

## Compiler depuis les sources

```bash
brew install xcodegen
make build      # Compilation Debug (une identité « CloseUp Dev » distincte)
make test       # tests unitaires + garde-fous i18n
make run        # compiler et lancer
make dmg        # créer un .dmg à installer par glisser-déposer
```

Le projet Xcode est généré à partir de `project.yml` par XcodeGen et n’est pas versionné. Consultez [docs/DESIGN.md](docs/DESIGN.md) pour l’architecture et [docs/RUNBOOK.md](docs/RUNBOOK.md) pour le processus de publication.

## Licence

[GPL-3.0](LICENSE).

## Remerciements

Merci à [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl), [DockDoor](https://github.com/ejbills/DockDoor) et [alt-tab-macos](https://github.com/lwouis/alt-tab-macos) : l’utilisation par CloseUp des API privées de Mission Control s’inspire de la manière dont ces projets les emploient.
