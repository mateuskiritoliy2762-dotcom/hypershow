--!strict
-- Cliente: deixa o lobby vivo. Tudo é só visual e local (nada vai para o servidor):
-- planetas girando e flutuando, anel do planeta girando, asteroides orbitando devagar, meteoros cruzando o céu,
-- lâmpadas da roleta em sequência, anéis do portal pulsando, linhas do chão acendendo em onda, brilhos piscando,
-- holofotes balançando, poeira cósmica, faíscas no logo, confete na roleta e no pódio e brasas no modo furioso.
-- Na ilha de nascimento (SpawnLobby), o vórtice do portal gira.
-- As cores das peças continuam com o servidor (tema furioso); aqui só mexemos em transparência e posição.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CutsceneController = require(script.Parent.CutsceneController)

local Fx = Config.LobbyFx

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local STAGE_CENTER = Vector3.new(0, 0, -36)

local LobbyFxController = {}

type Blink = { part: BasePart, base: number, phase: number }
type Orbit = { part: BasePart, cf: CFrame, phase: number, base: Vector3? }

local bulbs: { Blink } = {}
local portalRings: { Blink } = {}
local floorLines: { Blink } = {}
local sparkles: { Blink } = {}
local beams: { Orbit } = {}
local planets: { Orbit } = {}
local planetRings: { Orbit } = {}
local asteroids: { Orbit } = {}
local ringCenter = Vector3.zero
local ringAxis = Vector3.yAxis
-- vórtice do portal da ilha de nascimento; com StreamingEnabled ele pode sair e voltar, então é buscado de novo
local vortex: BasePart? = nil
local vortexCF = CFrame.identity
local nextVortexLookup = 0

local furious = false
local embers: ParticleEmitter? = nil
local fxFolder: Folder

local function blink(list: { Blink }, part: BasePart, phase: number)
	table.insert(list, { part = part, base = part.Transparency, phase = phase })
end

local function fxPart(name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = fxFolder
	return p
end

local function emitter(parent: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- Confete colorido: um emissor por cor (a cor do ParticleEmitter é por tempo de vida, não por partícula).
local confetti: { ParticleEmitter } = {}
local confettiHolder: Part

local function burstConfetti(at: Vector3)
	if not confettiHolder then return end
	confettiHolder.Position = at
	for _, e in confetti do
		e:Emit(Fx.ConfettiPerColor)
	end
end

local function meteor()
	local start = Vector3.new(math.random(-220, 220), math.random(110, 190), math.random(-320, -180))
	local direction = Vector3.new(if math.random() < 0.5 then -1 else 1, -0.45, math.random(-2, 2) / 10).Unit
	local head = fxPart("Meteor", Vector3.one * 2.2, CFrame.new(start))
	head.Shape = Enum.PartType.Ball
	head.Material = Enum.Material.Neon
	head.Transparency = 0
	head.Color = if furious then Color3.fromRGB(255, 140, 60) else Color3.fromRGB(255, 220, 255)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.9, 0)
	a0.Parent = head
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.9, 0)
	a1.Parent = head
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.6
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = if furious
		then ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 40, 20))
		else ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 80, 200))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = head
	local born = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - born
		if t > Fx.MeteorLife then
			conn:Disconnect()
			head:Destroy()
			return
		end
		head.CFrame = CFrame.new(start + direction * Fx.MeteorSpeed * t)
	end)
end

local function collect()
	local lobby = workspace:WaitForChild("Lobby", 30)
	local space = workspace:WaitForChild("Space", 30)
	if not lobby or not space then
		return false
	end
	local wheel = lobby:FindFirstChild("Wheel")
	local disc = wheel and wheel:FindFirstChild("Disc")
	local wheelCenter = if disc and disc:IsA("BasePart") then disc.Position else Vector3.zero
	local portal = lobby:FindFirstChild("PortalGlow")
	local portalCenter = if portal and portal:IsA("BasePart") then portal.Position else Vector3.zero

	for _, d in lobby:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		if d.Name == "Bulb" and wheel and d:IsDescendantOf(wheel) then
			local offset = d.Position - wheelCenter
			blink(bulbs, d, math.atan2(offset.Y, offset.X))
		elseif d.Name == "PortalRing" then
			blink(portalRings, d, (d.Position - portalCenter).Magnitude)
		elseif d.Name == "FloorLine" then
			local flat = Vector3.new(d.Position.X - STAGE_CENTER.X, 0, d.Position.Z - STAGE_CENTER.Z)
			blink(floorLines, d, flat.Magnitude)
		elseif d.Name == "Sparkle" then
			blink(sparkles, d, math.random() * 10)
		elseif d.Name == "LightBeam" then
			-- o facho é um cilindro com o eixo X do pé até a ponta: o pé fica em -X
			local foot = (d.CFrame * CFrame.new(-d.Size.X / 2, 0, 0)).Position
			table.insert(beams, { part = d, cf = d.CFrame, phase = if d.Position.X < 0 then 0 else math.pi, base = foot })
		end
	end

	local firstPlanet: BasePart? = nil
	for _, d in space:GetChildren() do
		if not d:IsA("BasePart") then
			continue
		end
		if d.Name == "Planet" then
			firstPlanet = firstPlanet or d
			table.insert(planets, { part = d, cf = d.CFrame, phase = math.random() * 6 })
		elseif d.Name == "PlanetRing" then
			table.insert(planetRings, { part = d, cf = d.CFrame, phase = 0 })
		elseif d.Name == "Asteroid" then
			table.insert(asteroids, { part = d, cf = d.CFrame, phase = math.random() * 6 })
		end
	end
	-- o anel gira em volta do planeta com anel (o mais próximo do centro dos segmentos)
	if #planetRings > 0 then
		local sum = Vector3.zero
		for _, r in planetRings do
			sum += r.cf.Position
		end
		ringCenter = sum / #planetRings
		local a, b = planetRings[1].cf.Position - ringCenter, planetRings[math.floor(#planetRings / 4) + 1].cf.Position - ringCenter
		ringAxis = a:Cross(b).Unit
	end
	return true
end

local function buildParticles()
	-- poeira cósmica brilhante flutuando sobre o lobby
	local dust = fxPart("Dust", Vector3.new(110, 40, 95), CFrame.new(0, 22, -8))
	emitter(dust, {
		Name = "Dust",
		Texture = SPARKLE_TEXTURE,
		Rate = Fx.DustRate,
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(0.3, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 140, 230), Color3.fromRGB(120, 220, 255)),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
	-- faíscas em volta do letreiro
	local lobby = workspace:FindFirstChild("Lobby")
	local board = lobby and lobby:FindFirstChild("Logo")
	if board and board:IsA("BasePart") then
		local around = fxPart("LogoSparks", board.Size + Vector3.new(8, 8, 2), board.CFrame * CFrame.new(0, 0, -2))
		emitter(around, {
			Name = "LogoSparks",
			Texture = SPARKLE_TEXTURE,
			Rate = Fx.LogoSparkRate,
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(0, 0.5),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 2), NumberSequenceKeypoint.new(1, 0) }),
			Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 120, 220)),
			Rotation = NumberRange.new(0, 360),
		})
	end
	-- brasas subindo do chão no modo furioso
	local floor = fxPart("Embers", Vector3.new(110, 1, 90), CFrame.new(0, 2, -8))
	embers = emitter(floor, {
		Name = "Embers",
		Rate = Fx.EmberRate,
		Enabled = furious,
		Lifetime = NumberRange.new(2.5, 4.5),
		Speed = NumberRange.new(3, 7),
		SpreadAngle = Vector2.new(15, 15),
		Acceleration = Vector3.new(0, 1.5, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 40, 20)),
		EmissionDirection = Enum.NormalId.Top,
	})
	-- confete (rosa, dourado, ciano, roxo)
	confettiHolder = fxPart("Confetti", Vector3.new(6, 1, 6), CFrame.new(0, 20, -36))
	for _, color in { Color3.fromRGB(255, 61, 139), Color3.fromRGB(255, 200, 61), Color3.fromRGB(31, 182, 255), Color3.fromRGB(180, 90, 255) } do
		table.insert(confetti, emitter(confettiHolder, {
			Name = "Confetti",
			Rate = 0,
			LightEmission = 0.4,
			Lifetime = NumberRange.new(2.5, 4),
			Speed = NumberRange.new(18, 30),
			SpreadAngle = Vector2.new(55, 55),
			Acceleration = Vector3.new(0, -16, 0),
			Drag = 1.2,
			Size = NumberSequence.new(0.5),
			Color = ColorSequence.new(color),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-300, 300),
			EmissionDirection = Enum.NormalId.Top,
		}))
	end
end

local lastBlink = 0
local nextMeteor = 0

-- O disco do vórtice é um plano com a normal no Z local: gira em volta dele.
local function spinVortex(camera: Camera, now: number)
	if not vortex or not vortex.Parent then
		vortex = nil
		if now < nextVortexLookup then
			return
		end
		nextVortexLookup = now + 1
		local island = workspace:FindFirstChild("SpawnLobby")
		local found = island and island:FindFirstChild("Vortex", true)
		if not found or not found:IsA("BasePart") then
			return
		end
		vortex, vortexCF = found, found.CFrame
	end
	local part = vortex :: BasePart
	if (camera.CFrame.Position - vortexCF.Position).Magnitude < Fx.VortexDistance then
		part.CFrame = vortexCF * CFrame.Angles(0, 0, now * Fx.VortexSpeed % (2 * math.pi))
	end
end

local function update()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local now = os.clock()
	spinVortex(camera, now)
	if (camera.CFrame.Position - STAGE_CENTER).Magnitude > 240 then return end

	-- movimentos (posição): parados enquanto a cena de humor gira o palco
	local t = now * Fx.SpaceSpeed
	for _, p in planets do
		p.part.CFrame = p.cf * CFrame.new(0, math.sin(now * 0.4 + p.phase) * Fx.PlanetBob, 0) * CFrame.Angles(0, t * 0.6, 0)
	end
	local ringSpin = CFrame.fromAxisAngle(ringAxis, t * 0.8)
	for _, r in planetRings do
		r.part.CFrame = CFrame.new(ringCenter) * ringSpin * CFrame.new(-ringCenter) * r.cf
	end
	local orbit = CFrame.new(STAGE_CENTER) * CFrame.Angles(0, t * 0.05, 0) * CFrame.new(-STAGE_CENTER)
	for _, a in asteroids do
		a.part.CFrame = orbit * a.cf * CFrame.new(0, math.sin(now * 0.5 + a.phase) * 1.5, 0) * CFrame.Angles(t * 0.3, t * 0.2, 0)
	end
	if not CutsceneController.isRunning() then
		for _, b in beams do
			-- balança em volta do pé do facho (no holofote)
			local sway = math.sin(now * Fx.BeamSpeed + b.phase) * math.rad(Fx.BeamDegrees)
			local base = b.base or b.cf.Position
			b.part.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, sway) * CFrame.new(-base) * b.cf
		end
	end

	-- piscar (transparência) em ~20 quadros por segundo, que é o bastante e pesa menos no celular
	if now - lastBlink < 0.05 then
		return
	end
	lastBlink = now
	local chase = now * Fx.BulbChaseSpeed
	for _, b in bulbs do
		b.part.Transparency = if math.sin(chase + b.phase * 4) > 0 then 0 else 0.65
	end
	for _, r in portalRings do
		r.part.Transparency = math.clamp(r.base + 0.45 * (0.5 + 0.5 * math.sin(now * 3 - r.phase * 0.5)), 0, 0.9)
	end
	for _, l in floorLines do
		l.part.Transparency = math.clamp(l.base + 0.6 * (0.5 + 0.5 * math.sin(now * 4 - l.phase * 0.15)), 0, 0.95)
	end
	for _, s in sparkles do
		s.part.Transparency = math.clamp(0.5 + 0.5 * math.sin(now * 2.5 + s.phase), 0, 0.85)
	end

	if now >= nextMeteor and Players.LocalPlayer:GetAttribute("HyperShowFx") ~= false then
		nextMeteor = now + math.random(Fx.MeteorEveryMin * 10, Fx.MeteorEveryMax * 10) / 10
		meteor()
	end
end

local function onRoundState(state: string, _endsAt: number, info: { winners: { string }? }?)
	local lobby = workspace:FindFirstChild("Lobby")
	if state == "Intro" then
		-- a roleta parou: confete saindo dela
		local wheel = lobby and lobby:FindFirstChild("Wheel")
		local disc = wheel and wheel:FindFirstChild("Disc")
		if disc and disc:IsA("BasePart") then
			burstConfetti(disc.Position + Vector3.new(0, 6, 2))
		end
	elseif state == "Results" and info and info.winners and #info.winners > 0 then
		local podium = workspace:FindFirstChild("Podium")
		local first = podium and podium:FindFirstChild("Step1")
		if first and first:IsA("BasePart") then
			burstConfetti(first.Position + Vector3.new(0, 8, 0))
			task.delay(0.6, burstConfetti, first.Position + Vector3.new(0, 8, 0))
		end
	end
end

function LobbyFxController.init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "LobbyFx"
	fxFolder.Parent = workspace
	task.spawn(function()
		if not collect() then
			warn("[LobbyFx] lobby não carregou")
			return
		end
		buildParticles()
		RunService.Heartbeat:Connect(update)
	end)
	Remotes.get("RoundState").OnClientEvent:Connect(onRoundState)
	-- configuração "Efeitos visuais": liga/desliga poeira e faíscas contínuas (confete e brasas seguem as regras deles)
	Players.LocalPlayer:GetAttributeChangedSignal("HyperShowFx"):Connect(function()
		local on = Players.LocalPlayer:GetAttribute("HyperShowFx") ~= false
		for _, e in fxFolder:GetDescendants() do
			if e:IsA("ParticleEmitter") and e ~= embers and e.Rate > 0 then
				e.Enabled = on
			end
		end
	end)
	Remotes.get("MoodState").OnClientEvent:Connect(function(state: { phase: string })
		furious = state.phase == "Furious" or state.phase == "ToFurious"
		if embers then
			embers.Enabled = furious
		end
	end)
end

return LobbyFxController
