# CloseUp

[English](../../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **Español** · [Português](README.pt-BR.md) · [Русский](README.ru.md)

**Devuelve los controles a Mission Control.** CloseUp superpone controles de
ventana sobre el Mission Control nativo de macOS —cerrar, minimizar, maximizar,
ocultar o salir de cualquier ventana sin abandonar la vista general— y añade
control total con el teclado. Gratis, nativo y de código abierto.

## Capturas de pantalla

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/overlay-dark.png">
    <img alt="Controles de ventana superpuestos en una miniatura de Mission Control" src="../images/overlay-light.png" width="48%">
  </picture>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-general-en-dark.png">
    <img alt="Ajustes generales" src="../images/settings-general-en-light.png" width="49%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-shortcuts-en-dark.png">
    <img alt="Atajos de teclado" src="../images/settings-shortcuts-en-light.png" width="49%">
  </picture>
</p>

## Funciones

- **Cerrar desde la vista general** — pasa el puntero sobre la miniatura de una
  ventana en Mission Control y haz clic en la × roja para cerrarla al instante,
  sin tener que cambiar a ella primero.
- **Todas las acciones de ventana** — minimizar, maximizar, ocultar la app o
  salir de la app. Cerrar, minimizar y maximizar son botones opcionales que
  puedes activar o desactivar en Ajustes; ocultar y salir se muestran siempre
  que la ventana lo permita.
- **Control con el teclado** — actúa sobre la ventana situada bajo el puntero con
  acciones nativas: ⌘W cerrar, ⌘M minimizar, ⌘F maximizar, ⌘H ocultar, ⌘Q salir,
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
  Sparkle, con un canal beta opcional.

## Comparativa

CloseUp se centra en una sola cosa: actuar sobre las ventanas directamente
dentro de la vista **nativa** de Mission Control. Así se compara con las
alternativas más cercanas que hacen lo mismo (verificado el 2026-07-02 en el
sitio/repositorio oficial de cada proyecto —consulta los enlaces para ver las
fuentes—; los campos que el fabricante no documenta se marcan como «No
documentado» en lugar de adivinarse):

| | CloseUp | [Mission Control Close](https://missioncontrolclose.com/) | [Open Mission Control](https://github.com/nohackjustnoobb/OpenMissionControl) | [Mission Control Plus](https://www.fadel.io/missioncontrolplus) |
|---|---|---|---|---|
| Precio | Gratis | £5 de pago único (prueba de 7 días) | Gratis | De pago, precio no publicado (prueba de 10 días) |
| Licencia | Código abierto (GPL-3.0) | Código cerrado | Código abierto (GPL-3.0) | Código cerrado |
| Acciones sobre la ventana bajo el cursor | Cerrar, minimizar, maximizar, ocultar, salir | Solo cerrar | Cerrar, minimizar, maximizar | Cerrar, minimizar, salir (+ abrir) |
| Acciones en lote | Cerrar todas, minimizar todas, ocultar todas menos una | Cerrar todas | No documentado | No documentado |
| Atajos de teclado reasignables | Todas las acciones | Tiene atajos; no se documenta si son reasignables | Fijos (⌘Q/⌘W/⌘M/⌘F) | Fijos (⌘W/⌘M/⌘Q/⏎) |
| Localización | 9 idiomas, cambiables en la app | No documentado | No documentado | No documentado |
| macOS necesario | 14.0+ | 26.0 (Tahoe)+ | No documentado | 10.13+ |
| Arquitectura de CPU | Apple Silicon e Intel, compilaciones firmadas por separado | Solo Apple Silicon | No documentado | No documentado |
| Distribución | Descarga directa + Homebrew, certificado, actualización automática con Sparkle | Descarga directa, pago mediante LemonSqueezy | GitHub + Homebrew (sin firmar; hay que quitar la cuarentena manualmente) | Descarga directa |

Otras herramientas de gestión de ventanas de macOS —[AltTab](https://github.com/lwouis/alt-tab-macos), [DockDoor](https://github.com/ejbills/DockDoor), [HyperDock](https://bahoom.com/hyperdock), [Contexts](https://contexts.co/)— ofrecen acciones de ventana similares (cerrar, ocultar, cambiar), pero a través de su propio conmutador o de una interfaz al pasar el cursor por el Dock, no de la vista nativa de Mission Control, por lo que resuelven un problema relacionado pero distinto y no se incluyen en la comparativa anterior.

## Requisitos

- macOS 14.0 o posterior
- Apple Silicon (arm64) o Intel (x86_64): CloseUp distribuye una compilación
  firmada por separado para cada arquitectura; descarga la que corresponda a
  tu Mac
- Permiso de Accesibilidad (CloseUp lee las ventanas y actúa sobre ellas a través
  de la API de Accesibilidad; nunca graba tu pantalla)

## Instalación

Descarga la versión correspondiente al chip de tu Mac desde
[Releases](https://github.com/oomol-lab/CloseUp/releases) —`CloseUp-*-arm64.dmg`
para Apple Silicon, `CloseUp-*-x86_64.dmg` para Intel—, ábrela y arrastra
CloseUp a Aplicaciones. También puedes instalarlo con Homebrew (detecta la
arquitectura automáticamente):

```bash
brew install --cask oomol-lab/tap/closeup
```

En el primer arranque, concede el acceso de Accesibilidad en Ajustes del Sistema →
Privacidad y seguridad → Accesibilidad: CloseUp abre el panel correcto por ti.

## Uso

Abre Mission Control como de costumbre (desliza hacia arriba con tres o cuatro
dedos, o pulsa la tecla Mission Control). Pasa el puntero sobre cualquier ventana
para mostrar su grupo de controles, o usa el teclado:

| Acción | Atajo | Actúa sobre |
|---|---|---|
| Cerrar ventana | ⌘W | la ventana bajo el puntero |
| Minimizar ventana | ⌘M | la ventana bajo el puntero |
| Maximizar ventana | ⌘F | la ventana bajo el puntero |
| Ocultar app | ⌘H | la ventana bajo el puntero |
| Salir de la app | ⌘Q | la ventana bajo el puntero |
| Cerrar todas las ventanas | ⌥⌘W | todas las ventanas |
| Minimizar todas las ventanas | ⌥⌘M | todas las ventanas |
| Ocultar todas menos esta | ⌥⌘H | todas las apps excepto la que está bajo el puntero |

Cada atajo se puede reasignar en Ajustes → Atajos. Puedes activar o desactivar
CloseUp en cualquier momento desde el icono de la barra de menús o Ajustes →
General.

## Ajustes

- **General** — activar/desactivar, abrir al iniciar sesión, ocultar el icono
  de la barra de menús, estado de Accesibilidad con concesión de un solo clic,
  qué botones de control aparecen, y el idioma dentro de la app.
- **Atajos** — reasigna cada acción.
- **Actualizaciones** — comprobaciones automáticas (canal Estable o Beta) y un
  «Buscar actualizaciones» manual.
- **Acerca de** — versión, licencia, enlace al repositorio de GitHub, y
  agradecimientos.

## Compilar desde el código fuente

```bash
brew install xcodegen
make build      # Compilación de depuración (una identidad "CloseUp Dev" distinta)
make dev-cert   # opcional: identidad de firma local estable para que el permiso
                # de Accesibilidad sobreviva a las recompilaciones
make test       # pruebas unitarias + comprobaciones de i18n
make run        # compilar y ejecutar
make dmg        # empaquetar un .dmg de instalación por arrastre
```

El proyecto de Xcode lo genera XcodeGen a partir de `project.yml` y no se incluye
en el repositorio. Consulta [../DESIGN.md](../DESIGN.md) para la arquitectura
y [../RUNBOOK.md](../RUNBOOK.md) para el proceso de publicación.

## Licencia

[GPL-3.0](../../LICENSE).

## Agradecimientos

Gracias a [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl),
[DockDoor](https://github.com/ejbills/DockDoor) y
[alt-tab-macos](https://github.com/lwouis/alt-tab-macos): el uso que hace CloseUp de las API privadas de Mission Control se
inspira en cómo las emplean estos proyectos.
