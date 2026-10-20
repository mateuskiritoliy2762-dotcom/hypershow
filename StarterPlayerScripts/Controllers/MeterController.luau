--!strict
-- Cliente: anima o ponteiro do medidor de paciência (Lobby.MoodMeter) a partir do estresse do servidor.
-- Movimento suave com TweenService e tremores breves, mais frequentes conforme o nível de irritação.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Meter = Config.Mood.Meter

type MoodState = { stress: number, level: number, phase: string }

local MeterController = {}

local pointer: BasePart? = nil
local pivot: BasePart? = nil
local angle = Instance.new("NumberValue") -- ângulo atual do ponteiro, interpolado
local jitter = 0
local level = 1
local moveTween: Tween? = nil

local function angleFor(stress: number): number
	-- 0 de estresse = ponta esquerda (muito feliz), 100 = ponta direita (furioso)
	return -Meter.MaxAngle + 2 * Meter.MaxAngle * math.clamp(stress / Config.Mood.MaxStress, 0, 1)
end

local function render()
	if pointer and pivot then
		pointer.CFrame = pivot.CFrame * CFrame.Angles(0, 0, math.rad(angle.Value + jitter)) * CFrame.new(0, pointer.Size.Y / 2, 0)
	end
end

local function apply(state: MoodState)
	level = state.level
	local target = angleFor(state.stress)
	local distance = math.abs(target - angle.Value) / (2 * Meter.MaxAngle) * Config.Mood.MaxStress
	if moveTween then
		moveTween:Cancel()
	end
	local tween = TweenService:Create(angle, TweenInfo.new(Meter.TweenBase + distance * Meter.TweenPerPoint, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = target })
	moveTween = tween
	tween:Play()
end

-- Um único laço de tremores; espera conforme o nível e não faz nada quando o Hyper está calmo.
local function tremorLoop()
	while true do
		local tremor = Meter.Tremor[level]
		if not tremor then
			task.wait(0.5)
			continue
		end
		task.wait(tremor.every.Min + math.random() * (tremor.every.Max - tremor.every.Min))
		for i = 1, 6 do
			jitter = tremor.amplitude * (if i % 2 == 0 then 1 else -1) * (1 - i / 7)
			render()
			task.wait(0.035)
		end
		jitter = 0
		render()
	end
end

function MeterController.init()
	local lobby = workspace:WaitForChild("Lobby", 30)
	local meter = lobby and lobby:WaitForChild("MoodMeter", 30)
	local foundPointer = meter and meter:WaitForChild("Pointer", 10)
	local foundPivot = meter and meter:WaitForChild("Pivot", 10)
	if not (foundPointer and foundPointer:IsA("BasePart") and foundPivot and foundPivot:IsA("BasePart")) then
		warn("[Meter] medidor não encontrado no Lobby")
		return
	end
	pointer, pivot = foundPointer, foundPivot
	angle.Value = angleFor(Config.Mood.StartStress)
	angle.Changed:Connect(render)
	render()

	Remotes.get("MoodState").OnClientEvent:Connect(apply)
	Remotes.get("MoodStateRequest"):FireServer()
	task.spawn(tremorLoop)
end

return MeterController
