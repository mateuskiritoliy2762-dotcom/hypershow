--!strict
-- Apagão: vira noite e a luz some; cada jogador carrega só uma luzinha em volta de si e o neon do mapa
-- vira a única referência. remove() devolve a iluminação e apaga as luzes dos jogadores.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local DARK = {
	ClockTime = 0,
	Brightness = 0,
	Ambient = Color3.fromRGB(12, 8, 22),
	OutdoorAmbient = Color3.fromRGB(18, 10, 32),
	ExposureCompensation = -0.6,
}

local saved: { [string]: any }? = nil
local lights: { PointLight } = {}

local Blackout: Types.ModifierDef = {
	id = "Blackout",
	displayName = "Apagão",
	weight = 1,
	apply = function(ctx)
		if not saved then
			local original = {}
			for prop, value in DARK do
				original[prop] = (Lighting :: any)[prop];
				(Lighting :: any)[prop] = value
			end
			saved = original
		end
		for _, player in ctx.players do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local light = Instance.new("PointLight")
				light.Name = "BlackoutLight"
				light.Color = Color3.fromRGB(200, 170, 255)
				light.Brightness = 2
				light.Range = Config.Modifiers.BlackoutLightRange
				light.Shadows = false
				light.Parent = root
				table.insert(lights, light)
			end
		end
	end,
	remove = function(_ctx)
		if saved then
			for prop, value in saved do
				(Lighting :: any)[prop] = value
			end
			saved = nil
		end
		for _, light in lights do
			light:Destroy()
		end
		table.clear(lights)
	end,
}

return Blackout
