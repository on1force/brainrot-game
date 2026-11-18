-- Client-side feedback: floating cash over your base, a beam pointing home while you carry,
-- screen flashes and shake for the lava wave, alarms, rebirth fanfare, sounds, rainbow brainrots
-- cycling their colors, and showing each player only the prompts meant for them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage") -- the shared modules sit right in it
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne

local state = nil
local beam: Beam? = nil

local gui = Instance.new("ScreenGui")
gui.Name = "Effects"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = -1
gui.Parent = player:WaitForChild("PlayerGui")

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(255, 40, 20)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui

local bigText = Instance.new("TextLabel")
bigText.AnchorPoint = Vector2.new(0.5, 0.5)
bigText.Position = UDim2.fromScale(0.5, 0.44)
bigText.Size = UDim2.fromScale(0.7, 0.12)
bigText.BackgroundTransparency = 1
bigText.Font = Enum.Font.LuckiestGuy
bigText.TextScaled = true
bigText.TextTransparency = 1
bigText.TextStrokeTransparency = 1
local bigStroke = Instance.new("UIStroke")
bigStroke.Thickness = 5
bigStroke.Color = Color3.fromRGB(58, 32, 30)
bigStroke.Transparency = 1
bigStroke.Parent = bigText
bigText.Parent = gui

local SOUNDS = {
	ping = "rbxasset://sounds/electronicpingshort.wav",
	swoosh = "rbxasset://sounds/action_jump.mp3",
	oof = "rbxasset://sounds/uuhhh.mp3",
	bonk = "rbxasset://sounds/collide.wav",
}

local function play(name: string, pitch: number?, volume: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = SOUNDS[name]
	sound.PlaybackSpeed = pitch or 1
	sound.Volume = volume or 0.6
	SoundService:PlayLocalSound(sound)
	task.delay(3, function()
		sound:Destroy()
	end)
end

local function flashScreen(color: Color3, strength: number, duration: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - strength
	TweenService:Create(flash, TweenInfo.new(duration), { BackgroundTransparency = 1 }):Play()
end

local function shout(message: string, color: Color3, hold: number?)
	bigText.Text = message
	bigText.TextColor3 = color
	bigText.TextTransparency = 0
	bigStroke.Transparency = 0
	bigText.Size = UDim2.fromScale(0.5, 0.08)
	TweenService:Create(bigText, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.7, 0.12) }):Play()
	TweenService:Create(bigText, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, hold or 1.4),
		{ TextTransparency = 1 }):Play()
	TweenService:Create(bigStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, hold or 1.4),
		{ Transparency = 1 }):Play()
end

local function myPlotFolder(): Instance?
	local world = workspace:FindFirstChild("World")
	return state and state.plot and world and world:FindFirstChild("Plot" .. state.plot)
end

-- "+$X" rising over your base's sign every second
local function popCash(amount: number)
	local folder = myPlotFolder()
	local sign = folder and folder:FindFirstChild("Sign") :: BasePart?
	if not sign then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromScale(14, 3.5)
	tag.StudsOffsetWorldSpace = Vector3.new(math.random(-8, 8), 6, 2)
	tag.LightInfluence = 0
	tag.Adornee = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.Text = "+" .. GameConfig.formatMoney(amount)
	label.TextColor3 = Color3.fromRGB(90, 255, 110)
	label.TextStrokeTransparency = 0
	label.Parent = tag
	tag.Parent = player.PlayerGui
	TweenService:Create(tag, TweenInfo.new(1.4), { StudsOffsetWorldSpace = tag.StudsOffsetWorldSpace + Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.5, function()
		tag:Destroy()
	end)
end

local function burstAtCharacter(color: Color3)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(1.2, 0)
	emitter.Speed = NumberRange.new(14, 24)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Parent = root
	emitter:Emit(50)
	task.delay(1.5, function()
		emitter:Destroy()
	end)
end

-- Beam from you to your base while you carry a brainrot.
local function updateHomeBeam()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local folder = myPlotFolder()
	local anchor = folder and folder:FindFirstChild("HomeAnchor")
	local home = anchor and anchor:FindFirstChild("Home") :: Attachment?
	local wanted = state and state.carrying and root and home
	if wanted and not beam then
		local from = Instance.new("Attachment")
		from.Name = "BeamFrom"
		from.Parent = root
		local b = Instance.new("Beam")
		b.Attachment0 = from
		b.Attachment1 = home
		b.Width0 = 1.2
		b.Width1 = 3
		b.FaceCamera = true
		b.LightEmission = 1
		b.Color = ColorSequence.new(Color3.fromRGB(90, 255, 140), Color3.fromRGB(255, 255, 120))
		b.Transparency = NumberSequence.new(0.2, 0.6)
		b.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 4
		b.TextureSpeed = 2
		b.Parent = root
		beam = b
	elseif not wanted and beam then
		if beam.Attachment0 then
			beam.Attachment0:Destroy()
		end
		beam:Destroy()
		beam = nil
	end
end

-- Sell prompts are for the owner, Steal prompts for everyone else.
local function filterPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local model = prompt:FindFirstAncestorOfClass("Model")
	local owner = model and model:GetAttribute("OwnerUserId")
	if prompt:GetAttribute("OwnerOnly") then
		prompt.Enabled = owner == player.UserId
	elseif prompt:GetAttribute("OthersOnly") then
		prompt.Enabled = owner ~= player.UserId
	end
end
workspace.DescendantAdded:Connect(function(instance)
	if instance:IsA("ProximityPrompt") then
		task.defer(filterPrompt, instance)
	end
end)
for _, instance in workspace:GetDescendants() do
	filterPrompt(instance)
end

GameConfig.remote("State").OnClientEvent:Connect(function(newState)
	state = newState
	if not newState.carrying and beam then
		updateHomeBeam()
	end
end)

-- A bat hit from another player: the server can't push our character (we own its physics), so we launch
-- ourselves away, tumble with controls off for `stun` seconds, then get back up.
local stunnedUntil = 0
GameConfig.remote("Knockback").OnClientEvent:Connect(function(direction: Vector3, stun: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) or humanoid.Health <= 0 then
		return
	end
	stunnedUntil = os.clock() + stun
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = direction * GameConfig.BAT_KNOCKBACK + Vector3.new(0, 30, 0)
	root.AssemblyAngularVelocity = Vector3.new(direction.Z, 0, -direction.X) * 9
	shout("BONKED!", Color3.fromRGB(255, 220, 80), stun - 0.4)
	flashScreen(Color3.fromRGB(255, 255, 255), 0.5, 0.4)
	play("bonk", 1, 1)
	task.delay(stun, function()
		if os.clock() >= stunnedUntil - 0.05 and humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end)

GameConfig.remote("Fx").OnClientEvent:Connect(function(kind, data)
	if player.PlayerGui:FindFirstChild("TitleScreen") then
		return -- nothing flashes over the start screen
	end
	if kind == "Income" then
		popCash(data.amount)
	elseif kind == "Grab" then
		local color = BrainrotCatalog.RARITY_BY_ID[data.rarity].color
		burstAtCharacter(color)
		play("ping", 1.2)
	elseif kind == "Placed" then
		local color = BrainrotCatalog.RARITY_BY_ID[data.rarity].color
		burstAtCharacter(color)
		play("ping", 1.6)
		if data.rarity ~= "Common" and data.rarity ~= "Rare" then
			shout(BrainrotCatalog.RARITY_BY_ID[data.rarity].label:upper() .. " SECURED!", color)
		end
	elseif kind == "Sell" then
		play("ping", 0.9)
	elseif kind == "WaveWarning" then
		shout("LAVA INCOMING!", Color3.fromRGB(255, 140, 40))
		flashScreen(Color3.fromRGB(255, 80, 20), 0.35, 1)
		for i = 0, 3 do
			task.delay(i * 0.5, play, "ping", 0.5, 0.8)
		end
	elseif kind == "WaveSurge" then
		flashScreen(Color3.fromRGB(255, 80, 20), 0.25, 0.8)
	elseif kind == "Wiped" then
		shout("WIPED OUT BY LAVA!", Color3.fromRGB(255, 80, 40), 2)
		flashScreen(Color3.fromRGB(255, 60, 10), 0.7, 1.6)
		play("oof")
	elseif kind == "Alarm" then
		shout("THIEF ALERT!", Color3.fromRGB(255, 70, 70))
		for i = 0, 5 do
			task.delay(i * 0.35, function()
				flashScreen(Color3.fromRGB(255, 0, 40), 0.3, 0.3)
				play("ping", 2, 0.5)
			end)
		end
	elseif kind == "Lock" then
		flashScreen(Color3.fromRGB(80, 255, 120), 0.25, 0.6)
		play("swoosh")
	elseif kind == "Bonk" then
		play("bonk")
		shout("BONK!", Color3.fromRGB(255, 230, 80))
	elseif kind == "Upgrade" then
		burstAtCharacter(Color3.fromRGB(120, 220, 255))
		play("swoosh", 1.3)
	elseif kind == "Rebirth" then
		shout("REBIRTH!", Color3.fromRGB(255, 120, 255), 2)
		flashScreen(Color3.fromRGB(255, 255, 255), 0.8, 1.5)
		burstAtCharacter(Color3.fromRGB(255, 120, 255))
		play("swoosh", 0.8, 0.9)
	elseif kind == "Meteor" then
		shout("METEOR SHOWER!", Color3.fromRGB(255, 180, 60))
		flashScreen(Color3.fromRGB(255, 200, 80), 0.3, 1)
	end
end)

RunService.RenderStepped:Connect(function()
	updateHomeBeam()

	-- your own base's sign reads YOUR BASE on your screen
	local plotFolder = myPlotFolder()
	local sign = plotFolder and plotFolder:FindFirstChild("Sign")
	local signGui = sign and sign:FindFirstChildOfClass("SurfaceGui")
	local signTitle = signGui and signGui:FindFirstChild("Frame") and (signGui :: any).Frame:FindFirstChildOfClass("TextLabel")
	if signTitle and signTitle.Text ~= "YOUR BASE" then
		signTitle.Text = "YOUR BASE"
	end

	-- rainbow brainrots cycle their hue
	local hue = (os.clock() * 0.25) % 1
	for _, model in CollectionService:GetTagged("RainbowBrainrot") do
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "Eye" and part.Name ~= "Root" then
				part.Color = Color3.fromHSV((hue + part.Size.Y * 0.07) % 1, 0.75, 1)
			end
		end
	end

	-- the camera shakes as the lava wave passes close by
	if workspace:GetAttribute("WavePhase") == "surge" then
		local camera = workspace.CurrentCamera
		local frontZ = workspace:GetAttribute("WaveFrontZ") or 1000
		local distance = math.abs(camera.CFrame.Position.Z - frontZ)
		local strength = math.clamp(1 - distance / 90, 0, 1) * 0.35
		if strength > 0 then
			camera.CFrame *= CFrame.Angles(math.rad(math.random() * strength - strength / 2),
				math.rad(math.random() * strength - strength / 2), 0)
		end
	end
end)
