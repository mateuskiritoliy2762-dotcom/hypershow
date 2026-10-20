--!strict
-- Palco do lobby: gira a roleta no estado Spin e revela minigame e modificador nos telões
-- ("PRÓXIMO MINIGAME" e "MODIFICADOR DE CAOS") quando ela para.
-- Também faz as cenas de humor do Hyper: lobby furioso (tema reversível) e volta ao normal.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HyperService = require(script.Parent.HyperService)
local MoodService = require(script.Parent.MoodService)

local Theme = Config.Mood.FuriousTheme
local Cutscene = Config.Mood.Cutscene

local StageService = {}

local disc: BasePart? = nil
local discBase: CFrame
local angle: NumberValue
local cutsceneRemote: RemoteEvent

-- Valores originais guardados quando o tema furioso entra; nil = lobby no tema normal.
type Snapshot = {
	parts: { [BasePart]: Color3 },
	props: { [Instance]: { [string]: any } }, -- propriedades soltas (iluminação, bordas dos telões, vapor)
	fx: Folder,
}
local snapshot: Snapshot? = nil

local function themedParts(): { BasePart }
	local list = {}
	for _, name in { "Lobby", "Podium", "Space", "SpawnLobby" } do
		local root = workspace:FindFirstChild(name)
		if root then
			for _, d in root:GetDescendants() do
				-- painéis invisíveis só carregam imagens (logo, medidor, roleta): ficam como estão;
				-- os espectadores da plateia mantêm pele e roupa (a arquibancada em volta deles fica vermelha)
				local spectators = d:FindFirstAncestor("Spectators")
				if d:IsA("BasePart") and d.Transparency < 1 and not spectators then
					table.insert(list, d)
				end
			end
		end
	end
	return list
end

local function furiousColor(color: Color3, neon: boolean): Color3
	local h, s, v = color:ToHSV()
	if neon then
		local warm = h > 0.09 and h < 0.2 -- dourados e amarelos
		return Color3.fromHSV(if warm then Theme.NeonWarmHue else Theme.NeonRedHue, math.max(s, 0.85), v)
	end
	return Color3.fromHSV(Theme.DarkHue, math.min(1, s * 0.8 + 0.2), v * Theme.DarkValue)
end

local function setGlass(broken: boolean)
	local lobby = workspace:FindFirstChild("Lobby")
	local meter = lobby and lobby:FindFirstChild("MoodMeter")
	local glass = meter and meter:FindFirstChild("Glass")
	local image = glass and glass:FindFirstChild("Image", true)
	if image and image:IsA("ImageLabel") then
		image.Image = if broken then Cutscene.BrokenGlassImage else Cutscene.GlassImage
	end
end

local function applyFurious()
	if snapshot then
		return
	end
	local fx = Instance.new("Folder")
	fx.Name = "FuriousFx"
	local saved: Snapshot = { parts = {}, props = {}, fx = fx }
	for _, part in themedParts() do
		saved.parts[part] = part.Color
		part.Color = furiousColor(part.Color, part.Material == Enum.Material.Neon)
	end
	local lobby = workspace:FindFirstChild("Lobby")
	local logo = lobby and lobby:FindFirstChild("Logo")
	local logoImage = logo and logo:FindFirstChildWhichIsA("ImageLabel", true)
	if logoImage then
		saved.props[logoImage] = { Image = logoImage.Image }
		logoImage.Image = Theme.LogoImage
	end
	-- bordas e "?" dos telões (SurfaceGui) e vapor dos tubos de vidro também ficam vermelhos
	for _, d in if lobby then lobby:GetDescendants() else {} do
		if d:IsA("UIStroke") and select(2, d.Color:ToHSV()) > 0.4 then
			saved.props[d] = { Color = d.Color }
			d.Color = furiousColor(d.Color, true)
		elseif d:IsA("TextLabel") and d.Name == "Content" then
			saved.props[d] = { TextColor3 = d.TextColor3 }
			d.TextColor3 = Theme.ScreenTextColor
		elseif d:IsA("ParticleEmitter") and d.Name == "Vapor" then
			saved.props[d] = { Color = d.Color }
			d.Color = ColorSequence.new(Color3.fromRGB(255, 170, 120), Theme.LightColor)
		end
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		-- névoa vermelha forte: tinge o céu de nebulosa (que não dá para recolorir) sem esconder as estrelas
		local props = {}
		for prop, value in Theme.Atmosphere do
			props[prop] = (atmosphere :: any)[prop];
			(atmosphere :: any)[prop] = value
		end
		saved.props[atmosphere] = props
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		saved.props[cc] = { TintColor = cc.TintColor }
		cc.TintColor = Theme.TintColor
	end
	-- luzes vermelhas no palco e faíscas subindo (somem na restauração)
	local stage = lobby and lobby:FindFirstChild("Stage")
	if stage and stage:IsA("BasePart") then
		for _, x in { -18, 18 } do
			local holder = Instance.new("Part")
			holder.Name = "RedLight"
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.Transparency = 1
			holder.Size = Vector3.one
			holder.Position = stage.Position + Vector3.new(x, 14, 4)
			holder.Parent = fx
			local light = Instance.new("PointLight")
			light.Color = Theme.LightColor
			light.Brightness = 3
			light.Range = 45
			light.Parent = holder
		end
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "Sparks"
		sparks.Color = ColorSequence.new(Theme.LightColor, Color3.fromRGB(255, 170, 60))
		sparks.LightEmission = 1
		sparks.Rate = 25
		sparks.Lifetime = NumberRange.new(1.5, 3)
		sparks.Speed = NumberRange.new(4, 9)
		sparks.SpreadAngle = Vector2.new(25, 25)
		sparks.Size = NumberSequence.new(0.25, 0)
		sparks.EmissionDirection = Enum.NormalId.Top
		local emitterPart = fx:FindFirstChild("RedLight") :: BasePart
		sparks.Parent = emitterPart
	end
	fx.Parent = lobby
	snapshot = saved
end

local function restoreNormal()
	local saved = snapshot
	if not saved then
		return
	end
	snapshot = nil
	for part, color in saved.parts do
		if part.Parent then
			part.Color = color
		end
	end
	for inst, props in saved.props do
		if inst.Parent then
			for prop, value in props do
				(inst :: any)[prop] = value
			end
		end
	end
	saved.fx:Destroy()
end

-- Espera até `seconds` depois do início da cena (relógio do servidor, o mesmo dos clientes).
local function waitUntil(start: number, seconds: number)
	local remaining = start + seconds - workspace:GetServerTimeNow()
	if remaining > 0 then
		task.wait(remaining)
	end
end

local runCutsceneSteps: (kind: "ToFurious" | "ToNormal") -> ()

-- Trava as falas comuns durante a cena e sempre destrava no fim, mesmo com erro.
local function runCutscene(kind: "ToFurious" | "ToNormal")
	HyperService.setCutscene(true)
	local ok, err = pcall(runCutsceneSteps, kind)
	HyperService.setCutscene(false)
	if not ok then
		error(err)
	end
end

runCutsceneSteps = function(kind: "ToFurious" | "ToNormal")
	local timeline = Cutscene[kind]
	local start = workspace:GetServerTimeNow() + 0.3 -- folga para o aviso chegar aos clientes
	cutsceneRemote:FireAllClients(kind, start)
	waitUntil(start, 0.2)
	HyperService.say(if kind == "ToFurious" then "CutsceneAngry" else "CutsceneCalm")
	waitUntil(start, timeline.GlassAt)
	setGlass(kind == "ToFurious")
	-- o tema troca no meio do giro do palco (de costas para o público)
	waitUntil(start, timeline.SpinAt + timeline.SpinTime / 2)
	if kind == "ToFurious" then
		applyFurious()
	else
		restoreNormal()
	end
	waitUntil(start, timeline.RevealAt)
	HyperService.say(if kind == "ToFurious" then "CutsceneAngryReveal" else "CutsceneCalmReveal")
	waitUntil(start, timeline.Duration)
end

local function content(screenName: string): TextLabel?
	local lobby = workspace:FindFirstChild("Lobby")
	local screen = lobby and lobby:FindFirstChild(screenName)
	local label = screen and screen:FindFirstChild("Content", true)
	return if label and label:IsA("TextLabel") then label else nil
end

-- Os telões usam tamanho de texto fixo (TextScaled para em 100 px e eles são desenhados ampliados):
-- a palavra mais longa precisa caber na largura da caixa (`widthShare` dela), o resto quebra linha.
local function fitTextSize(text: string, widthShare: number): number
	local longest = 1
	for word in string.gmatch(text, "%S+") do
		longest = math.max(longest, utf8.len(word) or #word)
	end
	return math.clamp(math.floor(Config.Stage.ScreenTextWidth * widthShare / longest), Config.Stage.ScreenTextMin, 100)
end

-- chaosId: id do modificador (ou "None"); nil = ainda não sorteado (mostra o "?" com energia)
local function setScreens(nextText: string, chaosText: string, chaosId: string?)
	local nextLabel, chaosLabel = content("NextScreen"), content("ChaosScreen")
	if nextLabel then
		nextLabel.Text = nextText
		nextLabel.TextSize = fitTextSize(nextText, 1)
	end
	if chaosLabel then
		-- o "?" já está no ícone; o nome só aparece depois do sorteio
		chaosLabel.Text = if chaosId then chaosText else ""
		chaosLabel.TextSize = fitTextSize(chaosText, 0.63)
		local icon = chaosLabel.Parent and chaosLabel.Parent:FindFirstChild("Icon")
		if icon and icon:IsA("ImageLabel") then
			icon.Image = (Config.Wheel.Icons :: { [string]: string })[chaosId or "Unknown"] or Config.Wheel.Icons.Unknown
		end
	end
end

-- Gira algumas voltas e para na fatia do resultado (Config.Wheel.Slices, mesma ordem da arte da roleta:
-- fatia 1 no topo, as outras no sentido horário). Girar o disco +X graus traz para o topo a fatia
-- que estava X graus à esquerda, então a fatia i fica no topo no ângulo -(i - 1) * passo.
local function spin(duration: number, sliceId: string)
	if not disc then
		return
	end
	local slices = Config.Wheel.Slices
	local step = 360 / #slices
	local index = table.find(slices, sliceId) or table.find(slices, "None") or 1
	local stop = (-(index - 1) * step + (math.random() - 0.5) * step * Config.Wheel.Jitter) % 360
	local base = angle.Value - angle.Value % 360
	local target = base + 360 * Config.Wheel.Turns + stop
	TweenService:Create(angle, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Value = target }):Play()
end

-- Chamado pelo RoundService a cada troca de estado.
function StageService.onState(state: string, duration: number, info: { minigame: string?, modifier: string?, modifierId: string? })
	if state == "Intermission" then
		setScreens(Config.Strings.Unknown, Config.Strings.Unknown)
	elseif state == "Spin" then
		setScreens(Config.Strings.Unknown, Config.Strings.Unknown)
		local spinTime = math.max(1, duration - 1)
		spin(spinTime, info.modifierId or "None")
		task.delay(spinTime, function()
			setScreens(info.minigame or Config.Strings.Unknown, info.modifier or Config.Strings.NoChaos, info.modifierId or "None")
		end)
	end
end

function StageService.init()
	local lobby = workspace:FindFirstChild("Lobby")
	local wheel = lobby and lobby:FindFirstChild("Wheel")
	local found = wheel and wheel:FindFirstChild("Disc")
	if found and found:IsA("BasePart") then
		disc = found
		discBase = found.CFrame
	end
	angle = Instance.new("NumberValue")
	angle.Changed:Connect(function(value: number)
		if disc then
			disc.CFrame = discBase * CFrame.Angles(0, 0, math.rad(value % 360))
		end
	end)

	cutsceneRemote = Remotes.get("MoodCutscene")
	MoodService.onTransition("ToFurious", function()
		runCutscene("ToFurious")
	end)
	MoodService.onTransition("ToNormal", function()
		runCutscene("ToNormal")
	end)
	-- rede de segurança: ao fim de cada transição, tema e vidro sempre batem com a fase
	MoodService.onChanged(function(_level, _oldLevel, phase)
		if phase == "Furious" then
			applyFurious()
			setGlass(true)
		elseif phase == "Normal" then
			restoreNormal()
			setGlass(false)
		end
	end)
end

return StageService
