--!strict
-- Campeonato estilo Fall Guys (autoridade do servidor). O RoundService roda as fases; aqui ficam:
-- * quem ainda concorre (contenders), quantas vagas cada fase classifica e quando vem a grande final;
-- * a ordem de classificação de uma fase, com desempate determinístico (nunca sorteio);
-- * a pontuação da partida (Config.Tournament.Points; separada das moedas);
-- * o camarim flutuante onde os classificados esperam a próxima fase sem voltar ao lobby.
-- Atributos: HyperShowInTournament (ainda concorre), HyperShowInGreenRoom (esperando no camarim),
-- HyperShowPoints (pontos desta partida).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local Settings = Config.Tournament
local Points = Settings.Points

local TournamentService = {}

local contenders: { Player } = {}
local seed: { [Player]: number } = {} -- colocação na fase anterior (1 = melhor); desempate da próxima
local points: { [Player]: number } = {}
local startCount = 0
local spots: { CFrame } = {}

local function addPoints(player: Player, amount: number)
	points[player] = (points[player] or 0) + amount
	if player.Parent == Players then
		player:SetAttribute("HyperShowPoints", points[player])
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function ringOf(parent: Instance, center: Vector3, radius: number, thickness: number, color: Color3, segments: number, name: string)
	for i = 0, segments - 1 do
		local a0 = 2 * math.pi * i / segments
		local a1 = 2 * math.pi * (i + 1) / segments
		local p0 = center + Vector3.new(math.cos(a0) * radius, 0, math.sin(a0) * radius)
		local p1 = center + Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius)
		part({
			Name = name,
			Size = Vector3.new(thickness, thickness, (p1 - p0).Magnitude + thickness * 0.5),
			CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
		}, parent)
	end
end

-- Camarim: disco voador de vidro escuro com anéis neon, propulsor embaixo, mureta de vidro, arcos neon e um
-- letreiro holográfico flutuando no alto, virado para a arena.
local function buildGreenRoom()
	local old = workspace:FindFirstChild("GreenRoom")
	if old then
		old:Destroy()
	end
	local origin = Settings.GreenRoomOrigin
	local radius = Settings.GreenRoomRadius
	local model = Instance.new("Model")
	model.Name = "GreenRoom"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- sempre carregado: ninguém cai antes de o chão chegar
	local disc = CFrame.Angles(0, 0, math.rad(90)) -- cilindro deitado (eixo X vira vertical)
	local floor = part({
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, radius * 2, radius * 2),
		CFrame = CFrame.new(origin) * disc,
		Color = Color3.fromHex("1C0F3D"),
		Material = Enum.Material.Glass,
		Reflectance = 0.25,
	}, model)
	-- piso: anéis neon concêntricos e um círculo central
	for i, r in { radius * 0.28, radius * 0.55, radius * 0.82 } do
		ringOf(model, origin + Vector3.new(0, 1.02, 0), r, 0.18, if i % 2 == 1 then Color3.fromHex("35C8FF") else Color3.fromHex("FF3D8B"), 28, "FloorRing")
	end
	part({
		Name = "CenterPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, radius * 0.4, radius * 0.4),
		CFrame = CFrame.new(origin + Vector3.new(0, 1.03, 0)) * disc,
		Color = Color3.fromHex("3DFF8B"),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		CanQuery = false,
	}, model)
	-- casco de baixo em degraus (formato de disco voador) com brilho e propulsor
	for i, r in { radius * 0.9, radius * 0.7, radius * 0.45 } do
		part({
			Name = "Hull",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, r * 2, r * 2),
			CFrame = CFrame.new(origin - Vector3.new(0, 1 + i * 1.5, 0)) * disc,
			Color = Color3.fromHex("2A1650"),
			Material = Enum.Material.Metal,
			CanQuery = false,
		}, model)
	end
	ringOf(model, origin - Vector3.new(0, 1.2, 0), radius + 0.3, 0.7, Color3.fromHex("3DFF8B"), 32, "Rim")
	local thruster = part({
		Name = "Thruster",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 5,
		Position = origin - Vector3.new(0, 6.5, 0),
		Color = Color3.fromHex("35C8FF"),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
	}, model)
	local flame = Instance.new("ParticleEmitter")
	flame.Color = ColorSequence.new(Color3.fromHex("35C8FF"), Color3.fromHex("FF3D8B"))
	flame.LightEmission = 1
	flame.Rate = 25
	flame.Lifetime = NumberRange.new(0.8, 1.4)
	flame.Speed = NumberRange.new(8, 12)
	flame.EmissionDirection = Enum.NormalId.Bottom
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0) })
	flame.Transparency = NumberSequence.new(0.3, 1)
	flame.Parent = thruster
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromHex("35C8FF")
	glow.Range = 24
	glow.Brightness = 2
	glow.Parent = thruster
	-- mureta de vidro com corrimão neon
	local segments = 24
	for i = 0, segments - 1 do
		local a = 2 * math.pi * (i + 0.5) / segments
		local length = 2 * math.pi * radius / segments + 0.4
		part({
			Name = "Glass",
			Size = Vector3.new(length, 4, 0.4),
			CFrame = CFrame.new(origin + Vector3.new(math.cos(a) * radius, 3, math.sin(a) * radius))
				* CFrame.Angles(0, -a + math.pi / 2, 0),
			Color = Config.NeonCollapse.CageColor,
			Material = Enum.Material.Glass,
			Transparency = 0.65,
		}, model)
	end
	ringOf(model, origin + Vector3.new(0, 5.1, 0), radius, 0.3, Color3.fromHex("FF3D8B"), 32, "Rail")
	-- dois arcos neon cruzados por cima do disco
	local archHeight = 16
	for k = 0, 1 do
		local yaw = math.rad(45 + 90 * k)
		local steps = 16
		for i = 0, steps - 1 do
			local t0, t1 = math.pi * i / steps, math.pi * (i + 1) / steps
			local function point(t: number): Vector3
				local h = math.cos(t) * radius
				return origin + Vector3.new(math.cos(yaw) * h, 1 + math.sin(t) * archHeight, math.sin(yaw) * h)
			end
			local p0, p1 = point(t0), point(t1)
			part({
				Name = "Arch",
				Size = Vector3.new(0.5, 0.5, (p1 - p0).Magnitude + 0.25),
				CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
				Color = if k == 0 then Color3.fromHex("35C8FF") else Color3.fromHex("C23DFF"),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
			}, model)
		end
	end
	-- letreiro holográfico no alto, virado para a arena (placa do ForgeGUI + texto de Config.Strings)
	local arena = Config.NeonCollapse.ArenaOrigin
	local toArena = Vector3.new(arena.X - origin.X, 0, arena.Z - origin.Z).Unit
	local signPos = origin + Vector3.new(0, archHeight + 6, 0)
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(22, 22 * 457 / 1024, 0.2),
		CFrame = CFrame.lookAt(signPos, signPos + toArena),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, model)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Brightness = 1.5
		gui.Parent = sign
		local plate = Instance.new("ImageLabel")
		plate.Size = UDim2.fromScale(1, 1)
		plate.BackgroundTransparency = 1
		plate.Image = Config.Icons.TitlePlate
		plate.Parent = gui
		local text = Instance.new("TextLabel")
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.Position = UDim2.fromScale(0.5, 0.5)
		text.Size = UDim2.fromScale(0.7, 0.4)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.Font = Enum.Font.LuckiestGuy
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.2
		text.Text = Config.Strings.GreenRoomSign
		text.Parent = plate
	end
	model.PrimaryPart = floor
	model.Parent = workspace

	-- vagas em dois anéis, todos de frente para a arena
	table.clear(spots)
	local top = origin.Y + 1
	for ringIndex, ring in { { r = radius * 0.35, n = 7 }, { r = radius * 0.7, n = 13 } } do
		for i = 0, ring.n - 1 do
			local a = 2 * math.pi * (i + ringIndex * 0.5) / ring.n
			local pos = Vector3.new(origin.X + math.cos(a) * ring.r, top, origin.Z + math.sin(a) * ring.r)
			table.insert(spots, CFrame.lookAt(pos, pos + toArena))
		end
	end
end

-- Coloca o personagem atual (vivo) numa vaga do camarim.
function TournamentService.sendToGreenRoom(player: Player, index: number?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(player)
	if not character or not humanoid or not root or #spots == 0 then
		return
	end
	player:SetAttribute("HyperShowInGreenRoom", true)
	local spot = spots[((index or math.random(1, #spots)) - 1) % #spots + 1]
	pcall(function()
		player:RequestStreamAroundAsync(spot.Position, Settings.GreenRoomStreamTimeout)
	end)
	if player.Character ~= character or not root.Parent then
		return
	end
	root.Anchored = false
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(spot * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.1, 0))
end

-- Começa um campeonato com estes jogadores (já validados pelo RoundService).
function TournamentService.begin(players: { Player })
	TournamentService.reset()
	workspace:SetAttribute("HyperShowTournament", true) -- o painel do lobby avisa quem chegar depois
	startCount = #players
	for i, player in players do
		table.insert(contenders, player)
		seed[player] = i
		points[player] = 0
		player:SetAttribute("HyperShowInTournament", true)
		player:SetAttribute("HyperShowPoints", 0)
	end
end

-- Encerra o campeonato e tira as marcas de todos (inclusive de quem já foi eliminado).
function TournamentService.reset()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("HyperShowInTournament", nil)
		player:SetAttribute("HyperShowInGreenRoom", nil)
	end
	table.clear(contenders)
	table.clear(seed)
	table.clear(points)
	startCount = 0
	workspace:SetAttribute("HyperShowTournament", nil)
end

-- Quem ainda concorre: conectado e sem ter pedido "Ficar no lobby".
function TournamentService.contenders(): { Player }
	local list = {}
	for _, player in contenders do
		if player.Parent == Players and player:GetAttribute("HyperShowQueued") == true then
			table.insert(list, player)
		elseif player.Parent == Players then
			player:SetAttribute("HyperShowInTournament", nil) -- desistiu entre fases
			player:SetAttribute("HyperShowInGreenRoom", nil)
		end
	end
	contenders = list
	return list
end

function TournamentService.isFinal(phase: number, count: number): boolean
	return count <= Settings.FinalSize or phase >= Settings.MaxPhases
end

-- Vagas da fase: corta uma fração fixa do total inicial (12 -> 9 -> 6 -> 3), nunca abaixo da final.
function TournamentService.qualifySlots(count: number): number
	local cut = math.max(1, math.floor(startCount * Settings.CutRatio + 0.5))
	return math.clamp(count - cut, math.min(Settings.FinalSize, count), count)
end

-- Ordem da fase: vivos no fim primeiro; depois quem caiu mais tarde; empate pela colocação anterior e,
-- por último, pelo UserId. Quem saiu do servidor fica de fora.
function TournamentService.rank(ctx: Types.RoundContext): { Player }
	local list = {}
	for _, player in ctx.players do
		if player.Parent == Players and ctx.leftAt[player] == nil then
			table.insert(list, player)
		end
	end
	local function aliveAtEnd(player: Player): boolean
		return ctx.alive[player] == true and ctx.eliminatedAt[player] == nil
	end
	table.sort(list, function(a, b)
		local aa, ab = aliveAtEnd(a), aliveAtEnd(b)
		if aa ~= ab then
			return aa
		end
		if not aa then
			local ta, tb = ctx.eliminatedAt[a] or 0, ctx.eliminatedAt[b] or 0
			if ta ~= tb then
				return ta > tb
			end
		end
		local sa, sb = seed[a] or math.huge, seed[b] or math.huge
		if sa ~= sb then
			return sa < sb
		end
		return a.UserId < b.UserId
	end)
	return list
end

-- Aplica o resultado de uma fase normal: os `slots` primeiros seguem; o resto sai do campeonato.
-- Retorna classificados, eliminados e as linhas da tela de classificação (na ordem de entrada).
function TournamentService.qualify(ranking: { Player }, slots: number): ({ Player }, { Player }, { Types.QualificationEntry })
	local qualified, eliminated = {}, {}
	local entries: { Types.QualificationEntry } = {}
	-- concorrente que não chegou a jogar a fase (teleporte falhou, morreu antes) também sai
	for _, player in contenders do
		if not table.find(ranking, player) then
			table.insert(eliminated, player)
			player:SetAttribute("HyperShowInTournament", nil)
			player:SetAttribute("HyperShowInGreenRoom", nil)
		end
	end
	for i, player in ranking do
		addPoints(player, Points.Participate)
		local passed = i <= slots
		if passed then
			addPoints(player, Points.Qualify)
			table.insert(qualified, player)
			seed[player] = i
		else
			table.insert(eliminated, player)
			player:SetAttribute("HyperShowInTournament", nil)
			player:SetAttribute("HyperShowInGreenRoom", nil)
		end
		table.insert(entries, { id = player.UserId, name = player.DisplayName, qualified = passed })
	end
	if ranking[1] then
		addPoints(ranking[1], Points.Highlight)
	end
	contenders = qualified
	return qualified, eliminated, entries
end

-- Grande final: soma participação, final e colocação dos três primeiros. Retorna os pontos de cada um.
function TournamentService.finish(ranking: { Player }): { [Player]: number }
	local placeBonus = { Points.First, Points.Second, Points.Third }
	for i, player in ranking do
		addPoints(player, Points.Participate + Points.Final + (placeBonus[i] or 0))
	end
	if ranking[1] then
		addPoints(ranking[1], Points.Highlight)
	end
	local result = table.clone(points)
	TournamentService.reset()
	return result
end

-- Quantas fases o campeonato deve ter (estimativa para o letreiro "FASE x DE y").
function TournamentService.estimatePhases(): number
	local count, phase = startCount, 1
	while not TournamentService.isFinal(phase, count) do
		count = TournamentService.qualifySlots(count)
		phase += 1
	end
	return phase
end

local elapsed = 0
local function step(dt: number)
	elapsed += dt
	if elapsed < Settings.CheckInterval then
		return
	end
	elapsed = 0
	local origin = Settings.GreenRoomOrigin
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("HyperShowInGreenRoom") ~= true or player:GetAttribute("HyperShowParticipant") == true then
			continue
		end
		local root = rootOf(player)
		if root and root.Position.Y < origin.Y - Settings.GreenRoomFallDepth then
			task.spawn(TournamentService.sendToGreenRoom, player, nil)
		end
	end
end

function TournamentService.init()
	buildGreenRoom()
	local function watch(player: Player)
		-- quem resetou no camarim volta para ele
		player.CharacterAdded:Connect(function()
			if player:GetAttribute("HyperShowInGreenRoom") == true then
				task.defer(TournamentService.sendToGreenRoom, player, nil)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		seed[player] = nil
		points[player] = nil
	end)
	RunService.Heartbeat:Connect(step)
end

return TournamentService
