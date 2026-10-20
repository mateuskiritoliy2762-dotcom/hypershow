--!strict
-- Gravidade Lunar: todo mundo pula altíssimo. remove() sempre restaura a gravidade original.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local originalGravity: number? = nil

local LunarGravity: Types.ModifierDef = {
	id = "LunarGravity",
	displayName = "Gravidade Lunar",
	weight = 1,
	apply = function(_ctx)
		originalGravity = originalGravity or workspace.Gravity
		workspace.Gravity = Config.Modifiers.LunarGravity
	end,
	remove = function(_ctx)
		if originalGravity then
			workspace.Gravity = originalGravity
			originalGravity = nil
		end
	end,
}

return LunarGravity
