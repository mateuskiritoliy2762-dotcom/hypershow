--!strict
-- Inicializa os controllers do cliente.

local controllers = script.Parent:WaitForChild("Controllers")

for _, name in { "SettingsController", "HyperController", "LobbyFxController", "ModifierController", "SocialController", "UIController", "RagdollController", "InputController", "SoundController", "CutsceneController", "MeterController", "EliminationController", "ShowSetController" } do
	local module = controllers:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		(require(module) :: any).init()
	end
end

print("[HyperShow] cliente iniciado")
