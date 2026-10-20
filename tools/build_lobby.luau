--!strict
-- Monta o lobby do HyperShow seguindo a planta de referência (palco largo, plataforma do Hyper, roleta e pódio
-- em bases próprias, arco de anéis, medidor, logo, colunas, telões e plateia com 12 spawns), com céu de nebulosa,
-- planetas e asteroides. O tema furioso (vermelho) é aplicado pelo StageService recolorindo estas peças.
-- Rodar no Studio (modo Edit): python tools/studio.py run tools/build_lobby.luau
-- e depois tools/build_audience.luau e tools/build_social.luau (arquibancadas e área social ficam dentro do Lobby).
-- Pode rodar de novo: apaga e recria Lobby, Podium e Space (e remove a Baseplate).

local Lighting = game:GetService("Lighting")

local PURPLE = Color3.fromHex("5B2BD6")
local DEEP = Color3.fromHex("4A1A7E")
local PINK = Color3.fromHex("FF3D8B")
local MAGENTA = Color3.fromHex("D43DFF")
local GOLD = Color3.fromHex("FFC83D")
local CYAN = Color3.fromHex("1FB6FF")
local BLUE = Color3.fromHex("2F5BFF")
local GRAPHITE = Color3.fromHex("1B1730")
local FLOOR = Color3.fromHex("24104F")

local WHEEL_IMAGE = "rbxassetid://103052250003063" -- arte/cenario/roleta.png (tools/make_wheel.py): fatias = Config.Wheel.Slices
local LOGO_IMAGE = "rbxassetid://113660197791956"
-- arte/cenario/medidor_esq.png e medidor_dir.png (tools/make_meter.py): o medidor em 2048 px, em duas metades
local METER_LEFT_IMAGE = "rbxassetid://111739185780214" -- arte/cenario/medidor_neon_esq.png (tools/make_meter_neon.py)
local METER_RIGHT_IMAGE = "rbxassetid://94937983258169" -- arte/cenario/medidor_neon_dir.png
local METER_GLASS_IMAGE = "rbxassetid://77626325982159" -- arte/cenario/medidor_vidro.png (= Config.Mood.Cutscene.GlassImage)

-- Hyper fica no centro da plataforma redonda do palco (tools/build_hyper.luau usa os mesmos pés)
local HYPER_FEET = Vector3.new(0, 8, -39)

for _, name in { "Lobby", "Podium", "Space", "Baseplate", "SpawnLocation" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- Iluminação espacial --------------------------------------------
-- Horário de dia: à noite o Roblox escurece a skybox. O sol fica escondido (CelestialBodiesShown).
Lighting.ClockTime = 14
Lighting.Brightness = 1.5
Lighting.Ambient = Color3.fromRGB(120, 90, 170)
Lighting.OutdoorAmbient = Color3.fromRGB(170, 120, 200)
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.6
-- DepthOfField e SunRays vêm do modelo Baseplate: pesam e não servem aqui (o sol fica escondido)
for _, cls in { "Sky", "Atmosphere", "BloomEffect", "ColorCorrectionEffect", "DepthOfFieldEffect", "SunRaysEffect" } do
	for _, child in Lighting:GetChildren() do
		if child.ClassName == cls then
			child:Destroy()
		end
	end
end
-- Skybox de nebulosa sem emendas: "Purple Nebula Space Skybox" (Creator Store, grátis, asset 83555979203508,
-- autor Zalthen, feita com Spacescape). No modo furioso o StageService a deixa vermelha com névoa
-- (Config.Mood.FuriousTheme.Atmosphere).
local sky = Instance.new("Sky")
sky.SkyboxFt = "rbxassetid://104400530594543"
sky.SkyboxBk = "rbxassetid://129876530632297"
sky.SkyboxLf = "rbxassetid://73372229972523"
sky.SkyboxRt = "rbxassetid://87408857415924"
sky.SkyboxUp = "rbxassetid://137817405681365"
sky.SkyboxDn = "rbxassetid://108406529909981"
sky.StarCount = 0
sky.CelestialBodiesShown = false
sky.Parent = Lighting
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.1
atmosphere.Offset = 0
atmosphere.Color = Color3.fromRGB(110, 60, 190)
atmosphere.Decay = Color3.fromRGB(60, 20, 110)
atmosphere.Glare = 0
atmosphere.Haze = 0
atmosphere.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.35
bloom.Size = 20
bloom.Threshold = 1.6
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.05
cc.Contrast = 0.08
cc.Parent = Lighting

-- Utilitários ------------------------------------------------------------
local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "ClassName" then
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- Neon um pouco mais escuro que a cor da paleta, para não estourar o brilho.
local NEON_DIM = 0.35

local function neon(props: { [string]: any }, parent: Instance): BasePart
	props.Material = Enum.Material.Neon
	props.Color = (props.Color :: Color3):Lerp(Color3.new(0, 0, 0), NEON_DIM)
	props.Transparency = props.Transparency or 0.1
	props.CanCollide = false
	props.CastShadow = false
	return part(props, parent)
end

-- CFrame olhando para +Z (a face Front da Part fica virada para o lobby).
local function facing(position: Vector3, yaw: number?): CFrame
	return CFrame.lookAt(position, position + Vector3.zAxis) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

-- Cilindro deitado no chão (eixo X da Part apontando para cima).
local function disc(center: Vector3): CFrame
	return CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
end

-- Cilindro em pé virado para +Z (disco vertical, como a roleta e o portal).
local function wallDisc(center: Vector3): CFrame
	return CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0)
end

-- Barra reta de `a` até `b` (comprimento no eixo Z da Part).
local function bar(name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, parent: Instance, props: { [string]: any }?): BasePart
	local p: { [string]: any } = props or {}
	p.Name = name
	p.Size = Vector3.new(thickness, thickness, (b - a).Magnitude)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Color = color
	return neon(p, parent)
end

local function textLabel(props: { [string]: any }, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	for k, v in props do
		(label :: any)[k] = v
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = GRAPHITE
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function surfaceGui(target: BasePart, pixelsPerStud: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0
	gui.Parent = target
	return gui
end

local function imageOn(target: BasePart, image: string, pixelsPerStud: number): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = image
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = surfaceGui(target, pixelsPerStud)
	return img
end

-- Neon emoldurando uma Part retangular virada para +Z.
local function frameNeon(target: BasePart, color: Color3, thickness: number, parent: Instance)
	local s = target.Size
	local cf = target.CFrame
	local t = thickness
	for _, edge in {
		{ Vector3.new(0, s.Y / 2, -s.Z / 2 - 0.1), Vector3.new(s.X + t, t, t) },
		{ Vector3.new(0, -s.Y / 2, -s.Z / 2 - 0.1), Vector3.new(s.X + t, t, t) },
		{ Vector3.new(s.X / 2, 0, -s.Z / 2 - 0.1), Vector3.new(t, s.Y + t, t) },
		{ Vector3.new(-s.X / 2, 0, -s.Z / 2 - 0.1), Vector3.new(t, s.Y + t, t) },
	} do
		neon({ Name = "Trim", Size = edge[2], CFrame = cf * CFrame.new(edge[1]), Color = color }, parent)
	end
end

-- Arco de neon (meia-volta) no plano XY, centrado em `center`.
local function arch(center: Vector3, radius: number, color: Color3, thickness: number, parent: Instance, name: string?)
	-- tubos redondos e curtos: de perto o arco parece liso, sem quinas
	local segments = math.clamp(math.floor(radius * 2.4), 24, 72)
	for i = 0, segments - 1 do
		local a0 = math.pi * i / segments
		local a1 = math.pi * (i + 1) / segments
		local p0 = center + Vector3.new(math.cos(a0) * radius, math.sin(a0) * radius, 0)
		local p1 = center + Vector3.new(math.cos(a1) * radius, math.sin(a1) * radius, 0)
		neon({
			Name = name or "Arch",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new((p1 - p0).Magnitude + thickness * 0.5, thickness, thickness),
			CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.rad(90), 0),
			Color = color,
		}, parent)
	end
end

-- Anel de neon deitado no chão (plano XZ).
local function floorRing(center: Vector3, radius: number, color: Color3, thickness: number, parent: Instance, name: string)
	local segments = 36
	for i = 0, segments - 1 do
		local a0 = 2 * math.pi * i / segments
		local a1 = 2 * math.pi * (i + 1) / segments
		local p0 = center + Vector3.new(math.cos(a0) * radius, 0, math.sin(a0) * radius)
		local p1 = center + Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius)
		local dir = (p1 - p0).Unit
		local b = bar(name, p0 - dir * 0.1, p1 + dir * 0.1, thickness, color, parent)
		b.Size = Vector3.new(thickness, 0.12, b.Size.Z)
	end
end

-- Brilho de quatro pontas (duas lâminas finas cruzadas) para enfeitar o cenário.
local function sparkle(at: Vector3, size: number, color: Color3, parent: Instance)
	for _, rot in { 0, 90 } do
		neon({
			Name = "Sparkle",
			Size = Vector3.new(size * 0.22, size, 0.2),
			CFrame = facing(at) * CFrame.Angles(0, 0, math.rad(rot)),
			Color = color,
			Transparency = 0,
		}, parent)
	end
	neon({ Name = "Sparkle", Size = Vector3.new(size * 0.35, size * 0.35, 0.25), CFrame = facing(at) * CFrame.Angles(0, 0, math.rad(45)), Color = color, Transparency = 0 }, parent)
end

-- Planta (referência do lobby): plateia na frente (+Z), palco retangular largo ao fundo (-Z).
-- Palco 104 x 34 x 5 (z -55 a -21), escadaria central de 5 degraus e escadas laterais; no centro do palco a
-- plataforma redonda do Hyper (32 de diâmetro, 2 mais alta); pódio à esquerda e roleta à direita, cada um na
-- própria base sobre o palco e mais baixos que o Hyper; arco de anéis, medidor e logo atrás; telões nas pontas.
local STAGE_TOP = 6
local STAGE_FRONT = -21
local STAGE_BACK = -55
local STAGE_Z = (STAGE_FRONT + STAGE_BACK) / 2
local DAIS_CENTER = Vector3.new(0, STAGE_TOP, -39)
local DAIS_TOP = STAGE_TOP + 2

local lobby = Instance.new("Model")
lobby.Name = "Lobby"
lobby.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- sempre no cliente (efeitos do LobbyFxController)
lobby.Parent = workspace

local function group(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = lobby
	return m
end

-- Piso e plateia -----------------------------------------------------------------
local mainFloor = group("MainFloor")
-- piso de 136 x 130: as laterais abrigam as arquibancadas (tools/build_audience.luau) e a frente (z 45 a 75)
-- a área de serviços e o mirante (tools/build_social.luau)
part({ Name = "Floor", Size = Vector3.new(136, 1, 130), Position = Vector3.new(0, 0.5, 10), Color = FLOOR, Reflectance = 0.12 }, lobby)
part({ Name = "Underside", Size = Vector3.new(132, 6, 126), Position = Vector3.new(0, -3, 10), Color = GRAPHITE }, mainFloor)
for _, e in {
	{ Vector3.new(0, 1.05, -55), Vector3.new(136, 0.2, 0.8) },
	{ Vector3.new(-68, 1.05, 10), Vector3.new(0.8, 0.2, 130) },
	{ Vector3.new(68, 1.05, 10), Vector3.new(0.8, 0.2, 130) },
} do
	neon({ Name = "FloorTrim", Size = e[2], Position = e[1], Color = GOLD }, mainFloor)
end
-- piso geométrico: quadrados roxos e azuis alternados com linhas neon entre eles (área da plateia)
for col = 0, 6 do
	for row = 0, 4 do
		if (col + row) % 2 == 0 then
			part({
				Name = "FloorTile",
				Size = Vector3.new(15.6, 0.1, 11.6),
				Position = Vector3.new(-48 + col * 16, 1.04, -4 + row * 12),
				Color = Color3.fromHex("2B1A6E"),
				Reflectance = 0.15,
				CanCollide = false,
				CastShadow = false,
			}, mainFloor)
		end
	end
end
for i = 0, 7 do
	local x = -56 + i * 16
	local line = bar("FloorLine", Vector3.new(x, 1.06, -10), Vector3.new(x, 1.06, 44), 0.3, if i % 2 == 0 then PINK else CYAN, mainFloor, { Transparency = 0.25 })
	line.Size = Vector3.new(0.3, 0.1, line.Size.Z)
end
for j = 0, 5 do
	local z = -10 + j * 12
	local line = bar("FloorLine", Vector3.new(-56, 1.06, z), Vector3.new(56, 1.06, z), 0.3, if j % 2 == 0 then CYAN else PINK, mainFloor, { Transparency = 0.25 })
	line.Size = Vector3.new(0.3, 0.1, line.Size.Z)
end

-- grades de vidro com corrimão de neon
local railings = group("Railings")
local function rail(a: Vector3, b: Vector3, name: string?)
	local n = name or "Rail"
	local length = (b - a).Magnitude
	local dir = (b - a).Unit
	local posts = math.max(1, math.floor(length / 8))
	for i = 0, posts do
		local p = a + dir * (length * i / posts)
		part({ Name = n, Size = Vector3.new(0.6, 3.6, 0.6), Position = p + Vector3.new(0, 1.8, 0), Color = Color3.fromHex("8C88A8"), Material = Enum.Material.Metal, CastShadow = false }, railings)
	end
	part({
		Name = n,
		Size = Vector3.new(0.2, 2.6, length),
		CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 1.5, 0), b + Vector3.new(0, 1.5, 0)),
		Color = MAGENTA,
		Material = Enum.Material.Glass,
		Transparency = 0.6,
		CastShadow = false,
	}, railings)
	bar(n .. "Light", a + Vector3.new(0, 3.6, 0), b + Vector3.new(0, 3.6, 0), 0.45, GOLD, railings)
end
-- laterais até a frente; a borda da frente é o mirante (tools/build_social.luau)
rail(Vector3.new(-67.5, 1, 74.5), Vector3.new(-67.5, 1, -54.5))
rail(Vector3.new(67.5, 1, 74.5), Vector3.new(67.5, 1, -54.5))

-- 12 spawns em 3 fileiras de 4, virados para o palco (o PushService não deixa empurrar em cima deles)
local spawns = Instance.new("Folder")
spawns.Name = "Spawns"
spawns.Parent = lobby
for row = 0, 2 do
	for col = 0, 3 do
		local position = Vector3.new(-24 + col * 16, 1.2, 4 + row * 12)
		part({
			ClassName = "SpawnLocation",
			Name = "LobbySpawn",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 5, 5),
			CFrame = CFrame.lookAt(position, position - Vector3.zAxis) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromHex("9A2E8F"),
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			Duration = 0,
		}, spawns)
		floorRing(position - Vector3.new(0, 0.12, 0), 2.9, CYAN, 0.2, mainFloor, "SpawnRing")
	end
end

-- Palco principal ------------------------------------------------------------------
local mainStage = group("MainStage")
part({ Name = "Stage", Size = Vector3.new(104, STAGE_TOP - 1, STAGE_FRONT - STAGE_BACK), Position = Vector3.new(0, 1 + (STAGE_TOP - 1) / 2, STAGE_Z), Color = Color3.fromHex("2A1458"), Reflectance = 0.08 }, lobby)
-- frente em camadas: faixas neon azul e rosa e borda dourada no alto
for _, band in { { y = 2.2, c = BLUE }, { y = 3.9, c = PINK } } do
	neon({ Name = "StageTrim", Size = Vector3.new(104, 0.35, 0.3), Position = Vector3.new(0, band.y, STAGE_FRONT + 0.1), Color = band.c }, mainStage)
end
neon({ Name = "StageTrim", Size = Vector3.new(104.4, 0.3, 0.5), Position = Vector3.new(0, STAGE_TOP - 0.2, STAGE_FRONT + 0.05), Color = GOLD }, mainStage)
for _, x in { -1, 1 } do
	neon({ Name = "StageTrim", Size = Vector3.new(0.5, 0.3, STAGE_FRONT - STAGE_BACK), Position = Vector3.new(x * 52.05, STAGE_TOP - 0.2, STAGE_Z), Color = GOLD }, mainStage)
	neon({ Name = "StageTrim", Size = Vector3.new(0.3, 0.35, STAGE_FRONT - STAGE_BACK), Position = Vector3.new(x * 52.1, 3, STAGE_Z), Color = PINK }, mainStage)
end

-- Escadaria central (5 degraus de 1 stud, cada um mais estreito) e escadas laterais
local mainStairs = group("MainStairs")
local function stairs(x: number, topWidth: number, widen: number, parent: Instance)
	for k = 1, 5 do
		local front = STAGE_FRONT + 2 * (6 - k)
		local depth = front - STAGE_FRONT
		local width = topWidth + (5 - k) * widen
		part({ Name = "Step", Size = Vector3.new(width, k, depth), Position = Vector3.new(x, 1 + k / 2, STAGE_FRONT + depth / 2), Color = Color3.fromHex("231048") }, parent)
		neon({ Name = "StepLight", Size = Vector3.new(width, 0.2, 0.25), Position = Vector3.new(x, 1 + k - 0.2, front + 0.08), Color = if k % 2 == 0 then PINK else BLUE }, parent)
	end
end
stairs(0, 24, 2, mainStairs)
local sideStairs = group("SideStairs")
stairs(-44, 10, 0, sideStairs)
stairs(44, 10, 0, sideStairs)
-- corrimãos nas pontas do palco e ao lado das escadas laterais
rail(Vector3.new(-52, STAGE_TOP, STAGE_BACK), Vector3.new(-52, STAGE_TOP, STAGE_FRONT), "StageRail")
rail(Vector3.new(52, STAGE_TOP, STAGE_BACK), Vector3.new(52, STAGE_TOP, STAGE_FRONT), "StageRail")
for _, x in { -1, 1 } do
	rail(Vector3.new(x * 52, STAGE_TOP, STAGE_FRONT), Vector3.new(x * 49.4, STAGE_TOP, STAGE_FRONT), "StageRail")
	rail(Vector3.new(x * 38.6, STAGE_TOP, STAGE_FRONT), Vector3.new(x * 30, STAGE_TOP, STAGE_FRONT), "StageRail")
end

-- Plataforma redonda do Hyper (32 de diâmetro) com anéis concêntricos
local centerPlatform = group("CenterPlatform")
part({ Name = "Dais", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 32, 32), CFrame = disc(DAIS_CENTER + Vector3.new(0, 1, 0)), Color = Color3.fromHex("2E1670") }, centerPlatform)
-- bordas neon abaixo do topo (superfícies na mesma altura piscam: z-fighting)
neon({ Name = "DaisRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 32.6, 32.6), CFrame = disc(DAIS_CENTER + Vector3.new(0, 1.65, 0)), Color = CYAN }, centerPlatform)
neon({ Name = "DaisRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 32.6, 32.6), CFrame = disc(DAIS_CENTER + Vector3.new(0, 0.6, 0)), Color = PINK }, centerPlatform)
for i, ring in { { r = 4.5, c = CYAN }, { r = 8.5, c = MAGENTA }, { r = 12.5, c = BLUE }, { r = 15.2, c = PINK } } do
	floorRing(Vector3.new(DAIS_CENTER.X, DAIS_TOP + 0.03, DAIS_CENTER.Z), ring.r, ring.c, 0.35 + i * 0.05, centerPlatform, "DaisRing")
end
-- paredes invisíveis: a plataforma é só do Hyper e ninguém passa por trás do medidor
part({ Name = "PlatformBarrier", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 33, 33), CFrame = disc(DAIS_CENTER + Vector3.new(0, 7, 0)), Transparency = 1, CanQuery = false, CastShadow = false }, centerPlatform)
part({ Name = "BackBarrier", Size = Vector3.new(48, 30, 6), Position = Vector3.new(0, STAGE_TOP + 15, -53), Transparency = 1, CanQuery = false, CastShadow = false }, centerPlatform)

-- Arco de anéis e medidor atrás do Hyper --------------------------------------
-- O medidor de paciência é o painel semicircular colorido da referência. O MeterController (cliente) gira o
-- Pointer em volta do Pivot; o Glass vira vidro quebrado na cena de raiva. O miolo escuro vira um portal
-- brilhante (atrás do Hyper) e os anéis neon contornam o painel por fora.
local METER_RADIUS = 16
local meterHub = Vector3.new(0, DAIS_TOP + 4, -53.4) -- alto o bastante para as carinhas ficarem em volta da cabeça
local neonArch = group("NeonArch")
local HUB_RADIUS = METER_RADIUS * 0.33 -- miolo escuro da arte do medidor
neon({ Name = "PortalGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, HUB_RADIUS * 2, HUB_RADIUS * 2), CFrame = wallDisc(meterHub + Vector3.new(0, 0, 0.6)), Color = MAGENTA, Transparency = 0.3 }, lobby)
for i, ring in { { r = HUB_RADIUS, c = CYAN, t = 0.45 }, { r = HUB_RADIUS - 1, c = PINK, t = 0.4 }, { r = METER_RADIUS + 2.4, c = BLUE, t = 0.55 }, { r = METER_RADIUS + 3.4, c = MAGENTA, t = 0.5 } } do
	arch(meterHub + Vector3.new(0, 0, 0.8 + i * 0.05), ring.r, ring.c, ring.t, neonArch, "PortalRing")
end
-- base maciça do palco até a borda de baixo do medidor: os arcos pousam nela e ela esconde a metade de
-- baixo do disco de fundo e do portal (que ficariam aparecendo embaixo do painel)
local baseWidth = (METER_RADIUS + 3.4) * 2 + 1.2
local baseHeight = meterHub.Y - STAGE_TOP
part({ Name = "MeterBase", Size = Vector3.new(baseWidth, baseHeight, 2), Position = Vector3.new(0, STAGE_TOP + baseHeight / 2, meterHub.Z + 1.3), Color = Color3.fromHex("231048") }, neonArch)
neon({ Name = "MeterBaseTrim", Size = Vector3.new(baseWidth + 0.2, 0.35, 0.3), Position = Vector3.new(0, meterHub.Y - 0.25, meterHub.Z + 2.35), Color = GOLD }, neonArch)
neon({ Name = "MeterBaseTrim", Size = Vector3.new(baseWidth + 0.2, 0.3, 0.3), Position = Vector3.new(0, STAGE_TOP + 1.2, meterHub.Z + 2.35), Color = PINK }, neonArch)
local portalLight = Instance.new("PointLight")
portalLight.Color = Color3.fromRGB(255, 80, 200)
portalLight.Brightness = 0.8
portalLight.Range = 10
portalLight.Parent = lobby:FindFirstChild("PortalGlow")

local meter = Instance.new("Model")
meter.Name = "MoodMeter"
meter.Parent = lobby
local function imagePanel(name: string, image: string, z: number): BasePart
	local panel = part({
		Name = name,
		Size = Vector3.new(METER_RADIUS * 2, METER_RADIUS, 0.05),
		CFrame = facing(Vector3.new(meterHub.X, meterHub.Y + METER_RADIUS / 2, z)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, meter)
	imageOn(panel, image, 30).ScaleType = Enum.ScaleType.Stretch
	return panel
end
part({ Name = "Backing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, METER_RADIUS * 2 + 2, METER_RADIUS * 2 + 2), CFrame = wallDisc(meterHub + Vector3.new(0, 0, -0.6)), Color = GRAPHITE }, meter)
-- Dial: centro do mostrador (a câmera das cenas mira nele); as duas metades levam a imagem em 2048 px
part({ Name = "Dial", Size = Vector3.new(METER_RADIUS * 2, METER_RADIUS, 0.05), CFrame = facing(Vector3.new(meterHub.X, meterHub.Y + METER_RADIUS / 2, meterHub.Z)), Transparency = 1, CanCollide = false, CanQuery = false }, meter)
for _, half in { { name = "DialLeft", image = METER_LEFT_IMAGE, x = -METER_RADIUS / 2 }, { name = "DialRight", image = METER_RIGHT_IMAGE, x = METER_RADIUS / 2 } } do
	local panel = part({
		Name = half.name,
		Size = Vector3.new(METER_RADIUS, METER_RADIUS, 0.05),
		CFrame = facing(Vector3.new(meterHub.X + half.x, meterHub.Y + METER_RADIUS / 2, meterHub.Z)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, meter)
	imageOn(panel, half.image, 60).ScaleType = Enum.ScaleType.Stretch
end
part({ Name = "Pivot", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = facing(meterHub + Vector3.new(0, 0, 0.25)), Transparency = 1, CanCollide = false, CanQuery = false }, meter)
part({
	Name = "Pointer",
	Size = Vector3.new(0.6, METER_RADIUS - 2.5, 0.2),
	CFrame = facing(meterHub + Vector3.new(0, (METER_RADIUS - 2.5) / 2, 0.25)),
	Color = Color3.fromHex("FF2E3D"),
	Material = Enum.Material.Neon,
	CanCollide = false,
	CanQuery = false,
}, meter)
neon({ Name = "Hub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2, 2), CFrame = wallDisc(meterHub + Vector3.new(0, 0, 0.4)), Color = GOLD, Transparency = 0 }, meter)
imagePanel("Glass", METER_GLASS_IMAGE, meterHub.Z + 0.5)
arch(Vector3.new(meterHub.X, meterHub.Y, meterHub.Z + 0.3), METER_RADIUS + 0.4, GOLD, 0.6, meter)
arch(Vector3.new(meterHub.X, meterHub.Y, meterHub.Z + 0.2), METER_RADIUS + 1.3, PINK, 0.5, meter)
for _, x in { -1, 1 } do
	neon({ Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, Position = meterHub + Vector3.new(x * (METER_RADIUS + 0.9), 0.5, 0.4), Color = GOLD, Transparency = 0 }, meter)
end

-- Logo suspenso com coroa e estrelas ----------------------------------------------
local mainLogo = group("MainLogo")
local LOGO_SIZE = Vector2.new(46, 18.8) -- proporção da arte (1024 x 419)
local logoCenter = Vector3.new(0, meterHub.Y + METER_RADIUS + 4 + LOGO_SIZE.Y / 2, -54)
local logo = part({ Name = "Logo", Size = Vector3.new(LOGO_SIZE.X, LOGO_SIZE.Y, 0.4), CFrame = facing(logoCenter), Transparency = 1, CanCollide = false }, lobby)
imageOn(logo, LOGO_IMAGE, 28)
arch(logoCenter + Vector3.new(0, -4, -0.6), 21, PINK, 0.6, mainLogo, "LogoArch")
local crownBase = logoCenter + Vector3.new(0, LOGO_SIZE.Y / 2 + 1.2, -0.6)
neon({ Name = "Crown", Size = Vector3.new(6, 1, 0.6), CFrame = facing(crownBase), Color = GOLD, Transparency = 0 }, mainLogo)
for _, spike in { { x = -2.4, h = 2.3, r = 18 }, { x = 0, h = 3.1, r = 0 }, { x = 2.4, h = 2.3, r = -18 } } do
	neon({
		Name = "Crown",
		Size = Vector3.new(1.1, spike.h, 0.5),
		CFrame = facing(crownBase + Vector3.new(spike.x, spike.h / 2 + 0.4, 0)) * CFrame.Angles(0, 0, math.rad(spike.r)),
		Color = GOLD,
		Transparency = 0,
	}, mainLogo)
	neon({ Name = "Crown", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Position = crownBase + Vector3.new(spike.x * 1.15, spike.h + 0.7, 0), Color = GOLD, Transparency = 0 }, mainLogo)
end
local decorations = group("LobbyDecorations")
for _, s in {
	{ Vector3.new(-25, logoCenter.Y + 7, -54.5), 3, GOLD },
	{ Vector3.new(-18, logoCenter.Y + 12, -54.5), 2, PINK },
	{ Vector3.new(25, logoCenter.Y + 7, -54.5), 2.8, GOLD },
	{ Vector3.new(18, logoCenter.Y + 12, -54.5), 1.8, CYAN },
	{ Vector3.new(-27, logoCenter.Y - 6, -54.5), 2, PINK },
	{ Vector3.new(27, logoCenter.Y - 5, -54.5), 2.2, MAGENTA },
} do
	sparkle(s[1], s[2], s[3], decorations)
end

-- Colunas com tubo de energia (26 de altura no centro, menores nas pontas) ------------
local columns = group("DecorativeColumns")
local function tube(x: number, z: number, height: number)
	local base = Vector3.new(x, STAGE_TOP, z)
	part({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 4, 4), CFrame = disc(base + Vector3.new(0, 0.8, 0)), Color = Color3.fromHex("8C88A8"), Material = Enum.Material.Metal }, columns)
	neon({ Name = "PillarRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 4.2, 4.2), CFrame = disc(base + Vector3.new(0, 1.6, 0)), Color = BLUE }, columns)
	local glassHeight = height - 3.6
	local mid = base + Vector3.new(0, 1.8 + glassHeight / 2, 0)
	part({ Name = "PillarGlass", Shape = Enum.PartType.Cylinder, Size = Vector3.new(glassHeight, 3, 3), CFrame = disc(mid), Color = Color3.fromHex("B9A6FF"), Material = Enum.Material.Glass, Transparency = 0.8, CastShadow = false }, columns)
	local core = neon({ Name = "PillarLight", Shape = Enum.PartType.Cylinder, Size = Vector3.new(glassHeight, 2.1, 2.1), CFrame = disc(mid), Color = MAGENTA, Transparency = 0 }, columns)
	for _, f in { 0.33, 0.66 } do
		neon({ Name = "PillarRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.15, 3.15), CFrame = disc(base + Vector3.new(0, 1.8 + glassHeight * f, 0)), Color = PINK }, columns)
	end
	local vapor = Instance.new("ParticleEmitter")
	vapor.Name = "Vapor"
	vapor.Color = ColorSequence.new(Color3.fromRGB(255, 200, 255), Color3.fromRGB(150, 110, 255))
	vapor.LightEmission = 1
	vapor.Rate = 4
	vapor.Lifetime = NumberRange.new(2, 3.5)
	vapor.Speed = NumberRange.new(2, 4)
	vapor.SpreadAngle = Vector2.new(4, 4)
	vapor.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.05) })
	vapor.Transparency = NumberSequence.new(0.2, 1)
	vapor.EmissionDirection = Enum.NormalId.Right -- eixo X do cilindro = para cima
	vapor.Parent = core
	part({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 4, 4), CFrame = disc(base + Vector3.new(0, height - 0.8, 0)), Color = GRAPHITE }, columns)
	neon({ Name = "PillarRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 4.2, 4.2), CFrame = disc(base + Vector3.new(0, height - 1.6, 0)), Color = GOLD }, columns)
	neon({ Name = "PillarTop", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, Position = base + Vector3.new(0, height + 0.5, 0), Color = GOLD, Transparency = 0 }, columns)
end
-- as colunas do meio ficam logo fora do arco (raio externo ~19,5)
for _, c in { { x = 22, z = -51, h = 26 }, { x = 29, z = -50, h = 20 }, { x = 38, z = -50, h = 26 }, { x = 50, z = -52, h = 18 } } do
	tube(-c.x, c.z, c.h)
	tube(c.x, c.z, c.h)
end

-- Holofotes: fachos subindo atrás do palco e três luzes apontadas para o Hyper -----------
for _, x in { -1, 1 } do
	local base = Vector3.new(x * 30, STAGE_TOP, -54)
	local tip = Vector3.new(x * 95, 175, -125)
	part({ Name = "Spotlight", Size = Vector3.new(3, 2.4, 3), CFrame = CFrame.lookAt(base, tip) * CFrame.Angles(math.rad(-90), 0, 0), Color = GRAPHITE }, decorations)
	local length = (tip - base).Magnitude
	neon({
		Name = "LightBeam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, 6, 6),
		CFrame = CFrame.lookAt((base + tip) / 2, tip) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromHex("7FD8FF"),
		Transparency = 0.72,
		CanQuery = false,
	}, decorations)
end
local hyperFocus = Vector3.new(0, DAIS_TOP + 5, DAIS_CENTER.Z)
for _, light in {
	-- luzes quase brancas: coloridas demais deixavam o Hyper todo rosa
	{ from = Vector3.new(-22, STAGE_TOP + 27, -51), color = Color3.fromRGB(255, 225, 240) },
	{ from = Vector3.new(22, STAGE_TOP + 27, -51), color = Color3.fromRGB(215, 235, 255) },
	{ from = Vector3.new(0, 34, -6), color = Color3.fromRGB(255, 240, 215) },
} do
	local holder = part({ Name = "StageLight", Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.lookAt(light.from, hyperFocus), Color = GRAPHITE, CanCollide = false, CanQuery = false }, decorations)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Color = light.color
	spot.Brightness = 1.6
	spot.Range = 45
	spot.Angle = 40
	spot.Parent = holder
end

-- Telões nas pontas do palco (20 x 12), com suporte próprio ---------------------------
local function sideScreen(name: string, title: string, x: number, yaw: number, icon: string?)
	local s = part({ Name = name, Size = Vector3.new(20, 12, 1), CFrame = facing(Vector3.new(x, STAGE_TOP + 4 + 6, -40), yaw), Color = GRAPHITE }, lobby)
	frameNeon(s, PINK, 0.8, lobby)
	local legHeight = s.Position.Y - s.Size.Y / 2 - STAGE_TOP
	for _, lx in { -6, 6 } do
		part({ Name = name .. "Stand", Size = Vector3.new(1.2, legHeight, 1.2), CFrame = s.CFrame * CFrame.new(lx, -s.Size.Y / 2 - legHeight / 2, 1), Color = Color3.fromHex("8C88A8"), Material = Enum.Material.Metal }, lobby)
	end
	-- 46 px por stud deixa o telão nítido; o texto automático para em 100 px, então o layout é feito
	-- em 20 px por stud e o UIScale amplia tudo na hora de desenhar
	local gui = surfaceGui(s, 46)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(20 / 46, 20 / 46)
	frame.BackgroundColor3 = Color3.fromHex("1A0B38")
	frame.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 46 / 20
	scale.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.1, 0)
	corner.Parent = frame
	local border = Instance.new("UIStroke")
	border.Color = PINK
	border.Thickness = 10
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = frame
	local titleLabel = textLabel({ Name = "Label", Text = title, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromScale(0.05, 0.06), Size = UDim2.fromScale(0.9, 0.22) }, frame)
	titleLabel.TextScaled = false
	titleLabel.TextSize = math.clamp(math.floor(s.Size.X * 20 * 0.9 / (utf8.len(title) or #title) / 0.58), 20, 48)
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.Position = UDim2.fromScale(0.12, 0.33)
	box.Size = UDim2.fromScale(0.76, 0.58)
	box.BackgroundColor3 = Color3.fromHex("0B0620")
	box.Parent = frame
	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0.14, 0)
	boxCorner.Parent = box
	local boxBorder = Instance.new("UIStroke")
	boxBorder.Color = MAGENTA
	boxBorder.Thickness = 5
	boxBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	boxBorder.Parent = box
	-- brilho holográfico: degradê suave dentro da caixa
	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new(Color3.fromHex("3A1C7A"), Color3.fromHex("0B0620"))
	glow.Rotation = 90
	glow.Parent = box
	-- telão com ícone (Modificador de Caos): ícone à esquerda e o nome à direita
	if icon then
		local image = Instance.new("ImageLabel")
		image.Name = "Icon"
		image.BackgroundTransparency = 1
		image.Position = UDim2.fromScale(0.03, 0.06)
		image.Size = UDim2.fromScale(0.36, 0.88)
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = icon
		image.Parent = box
	end
	local content = textLabel({ Name = "Content", Text = if icon then "" else "?", TextColor3 = Color3.fromHex("FF8AD8"), Position = UDim2.fromScale(if icon then 0.4 else 0.05, 0.06), Size = UDim2.fromScale(if icon then 0.57 else 0.9, 0.88) }, box)
	content.TextScaled = false
	content.TextWrapped = true
	content.TextSize = 100 -- o StageService ajusta conforme o nome do minigame/modificador
	local front = s.CFrame * CFrame.new(0, 0, -0.8)
	sparkle((front * CFrame.new(-s.Size.X / 2 - 1.4, s.Size.Y / 2 - 1.5, 0)).Position, 2.2, GOLD, decorations)
	sparkle((front * CFrame.new(s.Size.X / 2 + 1.4, -s.Size.Y / 2 + 2.5, 0)).Position, 1.8, PINK, decorations)
end
sideScreen("NextScreen", "PRÓXIMO MINIGAME", -42, 22)
sideScreen("ChaosScreen", "MODIFICADOR DE CAOS", 42, -22, "rbxassetid://117163015864861") -- arte/icones/icone_interrogacao.png

-- Roleta à direita do Hyper, na própria base (mais baixa que a plataforma dele) ----------
local WHEEL_RADIUS = 5.5
local wheelBaseCenter = Vector3.new(27, STAGE_TOP, -36)
local wheelCenter = wheelBaseCenter + Vector3.new(0, 0.6 + 1 + WHEEL_RADIUS, 0)
local wheel = Instance.new("Model")
wheel.Name = "Wheel"
wheel.Parent = lobby
part({ Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 12, 12), CFrame = disc(wheelBaseCenter + Vector3.new(0, 0.3, 0)), Color = Color3.fromHex("2E1670") }, wheel)
neon({ Name = "BaseRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 12.4, 12.4), CFrame = disc(wheelBaseCenter + Vector3.new(0, 0.3, 0)), Color = PINK }, wheel)
part({ Name = "Stand", Size = Vector3.new(1.8, wheelCenter.Y - wheelBaseCenter.Y - 0.6, 1.2), Position = Vector3.new(wheelCenter.X, (wheelCenter.Y + wheelBaseCenter.Y + 0.6) / 2, wheelCenter.Z - 1.4), Color = GOLD, Material = Enum.Material.Metal }, wheel)
part({ Name = "Back", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, WHEEL_RADIUS * 2 + 1.8, WHEEL_RADIUS * 2 + 1.8), CFrame = wallDisc(wheelCenter + Vector3.new(0, 0, -0.8)), Color = GRAPHITE }, wheel)
neon({ Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, WHEEL_RADIUS * 2 + 0.8, WHEEL_RADIUS * 2 + 0.8), CFrame = wallDisc(wheelCenter + Vector3.new(0, 0, -0.45)), Color = GOLD }, wheel)
local wheelDisc = part({ Name = "Disc", Size = Vector3.new(WHEEL_RADIUS * 2, WHEEL_RADIUS * 2, 0.2), CFrame = facing(wheelCenter), Transparency = 1, CanCollide = false }, wheel)
imageOn(wheelDisc, WHEEL_IMAGE, 90)
for i = 0, 15 do
	local a = 2 * math.pi * i / 16
	neon({
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.6,
		Position = wheelCenter + Vector3.new(math.cos(a) * (WHEEL_RADIUS + 0.7), math.sin(a) * (WHEEL_RADIUS + 0.7), 0.1),
		Color = if i % 2 == 0 then Color3.new(1, 1, 1) else PINK,
		Transparency = 0,
	}, wheel)
end
neon({ Name = "Pointer", Size = Vector3.new(1.5, 1.5, 0.5), CFrame = CFrame.new(wheelCenter + Vector3.new(0, WHEEL_RADIUS + 1.1, 0.4)) * CFrame.Angles(0, 0, math.rad(45)), Color = PINK, Transparency = 0 }, wheel)

-- Pódio 2-1-3 à esquerda do Hyper, sobre o palco (17 x 8) ---------------------------
-- (O RoundService põe uma estátua do avatar de cada vencedor em cima de cada degrau.)
local podium = Instance.new("Model")
podium.Name = "Podium"
podium.Parent = workspace
local podiumFrame = facing(Vector3.new(-28, STAGE_TOP, -33))
part({ Name = "Base", Size = Vector3.new(17, 0.8, 8), CFrame = podiumFrame * CFrame.new(0, 0.4, 0), Color = Color3.fromHex("2E1670") }, podium)
neon({ Name = "BaseTrim", Size = Vector3.new(17.4, 0.25, 8.4), CFrame = podiumFrame * CFrame.new(0, 0.55, 0), Color = PINK }, podium)
-- X local positivo aponta para a esquerda de quem olha da plateia: o 2º fica à esquerda, o 3º à direita
for _, s in {
	{ rank = 1, height = 4, x = 0, color = GOLD },
	{ rank = 2, height = 3, x = 5.6, color = Color3.fromHex("C9A6FF") },
	{ rank = 3, height = 2.2, x = -5.6, color = Color3.fromHex("FF8FC8") },
} do
	local step = part({ Name = "Step" .. s.rank, Size = Vector3.new(5.5, s.height, 6), CFrame = podiumFrame * CFrame.new(s.x, 0.8 + s.height / 2, 0), Color = s.color }, podium)
	local gui = surfaceGui(step, 30)
	textLabel({ Name = "Label", Text = tostring(s.rank), TextColor3 = Color3.fromHex("3A1470"), Size = UDim2.fromScale(1, 0.85), Position = UDim2.fromScale(0, 0.08) }, gui)
	neon({ Name = "StepTrim", Size = Vector3.new(5.7, 0.25, 6.2), CFrame = podiumFrame * CFrame.new(s.x, 0.8 + s.height, 0), Color = PURPLE }, podium)
end

-- Espaço: planetas e asteroides ao redor (fora da área de circulação) ---------------
local space = Instance.new("Model")
space.Name = "Space"
space.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- longe do jogador, mas precisa estar no cliente
space.Parent = workspace
part({ Name = "Planet", Shape = Enum.PartType.Ball, Size = Vector3.one * 60, Position = Vector3.new(-150, 120, -230), Color = Color3.fromHex("6B4BC2"), Material = Enum.Material.Sand, CanCollide = false, CastShadow = false }, space)
-- anel do planeta: segmentos de neon num plano inclinado (visto de frente vira uma elipse)
local ringFrame = CFrame.new(-150, 120, -230) * CFrame.Angles(math.rad(70), 0, math.rad(-18))
for i = 0, 39 do
	local a0, a1 = 2 * math.pi * i / 40, 2 * math.pi * (i + 1) / 40
	local p0 = (ringFrame * CFrame.new(math.cos(a0) * 50, math.sin(a0) * 50, 0)).Position
	local p1 = (ringFrame * CFrame.new(math.cos(a1) * 50, math.sin(a1) * 50, 0)).Position
	bar("PlanetRing", p0, p1, 2.2, Color3.fromHex("C9A8FF"), space, { Transparency = 0.3 })
end
part({ Name = "Planet", Shape = Enum.PartType.Ball, Size = Vector3.one * 48, Position = Vector3.new(160, 110, -210), Color = Color3.fromHex("2E5BC8"), Material = Enum.Material.Sand, CanCollide = false, CastShadow = false }, space)
local rng = Random.new(7)
for _ = 1, 16 do
	local angle = math.rad(rng:NextNumber(-150, -30)) -- atrás e dos lados do palco
	local dist = rng:NextNumber(95, 170)
	local center = Vector3.new(math.cos(angle) * dist, rng:NextNumber(15, 95), -36 + math.sin(angle) * dist)
	local size = rng:NextNumber(4, 11)
	-- três bolas sobrepostas de tamanhos diferentes formam uma pedra irregular
	for k = 1, 3 do
		local offset = Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.4, 0.4)) * size
		part({
			Name = "Asteroid",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size * (if k == 1 then 1 else rng:NextNumber(0.55, 0.8)),
			Position = center + offset * (if k == 1 then 0 else 1),
			Color = Color3.fromHex("3B2E5A"),
			Material = Enum.Material.Slate,
			CanCollide = false,
			CastShadow = false,
		}, space)
	end
end

-- Hyper no centro da plataforma (tools/build_hyper.luau usa os mesmos pés)
local hyper = workspace:FindFirstChild("Hyper")
if hyper and hyper:IsA("Model") then
	local cf, size = hyper:GetBoundingBox()
	hyper:PivotTo(hyper:GetPivot() + (HYPER_FEET - (cf.Position - Vector3.new(0, size.Y / 2, 0))))
end

return "cenário espacial criado"
