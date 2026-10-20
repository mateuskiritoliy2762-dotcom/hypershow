--!strict
-- Inicializa os serviços do servidor em ordem: primeiro todos os init(), depois todos os start().

local ServerScriptService = game:GetService("ServerScriptService")

local SERVICE_ORDER = {
	"DataService",
	"RewardService",
	"ShopService",
	"RagdollService",
	"PushService",
	"BotService",
	"HyperService",
	"MoodService",
	"StageService",
	"ShowSetService",
	"SocialService",
	"TournamentService",
	"RoundService",
}

type Service = {
	init: (() -> ())?,
	start: (() -> ())?,
}

local servicesFolder = ServerScriptService:FindFirstChild("Services")
local services: { { name: string, module: Service } } = {}

for _, name in SERVICE_ORDER do
	local moduleScript = servicesFolder and servicesFolder:FindFirstChild(name)
	if moduleScript and moduleScript:IsA("ModuleScript") then
		table.insert(services, { name = name, module = require(moduleScript) :: any })
	end
end

for _, entry in services do
	if entry.module.init then
		entry.module.init()
	end
end

for _, entry in services do
	if entry.module.start then
		task.spawn(entry.module.start)
	end
end

print(string.format("[HyperShow] servidor iniciado (%d serviços)", #services))
