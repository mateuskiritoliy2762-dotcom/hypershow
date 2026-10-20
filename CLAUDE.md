# HyperShow: Minigames do Caos (Roblox)

## Visão
Party game 3D estilo programa de auditório intergaláctico. Um robô apresentador
(Hyper) sorteia minigames curtos (60-90 s) e às vezes um Modificador de Caos.
Público: 7-16 anos, maioria no celular. Servidor: 12-24 jogadores.

## Regras de arquitetura (NÃO quebrar)
- Linguagem: Luau com --!strict no topo de todo módulo novo.
- O SERVIDOR é a autoridade: vitória, moedas, XP, eliminação, compras.
  O cliente só envia intenções ("quero empurrar") e mostra efeitos.
- Toda RemoteEvent valida: tipo dos argumentos, cooldown, distância,
  estado da rodada. Nunca confiar em valores vindos do cliente.
- Um único ModuleScript por sistema. Nada de lógica solta em scripts.
- Minigames são plugins: cada um é um ModuleScript em
  ServerScriptService/Minigames/ que segue a interface MinigameDef.
- Modificadores também são plugins em ServerScriptService/Modifiers/.
- Dados do jogador: um único DataService com ProfileStore-style
  (session lock, autosave a cada 60 s, salvar no PlayerRemoving e
  BindToClose, retry com backoff). Nunca escrever DataStore direto
  fora do DataService.
- Mobile primeiro: botões grandes, UI escalável (Scale, não Offset),
  UIAspectRatioConstraint, StreamingEnabled ligado.
- Performance: nada de loops com wait() curto em cada peça; usar
  RunService.Heartbeat central ou eventos. Limpar conexões (Maid/Trove)
  ao fim de cada rodada.

## Estrutura de pastas (Script Sync)
ServerScriptService/
  Main.server.luau            -- inicia os serviços
  Services/RoundService.luau  -- máquina de estados da rodada
  Services/DataService.luau
  Services/RewardService.luau
  Services/ShopService.luau
  Services/PushService.luau
  Services/BotService.luau
  Minigames/<Nome>.luau
  Modifiers/<Nome>.luau
ReplicatedStorage/
  Shared/Config.luau          -- tempos, valores, preços (TUDO configurável aqui)
  Shared/Types.luau           -- MinigameDef, ModifierDef, PlayerData
  Shared/Remotes.luau         -- cria/obtém RemoteEvents por nome
  Shared/Util/*.luau
StarterPlayerScripts/
  Client.client.luau
  Controllers/UIController.luau
  Controllers/RagdollController.luau
  Controllers/InputController.luau

## Estados da rodada
Intermission(25s) -> Spin(5s) -> Teleport -> Intro(3s, aviso de 3 palavras)
-> Playing(60-90s) -> Results(10s, pódio) -> Intermission

## Convenções
- Nomes em inglês no código; textos visíveis ao jogador em português (BR).
- Todo texto visível passa por Config/Strings para facilitar tradução.
- Ao terminar uma tarefa: rodar playtest via MCP, ler o Output e
  corrigir erros antes de dizer que terminou.
- Ao criar algo que dependa de um asset que ainda não existe, criar um
  placeholder (Part colorida com o nome do asset) e listar no final.

## Fora do escopo por enquanto
Gamepasses, Developer Products, pets, roleta diária, Boombox.
(Entram na Fase 4, depois do jogo divertido.)
