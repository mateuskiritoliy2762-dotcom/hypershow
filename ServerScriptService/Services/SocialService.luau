--!strict
-- Área social do lobby (autoridade do servidor):
-- * Inscrição: todo mundo nasce na ilha de nascimento (workspace.SpawnLobby). Quem entra no vórtice do portal
--   fica com o atributo HyperShowQueued = true (a contagem da rodada começa) e vai para a plateia do palco
--   (Lobby.PortalArrivals). Fica inscrito até pedir "Ficar no lobby" (remote LeaveQueue), que o devolve à ilha
--   de nascimento. O RoundService só chama inscritos. Inscrito que renasce fora de partida (morreu no minigame,
--   fim da rodada) volta para a plateia do palco, não para a ilha de nascimento.
-- * Espectador: o cliente pede (remote SpectateFocus) e o servidor muda o ReplicationFocus do jogador para a
--   arena, para ela carregar no aparelho dele mesmo com o personagem no lobby.
-- * Segurança: quem não está numa partida e cai/escapa da ilha volta para um spawn do lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Settings = Config.Social

local SocialService = {}

local lastRequest: { [Player]: number } = {}
local teleporting: { [Player]: boolean } = {}
local arenaFocus: Part

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

-- Limite simples por jogador para pedidos do cliente.
local function allowed(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < Settings.RequestCooldown then
		return false
	end
	lastRequest[player] = now
	return true
end

-- Pontos de destino: spawns da ilha de nascimento ou a chegada do portal na plateia do palco.
local function islandSpawns(): Instance?
	local island = workspace:FindFirstChild("SpawnLobby")
	return island and island:FindFirstChild("Spawns")
end

local function portalArrivals(): Instance?
	local lobby = workspace:FindFirstChild("Lobby")
	return lobby and (lobby:FindFirstChild("PortalArrivals") or lobby:FindFirstChild("Spawns"))
end

local function portalTrigger(): BasePart?
	local island = workspace:FindFirstChild("SpawnLobby")
	local trigger = island and island:FindFirstChild("PortalTrigger")
	return if trigger and trigger:IsA("BasePart") then trigger else nil
end

-- As ilhas ficam longe uma da outra: carrega o destino no aparelho do jogador antes de mover o personagem
-- (StreamingEnabled), para ele não chegar antes do chão.
local function sendTo(player: Player, points: Instance?)
	local list = if points then points:GetChildren() else {}
	if #list == 0 or teleporting[player] or not rootOf(player) then
		return
	end
	local target = (list[math.random(1, #list)] :: BasePart).Position + Vector3.new(0, 4, 0)
	teleporting[player] = true
	task.spawn(function()
		pcall(player.RequestStreamAroundAsync, player, target, Settings.StreamTimeout)
		teleporting[player] = nil
		local character = player.Character
		local root = rootOf(player)
		-- enquanto carregava, pode ter entrado numa partida ou ido para o camarim: aí não mexe
		local busy = player:GetAttribute("HyperShowParticipant") == true or player:GetAttribute("HyperShowInGreenRoom") == true
		if character and root and not busy then
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(CFrame.new(target) * CFrame.Angles(0, math.pi, 0))
		end
	end)
end

local elapsed = 0
local function step(dt: number)
	elapsed += dt
	if elapsed < Settings.CheckInterval then
		return
	end
	elapsed = 0
	local trigger = portalTrigger()
	local island = Settings.SpawnIsland
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if not root or teleporting[player] or player:GetAttribute("HyperShowParticipant") == true or player:GetAttribute("HyperShowInGreenRoom") == true then
			continue -- em partida quem cuida é o minigame; no camarim, o TournamentService
		end
		local pos = root.Position
		-- caiu ou escapou dos limites: volta para a ilha de onde saiu (oeste = ilha de nascimento)
		local onStage = math.abs(pos.X) <= Settings.MaxX and pos.Z <= Settings.MaxZ and pos.Z >= Settings.MinZ
		local onIsland = pos.X >= island.MinX and pos.X <= island.MaxX and pos.Z >= island.MinZ and pos.Z <= island.MaxZ
		if pos.Y < Settings.FallY or not (onStage or onIsland) then
			sendTo(player, if pos.X < -Settings.MaxX then islandSpawns() or portalArrivals() else portalArrivals())
			continue
		end
		-- entrou no vórtice do portal: inscrito nas próximas rodadas e levado para a plateia do palco
		if trigger then
			local rel = trigger.CFrame:PointToObjectSpace(pos):Abs()
			local half = trigger.Size / 2
			if rel.X <= half.X and rel.Y <= half.Y and rel.Z <= half.Z then
				player:SetAttribute("HyperShowQueued", true)
				sendTo(player, portalArrivals())
			end
		end
	end
end

-- Inscritos prontos para a próxima rodada (o RoundService ainda confere se estão vivos e conectados).
function SocialService.queued(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("HyperShowQueued") == true then
			table.insert(list, player)
		end
	end
	return list
end

-- Personagem novo de quem está inscrito (ou ainda no campeonato) e fora de partida/camarim: plateia do palco.
local function onCharacterAdded(player: Player, character: Model)
	local queued = player:GetAttribute("HyperShowQueued") == true or player:GetAttribute("HyperShowInTournament") == true
	if not queued or player:GetAttribute("HyperShowParticipant") == true or player:GetAttribute("HyperShowInGreenRoom") == true then
		return
	end
	task.spawn(function()
		if character:WaitForChild("HumanoidRootPart", 5) and player.Character == character then
			sendTo(player, portalArrivals())
		end
	end)
end

function SocialService.init()
	-- ponto invisível no centro da arena: foco de streaming de quem está assistindo
	arenaFocus = Instance.new("Part")
	arenaFocus.Name = "ArenaFocus"
	arenaFocus.Anchored = true
	arenaFocus.CanCollide = false
	arenaFocus.CanQuery = false
	arenaFocus.CanTouch = false
	arenaFocus.Transparency = 1
	arenaFocus.Size = Vector3.one
	arenaFocus.Position = Config.NeonCollapse.ArenaOrigin
	arenaFocus.Parent = workspace

	Remotes.get("ShowEvent") -- criado já no início: a plateia (cliente) escuta desde que entra
	Remotes.get("LeaveQueue").OnServerEvent:Connect(function(player)
		if allowed(player) then
			player:SetAttribute("HyperShowQueued", nil)
			-- fora de partida, volta para a ilha de nascimento (para jogar de novo, é só entrar no portal)
			if player:GetAttribute("HyperShowParticipant") ~= true and player:GetAttribute("HyperShowInGreenRoom") ~= true then
				sendTo(player, islandSpawns())
			end
		end
	end)
	Remotes.get("SpectateFocus").OnServerEvent:Connect(function(player, on: unknown)
		if typeof(on) ~= "boolean" or not allowed(player) then
			return
		end
		-- participante vivo não troca o foco (precisa da arena em volta do próprio personagem)
		if on and player:GetAttribute("HyperShowParticipant") ~= true then
			player.ReplicationFocus = arenaFocus
		else
			player.ReplicationFocus = nil
		end
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		teleporting[player] = nil
	end)
	RunService.Heartbeat:Connect(step)
end

return SocialService
