--!strict
-- O apresentador Hyper: fala por categoria (Config.Hyper.Categories) e troca o rosto (textura do modelo).
-- Fila de falas com prioridade (1 = cena ... 5 = comentário), intervalo mínimo e limite por janela
-- para falas comuns, sem repetir as últimas N de cada categoria. O rosto de descanso segue o humor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MoodService = require(script.Parent.MoodService)

local HyperConfig = Config.Hyper
local Dialog = HyperConfig.Dialog

type Category = { priority: number, faces: { string }, lines: { string } }
type Speech = { category: string, line: string, face: string, priority: number }

local HyperService = {}

local saysRemote: RemoteEvent
local recent: { [string]: { number } } = {}
local current: Speech? = nil
local currentUntil = 0
local queued: Speech? = nil -- uma fala importante esperando a atual terminar
local commonTimes: { number } = {}
local speechToken = 0
local idleFace = "Happy"
local cutsceneActive = false -- durante uma cena só falas de prioridade 1 vão ao ar

-- Cabeça, corpo e braços dividem a mesma textura (o rosto está desenhado nela): trocar em todos.
local function getParts(): { MeshPart }
	local hyper = workspace:FindFirstChild("Hyper")
	if not hyper then
		return {}
	end
	local meshes = {}
	for _, child in hyper:GetChildren() do
		if child:IsA("MeshPart") then
			table.insert(meshes, child)
		end
	end
	return meshes
end

local function pickLine(category: string, lines: { string }): string
	local history = recent[category] or {}
	recent[category] = history
	local options = {}
	for i = 1, #lines do
		if not table.find(history, i) then
			table.insert(options, i)
		end
	end
	local index = options[math.random(1, #options)]
	table.insert(history, index)
	while #history > math.min(HyperConfig.AvoidRepeatLast, #lines - 1) do
		table.remove(history, 1)
	end
	return lines[index]
end

local function speechTime(line: string): number
	return math.clamp(Dialog.BaseTime + #line * Dialog.PerChar, Dialog.MinTime, Dialog.MaxTime)
end

function HyperService.setFace(faceKey: string)
	local texture = (HyperConfig.FaceTextures :: { [string]: string })[faceKey]
	if texture then
		for _, mesh in getParts() do
			mesh.TextureID = texture
		end
	end
end

-- Volta para o rosto de descanso (o do humor atual), se nenhuma fala estiver no ar.
function HyperService.idle()
	if not current then
		HyperService.setFace(idleFace)
	end
end

local play: (speech: Speech) -> ()

local function finish(token: number)
	if token ~= speechToken then
		return
	end
	current = nil
	local nextSpeech = queued
	queued = nil
	if nextSpeech then
		play(nextSpeech)
	else
		HyperService.setFace(idleFace)
	end
end

play = function(speech: Speech)
	current = speech
	speechToken += 1
	local token = speechToken
	local duration = speechTime(speech.line)
	currentUntil = os.clock() + duration
	HyperService.setFace(speech.face)
	-- a fala aparece no cartão da interface (UIController); a categoria serve para a plateia reagir
	saysRemote:FireAllClients(speech.line, speech.face, duration, speech.priority, speech.category)
	print(string.format("[Hyper] %s (p%d, %s): %s", speech.category, speech.priority, speech.face, speech.line))
	task.delay(duration, finish, token)
end

-- Pede uma fala da categoria. Retorna true se ela foi ao ar ou entrou na fila.
-- forcedLine: fala fixa (cenas), no lugar de sortear uma da categoria.
function HyperService.say(categoryName: string, forcedLine: string?): boolean
	local category = (HyperConfig.Categories :: { [string]: Category })[categoryName]
	if not category then
		warn("[Hyper] categoria desconhecida: " .. categoryName)
		return false
	end
	local now = os.clock()
	local priority = category.priority
	if cutsceneActive and priority > 1 then
		return false
	end
	local busy = current ~= nil and now < currentUntil

	if priority >= 4 then
		-- comentário comum: nunca interrompe, respeita intervalo e limite por janela
		if busy or queued then
			return false
		end
		while commonTimes[1] and now - commonTimes[1] > Dialog.WindowSeconds do
			table.remove(commonTimes, 1)
		end
		local last = commonTimes[#commonTimes]
		if (last and now - last < Dialog.MinGapCommon) or #commonTimes >= Dialog.MaxPerWindow then
			return false
		end
		table.insert(commonTimes, now)
	end

	local speech: Speech = {
		category = categoryName,
		line = forcedLine or pickLine(categoryName, category.lines),
		face = category.faces[math.random(1, #category.faces)],
		priority = priority,
	}
	local active = current
	if busy and active then
		if priority == 1 and active.priority > 1 then
			play(speech) -- fala de cena corta qualquer fala que não seja de cena
		elseif not queued or priority < queued.priority then
			queued = speech -- importante: espera a atual terminar
		end
		return true
	end
	play(speech)
	return true
end

-- Trava de cena: ao começar, descarta a fala na fila; enquanto ativa, só prioridade 1 é aceita.
function HyperService.setCutscene(active: boolean)
	cutsceneActive = active
	if active and queued and queued.priority > 1 then
		queued = nil
	end
end

-- Compatível com as chamadas existentes do RoundService (momentos da rodada).
-- Durante o modo furioso, o início de rodada usa as falas do modo furioso.
function HyperService.react(moment: string)
	if moment == "RoundStart" and MoodService.isFurious() then
		moment = "FuriousMode"
	end
	HyperService.say(moment)
end

local function onMoodChanged(level: number, oldLevel: number, phase: string, oldPhase: string)
	idleFace = if phase == "Furious" or phase == "ToFurious" then HyperConfig.IdleFaceFurious else HyperConfig.IdleFaceByLevel[level]
	if phase ~= oldPhase then
		return -- as cenas de transformação cuidam das próprias falas
	end
	if level > oldLevel and level >= 3 and phase == "Normal" then
		HyperService.say(if level >= #HyperConfig.IdleFaceByLevel then "Anger" else "Impatience")
	elseif level < oldLevel then
		HyperService.say("Satisfaction")
	end
	HyperService.idle()
end

function HyperService.init()
	saysRemote = Remotes.get("HyperSays")
	local _, level = MoodService.getState()
	idleFace = HyperConfig.IdleFaceByLevel[level]
	MoodService.onChanged(onMoodChanged)
end

return HyperService
