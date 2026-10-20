--!strict
-- Empurrão: o cliente só pede ("quero empurrar"); o servidor escolhe o alvo e valida tudo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Util.Sfx)
local RagdollService = require(script.Parent.RagdollService)

local Settings = Config.Push

local PushService = {}

local lastPush: { [Player]: number } = {}
local lastRequest: { [Player]: number } = {}
local cooldownRemote: RemoteEvent
-- multiplicadores do modificador Super Empurrão (1 = normal)
local forceBoost, cooldownBoost = 1, 1

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

-- Zonas seguras: spawns da ilha de nascimento (SpawnLobby.Spawns) e chegada do portal na plateia
-- (Lobby.PortalArrivals, os antigos Lobby.Spawns). Todos chamados LobbySpawn.
local function nearLobbySpawn(position: Vector3): boolean
	local island = workspace:FindFirstChild("SpawnLobby")
	local lobby = workspace:FindFirstChild("Lobby")
	local folders: { Instance } = {}
	for _, folder in { island and island:FindFirstChild("Spawns"), lobby and (lobby:FindFirstChild("PortalArrivals") or lobby:FindFirstChild("Spawns")) } do
		if folder then
			table.insert(folders, folder)
		end
	end
	for _, spawns in folders do
		for _, spawn in spawns:GetChildren() do
			if spawn:IsA("BasePart") and (position - spawn.Position).Magnitude < Settings.SpawnSafeRadius then
				return true
			end
		end
	end
	return false
end

local function findTarget(pusher: Player, root: BasePart): (Player?, BasePart?)
	local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if forward.Magnitude < 0.01 then
		return nil, nil
	end
	forward = forward.Unit
	local best: Player?, bestRoot: BasePart?, bestDist = nil, nil, math.huge
	for _, other in Players:GetPlayers() do
		if other == pusher or RagdollService.isRagdolled(other)
			or (other:GetAttribute("HyperShowParticipant") == true) ~= (pusher:GetAttribute("HyperShowParticipant") == true) then
			continue
		end
		local otherRoot = rootOf(other)
		if not otherRoot then
			continue
		end
		local offset = otherRoot.Position - root.Position
		local dist = offset.Magnitude
		local flat = offset * Vector3.new(1, 0, 1)
		if dist <= Settings.Range and dist < bestDist and flat.Magnitude > 0.01 and flat.Unit:Dot(forward) >= Settings.MinFacingDot then
			best, bestRoot, bestDist = other, otherRoot, dist
		end
	end
	return best, bestRoot
end

local function onPushRequest(player: Player)
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < 0.15 then return end
	lastRequest[player] = now
	local inRound = player:GetAttribute("HyperShowParticipant") == true
	if inRound and workspace:GetAttribute("HyperShowRoundState") ~= "Playing" then return end
	local cooldown = Settings.Cooldown * cooldownBoost
	if now - (lastPush[player] or -math.huge) < cooldown then
		return
	end
	local root = rootOf(player)
	if not root or RagdollService.isRagdolled(player) or nearLobbySpawn(root.Position) then
		return
	end
	-- O cooldown conta mesmo sem acertar ninguém, para não virar spam de pedidos.
	lastPush[player] = now
	cooldownRemote:FireClient(player, cooldown)

	local target, targetRoot = findTarget(player, root)
	if not target or not targetRoot or nearLobbySpawn(targetRoot.Position) then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model, target.Character :: Model }
	params.RespectCanCollide = true
	if workspace:Raycast(root.Position, targetRoot.Position - root.Position, params) then return end
	local direction = ((targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)).Unit
	local velocity = (direction * Settings.HorizontalSpeed + Vector3.new(0, Settings.UpSpeed, 0)) * forceBoost
	RagdollService.ragdoll(target, Config.Ragdoll.Duration, velocity)
	Sfx.playAt("Push", targetRoot)
end

-- Usado pelo modificador Super Empurrão; remove() volta para 1, 1.
function PushService.setBoost(force: number, cooldown: number)
	forceBoost, cooldownBoost = force, cooldown
end

function PushService.init()
	cooldownRemote = Remotes.get("PushCooldown")
	Remotes.get("PushRequest").OnServerEvent:Connect(onPushRequest)
	Players.PlayerRemoving:Connect(function(player)
		lastPush[player] = nil
		lastRequest[player] = nil
	end)
end

return PushService
