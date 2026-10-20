--!strict
-- Tela de classificação do campeonato (estado Qualification): "RODADA ENCERRADA!", grade com os bonecos
-- de quem jogou a fase, os eliminados caem da tela e os classificados ganham o selo verde.
-- Só mostra o resultado que o servidor já decidiu (info.roster). Aparece para quem jogou a fase e para
-- quem está assistindo (atributo local HyperShowSpectating, ligado pelo SocialController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Strings = Config.Strings
local Icons = Config.Icons

local GOLD = Color3.fromHex("FFC83D")
local GREEN = Color3.fromHex("3DFF8B")
local RED = Color3.fromHex("FF2E3D")
local WHITE = Color3.new(1, 1, 1)
local CARD_ASPECT = 585 / 768

type Info = {
	minigame: string?,
	phase: string?,
	roster: { Types.QualificationEntry }?,
	qualifiedCount: number?,
	eliminatedCount: number?,
}

local EliminationController = {}

local player = Players.LocalPlayer
local refs: {
	gui: ScreenGui,
	backdrop: Frame,
	plate: ImageLabel,
	plateText: TextLabel,
	subtitle: TextLabel,
	grid: Frame,
	layout: UIGridLayout,
	count: TextLabel,
	personal: TextLabel,
}
local token = 0
local fallSound: Sound
local revealSound: Sound

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function label(props: { [string]: any }, parent: Instance): TextLabel
	local base = {
		BackgroundTransparency = 1,
		TextColor3 = WHITE,
		TextScaled = true,
		Font = Enum.Font.LuckiestGuy,
		TextStrokeTransparency = 0.1,
	}
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base, parent)
end

local function build()
	local gui = new("ScreenGui", {
		Name = "Qualification",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10, -- acima do HUD
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	local backdrop = new("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("0B0618"),
		BackgroundTransparency = 1,
	}, gui)
	local plate = new("ImageLabel", {
		Name = "Plate",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.6, 0.25),
		BackgroundTransparency = 1,
		Image = Icons.TitlePlate,
		ScaleType = Enum.ScaleType.Fit,
	}, gui)
	new("UIAspectRatioConstraint", { AspectRatio = 1024 / 457 }, plate)
	new("UIScale", { Scale = 1 }, plate)
	local plateText = label({ Name = "Text", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.36) }, plate)
	local subtitle = label({
		Name = "Subtitle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.265),
		Size = UDim2.fromScale(0.6, 0.045),
		TextColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
	}, gui)
	-- área da grade: cada célula é um suporte; o card dentro dele é que cai (a grade não segura a animação)
	local grid = new("Frame", {
		Name = "Grid",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromScale(0.9, 0.46),
		BackgroundTransparency = 1,
	}, gui)
	local layout = new("UIGridLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local count = label({
		Name = "Count",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(0.6, 0.08),
		Visible = false,
	}, gui)
	new("UIScale", { Scale = 1 }, count)
	local personal = label({
		Name = "Personal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.89),
		Size = UDim2.fromScale(0.6, 0.06),
		Font = Enum.Font.GothamBlack,
		Visible = false,
	}, gui)
	new("UIScale", { Scale = 1 }, personal)

	fallSound = new("Sound", { Name = "QualificationFall", SoundId = Config.Sounds.Fall, Volume = 0.5 }, SoundService)
	revealSound = new("Sound", { Name = "QualificationReveal", SoundId = Config.Sounds.Intro, Volume = 0.5 }, SoundService)

	refs = {
		gui = gui,
		backdrop = backdrop,
		plate = plate,
		plateText = plateText,
		subtitle = subtitle,
		grid = grid,
		layout = layout,
		count = count,
		personal = personal,
	}
end

local function popIn(object: GuiObject)
	local scale = object:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.2
	object.Visible = true
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Card de um participante: moldura de TV, boneco (miniatura do avatar), nome e selo escondido.
local function makeCard(entry: Types.QualificationEntry, order: number): (ImageLabel, ImageLabel)
	local holder = new("Frame", { Name = "Cell", LayoutOrder = order, BackgroundTransparency = 1 }, refs.grid)
	local card = new("ImageLabel", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Icons.AvatarCard,
		ScaleType = Enum.ScaleType.Fit,
	}, holder)
	new("UIAspectRatioConstraint", { AspectRatio = CARD_ASPECT }, card)
	new("UIScale", { Scale = 0 }, card)
	local avatar = new("ImageLabel", {
		Name = "Avatar",
		Position = UDim2.fromScale(0.16, 0.16),
		Size = UDim2.fromScale(0.68, 0.56),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
	}, card)
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(entry.id, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)
		end)
		if ok and avatar.Parent then
			avatar.Image = image
		end
	end)
	label({
		Name = "Name",
		Position = UDim2.fromScale(0.12, 0.73),
		Size = UDim2.fromScale(0.76, 0.1),
		Text = entry.name,
		TextColor3 = if entry.id == player.UserId then GOLD else WHITE,
		Font = Enum.Font.GothamBlack,
	}, card)
	local badge = new("ImageLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.82, 0.16),
		Size = UDim2.fromScale(0.42, 0.42 * CARD_ASPECT),
		BackgroundTransparency = 1,
		Image = if entry.qualified then Icons.Qualified else Icons.Eliminated,
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	}, card)
	new("UIScale", { Scale = 1 }, badge)
	return card, badge
end

local function clearGrid()
	for _, child in refs.grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function hide()
	token += 1
	refs.gui.Enabled = false
	clearGrid()
end

local function show(endsAt: number, info: Info)
	token += 1
	local myToken = token
	local function alive(): boolean
		return myToken == token
	end
	-- ordem embaralhada na tela: a ordem do servidor (classificados primeiro) entregaria o resultado
	local roster = table.clone(info.roster or {})
	for i = #roster, 2, -1 do
		local j = math.random(1, i)
		roster[i], roster[j] = roster[j], roster[i]
	end
	clearGrid()

	-- grade: até 6 por linha (12 jogadores = 2 linhas de 6); cards colados, no maior tamanho que couber
	local n = math.max(1, #roster)
	local columns = if n <= 6 then n else math.ceil(n / math.ceil(n / 6))
	local rows = math.ceil(n / columns)
	local area = refs.grid.AbsoluteSize
	local gap = math.floor(area.Y * 0.04)
	local cellH = (area.Y - gap * (rows - 1)) / rows
	local cellW = cellH * CARD_ASPECT
	local maxW = (area.X - gap * (columns - 1)) / columns
	if cellW > maxW then
		cellW, cellH = maxW, maxW / CARD_ASPECT
	end
	refs.layout.FillDirectionMaxCells = columns
	refs.layout.CellPadding = UDim2.fromOffset(gap, gap)
	refs.layout.CellSize = UDim2.fromOffset(math.floor(cellW), math.floor(cellH))

	refs.plateText.Text = Strings.RoundOver
	refs.subtitle.Text = table.concat({ info.phase or "", info.minigame or "" }, "  •  ")
	refs.count.Visible = false
	refs.personal.Visible = false
	refs.backdrop.BackgroundTransparency = 1
	refs.gui.Enabled = true
	TweenService:Create(refs.backdrop, TweenInfo.new(0.4), { BackgroundTransparency = 0.12 }):Play()
	popIn(refs.plate)
	revealSound:Play()

	local cards: { { card: ImageLabel, badge: ImageLabel, entry: Types.QualificationEntry } } = {}
	for i, entry in roster do
		local card, badge = makeCard(entry, i)
		table.insert(cards, { card = card, badge = badge, entry = entry })
		task.delay(0.5 + i * 0.05, function()
			if alive() then
				TweenService:Create(card:FindFirstChildOfClass("UIScale") :: UIScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
		end)
	end

	local eliminated = info.eliminatedCount or 0
	local qualified = info.qualifiedCount or 0
	local mine: Types.QualificationEntry? = nil
	for _, entry in roster do
		if entry.id == player.UserId then
			mine = entry
		end
	end

	-- 1) quantos caem
	task.delay(2, function()
		if not alive() then return end
		refs.count.Text = if eliminated == 0 then Strings.NoneEliminated
			elseif eliminated == 1 then Strings.EliminatedOne
			else string.format(Strings.EliminatedCount, eliminated)
		refs.count.TextColor3 = if eliminated == 0 then GREEN else RED
		popIn(refs.count)
	end)

	-- 2) os eliminados ganham o X, tremem e caem para fora da tela
	local fallIndex = 0
	for _, item in cards do
		if item.entry.qualified then
			continue
		end
		fallIndex += 1
		local delayTime = 2.8 + fallIndex * 0.18
		task.delay(delayTime, function()
			if not alive() then return end
			popIn(item.badge)
			local card = item.card
			local side = if fallIndex % 2 == 0 then 1 else -1
			TweenService:Create(card, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), { Rotation = 6 * side }):Play()
			task.delay(0.5, function()
				if not alive() then return end
				fallSound:Play()
				TweenService:Create(card, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.fromScale(0.5 + 0.4 * side, 3.2),
					Rotation = 70 * side,
					ImageTransparency = 0.4,
				}):Play()
			end)
		end)
	end

	-- 3) selo verde dos classificados e o total
	local qualifyAt = 2.8 + fallIndex * 0.18 + 1.6
	task.delay(qualifyAt, function()
		if not alive() then return end
		refs.count.Text = if qualified == 1 then Strings.QualifiedOne else string.format(Strings.QualifiedCount, qualified)
		refs.count.TextColor3 = GREEN
		popIn(refs.count)
		local index = 0
		for _, item in cards do
			if item.entry.qualified then
				index += 1
				task.delay(index * 0.06, function()
					if alive() then
						popIn(item.badge)
					end
				end)
			end
		end
	end)

	-- 4) recado para quem jogou
	local entry = mine
	if entry then
		task.delay(qualifyAt + 0.8, function()
			if not alive() then return end
			refs.personal.Text = if entry.qualified then Strings.YouQualified else Strings.YouEliminated
			refs.personal.TextColor3 = if entry.qualified then GREEN else RED
			popIn(refs.personal)
		end)
	end

	-- some um pouco antes de a próxima fase começar
	local remaining = endsAt - workspace:GetServerTimeNow()
	task.delay(math.max(1, remaining - 0.4), function()
		if alive() then
			hide()
		end
	end)
end

local function onRoundState(state: string, endsAt: number, info: Info)
	if state ~= "Qualification" then
		if refs.gui.Enabled then
			hide()
		end
		return
	end
	local inRoster = false
	for _, entry in info.roster or {} do
		if entry.id == player.UserId then
			inRoster = true
		end
	end
	if inRoster or player:GetAttribute("HyperShowSpectating") == true then
		show(endsAt, info)
	end
end

function EliminationController.init()
	build()
	Remotes.get("RoundState").OnClientEvent:Connect(onRoundState)
end

return EliminationController
