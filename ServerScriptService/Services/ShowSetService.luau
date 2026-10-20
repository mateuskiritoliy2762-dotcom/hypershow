--!strict
-- Cenário do show (servidor): arquibancadas flutuantes em volta da arena e do lobby, com bonecos vestidos com
-- skins reais do Roblox (Config.ShowSet.Usernames + quem está no servidor), e as peças dos telões.
-- Os bonecos são só visuais: raiz ancorada, sem física, sem colisão; o emote de cada um muda com o estado da
-- rodada (onState). A flutuação das arquibancadas e o conteúdo dos telões são do ShowSetController (cliente).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Settings = Config.ShowSet

local ShowSetService = {}

type Seat = { stand: Model, cframe: CFrame, rig: Model?, track: AnimationTrack? }

local folder: Folder
local seats: { Seat } = {}
local pool: { number } = {} -- UserIds disponíveis para vestir a plateia
local descriptions: { [number]: HumanoidDescription } = {}
local animations: { [string]: Animation } = {}
local mood = "Idle"
local rng = Random.new()

local PURPLE = Color3.fromHex("2A1650")
local PINK = Color3.fromHex("FF3D8B")
local CYAN = Color3.fromHex("35C8FF")
local GOLD = Color3.fromHex("FFC83D")

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CastShadow = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- Arquibancada flutuante: base de metal escuro em dois degraus, faixas neon, vidro na frente e dois
-- propulsores embaixo. `cf` olha para o centro do anel (frente = -Z local).
local function buildStand(cf: CFrame, index: number, seatCount: number, parent: Instance): (Model, { CFrame })
	local stand = Instance.new("Model")
	stand.Name = "Stand" .. index
	stand.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- chega inteira no cliente (bonecos junto)
	local w, d = 20, 9
	local base = part({ Name = "Base", Size = Vector3.new(w, 1.4, d), CFrame = cf, Color = PURPLE, Material = Enum.Material.Metal }, stand)
	part({ Name = "Tier", Size = Vector3.new(w, 1.6, d / 2), CFrame = cf * CFrame.new(0, 1.5, d / 4), Color = PURPLE, Material = Enum.Material.Metal }, stand)
	part({ Name = "Underside", Size = Vector3.new(w - 3, 1.2, d - 2), CFrame = cf * CFrame.new(0, -1.3, 0), Color = Color3.fromHex("1A0D33"), Material = Enum.Material.Metal }, stand)
	part({ Name = "FrontTrim", Size = Vector3.new(w + 0.2, 0.35, 0.35), CFrame = cf * CFrame.new(0, 0.55, -d / 2), Color = if index % 2 == 0 then PINK else CYAN, Material = Enum.Material.Neon }, stand)
	part({ Name = "TierTrim", Size = Vector3.new(w + 0.2, 0.3, 0.3), CFrame = cf * CFrame.new(0, 2.3, 0), Color = GOLD, Material = Enum.Material.Neon }, stand)
	part({ Name = "UnderGlow", Size = Vector3.new(w - 4, 0.2, d - 3), CFrame = cf * CFrame.new(0, -1.95, 0), Color = if index % 2 == 0 then CYAN else PINK, Material = Enum.Material.Neon, Transparency = 0.3 }, stand)
	part({ Name = "Glass", Size = Vector3.new(w, 2.2, 0.25), CFrame = cf * CFrame.new(0, 1.8, -d / 2 + 0.1), Color = Color3.fromHex("BFE9FF"), Material = Enum.Material.Glass, Transparency = 0.7 }, stand)
	for _, x in { -w / 3, w / 3 } do
		local thruster = part({
			Name = "Thruster",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.2,
			CFrame = cf * CFrame.new(x, -2.2, 0),
			Color = CYAN,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, stand)
		local flame = Instance.new("ParticleEmitter")
		flame.Color = ColorSequence.new(CYAN, PINK)
		flame.LightEmission = 1
		flame.Rate = 12
		flame.Lifetime = NumberRange.new(0.5, 0.9)
		flame.Speed = NumberRange.new(5, 8)
		flame.EmissionDirection = Enum.NormalId.Bottom
		flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		flame.Transparency = NumberSequence.new(0.3, 1)
		flame.Parent = thruster
	end
	stand.PrimaryPart = base
	stand.Parent = parent
	-- lugares: fila da frente (no piso) e fila de trás (no degrau), de frente para o centro
	local spots: { CFrame } = {}
	local perRow = math.ceil(seatCount / 2)
	for row = 0, 1 do
		for i = 1, perRow do
			if #spots >= seatCount then break end
			local x = (i - (perRow + 1) / 2) * (w / perRow)
			local y = 0.7 + row * 1.6
			local z = -d / 4 + row * d / 2
			table.insert(spots, cf * CFrame.new(x, y, z))
		end
	end
	return stand, spots
end

local function emoteFor(): string
	local list = if mood == "Excited" then { "Cheer", "Cheer", "Dance", "Dance2", "Point" }
		elseif mood == "Laugh" then { "Laugh", "Laugh", "Point", "Cheer" }
		else { "Wave", "Cheer", "Point", "Dance" }
	return list[rng:NextInteger(1, #list)]
end

local function playEmote(seat: Seat)
	local rig = seat.rig
	local humanoid = rig and rig:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	if seat.track then
		seat.track:Stop(0.4)
	end
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animations[emoteFor()])
	end)
	if ok and track then
		track.Looped = true
		track:Play(0.4, 1, rng:NextNumber(0.8, 1.15))
		seat.track = track
	end
end

local function getDescription(userId: number): HumanoidDescription?
	local cached = descriptions[userId]
	if cached then
		return cached
	end
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	if ok and description then
		descriptions[userId] = description
		return description
	end
	return nil
end

-- Veste o lugar com a skin de `userId`: cria o boneco R15, ancora, tira colisão e põe para torcer.
local function dress(seat: Seat, userId: number)
	local description = getDescription(userId)
	if not description or not seat.stand.Parent then
		return
	end
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		return
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.EvaluateStateMachine = false
	root.Anchored = true
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Massless = true
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	rig.Name = "Fan"
	rig:SetAttribute("UserId", userId)
	rig:PivotTo(seat.cframe * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	if seat.rig then
		seat.rig:Destroy()
	end
	seat.rig = rig
	seat.track = nil
	rig.Parent = seat.stand
	playEmote(seat)
end

local function buildSite(name: string, site: { center: Vector3, radius: number, stands: number, seats: number, skipAngle: number })
	local siteFolder = Instance.new("Folder")
	siteFolder.Name = name
	siteFolder.Parent = folder
	-- distribui as arquibancadas no anel, pulando a direção livre (skipAngle)
	local count = site.stands
	local step = 360 / (count + 1)
	for i = 1, count do
		local angle = math.rad(site.skipAngle + step * i)
		local pos = site.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * site.radius
		local cf = CFrame.lookAt(pos, Vector3.new(site.center.X, pos.Y, site.center.Z))
		local stand, spots = buildStand(cf, i, site.seats, siteFolder)
		stand:SetAttribute("Site", name)
		for _, spot in spots do
			table.insert(seats, { stand = stand, cframe = spot, rig = nil, track = nil })
		end
	end
end

-- Telões: peças vazias com o nome certo; o ShowSetController desenha o conteúdo (SurfaceGui) no cliente.
local function buildScreens()
	local arenaCenter = Config.NeonCollapse.ArenaOrigin + Settings.ArenaScreen.offset
	local size = Settings.ArenaScreen.size
	local cube = Instance.new("Model")
	cube.Name = "ArenaScreen"
	cube.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local body = part({
		Name = "Screen",
		Size = Vector3.new(size.X, size.Y, size.X),
		CFrame = CFrame.new(arenaCenter),
		Color = Color3.fromHex("120A26"),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, cube)
	for _, y in { size.Y / 2, -size.Y / 2 } do
		part({ Name = "Trim", Size = Vector3.new(size.X + 0.6, 0.5, size.X + 0.6), CFrame = CFrame.new(arenaCenter + Vector3.new(0, y, 0)), Color = PINK, Material = Enum.Material.Neon, CanCollide = false }, cube)
	end
	-- cabos de luz até o "teto"
	for _, c in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		local top = arenaCenter + Vector3.new(0, size.Y / 2, 0) + c * (size.X / 2 - 1)
		part({ Name = "Cable", Size = Vector3.new(0.3, 30, 0.3), CFrame = CFrame.new(top + Vector3.new(0, 15, 0)), Color = CYAN, Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.3 }, cube)
	end
	cube.PrimaryPart = body
	cube.Parent = folder

	local lobbyCfg = Settings.LobbyScreen
	local lobbyScreen = Instance.new("Model")
	lobbyScreen.Name = "LobbyScreen"
	-- frente (-Z local) virada para a ilha (+Z do mundo), um pouco girada para o centro; moldura atrás (+Z local)
	local cf = CFrame.new(lobbyCfg.position) * CFrame.Angles(0, math.rad(180 + lobbyCfg.yaw), 0)
	local screen = part({
		Name = "Screen",
		Size = Vector3.new(lobbyCfg.size.X, lobbyCfg.size.Y, 0.6),
		CFrame = cf,
		Color = Color3.fromHex("120A26"),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, lobbyScreen)
	part({ Name = "Frame", Size = Vector3.new(lobbyCfg.size.X + 1, lobbyCfg.size.Y + 1, 0.4), CFrame = cf * CFrame.new(0, 0, 0.3), Color = PINK, Material = Enum.Material.Neon, CanCollide = false }, lobbyScreen)
	part({ Name = "Back", Size = Vector3.new(lobbyCfg.size.X + 2, lobbyCfg.size.Y + 2, 0.4), CFrame = cf * CFrame.new(0, 0, 0.6), Color = PURPLE, Material = Enum.Material.Metal, CanCollide = false }, lobbyScreen)
	lobbyScreen.PrimaryPart = screen
	lobbyScreen.Parent = folder
end

-- Muda o clima da plateia com o estado da rodada (chamado pelo RoundService).
function ShowSetService.onState(state: string)
	local new = if state == "Playing" or state == "Results" or state == "Intro" then "Excited"
		elseif state == "Qualification" then "Laugh"
		else "Idle"
	if new == mood then
		return
	end
	mood = new
	for i, seat in seats do
		task.delay((i % 10) * 0.15, playEmote, seat) -- não mudam todos no mesmo instante
	end
end

local function resolveUsernames()
	for _, name in Settings.Usernames do
		local ok, id = pcall(function()
			return Players:GetUserIdFromNameAsync(name)
		end)
		if ok and id and not table.find(pool, id) then
			table.insert(pool, id)
		end
	end
end

local function fillSeats()
	if #pool == 0 then
		return
	end
	for i, seat in seats do
		dress(seat, pool[(i - 1) % #pool + 1])
		if i % 4 == 0 then
			task.wait() -- espalha o trabalho (cada boneco é uma chamada web + montagem)
		end
	end
end

function ShowSetService.init()
	folder = Instance.new("Folder")
	folder.Name = "ShowSet"
	folder.Parent = workspace
	for key, id in Settings.Emotes do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		animations[key] = animation
	end
	for name, site in Settings.Sites do
		buildSite(name, site)
	end
	buildScreens()
end

function ShowSetService.start()
	-- jogadores do servidor entram na lista de skins; de tempos em tempos um boneco vira um deles
	local function addPlayer(player: Player)
		if player.UserId > 0 and not table.find(pool, player.UserId) then
			table.insert(pool, player.UserId)
		end
	end
	Players.PlayerAdded:Connect(addPlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	resolveUsernames()
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	fillSeats()
	while true do
		task.wait(Settings.RefreshInterval)
		local present = Players:GetPlayers()
		if #present > 0 and #seats > 0 then
			local player = present[rng:NextInteger(1, #present)]
			if player.UserId > 0 then
				dress(seats[rng:NextInteger(1, #seats)], player.UserId)
			end
		end
	end
end

return ShowSetService
