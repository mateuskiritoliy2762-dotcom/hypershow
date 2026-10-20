--!strict
-- Dados do jogador (estilo ProfileStore). Único lugar que escreve no DataStore.
-- * Trava de sessão: o perfil guarda qual servidor está com ele (_lock); outro servidor só assume depois que a
--   trava fica velha (Config.Data.LockStale), para dois servidores nunca salvarem por cima um do outro.
-- * Salva a cada Config.Data.AutosaveInterval, quando o jogador sai e no BindToClose; toda chamada ao DataStore
--   tenta de novo com espera crescente (backoff).
-- * Sem acesso ao DataStore (Studio sem permissão), o jogo segue com dados padrão e não salva.
-- Também cuida das configurações do jogador (remotes SettingsData / SettingsSave) e do placar (leaderstats).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerData = Types.PlayerData
type PlayerSettings = Types.PlayerSettings
type Profile = { data: PlayerData, saving: boolean, released: boolean }

local Settings = Config.Data

local DataService = {}

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local sessionId = HttpService:GenerateGUID(false)
local lastSettingsSave: { [Player]: number } = {}
local settingsDataRemote: RemoteEvent

local function defaultSettings(): PlayerSettings
	return table.clone(Settings.DefaultSettings)
end

local function newData(): PlayerData
	return {
		coins = 0,
		xp = 0,
		wins = 0,
		tournaments = 0,
		ownedTrails = {},
		equippedTrail = nil,
		processedPurchases = {},
		settings = defaultSettings(),
	}
end

-- Completa campos que faltam em perfis antigos e descarta tipos errados.
local function reconcile(raw: any): PlayerData
	local data = newData()
	if typeof(raw) ~= "table" then
		return data
	end
	for _, key in { "coins", "xp", "wins", "tournaments" } do
		if typeof(raw[key]) == "number" then
			(data :: any)[key] = raw[key]
		end
	end
	if typeof(raw.ownedTrails) == "table" then
		data.ownedTrails = raw.ownedTrails
	end
	if typeof(raw.equippedTrail) == "string" then
		data.equippedTrail = raw.equippedTrail
	end
	if typeof(raw.processedPurchases) == "table" then
		data.processedPurchases = raw.processedPurchases
	end
	if typeof(raw.settings) == "table" then
		for key, default in Settings.DefaultSettings do
			if typeof(raw.settings[key]) == typeof(default) then
				(data.settings :: any)[key] = raw.settings[key]
			end
		end
	end
	return data
end

-- Chama o DataStore com novas tentativas (1 s, 2 s, 4 s...). Retorna ok e o resultado.
local function withRetry<T>(label: string, fn: () -> T): (boolean, T?)
	local wait = 1
	for attempt = 1, Settings.Retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(string.format("[Data] %s falhou (tentativa %d): %s", label, attempt, tostring(result)))
		local message = tostring(result)
		if message:find("403") or message:find("StudioAccess") then
			store = nil -- sem permissão (Studio): para de tentar e segue sem salvar
			return false, nil
		end
		if attempt < Settings.Retries then
			task.wait(wait)
			wait *= 2
		end
	end
	return false, nil
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

-- Carrega e trava o perfil. Se outro servidor está com uma trava recente, espera e tenta de novo.
local function loadProfile(player: Player): PlayerData?
	if not store then
		return newData()
	end
	local dataStore = store :: DataStore
	for _ = 1, Settings.LockAttempts do
		local loaded: PlayerData? = nil
		local blocked = false
		local ok = withRetry("carregar " .. player.Name, function()
			dataStore:UpdateAsync(keyFor(player), function(raw: any)
				local lock = typeof(raw) == "table" and raw._lock
				if typeof(lock) == "table" and lock.session ~= sessionId and os.time() - (tonumber(lock.time) or 0) < Settings.LockStale then
					blocked = true
					return nil -- não mexe: outro servidor ainda está salvando este perfil
				end
				blocked = false
				local data = reconcile(raw)
				loaded = data
				local out = table.clone(data) :: any
				out._lock = { session = sessionId, time = os.time() }
				return out
			end)
			return true
		end)
		if not ok then
			return nil
		end
		if not blocked and loaded then
			return loaded
		end
		task.wait(Settings.LockRetryWait)
		if player.Parent ~= Players then
			return nil
		end
	end
	return nil
end

-- Salva o perfil; release = solta a trava (jogador saiu ou servidor fechando).
local function saveProfile(player: Player, profile: Profile, release: boolean)
	if not store or profile.released or profile.saving then
		return
	end
	local dataStore = store :: DataStore
	profile.saving = true
	withRetry("salvar " .. player.Name, function()
		dataStore:UpdateAsync(keyFor(player), function(raw: any)
			local lock = typeof(raw) == "table" and raw._lock
			if typeof(lock) == "table" and lock.session ~= sessionId then
				return nil -- perdemos a trava para outro servidor: não sobrescreve
			end
			local out = table.clone(profile.data) :: any
			out._lock = if release then nil else { session = sessionId, time = os.time() }
			return out
		end)
		return true
	end)
	profile.saving = false
	if release then
		profile.released = true
	end
end

local function updateLeaderstats(player: Player, data: PlayerData)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	for _, entry in { { name = Config.Strings.StatPoints, value = data.xp }, { name = Config.Strings.StatWins, value = data.wins } } do
		local value = stats:FindFirstChild(entry.name) :: IntValue?
		if not value then
			local created = Instance.new("IntValue")
			created.Name = entry.name
			created.Parent = stats
			value = created
		end
		(value :: IntValue).Value = entry.value
	end
end

local function onPlayerAdded(player: Player)
	local data = loadProfile(player)
	if player.Parent ~= Players then
		return
	end
	if not data then
		-- perfil travado por outro servidor ou DataStore fora do ar: joga com padrão, sem salvar por cima
		warn("[Data] perfil indisponível para " .. player.Name .. "; jogando sem salvar")
		data = newData()
		profiles[player] = { data = data :: PlayerData, saving = false, released = true }
	else
		profiles[player] = { data = data, saving = false, released = false }
	end
	local loaded = profiles[player].data
	updateLeaderstats(player, loaded)
	player:SetAttribute("HyperShowDataLoaded", true)
	settingsDataRemote:FireClient(player, loaded.settings)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	lastSettingsSave[player] = nil
	if profile then
		saveProfile(player, profile, true)
		profiles[player] = nil
	end
end

function DataService.get(player: Player): PlayerData?
	local profile = profiles[player]
	return profile and profile.data
end

-- Pontos de experiência do campeonato (separados das moedas).
function DataService.addXp(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or amount <= 0 then
		return
	end
	profile.data.xp += math.floor(amount)
	updateLeaderstats(player, profile.data)
end

function DataService.addResult(player: Player, champion: boolean)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.data.tournaments += 1
	if champion then
		profile.data.wins += 1
	end
	updateLeaderstats(player, profile.data)
end

-- Valida as configurações vindas do cliente: só chaves conhecidas, tipo certo e brilho dentro da faixa.
local function onSettingsSave(player: Player, incoming: unknown)
	local profile = profiles[player]
	if not profile or typeof(incoming) ~= "table" then
		return
	end
	local now = os.clock()
	if now - (lastSettingsSave[player] or -math.huge) < Settings.SettingsCooldown then
		return
	end
	lastSettingsSave[player] = now
	local data = incoming :: { [any]: any }
	for key, default in Settings.DefaultSettings do
		local value = data[key]
		if typeof(value) == typeof(default) then
			if typeof(value) == "number" then
				value = math.clamp(math.floor(value), Settings.BrightnessMin, Settings.BrightnessMax)
			end
			(profile.data.settings :: any)[key] = value
		end
	end
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Settings.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore indisponível (no Studio, ligue 'Enable Studio Access to API Services'): " .. tostring(result))
	end
	settingsDataRemote = Remotes.get("SettingsData")
	Remotes.get("SettingsSave").OnServerEvent:Connect(onSettingsSave)
	-- o cliente pede quando a interface carrega (o envio do PlayerAdded pode chegar antes de ele escutar)
	Remotes.get("SettingsRequest").OnServerEvent:Connect(function(player)
		local profile = profiles[player]
		local now = os.clock()
		if profile and now - (lastSettingsSave[player] or -math.huge) >= Settings.SettingsCooldown then
			lastSettingsSave[player] = now
			settingsDataRemote:FireClient(player, profile.data.settings)
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function DataService.start()
	while true do
		task.wait(Settings.AutosaveInterval)
		for player, profile in profiles do
			task.spawn(saveProfile, player, profile, false)
		end
	end
end

return DataService
