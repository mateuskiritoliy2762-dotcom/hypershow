--!strict
-- Desmoronamento Neon (Sobrevivência): 3 andares de hexágonos que caem depois de pisados.
-- Pisada e eliminação são verificadas no servidor (raycast dos pés e altura), não por Touched.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Sfx = require(ReplicatedStorage.Shared.Util.Sfx)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Settings = Config.NeonCollapse
local MAP_NAME = "NeonCollapse"

-- Um hexágono = 3 retângulos (lado x largura entre faces planas) girados 0°, 60° e 120°.
local function hexParts(hex: Model, center: Vector3, radius: number, height: number, color: Color3, neon: boolean)
	for i = 0, 2 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Reflectance = if neon then 0 else 0.15
		p.CanCollide = not neon
		p.CastShadow = false -- 1.152 peças na arena: sombra delas pesa muito no celular
		p.Color = color
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = Vector3.new(radius, height, radius * math.sqrt(3))
		p.CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(60 * i), 0)
		p.Parent = hex
	end
end

-- Hexágono com borda neon: um hexágono neon um pouco maior e mais fino logo abaixo do topo.
local function makeHex(center: Vector3, color: Color3, parent: Instance): Model
	local hex = Instance.new("Model")
	hex.Name = "Hex"
	local r = Settings.HexRadius - Settings.HexGap
	hexParts(hex, center, r, Settings.HexHeight, color, false)
	local rimHeight = 0.35
	hexParts(hex, center + Vector3.new(0, Settings.HexHeight / 2 - rimHeight / 2 - 0.03, 0), r + Settings.HexRim, rimHeight, color:Lerp(Color3.new(1, 1, 1), 0.15):Lerp(Color3.new(0, 0, 0), Settings.NeonDim), true)
	hex.Parent = parent
	return hex
end

-- Anel neon flutuando em volta da arena (estádio espacial).
local function ring(parent: Instance, center: Vector3, radius: number, color: Color3)
	local segments = 32
	for i = 0, segments - 1 do
		local a0 = 2 * math.pi * i / segments
		local a1 = 2 * math.pi * (i + 1) / segments
		local p0 = center + Vector3.new(math.cos(a0) * radius, 0, math.sin(a0) * radius)
		local p1 = center + Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius)
		local p = Instance.new("Part")
		p.Name = "Ring"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color:Lerp(Color3.new(0, 0, 0), Settings.NeonDim)
		p.Size = Vector3.new(0.8, 0.8, (p1 - p0).Magnitude + 0.2)
		p.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		p.Parent = parent
	end
end

local function buildMap(): Model
	local map = Instance.new("Model")
	map.Name = MAP_NAME
	local floorsFolder = Instance.new("Folder")
	floorsFolder.Name = "Floors"
	floorsFolder.Parent = map

	local r = Settings.HexRadius
	local n = Settings.GridSize
	-- Grade de hexágonos com ponta no eixo X: colunas a 1,5r, linhas a √3·r, colunas ímpares deslocadas.
	local width = (n - 1) * 1.5 * r
	local depth = (n - 0.5) * math.sqrt(3) * r
	for floor = 1, Settings.Floors do
		local folder = Instance.new("Folder")
		folder.Name = "Floor" .. floor
		folder.Parent = floorsFolder
		local y = Settings.ArenaOrigin.Y - (floor - 1) * Settings.FloorSpacing
		local color = Settings.FloorColors[(floor - 1) % #Settings.FloorColors + 1]
		for col = 0, n - 1 do
			for row = 0, n - 1 do
				local x = col * 1.5 * r - width / 2
				local z = row * math.sqrt(3) * r + (col % 2) * math.sqrt(3) * r / 2 - depth / 2
				makeHex(Vector3.new(Settings.ArenaOrigin.X + x, y, Settings.ArenaOrigin.Z + z), color, folder)
			end
		end
	end

	local lowestY = Settings.ArenaOrigin.Y - (Settings.Floors - 1) * Settings.FloorSpacing
	local goo = Instance.new("Part")
	goo.Name = "Goo"
	goo.Anchored = true
	goo.CanCollide = false
	goo.CastShadow = false
	goo.Material = Enum.Material.Neon
	goo.Color = Settings.GooColor
	goo.Transparency = 0.3
	-- só embaixo da arena; quem cai fora dela também é eliminado pela altura
	goo.Size = Vector3.new(width + 34, 1, depth + 30)
	goo.Position = Vector3.new(Settings.ArenaOrigin.X, lowestY - Settings.GooDepth, Settings.ArenaOrigin.Z)
	goo.Parent = map
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	bubbles.Color = ColorSequence.new(Settings.GooColor)
	bubbles.LightEmission = 1
	bubbles.Rate = 40
	bubbles.Lifetime = NumberRange.new(1.5, 2.5)
	bubbles.Speed = NumberRange.new(3, 6)
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.2) })
	bubbles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Parent = goo

	local center = Vector3.new(Settings.ArenaOrigin.X, 0, Settings.ArenaOrigin.Z)
	local ringRadius = math.max(width, depth) / 2 + 14
	ring(map, center + Vector3.new(0, Settings.ArenaOrigin.Y - 3, 0), ringRadius, Color3.fromHex("FF3D8B"))
	ring(map, center + Vector3.new(0, lowestY - 3, 0), ringRadius + 4, Color3.fromHex("1FB6FF"))

	map.PrimaryPart = goo
	return map
end

-- Cápsulas de vidro (estilo Sky Wars): uma por vaga, espalhadas em círculo no andar de cima.
-- Seguram o jogador enquanto o andar carrega no cliente e quebram quando a partida começa.
local function pickCageHexes(topHexes: { Instance }): { Model }
	local center = Settings.ArenaOrigin
	local farthest = 0
	for _, hex in topHexes do
		local p = (hex :: Model):GetPivot().Position
		farthest = math.max(farthest, Vector3.new(p.X - center.X, 0, p.Z - center.Z).Magnitude)
	end
	local chosen: { Model } = {}
	local used: { [Instance]: boolean } = {}
	for k = 1, Settings.Cages do
		local angle = 2 * math.pi * k / Settings.Cages
		local target = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * farthest * Settings.CageRingRatio
		local best: Model? = nil
		local bestDistance = math.huge
		for _, hex in topHexes do
			if not used[hex] then
				local p = (hex :: Model):GetPivot().Position
				local distance = Vector3.new(p.X - target.X, 0, p.Z - target.Z).Magnitude
				if distance < bestDistance then
					best, bestDistance = hex :: Model, distance
				end
			end
		end
		if best then
			used[best] = true
			table.insert(chosen, best)
		end
	end
	return chosen
end

local function glassPart(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CastShadow = false
	p.Material = Enum.Material.Glass
	p.Color = Settings.CageColor
	p.Transparency = Settings.CageTransparency
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- Cápsula em cima do hexágono: chão e teto de vidro, aros e colunas neon nos cantos. Sem paredes laterais:
-- a vista fica livre na contagem e ninguém escapa, porque o servidor prende a raiz do jogador até o start.
-- Retorna onde o jogador fica.
local function buildCage(hex: Model, parent: Instance): CFrame
	local cage = Instance.new("Model")
	cage.Name = "Cage"
	local floorY = hex:GetPivot().Position.Y + Settings.HexHeight / 2 + Settings.CageLift
	local base = CFrame.new(hex:GetPivot().Position.X, floorY, hex:GetPivot().Position.Z)
	local w, h, t = Settings.CageWidth, Settings.CageHeight, 0.4
	glassPart("Floor", Vector3.new(w, t, w), base * CFrame.new(0, -t / 2, 0), cage)
	glassPart("Roof", Vector3.new(w, t, w), base * CFrame.new(0, h + t / 2, 0), cage)
	for _, corner in { Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) } do
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Anchored = true
		post.CanCollide = false
		post.CanQuery = false
		post.CastShadow = false
		post.Material = Enum.Material.Neon
		post.Color = Settings.CageRimColor
		post.Transparency = 0.5 -- fina e translúcida: não tapa a câmera de quem está dentro
		post.Size = Vector3.new(0.15, h, 0.15)
		post.CFrame = base * CFrame.new(corner.X * w / 2, h / 2, corner.Y * w / 2)
		post.Parent = cage
	end
	for _, y in { 0, h } do
		local rim = Instance.new("Part")
		rim.Name = "Rim"
		rim.Anchored = true
		rim.CanCollide = false
		rim.CanQuery = false
		rim.CastShadow = false
		rim.Material = Enum.Material.Neon
		rim.Color = Settings.CageRimColor
		rim.Size = Vector3.new(w + 0.3, 0.3, w + 0.3)
		rim.Transparency = 0.2
		rim.CFrame = base * CFrame.new(0, y, 0)
		rim.Parent = cage
	end
	cage.Parent = parent
	return base -- topo do chão da cápsula; cada jogador é posto em pé conforme a altura do próprio avatar
end

-- Quebra as cápsulas: vidro some com estilhaços e o jogador cai no hexágono logo abaixo.
local function breakCages(cages: Folder)
	for _, cage in cages:GetChildren() do
		local floor = cage:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			Sfx.playAt("HexCrack", floor)
			local shards = Instance.new("ParticleEmitter")
			shards.Color = ColorSequence.new(Settings.CageColor)
			shards.LightEmission = 0.6
			shards.Lifetime = NumberRange.new(0.6, 1.2)
			shards.Speed = NumberRange.new(10, 18)
			shards.SpreadAngle = Vector2.new(180, 180)
			shards.Acceleration = Vector3.new(0, -40, 0)
			shards.Size = NumberSequence.new(0.35, 0)
			shards.Rotation = NumberRange.new(0, 360)
			shards.RotSpeed = NumberRange.new(-400, 400)
			shards.Parent = floor
			shards:Emit(40)
		end
		for _, p in cage:GetChildren() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.Transparency = 1
			end
		end
	end
	task.delay(1.5, function()
		cages:Destroy()
	end)
end

local function getMapTemplate(): Model
	local maps = ServerStorage:FindFirstChild("Maps")
	if not maps then
		maps = Instance.new("Folder")
		maps.Name = "Maps"
		maps.Parent = ServerStorage
	end
	local template = maps:FindFirstChild(MAP_NAME)
	if not template then
		template = buildMap()
		template.Parent = maps
	end
	return template :: Model
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function eliminate(ctx: Types.RoundContext, player: Player)
	ctx.alive[player] = nil
	local root = rootOf(player)
	if root then
		Sfx.playAt("Fall", root)
	end
	ctx.eliminatedAt[player] = ctx.eliminatedAt[player] or workspace:GetServerTimeNow()
	player:SetAttribute("HyperShowParticipant", nil)
	local character = ctx.characters[player]
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and player.Character == character then
		humanoid.Health = 0
	end
end

local function dropHex(hex: Model, fallDelay: number)
	local first = hex:FindFirstChildWhichIsA("BasePart")
	if first then
		Sfx.playAt("HexCrack", first)
	end
	for _, p in hex:GetChildren() do
		if p:IsA("BasePart") then
			p.Material = Enum.Material.Neon
			p.Color = Settings.WarningColor
		end
	end
	task.delay(fallDelay, function()
		if not hex.Parent then
			return
		end
		for _, p in hex:GetChildren() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.Anchored = false
			end
		end
		task.delay(2, function()
			hex:Destroy()
		end)
	end)
end

local NeonCollapse: Types.MinigameDef = {
	id = "NeonCollapse",
	displayName = "Desmoronamento Neon",
	instruction = "NÃO CAIA!",
	category = "Survival",
	minPlayers = 1,
	duration = Settings.Duration,
	mapName = MAP_NAME,

	setup = function(ctx)
		local map = getMapTemplate():Clone()
		map.Parent = workspace
		ctx.map = map

		-- Cada jogador começa numa cápsula de vidro em cima do andar de cima (vagas sorteadas).
		local topHexes = ((map:FindFirstChild("Floors") :: Folder):FindFirstChild("Floor1") :: Folder):GetChildren()
		local cages = Instance.new("Folder")
		cages.Name = "Cages"
		cages.Parent = map
		local spots: { CFrame } = {}
		for _, hex in pickCageHexes(topHexes) do
			table.insert(spots, buildCage(hex, cages))
		end
		for i = #spots, 2, -1 do
			local j = math.random(1, i)
			spots[i], spots[j] = spots[j], spots[i]
		end
		assert(#spots > 0 and #ctx.players <= #spots, "Vagas insuficientes na arena")
		local pending = #ctx.players
		local accepting = true
		local prepared: { [Player]: boolean } = {}
		-- raízes presas dentro das cápsulas até o vidro quebrar (o servidor solta no start)
		local held: { BasePart } = {}
		ctx.cleanupTasks[#ctx.cleanupTasks + 1] = function()
			for _, root in held do
				if root.Parent then
					root.Anchored = false
				end
			end
		end
		for i, player in ctx.players do
			local spot = spots[i]
			local character = player.Character
			task.spawn(function()
				local ok, err = pcall(function()
					player:RequestStreamAroundAsync(spot.Position, Settings.StreamTimeout)
					if not accepting or ctx.cancelled or not map.Parent or player.Parent ~= game:GetService("Players")
						or not character or player.Character ~= character or not character.Parent then return end
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					local root = character:FindFirstChild("HumanoidRootPart")
					if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return end
					-- pés no chão da cápsula, seja qual for a altura do avatar (avatares altos ficavam com os pés
					-- abaixo do vidro e a física os empurrava para fora); a raiz fica presa até o vidro quebrar
					root.Anchored = true
					table.insert(held, root)
					character:PivotTo(spot * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.05, 0))
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
					ctx.characters[player] = character
					prepared[player] = true
				end)
				if not ok then warn("[NeonCollapse] preparação: " .. tostring(err)) end
				pending -= 1
			end)
		end
		local deadline = os.clock() + Settings.StreamTimeout + 2
		while pending > 0 and os.clock() < deadline and not ctx.cancelled do task.wait(0.05) end
		accepting = false -- tarefas atrasadas nunca teleportam na próxima rodada
		local ready = {}
		table.clear(ctx.alive)
		for _, player in ctx.players do
			if prepared[player] and player.Parent == game:GetService("Players") and player.Character == ctx.characters[player] then
				table.insert(ready, player)
				ctx.alive[player] = true
			end
		end
		ctx.players = ready
	end,

	start = function(ctx)
		local map = ctx.map :: Model
		-- solta quem estava preso na cápsula e quebra o vidro: todos caem juntos no andar de cima
		for _, player in ctx.players do
			local character = ctx.characters[player]
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.Anchored = false
			end
		end
		local cages = map:FindFirstChild("Cages")
		if cages and cages:IsA("Folder") then
			breakCages(cages)
		end
		local goo = map:FindFirstChild("Goo") :: BasePart
		local gooTop = goo.Position.Y + goo.Size.Y / 2
		local startedWith = #ctx.players
		local triggered: { [Model]: boolean } = {}
		-- modo furioso: hexágonos caem mais rápido (Config.Mood.Furious.FallDelayMultiplier por intensidade)
		local fallDelay = Settings.FallDelay * (Config.Mood.Furious.FallDelayMultiplier[ctx.difficulty] or 1)

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { map:FindFirstChild("Floors") :: Folder }

		-- acontecimentos do show para a plateia (AudienceController): primeiro desmoronamento e poucos vivos
		local showEvent = Remotes.get("ShowEvent")
		local firstDrop, fewAnnounced = false, false
		local airborne: { [Player]: number } = {}
		local elapsed = 0
		local conn = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed < Settings.FootCheckInterval then
				return
			end
			local sampleTime = elapsed
			elapsed = 0
			if ctx.cancelled then return end

			local aliveCount = 0
			for _, player in ctx.players do
				if not ctx.alive[player] then
					continue
				end
				local root = rootOf(player)
				if player.Character ~= ctx.characters[player] or not root or root.Position.Y < gooTop + 1 then
					eliminate(ctx, player)
					continue
				end
				local result = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
				local offset = root.Position - Settings.ArenaOrigin
				local outside = math.abs(offset.X) > goo.Size.X / 2 + Settings.BoundaryMargin
					or math.abs(offset.Z) > goo.Size.Z / 2 + Settings.BoundaryMargin
					or offset.Y > Settings.MaxAboveArena
				airborne[player] = if result then 0 else (airborne[player] or 0) + sampleTime
				if outside or airborne[player] > Settings.MaxAirTime then
					warn("[NeonCollapse] posição/tempo no ar inválido: " .. player.Name)
					eliminate(ctx, player) -- somente esta rodada; nunca aplica ban
					continue
				end
				aliveCount += 1
				local hex = result and result.Instance.Parent
				if hex and hex:IsA("Model") and not triggered[hex] then
					triggered[hex] = true
					if not firstDrop then
						firstDrop = true
						showEvent:FireAllClients("FirstCollapse")
					end
					dropHex(hex, fallDelay)
				end
			end

			if not fewAnnounced and startedWith >= 4 and aliveCount >= 2 and aliveCount <= 3 then
				fewAnnounced = true
				showEvent:FireAllClients("FewLeft")
			end
			if startedWith >= 2 and aliveCount <= 1 then
				ctx.finish()
			end
		end)
		table.insert(ctx.cleanupTasks, function()
			conn:Disconnect()
		end)
	end,

	getWinners = function(ctx)
		local winners = {}
		for _, player in ctx.players do
			if ctx.alive[player] and player.Parent == game:GetService("Players") and player.Character == ctx.characters[player] then
				table.insert(winners, player)
			end
		end
		return winners
	end,

	cleanup = function(_ctx)
		-- O mapa é destruído pelo RoundService (ctx.map); a conexão sai em cleanupTasks.
	end,
}

return NeonCollapse
