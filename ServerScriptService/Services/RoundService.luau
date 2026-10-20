--!strict
-- Máquina de estados da rodada:
-- Campeonato: Intermission -> [Spin -> Teleport -> Intro -> Playing -> Qualification] x fases
-- -> grande final -> Results (pódio) -> Intermission

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local HyperService = require(script.Parent.HyperService)
local StageService = require(script.Parent.StageService)
local MoodService = require(script.Parent.MoodService)
local SocialService = require(script.Parent.SocialService)
local TournamentService = require(script.Parent.TournamentService)
local ShowSetService = require(script.Parent.ShowSetService)
local DataService = require(script.Parent.DataService)

type RoundContext = Types.RoundContext
type MinigameDef = Types.MinigameDef
type ModifierDef = Types.ModifierDef
type RoundState = Types.RoundState

type StateInfo = {
	minigame: string?,
	instruction: string?,
	category: string?,
	modifier: string?,
	modifierId: string?, -- a roleta do palco para na fatia deste modificador
	winners: { string }?,
	phase: string?, -- "FASE 2" / "GRANDE FINAL"
	roster: { Types.QualificationEntry }?, -- tela de classificação
	qualifiedCount: number?,
	eliminatedCount: number?,
	scores: { [string]: number }?, -- pontos da partida por UserId (resultado final)
	championId: number?, -- UserId do campeão (avatar no telão)
}

local RoundService = {}

local minigames: { MinigameDef } = {}
local modifiers: { ModifierDef } = {}
local roundStateRemote: RemoteEvent
local currentState: RoundState = "Intermission"
local currentEndsAt = 0
local currentInfo: StateInfo = {}
local activeContext: RoundContext? = nil
local stateRequests: { [Player]: number } = {}

local function readyPlayers(candidates: { Player }): { Player }
	local ready = {}
	for _, player in candidates do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if player.Parent == Players and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(ready, player)
			if #ready >= Config.Round.MaxPlayers then break end
		end
	end
	return ready
end

local function returnToLobby(players: { Player })
	for _, player in players do
		if player.Parent == Players then
			local ok, err = pcall(function() player:LoadCharacterAsync() end)
			if not ok and player.Parent == Players then
				warn("[Round] respawn falhou para " .. player.Name .. ": " .. tostring(err))
			end
		end
	end
end

local function loadModules(folderName: string): { any }
	local list = {}
	local folder = ServerScriptService:FindFirstChild(folderName)
	if not folder then
		return list
	end
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok then
				table.insert(list, result)
			else
				warn(string.format("[Round] falha ao carregar %s/%s: %s", folderName, child.Name, tostring(result)))
			end
		end
	end
	return list
end

local function setState(state: RoundState, duration: number, info: StateInfo?)
	currentState = state
	workspace:SetAttribute("HyperShowRoundState", state)
	currentEndsAt = if duration > 0 then workspace:GetServerTimeNow() + duration else 0
	currentInfo = info or {}
	roundStateRemote:FireAllClients(currentState, currentEndsAt, currentInfo)
	StageService.onState(state, duration, currentInfo)
	ShowSetService.onState(state)
	print(string.format("[Round] %s (%ds)", state, duration))
end

-- Espera até o fim do estado atual; para antes se shouldStop() for true.
local function waitState(shouldStop: (() -> boolean)?)
	while workspace:GetServerTimeNow() < currentEndsAt do
		if shouldStop and shouldStop() then
			return
		end
		task.wait(0.2)
	end
end

local function pickMinigame(playerCount: number): MinigameDef?
	local compatible = {}
	for _, def in minigames do
		if playerCount >= def.minPlayers then
			table.insert(compatible, def)
		end
	end
	if #compatible == 0 then
		return nil
	end
	return compatible[math.random(1, #compatible)]
end

local function pickModifier(): ModifierDef?
	if #modifiers == 0 or math.random() > Config.Modifiers.Chance then
		return nil
	end
	local total = 0
	for _, def in modifiers do
		total += def.weight
	end
	local roll = math.random() * total
	for _, def in modifiers do
		roll -= def.weight
		if roll <= 0 then
			return def
		end
	end
	return modifiers[#modifiers]
end

local function call(label: string, fn: () -> ()): boolean
	local ok, err = pcall(fn)
	if not ok then
		warn(string.format("[Round] erro em %s: %s", label, tostring(err)))
	end
	return ok
end

local function getPodiumStep(rank: number): BasePart?
	local podium = workspace:FindFirstChild("Podium")
	local step = podium and podium:FindFirstChild("Step" .. rank)
	return if step and step:IsA("BasePart") then step else nil
end

-- Estátuas dos vencedores no pódio: um boneco com a roupa do jogador, parado no degrau comemorando.
-- O jogador em si não é puxado; as estátuas somem no próximo intervalo.
local function clearStatues()
	local podium = workspace:FindFirstChild("Podium")
	local folder = podium and podium:FindFirstChild("Statues")
	if folder then
		folder:Destroy()
	end
end

local function buildStatue(description: HumanoidDescription, name: string, step: BasePart, folder: Folder)
	local ok, statue = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not folder.Parent then
		return
	end
	statue.Name = name
	local humanoid = statue:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = statue:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayName = name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	root.Anchored = true
	for _, d in statue:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	-- pés no topo do degrau, de frente para a plateia (a frente do degrau)
	statue:PivotTo(step.CFrame * CFrame.new(0, step.Size.Y / 2 + humanoid.HipHeight + root.Size.Y / 2, 0))
	statue.Parent = folder
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local animation = Instance.new("Animation")
	animation.AnimationId = Config.Podium.CheerAnimation
	local played, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if played and track then
		track.Looped = true
		track:Play()
	end
end

local function showPodium(winners: { Player }, descriptions: { [Player]: HumanoidDescription })
	clearStatues()
	local podium = workspace:FindFirstChild("Podium")
	if not podium then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Statues"
	folder.Parent = podium
	for rank = 1, math.min(3, #winners) do
		local step = getPodiumStep(rank)
		local winner = winners[rank]
		local description = descriptions[winner]
		if step and description then
			task.spawn(buildStatue, description, winner.DisplayName, step, folder)
		end
	end
end

local FELL_COMMENT_COOLDOWN = 3

local function trackAlive(ctx: RoundContext)
	local lastFellComment = 0
	local announcedLastOne = false
	local recentFalls: { number } = {}
	for _, player in ctx.players do
		local character = ctx.characters[player]
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if player.Parent == Players and player.Character == character and humanoid and humanoid.Health > 0 then
			local conn = humanoid.Died:Connect(function()
				ctx.alive[player] = nil
				player:SetAttribute("HyperShowParticipant", nil)
				if ctx.eliminatedAt[player] == nil and ctx.leftAt[player] == nil then
					ctx.eliminatedAt[player] = workspace:GetServerTimeNow()
				end
				local aliveCount = 0
				for _ in ctx.alive do
					aliveCount += 1
				end
				if #ctx.players >= 2 and aliveCount == 1 and not announcedLastOne then
					announcedLastOne = true
					HyperService.react("LastOne")
				elseif aliveCount > 0 then
					-- várias eliminações seguidas viram um comentário só ("vários caíram")
					local now = os.clock()
					table.insert(recentFalls, now)
					while recentFalls[1] and now - recentFalls[1] > Config.Hyper.Dialog.MultiFellWindow do
						table.remove(recentFalls, 1)
					end
					if #recentFalls >= Config.Hyper.Dialog.MultiFellCount then
						table.clear(recentFalls)
						HyperService.react("MultiFell")
					elseif now - lastFellComment > FELL_COMMENT_COOLDOWN then
						lastFellComment = now
						HyperService.react("Fell")
					end
				end
			end)
			table.insert(ctx.cleanupTasks, function()
				conn:Disconnect()
			end)
		else
			ctx.alive[player] = nil
			ctx.eliminatedAt[player] = workspace:GetServerTimeNow()
		end
	end
	local leaving = Players.PlayerRemoving:Connect(function(player)
		-- sair do servidor não conta como eliminação para o humor do apresentador
		if ctx.alive[player] and ctx.eliminatedAt[player] == nil then
			ctx.leftAt[player] = workspace:GetServerTimeNow()
		end
		ctx.alive[player] = nil
	end)
	table.insert(ctx.cleanupTasks, function()
		leaving:Disconnect()
	end)
end

-- Resumo da rodada para o humor do apresentador, a partir do que o RoundService já registra.
local function summarize(ctx: RoundContext, plannedDuration: number, endTime: number, winners: number, cancelled: boolean): Types.RoundSummary
	local started = ctx.startTime > 0
	local participants = 0
	local early = 0
	local survivors = 0
	local aliveLate = 0
	local lateMark = ctx.startTime + plannedDuration * Config.Mood.Weights.LongRoundRatio
	for _, player in ctx.players do
		local left = ctx.leftAt[player]
		if left and (not started or left <= ctx.startTime) then
			continue -- saiu antes de jogar: não participou
		end
		participants += 1
		local diedAt = ctx.eliminatedAt[player]
		if diedAt and diedAt <= ctx.startTime + Config.Mood.EarlyWindow then
			early += 1
		end
		local goneAt = diedAt or left
		if not goneAt then
			survivors += 1
		end
		if endTime >= lateMark and (not goneAt or goneAt > lateMark) then
			aliveLate += 1
		end
	end
	return {
		cancelled = cancelled or not started,
		participants = participants,
		plannedDuration = plannedDuration,
		actualDuration = if started then endTime - ctx.startTime else 0,
		earlyEliminated = early,
		survivorsAtEnd = survivors,
		aliveLate = aliveLate,
		winners = winners,
		objectives = ctx.objectives,
	}
end

local function cleanupRound(ctx: RoundContext)
	if ctx.cleaned then return end
	ctx.cleaned = true
	ctx.cancelled = true
	for _, player in ctx.players do
		if player.Parent == Players then player:SetAttribute("HyperShowParticipant", nil) end
	end
	-- Desliga observadores antes de destruir o mapa/restaurar modificadores.
	for _, task_ in ctx.cleanupTasks do call("cleanupTask", task_) end
	table.clear(ctx.cleanupTasks)
	call("minigame.cleanup", function()
		ctx.minigame.cleanup(ctx)
	end)
	local modifier = ctx.modifier
	if modifier then
		call("modifier.remove", function()
			modifier.remove(ctx)
		end)
	end
	for _, task_ in ctx.cleanupTasks do
		call("cleanupTask", task_)
	end
	table.clear(ctx.cleanupTasks)
	if ctx.map then
		ctx.map:Destroy()
		ctx.map = nil
	end
end

local usedMinigames: { [string]: boolean } = {}

-- Prefere minigames que ainda não apareceram neste campeonato; esgotados, libera repetição.
local function pickTournamentMinigame(playerCount: number): MinigameDef?
	local fresh = {}
	for _, def in minigames do
		if playerCount >= def.minPlayers and not usedMinigames[def.id] then
			table.insert(fresh, def)
		end
	end
	local def = if #fresh > 0 then fresh[math.random(1, #fresh)] else pickMinigame(playerCount)
	if def then
		usedMinigames[def.id] = true
	end
	return def
end

local function phaseLabel(phase: number, isFinal: boolean): string
	return if isFinal then Config.Strings.GrandFinal else string.format(Config.Strings.Phase, phase)
end

local function aliveCount(ctx: RoundContext): number
	local count = 0
	for _ in ctx.alive do
		count += 1
	end
	return count
end

type PhaseResult = {
	ok: boolean,
	ctx: RoundContext?,
	minigame: MinigameDef?,
}

-- Uma fase do campeonato: Spin -> Teleport -> Intro -> Playing. Termina quando sobram `slots` vivos
-- (ou 1 na final), no fim do tempo ou se o minigame encerrar. O mapa ainda existe ao retornar.
local function runPhase(players: { Player }, phase: number, isFinal: boolean, slots: number): PhaseResult
	local label = phaseLabel(phase, isFinal)
	local minigame = pickTournamentMinigame(#players)
	if not minigame then
		return { ok = false }
	end
	local modifier = pickModifier()

	setState("Spin", Config.Round.SpinTime, {
		minigame = minigame.displayName,
		modifier = modifier and modifier.displayName,
		modifierId = modifier and modifier.id,
		phase = label,
	})
	HyperService.react(if phase > 1 then "PhaseStart" else "Spin")
	if modifier then
		task.delay(Config.Round.SpinTime / 2, HyperService.react, "Modifier")
	end
	waitState()

	players = readyPlayers(players) -- revalida desconexões e mortes durante Spin
	if #players < math.max(Config.Round.MinPlayers, minigame.minPlayers) then
		return { ok = false }
	end

	local finished = false
	local alive: { [Player]: boolean } = {}
	for _, player in players do
		alive[player] = true
	end
	local ctx: RoundContext = {
		minigame = minigame,
		modifier = modifier,
		players = players,
		alive = alive,
		characters = {},
		cancelled = false,
		cleaned = false,
		map = nil,
		startTime = 0,
		cleanupTasks = {},
		finish = function()
			finished = true
		end,
		eliminatedAt = {},
		leftAt = {},
		objectives = 0,
		difficulty = MoodService.getDifficulty(),
	}

	activeContext = ctx
	setState("Teleport", 0, { minigame = minigame.displayName, phase = label })
	-- marcados como participantes ANTES do teleporte (o SocialService devolve ao lobby quem não está em
	-- partida e cai da ilha); quem não chegar à arena perde a marca logo depois do setup
	local candidates = players
	for _, player in candidates do
		player:SetAttribute("HyperShowParticipant", true)
		player:SetAttribute("HyperShowInGreenRoom", nil)
		player.ReplicationFocus = nil -- quem estava assistindo volta a carregar em volta do próprio personagem
	end
	local ok = call(minigame.id .. ".setup", function()
		minigame.setup(ctx)
	end)
	for _, player in candidates do
		if not table.find(ctx.players, player) and player.Parent == Players then
			player:SetAttribute("HyperShowParticipant", nil)
		end
	end
	if ok then
		-- minigame que não inscreve os personagens (ctx.characters) usa o personagem atual de cada um
		for _, player in ctx.players do
			if ctx.characters[player] == nil and player.Character then
				ctx.characters[player] = player.Character
			end
		end
		ok = #ctx.players >= math.max(Config.Round.MinPlayers, minigame.minPlayers)
		for _, player in ctx.players do player:SetAttribute("HyperShowParticipant", true) end
	end
	if ok and modifier then
		ok = call(modifier.id .. ".apply", function()
			modifier.apply(ctx)
		end)
	end

	local playTime = math.min(minigame.duration, Config.Round.MaxPlayTime)
	local endTime = 0
	if ok then
		trackAlive(ctx)
		setState("Intro", Config.Round.IntroTime, {
			minigame = minigame.displayName,
			instruction = minigame.instruction,
			category = minigame.category,
			modifier = modifier and modifier.displayName,
			phase = label,
		})
		HyperService.react(if isFinal then "GrandFinal" else "RoundStart")
		waitState()

		ctx.startTime = workspace:GetServerTimeNow()
		ok = call(minigame.id .. ".start", function()
			minigame.start(ctx)
		end)
		if ok then
			setState("Playing", playTime, {
				minigame = minigame.displayName,
				modifier = modifier and modifier.displayName,
				phase = label,
			})
			-- fase normal acaba quando só sobram os classificados; a final, quando sobra 1
			local target = if isFinal then 1 else slots
			local startedWith = #ctx.players
			workspace:SetAttribute("HyperShowStarted", startedWith) -- telões: "VIVOS x / y"
			waitState(function()
				local count = aliveCount(ctx)
				workspace:SetAttribute("HyperShowAlive", count)
				return finished or count == 0 or (startedWith > target and count <= target)
			end)
			endTime = workspace:GetServerTimeNow()
		end
	end

	-- o RoundSummary do humor usa os vivos no fim como "vencedores"
	local survivors = if ok then aliveCount(ctx) else 0
	if not ok then
		cleanupRound(ctx)
	end
	MoodService.evaluateRound(summarize(ctx, playTime, endTime, survivors, not ok))
	return { ok = ok, ctx = ctx, minigame = minigame }
end

-- Tira todo mundo do campeonato e devolve ao lobby (erro ou campeonato esvaziado).
local function abortTournament(players: { Player })
	TournamentService.reset()
	returnToLobby(players)
	activeContext = nil
end

-- Classificados vão para o camarim (vivos direto; quem morreu renasce e vai junto); eliminados, ao lobby.
local function moveAfterPhase(qualified: { Player }, eliminated: { Player })
	local pending = #qualified
	for i, player in qualified do
		task.spawn(function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				pcall(function() player:LoadCharacterAsync() end)
			end
			TournamentService.sendToGreenRoom(player, i)
			pending -= 1
		end)
	end
	local deadline = os.clock() + Config.Tournament.GreenRoomStreamTimeout + 3
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	task.spawn(returnToLobby, eliminated)
end

local function finalCeremony(ctx: RoundContext, minigame: MinigameDef)
	local ranking = TournamentService.rank(ctx)
	local scores = TournamentService.finish(ranking)
	local top: { Player } = {}
	local names = {}
	for i = 1, math.min(3, #ranking) do
		top[i] = ranking[i]
		table.insert(names, string.format(Config.Strings.PlaceFormat, i, ranking[i].DisplayName))
	end
	local scoreById: { [string]: number } = {}
	for player, value in scores do
		scoreById[tostring(player.UserId)] = value
		-- pontos da partida viram experiência salva; campeão ganha uma vitória
		DataService.addXp(player, value)
		DataService.addResult(player, player == top[1])
	end
	-- a roupa de cada finalista vem do personagem atual (sem chamada web); todos voltam ao lobby para ver o pódio
	local descriptions: { [Player]: HumanoidDescription } = {}
	for _, player in top do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			pcall(function() descriptions[player] = humanoid:GetAppliedDescription() end)
		end
	end
	cleanupRound(ctx)
	returnToLobby(ctx.players)
	activeContext = nil
	showPodium(top, descriptions)
	HyperService.react(if #top > 0 then "Champion" else "Nobody")
	setState("Results", Config.Round.ResultsTime, {
		minigame = minigame.displayName,
		winners = names,
		scores = scoreById,
		championId = top[1] and top[1].UserId,
	})
	waitState()
end

local function runRound()
	-- transição de humor pendente (cena) só entre campeonatos
	MoodService.runPendingTransition()
	HyperService.idle()
	clearStatues()
	-- ninguém inscrito: fica no intervalo mostrando como participar, sem contagem
	if #SocialService.queued() < Config.Round.MinPlayers then
		if currentState ~= "Intermission" or currentInfo.minigame ~= Config.Strings.WaitingParticipants then
			setState("Intermission", 0, { minigame = Config.Strings.WaitingParticipants })
		end
		task.wait(Config.Social.WaitRecheck)
		return
	end
	setState("Intermission", Config.Round.IntermissionTime)
	waitState()

	-- só quem se inscreveu entrando no portal; sem inscritos, espera (nada de rodada vazia)
	local players = readyPlayers(SocialService.queued())
	if #players < Config.Round.MinPlayers then
		setState("Intermission", 0, { minigame = Config.Strings.WaitingParticipants })
		task.wait(Config.Social.WaitRecheck)
		return
	end

	-- campeonato: fases seguidas sem voltar ao lobby; pódio só depois da grande final
	TournamentService.begin(players)
	table.clear(usedMinigames)
	local phase = 1
	while true do
		local contenders = TournamentService.contenders()
		if #contenders < Config.Round.MinPlayers then
			abortTournament(contenders)
			return
		end
		local isFinal = TournamentService.isFinal(phase, #contenders)
		local slots = if isFinal then 1 else TournamentService.qualifySlots(#contenders)
		local result = runPhase(contenders, phase, isFinal, slots)
		local ctx, minigame = result.ctx, result.minigame
		if not result.ok or not ctx or not minigame then
			-- erro no minigame ou ninguém para jogar: volta todo mundo para o lobby sem pódio
			abortTournament(TournamentService.contenders())
			return
		end
		if isFinal then
			finalCeremony(ctx, minigame)
			return
		end

		-- fim do tempo com mais vivos que vagas: todos os vivos se classificam
		local ranking = TournamentService.rank(ctx)
		ctx.cancelled = true -- o minigame para de vigiar a arena enquanto os classificados saem dela
		local qualified, eliminated, entries = TournamentService.qualify(ranking, math.max(slots, aliveCount(ctx)))
		moveAfterPhase(qualified, eliminated)
		cleanupRound(ctx)
		activeContext = nil
		if #qualified == 0 then
			abortTournament({})
			return
		end
		setState("Qualification", Config.Tournament.QualificationTime, {
			minigame = minigame.displayName,
			phase = phaseLabel(phase, false),
			roster = entries,
			qualifiedCount = #qualified,
			eliminatedCount = #eliminated,
		})
		HyperService.react(if #eliminated > 0 then "Qualified" else "Nobody")
		waitState()
		phase += 1
	end
end

function RoundService.init()
	roundStateRemote = Remotes.get("RoundState")
	Players.PlayerRemoving:Connect(function(player) stateRequests[player] = nil end)
	minigames = loadModules("Minigames")
	modifiers = loadModules("Modifiers")
	print(string.format("[Round] %d minigames, %d modificadores", #minigames, #modifiers))

	-- Quem entra no meio da rodada pede o estado atual quando a interface carrega
	-- e fica no lobby até a próxima rodada.
	Remotes.get("RoundStateRequest").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (stateRequests[player] or -math.huge) < 1 then return end
		stateRequests[player] = now
		roundStateRemote:FireClient(player, currentState, currentEndsAt, currentInfo)
	end)
end

function RoundService.start()
	while true do
		local ok, err = pcall(runRound)
		local remaining = activeContext
		if remaining then
			cleanupRound(remaining)
			returnToLobby(remaining.players)
			activeContext = nil
		end
		if not ok then
			returnToLobby(TournamentService.contenders())
			TournamentService.reset()
			warn("[Round] erro inesperado no loop: " .. tostring(err))
			task.wait(1)
		end
	end
end

return RoundService
