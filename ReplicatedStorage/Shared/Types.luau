--!strict
-- Contratos compartilhados entre os sistemas.

export type RoundState = "Intermission" | "Spin" | "Teleport" | "Intro" | "Playing" | "Qualification" | "Results"

-- Uma linha da tela de classificação (bonecos caindo): decidida no servidor, só exibida no cliente.
export type QualificationEntry = {
	id: number, -- UserId (miniatura do avatar)
	name: string,
	qualified: boolean,
}

export type MinigameCategory = "Survival" | "Race" | "Team" | "OneVsAll"

-- Estado de uma rodada, criado pelo RoundService e passado a minigames e modificadores.
export type RoundContext = {
	minigame: MinigameDef,
	modifier: ModifierDef?,
	players: { Player }, -- participantes prontos
	characters: { [Player]: Model }, -- personagem inscrito, nunca substituído por respawn
	cancelled: boolean,
	cleaned: boolean,
	alive: { [Player]: boolean },
	map: Model?,
	startTime: number,
	cleanupTasks: { () -> () }, -- executadas no fim da rodada, mesmo com erro
	finish: () -> (), -- encerra a rodada antes do tempo
	eliminatedAt: { [Player]: number }, -- hora de cada eliminação (morte), uma vez por jogador
	leftAt: { [Player]: number }, -- quem saiu do servidor durante a rodada (não conta como morte)
	objectives: number, -- objetivos concluídos que o minigame queira informar ao humor do apresentador
	difficulty: number, -- 0 = normal; 1..3 = intensidade do modo furioso (cada minigame decide o que muda)
}

-- Resumo de uma rodada para o humor do apresentador (montado pelo RoundService).
export type RoundSummary = {
	cancelled: boolean,
	participants: number,
	plannedDuration: number,
	actualDuration: number,
	earlyEliminated: number,
	survivorsAtEnd: number,
	aliveLate: number, -- vivos aos 70% da duração prevista
	winners: number,
	objectives: number,
}

export type MinigameDef = {
	id: string, -- "NeonCollapse"
	displayName: string, -- "Desmoronamento Neon"
	instruction: string, -- "NÃO CAIA!" (até 3 palavras)
	category: MinigameCategory,
	minPlayers: number,
	duration: number, -- segundos
	mapName: string, -- nome do modelo em ServerStorage/Maps
	setup: (ctx: RoundContext) -> (),
	start: (ctx: RoundContext) -> (),
	getWinners: (ctx: RoundContext) -> { Player },
	cleanup: (ctx: RoundContext) -> (),
}

export type ModifierDef = {
	id: string,
	displayName: string,
	weight: number,
	apply: (ctx: RoundContext) -> (),
	remove: (ctx: RoundContext) -> (),
	incompatibleWith: { string }?,
}

export type PlayerSettings = {
	music: boolean,
	voice: boolean,
	speechFx: boolean,
	fx: boolean,
	brightness: number, -- -2..2
}

export type PlayerData = {
	coins: number,
	xp: number,
	wins: number, -- campeonatos vencidos
	tournaments: number, -- campeonatos jogados até o fim (chegou à final ou foi eliminado)
	ownedTrails: { string },
	equippedTrail: string?,
	processedPurchases: { [string]: boolean }, -- PurchaseId já entregues
	settings: PlayerSettings,
}

return {}
