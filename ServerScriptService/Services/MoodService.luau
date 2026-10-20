--!strict
-- Humor do apresentador (autoridade do servidor).
-- * stress: valor contínuo 0..100, muda só pela avaliação de cada rodada (uma vez por rodada).
-- * level: faixa do medidor (1 = muito feliz ... 5 = furioso), derivada do stress.
-- * phase: estado da cena, separado do stress: Normal -> ToFurious -> Furious -> ToNormal -> Normal.
--   As transições ficam pendentes e só rodam em momento seguro (entre rodadas), uma de cada vez.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Mood = Config.Mood
local W = Mood.Weights

export type Phase = "Normal" | "ToFurious" | "Furious" | "ToNormal"

local MoodService = {}
local stateRequests: { [Player]: number } = {}

local stress = Mood.StartStress
local phase: Phase = "Normal"
local pending: Phase? = nil -- "ToFurious" ou "ToNormal" aguardando um momento seguro
local goodStreak = 0
local moodRemote: RemoteEvent
local transitionHandlers: { [string]: () -> () } = {}
local listeners: { (level: number, oldLevel: number, phase: Phase, oldPhase: Phase) -> () } = {}

local function levelOf(value: number): number
	local level = 1
	for i, l in Mood.Levels do
		if value >= l.from then
			level = i
		end
	end
	return level
end

local function notify(oldLevel: number, oldPhase: Phase)
	local level = levelOf(stress)
	if level == oldLevel and phase == oldPhase then
		return
	end
	for _, fn in listeners do
		task.spawn(fn, level, oldLevel, phase, oldPhase)
	end
end

local function broadcast(target: Player?)
	local state = { stress = stress, level = levelOf(stress), phase = phase, pending = pending }
	if target then
		moodRemote:FireClient(target, state)
	else
		moodRemote:FireAllClients(state)
	end
end

-- Variação do estresse para uma rodada (positivo = mais irritado). Pura, sem efeitos colaterais.
function MoodService.scoreRound(s: Types.RoundSummary): number
	if s.cancelled or s.participants <= 0 or s.plannedDuration <= 0 then
		return 0 -- rodada inválida: política neutra
	end
	local ratio = math.clamp(s.actualDuration / s.plannedDuration, 0, 1)
	local delta = 0

	-- piora: muita gente eliminada cedo, rodada que acabou cedo demais
	delta += W.EarlyEliminations * (s.earlyEliminated / s.participants)
	if ratio < W.ShortRoundRatio and s.survivorsAtEnd <= 1 then
		delta += W.ShortRound * (1 - ratio / W.ShortRoundRatio)
	end

	-- melhora: durou bastante, disputa até o fim, terminou normalmente, objetivos
	if ratio >= W.LongRoundRatio then
		delta -= W.LongRound * ratio
	end
	if s.participants >= 2 and s.aliveLate >= 2 then
		delta -= W.CloseFight
	end
	if s.winners > 0 and ratio >= W.LongRoundRatio then
		delta -= W.Completed
	end
	delta -= W.PerObjective * math.min(s.objectives, W.MaxObjectives)

	-- poucos jogadores pesam menos (um jogador sozinho não decide o humor do servidor)
	delta *= math.min(1, s.participants / Mood.FullWeightPlayers)
	return math.clamp(delta, -Mood.MaxDeltaDown, Mood.MaxDeltaUp)
end

-- Chamado pelo RoundService uma vez por rodada, depois da limpeza.
function MoodService.evaluateRound(s: Types.RoundSummary): number
	local delta = MoodService.scoreRound(s)
	local oldLevel = levelOf(stress)
	stress = math.clamp(stress + delta, 0, Mood.MaxStress)
	goodStreak = if delta < 0 then goodStreak + 1 elseif delta > 0 then 0 else goodStreak

	if phase == "Normal" and stress >= Mood.FuriousAt then
		pending = "ToFurious"
	elseif phase == "Furious" and stress <= Mood.RecoverAt and goodStreak >= Mood.RecoverGoodRounds then
		pending = "ToNormal"
	end
	print(string.format("[Mood] rodada %+.1f -> estresse %.1f (nível %d, fase %s%s, boas seguidas %d)",
		delta, stress, levelOf(stress), phase, if pending then ", pendente " .. pending else "", goodStreak))
	broadcast(nil)
	notify(oldLevel, phase)
	return delta
end

-- Quem toca a cena (StageService, etapa 5) registra aqui; sem handler a troca é imediata.
function MoodService.onTransition(name: "ToFurious" | "ToNormal", handler: () -> ())
	transitionHandlers[name] = handler
end

-- Chamado pelo RoundService num momento seguro (início do intervalo). Roda no máximo uma transição.
function MoodService.runPendingTransition()
	local next = pending
	if not next then
		return
	end
	pending = nil
	local oldPhase = phase
	phase = next
	broadcast(nil)
	notify(levelOf(stress), oldPhase)
	local handler = transitionHandlers[next]
	if handler then
		local ok, err = pcall(handler)
		if not ok then
			warn("[Mood] erro na cena " .. next .. ": " .. tostring(err))
		end
	end
	-- a fase sempre termina num estado estável, mesmo se a cena falhar
	phase = if next == "ToFurious" then "Furious" else "Normal"
	if phase == "Normal" then
		goodStreak = 0
	end
	print("[Mood] fase agora: " .. phase)
	broadcast(nil)
	notify(levelOf(stress), next)
end

-- Avisos de mudança de nível do medidor ou de fase (ex.: o Hyper comenta e troca o rosto).
function MoodService.onChanged(fn: (level: number, oldLevel: number, phase: Phase, oldPhase: Phase) -> ())
	table.insert(listeners, fn)
end

function MoodService.getState(): (number, number, Phase)
	return stress, levelOf(stress), phase
end

function MoodService.isFurious(): boolean
	return phase == "Furious" or phase == "ToFurious"
end

-- Intensidade da dificuldade: 0 fora do modo furioso; 1..3 dentro dele, conforme o estresse atual.
function MoodService.getDifficulty(): number
	if not MoodService.isFurious() then
		return 0
	end
	local intensity = 1
	for i, from in Config.Mood.Furious.IntensityFrom do
		if stress >= from then
			intensity = i
		end
	end
	return intensity
end

function MoodService.init()
	moodRemote = Remotes.get("MoodState")
	game:GetService("Players").PlayerRemoving:Connect(function(player) stateRequests[player] = nil end)
	-- quem entra pede o estado atual quando a interface carrega
	Remotes.get("MoodStateRequest").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (stateRequests[player] or -math.huge) < 1 then return end
		stateRequests[player] = now
		broadcast(player)
	end)

	-- Atalho de teste só no Studio (não existe no jogo publicado):
	-- ServerStorage.MoodDebug:Invoke("evaluate", resumo) / ("run") / ("state")
	if RunService:IsStudio() then
		local debug = Instance.new("BindableFunction")
		debug.Name = "MoodDebug"
		debug.OnInvoke = function(action: string, arg: any)
			if action == "evaluate" then
				MoodService.evaluateRound(arg)
			elseif action == "run" then
				MoodService.runPendingTransition()
			end
			return { stress = stress, level = levelOf(stress), phase = phase, pending = pending, difficulty = MoodService.getDifficulty() }
		end
		debug.Parent = ServerStorage
	end
end

return MoodService
