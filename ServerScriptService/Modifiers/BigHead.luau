--!strict
-- Cabeção: cabeças gigantes (visual cômico). Usa a escala de cabeça do avatar R15
-- e devolve a escala original no remove().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local saved: { [NumberValue]: number } = {}

local BigHead: Types.ModifierDef = {
	id = "BigHead",
	displayName = "Cabeção",
	weight = 1,
	apply = function(ctx)
		for _, player in ctx.players do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local headScale = humanoid and humanoid:FindFirstChild("HeadScale")
			if headScale and headScale:IsA("NumberValue") and saved[headScale] == nil then
				saved[headScale] = headScale.Value
				headScale.Value *= Config.Modifiers.BigHeadScale
			end
		end
	end,
	remove = function(_ctx)
		for headScale, original in saved do
			if headScale.Parent then
				headScale.Value = original
			end
		end
		table.clear(saved)
	end,
}

return BigHead
