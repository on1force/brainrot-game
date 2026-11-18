-- The start screen: the game's logo and a three-step how-to over a showcase stage of one brainrot of
-- every rarity, the field and the volcano behind. PLAY (or Enter / Space) hands the camera back and shows the HUD.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local BrainrotModel = require(Shared:WaitForChild("BrainrotModel"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FONT = Enum.Font.FredokaOne

local gui = Instance.new("ScreenGui")
gui.Name = "TitleScreen"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
local scale = Instance.new("UIScale")
scale.Parent = gui

local shade = Instance.new("Frame")
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.new(1, 1, 1)
shade.BorderSizePixel = 0
shade.Parent = gui
local shadeGradient = Instance.new("UIGradient")
shadeGradient.Rotation = 90
shadeGradient.Color = ColorSequence.new(Color3.fromRGB(30, 10, 40))
shadeGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.35),
	NumberSequenceKeypoint.new(0.45, 1),
	NumberSequenceKeypoint.new(0.75, 1),
	NumberSequenceKeypoint.new(1, 0.3),
})
shadeGradient.Parent = shade

local function logoLine(text: string, y: number, height: number, top: Color3, bottom: Color3, rotation: number)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 0, y)
	label.Size = UDim2.fromOffset(900, height)
	label.BackgroundTransparency = 1
	label.Font = UiKit.TITLE_FONT
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Rotation = rotation
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 7
	stroke.Color = Color3.fromRGB(45, 12, 30)
	stroke.Parent = label
	label.Parent = gui
	return label
end

local column = Instance.new("Frame")
column.AnchorPoint = Vector2.new(0.5, 0)
column.Position = UDim2.fromScale(0.5, 0)
column.Size = UDim2.fromOffset(1000, 760)
column.BackgroundTransparency = 1
column.Parent = gui

local firstWord, rest = GameConfig.GAME_NAME:match("^(%S+)%s+(.+)$")
local logoTop = logoLine(firstWord, 120, 130, Color3.fromRGB(255, 245, 120), Color3.fromRGB(255, 170, 30), -3)
local logoBottom = logoLine(rest, 235, 120, Color3.fromRGB(255, 140, 40), Color3.fromRGB(230, 30, 40), -3)
logoTop.Parent = column
logoBottom.Parent = column

local tagline = UiKit.panel(column, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -240),
	Size = UDim2.fromOffset(700, 44) })
UiKit.text(tagline, "19 absurd brainrots. 1 angry volcano. Zero chill.", { Position = UDim2.fromOffset(14, 7),
	Size = UDim2.new(1, -28, 1, -14), TextColor3 = UiKit.INK, outline = 0 })

local steps = Instance.new("Frame")
steps.AnchorPoint = Vector2.new(0.5, 1)
steps.Position = UDim2.new(0.5, 0, 1, -130)
steps.Size = UDim2.fromOffset(980, 96)
steps.BackgroundTransparency = 1
steps.Parent = column
local stepsLayout = Instance.new("UIListLayout")
stepsLayout.FillDirection = Enum.FillDirection.Horizontal
stepsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
stepsLayout.Padding = UDim.new(0, 14)
stepsLayout.SortOrder = Enum.SortOrder.LayoutOrder
stepsLayout.Parent = steps

for order, spec in {
	{ "1  BUY", "grab brainrots in the field", Color3.fromRGB(60, 150, 255) },
	{ "2  RUN HOME", "before the lava wave hits", Color3.fromRGB(255, 110, 40) },
	{ "3  GET RICH", "cash every second + rebirths", Color3.fromRGB(60, 200, 90) },
} do
	local card = UiKit.panel(steps, { LayoutOrder = order, Size = UDim2.fromOffset(310, 96) }, spec[3])
	UiKit.text(card, spec[1], { Font = UiKit.TITLE_FONT, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 44),
		outline = 3 })
	UiKit.text(card, spec[2], { Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 0, 30), outline = 2.5 })
end

local playButton = UiKit.button(column, { title = "PLAY", icon = "▶", color = UiKit.COLORS.green,
	size = UDim2.fromOffset(300, 86), anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -24) })

local OTHER_GUIS = { "Hud", "BrainrotIndex" }
local active = true
local started = os.clock()

local function setOtherGuis(enabled: boolean)
	for _, name in OTHER_GUIS do
		local other = playerGui:FindFirstChild(name)
		if other then
			(other :: ScreenGui).Enabled = enabled
		end
	end
end

-- A local showcase stage on the safe line: one brainrot of every rarity on pedestals that climb from
-- Common to SECRET, each lit by a beam of its rarity's color, behind a row of chasing marquee bulbs.
-- Each entry: catalog id, mutation, x along the stage (screen left to right), pedestal width.
local LINEUP = {
	{ "Toastolino", "None", -46, 9 }, { "Cactusso", "None", -32, 9 }, { "Pinguino", "Gold", -17, 10 },
	{ "Gelatone", "Diamond", -1, 10 }, { "Lunetta", "Rainbow", 15, 11 }, { "Spaghettus", "None", 31, 12 },
	{ "Mucca", "Cosmic", 49, 14 },
}
local STAGE_Z = 16
local DECK_TOP = 1.6
local UP = CFrame.Angles(0, 0, math.rad(90))
local stage = Instance.new("Folder")
stage.Name = "TitleStage"
local bulbs: { BasePart } = {}
local showcase: { { model: Model, home: CFrame, phase: number } } = {}

local function stagePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = stage
	return p
end

-- the camera looks along +Z, so a stage x of +n sits on screen left: flip it so the ladder climbs left to right
local function stageX(x: number): number
	return -x
end

local function buildStageShell()
	stagePart({ Name = "Deck", Size = Vector3.new(124, DECK_TOP, 20), Position = Vector3.new(0, DECK_TOP / 2, STAGE_Z + 2),
		Color = Color3.fromRGB(34, 18, 52), Reflectance = 0.15 })
	stagePart({ Name = "Step", Size = Vector3.new(128, 0.8, 4), Position = Vector3.new(0, 0.4, STAGE_Z - 10),
		Color = Color3.fromRGB(58, 30, 86) })
	stagePart({ Name = "Edge", Size = Vector3.new(124, 0.3, 0.5), Position = Vector3.new(0, DECK_TOP + 0.05, STAGE_Z - 7.8),
		Color = Color3.fromRGB(255, 170, 40), Material = Enum.Material.Neon })
	for x = -62, 62, 4 do
		table.insert(bulbs, stagePart({ Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8,
			Position = Vector3.new(x, 1.15, STAGE_Z - 11.2), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 220, 120) }))
	end

	local backdrop = stagePart({ Name = "Backdrop", Size = Vector3.new(124, 18, 1), Position = Vector3.new(0, DECK_TOP + 9, STAGE_Z + 11.5),
		Color = Color3.fromRGB(26, 12, 40) })
	stagePart({ Name = "BackdropTrim", Size = Vector3.new(125, 0.6, 1.4), Position = Vector3.new(0, DECK_TOP + 18, STAGE_Z + 11.5),
		Color = Color3.fromRGB(255, 90, 200), Material = Enum.Material.Neon })
	local sign = Instance.new("SurfaceGui")
	sign.Face = Enum.NormalId.Front
	sign.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sign.PixelsPerStud = 12
	sign.LightInfluence = 0
	local signText = Instance.new("TextLabel")
	signText.AnchorPoint = Vector2.new(0.5, 0)
	signText.Position = UDim2.fromScale(0.5, 0.05)
	signText.Size = UDim2.fromScale(0.5, 0.14)
	signText.BackgroundTransparency = 1
	signText.Font = FONT
	signText.TextScaled = true
	signText.Text = "CLIMB THE RARITY LADDER"
	signText.TextColor3 = Color3.fromRGB(255, 225, 120)
	signText.Parent = sign
	sign.Parent = backdrop

	local confetti = stagePart({ Name = "ConfettiSky", Size = Vector3.new(120, 1, 22), Position = Vector3.new(0, 30, STAGE_Z),
		Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 30
	emitter.Lifetime = NumberRange.new(5, 7)
	emitter.Speed = NumberRange.new(0, 2)
	emitter.Acceleration = Vector3.new(0, -5, 0)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Size = NumberSequence.new(0.7)
	emitter.LightEmission = 0.6
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 160)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 255, 120)),
	})
	emitter.Parent = confetti
end

-- One pedestal: a glossy column whose height grows with rarity, a neon ring and up-light in the rarity's
-- color, a beam of light from above and a plaque with the rarity's name.
local function buildPedestal(index: number, x: number, width: number, rarity): number
	local height = 1.2 + (index - 1) * 0.55
	local top = DECK_TOP + height
	stagePart({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, width, width),
		CFrame = CFrame.new(x, DECK_TOP + height / 2, STAGE_Z) * UP, Color = Color3.fromRGB(28, 22, 40), Reflectance = 0.2 })
	local ring = stagePart({ Name = "PedestalRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, width + 0.7, width + 0.7),
		CFrame = CFrame.new(x, top, STAGE_Z) * UP, Color = rarity.color, Material = Enum.Material.Neon })
	stagePart({ Name = "PedestalBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, width + 1.4, width + 1.4),
		CFrame = CFrame.new(x, DECK_TOP + 0.15, STAGE_Z) * UP, Color = rarity.color:Lerp(Color3.new(0, 0, 0), 0.4),
		Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = rarity.color
	light.Range = 14
	light.Brightness = 2.5
	light.Parent = ring

	local low = Instance.new("Attachment")
	low.Parent = ring
	low.WorldPosition = Vector3.new(x, top + 0.2, STAGE_Z)
	local high = Instance.new("Attachment")
	high.Parent = ring
	high.WorldPosition = Vector3.new(x, top + 26, STAGE_Z + 2)
	local beam = Instance.new("Beam")
	beam.Attachment0 = high
	beam.Attachment1 = low
	beam.Width0 = width * 0.35
	beam.Width1 = width * 1.05
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(rarity.color)
	beam.Transparency = NumberSequence.new(1, 0.72)
	beam.Segments = 1
	beam.Parent = ring

	local plaque = stagePart({ Name = "Plaque", Size = Vector3.new(math.min(width * 0.85, 9), 1.5, 0.3),
		CFrame = CFrame.new(x, DECK_TOP + 0.75, STAGE_Z - width / 2 - 1.4) * CFrame.Angles(math.rad(-18), 0, 0),
		Color = Color3.fromRGB(20, 12, 30) })
	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Front
	face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	face.PixelsPerStud = 40
	face.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = FONT
	text.TextScaled = true
	text.Text = rarity.label:upper()
	text.TextColor3 = rarity.color
	text.TextStrokeTransparency = 0.4
	text.Parent = face
	face.Parent = plaque
	return top
end

buildStageShell()
stage.Parent = workspace
-- the brainrots wait for the server's mesh templates, so the screen shows first and they arrive after
task.spawn(function()
	for index, spec in LINEUP do
		if not active then
			return
		end
		local id, mutationId, x, width = spec[1], spec[2], stageX(spec[3]), spec[4]
		local rarity = BrainrotCatalog.RARITY_BY_ID[BrainrotCatalog.BY_ID[id].rarity]
		local top = buildPedestal(index, x, width, rarity)
		local model = BrainrotModel.build(id, mutationId)
		if not active then
			model:Destroy()
			return
		end
		local home = CFrame.lookAt(Vector3.new(x, top + 0.2, STAGE_Z), Vector3.new(x, top + 0.2, STAGE_Z - 10))
		model:PivotTo(home)
		BrainrotModel.label(model, nil, nil, true)
		model.Parent = stage
		table.insert(showcase, { model = model, home = home, phase = index * 0.9 })
	end
end)

-- Marquee bulbs chase along the stage edge; the brainrots turn a little on their pedestals.
local function animateStage(t: number)
	for i, bulb in bulbs do
		local lit = (i + math.floor(t * 8)) % 3 == 0
		bulb.Color = if lit then Color3.fromRGB(255, 245, 200) else Color3.fromRGB(255, 140, 40)
		bulb.Transparency = if lit then 0 else 0.35
	end
	for _, entry in showcase do
		entry.model:PivotTo(entry.home * CFrame.Angles(0, math.sin(t * 0.9 + entry.phase) * 0.45, 0))
	end
end

-- The camera sways gently in front of the stage, the field and the volcano behind it.
local function orbitCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local t = os.clock() - started
	local sway = math.sin(t * 0.3) * 6
	camera.CFrame = CFrame.lookAt(Vector3.new(sway, 22, STAGE_Z - 52), Vector3.new(0, 2, STAGE_Z + 30))
end

local function play()
	if not active then
		return
	end
	active = false
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	setOtherGuis(true)
	stage:Destroy()
	gui:Destroy()
	ContextActionService:UnbindAction("BrainrotPlay")
end

playButton.Activated:Connect(play)
ContextActionService:BindAction("BrainrotPlay", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		play()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Return, Enum.KeyCode.Space)

RunService.RenderStepped:Connect(function()
	if not active then
		return
	end
	scale.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.Y / 760, 0.5, 1.4)
	setOtherGuis(false)
	orbitCamera()
	animateStage(os.clock() - started)
	local pulse = 1 + math.sin(os.clock() * 4) * 0.04
	playButton.Size = UDim2.fromOffset(300 * pulse, 86 * pulse)
end)

gui.Parent = playerGui
