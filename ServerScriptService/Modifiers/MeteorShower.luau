--!strict
-- Chuva de Meteoros: durante a partida caem meteoros no mapa. Um círculo vermelho avisa onde vai cair;
-- no impacto quem estiver perto é arremessado (ragdoll) e as peças pequenas do chão em volta despencam.
-- Tudo fica dentro do mapa da rodada (some junto com ele); remove() só desliga o laço.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Sfx = require(ReplicatedStorage.Shared.Util.Sfx)
local RagdollService = require(ServerScriptService.Services.RagdollService)

local Settings = Config.Modifiers

local active = false

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function fxPart(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- Ponto do chão do mapa embaixo de `position` (nil se não houver chão).
local function groundBelow(map: Model, position: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	local hit = workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	return hit and hit.Position
end

local function pickTarget(ctx: Types.RoundContext, map: Model): Vector3?
	if math.random() < Settings.MeteorNearPlayerChance then
		local alive = {}
		for _, player in ctx.players do
			local root = ctx.alive[player] and rootOf(player)
			if root then
				table.insert(alive, root.Position)
			end
		end
		if #alive > 0 then
			local around = alive[math.random(1, #alive)] + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
			return groundBelow(map, around)
		end
	end
	local cf, size = map:GetBoundingBox()
	local x = (math.random() - 0.5) * size.X * 0.8
	local z = (math.random() - 0.5) * size.Z * 0.8
	return groundBelow(map, cf.Position + Vector3.new(x, size.Y / 2, z))
end

local function impact(ctx: Types.RoundContext, map: Model, ground: Vector3, holder: BasePart)
	local blast = Instance.new("Explosion")
	blast.Position = ground
	blast.BlastPressure = 0 -- só o visual; o empurrão é feito abaixo, pelo RagdollService
	blast.BlastRadius = Settings.MeteorRadius
	blast.DestroyJointRadiusPercent = 0
	blast.Parent = workspace
	Sfx.playAt("HexCrack", holder)
	for _, player in ctx.players do
		local root = ctx.alive[player] and rootOf(player)
		if root then
			local offset = root.Position - ground
			if offset.Magnitude <= Settings.MeteorRadius then
				local flat = offset * Vector3.new(1, 0, 1)
				local direction = if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis
				RagdollService.ragdoll(player, Config.Ragdoll.Duration, direction * Settings.MeteorKnockSpeed + Vector3.new(0, Settings.MeteorUpSpeed, 0))
			end
		end
	end
	-- peças pequenas do mapa em volta despencam (o chão grande e a gosma nunca)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { map }
	for _, part in workspace:GetPartBoundsInRadius(ground, Settings.MeteorBreakRadius, overlap) do
		if part.Anchored and part.CanCollide and part.Size.Magnitude < 20 then
			part.Anchored = false
			Debris:AddItem(part, 3)
		end
	end
end

local function meteor(ctx: Types.RoundContext, map: Model, folder: Folder)
	local ground = pickTarget(ctx, map)
	if not ground then
		return
	end
	-- aviso: círculo vermelho pulsando no chão
	local warning = fxPart({
		Name = "MeteorWarning",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 1, 1),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 40, 30),
		Transparency = 0.35,
	}, folder)
	local diameter = Settings.MeteorRadius * 2
	TweenService:Create(warning, TweenInfo.new(Settings.MeteorWarning, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, diameter, diameter) }):Play()
	task.wait(Settings.MeteorWarning - 0.45)
	if not active or not folder.Parent then
		return
	end
	-- o meteoro cai do alto com rastro de fogo
	local rock = fxPart({
		Name = "Meteor",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 4,
		Position = ground + Vector3.new(18, 70, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 120, 40),
	}, folder)
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Heat = 0
	fire.Color = Color3.fromRGB(255, 120, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 40, 20)
	fire.Parent = rock
	local fall = TweenService:Create(rock, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = ground + Vector3.new(0, 1, 0) })
	fall:Play()
	fall.Completed:Wait()
	if active and folder.Parent then
		impact(ctx, map, ground, warning)
	end
	Debris:AddItem(warning, 0.3)
	Debris:AddItem(rock, 0.3)
end

local MeteorShower: Types.ModifierDef = {
	id = "MeteorShower",
	displayName = "Chuva de Meteoros",
	weight = 1,
	apply = function(ctx)
		local map = ctx.map
		if not map then
			return
		end
		active = true
		local folder = Instance.new("Folder")
		folder.Name = "MeteorFx"
		folder.Parent = map
		task.spawn(function()
			while active and folder.Parent do
				-- só durante a partida (startTime é marcado quando começa o Playing)
				if ctx.startTime > 0 then
					task.spawn(meteor, ctx, map, folder)
				end
				task.wait(Settings.MeteorInterval)
			end
		end)
	end,
	remove = function(_ctx)
		active = false
	end,
}

return MeteorShower
