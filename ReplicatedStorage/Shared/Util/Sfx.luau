--!strict
-- Toca um som de Config.Sounds preso a uma Part (som 3D). Chamado no servidor, todos ouvem.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Sfx = {}

function Sfx.playAt(key: string, parent: Instance)
	local id = Config.Sounds[key]
	if not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Sfx_" .. key
	sound.SoundId = id
	sound.Volume = Config.SoundVolumes[key] or 0.7
	sound.RollOffMaxDistance = 250
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 8)
end

return Sfx
