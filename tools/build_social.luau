--!strict
-- Monta a área social da frente da ilha (Lobby.SocialArea): estação ASSISTIR, mirante com vidro e barreiras
-- invisíveis (a loja e a roleta de recompensas ficam na ilha de nascimento, SpawnLobby). A arena do
-- Desmoronamento Neon fica abaixo e à frente do mirante (Config.NeonCollapse.ArenaOrigin).
-- A inscrição nos minigames é pelo portal da ilha de nascimento (SocialService).
-- A lógica fica no SocialService (inscrição, segurança) e no SocialController (interface, espectador).
-- Rodar no Studio (modo Edit), depois do build_lobby: python tools/studio.py run tools/build_social.luau
-- Pode rodar de novo: apaga e recria Lobby.SocialArea.

local PURPLE = Color3.fromHex("5B2BD6")
local PINK = Color3.fromHex("FF3D8B")
local GOLD = Color3.fromHex("FFC83D")
local BLUE = Color3.fromHex("35C8FF")
local DARK = Color3.fromHex("100C24")
local DECK = Color3.fromHex("231048")
local METAL = Color3.fromHex("8C88A8")

local FLOOR_TOP = 1

local lobby = workspace:FindFirstChild("Lobby")
assert(lobby, "rode tools/build_lobby.luau antes")
local old = lobby:FindFirstChild("SocialArea")
if old then
	old:Destroy()
end
local area = Instance.new("Model")
area.Name = "SocialArea"
area.Parent = lobby

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

local function neon(props: { [string]: any }, parent: Instance): BasePart
	props.Material = Enum.Material.Neon
	props.Color = (props.Color :: Color3):Lerp(Color3.new(0, 0, 0), 0.35)
	props.Transparency = props.Transparency or 0.1
	props.CanCollide = false
	props.CastShadow = false
	return part(props, parent)
end

local function group(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = area
	return m
end

local function prompt(parent: BasePart, name: string, action: string, objectText: string)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = parent
end

-- Estação ASSISTIR -------------------------------------------------------------------------------
local station = group("SpectatorStation")
local stationCenter = Vector3.new(46, FLOOR_TOP, 60)
part({ Name = "KioskBase", Size = Vector3.new(6, 1, 4), Position = stationCenter + Vector3.new(0, 0.5, 0), Color = DARK, Material = Enum.Material.Metal }, station)
part({ Name = "KioskPost", Size = Vector3.new(1.2, 4, 1.2), Position = stationCenter + Vector3.new(0, 3, 0.8), Color = METAL, Material = Enum.Material.Metal }, station)
local screen = part({ Name = "KioskScreen", Size = Vector3.new(7, 4.5, 0.5), CFrame = CFrame.lookAt(stationCenter + Vector3.new(0, 6.6, 0.8), stationCenter + Vector3.new(0, 6.6, -10)), Color = DARK, Material = Enum.Material.Metal }, station)
neon({ Name = "KioskFrame", Size = Vector3.new(7.4, 4.9, 0.3), CFrame = screen.CFrame * CFrame.new(0, 0, 0.2), Color = BLUE }, station)
local screenGui = Instance.new("SurfaceGui")
screenGui.Face = Enum.NormalId.Front
screenGui.LightInfluence = 0
screenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
screenGui.PixelsPerStud = 50
screenGui.Parent = screen
for i, line in { { "ASSISTIR", Color3.new(1, 1, 1), 0.5 }, { "câmera da arena", BLUE, 0.28 } } do
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.05, if i == 1 then 0.12 else 0.64)
	label.Size = UDim2.fromScale(0.9, line[3] :: number)
	label.Font = if i == 1 then Enum.Font.LuckiestGuy else Enum.Font.FredokaOne
	label.Text = line[1] :: string
	label.TextColor3 = line[2] :: Color3
	label.TextScaled = true
	label.Parent = screenGui
end
prompt(screen, "WatchPrompt", "Assistir partida", "Desmoronamento Neon")

-- Mirante na borda da frente (z 75 a 90), olhando para a arena lá embaixo -------------------------
local deck = group("ObservationDeck")
part({ Name = "DeckFloor", Size = Vector3.new(120, 1, 15), Position = Vector3.new(0, 0.5, 82.5), Color = DECK, Reflectance = 0.12 }, deck)
part({ Name = "DeckUnderside", Size = Vector3.new(116, 4, 13), Position = Vector3.new(0, -2, 82), Color = DARK }, deck)
neon({ Name = "DeckEdge", Size = Vector3.new(120, 0.25, 0.4), Position = Vector3.new(0, 0.95, 89.8), Color = BLUE }, deck)
neon({ Name = "DeckEdge", Size = Vector3.new(120, 0.25, 0.4), Position = Vector3.new(0, 1.05, 75.2), Color = PINK }, deck)
-- guarda-corpo de vidro (3 de altura) na frente e nas laterais, com corrimão dourado
local function glassRail(a: Vector3, b: Vector3)
	local length = (b - a).Magnitude
	local mid = (a + b) / 2
	part({ Name = "DeckGlass", Size = Vector3.new(0.3, 3, length), CFrame = CFrame.lookAt(mid + Vector3.new(0, 1.5, 0), b + Vector3.new(0, 1.5, 0)), Color = Color3.fromHex("B9A6FF"), Material = Enum.Material.Glass, Transparency = 0.65, CastShadow = false }, deck)
	neon({ Name = "DeckRail", Size = Vector3.new(0.4, 0.4, length), CFrame = CFrame.lookAt(mid + Vector3.new(0, 3.1, 0), b + Vector3.new(0, 3.1, 0)), Color = GOLD }, deck)
	local posts = math.max(1, math.floor(length / 10))
	for i = 0, posts do
		part({ Name = "DeckPost", Size = Vector3.new(0.5, 3.2, 0.5), Position = a:Lerp(b, i / posts) + Vector3.new(0, 1.6, 0), Color = METAL, Material = Enum.Material.Metal, CastShadow = false }, deck)
	end
end
glassRail(Vector3.new(-60, FLOOR_TOP, 89.7), Vector3.new(60, FLOOR_TOP, 89.7))
glassRail(Vector3.new(-60, FLOOR_TOP, 75), Vector3.new(-60, FLOOR_TOP, 89.7))
glassRail(Vector3.new(60, FLOOR_TOP, 75), Vector3.new(60, FLOOR_TOP, 89.7))
-- binóculos decorativos, fora do centro (não tapam a vista da arena) e baixos
for _, x in { -45, -25, 25, 45 } do
	part({ Name = "BinocularPost", Size = Vector3.new(0.4, 2.2, 0.4), Position = Vector3.new(x, FLOOR_TOP + 1.1, 88.4), Color = METAL, Material = Enum.Material.Metal }, deck)
	part({ Name = "Binocular", Size = Vector3.new(1.1, 0.55, 0.9), CFrame = CFrame.lookAt(Vector3.new(x, FLOOR_TOP + 2.45, 88.4), Vector3.new(x, -40, 140)), Color = PURPLE, Material = Enum.Material.Metal }, deck)
end

-- Barreiras invisíveis: não dá para pular para fora (o SocialService ainda devolve quem cair) ----
local barriers = group("SafetyBarriers")
local function wallBetween(a: Vector3, b: Vector3)
	local mid = (a + b) / 2
	part({ Name = "Barrier", Size = Vector3.new(1, 40, (b - a).Magnitude), CFrame = CFrame.lookAt(mid + Vector3.new(0, 20, 0), b + Vector3.new(0, 20, 0)), Transparency = 1, CanQuery = false, CanTouch = false, CastShadow = false }, barriers)
end
wallBetween(Vector3.new(-60.5, FLOOR_TOP, 90.4), Vector3.new(60.5, FLOOR_TOP, 90.4))
wallBetween(Vector3.new(-60.5, FLOOR_TOP, 74), Vector3.new(-60.5, FLOOR_TOP, 90.4))
wallBetween(Vector3.new(60.5, FLOOR_TOP, 74), Vector3.new(60.5, FLOOR_TOP, 90.4))
wallBetween(Vector3.new(-68.5, FLOOR_TOP, -55), Vector3.new(-68.5, FLOOR_TOP, 75))
wallBetween(Vector3.new(68.5, FLOOR_TOP, -55), Vector3.new(68.5, FLOOR_TOP, 75))
-- cantos da frente da ilha que ficam fora do mirante (x 60 a 68)
wallBetween(Vector3.new(-68.5, FLOOR_TOP, 75.5), Vector3.new(-60.5, FLOOR_TOP, 75.5))
wallBetween(Vector3.new(60.5, FLOOR_TOP, 75.5), Vector3.new(68.5, FLOOR_TOP, 75.5))

return "área social criada"
