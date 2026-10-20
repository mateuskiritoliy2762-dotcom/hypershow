--!strict
-- Cliente: efeitos de modificadores que precisam mexer no próprio jogador.
-- Controles Invertidos: enquanto o servidor deixar o atributo ReverseControls ligado, a direção de andar é
-- invertida a cada quadro, logo depois de o Roblox ler o teclado/joystick (prioridade Character + 1).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BIND_NAME = "HyperShowReverseControls"

local ModifierController = {}

local function reverseStep()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		humanoid:Move(-humanoid.MoveDirection, false)
	end
end

local function onAttribute()
	RunService:UnbindFromRenderStep(BIND_NAME)
	if Players.LocalPlayer:GetAttribute("ReverseControls") then
		RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Character.Value + 1, reverseStep)
	end
end

function ModifierController.init()
	Players.LocalPlayer:GetAttributeChangedSignal("ReverseControls"):Connect(onAttribute)
	onAttribute()
end

return ModifierController
