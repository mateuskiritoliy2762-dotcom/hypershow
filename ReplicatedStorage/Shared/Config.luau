--!strict
-- Todos os números ajustáveis do jogo ficam aqui.

local Config = {}

Config.Round = {
	MaxPlayers = 12,
	MinPlayers = 1,
	IntermissionTime = 12,
	SpinTime = 5,
	IntroTime = 5, -- contagem 5-4-3-2-1 com os jogadores presos nas cápsulas, olhando a arena
	DefaultPlayTime = 60,
	MaxPlayTime = 90,
	ResultsTime = 10,
}

-- Campeonato (estilo Fall Guys): fases seguidas com eliminação até a grande final, sem voltar ao lobby.
Config.Tournament = {
	CutRatio = 0.25, -- fração do total inicial eliminada por fase (12 -> 9 -> 6 -> 3 -> final)
	FinalSize = 3, -- com até este número de classificados, a próxima fase é a grande final
	MaxPhases = 5, -- a fase de número MaxPhases é sempre a final (evita campeonato sem fim)
	QualificationTime = 10, -- tela "RODADA ENCERRADA" com os bonecos caindo
	Points = { -- pontuação da partida (experiência/ranking, separada das moedas)
		Participate = 10,
		Qualify = 25,
		Highlight = 10, -- melhor colocado da fase
		Final = 50,
		Third = 75,
		Second = 125,
		First = 200,
	},
	-- camarim flutuante onde os classificados esperam a próxima fase (ao lado da arena, de onde se vê tudo)
	GreenRoomOrigin = Vector3.new(150, -30, 260), -- fora dos anéis (raio ~73) e da plateia flutuante (raio ~110)
	GreenRoomRadius = 18,
	GreenRoomFallDepth = 18, -- caiu mais que isso abaixo do camarim: volta para ele
	GreenRoomStreamTimeout = 3,
	CheckInterval = 0.5,
}

-- Cenário do show (ShowSetService / ShowSetController): arquibancadas flutuantes com bonecos de skins reais do
-- Roblox em volta da arena e do lobby, e telões (arena: cubo pendurado no centro; lobby: ao lado do Hyper).
Config.ShowSet = {
	Sites = {
		-- center: centro do anel de arquibancadas; seats: bonecos por arquibancada; skipAngle: direção (graus, 0 = +X) deixada livre
		Arena = { center = Vector3.new(0, -24, 260), radius = 92, stands = 8, seats = 5, skipAngle = 0 }, -- livre: camarim
		Lobby = { center = Vector3.new(0, 34, 10), radius = 104, stands = 6, seats = 4, skipAngle = 90 }, -- livre: frente da ilha
	},
	-- skins da plateia: estes usuários + quem estiver no servidor (trocados aos poucos)
	Usernames = { "KaioStarkBR", "TheusSTKBR", "Roblox", "builderman", "Shedletsky", "Stickmasterluke", "Merely", "Telamon" },
	RefreshInterval = 45, -- segundos entre trocas de um boneco por um jogador do servidor
	-- emotes R15 padrão do Roblox: torcida, aceno, apontar, risada, dança
	Emotes = {
		Cheer = "rbxassetid://507770677",
		Wave = "rbxassetid://507770239",
		Point = "rbxassetid://507770453",
		Laugh = "rbxassetid://507770818",
		Dance = "rbxassetid://507771019",
		Dance2 = "rbxassetid://507776043",
	},
	BobHeight = 2.2, -- flutuação das arquibancadas (studs)
	BobSpeed = 0.55,
	OrbitSway = 6, -- graus que o anel de arquibancadas balança em volta do centro (vai e volta)
	OrbitSpeed = 0.07, -- velocidade desse balanço
	UpdateDistance = 420, -- só anima arquibancadas perto da câmera
	ArenaScreen = { offset = Vector3.new(0, 40, 0), size = Vector2.new(34, 19) }, -- cubo do telão, acima da arena
	LobbyScreen = { position = Vector3.new(-30, 32, -46), size = Vector2.new(22, 12.4), yaw = 12 },
}

-- Dados salvos (DataService).
Config.Data = {
	StoreName = "HyperShowPlayers_v1",
	AutosaveInterval = 60,
	Retries = 4, -- tentativas por chamada ao DataStore (espera 1, 2, 4 s)
	LockStale = 150, -- segundos sem salvar até a trava de outro servidor ser considerada abandonada
	LockAttempts = 6, -- quantas vezes espera uma trava recente antes de jogar sem salvar
	LockRetryWait = 6,
	SettingsCooldown = 1,
	BrightnessMin = -2,
	BrightnessMax = 2,
	DefaultSettings = {
		music = true,
		voice = true, -- voz gravada do Hyper e bipes
		speechFx = true, -- símbolos, texto letra por letra e efeitos da fala
		fx = true, -- planetas, meteoros, partículas e efeitos de fundo
		brightness = 0, -- -2..2
	},
}

Config.Modifiers = {
	Chance = 0.35, -- chance de sortear 1 modificador por rodada
	MaxPerRound = 1,
	LunarGravity = 60, -- workspace.Gravity padrão é 196.2
	TurboWalkSpeedMultiplier = 1.6,
	TurboJumpPowerMultiplier = 1.2,
	BigHeadScale = 1.5,
	SlipperyFriction = 0, -- atrito do chão ensaboado (padrão do plástico: 0.3)
	-- Chuva de Meteoros
	MeteorInterval = 1.1, -- segundos entre meteoros
	MeteorWarning = 1.4, -- tempo do círculo de aviso antes do impacto
	MeteorRadius = 7, -- raio do impacto (arremessa quem estiver dentro)
	MeteorNearPlayerChance = 0.6, -- chance de mirar perto de um jogador vivo (o resto cai em qualquer lugar)
	MeteorKnockSpeed = 55,
	MeteorUpSpeed = 50,
	MeteorBreakRadius = 4.5, -- peças do mapa nesse raio caem (peças pequenas, nunca o chão inteiro)
	-- Apagão
	BlackoutLightRange = 16, -- luz que cada jogador carrega
	-- Super Empurrão
	MegaPushForce = 2, -- multiplica a força do empurrão
	MegaPushCooldown = 0.25, -- multiplica o tempo de recarga (10 s -> 2,5 s)
}

Config.NeonCollapse = {
	Floors = 3,
	GridSize = 11, -- hexágonos por lado em cada andar (arena ~90 x 110 para até 20 jogadores)
	FloorSpacing = 18,
	FallDelay = 0.6, -- segundos entre pisar (fica branco) e o hexágono cair
	FootCheckInterval = 0.1,
	Duration = 60,
	HexRadius = 6, -- distância do centro até a ponta do hexágono (hexágonos maiores = arena maior sem mais peças)
	HexGap = 0.5,
	HexRim = 0.3, -- quanto a borda neon passa do hexágono
	NeonDim = 0.35, -- escurece bordas e anéis neon (0 = brilho máximo)
	HexHeight = 1,
	-- centro do andar de cima: abaixo e à frente da ilha, visível do mirante (lobby no y 1, mirante até z 90)
	ArenaOrigin = Vector3.new(0, -40, 260), -- longe da ilha: a plateia flutuante da arena não passa embaixo do lobby
	GooDepth = 14, -- distância da gosma abaixo do último andar
	FloorColors = { Color3.fromHex("FF3D8B"), Color3.fromHex("1FB6FF"), Color3.fromHex("5B2BD6") },
	WarningColor = Color3.new(1, 1, 1),
	GooColor = Color3.fromHex("8BFF3D"),
	-- cápsulas de vidro no começo (uma por vaga do servidor)
	Cages = 20,
	CageRingRatio = 0.72, -- distância do centro, em fração do raio do andar
	CageWidth = 6,
	CageHeight = 8,
	CageLift = 6, -- altura do chão da cápsula acima do hexágono (cai no andar quando o vidro quebra)
	CageColor = Color3.fromHex("BFE9FF"),
	CageTransparency = 0.55,
	CageRimColor = Color3.fromHex("FF3D8B"),
	MaxAirTime = 15, -- tolerância para saltos, gravidade lunar e impulsos; sem ban automático
	MaxAboveArena = 100,
	BoundaryMargin = 40,
	StreamTimeout = 3, -- segundos esperando o andar carregar no cliente antes de teleportar
}

Config.Push = {
	Cooldown = 10,
	Range = 6,
	MinFacingDot = 0.3, -- alvo precisa estar na frente (cosseno do ângulo)
	HorizontalSpeed = 55,
	UpSpeed = 30,
	SpawnSafeRadius = 4, -- sem empurrão em cima de um dos 12 spawns da plateia
}

Config.Ragdoll = {
	Duration = 2,
}

-- Valores provisórios: ainda não definidos no design, ajustar depois de testar.
Config.Rewards = {
	WinCoins = 50,
	ParticipationCoins = 10,
	WinXP = 25,
	ParticipationXP = 5,
}

Config.Bots = {
	MinRealPlayers = 6, -- abaixo disso entram bots
	NamePrefix = "[BOT] ",
}

-- Sons (Creator Store). Para trocar, basta mudar o ID; Volumes opcionais por som.
Config.Sounds = {
	MusicLobby = "rbxassetid://1842174239", -- "Game Show" (APM)
	MusicGame = "rbxassetid://1839885864", -- "Silly Things" (APM)
	Spin = "rbxassetid://1840444182", -- "Drum Rolls (A)" (APM)
	Intro = "rbxassetid://9113867249", -- beep de sintetizador (ProSoundEffects)
	Victory = "rbxassetid://1844278029", -- "Cartoon Time 3 (b) Link 2" (APM)
	Fail = "rbxassetid://190705984", -- trombone triste
	Push = "rbxassetid://9120728815", -- "Whoosh Heavy Punches 1" (ProSoundEffects)
	Fall = "rbxassetid://140727221118804", -- splash cartunesco
	HexCrack = "rbxassetid://9119232904", -- estalo (ProSoundEffects)
	HyperTalk = "rbxassetid://9113880475", -- beep curto (ProSoundEffects)
} :: { [string]: string }

Config.SoundVolumes = {
	MusicLobby = 0.3,
	MusicGame = 0.3,
	HexCrack = 0.35,
	HyperTalk = 0.4,
} :: { [string]: number }

-- Humor do apresentador: estresse de 0 a 100 calculado pelo servidor ao fim de cada rodada.
-- Pódio: estátuas dos vencedores (RoundService)
Config.Podium = {
	CheerAnimation = "rbxassetid://507770677", -- emote "Cheer" padrão do Roblox (R15)
}

-- Roleta do palco (StageService): fatias na MESMA ordem da arte (tools/make_wheel.py), começando pelo topo
-- e seguindo no sentido horário. "None" = sem modificador. Cada id é o id de um módulo em Modifiers/.
Config.Wheel = {
	Slices = { "Turbo", "LunarGravity", "SlipperyFloor", "BigHead", "MeteorShower", "ReverseControls", "Blackout", "MegaPush", "None" },
	-- ícone de cada resultado (arte/icones, mesmos da roleta), mostrado no telão Modificador de Caos
	Icons = {
		Turbo = "rbxassetid://98074301842039",
		LunarGravity = "rbxassetid://89141319653388",
		SlipperyFloor = "rbxassetid://116498955085675",
		BigHead = "rbxassetid://106807359054035",
		MeteorShower = "rbxassetid://133661672572100",
		ReverseControls = "rbxassetid://82041274523577",
		Blackout = "rbxassetid://76148836376144",
		MegaPush = "rbxassetid://127803833052297",
		None = "rbxassetid://90878512943111",
		Unknown = "rbxassetid://117163015864861", -- "?" com energia, antes do sorteio
	},
	Turns = 4, -- voltas completas antes de parar
	Jitter = 0.6, -- quanto a parada varia dentro da fatia (0 = sempre no meio, 1 = fatia inteira)
}

-- Telões do lobby (StageService): largura útil da caixa de texto dividida pela largura média de uma letra.
Config.Stage = {
	ScreenTextWidth = 390, -- tamanho do texto = isto / letras da palavra mais longa
	ScreenTextMin = 28,
}

-- Área social do lobby (SocialService no servidor, SocialController no cliente)
Config.Social = {
	CheckInterval = 0.25, -- segundos entre conferências de plataforma e quedas
	FallY = -15, -- abaixo disso (fora de partida) volta ao lobby
	MaxX = 75, -- limites da ilha do palco (fora de partida)
	MinZ = -62,
	MaxZ = 95,
	-- ilha de nascimento (workspace.SpawnLobby, montada por tools/build_spawn_lobby.luau): também é área permitida;
	-- quem cai dela volta para os spawns dela, quem cai do palco volta para a chegada do portal
	SpawnIsland = { MinX = -665, MaxX = -448, MinZ = -135, MaxZ = 135 },
	StreamTimeout = 3, -- segundos esperando o destino carregar no aparelho antes de teleportar entre as ilhas
	RequestCooldown = 0.5, -- pedidos do cliente (sair da fila, foco de espectador)
	WaitRecheck = 2, -- sem inscritos: segundos até conferir de novo
	SpectateHeight = 9, -- câmera de espectador: altura e distância atrás do jogador observado
	SpectateDistance = 16,
	ArenaViewOffset = Vector3.new(0, 85, 120), -- câmera geral, em relação ao centro da arena
}

-- Efeitos do lobby no cliente (LobbyFxController).
Config.LobbyFx = {
	SpaceSpeed = 0.25, -- velocidade geral de planetas, anel e asteroides
	PlanetBob = 3, -- studs que os planetas sobem e descem
	BeamSpeed = 0.6,
	BeamDegrees = 8, -- balanço dos holofotes
	BulbChaseSpeed = 6, -- lâmpadas da roleta correndo
	MeteorEveryMin = 2.5, -- segundos entre meteoros
	MeteorEveryMax = 6,
	MeteorSpeed = 160,
	MeteorLife = 1.6,
	DustRate = 18, -- poeira cósmica por segundo
	LogoSparkRate = 6,
	EmberRate = 30, -- brasas no modo furioso
	ConfettiPerColor = 30,
	VortexSpeed = math.pi * 2 / 8, -- vórtice do portal da ilha de nascimento: uma volta a cada 8 s (rad/s)
	VortexDistance = 400, -- câmera mais longe que isso: o vórtice para de girar
}

Config.Mood = {
	StartStress = 15,
	MaxStress = 100,
	FuriousAt = 100, -- entra no modo furioso
	RecoverAt = 25, -- sai do modo furioso (histerese: bem abaixo do FuriousAt)
	RecoverGoodRounds = 2, -- rodadas boas seguidas exigidas para recuperar
	-- Faixas do medidor (limite inferior de cada nível, do mais feliz ao furioso).
	Levels = {
		{ name = "VeryHappy", from = 0 },
		{ name = "Happy", from = 20 },
		{ name = "Neutral", from = 40 },
		{ name = "Irritated", from = 60 },
		{ name = "Furious", from = 80 },
	},
	-- Avaliação da rodada
	EarlyWindow = 12, -- segundos do início da partida em que eliminações contam como "cedo demais"
	FullWeightPlayers = 4, -- abaixo disso a avaliação pesa proporcionalmente menos
	MaxDeltaUp = 35,
	MaxDeltaDown = 30,
	Weights = {
		EarlyEliminations = 30, -- todos eliminados cedo = +30
		ShortRound = 20, -- rodada que acabou muito antes do previsto
		ShortRoundRatio = 0.35, -- abaixo dessa fração da duração conta como curta
		LongRound = 12, -- durou até perto do fim = -12
		LongRoundRatio = 0.7,
		CloseFight = 8, -- 2+ vivos depois de 70% da partida = -8
		Completed = 6, -- terminou com vencedor de forma normal = -6
		PerObjective = 2, -- objetivos que o minigame informar (ctx.objectives)
		MaxObjectives = 10,
	},
	-- Cenas de transformação (segundos a partir do início da cena; todos os clientes usam o mesmo relógio)
	Cutscene = {
		ToFurious = { Duration = 9, GlassAt = 2.6, FaceAt = 3.4, SpinAt = 4.4, SpinTime = 2.6, RevealAt = 7.2 },
		ToNormal = { Duration = 8, GlassAt = 2.2, FaceAt = 2.2, SpinAt = 3.4, SpinTime = 2.6, RevealAt = 6.2 },
		GlassImage = "rbxassetid://77626325982159",
		BrokenGlassImage = "rbxassetid://84180984917700", -- arte/cenario/medidor_vidro_quebrado.png
		CameraFov = 60,
	},
	-- Lobby furioso: o neon vira vermelho/laranja e o resto escurece puxando para o vermelho.
	FuriousTheme = {
		NeonWarmHue = 0.075, -- dourados e amarelos viram laranja
		NeonRedHue = 0.0, -- o resto do neon vira vermelho
		DarkHue = 0.97,
		DarkValue = 0.55, -- peças comuns ficam com 55% do brilho
		Atmosphere = {
			Color = Color3.fromRGB(240, 45, 30),
			Decay = Color3.fromRGB(120, 0, 15),
			Haze = 2.1,
			Glare = 0.8,
			Density = 0.14,
			Offset = 0.5,
		},
		TintColor = Color3.fromRGB(255, 175, 165),
		ScreenTextColor = Color3.fromRGB(255, 120, 90), -- "?" e nomes nos telões
		LogoImage = "rbxassetid://99682676991811", -- robo/Logo neon HYPERSHOW_ Minigames do Caos.png
		LightColor = Color3.fromRGB(255, 60, 40),
	},
	-- Modo furioso: intensidade 1..3 conforme o estresse (a cena acontece uma vez; a intensidade varia)
	Furious = {
		IntensityFrom = { 0, 50, 80 }, -- estresse mínimo para a intensidade 1, 2 e 3
		FallDelayMultiplier = { 0.8, 0.65, 0.5 }, -- Desmoronamento Neon: hexágono cai mais rápido
		MusicSpeed = 0.9,
	},
	-- Medidor no palco (animação no cliente; o valor vem do servidor)
	Meter = {
		MaxAngle = 84, -- graus do ponteiro em cada ponta do semicírculo
		TweenBase = 0.6, -- segundos mínimos do movimento do ponteiro
		TweenPerPoint = 0.02, -- segundos extras por ponto de estresse de diferença
		-- tremores por nível do medidor: intervalo entre tremores (s) e amplitude (graus)
		Tremor = {
			[3] = { every = NumberRange.new(2.5, 4), amplitude = 1.5 },
			[4] = { every = NumberRange.new(1, 2), amplitude = 3 },
			[5] = { every = NumberRange.new(0.35, 0.7), amplitude = 5 },
		} :: { [number]: { every: NumberRange, amplitude: number } },
	},
}

-- Ícones da interface (arte/icones, enviados ao Roblox).
Config.Icons = {
	Push = "rbxassetid://97007203167616",
	Coin = "rbxassetid://116373187407512",
	Trophy = "rbxassetid://87251909596152",
	Skull = "rbxassetid://114410725791984",
	Heart = "rbxassetid://132054856041691",
	Clock = "rbxassetid://101141637106033",
	-- tela de classificação do campeonato (arte gerada no ForgeGUI, arquivos em arte/campeonato)
	AvatarCard = "rbxassetid://128210031985947", -- moldura de TV do boneco (585 x 768)
	TitlePlate = "rbxassetid://126759354592241", -- placa de letreiro (1024 x 457)
	Qualified = "rbxassetid://87143051818608",
	Eliminated = "rbxassetid://87061409524196",
	SpeechPanel = "rbxassetid://108810832862339", -- cartão de fala do Hyper (arte/campeonato/balao.png, 1024 x 446)
}

-- Apresentador Hyper: rostos da tela (imagens enviadas ao Roblox) e falas por categoria.
Config.Hyper = {
	Faces = {
		Happy = "rbxassetid://122000960696879",
		Shocked = "rbxassetid://76762821716856",
		Laughing = "rbxassetid://112815014630832",
		Evil = "rbxassetid://103552628823425",
		Countdown = "rbxassetid://108359655170566",
		Sad = "rbxassetid://137053273620866",
		Neutral = "rbxassetid://102753804632047",
		Irritated = "rbxassetid://125886460447799",
		Angry = "rbxassetid://98686394595829",
		Furious = "rbxassetid://89762098939009",
	},
	-- Texturas do modelo 3D com cada rosto pintado na tela (geradas por tools/paint_hyper_faces.py).
	FaceTextures = {
		Happy = "rbxassetid://103906419870860",
		Shocked = "rbxassetid://72034348782073",
		Laughing = "rbxassetid://88332950177214",
		Evil = "rbxassetid://131661777893608",
		Countdown = "rbxassetid://108022502871187",
		Sad = "rbxassetid://77790764191350",
		Neutral = "rbxassetid://89174808199647",
		Irritated = "rbxassetid://128313583606089",
		Angry = "rbxassetid://92694212235502",
		Furious = "rbxassetid://112248120747232",
	},
	-- Rosto de descanso por nível do medidor (1 muito feliz ... 5 furioso) e no modo furioso.
	IdleFaceByLevel = { "Happy", "Happy", "Neutral", "Irritated", "Angry" },
	IdleFaceFurious = "Furious",
	-- Animação do apresentador no cliente (HyperController): velocidades em rad/s, ângulos em graus.
	Anim = {
		SpringStiffness = 70, -- mola das poses: rigidez (maior = chega mais rápido)
		SpringDamping = 0.62, -- amortecimento (< 1 = passa um pouquinho do ponto e volta: gesto com "quique")
		LookEvery = NumberRange.new(2.5, 5), -- parado, olha para um lado da plateia de tempos em tempos
		LookDegrees = 14,
		HoverHeight = 0.25, -- flutua de leve, como um robô
		HoverSpeed = 1.3,
		BreathSpeed = 2.2,
		BreathAmount = 0.06, -- studs que a cabeça sobe e desce ao respirar
		SwaySpeed = 0.9,
		SwayDegrees = 3, -- balanço do corpo parado
		TalkNodSpeed = 9,
		TalkNodDegrees = 4, -- cabeça balançando enquanto fala
		WaveSpeed = 10,
		WaveDegrees = 22, -- aceno com a mão livre
		ShakeSpeed = 38,
		ShakeDegrees = 3, -- tremor de raiva
		HopTime = 0.35,
		HopHeight = 0.6, -- pulinho nas frases empolgadas
		StompEvery = 2.6, -- segundos entre pisadas no modo furioso (parado)
		MouthOffset = Vector3.new(-0.56, -2.1, 2.8), -- onde o microfone aponta, em relação ao centro da cabeça
	},
	AvoidRepeatLast = 3, -- não repete as últimas N falas da mesma categoria
	-- Efeitos da fala (cliente, opção "Efeitos da fala"): símbolos que sobem da cabeça conforme o rosto e ondas
	-- de som saindo do microfone. Emojis em vez de palavras: a emoção chega sem depender do idioma.
	SpeechFx = {
		Symbols = {
			Happy = { "⭐", "🎵", "💖", "✨" },
			Laughing = { "😂", "🎵", "⭐", "✨" },
			Shocked = { "❗", "❓", "⁉️", "😱" },
			Neutral = { "💬", "🎵", "✨" },
			Irritated = { "💢", "😤", "❗" },
			Angry = { "💢", "⚡", "🔥" },
			Furious = { "🔥", "💢", "⚡", "💥" },
			Evil = { "😈", "⚡", "💀" },
			Sad = { "💧", "😢", "💔" },
			Countdown = { "⏱️", "❗", "⭐" },
		} :: { [string]: { string } },
		SymbolsPerLine = 3,
		SymbolRise = 7, -- studs que cada símbolo sobe
		SymbolTime = 1.6,
		Waves = 3, -- ondas de som por fala
		WaveColor = Color3.fromHex("35C8FF"),
		WaveColorAngry = Color3.fromHex("FF2E3D"),
	},
	-- Voz gravada (Kairogen "Açougueirão", arquivos em audio/hyper/falas/). Mesma ordem de Categories[x].lines:
	-- Ids[categoria][i] é o áudio da fala i. Fala sem id (ou "") toca o beep HyperTalk no lugar.
	Voice = {
		Volume = 1,
		-- Voz de TV robótica (efeitos do Roblox, aplicados no cliente): eco bem curto = timbre metálico,
		-- flanger leve, equalizador de alto-falante de TV e reverb de estúdio no espaço.
		Robot = {
			EchoDelay = 0.015, EchoWet = -4, -- delay de 15 ms realimentado vira o "metal" do robô
			FlangeDepth = 0.15, FlangeMix = 0.3, FlangeRate = 0.6,
			EqLow = -4, EqMid = 2, EqHigh = -3, -- dB
		},
		-- Tom da voz: o mais forte entre o rosto da fala e o humor do Hyper (nível do medidor / modo furioso),
		-- assim o sorteio e as quedas também saem com raiva quando ele está bravo. Octave < 1 deixa mais grave.
		ProfileOrder = { "VeryHappy", "Happy", "Normal", "Irritated", "Angry", "Furious" }, -- do mais feliz ao mais bravo
		ProfileByFace = { Irritated = "Irritated", Angry = "Angry", Furious = "Furious" } :: { [string]: string },
		-- um tom para cada nível do medidor atrás do Hyper (1 muito feliz ... 5 furioso)
		ProfileByLevel = { "VeryHappy", "Happy", "Normal", "Irritated", "Angry" } :: { [number]: string },
		ProfileFurious = "Furious", -- modo furioso (fase Furious ou ToFurious)
		Profiles = {
			VeryHappy = { Octave = 1.06, Distortion = 0, EchoFeedback = 0.4, TremoloDepth = 0, ReverbDecay = 1.2, ReverbWet = -13 },
			Happy = { Octave = 1.03, Distortion = 0, EchoFeedback = 0.42, TremoloDepth = 0, ReverbDecay = 1.3, ReverbWet = -12 },
			Normal = { Octave = 1, Distortion = 0, EchoFeedback = 0.45, TremoloDepth = 0, ReverbDecay = 1.4, ReverbWet = -12 },
			Irritated = { Octave = 0.96, Distortion = 0.12, EchoFeedback = 0.5, TremoloDepth = 0, ReverbDecay = 1.6, ReverbWet = -11 },
			Angry = { Octave = 0.9, Distortion = 0.3, EchoFeedback = 0.6, TremoloDepth = 0.1, ReverbDecay = 2.2, ReverbWet = -8 },
			Furious = { Octave = 0.82, Distortion = 0.5, EchoFeedback = 0.65, TremoloDepth = 0.25, ReverbDecay = 3, ReverbWet = -5 },
		} :: { [string]: { Octave: number, Distortion: number, EchoFeedback: number, TremoloDepth: number, ReverbDecay: number, ReverbWet: number } },
		TremoloFrequency = 12, -- tremor da voz com raiva (Hz)
		-- "Língua original" do Hyper (zumbido estilo Animal Crossing, audio/hyper/Hyper_Zumbido.mp3) tocando baixo
		-- por baixo da voz, como se a fala em português fosse a saída de um tradutor. Id vazio = sem zumbido.
		Hum = { Id = "rbxassetid://117622925687711", Volume = 0.5, ReverbDecay = 2.5, ReverbWet = -4 },
		Ids = {
			RoundStart = {
				"rbxassetid://125193179442198", "rbxassetid://100900394698829", "rbxassetid://114843985506192",
				"rbxassetid://119723775053702", "rbxassetid://125486725467869", "rbxassetid://87698350117911",
				"rbxassetid://101768782890634", "rbxassetid://135215938403684", "rbxassetid://124180714137447",
				"rbxassetid://84372588738922",
			},
			Spin = {
				"rbxassetid://111135526249968", "rbxassetid://139303701410050", "rbxassetid://74569995505477",
				"rbxassetid://121858132278322", "rbxassetid://94321389986815", "rbxassetid://106424342911834",
				"rbxassetid://110684638497056", "rbxassetid://77673030868090", "rbxassetid://93628848576819",
				"rbxassetid://79075284898168",
			},
			Modifier = {
				"rbxassetid://90968028661147", "rbxassetid://83679221917344", "rbxassetid://104941866773429",
				"rbxassetid://111494096594070", "rbxassetid://87772306711994", "rbxassetid://104299421269155",
				"rbxassetid://100082394254061", "rbxassetid://101580284017154", "rbxassetid://98971722946730",
				"rbxassetid://100055868062190",
			},
			Fell = {
				"rbxassetid://117363350816101", "rbxassetid://135215696633359", "rbxassetid://134004432090603",
				"rbxassetid://140548275547323", "rbxassetid://89228069780400", "rbxassetid://126519545055599",
				"rbxassetid://107422909419607", "rbxassetid://87065980446742", "rbxassetid://95651146550158",
				"rbxassetid://104914075281368",
			},
			LastOne = {
				"rbxassetid://85810590609874", "rbxassetid://79864804681393", "rbxassetid://121604600875487",
				"rbxassetid://138977391756408", "rbxassetid://96414628193852", "rbxassetid://95132839936294",
				"rbxassetid://78311714866338", "rbxassetid://84648327197755", "rbxassetid://98657244814569",
				"rbxassetid://96068612940817",
			},
			Nobody = {
				"rbxassetid://106102659752320", "rbxassetid://81852943223370", "rbxassetid://80722138517786",
				"rbxassetid://109270160245861", "rbxassetid://107691008628067", "rbxassetid://110227157409415",
				"rbxassetid://113043397950038", "rbxassetid://91075030739496", "rbxassetid://75831155452021",
				"rbxassetid://74467578624736",
			},
			Victory = {
				"rbxassetid://99299156642751", "rbxassetid://119869513628599", "rbxassetid://78755574374952",
				"rbxassetid://120049024480081", "rbxassetid://87730168237417", "rbxassetid://108344098748360",
				"rbxassetid://74815323623785", "rbxassetid://138923179965863", "rbxassetid://91901208108425",
				"rbxassetid://133265967508407",
			},
			MultiFell = {
				"rbxassetid://114145259418694", "rbxassetid://125902388328666", "rbxassetid://116035929729822",
				"rbxassetid://73714069738803",
			},
			Satisfaction = {
				"rbxassetid://125196218309064", "rbxassetid://74511614618573", "rbxassetid://117113301104304",
			},
			Impatience = {
				"rbxassetid://118345667714758", "rbxassetid://101244201325833", "rbxassetid://134620818400846",
			},
			Anger = {
				"rbxassetid://71934685810039", "rbxassetid://118365143427777", "rbxassetid://71475513613970",
			},
			FuriousMode = {
				"rbxassetid://129705758439146", "rbxassetid://80348789129666", "rbxassetid://95148512984694",
			},
			CutsceneAngry = {
				"rbxassetid://100906442499599", "rbxassetid://82239349742916", "rbxassetid://99324225136366",
			},
			CutsceneAngryReveal = {
				"rbxassetid://91115180995296",
			},
			CutsceneCalm = {
				"rbxassetid://79285565238215",
			},
			CutsceneCalmReveal = {
				"rbxassetid://70707209306876",
			},
			Recovery = {
				"rbxassetid://97427959410337", "rbxassetid://99492318653696", "rbxassetid://80694026712485",
			},
		} :: { [string]: { string } },
	},
	-- Fila de falas: prioridade 1 = cena (nunca interrompida) ... 5 = comentário comum.
	Dialog = {
		MinGapCommon = 3.5, -- segundos mínimos entre falas comuns (prioridade 4 e 5)
		WindowSeconds = 30, -- no máximo MaxPerWindow falas comuns nessa janela
		MaxPerWindow = 6,
		BaseTime = 2.4, -- tempo do balão: base + por caractere, entre Min e Max
		PerChar = 0.045,
		MinTime = 3,
		MaxTime = 6.5,
		TypeSpeed = 0.025, -- segundos por letra no texto que aparece letra por letra
		MultiFellCount = 3, -- eliminações em sequência que viram "vários caíram"
		MultiFellWindow = 4,
	},
	-- Categorias: prioridade, rostos possíveis e falas (textos iniciais em arte/falas_hyper.txt).
	Categories = {
		-- campeonato (sem voz gravada ainda: tocam o bipe com os efeitos de fala)
		PhaseStart = {
			priority = 4,
			faces = { "Happy", "Shocked" },
			lines = {
				"Próxima fase! Quem sobra dessa vez?",
				"Mais uma fase! Segurem seus parafusos!",
				"Classificados, preparem-se para mais caos!",
				"Fase nova, perigo novo!",
				"Ainda de pé? Vamos ver por quanto tempo!",
			},
		},
		GrandFinal = {
			priority = 3,
			faces = { "Countdown", "Evil" },
			lines = {
				"GRANDE FINAL! Só um sai campeão!",
				"Chegou a hora da verdade!",
				"A final do HyperShow começou!",
				"Poucos finalistas, um troféu só!",
			},
		},
		Qualified = {
			priority = 4,
			faces = { "Laughing", "Happy" },
			lines = {
				"Os classificados seguem! O resto... tchauzinho!",
				"Quem caiu, caiu! Próxima!",
				"Que eliminação linda!",
				"Sobreviventes, vocês continuam no show!",
			},
		},
		Champion = {
			priority = 3,
			faces = { "Laughing", "Happy" },
			lines = {
				"Temos um campeão!",
				"Aplausos para o campeão do HyperShow!",
				"Campeão! A galáxia inteira viu!",
				"Que final! Que campeão!",
			},
		},
		RoundStart = {
			priority = 4,
			faces = { "Happy" },
			lines = {
				"Senhoras, senhores e criaturas espaciais!",
				"O espetáculo vai começar!",
				"Preparados para passar vergonha espacial?",
				"Apertem os cintos! Ou não!",
				"Quem pediu diversão com perigo?",
				"Hyper na área! Segurem seus parafusos!",
				"Começou! Que a confusão seja linda!",
				"Respirem fundo! Vai ficar esquisito!",
				"Atenção, terráqueos! O caos está chegando!",
				"Luzes, câmera... CORRAM!",
			},
		},
		Spin = {
			priority = 4,
			faces = { "Shocked" },
			lines = {
				"Girando a roleta da confusão!",
				"O destino está com preguiça hoje!",
				"Que comece o suspense desnecessário!",
				"Escolhendo sua próxima aventura... ou desastre!",
				"Minha roleta nunca erra! Quase nunca!",
				"Será diversão? Será sofrimento? SURPRESA!",
				"Computando diversão... erro! Diversão encontrada!",
				"A sorte sorri! Às vezes!",
				"Tambores, por favor! Não temos tambores!",
				"O próximo desafio será... TCHARAM!",
			},
		},
		Modifier = {
			priority = 4,
			faces = { "Evil", "Laughing" },
			lines = {
				"OPS! Apertei o botão errado!",
				"O caos acaba de ganhar tempero!",
				"Mudança de planos, meus queridos!",
				"Quem autorizou essa loucura? Fui eu!",
				"Ativando o modo BAGUNÇA!",
				"A física pediu demissão!",
				"Isso não estava no contrato!",
				"Mais caos? COM CERTEZA!",
				"Meu botão favorito! HAHAHA!",
				"As regras mudaram! Boa sorte!",
			},
		},
		Fell = {
			priority = 5,
			faces = { "Shocked", "Laughing" },
			lines = {
				"E lá se foi nosso astronauta!",
				"Houston, temos um tropeço!",
				"A gravidade venceu novamente!",
				"Isso foi uma aterrissagem alternativa!",
				"Alguém esqueceu como funciona o chão!",
				"Cuidado! O chão está desaparecendo!",
				"Eita! Essa queda teve estilo!",
				"Mais um voo sem passagem!",
				"A plateia agradece pelo espetáculo!",
				"Direto para o departamento de quedas!",
			},
		},
		LastOne = {
			priority = 4,
			faces = { "Shocked", "Happy" },
			lines = {
				"TEMOS UM FINALISTA!",
				"Só sobrou uma lenda!",
				"Um sobrevivente! Mil histórias para contar!",
				"O último biscoito do pacote!",
				"Todos caíram... menos essa criatura!",
				"Alguém merece uma estátua!",
				"A resistência tem um nome!",
				"O universo escolheu seu favorito!",
				"Um contra o caos inteiro!",
				"Atenção! Temos uma máquina de sobreviver!",
			},
		},
		Nobody = {
			priority = 3,
			faces = { "Sad", "Shocked", "Laughing" },
			lines = {
				"Bom... isso foi inesperado!",
				"Todo mundo perdeu! Inclusive minha esperança!",
				"Silêncio... pelos nossos queridos participantes!",
				"Acho que exagerei um pouquinho!",
				"Nem meu processador esperava essa!",
				"O caos venceu! De novo!",
				"Alguém viu para onde todos foram?",
				"Resultado oficial: desastre completo!",
				"Precisamos revisar as normas de segurança!",
				"Ninguém ganhou! Que eficiência impressionante!",
			},
		},
		Victory = {
			priority = 3,
			faces = { "Happy", "Laughing" },
			lines = {
				"TEMOS UM CAMPEÃO!",
				"Aplausos para essa criatura lendária!",
				"Vitória desbloqueada! Ego aumentado!",
				"O Hyper aprova essa performance!",
				"Você venceu! Meu processador está emocionado!",
				"Isso merece confete! MUITO CONFETE!",
				"O universo tem um novo campeão!",
				"Parabéns! Você sobreviveu ao meu programa!",
				"A vitória tem gosto de HyperCoins!",
				"Senhoras e senhores... UMA LENDA!",
			},
		},
		MultiFell = {
			priority = 4,
			faces = { "Shocked", "Laughing" },
			lines = {
				"E TEMOS MAIS UM PARTICIPANTE FORA!",
				"OPA! ESSE AÍ NÃO VIU O CHÃO CHEGANDO!",
				"NÃO DESANIMA! OU... DESANIMA, SEI LÁ!",
				"Caiu um, caiu outro... é uma chuva de gente!",
			},
		},
		Satisfaction = {
			priority = 2,
			faces = { "Happy", "Laughing" },
			lines = {
				"AGORA SIM, ISSO É ENTRETENIMENTO!",
				"QUE DISPUTA! NÃO CONSIGO TIRAR OS OLHOS!",
				"VOCÊS ESTÃO ME IMPRESSIONANDO!",
			},
		},
		Impatience = {
			priority = 2,
			faces = { "Irritated" },
			lines = {
				"ALGUÉM VAI FAZER ALGUMA COISA?",
				"EU TENHO UM PROGRAMA PRA APRESENTAR, SABEM?",
				"VAMOS LÁ! NÃO TEMOS O DIA INTEIRO!",
			},
		},
		Anger = {
			priority = 2,
			faces = { "Angry" },
			lines = {
				"VOCÊS ESTÃO TESTANDO A MINHA PACIÊNCIA!",
				"EU TENTEI SER LEGAL COM VOCÊS!",
				"CHEGA! AGORA AS COISAS VÃO MUDAR!",
			},
		},
		FuriousMode = {
			priority = 4,
			faces = { "Furious" },
			lines = {
				"AGORA É CADA UM POR SI!",
				"QUERO VER QUEM AGUENTA O SHOW DE VERDADE!",
				"NÃO RECLAMEM DEPOIS!",
			},
		},
		-- Falas obrigatórias das cenas (prioridade 1: nada interrompe)
		CutsceneAngry = {
			priority = 1,
			faces = { "Angry" },
			lines = {
				"AH, VOCÊS ACHAM QUE ISSO AQUI É BRINCADEIRA?!",
				"O SHOW ACABOU! AGORA É SOBREVIVÊNCIA!",
				"EU TENTEI SER LEGAL COM VOCÊS... MAS VOCÊS PEDIRAM POR ISSO!",
			},
		},
		CutsceneAngryReveal = {
			priority = 1,
			faces = { "Furious" },
			lines = { "SE VOCÊS QUEREM UM SHOW DE VERDADE, ENTÃO VAMOS VER QUEM CONSEGUE SOBREVIVER!" },
		},
		CutsceneCalm = {
			priority = 1,
			faces = { "Neutral" },
			lines = { "AH... FINALMENTE! AGORA SIM, ISSO É UM ESPETÁCULO!" },
		},
		CutsceneCalmReveal = {
			priority = 1,
			faces = { "Happy" },
			lines = { "É DISSO QUE EU ESTOU FALANDO! O SHOW ESTÁ SALVO!" },
		},
		Recovery = {
			priority = 2,
			faces = { "Happy" },
			lines = {
				"FINALMENTE, UMA PARTIDA DECENTE!",
				"ESTÁ VENDO? EU SABIA QUE VOCÊS CONSEGUIAM!",
				"MUITO BEM! O SHOW ESTÁ DE VOLTA!",
			},
		},
	},
}

-- Textos visíveis ao jogador (pt-BR).
Config.Strings = {
	HyperName = "HYPER", -- plaquinha do cartão de fala
	Intermission = "Intervalo",
	Spin = "Girando a roleta...",
	Teleport = "Indo para o palco...",
	Intro = "Prepare-se!",
	Playing = "Valendo!",
	Results = "Resultados",
	WaitingPlayers = "Esperando jogadores...",
	WaitingParticipants = "Entre no PORTAL para jogar!",
	Participating = "Participando ✓",
	NotParticipating = "Entre no PORTAL para jogar",
	StayInLobby = "Ficar no lobby",
	Watch = "ASSISTIR",
	BackToLobby = "VOLTAR AO LOBBY",
	ArenaView = "Câmera geral",
	Survivors = "Sobreviventes: ",
	NoMatch = "Nenhuma partida acontecendo agora",
	JoinedToast = "Você está participando das próximas rodadas!",
	Winners = "VENCEDORES",
	NoWinners = "NINGUÉM VENCEU",
	ChaosPrefix = "CAOS: ",
	NoChaos = "SEM CAOS",
	Unknown = "?",
	-- campeonato
	Qualification = "Classificação",
	Phase = "FASE %d",
	GrandFinal = "GRANDE FINAL",
	RoundOver = "RODADA ENCERRADA!",
	EliminatedCount = "%d ELIMINADOS",
	EliminatedOne = "1 ELIMINADO",
	NoneEliminated = "NINGUÉM ELIMINADO!",
	QualifiedCount = "%d CLASSIFICADOS",
	QualifiedOne = "1 CLASSIFICADO",
	YouQualified = "VOCÊ SE CLASSIFICOU!",
	YouEliminated = "VOCÊ FOI ELIMINADO",
	GreenRoomSign = "CAMARIM DOS CLASSIFICADOS",
	PlaceFormat = "%dº  %s",
	PointsFormat = "+%d pontos",
	-- placar e configurações
	StatPoints = "Pontos",
	StatWins = "Vitórias",
	SettingsTitle = "CONFIGURAÇÕES",
	SettingMusic = "Música",
	SettingVoice = "Voz do Hyper",
	SettingSpeechFx = "Efeitos da fala",
	SettingFx = "Efeitos visuais",
	SettingBrightness = "Brilho",
	On = "LIGADO",
	Off = "DESLIGADO",
	Close = "FECHAR",
	LiveBadge = "● AO VIVO",
	TournamentRunning = "Campeonato rolando! Você entra no próximo",
	NextUp = "PRÓXIMO: %s",
	-- telões
	ScreenTitle = "HYPERSHOW AO VIVO",
	ScreenLogo = "HYPERSHOW",
	ScreenAlive = "VIVOS %d / %d",
	ScreenTime = "%d s",
	ScreenChampion = "CAMPEÃO DO HYPERSHOW",
}

return Config
