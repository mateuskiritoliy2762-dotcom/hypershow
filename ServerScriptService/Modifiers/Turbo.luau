--!strict
-- Turbo: todo mundo corre e pula mais. remove() devolve os valores originais de cada humanoid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type Saved = { walk: number, jumpPower: number, jumpHeight: number }

local saved: { [Humanoid]: Saved } = {}

local Turbo: Types.ModifierDef = {
	id = "Turbo",
	displayName = "Turbo",
	weight = 1,
	apply = function(ctx)
		for _, player in ctx.players do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and not saved[humanoid] then
				saved[humanoid] = { walk = humanoid.WalkSpeed, jumpPower = humanoid.JumpPower, jumpHeight = humanoid.JumpHeight }
				humanoid.WalkSpeed *= Config.Modifiers.TurboWalkSpeedMultiplier
				-- o pulo pode usar JumpPower ou JumpHeight, conforme StarterPlayer
				humanoid.JumpPower *= Config.Modifiers.TurboJumpPowerMultiplier
				humanoid.JumpHeight *= Config.Modifiers.TurboJumpPowerMultiplier ^ 2
			end
		end
	end,
	remove = function(_ctx)
		for humanoid, values in saved do
			if humanoid.Parent then
				humanoid.WalkSpeed = values.walk
				humanoid.JumpPower = values.jumpPower
				humanoid.JumpHeight = values.jumpHeight
			end
		end
		table.clear(saved)
	end,
}

return Turbo
