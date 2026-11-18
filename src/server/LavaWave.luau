-- The threat that forces the dash home: every WAVE_INTERVAL seconds a wall of lava pours off the
-- volcano and sweeps the whole field to the safe line. Anyone it catches outside a safe dome is wiped
-- out and drops what they carry; wild brainrots it washes over may turn into Lava mutations.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(game.ReplicatedStorage.GameConfig)
local PlayerState = require(script.Parent.PlayerState)
local WildSpawner = require(script.Parent.WildSpawner)
local ArenaBuilder = require(script.Parent.ArenaBuilder)

local LavaWave = {}

local START_Z = GameConfig.FIELD_LENGTH + 10
local END_Z = -GameConfig.WAVE_DEPTH / 2 + 1

local wave: Model

local function buildWave(): Model
	local model = Instance.new("Model")
	model.Name = "LavaWave"
	local width = GameConfig.FIELD_WIDTH + 4
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(width, GameConfig.WAVE_HEIGHT, GameConfig.WAVE_DEPTH)
	body.Color = Color3.fromRGB(255, 84, 16)
	body.Material = Enum.Material.Neon
	body.Transparency = 0.12
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Parent = model
	local crest = Instance.new("Part")
	crest.Name = "Crest"
	crest.Size = Vector3.new(width, 3, GameConfig.WAVE_DEPTH * 0.7)
	crest.Color = Color3.fromRGB(255, 200, 60)
	crest.Material = Enum.Material.Neon
	crest.Anchored = true
	crest.CanCollide = false
	crest.CanQuery = false
	crest.CanTouch = false
	crest.Parent = model
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Rate = 140
	fire.Lifetime = NumberRange.new(0.8, 1.4)
	fire.Speed = NumberRange.new(6, 12)
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 1) })
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 180, 40), Color3.fromRGB(255, 60, 10))
	fire.LightEmission = 1
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Parent = crest
	local glow = Instance.new("PointLight")
	glow.Range = 40
	glow.Brightness = 3
	glow.Color = Color3.fromRGB(255, 120, 40)
	glow.Parent = body
	model.PrimaryPart = body
	return model
end

local function placeWave(frontZ: number)
	local height = GameConfig.WAVE_HEIGHT
	local crest = wave:FindFirstChild("Crest") :: BasePart
	wave.PrimaryPart.CFrame = CFrame.new(0, height / 2 - 1, frontZ)
	crest.CFrame = CFrame.new(0, height + 0.2, frontZ - 1)
end

-- Wipes out every player the wave front at frontZ is touching outside a safe dome.
local function sweepPlayers(frontZ: number)
	local half = GameConfig.WAVE_DEPTH / 2
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and humanoid and humanoid.Health > 0) then
			continue
		end
		local position = root.Position
		local inWave = position.Z > 0 and math.abs(position.Z - frontZ) <= half and position.Y < GameConfig.WAVE_HEIGHT + 3
		if inWave and not ArenaBuilder.isInSafeDome(position) then
			humanoid.Health = 0
			PlayerState.fx(player, "Wiped")
		end
	end
end

-- One whole surge: the wave runs from the volcano to the safe line over WAVE_TRAVEL_TIME seconds
-- (or `travelTime`, which the Studio test hook passes to slow it down).
function LavaWave.surge(travelTime: number?)
	local duration = travelTime or GameConfig.WAVE_TRAVEL_TIME
	workspace:SetAttribute("WavePhase", "surge")
	PlayerState.fxAll("WaveSurge")
	wave.Parent = workspace
	WildSpawner.resetLavaChecks()
	local started = os.clock()
	local connection
	local done = Instance.new("BindableEvent")
	connection = RunService.Heartbeat:Connect(function()
		local alpha = math.min((os.clock() - started) / duration, 1)
		local frontZ = START_Z + (END_Z - START_Z) * alpha
		workspace:SetAttribute("WaveFrontZ", frontZ)
		placeWave(frontZ)
		sweepPlayers(frontZ)
		WildSpawner.lavaTouch(frontZ, GameConfig.WAVE_DEPTH)
		if alpha >= 1 then
			connection:Disconnect()
			done:Fire()
		end
	end)
	done.Event:Wait()
	done:Destroy()
	wave.Parent = nil
end

-- The calm before a surge: publishes when the next wave hits (the HUD counts down to it), sounds the
-- warning WAVE_WARNING seconds ahead and returns as the wave is due.
function LavaWave.countDown()
	local surgeAt = workspace:GetServerTimeNow() + GameConfig.WAVE_INTERVAL
	workspace:SetAttribute("WavePhase", "calm")
	workspace:SetAttribute("WaveAt", surgeAt)
	task.wait(GameConfig.WAVE_INTERVAL - GameConfig.WAVE_WARNING)
	workspace:SetAttribute("WavePhase", "warning")
	PlayerState.fxAll("WaveWarning")
	task.wait(math.max(surgeAt - workspace:GetServerTimeNow(), 0))
end

-- Builds the wave and parks it behind the volcano. The server script's sendLavaWaves runs the cycle.
function LavaWave.start()
	wave = buildWave()
	placeWave(START_Z)
end

return LavaWave
