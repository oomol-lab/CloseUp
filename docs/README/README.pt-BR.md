# CloseUp

[English](../../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · **Português** · [Русский](README.ru.md)

**Devolva os controles ao Mission Control.** O CloseUp sobrepõe controles de janela
ao Mission Control nativo do macOS — feche, minimize, faça zoom, oculte ou encerre qualquer
janela sem sair da visão geral — e adiciona controle total pelo teclado.
Gratuito, nativo e de código aberto.

## Recursos

- **Feche pela visão geral** — passe o ponteiro sobre a miniatura de uma janela no Mission Control e
  clique no × vermelho para fechá-la instantaneamente, sem precisar alternar para ela antes.
- **Todas as ações de janela** — minimize, faça zoom, oculte o app ou encerre o app, cada uma como
  um botão opcional que você pode ativar ou desativar.
- **Controle pelo teclado** — atue sobre a janela sob o ponteiro com ações nativas:
  ⌘W fechar, ⌘M minimizar, ⌘F zoom, ⌘H ocultar, ⌘Q encerrar — todas remapeáveis.
- **Ações em lote** — ⌥⌘W fechar tudo, ⌥⌘M minimizar tudo, ⌥⌘H ocultar todas exceto a
  que está sob o ponteiro.
- **Nove idiomas** — English, 简体中文, 繁體中文, 日本語, Français, Deutsch,
  Español, Português, Русский, alternáveis no app e aplicados em tempo real.
- **Nativo e discreto** — uma sobreposição passiva que nunca interfere no próprio gerenciamento de teclado
  do Mission Control; apenas na barra de menus, sem ícone no Dock.
- **Atualização automática** — versões assinadas e autenticadas via Sparkle.

## Requisitos

- macOS 14.0 ou posterior
- Apple Silicon ou Intel (binário universal)
- Permissão de Acessibilidade (o CloseUp lê e atua sobre as janelas por meio da
  API de Acessibilidade; ele nunca grava sua tela)

## Instalação

Baixe o `.dmg` mais recente em [Releases](https://github.com/oomol-lab/CloseUp/releases),
abra-o e arraste o CloseUp para a pasta Aplicativos. Na primeira execução, conceda acesso de
Acessibilidade em Ajustes do Sistema → Privacidade e Segurança → Acessibilidade — o CloseUp abre
o painel correto para você.

## Uso

Abra o Mission Control normalmente (deslize para cima com três/quatro dedos ou use a tecla Mission
Control). Passe o ponteiro sobre qualquer janela para revelar seu conjunto de controles ou use o
teclado:

| Ação | Atalho | Atua sobre |
|---|---|---|
| Fechar janela | ⌘W | janela sob o ponteiro |
| Minimizar janela | ⌘M | janela sob o ponteiro |
| Zoom da janela | ⌘F | janela sob o ponteiro |
| Ocultar app | ⌘H | janela sob o ponteiro |
| Encerrar app | ⌘Q | janela sob o ponteiro |
| Fechar todas as janelas | ⌥⌘W | todas as janelas |
| Minimizar todas as janelas | ⌥⌘M | todas as janelas |
| Ocultar todas exceto esta | ⌥⌘H | todos os apps exceto o que está sob o ponteiro |

Todos os atalhos são remapeáveis em Ajustes → Atalhos, e uma tecla de atalho global pode
ativar ou desativar o CloseUp de qualquer lugar.

## Ajustes

- **Geral** — ativar/desativar, abrir ao iniciar a sessão, quais botões de controle aparecem
  e o idioma do app.
- **Atalhos** — remapeie cada ação e o botão global de ativação.
- **Permissão** — status da Acessibilidade e concessão com um clique.
- **Atualizações** — verificações automáticas e um botão manual "Verificar Atualizações".

## Compilar a partir do código-fonte

```bash
brew install xcodegen
make build      # Compilação Debug (uma identidade distinta "CloseUp Dev")
make test       # testes unitários + verificações de i18n
make run        # compilar e executar
make dmg        # empacotar um .dmg de arrastar para instalar
```

O projeto do Xcode é gerado a partir de `project.yml` pelo XcodeGen e não é versionado
no repositório. Consulte [docs/DESIGN.md](docs/DESIGN.md) para a arquitetura e
[docs/RUNBOOK.md](docs/RUNBOOK.md) para o processo de lançamento.

## Licença

[GPL-3.0](LICENSE).

## Agradecimentos

Obrigado a [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl),
[DockDoor](https://github.com/ejbills/DockDoor) e
[alt-tab-macos](https://github.com/lwouis/alt-tab-macos): o uso que
o CloseUp faz das APIs privadas do Mission Control se inspira em como esses
projetos as utilizam.
