--!strict
-- Chão Ensaboado: as peças do mapa do minigame ficam sem atrito (só o mapa, nunca o lobby).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local saved: { [BasePart]: { props: PhysicalProperties? } } = {}

local SlipperyFloor: Types.ModifierDef = {
	id = "SlipperyFloor",
	displayName = "Chão Ensaboado",
	weight = 1,
	apply = function(ctx)
		local map = ctx.map
		if not map then
			return
		end
		for _, part in map:GetDescendants() do
			if part:IsA("BasePart") and saved[part] == nil then
				saved[part] = { props = part.CustomPhysicalProperties }
				local current = PhysicalProperties.new(part.Material)
				-- atrito mínimo e peso máximo do atrito: vale o do chão, não o do sapato
				part.CustomPhysicalProperties = PhysicalProperties.new(current.Density, Config.Modifiers.SlipperyFriction, current.Elasticity, 100, current.ElasticityWeight)
			end
		end
	end,
	remove = function(_ctx)
		for part, original in saved do
			if part.Parent then
				part.CustomPhysicalProperties = original.props
			end
		end
		table.clear(saved)
	end,
}

return SlipperyFloor
