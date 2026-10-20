--!strict
-- Controles Invertidos: frente vira trás e esquerda vira direita. O servidor só marca o atributo no jogador;
-- o ModifierController (cliente) inverte o movimento enquanto o atributo estiver ligado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local ATTRIBUTE = "ReverseControls"

local marked: { Player } = {}

local ReverseControls: Types.ModifierDef = {
	id = "ReverseControls",
	displayName = "Controles Invertidos",
	weight = 1,
	apply = function(ctx)
		for _, player in ctx.players do
			player:SetAttribute(ATTRIBUTE, true)
			table.insert(marked, player)
		end
	end,
	remove = function(_ctx)
		for _, player in marked do
			if player.Parent then
				player:SetAttribute(ATTRIBUTE, nil)
			end
		end
		table.clear(marked)
	end,
}

return ReverseControls
