--!strict
-- Interface da rodada (mobile primeiro, tudo em Scale):
-- barra de estado com contador, aviso gigante no Intro, tela de resultados e balão de fala do Hyper.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GOLD = Color3.fromHex("FFC83D")
local PINK = Color3.fromHex("FF3D8B")
local PURPLE = Color3.fromHex("5B2BD6")
local GRAPHITE = Color3.fromHex("1B1730")
local WHITE = Color3.new(1, 1, 1)

local CATEGORY_ICON: { [string]: string } = {
	Survival = Config.Icons.Skull,
	Race = Config.Icons.Trophy,
	Team = Config.Icons.Heart,
	OneVsAll = Config.Icons.Push,
}

type StateInfo = {
	minigame: string?,
	instruction: string?,
	category: string?,
	modifier: string?,
	winners: { string }?,
	phase: string?, -- campeonato: "FASE 2" / "GRANDE FINAL"
	scores: { [string]: number }?, -- pontos da partida por UserId (resultado final)
}

local UIController = {}

local refs: {
	gui: ScreenGui,
	title: TextLabel,
	timer: TextLabel,
	subtitle: TextLabel,
	banner: Frame,
	bannerIcon: ImageLabel,
	bannerText: TextLabel,
	results: Frame,
	resultsIcon: ImageLabel,
	resultsTitle: TextLabel,
	resultsNames: TextLabel,
	countdown: TextLabel,
	hyper: ImageLabel,
	hyperFace: ImageLabel,
	hyperText: TextLabel,
	hyperStroke: UIStroke,
	hyperPadding: UIPadding,
	hyperSize: UISizeConstraint,
	faceRing: Frame,
	nameTag: TextLabel,
	hyperBody: Frame,
	hyperRow: UIListLayout,
	hyperColumn: UIListLayout,
}
local endsAt = 0
local currentState = ""
local tickSound: Sound
local hyperToken = 0

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function rounded(parent: Instance, radius: number, stroke: Color3?)
	new("UICorner", { CornerRadius = UDim.new(radius, 0) }, parent)
	if stroke then
		new("UIStroke", { Color = stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
	end
end

local function label(props: { [string]: any }, parent: Instance): TextLabel
	local base = {
		BackgroundTransparency = 1,
		TextColor3 = WHITE,
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
	}
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base, parent)
end

local function build()
	local gui = new("ScreenGui", { Name = "HUD", ResetOnSpawn = false }, Players.LocalPlayer:WaitForChild("PlayerGui"))

	-- Barra superior
	local bar = new("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.01),
		Size = UDim2.fromScale(0.42, 0.09),
		BackgroundColor3 = GRAPHITE,
		BackgroundTransparency = 0.15,
	}, gui)
	rounded(bar, 0.35, PURPLE)
	new("UISizeConstraint", { MinSize = Vector2.new(260, 44) }, bar)
	local title = label({ Name = "Title", Position = UDim2.fromScale(0.05, 0.08), Size = UDim2.fromScale(0.68, 0.84), TextXAlignment = Enum.TextXAlignment.Left }, bar)
	new("ImageLabel", {
		Name = "ClockIcon",
		BackgroundTransparency = 1,
		Image = Config.Icons.Clock,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.72, 0.5),
		Size = UDim2.fromScale(0.1, 0.8),
		ScaleType = Enum.ScaleType.Fit,
	}, bar)
	local timer = label({ Name = "Timer", Position = UDim2.fromScale(0.82, 0.08), Size = UDim2.fromScale(0.15, 0.84), TextColor3 = GOLD }, bar)
	local subtitle = label({
		Name = "Subtitle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 1.05),
		Size = UDim2.fromScale(1, 0.5),
		TextStrokeTransparency = 0.2,
		Font = Enum.Font.GothamBold,
	}, bar)

	-- Aviso gigante (Intro)
	local banner = new("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56), -- abaixo do cartão de fala do Hyper
		Size = UDim2.fromScale(0.7, 0.22),
		BackgroundColor3 = PINK,
		Visible = false,
	}, gui)
	rounded(banner, 0.25, GOLD)
	new("UIAspectRatioConstraint", { AspectRatio = 4 }, banner)
	new("UIScale", { Scale = 1 }, banner)
	local bannerIcon = new("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.03, 0.1),
		Size = UDim2.fromScale(0.2, 0.8),
		ScaleType = Enum.ScaleType.Fit,
	}, banner)
	local bannerText = label({ Name = "Text", Position = UDim2.fromScale(0.25, 0.1), Size = UDim2.fromScale(0.72, 0.8), TextStrokeTransparency = 0 }, banner)

	-- Resultados
	local results = new("Frame", {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.61), -- abaixo do cartão de fala do Hyper
		Size = UDim2.fromScale(0.5, 0.4),
		BackgroundColor3 = GRAPHITE,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, gui)
	rounded(results, 0.12, GOLD)
	new("UIAspectRatioConstraint", { AspectRatio = 1.4 }, results)
	new("UIScale", { Scale = 1 }, results)
	local resultsIcon = new("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromScale(0.3, 0.32),
		ScaleType = Enum.ScaleType.Fit,
	}, results)
	local resultsTitle = label({ Name = "Title", Position = UDim2.fromScale(0.05, 0.38), Size = UDim2.fromScale(0.9, 0.16), TextColor3 = GOLD }, results)
	local resultsNames = label({ Name = "Names", Position = UDim2.fromScale(0.07, 0.57), Size = UDim2.fromScale(0.86, 0.36), Font = Enum.Font.GothamBold }, results)

	-- Contagem 5-4-3-2-1 do Intro (jogadores presos nas cápsulas olhando a arena), abaixo do aviso gigante
	local countdown = label({
		Name = "Countdown",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(0.2, 0.16),
		TextColor3 = GOLD,
		Font = Enum.Font.LuckiestGuy,
		Visible = false,
	}, gui)
	new("UIStroke", { Color = PINK, Thickness = 4 }, countdown)
	new("UIScale", { Scale = 1 }, countdown)
	tickSound = new("Sound", { Name = "CountdownTick", SoundId = Config.Sounds.Intro, Volume = 0.5 }, gui)

	-- Fala do Hyper: cartão de TV no alto, embaixo da barra (longe dos botões do celular). Tudo em layout
	-- automático (rosto à esquerda, nome e texto à direita), sem nada pendurado para fora do cartão;
	-- os tamanhos em pixels são acertados pela altura da tela a cada fala (layoutBubble).
	-- painel holográfico de TV (arte do ForgeGUI, arte/campeonato/balao.png) fatiado em 9 partes: os cantos
	-- dourados ficam do mesmo tamanho e o meio estica com o texto
	local hyper = new("ImageLabel", {
		Name = "HyperBubble",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.165),
		Size = UDim2.new(0.46, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Image = Config.Icons.SpeechPanel,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(170, 130, 854, 316),
		Visible = false,
	}, gui)
	-- borda extra só para o modo bravo (fica desligada no normal; a arte já tem a moldura neon)
	local hyperStroke = new("UIStroke", { Color = PINK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Enabled = false }, hyper)
	new("UICorner", { CornerRadius = UDim.new(0, 18) }, hyper)
	local hyperSize = new("UISizeConstraint", { MinSize = Vector2.new(280, 0), MaxSize = Vector2.new(640, math.huge) }, hyper)
	local hyperPadding = new("UIPadding", {}, hyper)
	new("UIScale", { Scale = 1 }, hyper)
	local row = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, hyper)
	local faceRing = new("Frame", {
		Name = "FaceRing",
		LayoutOrder = 1,
		BackgroundColor3 = Color3.new(0, 0, 0),
	}, hyper)
	-- moldura de TV (como a cabeça do Hyper): a arte do rosto já vem com cantos amarelos de moldura,
	-- então a imagem é recortada para mostrar só a tela e preenche a moldura toda
	new("UICorner", { CornerRadius = UDim.new(0.22, 0) }, faceRing)
	new("UIStroke", { Color = GOLD, Thickness = 3 }, faceRing)
	local hyperFace = new("ImageLabel", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Stretch,
		ImageRectOffset = Vector2.new(18, 14),
		ImageRectSize = Vector2.new(308, 198),
	}, faceRing)
	new("UICorner", { CornerRadius = UDim.new(0.22, 0) }, hyperFace)
	local body = new("Frame", {
		Name = "Body",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, hyper)
	local column = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, body)
	local nameTag = new("TextLabel", {
		Name = "NameTag",
		LayoutOrder = 1,
		BackgroundColor3 = GOLD,
		TextColor3 = GRAPHITE,
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		Text = Config.Strings.HyperName,
	}, body)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, nameTag)
	new("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.06, 0) }, nameTag)
	local hyperText = new("TextLabel", {
		Name = "Text",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = WHITE,
		Font = Enum.Font.FredokaOne,
		Text = "",
	}, body)

	refs = {
		gui = gui,
		title = title,
		timer = timer,
		subtitle = subtitle,
		banner = banner,
		bannerIcon = bannerIcon,
		bannerText = bannerText,
		results = results,
		resultsIcon = resultsIcon,
		resultsTitle = resultsTitle,
		resultsNames = resultsNames,
		countdown = countdown,
		hyper = hyper,
		hyperFace = hyperFace,
		hyperText = hyperText,
		hyperStroke = hyperStroke,
		hyperPadding = hyperPadding,
		hyperSize = hyperSize,
		faceRing = faceRing,
		nameTag = nameTag,
		hyperBody = body,
		hyperRow = row,
		hyperColumn = column,
	}
end

-- Entrada com "pulo": escala de 0 até 1.
local function popIn(frame: GuiObject)
	local scale = frame:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.2
	frame.Visible = true
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function UIController.render(state: string, newEndsAt: number, info: StateInfo)
	endsAt = newEndsAt
	currentState = state
	local strings = Config.Strings :: { [string]: string }
	refs.title.Text = strings[state] or state

	local parts = {}
	if info.phase then
		table.insert(parts, info.phase)
	end
	if info.minigame then
		table.insert(parts, info.minigame)
	end
	if info.modifier then
		table.insert(parts, Config.Strings.ChaosPrefix .. info.modifier)
	end
	-- Durante a roleta não revela nada: os telões do palco mostram o resultado quando ela para.
	refs.subtitle.Text = if state == "Spin" then "" else table.concat(parts, "  •  ")

	if state == "Intro" and info.instruction then
		refs.bannerText.Text = info.instruction
		refs.bannerIcon.Image = CATEGORY_ICON[info.category or ""] or Config.Icons.Clock
		popIn(refs.banner)
	else
		refs.banner.Visible = false
	end

	if state == "Results" then
		local winners = info.winners or {}
		local won = #winners > 0
		refs.resultsIcon.Image = if won then Config.Icons.Trophy else Config.Icons.Skull
		refs.resultsTitle.Text = if won then Config.Strings.Winners else Config.Strings.NoWinners
		local lines = table.clone(winners)
		local myPoints = info.scores and info.scores[tostring(Players.LocalPlayer.UserId)]
		if myPoints then
			table.insert(lines, string.format(Config.Strings.PointsFormat, myPoints))
		end
		refs.resultsNames.Text = table.concat(lines, "\n")
		popIn(refs.results)
	else
		refs.results.Visible = false
	end
end

-- Tamanhos do cartão pela altura da tela atual (no começo do jogo a câmera ainda não tem o tamanho real).
local function layoutBubble()
	local textSize = math.clamp(math.floor(workspace.CurrentCamera.ViewportSize.Y * 0.032), 16, 28)
	local faceSize = math.floor(textSize * 2.6)
	local gap = math.floor(textSize * 0.6)
	-- cantos da arte com ~3 letras de largura; o conteúdo fica para dentro da moldura neon
	local bubble = refs.hyper :: any
	bubble.SliceScale = textSize * 2.4 / 170
	local inset = math.floor(textSize * 1.2)
	refs.hyperPadding.PaddingLeft = UDim.new(0, inset)
	refs.hyperPadding.PaddingRight = UDim.new(0, inset)
	refs.hyperPadding.PaddingTop = UDim.new(0, inset)
	refs.hyperPadding.PaddingBottom = UDim.new(0, inset)
	refs.hyperRow.Padding = UDim.new(0, gap)
	refs.hyperColumn.Padding = UDim.new(0, math.floor(gap * 0.5))
	local faceWidth = math.floor(faceSize * 1.5) -- proporção da tela do rosto (308 x 198)
	refs.faceRing.Size = UDim2.fromOffset(faceWidth, faceSize)
	refs.hyperBody.Size = UDim2.new(1, -(faceWidth + gap), 0, 0)
	refs.nameTag.Size = UDim2.fromOffset(textSize * 4.4, math.floor(textSize * 1.25))
	refs.hyperText.TextSize = textSize
	refs.hyperSize.MinSize = Vector2.new(280, faceSize + inset * 2)
end

-- Rostos bravos deixam a borda do cartão vermelha.
local ANGRY_FACES = { Irritated = true, Angry = true, Furious = true, Evil = true }

function UIController.hyperSays(line: string, faceKey: string, duration: number)
	layoutBubble()
	-- com "Efeitos da fala": símbolo da emoção na frente e texto letra por letra; sem, o texto aparece inteiro
	local fxOn = Players.LocalPlayer:GetAttribute("HyperShowSpeechFx") ~= false
	local symbols = Config.Hyper.SpeechFx.Symbols[faceKey]
	if fxOn and symbols then
		line = symbols[1] .. "  " .. line
	end
	refs.hyperText.Text = line
	refs.hyperFace.Image = (Config.Hyper.Faces :: { [string]: string })[faceKey] or ""
	local angry = ANGRY_FACES[faceKey] == true
	refs.hyperStroke.Enabled = angry
	refs.hyperStroke.Color = Color3.fromHex("FF2E3D")
	refs.hyper.ImageColor3 = if angry then Color3.fromHex("FFB0B0") else WHITE
	local letters = utf8.len(line) or #line
	if fxOn then
		refs.hyperText.MaxVisibleGraphemes = 0
		TweenService:Create(refs.hyperText, TweenInfo.new(math.min(duration * 0.5, letters * Config.Hyper.Dialog.TypeSpeed), Enum.EasingStyle.Linear), { MaxVisibleGraphemes = letters }):Play()
	else
		refs.hyperText.MaxVisibleGraphemes = -1
	end
	popIn(refs.hyper)
	hyperToken += 1
	local token = hyperToken
	task.delay(duration, function()
		if token ~= hyperToken then
			return
		end
		local scale = refs.hyper:FindFirstChildOfClass("UIScale") :: UIScale
		local out = TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		out.Completed:Once(function()
			if token == hyperToken then
				refs.hyper.Visible = false
			end
		end)
		out:Play()
	end)
end

function UIController.init()
	build()
	Remotes.get("RoundState").OnClientEvent:Connect(UIController.render)
	Remotes.get("HyperSays").OnClientEvent:Connect(UIController.hyperSays)
	Remotes.get("RoundStateRequest"):FireServer()

	task.spawn(function()
		local lastCount = 0
		while true do
			local seconds = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			refs.timer.Text = if endsAt > 0 then tostring(seconds) else ""
			-- contagem grande: um "pulo" e um bipe a cada segundo do Intro
			local count = if currentState == "Intro" and endsAt > 0 then seconds else 0
			if count ~= lastCount then
				lastCount = count
				if count > 0 then
					refs.countdown.Text = tostring(count)
					popIn(refs.countdown)
					tickSound:Play()
				else
					refs.countdown.Visible = false
				end
			end
			task.wait(0.1)
		end
	end)
end

return UIController
