--!strict
-- Cliente: dá vida ao cenário do show criado pelo ShowSetService. Tudo local e só visual:
-- * arquibancadas flutuando (sobe e desce + balanço em volta do centro), só as perto da câmera;
-- * telões (cubo da arena e telão do lobby): estado da rodada, vivos, classificados, campeão e o rosto do Hyper
--   quando ele fala;
-- * fundo espacial da arena: planetas girando, meteoros e estrelas cadentes.
-- Efeitos visuais respeitam a configuração do jogador (atributo local HyperShowFx, do SettingsController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Settings = Config.ShowSet
local Strings = Config.Strings

local GOLD = Color3.fromHex("FFC83D")
local PINK = Color3.fromHex("FF3D8B")
local CYAN = Color3.fromHex("35C8FF")
local GREEN = Color3.fromHex("3DFF8B")
local WHITE = Color3.new(1, 1, 1)

local ShowSetController = {}

local player = Players.LocalPlayer

type Stand = { model: Model, base: CFrame, center: Vector3, phase: number, current: CFrame }
local stands: { [Model]: Stand } = {}

type Screen = { header: TextLabel, big: TextLabel, sub: TextLabel, face: ImageLabel, ticker: TextLabel, avatar: ImageLabel }
local screens: { Screen } = {}
local roundState = "Intermission"
local roundInfo: { [string]: any } = {}
local endsAt = 0
local hyperUntil = 0

local function fxEnabled(): boolean
	return player:GetAttribute("HyperShowFx") ~= false
end

-- Arquibancadas ---------------------------------------------------------------------------------------------
local function siteCenter(model: Model): Vector3
	local site = (Settings.Sites :: any)[model:GetAttribute("Site") or ""]
	return if site then site.center else model:GetPivot().Position
end

local function addStand(model: Model)
	if stands[model] then
		return
	end
	local entry: Stand = {
		model = model,
		base = model:GetPivot(), -- posição que o servidor deu (nunca muda no servidor)
		center = siteCenter(model),
		phase = math.random() * math.pi * 2,
		current = model:GetPivot(),
	}
	stands[model] = entry
	-- boneco novo (o servidor troca skins) chega na posição base: leva para onde a arquibancada está agora
	model.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.defer(function()
				if child.Parent == model then
					child:PivotTo(entry.current * entry.base:Inverse() * child:GetPivot())
				end
			end)
		end
	end)
	model.Destroying:Connect(function()
		stands[model] = nil
	end)
end

local function watchSite(site: Instance)
	for _, child in site:GetChildren() do
		if child:IsA("Model") then
			addStand(child)
		end
	end
	site.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.defer(addStand, child) -- deixa o modelo chegar inteiro (Atomic)
		end
	end)
end

local accumulator = 0
local function updateStands(dt: number)
	accumulator += dt
	if accumulator < 1 / 30 then
		return -- 30 vezes por segundo bastam para um movimento lento
	end
	accumulator = 0
	local t = os.clock()
	local camera = workspace.CurrentCamera.CFrame.Position
	local sway = math.rad(Settings.OrbitSway) * math.sin(t * Settings.OrbitSpeed * math.pi * 2)
	for model, s in stands do
		if not model.Parent then
			stands[model] = nil
			continue
		end
		if (s.base.Position - camera).Magnitude > Settings.UpdateDistance then
			continue
		end
		local bob = Settings.BobHeight * math.sin(t * Settings.BobSpeed * math.pi * 2 + s.phase)
		local tilt = math.rad(2) * math.sin(t * Settings.BobSpeed * math.pi + s.phase)
		local orbit = CFrame.new(s.center) * CFrame.Angles(0, sway, 0) * CFrame.new(-s.center)
		local target = orbit * s.base * CFrame.new(0, bob, 0) * CFrame.Angles(tilt, 0, tilt * 0.5)
		model:PivotTo(target)
		s.current = target
	end
end

-- Telões ----------------------------------------------------------------------------------------------------
local function label(props: { [string]: any }, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.LuckiestGuy
	l.TextColor3 = WHITE
	l.TextStrokeTransparency = 0.3
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function makeScreen(part: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ShowScreen"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 14 -- letras grandes: o telão é visto de longe
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromHex("0D0620")
	bg.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromHex("2A0F55"), Color3.fromHex("07031A"))
	gradient.Rotation = 90
	gradient.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = CYAN
	stroke.Thickness = 6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = bg
	-- linhas de varredura de TV
	local scan = Instance.new("Frame")
	scan.Size = UDim2.fromScale(1, 0.06)
	scan.BackgroundColor3 = WHITE
	scan.BackgroundTransparency = 0.93
	scan.BorderSizePixel = 0
	scan.Parent = bg
	TweenService:Create(scan, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Position = UDim2.fromScale(0, 0.94) }):Play()
	local header = label({ Name = "Header", Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.16), TextColor3 = GOLD, Font = Enum.Font.GothamBlack }, bg)
	local big = label({ Name = "Big", Position = UDim2.fromScale(0.05, 0.24), Size = UDim2.fromScale(0.9, 0.38) }, bg)
	local sub = label({ Name = "Sub", Position = UDim2.fromScale(0.05, 0.63), Size = UDim2.fromScale(0.9, 0.14), Font = Enum.Font.GothamBlack, TextColor3 = CYAN }, bg)
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundTransparency = 1
	avatar.AnchorPoint = Vector2.new(0.5, 0)
	avatar.Position = UDim2.fromScale(0.5, 0.2)
	avatar.Size = UDim2.fromScale(0.3, 0.45)
	avatar.ScaleType = Enum.ScaleType.Fit
	avatar.Visible = false
	avatar.Parent = bg
	local faceImage = Instance.new("ImageLabel")
	faceImage.Name = "HyperFace"
	faceImage.BackgroundColor3 = Color3.new(0, 0, 0)
	faceImage.Position = UDim2.fromScale(0.03, 0.78)
	faceImage.Size = UDim2.fromScale(0.16, 0.19)
	faceImage.ScaleType = Enum.ScaleType.Stretch
	faceImage.ImageRectOffset = Vector2.new(18, 14)
	faceImage.ImageRectSize = Vector2.new(308, 198)
	faceImage.Visible = false
	faceImage.Parent = bg
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = faceImage
	local ticker = label({ Name = "Ticker", Position = UDim2.fromScale(0.21, 0.8), Size = UDim2.fromScale(0.76, 0.15), Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, bg)
	table.insert(screens, { header = header, big = big, sub = sub, face = faceImage, ticker = ticker, avatar = avatar })
end

local function setupScreens(folder: Instance)
	local function tryArena(model: Instance)
		local body = model:FindFirstChild("Screen")
		if body and body:IsA("BasePart") and not body:FindFirstChild("ShowScreen") then
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
				makeScreen(body, face)
			end
		end
	end
	local function tryLobby(model: Instance)
		local body = model:FindFirstChild("Screen")
		if body and body:IsA("BasePart") and not body:FindFirstChild("ShowScreen") then
			makeScreen(body, Enum.NormalId.Front)
		end
	end
	local arena = folder:WaitForChild("ArenaScreen", 30)
	if arena then
		tryArena(arena)
	end
	local lobby = folder:WaitForChild("LobbyScreen", 30)
	if lobby then
		lobby:WaitForChild("Screen", 10)
		tryLobby(lobby)
	end
end

local avatarCache: { [string]: string } = {}
local function refreshScreens()
	local header, big, sub = "", "", ""
	local bigColor = WHITE
	local avatarImage: string? = nil
	local phase = roundInfo.phase
	local minigame = roundInfo.minigame
	local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
	if roundState == "Playing" then
		header = table.concat({ phase or "", minigame or "" }, "  •  ")
		local alive = workspace:GetAttribute("HyperShowAlive") or 0
		local started = workspace:GetAttribute("HyperShowStarted") or 0
		big = string.format(Strings.ScreenAlive, alive, started)
		bigColor = GREEN
		sub = string.format(Strings.ScreenTime, remaining)
	elseif roundState == "Intro" then
		header = table.concat({ phase or "", minigame or "" }, "  •  ")
		big = if remaining > 0 then tostring(remaining) else Strings.Playing
		bigColor = GOLD
		sub = roundInfo.instruction or ""
	elseif roundState == "Spin" or roundState == "Teleport" then
		header = phase or Strings.ScreenTitle
		big = Strings.Spin
		bigColor = PINK
		sub = if roundState == "Teleport" then minigame or "" else ""
	elseif roundState == "Qualification" then
		header = table.concat({ phase or "", minigame or "" }, "  •  ")
		big = string.format(Strings.QualifiedCount, roundInfo.qualifiedCount or 0)
		bigColor = GREEN
		sub = string.format(Strings.EliminatedCount, roundInfo.eliminatedCount or 0)
	elseif roundState == "Results" then
		header = Strings.ScreenChampion
		local winners = roundInfo.winners or {}
		big = winners[1] or Strings.NoWinners
		bigColor = GOLD
		sub = minigame or ""
		local championId = roundInfo.championId
		if championId then
			avatarImage = avatarCache[tostring(championId)]
		end
	else
		header = Strings.ScreenTitle
		big = Strings.ScreenLogo
		bigColor = PINK
		sub = roundInfo.minigame or Strings.WaitingParticipants
	end
	local talking = os.clock() < hyperUntil
	for _, screen in screens do
		screen.header.Text = header
		screen.big.Text = big
		screen.big.TextColor3 = bigColor
		screen.sub.Text = sub
		screen.avatar.Visible = avatarImage ~= nil
		if avatarImage then
			screen.avatar.Image = avatarImage
			screen.big.Position = UDim2.fromScale(0.05, 0.62)
			screen.big.Size = UDim2.fromScale(0.9, 0.16)
			screen.sub.Visible = false
		else
			screen.big.Position = UDim2.fromScale(0.05, 0.24)
			screen.big.Size = UDim2.fromScale(0.9, 0.38)
			screen.sub.Visible = true
		end
		screen.face.Visible = talking
		if not talking then
			screen.ticker.Text = ""
		end
	end
end

local function onRoundState(state: string, newEndsAt: number, info: { [string]: any }?)
	roundState = state
	endsAt = newEndsAt
	roundInfo = info or {}
	local championId = roundInfo.championId
	if state == "Results" and championId and not avatarCache[tostring(championId)] then
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(championId, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)
			end)
			if ok then
				avatarCache[tostring(championId)] = image
				refreshScreens()
			end
		end)
	end
	refreshScreens()
end

local function onHyperSays(line: string, faceKey: string, duration: number)
	hyperUntil = os.clock() + duration
	local image = (Config.Hyper.Faces :: { [string]: string })[faceKey] or ""
	for _, screen in screens do
		screen.face.Image = image
		screen.ticker.Text = line
	end
	refreshScreens()
end

-- Fundo espacial da arena -----------------------------------------------------------------------------------
local spaceFolder: Folder
type Planet = { part: BasePart, ring: BasePart?, base: CFrame, phase: number, spin: number }
local planets: { Planet } = {}

local function spacePart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = spaceFolder
	return p
end

local function buildArenaSpace()
	spaceFolder = Instance.new("Folder")
	spaceFolder.Name = "ArenaSpaceFx"
	spaceFolder.Parent = workspace
	local c = Config.NeonCollapse.ArenaOrigin
	local defs = {
		{ offset = Vector3.new(-260, 60, 180), size = 70, color = Color3.fromHex("7B3DFF"), ring = Color3.fromHex("35C8FF") },
		{ offset = Vector3.new(240, 110, 260), size = 46, color = Color3.fromHex("FF7A3D"), ring = nil },
		{ offset = Vector3.new(60, -120, 330), size = 90, color = Color3.fromHex("1FB6FF"), ring = Color3.fromHex("FF3D8B") },
		{ offset = Vector3.new(-120, 150, -220), size = 30, color = Color3.fromHex("3DFF8B"), ring = nil },
	}
	for i, def in defs do
		local cf = CFrame.new(c + def.offset)
		local planet = spacePart("Planet", Vector3.one * def.size, cf, def.color, Enum.Material.SmoothPlastic)
		planet.Shape = Enum.PartType.Ball
		local atmosphere = spacePart("Atmosphere", Vector3.one * def.size * 1.08, cf, def.color, Enum.Material.Neon)
		atmosphere.Shape = Enum.PartType.Ball
		atmosphere.Transparency = 0.8
		local ring: BasePart? = nil
		if def.ring then
			local r = spacePart("PlanetRing", Vector3.new(0.6, def.size * 2.1, def.size * 2.1), cf * CFrame.Angles(0, 0, math.rad(70)), def.ring, Enum.Material.Neon)
			r.Shape = Enum.PartType.Cylinder
			r.Transparency = 0.55
			ring = r
		end
		table.insert(planets, { part = planet, ring = ring, base = cf, phase = i * 1.7, spin = 0.05 + i * 0.02 })
		table.insert(planets, { part = atmosphere, ring = nil, base = cf, phase = i * 1.7, spin = 0 })
	end
	-- estrelas cintilando em volta da arena
	local holder = spacePart("Stars", Vector3.new(700, 300, 700), CFrame.new(c + Vector3.new(0, 40, 0)), WHITE, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	local stars = Instance.new("ParticleEmitter")
	stars.Name = "Twinkle"
	stars.Shape = Enum.ParticleEmitterShape.Box
	stars.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	stars.LightEmission = 1
	stars.Rate = 30
	stars.Lifetime = NumberRange.new(3, 5)
	stars.Speed = NumberRange.new(0)
	stars.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 2.5), NumberSequenceKeypoint.new(1, 0) })
	stars.Color = ColorSequence.new(WHITE, Color3.fromHex("BFE9FF"))
	stars.Parent = holder
end

local function streak(kind: string)
	local c = Config.NeonCollapse.ArenaOrigin
	local meteorKind = kind == "Meteor"
	local start = c + Vector3.new(math.random(-300, 300), math.random(60, 180), math.random(-250, 350))
	local direction = Vector3.new(if math.random() < 0.5 then -1 else 1, if meteorKind then -0.35 else -0.15, math.random(-3, 3) / 10).Unit
	local head = spacePart(kind, Vector3.one * (if meteorKind then 3 else 0.8), CFrame.new(start), if meteorKind then Color3.fromRGB(255, 160, 80) else WHITE, Enum.Material.Neon)
	head.Shape = Enum.PartType.Ball
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = head
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = head
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = if meteorKind then 0.8 else 0.4
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = if meteorKind
		then ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 60, 30))
		else ColorSequence.new(WHITE, Color3.fromHex("35C8FF"))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = head
	local speed = if meteorKind then 120 else 260
	local life = if meteorKind then 2.4 else 1.2
	local born = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - born
		if t > life then
			conn:Disconnect()
			head:Destroy()
			return
		end
		head.CFrame = CFrame.new(start + direction * speed * t)
	end)
end

local function updateSpace()
	local t = os.clock()
	for _, p in planets do
		local bob = math.sin(t * 0.3 + p.phase) * 4
		local cf = p.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * p.spin, 0)
		p.part.CFrame = cf
		local ring = p.ring
		if ring then
			ring.CFrame = p.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * 0.03, math.rad(70))
		end
	end
end

-- Extras neon do lobby (tools/build_lobby_neon.luau): halo do céu girando e orbes flutuando.
type Orb = { model: Model, base: CFrame, phase: number }
local skyHalo: Model? = nil
local skyBase = CFrame.identity
local orbs: { Orb } = {}

local function collectLobbyExtras()
	local lobby = workspace:WaitForChild("Lobby", 60)
	local extras = lobby and lobby:WaitForChild("NeonExtras", 30)
	if not extras then
		return
	end
	local sky = extras:FindFirstChild("SkyHalo")
	if sky and sky:IsA("Model") then
		skyHalo = sky
		skyBase = sky:GetPivot()
	end
	local orbFolder = extras:FindFirstChild("Orbs")
	if orbFolder then
		for i, orb in orbFolder:GetChildren() do
			if orb:IsA("Model") then
				table.insert(orbs, { model = orb, base = orb:GetPivot(), phase = i * 0.8 })
			end
		end
	end
end

local function updateLobbyExtras()
	local camera = workspace.CurrentCamera.CFrame.Position
	if camera.Magnitude > 320 then
		return -- longe do lobby (por exemplo, na arena)
	end
	local t = os.clock()
	local halo = skyHalo
	if halo then
		halo:PivotTo(skyBase * CFrame.Angles(0, math.rad(t * (halo:GetAttribute("Spin") or 4)), 0))
	end
	for _, orb in orbs do
		orb.model:PivotTo(orb.base * CFrame.new(0, math.sin(t * 0.8 + orb.phase) * 2.5, 0) * CFrame.Angles(0, t * 0.6, 0))
	end
end

local function nearArena(): boolean
	local camera = workspace.CurrentCamera.CFrame.Position
	return (camera - Config.NeonCollapse.ArenaOrigin).Magnitude < 450
end

function ShowSetController.init()
	buildArenaSpace()
	task.spawn(collectLobbyExtras)
	task.spawn(function()
		local folder = workspace:WaitForChild("ShowSet", 60)
		if not folder then
			warn("[ShowSet] cenário não encontrado")
			return
		end
		for _, site in folder:GetChildren() do
			if site:IsA("Folder") then
				watchSite(site)
			end
		end
		folder.ChildAdded:Connect(function(site)
			if site:IsA("Folder") then
				watchSite(site)
			end
		end)
		setupScreens(folder)
		refreshScreens()
	end)
	Remotes.get("RoundState").OnClientEvent:Connect(onRoundState)
	Remotes.get("HyperSays").OnClientEvent:Connect(onHyperSays)
	RunService.Heartbeat:Connect(function(dt)
		updateStands(dt)
		if fxEnabled() and nearArena() then
			updateSpace()
		end
		if fxEnabled() then
			updateLobbyExtras()
		end
	end)
	-- telões: contagem de vivos e tempo mudam sem novo estado
	task.spawn(function()
		while true do
			task.wait(0.5)
			refreshScreens()
		end
	end)
	-- meteoros e estrelas cadentes perto da arena
	task.spawn(function()
		while true do
			task.wait(math.random(15, 40) / 10)
			if fxEnabled() and nearArena() then
				streak(if math.random() < 0.4 then "Meteor" else "ShootingStar")
			end
		end
	end)
end

return ShowSetController
