--!strict
-- Cliente: música de fundo (lobby e partida) e sons da rodada e do Hyper.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SoundController = {}

local function makeSound(key: string, looped: boolean): Sound
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = Config.Sounds[key] or ""
	sound.Volume = Config.SoundVolumes[key] or 0.7
	sound.Looped = looped
	sound.Parent = SoundService
	return sound
end

local function playOnce(key: string)
	local id = Config.Sounds[key]
	if id and id ~= "" then
		local sound = makeSound(key, false)
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end
end

-- grupos de som que as configurações do jogador ligam e desligam (atributos locais do SettingsController)
local function group(name: string, attribute: string): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Parent = SoundService
	local player = game:GetService("Players").LocalPlayer
	local function apply()
		g.Volume = if player:GetAttribute(attribute) == false then 0 else 1
	end
	player:GetAttributeChangedSignal(attribute):Connect(apply)
	apply()
	return g
end

function SoundController.init()
	local musicGroup = group("Music", "HyperShowMusic")
	local voiceGroup = group("HyperVoice", "HyperShowVoice")
	local lobbyMusic = makeSound("MusicLobby", true)
	local gameMusic = makeSound("MusicGame", true)
	lobbyMusic.SoundGroup = musicGroup
	gameMusic.SoundGroup = musicGroup
	local current: Sound? = nil

	-- troca a música com um fade curto
	local function playMusic(music: Sound)
		if current == music then
			return
		end
		local previous = current
		current = music
		if previous then
			local fade = TweenService:Create(previous, TweenInfo.new(0.6), { Volume = 0 })
			fade.Completed:Once(function()
				previous:Stop()
			end)
			fade:Play()
		end
		music.Volume = Config.SoundVolumes[music.Name] or 0.3
		music:Play()
	end

	Remotes.get("RoundState").OnClientEvent:Connect(function(state: string, _endsAt: number, info: { winners: { string }? })
		if state == "Playing" then
			playMusic(gameMusic)
		elseif state == "Intermission" or state == "Results" then
			playMusic(lobbyMusic)
		end
		if state == "Spin" then
			playOnce("Spin")
		elseif state == "Intro" then
			playOnce("Intro")
		elseif state == "Results" then
			playOnce(if info.winners and #info.winners > 0 then "Victory" else "Fail")
		end
	end)

	-- voz gravada da fala (Config.Hyper.Voice); sem áudio, toca o beep. Fala nova corta a anterior.
	local VoiceConfig = Config.Hyper.Voice
	local voice = Instance.new("Sound")
	voice.Name = "HyperVoice"
	voice.Volume = VoiceConfig.Volume
	voice.Parent = SoundService
	voice.SoundGroup = voiceGroup

	-- cadeia de efeitos da voz de TV robótica; o que muda com o humor é ajustado a cada fala
	local robot = VoiceConfig.Robot
	local function addEffect<T>(className: string, priority: number, props: { [string]: any }): T
		local effect = Instance.new(className) :: any
		effect.Priority = priority
		for key, value in props do
			effect[key] = value
		end
		effect.Parent = voice
		return effect
	end
	local pitch: PitchShiftSoundEffect = addEffect("PitchShiftSoundEffect", 6, {})
	local distortion: DistortionSoundEffect = addEffect("DistortionSoundEffect", 5, {})
	local echo: EchoSoundEffect = addEffect("EchoSoundEffect", 4, { Delay = robot.EchoDelay, DryLevel = 0, WetLevel = robot.EchoWet })
	addEffect("FlangeSoundEffect", 3, { Depth = robot.FlangeDepth, Mix = robot.FlangeMix, Rate = robot.FlangeRate })
	local tremolo: TremoloSoundEffect = addEffect("TremoloSoundEffect", 2, { Frequency = VoiceConfig.TremoloFrequency, Duty = 1 })
	addEffect("EqualizerSoundEffect", 1, { LowGain = robot.EqLow, MidGain = robot.EqMid, HighGain = robot.EqHigh })
	local reverb: ReverbSoundEffect = addEffect("ReverbSoundEffect", 0, { Density = 1, Diffusion = 1, DryLevel = 0 })

	local moodProfile = "Normal"
	Remotes.get("MoodState").OnClientEvent:Connect(function(state: { level: number, phase: string })
		moodProfile = if state.phase == "Furious" or state.phase == "ToFurious"
			then VoiceConfig.ProfileFurious
			else VoiceConfig.ProfileByLevel[state.level] or "Normal"
	end)

	local function applyProfile(face: string)
		-- rosto bravo puxa o tom para mais bravo; fora isso vale o humor do medidor
		local faceProfile = VoiceConfig.ProfileByFace[face]
		local order = VoiceConfig.ProfileOrder
		local strongest = if faceProfile and (table.find(order, faceProfile) or 1) > (table.find(order, moodProfile) or 1)
			then faceProfile
			else moodProfile
		local profile = VoiceConfig.Profiles[strongest]
		pitch.Octave = profile.Octave
		distortion.Enabled = profile.Distortion > 0
		distortion.Level = profile.Distortion
		echo.Feedback = profile.EchoFeedback
		tremolo.Enabled = profile.TremoloDepth > 0
		tremolo.Depth = profile.TremoloDepth
		reverb.DecayTime = profile.ReverbDecay
		reverb.WetLevel = profile.ReverbWet
	end

	-- zumbido da "língua original" por baixo da voz, começando num ponto qualquer e parando junto com ela
	local hum = Instance.new("Sound")
	hum.Name = "HyperHum"
	hum.SoundId = VoiceConfig.Hum.Id
	hum.Volume = VoiceConfig.Hum.Volume
	hum.Looped = true
	hum.Parent = SoundService
	hum.SoundGroup = voiceGroup
	local humReverb = Instance.new("ReverbSoundEffect")
	humReverb.DecayTime = VoiceConfig.Hum.ReverbDecay
	humReverb.WetLevel = VoiceConfig.Hum.ReverbWet
	humReverb.DryLevel = 0 -- o padrão (-6 dB) abafava o zumbido
	humReverb.Parent = hum
	voice.Ended:Connect(function()
		hum:Stop()
	end)

	Remotes.get("HyperSays").OnClientEvent:Connect(function(line: string, face: string, _duration: number, _priority: number, category: string?)
		local categories = Config.Hyper.Categories :: { [string]: { lines: { string } } }
		local entry = category and categories[category]
		local ids = category and Config.Hyper.Voice.Ids[category]
		local index = entry and table.find(entry.lines, line)
		local id = ids and index and ids[index]
		if id and id ~= "" then
			voice:Stop()
			applyProfile(face)
			voice.SoundId = id
			voice:Play()
			if hum.SoundId ~= "" then
				hum.TimePosition = if hum.TimeLength > 0 then math.random() * hum.TimeLength else 0
				hum:Play()
			end
		elseif voiceGroup.Volume > 0 then
			playOnce("HyperTalk")
		end
	end)

	-- baixa todas as vozes logo ao entrar, para a fala não começar atrasada na primeira vez
	task.spawn(function()
		local preload: { Instance } = {}
		for _, ids in Config.Hyper.Voice.Ids do
			for _, id in ids do
				local sound = Instance.new("Sound")
				sound.SoundId = id
				table.insert(preload, sound)
			end
		end
		ContentProvider:PreloadAsync(preload)
		for _, sound in preload do
			sound:Destroy()
		end
		if hum.SoundId ~= "" then
			ContentProvider:PreloadAsync({ hum })
		end
	end)

	playMusic(lobbyMusic)
end

return SoundController
