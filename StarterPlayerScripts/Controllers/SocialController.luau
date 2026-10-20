--!strict
-- Cliente: interface da área social e modo espectador.
-- * Painel de participação: mostra "Participando ✓" + botão "Ficar no lobby" (atributo HyperShowQueued, que o
--   servidor liga quando o jogador entra no portal da ilha de nascimento) ou a dica para entrar no portal.
-- * ASSISTIR (botão, ou a estação no lobby): câmera que segue os sobreviventes do Desmoronamento Neon, com
--   anterior / próxima / câmera geral / voltar ao lobby. O personagem continua no lobby; o servidor só muda o
--   foco de streaming (SpectateFocus) para a arena carregar.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Strings = Config.Strings
local Settings = Config.Social

local GOLD = Color3.fromHex("FFC83D")
local PINK = Color3.fromHex("FF3D8B")
local GREEN = Color3.fromHex("3DFF8B")
local GRAPHITE = Color3.fromHex("1B1730")
local WHITE = Color3.new(1, 1, 1)

local SocialController = {}

local player = Players.LocalPlayer
local roundState = "Intermission"
local roundEndsAt = 0
local minigameName = ""

local ui: {
	status: TextLabel,
	leave: TextButton,
	watch: TextButton,
	spectate: Frame,
	watchName: TextLabel,
	watchInfo: TextLabel,
	toast: TextLabel,
}

local spectating = false
local targetIndex = 1
local overview = false
local camPos = Vector3.zero
local BIND = "HyperShowSpectate"

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function round(parent: Instance, radius: number, stroke: Color3?)
	new("UICorner", { CornerRadius = UDim.new(radius, 0) }, parent)
	if stroke then
		new("UIStroke", { Color = stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
	end
end

local function button(props: { [string]: any }, parent: Instance): TextButton
	local b = new("TextButton", {
		AutoButtonColor = true,
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextColor3 = WHITE,
	}, parent)
	for k, v in props do
		(b :: any)[k] = v
	end
	round(b, 0.3, GRAPHITE)
	new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.12, 0), PaddingLeft = UDim.new(0.06, 0), PaddingRight = UDim.new(0.06, 0) }, b)
	return b
end

local toastToken = 0
local function toast(text: string)
	toastToken += 1
	local token = toastToken
	ui.toast.Text = text
	ui.toast.Visible = true
	ui.toast.TextTransparency = 0
	ui.toast.BackgroundTransparency = 0.15
	task.delay(2.5, function()
		if token ~= toastToken then
			return
		end
		local fade = TweenService:Create(ui.toast, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		fade.Completed:Once(function()
			if token == toastToken then
				ui.toast.Visible = false
			end
		end)
		fade:Play()
	end)
end

-- Participantes vivos da partida atual (o servidor tira a marca de quem é eliminado).
local function survivors(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if p:GetAttribute("HyperShowParticipant") == true and humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
			table.insert(list, p)
		end
	end
	return list
end

local function matchRunning(): boolean
	return roundState == "Playing" or roundState == "Intro" or roundState == "Teleport" or roundState == "Qualification"
end

local function refreshPanel()
	local queued = player:GetAttribute("HyperShowQueued") == true
	-- inscrito durante um campeonato que já começou: avisa que entra no próximo
	local waitingNext = queued and workspace:GetAttribute("HyperShowTournament") == true
		and player:GetAttribute("HyperShowInTournament") ~= true
	ui.status.Text = if waitingNext then Strings.TournamentRunning
		elseif queued then Strings.Participating
		else Strings.NotParticipating
	ui.status.TextColor3 = if waitingNext then PINK elseif queued then GREEN else GOLD
	ui.leave.Visible = queued
	-- sem o botão, o texto ocupa o painel inteiro
	ui.status.Size = UDim2.fromScale(0.88, if queued then 0.42 else 0.86)
	ui.watch.Visible = matchRunning() and not spectating and player:GetAttribute("HyperShowParticipant") ~= true
end

-- Modo espectador -----------------------------------------------------------------------------
local function stopSpectating()
	if not spectating then
		return
	end
	spectating = false
	player:SetAttribute("HyperShowSpectating", nil) -- só local: a tela de classificação aparece para quem assiste
	RunService:UnbindFromRenderStep(BIND)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	ui.spectate.Visible = false
	Remotes.get("SpectateFocus"):FireServer(false)
	refreshPanel()
end

local function spectateStep(dt: number)
	local list = survivors()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local arena = Config.NeonCollapse.ArenaOrigin
	local wantPos: Vector3
	local lookAt: Vector3
	local target: Player? = nil
	if not overview and #list > 0 then
		targetIndex = (targetIndex - 1) % #list + 1
		target = list[targetIndex]
	end
	local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		-- atrás do jogador, do lado do lobby (a ilha fica no -Z da arena), um pouco acima
		lookAt = root.Position + Vector3.new(0, 2, 0)
		wantPos = root.Position + Vector3.new(0, Settings.SpectateHeight, -Settings.SpectateDistance)
		ui.watchName.Text = (target :: Player).DisplayName
	else
		lookAt = arena - Vector3.new(0, 10, 0)
		wantPos = arena + Settings.ArenaViewOffset
		ui.watchName.Text = Strings.ArenaView
	end
	camPos = if camPos == Vector3.zero then wantPos else camPos:Lerp(wantPos, 1 - math.exp(-6 * dt))
	camera.CFrame = CFrame.lookAt(camPos, lookAt)
	local seconds = math.max(0, math.ceil(roundEndsAt - workspace:GetServerTimeNow()))
	ui.watchInfo.Text = string.format("%s  •  %s%d  •  %ds", minigameName, Strings.Survivors, #list, seconds)
end

local function startSpectating()
	if spectating then
		return
	end
	if not matchRunning() then
		toast(Strings.NoMatch)
		return
	end
	if player:GetAttribute("HyperShowParticipant") == true then
		return
	end
	spectating = true
	player:SetAttribute("HyperShowSpectating", true)
	overview = false
	targetIndex = 1
	camPos = Vector3.zero
	ui.spectate.Visible = true
	Remotes.get("SpectateFocus"):FireServer(true)
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, spectateStep)
	refreshPanel()
end

-- Interface -----------------------------------------------------------------------------------
local function build()
	local gui = new("ScreenGui", { Name = "SocialHUD", ResetOnSpawn = false, DisplayOrder = 5 }, player:WaitForChild("PlayerGui"))

	-- painel de participação (lado esquerdo, acima do joystick do celular)
	local panel = new("Frame", {
		Name = "Participation",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.01, 0.4),
		Size = UDim2.fromScale(0.24, 0.16),
		BackgroundColor3 = GRAPHITE,
		BackgroundTransparency = 0.15,
	}, gui)
	round(panel, 0.2, PINK)
	new("UISizeConstraint", { MinSize = Vector2.new(170, 70), MaxSize = Vector2.new(300, 120) }, panel)
	local status = new("TextLabel", {
		Name = "Status",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.06, 0.06),
		Size = UDim2.fromScale(0.88, 0.42),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = GOLD,
		Text = "",
	}, panel)
	local leave = button({ Name = "Leave", Text = Strings.StayInLobby, BackgroundColor3 = PINK, Position = UDim2.fromScale(0.12, 0.54), Size = UDim2.fromScale(0.76, 0.38) }, panel)
	local watch = button({
		Name = "Watch",
		Text = Strings.Watch,
		BackgroundColor3 = Color3.fromHex("3D7BFF"),
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 1, 8),
		Size = UDim2.fromScale(0.7, 0.45),
		Visible = false,
	}, panel)

	-- barra do espectador (embaixo, no centro)
	local spectate = new("Frame", {
		Name = "Spectate",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.97),
		Size = UDim2.fromScale(0.62, 0.2),
		BackgroundColor3 = GRAPHITE,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, gui)
	round(spectate, 0.18, Color3.fromHex("3D7BFF"))
	new("UISizeConstraint", { MinSize = Vector2.new(320, 100), MaxSize = Vector2.new(760, 170) }, spectate)
	local watchName = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.05),
		Size = UDim2.fromScale(0.92, 0.3),
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "",
	}, spectate)
	local watchInfo = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.36),
		Size = UDim2.fromScale(0.92, 0.2),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = GOLD,
		Text = "",
	}, spectate)
	local row = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.03, 0.6), Size = UDim2.fromScale(0.94, 0.34) }, spectate)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.015, 0), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local prev = button({ Name = "Prev", Text = "◀", LayoutOrder = 1, BackgroundColor3 = Color3.fromHex("5B2BD6"), Size = UDim2.fromScale(0.14, 1) }, row)
	local nextB = button({ Name = "Next", Text = "▶", LayoutOrder = 2, BackgroundColor3 = Color3.fromHex("5B2BD6"), Size = UDim2.fromScale(0.14, 1) }, row)
	local general = button({ Name = "General", Text = Strings.ArenaView, LayoutOrder = 3, BackgroundColor3 = Color3.fromHex("3D7BFF"), Size = UDim2.fromScale(0.3, 1) }, row)
	local back = button({ Name = "Back", Text = Strings.BackToLobby, LayoutOrder = 4, BackgroundColor3 = PINK, Size = UDim2.fromScale(0.36, 1) }, row)

	local toastLabel = new("TextLabel", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.75),
		Size = UDim2.fromScale(0.5, 0.06),
		BackgroundColor3 = GRAPHITE,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = WHITE,
		Visible = false,
		Text = "",
	}, gui)
	round(toastLabel, 0.4, GOLD)
	new("UISizeConstraint", { MinSize = Vector2.new(260, 34), MaxSize = Vector2.new(620, 56) }, toastLabel)

	ui = { status = status, leave = leave, watch = watch, spectate = spectate, watchName = watchName, watchInfo = watchInfo, toast = toastLabel }

	leave.Activated:Connect(function()
		Remotes.get("LeaveQueue"):FireServer()
	end)
	watch.Activated:Connect(startSpectating)
	prev.Activated:Connect(function()
		overview = false
		targetIndex -= 1
	end)
	nextB.Activated:Connect(function()
		overview = false
		targetIndex += 1
	end)
	general.Activated:Connect(function()
		overview = not overview
	end)
	back.Activated:Connect(stopSpectating)
end

function SocialController.init()
	build()
	refreshPanel()
	player:GetAttributeChangedSignal("HyperShowQueued"):Connect(function()
		if player:GetAttribute("HyperShowQueued") == true then
			toast(Strings.JoinedToast)
		end
		refreshPanel()
	end)
	player:GetAttributeChangedSignal("HyperShowInTournament"):Connect(refreshPanel)
	workspace:GetAttributeChangedSignal("HyperShowTournament"):Connect(refreshPanel)
	player:GetAttributeChangedSignal("HyperShowParticipant"):Connect(function()
		-- virou participante (a rodada começou com ele): sai do modo espectador
		if player:GetAttribute("HyperShowParticipant") == true then
			stopSpectating()
		end
		refreshPanel()
	end)
	Remotes.get("RoundState").OnClientEvent:Connect(function(state: string, endsAt: number, info: { minigame: string? }?)
		roundState, roundEndsAt = state, endsAt
		if info and info.minigame and matchRunning() then
			minigameName = info.minigame
		end
		if state == "Results" or state == "Intermission" then
			stopSpectating()
		end
		refreshPanel()
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who ~= player then
			return
		end
		if prompt.Name == "WatchPrompt" then
			startSpectating()
		end
	end)
end

return SocialController
