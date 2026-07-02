# CloseUp

[English](../../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **Español** · [Português](README.pt-BR.md) · [Русский](README.ru.md)

**Devuelve los controles a Mission Control.** CloseUp superpone controles de
ventana sobre el Mission Control nativo de macOS —cerrar, minimizar, hacer zoom,
ocultar o salir de cualquier ventana sin abandonar la vista general— y añade
control total con el teclado. Gratis, nativo y de código abierto.

## Funciones

- **Cerrar desde la vista general** — pasa el puntero sobre la miniatura de una
  ventana en Mission Control y haz clic en la × roja para cerrarla al instante,
  sin tener que cambiar a ella primero.
- **Todas las acciones de ventana** — minimizar, hacer zoom, ocultar la app o
  salir de la app, cada una como un botón opcional que puedes activar o
  desactivar.
- **Control con el teclado** — actúa sobre la ventana situada bajo el puntero con
  acciones nativas: ⌘W cerrar, ⌘M minimizar, ⌘F zoom, ⌘H ocultar, ⌘Q salir,
  todas reasignables.
- **Acciones en lote** — ⌥⌘W cerrar todas, ⌥⌘M minimizar todas, ⌥⌘H ocultar todas
  menos la que está bajo el puntero.
- **Nueve idiomas** — English, 简体中文, 繁體中文, 日本語, Français, Deutsch,
  Español, Português, Русский, cambiables dentro de la app y aplicados al
  instante.
- **Nativo y discreto** — una superposición pasiva que nunca interfiere con la
  gestión del teclado propia de Mission Control; solo en la barra de menús, sin
  icono en el Dock.
- **Actualización automática** — versiones firmadas y certificadas mediante
  Sparkle.

## Requisitos

- macOS 14.0 o posterior
- Apple Silicon o Intel (binario universal)
- Permiso de Accesibilidad (CloseUp lee las ventanas y actúa sobre ellas a través
  de la API de Accesibilidad; nunca graba tu pantalla)

## Instalación

Descarga el archivo `.dmg` más reciente desde [Releases](https://github.com/oomol-lab/CloseUp/releases),
ábrelo y arrastra CloseUp a Aplicaciones. En el primer arranque, concede el
acceso de Accesibilidad en Ajustes del Sistema → Privacidad y seguridad →
Accesibilidad: CloseUp abre el panel correcto por ti.

## Uso

Abre Mission Control como de costumbre (desliza hacia arriba con tres o cuatro
dedos, o pulsa la tecla Mission Control). Pasa el puntero sobre cualquier ventana
para mostrar su grupo de controles, o usa el teclado:

| Acción | Atajo | Actúa sobre |
|---|---|---|
| Cerrar ventana | ⌘W | la ventana bajo el puntero |
| Minimizar ventana | ⌘M | la ventana bajo el puntero |
| Hacer zoom en la ventana | ⌘F | la ventana bajo el puntero |
| Ocultar app | ⌘H | la ventana bajo el puntero |
| Salir de la app | ⌘Q | la ventana bajo el puntero |
| Cerrar todas las ventanas | ⌥⌘W | todas las ventanas |
| Minimizar todas las ventanas | ⌥⌘M | todas las ventanas |
| Ocultar todas menos esta | ⌥⌘H | todas las apps excepto la que está bajo el puntero |

Cada atajo se puede reasignar en Ajustes → Atajos, y un atajo de teclado global
puede activar o desactivar CloseUp desde cualquier lugar.

## Ajustes

- **General** — activar/desactivar, abrir al iniciar sesión, qué botones de
  control aparecen y el idioma dentro de la app.
- **Atajos** — reasigna cada acción y el conmutador global.
- **Permiso** — estado de Accesibilidad y concesión con un solo clic.
- **Actualizaciones** — comprobaciones automáticas y un «Buscar actualizaciones»
  manual.

## Compilar desde el código fuente

```bash
brew install xcodegen
make build      # Compilación de depuración (una identidad "CloseUp Dev" distinta)
make test       # pruebas unitarias + comprobaciones de i18n
make run        # compilar y ejecutar
make dmg        # empaquetar un .dmg de instalación por arrastre
```

El proyecto de Xcode lo genera XcodeGen a partir de `project.yml` y no se incluye
en el repositorio. Consulta [docs/DESIGN.md](docs/DESIGN.md) para la arquitectura
y [docs/RUNBOOK.md](docs/RUNBOOK.md) para el proceso de publicación.

## Licencia

[GPL-3.0](LICENSE).

## Agradecimientos

Gracias a [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl),
[DockDoor](https://github.com/ejbills/DockDoor) y
[alt-tab-macos](https://github.com/lwouis/alt-tab-macos): el uso que hace CloseUp de las API privadas de Mission Control se
inspira en cómo las emplean estos proyectos.
