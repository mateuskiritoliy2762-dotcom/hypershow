--!strict
-- Cliente: deixa o humanoid mole durante o ragdoll e levanta no final (o servidor manda o sinal).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RagdollController = {}

function RagdollController.init()
	Remotes.get("Ragdoll").OnClientEvent:Connect(function(on: boolean)
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		humanoid:ChangeState(if on then Enum.HumanoidStateType.Physics else Enum.HumanoidStateType.GettingUp)
	end)
end

return RagdollController
