--!strict
-- Super Empurrão: o empurrão arremessa muito mais longe e recarrega bem mais rápido.
-- A validação continua toda no PushService; aqui só mudam os multiplicadores.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local PushService = require(ServerScriptService.Services.PushService)

local MegaPush: Types.ModifierDef = {
	id = "MegaPush",
	displayName = "Super Empurrão",
	weight = 1,
	apply = function(_ctx)
		PushService.setBoost(Config.Modifiers.MegaPushForce, Config.Modifiers.MegaPushCooldown)
	end,
	remove = function(_ctx)
		PushService.setBoost(1, 1)
	end,
}

return MegaPush
