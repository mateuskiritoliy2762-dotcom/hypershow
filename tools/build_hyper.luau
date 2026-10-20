--!strict
-- Monta o apresentador Hyper com o modelo 3D gerado pelo Cube (Roblox), separado em cabeça, corpo e
-- braços (segment_mesh do Studio) para o HyperController (cliente) animar gestos, e um microfone na mão.
-- As partes usam a mesma textura do modelo inteiro: o rosto fica desenhado nela
-- (tools/paint_hyper_faces.py gera uma textura por rosto) e o HyperService troca a TextureID de todas.
-- Rodar no Studio (modo Edit): python tools/studio.py run tools/build_hyper.luau
-- Pode rodar de novo: apaga e recria Workspace.Hyper.

local AssetService = game:GetService("AssetService")

local TEXTURE_ID = "rbxassetid://103906419870860" -- textura com o rosto feliz (Config.Hyper.FaceTextures.Happy)
local GOLD = Color3.fromHex("FFC83D")
local PINK = Color3.fromHex("FF3D8B")
local GRAPHITE = Color3.fromHex("1B1730")
-- altura final do Hyper: ~14 studs (a malha cortada tem 30); tudo abaixo é multiplicado por esta escala
local SCALE = 14 / 30

-- Partes cortadas de arte/hyper/hyper_corpo.obj (escala 1.25): posição do centro em relação aos pés.
-- A malha cortada olha para -Z; o giro de 180° a deixa virada para o lobby (+Z).
local PIECES = {
	{ name = "Head", mesh = "rbxassetid://123468930742131", offset = Vector3.new(0, 22.981, 0), size = Vector3.new(14.515, 14.038, 9.901) },
	{ name = "Body", mesh = "rbxassetid://83663584183344", offset = Vector3.new(0.014, 8.43, 0.397), size = Vector3.new(7.688, 16.859, 7.326) },
	{ name = "LeftArm", mesh = "rbxassetid://78523846882805", offset = Vector3.new(4.602, 11.09, 0.904), size = Vector3.new(2.941, 7.762, 3.421) },
	{ name = "RightArm", mesh = "rbxassetid://129732999570177", offset = Vector3.new(-4.593, 11.085, 0.899), size = Vector3.new(2.927, 7.797, 3.415) },
}

for _, name in { "Hyper", "hyper_corpo" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- No centro do tablado do palco, olhando para o lobby (+Z).
local feet = Vector3.new(0, 8, -39)

local hyper = Instance.new("Model")
hyper.Name = "Hyper"

local parts: { [string]: MeshPart } = {}
for _, piece in PIECES do
	local p = AssetService:CreateMeshPartAsync(Content.fromUri(piece.mesh))
	p.Name = piece.name
	p.TextureID = TEXTURE_ID
	p.Anchored = true
	p.CanCollide = piece.name == "Body"
	p.Size = piece.size * SCALE
	p.CFrame = CFrame.new(feet + piece.offset * SCALE) * CFrame.Angles(0, math.pi, 0)
	p.Parent = hyper
	parts[piece.name] = p
end

-- Microfone de mão (o HyperController o prende na mão direita a cada quadro).
local mic = Instance.new("Model")
mic.Name = "Mic"
local function micPart(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = mic
	return p
end
-- o microfone fica em pé (eixo Y), com a cabeça para cima; a posição real vem do HyperController
local micBase = parts.RightArm.CFrame
micPart({ Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.6, 1.1, 1.1) * SCALE, CFrame = micBase * CFrame.Angles(0, 0, math.rad(90)), Color = GRAPHITE, Material = Enum.Material.Metal })
micPart({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.35, 1.35) * SCALE, CFrame = micBase * CFrame.new(0, 1.75 * SCALE, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = PINK, Material = Enum.Material.Neon })
micPart({ Name = "Grille", Shape = Enum.PartType.Ball, Size = Vector3.one * 2 * SCALE, CFrame = micBase * CFrame.new(0, 2.6 * SCALE, 0), Color = Color3.fromHex("B8B4C8"), Material = Enum.Material.DiamondPlate })
micPart({ Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.05, 2.05) * SCALE, CFrame = micBase * CFrame.new(0, 2.6 * SCALE, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = Enum.Material.Neon })
mic.PrimaryPart = mic:FindFirstChild("Handle") :: BasePart
mic.Parent = hyper

hyper.PrimaryPart = parts.Body
-- sempre presente no cliente (StreamingEnabled): o HyperController anima todas as peças juntas
hyper.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
hyper.Parent = workspace
return string.format("Hyper criado (altura %.1f)", parts.Head.Position.Y + parts.Head.Size.Y / 2 - feet.Y)
