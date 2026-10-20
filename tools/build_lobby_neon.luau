--!strict
-- Visual futurista extra do lobby (Lobby.NeonExtras): deixa a ilha menos quadrada.
-- * IslandHalo: anel neon duplo em volta da ilha, logo abaixo do piso (silhueta redonda vista de longe);
-- * SkyHalo: halo dourado inclinado no céu, acima do palco (o ShowSetController gira devagar);
-- * Orbs: orbes de cristal flutuando nas bordas (o ShowSetController faz subir e descer).
-- Nada colide nem atrapalha o caminho. Rodar no Studio (modo Edit), depois do build_lobby:
--   python tools/studio.py run tools/build_lobby_neon.luau
-- Pode rodar de novo: apaga e recria Lobby.NeonExtras.

local PINK = Color3.fromHex("FF3D8B")
local CYAN = Color3.fromHex("35C8FF")
local GOLD = Color3.fromHex("FFC83D")
local PURPLE = Color3.fromHex("C23DFF")

local lobby = workspace:FindFirstChild("Lobby")
assert(lobby, "rode tools/build_lobby.luau antes")
local old = lobby:FindFirstChild("NeonExtras")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "NeonExtras"
root.Parent = lobby

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- anel de segmentos em volta de `center`, no plano dado por `frame` (eixo Y = normal do anel)
local function ring(name: string, frame: CFrame, radius: number, thickness: number, segments: number, colors: { Color3 }, parent: Instance)
	local model = Instance.new("Model")
	model.Name = name
	for i = 0, segments - 1 do
		local a0 = 2 * math.pi * i / segments
		local a1 = 2 * math.pi * (i + 1) / segments
		local p0 = frame * Vector3.new(math.cos(a0) * radius, 0, math.sin(a0) * radius)
		local p1 = frame * Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius)
		part({
			Name = "Segment",
			Size = Vector3.new(thickness, thickness, (p1 - p0).Magnitude + thickness * 0.4),
			CFrame = CFrame.lookAt((p0 + p1) / 2, p1, frame.UpVector),
			Color = colors[i % #colors + 1],
		}, model)
	end
	model.Parent = parent
	return model
end

local center = Vector3.new(0, 0, 9) -- centro do piso da ilha
ring("IslandHalo", CFrame.new(center + Vector3.new(0, -3, 0)), 100, 1.2, 72, { PINK, PINK, CYAN, CYAN }, root)
ring("IslandHaloInner", CFrame.new(center + Vector3.new(0, -5, 0)), 96, 0.6, 72, { PURPLE }, root)

local sky = ring("SkyHalo", CFrame.new(0, 78, -30) * CFrame.Angles(math.rad(-18), 0, 0), 46, 1.4, 56, { GOLD }, root)
sky:SetAttribute("Spin", 4) -- graus por segundo (ShowSetController)
sky.WorldPivot = CFrame.new(0, 78, -30) * CFrame.Angles(math.rad(-18), 0, 0) -- gira no próprio plano
ring("SkyHaloInner", CFrame.new(0, 78, -30) * CFrame.Angles(math.rad(-18), 0, 0), 42, 0.6, 56, { PINK, CYAN }, sky)

local orbs = Instance.new("Model")
orbs.Name = "Orbs"
orbs.Parent = root
for i = 0, 7 do
	local a = 2 * math.pi * (i + 0.5) / 8
	local pos = center + Vector3.new(math.cos(a) * 86, 14 + (i % 2) * 6, math.sin(a) * 84)
	local orb = Instance.new("Model")
	orb.Name = "Orb"
	local color = if i % 2 == 0 then CYAN else PINK
	local core = part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Position = pos, Color = color }, orb)
	part({ Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.one * 5.5, Position = pos, Color = Color3.fromHex("BFE9FF"), Material = Enum.Material.Glass, Transparency = 0.6 }, orb)
	part({
		Name = "Band",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 7.5, 7.5),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(20), 0, 0),
		Color = GOLD,
		Transparency = 0.3,
	}, orb)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 1.5
	light.Parent = core
	orb.PrimaryPart = core
	orb.Parent = orbs
end

return "NeonExtras criado"
