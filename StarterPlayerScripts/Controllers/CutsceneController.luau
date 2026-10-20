--!strict
-- Cliente: cenas de humor do Hyper (lobby furioso e volta ao normal), sincronizadas pelo horário do servidor.
-- Só efeitos locais: câmera, flash, tremor, cacos e o giro do cenário do palco. O que é estado do jogo
-- (cores, vidro, rosto, falas) vem do servidor. A câmera e as peças giradas sempre voltam ao normal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HyperController = require(script.Parent.HyperController)

local Cutscene = Config.Mood.Cutscene

-- Peças do lobby que NÃO giram: o chão onde os jogadores ficam e o spawn.
local FIXED = { Floor = true, Underside = true, FloorTrim = true, FloorLine = true, LobbySpawn = true, Rail = true, RailLight = true }
local STAGE_CENTER = Vector3.new(0, 0, -40)
-- Só o centro do palco gira (plataforma, arco, medidor, logo, colunas do meio): o palco é largo e as pontas
-- passariam por cima da plateia.
local SPIN_RADIUS = 24

local CutsceneController = {}

local running = false

local function waitUntil(start: number, seconds: number)
	local remaining = start + seconds - workspace:GetServerTimeNow()
	if remaining > 0 then
		task.wait(remaining)
	end
end

local function find(path: { string }): Instance?
	local node: Instance? = workspace
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function partPosition(path: { string }, fallback: Vector3): Vector3
	local inst = find(path)
	if inst and inst:IsA("BasePart") then
		return inst.Position
	elseif inst and inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return fallback
end

local function flash(color: Color3)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CutsceneFlash"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0.15
	frame.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local fade = TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	fade.Completed:Once(function()
		gui:Destroy()
	end)
	fade:Play()
end

-- cacos de vidro (raiva) ou brilho dourado (recuperação) saindo do medidor
local function burst(at: Vector3, broken: boolean)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(14, 6, 0.2)
	holder.Position = at
	holder.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = if broken then ColorSequence.new(Color3.fromRGB(220, 240, 255), Color3.fromRGB(255, 120, 120)) else ColorSequence.new(Color3.fromRGB(255, 220, 120))
	emitter.LightEmission = if broken then 0.4 else 1
	emitter.Size = if broken then NumberSequence.new(0.5, 0.2) else NumberSequence.new(0.6, 0)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(14, 26)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-300, 300)
	emitter.Acceleration = if broken then Vector3.new(0, -40, 0) else Vector3.new(0, 4, 0)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(if broken then 45 else 35)
	task.delay(2, function()
		holder:Destroy()
	end)
end

local function playSfx(key: string, volume: number)
	local id = Config.Sounds[key]
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- abaixa a música durante a cena e devolve o volume no fim
local function duckMusic(): () -> ()
	local saved: { [Sound]: number } = {}
	for _, name in { "MusicLobby", "MusicGame" } do
		local music = SoundService:FindFirstChild(name)
		if music and music:IsA("Sound") then
			saved[music] = music.Volume
			TweenService:Create(music, TweenInfo.new(0.4), { Volume = music.Volume * 0.15 }):Play()
		end
	end
	return function()
		for music, volume in saved do
			TweenService:Create(music, TweenInfo.new(0.8), { Volume = volume }):Play()
		end
	end
end

-- gira o cenário do palco (só localmente) 360° em volta do centro do palco e volta ao lugar exato
local function spinStage(duration: number)
	local parts: { [BasePart]: CFrame } = {}
	-- o Hyper é animado pelo HyperController: ele recebe a rotação do palco em vez de ter as peças movidas aqui
	local lobby = find({ "Lobby" })
	if lobby then
		for _, d in lobby:GetDescendants() do
			if not d:IsA("BasePart") then
				continue
			end
			local flat = Vector3.new(d.Position.X - STAGE_CENTER.X, 0, d.Position.Z - STAGE_CENTER.Z)
			if not FIXED[d.Name] and flat.Magnitude <= SPIN_RADIUS and d.Parent and d.Parent.Name ~= "FuriousFx" then
				parts[d] = d.CFrame
			end
		end
	end
	local pivot = CFrame.new(STAGE_CENTER)
	local value = Instance.new("NumberValue")
	local conn = RunService.RenderStepped:Connect(function()
		local rotation = pivot * CFrame.Angles(0, math.rad(value.Value), 0) * pivot:Inverse()
		for part, original in parts do
			part.CFrame = rotation * original
		end
		HyperController.setStageRotation(rotation)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = 360 })
	tween:Play()
	task.wait(duration)
	conn:Disconnect()
	HyperController.setStageRotation(CFrame.identity)
	for part, original in parts do
		if part.Parent then
			part.CFrame = original
		end
	end
	value:Destroy()
end

local function play(kind: string, start: number)
	local timeline = Cutscene[kind]
	if not timeline or running then
		return
	end
	running = true
	local camera = workspace.CurrentCamera
	local savedType, savedFov = camera.CameraType, camera.FieldOfView
	local restoreMusic = duckMusic()
	local restored = false
	local function restore()
		if restored then
			return
		end
		restored = true
		camera.CameraType = savedType
		camera.FieldOfView = savedFov
		restoreMusic()
		running = false
	end
	-- reserva: mesmo se algo falhar, a câmera volta
	task.delay(timeline.Duration + 2, restore)

	local ok, err = pcall(function()
		local dial = partPosition({ "Lobby", "MoodMeter", "Dial" }, Vector3.new(0, 72, -60))
		local head = partPosition({ "Hyper" }, Vector3.new(0, 21, -37)) + Vector3.new(0, 9, 0)
		local wide = CFrame.lookAt(Vector3.new(0, 32, 46), Vector3.new(0, 34, -50))
		local function shot(cf: CFrame, time: number)
			TweenService:Create(camera, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = cf }):Play()
		end

		waitUntil(start, 0)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = Cutscene.CameraFov
		if kind == "ToFurious" then
			shot(CFrame.lookAt(dial + Vector3.new(0, -3, 34), dial), 1.2)
			task.wait(1.3)
			shot(CFrame.lookAt(dial + Vector3.new(0, -1.5, 20), dial), timeline.GlassAt - 1.4)
		else
			shot(CFrame.lookAt(head + Vector3.new(6, -1, 24), head), 1.2)
			waitUntil(start, timeline.GlassAt - 1.2)
			shot(CFrame.lookAt(dial + Vector3.new(0, -2, 24), dial), 1.1)
		end

		waitUntil(start, timeline.GlassAt)
		local broken = kind == "ToFurious"
		flash(if broken then Color3.new(1, 1, 1) else Color3.fromRGB(255, 230, 150))
		burst(dial + Vector3.new(0, 0, 1), broken)
		playSfx(if broken then "HexCrack" else "Victory", if broken then 1 else 0.6)
		if broken then
			-- tremor da câmera no impacto
			local base = camera.CFrame
			for i = 1, 8 do
				camera.CFrame = base * CFrame.new(math.random(-10, 10) / 25, math.random(-10, 10) / 25, 0)
				task.wait(0.03)
			end
			camera.CFrame = base
		end

		waitUntil(start, timeline.FaceAt)
		shot(CFrame.lookAt(head + Vector3.new(-4, -1, 22), head), 0.8)

		waitUntil(start, timeline.SpinAt - 0.8)
		shot(wide, 0.8)
		waitUntil(start, timeline.SpinAt)
		spinStage(timeline.SpinTime)

		waitUntil(start, timeline.Duration)
	end)
	if not ok then
		warn("[Cutscene] " .. tostring(err))
	end
	restore()
end

-- Cena da roleta (estado Spin) para quem está no campeonato: como numa transmissão de TV, a câmera vai do
-- camarim para o palco, mostra o Hyper, a roleta girando e o anúncio do próximo minigame, e volta antes do
-- teleporte. Quem está só no lobby continua vendo a roleta normalmente (nada muda para ele).
local function overlay(): (ScreenGui, TextLabel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinBroadcast"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ResetOnSpawn = false
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1)
		bar.Size = UDim2.fromScale(1, 0)
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Parent = gui
		TweenService:Create(bar, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, 0.1) }):Play()
	end
	local live = Instance.new("TextLabel")
	live.Position = UDim2.fromScale(0.03, 0.02)
	live.Size = UDim2.fromScale(0.18, 0.06)
	live.BackgroundTransparency = 1
	live.TextScaled = true
	live.Font = Enum.Font.GothamBlack
	live.TextColor3 = Color3.fromHex("FF2E3D")
	live.TextXAlignment = Enum.TextXAlignment.Left
	live.Text = Config.Strings.LiveBadge
	live.Parent = gui
	local reveal = Instance.new("TextLabel")
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	reveal.Position = UDim2.fromScale(0.5, 0.95)
	reveal.Size = UDim2.fromScale(0.7, 0.07)
	reveal.BackgroundTransparency = 1
	reveal.TextScaled = true
	reveal.Font = Enum.Font.LuckiestGuy
	reveal.TextColor3 = Color3.fromHex("FFC83D")
	reveal.TextStrokeTransparency = 0.2
	reveal.Text = ""
	reveal.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui, reveal
end

local function playSpin(endsAt: number, minigame: string?)
	if running then
		return
	end
	local duration = endsAt - workspace:GetServerTimeNow()
	if duration < 2 then
		return
	end
	running = true
	local camera = workspace.CurrentCamera
	local savedType, savedFov = camera.CameraType, camera.FieldOfView
	local gui, reveal = overlay()
	local restored = false
	local function restore()
		if restored then
			return
		end
		restored = true
		camera.CameraType = savedType
		camera.FieldOfView = savedFov
		gui:Destroy()
		running = false
	end
	task.delay(duration + 1, restore)
	local ok, err = pcall(function()
		local head = partPosition({ "Hyper" }, Vector3.new(0, 21, -37)) + Vector3.new(0, 9, 0)
		local wheel = partPosition({ "Lobby", "Wheel", "Disc" }, Vector3.new(27, 13, -36))
		local function shot(cf: CFrame, time: number)
			TweenService:Create(camera, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = cf }):Play()
		end
		local start = workspace:GetServerTimeNow()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 55
		-- 1) o Hyper chamando a roleta
		camera.CFrame = CFrame.lookAt(head + Vector3.new(-10, 2, 34), head)
		shot(CFrame.lookAt(head + Vector3.new(-5, 0, 22), head), duration * 0.25)
		waitUntil(start, duration * 0.25)
		-- 2) a roleta girando, de perto
		shot(CFrame.lookAt(wheel + Vector3.new(-6, 2, 16), wheel), duration * 0.15)
		waitUntil(start, duration * 0.72)
		-- 3) plano aberto do palco com o anúncio do próximo minigame
		shot(CFrame.lookAt(Vector3.new(0, 26, 40), Vector3.new(0, 18, -45)), duration * 0.18)
		if minigame then
			reveal.Text = string.format(Config.Strings.NextUp, minigame)
			local scale = Instance.new("UIScale")
			scale.Scale = 0.2
			scale.Parent = reveal
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		waitUntil(start, duration - 0.15)
	end)
	if not ok then
		warn("[Cutscene] roleta: " .. tostring(err))
	end
	restore()
end

-- Música mais lenta e pesada enquanto o Hyper estiver furioso.
local function onMood(state: { phase: string })
	local furious = state.phase == "Furious" or state.phase == "ToFurious"
	for _, name in { "MusicLobby", "MusicGame" } do
		local music = SoundService:FindFirstChild(name)
		if music and music:IsA("Sound") then
			music.PlaybackSpeed = if furious then Config.Mood.Furious.MusicSpeed else 1
		end
	end
end

-- O LobbyFxController pausa os movimentos do cenário enquanto o palco gira numa cena.
function CutsceneController.isRunning(): boolean
	return running
end

function CutsceneController.init()
	Remotes.get("MoodCutscene").OnClientEvent:Connect(function(kind: string, start: number)
		task.spawn(play, kind, start)
	end)
	Remotes.get("MoodState").OnClientEvent:Connect(onMood)
	Remotes.get("RoundState").OnClientEvent:Connect(function(state: string, endsAt: number, info: { minigame: string? }?)
		if state == "Spin" and Players.LocalPlayer:GetAttribute("HyperShowInTournament") == true then
			task.spawn(playSpin, endsAt, info and info.minigame)
		end
	end)
end

return CutsceneController
