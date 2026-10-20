--!strict
-- Cliente: menu de configurações (botão de engrenagem). Música, voz do Hyper, efeitos da fala, efeitos visuais e
-- brilho. Cada opção vira um atributo local no jogador (HyperShowMusic, HyperShowVoice, HyperShowSpeechFx,
-- HyperShowFx) que os outros controllers escutam; o brilho é um ColorCorrection só deste aparelho.
-- O servidor guarda as escolhas no perfil (SettingsSave) e devolve ao entrar (SettingsData).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Strings = Config.Strings
local Data = Config.Data

local GOLD = Color3.fromHex("FFC83D")
local PINK = Color3.fromHex("FF3D8B")
local CYAN = Color3.fromHex("35C8FF")
local GREEN = Color3.fromHex("3DFF8B")
local GRAPHITE = Color3.fromHex("1B1730")
local WHITE = Color3.new(1, 1, 1)

local SettingsController = {}

local player = Players.LocalPlayer
local current: { [string]: any } = table.clone(Data.DefaultSettings)
local correction: ColorCorrectionEffect
local saveToken = 0
local refreshers: { () -> () } = {}

local ATTRIBUTES = {
	music = "HyperShowMusic",
	voice = "HyperShowVoice",
	speechFx = "HyperShowSpeechFx",
	fx = "HyperShowFx",
}

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function apply()
	for key, attribute in ATTRIBUTES do
		player:SetAttribute(attribute, current[key] == true)
	end
	local level = tonumber(current.brightness) or 0
	correction.Brightness = level * 0.06
	correction.Contrast = level * 0.03
	for _, refresh in refreshers do
		refresh()
	end
end

-- Salva com atraso curto: vários toques seguidos viram um pedido só.
local function scheduleSave()
	saveToken += 1
	local token = saveToken
	task.delay(1.2, function()
		if token == saveToken then
			Remotes.get("SettingsSave"):FireServer(current)
		end
	end)
end

local function set(key: string, value: any)
	current[key] = value
	apply()
	scheduleSave()
end

local function rowFrame(parent: Instance, order: number, title: string): Frame
	local row = new("Frame", {
		Name = "Row",
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0.184),
		BackgroundColor3 = Color3.fromHex("2A1650"),
		BackgroundTransparency = 0.25,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, row)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.05, 0.15),
		Size = UDim2.fromScale(0.5, 0.7),
		Text = title,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		TextColor3 = WHITE,
	}, row)
	return row
end

local function toggleRow(parent: Instance, order: number, title: string, key: string)
	local row = rowFrame(parent, order, title)
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.96, 0.5),
		Size = UDim2.fromScale(0.36, 0.84),
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextColor3 = GRAPHITE,
		AutoButtonColor = true,
	}, row)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, button)
	new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.1, 0) }, button)
	local stroke = new("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
	table.insert(refreshers, function()
		local on = current[key] == true
		button.Text = if on then Strings.On else Strings.Off
		button.BackgroundColor3 = if on then GREEN else Color3.fromHex("5A5470")
		stroke.Color = if on then WHITE else Color3.fromHex("8C88A8")
	end)
	button.Activated:Connect(function()
		set(key, not (current[key] == true))
	end)
end

local function brightnessRow(parent: Instance, order: number)
	local row = rowFrame(parent, order, Strings.SettingBrightness)
	local function stepButton(text: string, x: number, delta: number)
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromScale(0.1, 0.72),
			Text = text,
			Font = Enum.Font.LuckiestGuy,
			TextScaled = true,
			TextColor3 = GRAPHITE,
			BackgroundColor3 = GOLD,
		}, row)
		new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, b)
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, b)
		b.Activated:Connect(function()
			local value = math.clamp((tonumber(current.brightness) or 0) + delta, Data.BrightnessMin, Data.BrightnessMax)
			set("brightness", value)
		end)
	end
	stepButton("-", 0.58, -1)
	stepButton("+", 0.92, 1)
	local dots: { Frame } = {}
	for i = Data.BrightnessMin, Data.BrightnessMax do
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.75 + i * 0.045, 0.5),
			Size = UDim2.fromScale(0.03, 0.3),
			BackgroundColor3 = CYAN,
		}, row)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
		dots[i - Data.BrightnessMin + 1] = dot
	end
	table.insert(refreshers, function()
		local level = tonumber(current.brightness) or 0
		for i, dot in dots do
			local value = Data.BrightnessMin + i - 1
			dot.BackgroundTransparency = if value <= level then 0 else 0.7
		end
	end)
end

local function build()
	local gui = new("ScreenGui", { Name = "Settings", ResetOnSpawn = false, DisplayOrder = 20 }, player:WaitForChild("PlayerGui"))
	-- engrenagem no alto à direita, grande o bastante para o dedo
	local gear = new("TextButton", {
		Name = "Gear",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.985, 0.14),
		Size = UDim2.fromScale(0.07, 0.1),
		Text = "⚙",
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = GOLD,
		BackgroundColor3 = GRAPHITE,
		BackgroundTransparency = 0.1,
	}, gui)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, gear)
	new("UISizeConstraint", { MinSize = Vector2.new(44, 44) }, gear)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, gear)
	new("UIStroke", { Color = PINK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, gear)

	local panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.92),
		BackgroundColor3 = WHITE,
		Visible = false,
	}, gui)
	new("UIAspectRatioConstraint", { AspectRatio = 1.05 }, panel)
	new("UICorner", { CornerRadius = UDim.new(0.06, 0) }, panel)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromHex("3A1C7A"), Color3.fromHex("0E0626")), Rotation = 90 }, panel)
	new("UIStroke", { Color = CYAN, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
	new("UIScale", { Scale = 1 }, panel)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.06, 0.03),
		Size = UDim2.fromScale(0.88, 0.1),
		Text = Strings.SettingsTitle,
		TextScaled = true,
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = GOLD,
	}, panel)
	local list = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.06, 0.15),
		Size = UDim2.fromScale(0.88, 0.7),
	}, panel)
	new("UIListLayout", { Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	toggleRow(list, 1, Strings.SettingMusic, "music")
	toggleRow(list, 2, Strings.SettingVoice, "voice")
	toggleRow(list, 3, Strings.SettingSpeechFx, "speechFx")
	toggleRow(list, 4, Strings.SettingFx, "fx")
	brightnessRow(list, 5)
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.5, 0.1),
		Text = Strings.Close,
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextColor3 = WHITE,
		BackgroundColor3 = PINK,
	}, panel)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, close)
	new("UIPadding", { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.1, 0) }, close)

	local function open(visible: boolean)
		local scale = panel:FindFirstChildOfClass("UIScale") :: UIScale
		if visible then
			scale.Scale = 0.3
			panel.Visible = true
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		else
			panel.Visible = false
		end
	end
	gear.Activated:Connect(function()
		open(not panel.Visible)
	end)
	close.Activated:Connect(function()
		open(false)
	end)
end

function SettingsController.init()
	correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "PlayerBrightness"
	correction.Parent = Lighting
	build()
	apply()
	Remotes.get("SettingsData").OnClientEvent:Connect(function(saved: unknown)
		if typeof(saved) ~= "table" then
			return
		end
		for key, default in Data.DefaultSettings do
			local value = (saved :: any)[key]
			if typeof(value) == typeof(default) then
				current[key] = value
			end
		end
		apply()
	end)
	Remotes.get("SettingsRequest"):FireServer()
end

return SettingsController
