--!strict
-- Ragdoll no servidor: solta as juntas animadas do personagem por alguns segundos.
-- Durante o ragdoll o servidor fica com a posse da rede (para o impulso valer) e devolve ao final.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RagdollService = {}

local ragdollRemote: RemoteEvent
local active: { [Model]: boolean } = {}

local function setOwner(character: Model, owner: Player?)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d:CanSetNetworkOwnership() then
			d:SetNetworkOwner(owner)
		end
	end
end

-- Dois tipos de avatar:
-- * juntas novas (AnimationConstraint + BallSocketConstraint já existente): basta desligar a AnimationConstraint;
-- * Motor6D (rig antigo): desliga o motor e cria uma BallSocketConstraint no lugar.
-- A junta Root (HumanoidRootPart -> LowerTorso) fica ligada: o corpo cai junto com o root.
local function enable(character: Model): { Instance }
	local created = {}
	for _, joint in character:GetDescendants() do
		if joint:IsA("AnimationConstraint") and joint.Name ~= "Root" then
			joint.Enabled = false
		end
	end
	for _, motor in character:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Name ~= "Root" and motor.Part0 and motor.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = "RagdollA0"
			a0.CFrame = motor.C0
			a0.Parent = motor.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagdollA1"
			a1.CFrame = motor.C1
			a1.Parent = motor.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "RagdollSocket"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.UpperAngle = 60
			socket.TwistLowerAngle = -45
			socket.TwistUpperAngle = 45
			socket.Parent = motor.Parent
			motor.Enabled = false
			table.insert(created, a0)
			table.insert(created, a1)
			table.insert(created, socket)
		end
	end
	return created
end

local function disable(character: Model, created: { Instance })
	for _, inst in created do
		inst:Destroy()
	end
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then
			joint.Enabled = true
		end
	end
end

-- Derruba o jogador por `duration` segundos e aplica a velocidade `velocity` no corpo.
function RagdollService.ragdoll(player: Player, duration: number, velocity: Vector3)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	if active[character] then
		return
	end
	active[character] = true

	local requiresNeck = humanoid.RequiresNeck
	local platformStand = humanoid.PlatformStand
	local enabled: { [Instance]: boolean } = {}
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then enabled[joint] = joint.Enabled end
	end
	humanoid.RequiresNeck = false
	local created = enable(character)
	humanoid.PlatformStand = true
	setOwner(character, nil)
	root.AssemblyLinearVelocity = velocity
	ragdollRemote:FireClient(player, true)

	task.delay(duration, function()
		active[character] = nil
		if not character.Parent then
			return
		end
		disable(character, created)
		for joint, wasEnabled in enabled do
			if joint.Parent then (joint :: any).Enabled = wasEnabled end
		end
		humanoid.RequiresNeck = requiresNeck
		humanoid.PlatformStand = platformStand
		if player.Parent == Players and player.Character == character then
			setOwner(character, player)
			ragdollRemote:FireClient(player, false)
		end
	end)
end

function RagdollService.isRagdolled(player: Player): boolean
	local character = player.Character
	return character ~= nil and active[character] == true
end

function RagdollService.init()
	ragdollRemote = Remotes.get("Ragdoll")
end

return RagdollService
