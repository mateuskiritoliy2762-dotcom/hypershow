# HyperShow

Jogo de minigames para Roblox no estilo game show espacial. O apresentador robô **Hyper** comanda um campeonato com fases eliminatórias até a grande final. Ele sorteia o minigame e os modificadores de caos numa roleta, comenta as rodadas com voz gravada e muda de humor (do muito feliz ao modo furioso) conforme o desempenho dos jogadores.

O código é Luau (`--!strict`) e é sincronizado com o Roblox Studio (Script Sync / `tools/studio.py`). Veja o `CLAUDE.md` para as convenções do projeto.

## Estrutura

| Pasta | Conteúdo |
| --- | --- |
| `ServerScriptService/` | `Main.server.luau` e a lógica do servidor |
| `ServerScriptService/Services/` | Rodadas, campeonato, Hyper, humor, palco, área social, dados salvos, empurrão, ragdoll |
| `ServerScriptService/Minigames/` | Minigames (ex.: `NeonCollapse` — Desmoronamento Neon) |
| `ServerScriptService/Modifiers/` | Modificadores de caos (Turbo, Gravidade Lunar, Chuva de Meteoros…) |
| `ReplicatedStorage/Shared/` | `Config` (todos os números ajustáveis e textos), `Remotes`, `Types`, utilitários |
| `StarterPlayerScripts/` | `Client.client.luau` e os controllers do cliente (UI, câmera, cenas, sons…) |
| `tools/` | Scripts de construção do mapa no Studio (`build_*.luau`), ponte com o Studio (`studio.py`) e geradores de arte em Python |
| `robo/`, `arte/` | Roteiros das falas do Hyper |
| `docs/minigame-nbovo/` | Documentação do minigame novo (Gigante do Martelo, V2): leia-me, manifesto, validação e hashes |

## O que ficou só no Google Drive

Os arquivos binários e pesados não estão no repositório. Eles continuam na pasta [HyperShow_para_Drive](https://drive.google.com/drive/folders/16iUlgb46s-a7uaRR0G9vx3uw87am0nqQ):

- `1_projeto/historico_git.bundle` (~57 MB): o **histórico git completo** do projeto
- `1_projeto/robo/` e `1_projeto/arte/`: imagens PNG (rostos, ícones, cenário, logo)
- `2_mapa_do_studio/`: modelos `.rbxm` do Studio (Lobby, Hyper, Pódio, SpawnLobby, Espaço, Iluminação, efeitos de partículas)
- `3_blender/lobby_oficial/`: arquivos `.blend` e `.glb` do lobby
- `4_documentos/`: PDFs (Apresentação, Kit de Produção IA, Sistema de Campeonato)
- `minigame nbovo/`: modelos `.glb` / `.blend`, renders PNG, `.zip` e a pasta `Compatibilidade_GLTF`

### Recuperar o histórico antigo

Baixe o `historico_git.bundle` do Drive e rode:

```sh
git clone historico_git.bundle hypershow-historico
```

Para juntar esse histórico a este repositório, faça um `git fetch` do bundle e depois um merge ou rebase.
