--!strict
-- Cliente: anima o Hyper como apresentador de auditório. Só visual e local: o servidor manda as falas
-- (HyperSays), o estado da rodada (RoundState) e o humor (MoodState); aqui viram poses e gestos.
-- Cada parte (cabeça, corpo, braços, microfone) é recalculada a partir da posição de descanso a cada quadro.
-- O microfone fica preso na mão direita; ao falar o braço o leva até a boca e o outro braço gesticula.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Anim = Config.Hyper.Anim

-- Pose em graus. Braço: forward = erguer para a plateia, out = abrir para o lado, twist = girar no eixo.
type Arm = { forward: number, out: number, twist: number }
type Pose = { right: Arm, left: Arm, nod: number, tilt: number, lean: number, yaw: number }
type Step = { pose: Pose, time: number, wave: number?, shake: number?, hop: boolean? }

local function arm(forward: number, out: number, twist: number?): Arm
	return { forward = forward, out = out, twist = twist or 0 }
end

local function pose(right: Arm, left: Arm, extra: { nod: number?, tilt: number?, lean: number?, yaw: number? }?): Pose
	local e = extra or {}
	return { right = right, left = left, nod = e.nod or 0, tilt = e.tilt or 0, lean = e.lean or 0, yaw = e.yaw or 0 }
end

-- Braço direito: microfone perto do peito (parado) ou na boca (falando).
local MIC_CHEST = arm(48, -12, 10)
local MIC_MOUTH = arm(72, -18, 20)

local POSES = {
	idle = pose(MIC_CHEST, arm(6, 8)),
	talk = pose(MIC_MOUTH, arm(14, 14)),
	open = pose(MIC_MOUTH, arm(45, 70), { tilt = -6 }),
	pointCrowd = pose(MIC_MOUTH, arm(88, 12), { lean = 6, nod = 4 }),
	pointUp = pose(MIC_MOUTH, arm(165, 18), { nod = -8 }),
	wave = pose(MIC_MOUTH, arm(20, 150), { tilt = 6 }),
	fist = pose(MIC_MOUTH, arm(150, 25), { nod = -6 }),
	shrug = pose(arm(40, -40), arm(40, 40), { tilt = 10 }),
	sad = pose(arm(30, -6), arm(4, 4), { nod = 14, lean = 4 }),
	shocked = pose(arm(70, -55), arm(70, 55), { nod = -10, lean = -6 }),
	angry = pose(MIC_MOUTH, arm(70, 30), { lean = 8, nod = 6 }),
	pointWheel = pose(MIC_CHEST, arm(80, 75), { yaw = 18, tilt = 4 }),
	celebrate = pose(arm(165, -25), arm(165, 25), { nod = -12 }),
	furiousIdle = pose(arm(55, -20, 10), arm(40, 20), { lean = 6, nod = 4 }),
}

-- Gestos por emoção do rosto da fala (o servidor escolhe o rosto).
local GESTURES: { [string]: { { Step } } } = {
	Happy = {
		{ { pose = POSES.open, time = 1.1, hop = true }, { pose = POSES.pointCrowd, time = 1.2 }, { pose = POSES.talk, time = 1 } },
		{ { pose = POSES.wave, time = 1.4, wave = 1 }, { pose = POSES.open, time = 1.2 } },
		{ { pose = POSES.pointCrowd, time = 1 }, { pose = POSES.open, time = 1.2, hop = true } },
	},
	Laughing = {
		{ { pose = POSES.shrug, time = 0.8, shake = 0.5 }, { pose = POSES.open, time = 1.2, hop = true } },
		{ { pose = POSES.fist, time = 1, hop = true }, { pose = POSES.wave, time = 1.2, wave = 1 } },
	},
	Shocked = { { { pose = POSES.shocked, time = 1.4, hop = true }, { pose = POSES.open, time = 1 } } },
	Countdown = { { { pose = POSES.pointUp, time = 1.6 }, { pose = POSES.pointCrowd, time = 1 } } },
	Evil = { { { pose = POSES.angry, time = 1.2 }, { pose = POSES.pointCrowd, time = 1.2 } } },
	Sad = { { { pose = POSES.sad, time = 2.2 } } },
	Neutral = { { { pose = POSES.talk, time = 1.2 }, { pose = POSES.open, time = 1.2 } } },
	Irritated = { { { pose = POSES.shrug, time = 1.2 }, { pose = POSES.pointCrowd, time = 1.2 } } },
	Angry = { { { pose = POSES.angry, time = 0.8, shake = 1 }, { pose = POSES.fist, time = 1.2, shake = 1, hop = true } } },
	Furious = { { { pose = POSES.fist, time = 0.8, shake = 1.5, hop = true }, { pose = POSES.angry, time = 1.2, shake = 1.5, hop = true } } },
}

local HyperController = {}

type Rest = { part: BasePart, cf: CFrame }
local rest: { [string]: Rest } = {}
local micParts: { Rest } = {} -- CFrame de cada peça do microfone em relação ao punho
local micGrip = CFrame.identity -- microfone em relação ao braço direito
local feet = Vector3.zero
local neck = Vector3.zero
local shoulders: { [string]: Vector3 } = { right = Vector3.zero, left = Vector3.zero }

local current: Pose = POSES.idle
local velocity: Pose = { right = { forward = 0, out = 0, twist = 0 }, left = { forward = 0, out = 0, twist = 0 }, nod = 0, tilt = 0, lean = 0, yaw = 0 }
local look, lookVelocity, lookTarget, nextLook = 0, 0, 0, 0
local target: Pose = POSES.idle
local wave, shake = 0, 0
local hopStart = -10
local talking = false
local talkUntil = 0
local sequenceId = 0
local roundState = "Intermission"
local furious = false
local stageRotation = CFrame.identity

local function lerpArm(a: Arm, b: Arm, t: number): Arm
	return { forward = a.forward + (b.forward - a.forward) * t, out = a.out + (b.out - a.out) * t, twist = a.twist + (b.twist - a.twist) * t }
end

local function lerpPose(a: Pose, b: Pose, t: number): Pose
	return {
		right = lerpArm(a.right, b.right, t),
		left = lerpArm(a.left, b.left, t),
		nod = a.nod + (b.nod - a.nod) * t,
		tilt = a.tilt + (b.tilt - a.tilt) * t,
		lean = a.lean + (b.lean - a.lean) * t,
		yaw = a.yaw + (b.yaw - a.yaw) * t,
	}
end

-- Mola amortecida para um número: devolve posição e velocidade novas (passos curtos para ficar estável).
local function spring(x: number, v: number, goal: number, dt: number): (number, number)
	local k = Anim.SpringStiffness
	local c = 2 * Anim.SpringDamping * math.sqrt(k)
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		v += (k * (goal - x) - c * v) * h
		x += v * h
	end
	return x, v
end

local function springArm(a: Arm, va: Arm, b: Arm, dt: number)
	a.forward, va.forward = spring(a.forward, va.forward, b.forward, dt)
	a.out, va.out = spring(a.out, va.out, b.out, dt)
	a.twist, va.twist = spring(a.twist, va.twist, b.twist, dt)
end

-- Leva a pose atual até a alvo com mola (passa um pouquinho e volta), em vez de chegar em linha reta.
local ownsCurrent = false
local function springPose(dt: number)
	if not ownsCurrent then
		current = lerpPose(current, current, 0) -- cópia própria: a mola altera os campos, nunca as POSES
		ownsCurrent = true
	end
	springArm(current.right, velocity.right, target.right, dt)
	springArm(current.left, velocity.left, target.left, dt)
	current.nod, velocity.nod = spring(current.nod, velocity.nod, target.nod, dt)
	current.tilt, velocity.tilt = spring(current.tilt, velocity.tilt, target.tilt, dt)
	current.lean, velocity.lean = spring(current.lean, velocity.lean, target.lean, dt)
	current.yaw, velocity.yaw = spring(current.yaw, velocity.yaw, target.yaw, dt)
end

-- Efeitos da fala: símbolos (emojis) subindo da cabeça e ondas de som saindo do microfone.
local fxFolder: Folder? = nil
local function speechFxOn(): boolean
	return Players.LocalPlayer:GetAttribute("HyperShowSpeechFx") ~= false
end

local function emitSymbols(face: string)
	local headRest = rest.Head
	if not headRest or not fxFolder then
		return
	end
	local fx = Config.Hyper.SpeechFx
	local list = fx.Symbols[face] or fx.Symbols.Happy
	for i = 1, fx.SymbolsPerLine do
		task.delay((i - 1) * 0.25, function()
			local head = headRest.part
			local anchor = Instance.new("Part")
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.one * 0.2
			local start = head.Position + Vector3.new(math.random(-30, 30) / 10, head.Size.Y * 0.6, math.random(5, 15) / 10)
			anchor.Position = start
			anchor.Parent = fxFolder
			local board = Instance.new("BillboardGui")
			board.Size = UDim2.fromScale(3, 3)
			board.LightInfluence = 0
			board.Parent = anchor
			local glyph = Instance.new("TextLabel")
			glyph.Size = UDim2.fromScale(1, 1)
			glyph.BackgroundTransparency = 1
			glyph.TextScaled = true
			glyph.Text = list[math.random(1, #list)]
			glyph.Parent = board
			local info = TweenInfo.new(fx.SymbolTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(anchor, info, { Position = start + Vector3.new(math.random(-15, 15) / 10, fx.SymbolRise, 0) }):Play()
			TweenService:Create(glyph, TweenInfo.new(fx.SymbolTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
			TweenService:Create(board, info, { Size = UDim2.fromScale(4.2, 4.2) }):Play()
			task.delay(fx.SymbolTime + 0.1, function()
				anchor:Destroy()
			end)
		end)
	end
end

local ANGRY = { Irritated = true, Angry = true, Furious = true, Evil = true }
local function emitWaves(face: string, duration: number)
	local headRest = rest.Head
	if not headRest or not fxFolder then
		return
	end
	local fx = Config.Hyper.SpeechFx
	for i = 1, fx.Waves do
		task.delay((i - 1) * math.min(0.5, duration / fx.Waves), function()
			local head = headRest.part
			local ring = Instance.new("Part")
			ring.Shape = Enum.PartType.Cylinder
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CanTouch = false
			ring.CastShadow = false
			ring.Material = Enum.Material.Neon
			ring.Color = if ANGRY[face] then fx.WaveColorAngry else fx.WaveColor
			ring.Transparency = 0.35
			ring.Size = Vector3.new(0.1, 1.5, 1.5)
			-- disco virado para a plateia (+Z), na frente da boca
			local mouth = head.Position + Vector3.new(Anim.MouthOffset.X, Anim.MouthOffset.Y, Anim.MouthOffset.Z + 0.6)
			ring.CFrame = CFrame.new(mouth) * CFrame.Angles(0, math.rad(90), 0)
			ring.Parent = fxFolder
			local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(ring, info, { Size = Vector3.new(0.1, 9, 9), Transparency = 1, CFrame = ring.CFrame * CFrame.new(-2.5, 0, 0) }):Play()
			task.delay(1, function()
				ring:Destroy()
			end)
		end)
	end
end

local function about(point: Vector3, rotation: CFrame): CFrame
	return CFrame.new(point) * rotation * CFrame.new(-point)
end

-- Rotação do braço em volta do ombro. O lado esquerdo do Hyper fica em +X (ele olha para +Z).
local function armRotation(a: Arm, side: number): CFrame
	return CFrame.Angles(-math.rad(a.forward), math.rad(a.twist) * side, math.rad(a.out) * side)
end

-- Pose de base quando ninguém está falando, conforme o momento da rodada e o humor.
local function basePose(): Pose
	if furious then
		return POSES.furiousIdle
	elseif roundState == "Spin" then
		return POSES.pointWheel
	end
	return POSES.idle
end

local function playSequence(steps: { Step })
	sequenceId += 1
	local id = sequenceId
	task.spawn(function()
		for _, step in steps do
			if id ~= sequenceId then
				return
			end
			target = step.pose
			wave = step.wave or 0
			shake = step.shake or 0
			if step.hop then
				hopStart = os.clock()
			end
			task.wait(step.time)
		end
		if id == sequenceId then
			-- terminou o gesto: segue falando com o microfone na boca até a fala acabar
			wave, shake = 0, if furious then 0.6 else 0
			target = if os.clock() < talkUntil then POSES.talk else basePose()
		end
	end)
end

local function onSays(_line: string, face: string, duration: number)
	if speechFxOn() then
		emitSymbols(face)
		emitWaves(face, duration)
	end
	talking = true
	talkUntil = os.clock() + duration
	local options = GESTURES[face] or GESTURES.Happy
	playSequence(options[math.random(1, #options)])
	task.delay(duration, function()
		if os.clock() >= talkUntil - 0.05 then
			talking = false
			sequenceId += 1
			wave, shake = 0, if furious then 0.6 else 0
			target = basePose()
		end
	end)
end

local function onRoundState(state: string, _endsAt: number, info: { winners: { string }? }?)
	roundState = state
	if state == "Results" and info and info.winners and #info.winners > 0 then
		playSequence({ { pose = POSES.celebrate, time = 2.5, wave = 0.6, hop = true }, { pose = POSES.open, time = 1.5, hop = true } })
	elseif not talking then
		sequenceId += 1
		target = basePose()
	end
end

local function onMood(state: { phase: string })
	furious = state.phase == "Furious" or state.phase == "ToFurious"
	if not talking then
		shake = if furious then 0.6 else 0
		target = basePose()
	end
end

-- O CutsceneController gira o palco (com o Hyper junto) durante as cenas de humor.
function HyperController.setStageRotation(rotation: CFrame)
	stageRotation = rotation
end

local function render(dt: number)
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - feet).Magnitude > 240 then return end
	local now = os.clock()
	springPose(dt)
	-- parado: olha para um lado da plateia de vez em quando (mola própria, somada ao giro da pose)
	if not talking and now >= nextLook then
		nextLook = now + Anim.LookEvery.Min + math.random() * (Anim.LookEvery.Max - Anim.LookEvery.Min)
		lookTarget = if math.random() < 0.3 then 0 else (math.random() * 2 - 1) * Anim.LookDegrees
	elseif talking then
		lookTarget = 0
	end
	look, lookVelocity = spring(look, lookVelocity, lookTarget, dt)
	local hover = math.sin(now * Anim.HoverSpeed) * Anim.HoverHeight

	-- movimentos contínuos por cima da pose: respiração, balanço, aceno e tremor de raiva
	local breath = math.sin(now * Anim.BreathSpeed) * Anim.BreathAmount
	local sway = math.sin(now * Anim.SwaySpeed) * Anim.SwayDegrees
	local talkNod = if talking then math.sin(now * Anim.TalkNodSpeed) * Anim.TalkNodDegrees else 0
	local jitter = if shake > 0 then math.sin(now * Anim.ShakeSpeed) * Anim.ShakeDegrees * shake else 0
	local waveAngle = if wave > 0 then math.sin(now * Anim.WaveSpeed) * Anim.WaveDegrees * wave else 0
	local hopT = (now - hopStart) / Anim.HopTime
	local hop = if hopT >= 0 and hopT <= 1 then math.sin(hopT * math.pi) * Anim.HopHeight else 0
	if furious and not talking and math.floor(now / Anim.StompEvery) ~= math.floor((now - dt) / Anim.StompEvery) then
		hopStart = now -- pisa forte de tempos em tempos quando está furioso
	end

	local p = current
	local root = stageRotation
		* CFrame.new(0, hop + breath * 0.3 + hover, 0)
		* about(feet, CFrame.Angles(math.rad(p.lean), math.rad(p.yaw + sway + jitter * 0.5 + look), math.rad(jitter * 0.3)))

	local head = rest.Head
	head.part.CFrame = root * about(neck, CFrame.Angles(math.rad(p.nod + talkNod), 0, math.rad(p.tilt + jitter))) * CFrame.new(0, breath, 0) * head.cf
	rest.Body.part.CFrame = root * rest.Body.cf

	local left: Arm = { forward = p.left.forward, out = p.left.out + waveAngle, twist = p.left.twist }
	local rightArm = rest.RightArm
	local rightCF = root * about(shoulders.right, armRotation(p.right, -1)) * rightArm.cf
	rightArm.part.CFrame = rightCF
	rest.LeftArm.part.CFrame = root * about(shoulders.left, armRotation(left, 1)) * rest.LeftArm.cf

	local grip = rightCF * micGrip
	for _, m in micParts do
		m.part.CFrame = grip * m.cf
	end
end

function HyperController.init()
	local folder = Instance.new("Folder")
	folder.Name = "HyperSpeechFx"
	folder.Parent = workspace
	fxFolder = folder
	task.spawn(function()
		local hyper = workspace:WaitForChild("Hyper", 30)
		if not hyper then
			return
		end
		for _, name in { "Head", "Body", "LeftArm", "RightArm" } do
			local part = hyper:WaitForChild(name, 30)
			if not (part and part:IsA("BasePart")) then
				warn("[HyperController] parte não encontrada: " .. name)
				return
			end
			rest[name] = { part = part, cf = part.CFrame }
		end
		local body = rest.Body.part
		feet = body.Position - Vector3.new(0, body.Size.Y / 2, 0)
		local headPart = rest.Head.part
		neck = headPart.Position - Vector3.new(0, headPart.Size.Y * 0.46, 0)
		for side, name in { right = "RightArm", left = "LeftArm" } do
			local a = rest[name].part
			shoulders[side] = a.Position + Vector3.new(0, a.Size.Y * 0.41, 0)
		end

		-- Microfone: na pose de falar, o punho fica na mão e a cabeça do microfone aponta para a boca.
		local mic = hyper:WaitForChild("Mic", 30)
		local handle = mic and mic:WaitForChild("Handle", 10)
		if mic and handle and handle:IsA("BasePart") then
			local rightArm = rest.RightArm
			local armAtMouth = about(shoulders.right, armRotation(MIC_MOUTH, -1)) * rightArm.cf
			local hand = (armAtMouth * CFrame.new(0, -rightArm.part.Size.Y / 2 * 0.77, 0)).Position
			local mouth = headPart.Position + Vector3.new(Anim.MouthOffset.X, Anim.MouthOffset.Y, Anim.MouthOffset.Z)
			local grip = CFrame.lookAt(hand, mouth) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, rightArm.part.Size.Y * 0.154, 0)
			micGrip = armAtMouth:Inverse() * grip
			-- o cabo é um cilindro deitado no eixo X; o "eixo do microfone" (Y, cabeça para cima) é ele girado -90°
			local micFrame = handle.CFrame * CFrame.Angles(0, 0, -math.pi / 2)
			for _, d in mic:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(micParts, { part = d, cf = micFrame:Inverse() * d.CFrame })
				end
			end
		end

		RunService.RenderStepped:Connect(render)
	end)

	Remotes.get("HyperSays").OnClientEvent:Connect(onSays)
	Remotes.get("RoundState").OnClientEvent:Connect(onRoundState)
	Remotes.get("MoodState").OnClientEvent:Connect(onMood)
end

return HyperController
