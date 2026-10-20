--!strict
-- Botão grande de empurrar (celular) e tecla E. Só envia o pedido; o servidor decide.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local InputController = {}

local cooldownEndsAt = 0

local function buildButton(): (ImageButton, TextLabel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "PushGui"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Acima do botão de pular do celular, ao alcance do polegar direito.
	local button = Instance.new("ImageButton")
	button.Name = "Push"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.fromScale(0.97, 0.66)
	button.Size = UDim2.fromScale(0.13, 0.13)
	button.BackgroundColor3 = Color3.fromHex("1B1730")
	button.BackgroundTransparency = 0.2
	button.Image = Config.Icons.Push
	button.Parent = gui
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = button
	local size = Instance.new("UISizeConstraint")
	size.MinSize = Vector2.new(80, 80)
	size.Parent = button
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("FFC83D")
	stroke.Thickness = 3
	stroke.Parent = button

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.fromScale(0.5, 1.02)
	hint.Size = UDim2.fromScale(1, 0.25)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.TextStrokeTransparency = 0.3
	hint.TextScaled = true
	hint.Font = Enum.Font.GothamBlack
	hint.Text = if UserInputService.KeyboardEnabled then "[E]" else ""
	hint.Parent = button

	local cooldown = Instance.new("TextLabel")
	cooldown.Name = "Cooldown"
	cooldown.Size = UDim2.fromScale(1, 1)
	cooldown.BackgroundColor3 = Color3.new(0, 0, 0)
	cooldown.BackgroundTransparency = 0.4
	cooldown.TextColor3 = Color3.new(1, 1, 1)
	cooldown.TextScaled = true
	cooldown.Font = Enum.Font.GothamBlack
	cooldown.Visible = false
	cooldown.Parent = button
	local cooldownCorner = corner:Clone()
	cooldownCorner.Parent = cooldown

	return button, cooldown
end

function InputController.init()
	local pushRemote = Remotes.get("PushRequest")
	local button, cooldownLabel = buildButton()

	local function requestPush()
		if os.clock() < cooldownEndsAt then
			return
		end
		pushRemote:FireServer()
	end

	button.Activated:Connect(requestPush)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.E then
			requestPush()
		end
	end)

	Remotes.get("PushCooldown").OnClientEvent:Connect(function(seconds: number)
		cooldownEndsAt = os.clock() + seconds
		cooldownLabel.Visible = true
		while os.clock() < cooldownEndsAt do
			cooldownLabel.Text = tostring(math.ceil(cooldownEndsAt - os.clock()))
			task.wait(0.1)
		end
		cooldownLabel.Visible = false
	end)
end

return InputController
