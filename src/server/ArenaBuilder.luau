-- Builds the whole 3D map at server start: four player bases in the safe zone, the four-zone field
-- running north to the volcano, safe domes, zone gates, lava moats, decor, the title board and lighting.

local Lighting = game:GetService("Lighting")

local BrainrotModel = require(game.ReplicatedStorage.BrainrotModel)
local GameConfig = require(game.ReplicatedStorage.GameConfig)

local ArenaBuilder = {}

local FONT = Enum.Font.FredokaOne
local UP = CFrame.Angles(0, 0, math.rad(90))
local PLOT_COLORS = {
	Color3.fromRGB(255, 120, 190),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(150, 235, 80),
	Color3.fromRGB(255, 170, 60),
}

local worldFolder: Folder

-- The build steps, each defined further down in the order buildWorld runs them.
local buildLighting, buildGround, buildZoneGates, buildVolcano, buildSafeDomes, buildTitleBoard, buildPlayerBase

-- Builds the whole arena once and keeps what the other services need: the player bases (plots) and
-- the safe domes.
function ArenaBuilder.buildWorld()
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = workspace

	buildLighting()
	buildGround()
	buildZoneGates()
	buildVolcano()
	local domes = buildSafeDomes()
	buildTitleBoard()
	local plots = {}
	for index = 1, GameConfig.PLOT_COUNT do
		plots[index] = buildPlayerBase(index)
		task.wait()
	end
	ArenaBuilder.plots = plots
	ArenaBuilder.domes = domes
	return ArenaBuilder
end

local function part(props: { [string]: any }, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent or worldFolder
	return p
end

local function surfaceText(target: BasePart, face: Enum.NormalId, lines: { { text: string, color: Color3, size: number } }, bg: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = math.min(20, 1600 / math.max(target.Size.X, target.Size.Y, target.Size.Z))
	gui.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = bg or Color3.new(0, 0, 0)
	frame.BackgroundTransparency = if bg then 0 else 1
	frame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	local labels = {}
	for i, spec in lines do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = i
		label.Size = UDim2.fromScale(1, spec.size)
		label.BackgroundTransparency = 1
		label.Font = FONT
		label.TextScaled = true
		label.Text = spec.text
		label.TextColor3 = spec.color
		label.TextStrokeTransparency = 0
		label.Parent = frame
		labels[i] = label
	end
	gui.Parent = target
	return labels
end

-- A one-line floating tag `height` studs straight above a part, hung from an unrotated attachment
-- (a billboard's offset turns with a rotated part, so tags on upright cylinders would slide sideways).
function ArenaBuilder.tagAbove(target: BasePart, height: number, width: number, text: string, color: Color3, maxDistance: number?)
	local anchor = Instance.new("Attachment")
	anchor.Name = "TagAnchor"
	anchor.Parent = target
	anchor.WorldCFrame = CFrame.new(target.Position + Vector3.new(0, height, 0))
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Adornee = anchor
	tag.Size = UDim2.fromScale(width, width / 5.5) -- studs; wide enough that scaled text stays on one line
	tag.LightInfluence = 0
	tag.MaxDistance = maxDistance or 150
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = tag
	tag.Parent = anchor
	return tag, label
end

function buildLighting()
	Lighting.ClockTime = 15.4
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(70, 60, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 130, 140)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(255, 205, 175)
	atmosphere.Decay = Color3.fromRGB(190, 110, 90)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 0.92
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.25
	grade.Contrast = 0.08
	grade.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Parent = Lighting
end

local TERRAIN_COLORS = {
	[Enum.Material.LeafyGrass] = Color3.fromRGB(96, 196, 72),
	[Enum.Material.Grass] = Color3.fromRGB(120, 206, 84),
	[Enum.Material.Sand] = Color3.fromRGB(240, 206, 132),
	[Enum.Material.Ground] = Color3.fromRGB(196, 132, 86),
	[Enum.Material.Basalt] = Color3.fromRGB(74, 58, 60),
	[Enum.Material.Rock] = Color3.fromRGB(128, 116, 112),
	[Enum.Material.CrackedLava] = Color3.fromRGB(255, 110, 30),
	[Enum.Material.Mud] = Color3.fromRGB(110, 78, 60),
}

-- A slab of terrain whose surface sits at y = 0, from x0..x1 and z0..z1 (smooth terrain's surface lands
-- 2 studs above a filled block's top, so the block stops at y = -2).
local function terrainSlab(material: Enum.Material, x0: number, x1: number, z0: number, z1: number)
	workspace.Terrain:FillBlock(CFrame.new((x0 + x1) / 2, -5, (z0 + z1) / 2), Vector3.new(x1 - x0, 6, z1 - z0), material)
end

-- The ground is real terrain: a grassy safe zone, one material per field zone, lava trenches along the
-- field, and rolling hills that frame the map and darken to volcanic rock toward the volcano.
function buildGround()
	local terrain = workspace.Terrain
	terrain:Clear()
	pcall(function()
		(terrain :: any).Decoration = true
	end)
	for material, color in TERRAIN_COLORS do
		terrain:SetMaterialColor(material, color)
	end

	local halfWidth = GameConfig.FIELD_WIDTH / 2
	terrainSlab(Enum.Material.Mud, -420, 420, -260, 620)
	terrainSlab(Enum.Material.LeafyGrass, -170, 170, -150, 0)
	local materials = { Enum.Material.Grass, Enum.Material.Sand, Enum.Material.Ground, Enum.Material.Basalt }
	for index, zone in GameConfig.ZONES do
		terrainSlab(materials[index], -halfWidth, halfWidth, zone.from, zone.to)
	end
	task.wait()

	part({ Name = "SafeLine", Size = Vector3.new(GameConfig.FIELD_WIDTH, 0.3, 2.5), Position = Vector3.new(0, 0.1, -1),
		Color = Color3.fromRGB(60, 255, 120), Material = Enum.Material.Neon })
	local safeSign = part({ Name = "SafeSign", Size = Vector3.new(60, 0.2, 8), Position = Vector3.new(0, 0.4, -8),
		Transparency = 1, CanCollide = false })
	surfaceText(safeSign, Enum.NormalId.Top, { { text = "SAFE ZONE - LAVA STOPS HERE", color = Color3.fromRGB(230, 255, 230), size = 1 } })

	for _, side in { -1, 1 } do
		part({ Name = "Rail", Size = Vector3.new(2, 3, GameConfig.FIELD_LENGTH + 20),
			Position = Vector3.new(side * (halfWidth + 1), 1.5, GameConfig.FIELD_LENGTH / 2),
			Color = Color3.fromRGB(110, 70, 45), Material = Enum.Material.WoodPlanks })
		-- a lava trench just outside each rail
		local trenchX = side * (halfWidth + 24)
		terrain:FillBlock(CFrame.new(trenchX, -2, GameConfig.FIELD_LENGTH / 2 + 10), Vector3.new(40, 8, GameConfig.FIELD_LENGTH + 40),
			Enum.Material.Air)
		terrain:FillBlock(CFrame.new(trenchX, -7, GameConfig.FIELD_LENGTH / 2 + 10), Vector3.new(44, 4, GameConfig.FIELD_LENGTH + 44),
			Enum.Material.Basalt)
		part({ Name = "LavaMoat", Size = Vector3.new(40, 1, GameConfig.FIELD_LENGTH + 40),
			Position = Vector3.new(trenchX, -2.6, GameConfig.FIELD_LENGTH / 2 + 10),
			Color = Color3.fromRGB(255, 100, 20), Material = Enum.Material.Neon, CanCollide = false })
	end

	-- hills: two ridges along the field and one behind the bases
	local rng = Random.new(3)
	for z = -150, 460, 34 do
		for _, side in { -1, 1 } do
			local material = if z < 120 then Enum.Material.Grass elseif z < 280 then Enum.Material.Rock else Enum.Material.Basalt
			local radius = rng:NextNumber(30, 48)
			terrain:FillBall(Vector3.new(side * rng:NextNumber(205, 245), -radius * 0.35, z), radius, material)
		end
	end
	for x = -260, 260, 40 do
		local radius = rng:NextNumber(32, 50)
		terrain:FillBall(Vector3.new(x, -radius * 0.3, rng:NextNumber(-215, -195)), radius, Enum.Material.Grass)
	end
	task.wait()
end

function buildZoneGates()
	local halfWidth = GameConfig.FIELD_WIDTH / 2
	for index, zone in GameConfig.ZONES do
		if index == 1 then
			continue
		end
		local z = zone.from
		for _, side in { -1, 1 } do
			local x = side * (halfWidth - 2)
			part({ Name = "GatePillar", Size = Vector3.new(5, 24, 5), Position = Vector3.new(x, 12, z),
				Color = Color3.fromRGB(150, 138, 130), Material = Enum.Material.Cobblestone })
			part({ Name = "GateFoot", Size = Vector3.new(7, 2, 7), Position = Vector3.new(x, 1, z),
				Color = Color3.fromRGB(120, 110, 104), Material = Enum.Material.Cobblestone })
			part({ Name = "GateLamp", Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Position = Vector3.new(x, 31, z),
				Color = zone.color:Lerp(Color3.new(1, 1, 1), 0.3), Material = Enum.Material.Neon })
		end
		local beam = part({ Name = "GateBeam", Size = Vector3.new(GameConfig.FIELD_WIDTH, 6, 2), Position = Vector3.new(0, 26, z),
			Color = zone.color })
		local best = "?"
		for _, rarity in { "Secret", "BrainrotGod", "Mythic", "Legendary", "Epic", "Rare" } do
			if zone.weights[rarity] then
				best = rarity
				break
			end
		end
		local text = { { text = ("ZONE %d  -  %s  -  up to %s"):format(index, zone.name:upper(), best:upper()),
			color = Color3.new(1, 1, 1), size = 1 } }
		surfaceText(beam, Enum.NormalId.Front, text)
		surfaceText(beam, Enum.NormalId.Back, text)
	end
end

-- The volcano is a terrain cone of basalt and rock with a glowing lava crater and lava flows down its face.
local VOLCANO_Z = GameConfig.FIELD_LENGTH + 92
local VOLCANO_BASE_RADIUS = 84
local VOLCANO_TOP_RADIUS = 20
local VOLCANO_HEIGHT = 100

function buildVolcano()
	local terrain = workspace.Terrain
	local layers = VOLCANO_HEIGHT / 4
	for i = 0, layers - 1 do
		local y = i * 4
		local radius = VOLCANO_BASE_RADIUS + (VOLCANO_TOP_RADIUS - VOLCANO_BASE_RADIUS) * (i / layers)
		local material = if i % 5 == 2 then Enum.Material.Rock else Enum.Material.Basalt
		terrain:FillCylinder(CFrame.new(0, y + 2, VOLCANO_Z), 4, radius, material)
		if i % 6 == 5 then
			task.wait()
		end
	end
	terrain:FillCylinder(CFrame.new(0, VOLCANO_HEIGHT - 2, VOLCANO_Z), 8, VOLCANO_TOP_RADIUS - 4, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(0, VOLCANO_HEIGHT - 7, VOLCANO_Z), 2, VOLCANO_TOP_RADIUS - 4, Enum.Material.CrackedLava)
	local crater = part({ Name = "Crater", Size = Vector3.new(1.5, (VOLCANO_TOP_RADIUS - 4) * 2, (VOLCANO_TOP_RADIUS - 4) * 2),
		CFrame = CFrame.new(0, VOLCANO_HEIGHT - 5.5, VOLCANO_Z) * UP,
		Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 110, 20), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 4
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Parent = crater
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 6
	smoke.Lifetime = NumberRange.new(8, 12)
	smoke.Speed = NumberRange.new(10, 16)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 40) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 80, 80))
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Parent = crater
	-- lava flows down the face toward the field, following the cone's slope
	local run = VOLCANO_BASE_RADIUS - VOLCANO_TOP_RADIUS
	local length = math.sqrt(run * run + VOLCANO_HEIGHT * VOLCANO_HEIGHT)
	local slope = math.atan2(VOLCANO_HEIGHT, run)
	for _, spec in { { -0.35, 7 }, { 0.05, 9 }, { 0.42, 6 } } do
		local angle, width = spec[1], spec[2]
		local midRadius = (VOLCANO_BASE_RADIUS + VOLCANO_TOP_RADIUS) / 2 + 1.5
		local mid = Vector3.new(math.sin(angle) * midRadius, VOLCANO_HEIGHT / 2 + 1, VOLCANO_Z - math.cos(angle) * midRadius)
		part({ Name = "LavaFlow", Size = Vector3.new(width, 1, length),
			CFrame = CFrame.new(mid) * CFrame.Angles(0, -angle, 0) * CFrame.Angles(-slope, 0, 0),
			Color = Color3.fromRGB(255, 120, 30), Material = Enum.Material.Neon, CanCollide = false })
	end
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.45
	clouds.Color = Color3.fromRGB(255, 240, 235)
	clouds.Parent = workspace.Terrain
end

function buildSafeDomes(): { { position: Vector3, radius: number } }
	local domes = {}
	local radius = GameConfig.SAFE_DOME_RADIUS
	for index, zone in GameConfig.ZONES do
		local z = zone.from + (zone.to - zone.from) / 2
		for _, x in (if index % 2 == 1 then { -70, 50 } else { -45, 75 }) do
			local center = Vector3.new(x, 0, z)
			part({ Name = "SafeDome", Size = Vector3.one * radius * 2, Position = center, Shape = Enum.PartType.Ball,
				Color = Color3.fromRGB(80, 255, 140), Material = Enum.Material.ForceField, Transparency = 0.15,
				CanCollide = false, CanQuery = false, CanTouch = false })
			local ring = part({ Name = "DomeRing", Size = Vector3.new(0.4, radius * 2 + 1, radius * 2 + 1),
				CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0)) * UP, Shape = Enum.PartType.Cylinder,
				Color = Color3.fromRGB(80, 255, 140), Material = Enum.Material.Neon, CanCollide = false })
			ArenaBuilder.tagAbove(ring, radius + 3, 18, "SAFE DOME", Color3.fromRGB(150, 255, 180), 220)
			table.insert(domes, { position = center, radius = radius })
		end
	end
	return domes
end

local function buildTree(position: Vector3, height: number)
	part({ Name = "Trunk", Size = Vector3.new(height, 2, 2), CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * UP,
		Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood })
	for i = 0, 3 do
		local angle = i * math.pi / 2
		part({ Name = "Leaf", Size = Vector3.new(9, 1.2, 3.5), CanCollide = false,
			CFrame = CFrame.new(position + Vector3.new(0, height, 0)) * CFrame.Angles(0, angle, 0)
				* CFrame.new(3.5, -0.8, 0) * CFrame.Angles(0, 0, math.rad(-18)),
			Color = Color3.fromRGB(60, 170, 70), Material = Enum.Material.Grass })
	end
end

function buildTitleBoard()
	local board = part({ Name = "TitleBoard", Size = Vector3.new(130, 34, 2), Position = Vector3.new(0, 34, -116),
		Color = Color3.fromRGB(40, 20, 60) })
	surfaceText(board, Enum.NormalId.Back, {
		{ text = GameConfig.GAME_NAME, color = Color3.fromRGB(255, 220, 60), size = 0.55 },
		{ text = "grab brainrots - run home - outrun the lava", color = Color3.fromRGB(255, 255, 255), size = 0.25 },
	}, Color3.fromRGB(50, 22, 80))
	for _, x in { -55, 55 } do
		part({ Name = "BoardPost", Size = Vector3.new(3, 20, 3), Position = Vector3.new(x, 8, -116), Color = Color3.fromRGB(60, 40, 40) })
	end
end

function buildPlayerBase(index: number)
	local size = GameConfig.PLOT_SIZE
	local half = size / 2
	local color = PLOT_COLORS[index]
	local center = Vector3.new((index - (GameConfig.PLOT_COUNT + 1) / 2) * GameConfig.PLOT_SPACING, 0, GameConfig.PLOT_CENTER_Z)
	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder.Parent = worldFolder

	part({ Name = "Floor", Size = Vector3.new(size, 1, size), Position = center + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(214, 168, 118):Lerp(color, 0.12), Material = Enum.Material.WoodPlanks }, folder)
	part({ Name = "Trim", Size = Vector3.new(size + 1, 0.6, size + 1), Position = center + Vector3.new(0, 0.3, 0),
		Color = color, Material = Enum.Material.Neon }, folder)

	-- fences on three sides, a gate gap on the field side (+Z)
	local fenceColor = Color3.fromRGB(240, 240, 250)
	local fences = {
		part({ Name = "Fence", Size = Vector3.new(size, 4, 1), Position = center + Vector3.new(0, 3, -half), Color = fenceColor }, folder),
	}
	for _, side in { -1, 1 } do
		table.insert(fences, part({ Name = "Fence", Size = Vector3.new(1, 4, size), Position = center + Vector3.new(side * half, 3, 0),
			Color = fenceColor }, folder))
		table.insert(fences, part({ Name = "Fence", Size = Vector3.new(half - 9, 4, 1),
			Position = center + Vector3.new(side * (half + 9) / 2, 3, half), Color = fenceColor }, folder))
	end

	local pads = {}
	local padXs = { -18, -6, 6, 18 }
	local rowRise = { 3, 1.5, 0 } -- back rows sit on steps so every brainrot faces the gate in view
	for row, dz in { -20, -8, 4 } do
		local rise = rowRise[row]
		if rise > 0 then
			part({ Name = "Tier", Size = Vector3.new(size - 2, rise, 12), Position = center + Vector3.new(0, 1 + rise / 2, dz),
				Color = Color3.fromRGB(176, 128, 84):Lerp(color, 0.15), Material = Enum.Material.WoodPlanks }, folder)
			part({ Name = "TierEdge", Size = Vector3.new(size - 2, 0.4, 0.6), Position = center + Vector3.new(0, 1 + rise - 0.1, dz + 6),
				Color = color, Material = Enum.Material.Neon }, folder)
		end
		for column, dx in padXs do
			local position = center + Vector3.new(dx, 1 + rise, dz)
			local pad = part({ Name = "Pad", Size = Vector3.new(0.5, 6.4, 6.4), CFrame = CFrame.new(position + Vector3.new(0, 0.25, 0)) * UP,
				Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(50, 50, 64) }, folder)
			part({ Name = "PadRing", Size = Vector3.new(0.3, 7.2, 7.2), CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * UP,
				Shape = Enum.PartType.Cylinder, Color = color, Material = Enum.Material.Neon }, folder)
			table.insert(pads, { part = pad, base = position,
				cframe = CFrame.lookAt(position + Vector3.new(0, 0.5, 0), position + Vector3.new(0, 0.5, 10)),
				index = (row - 1) * #padXs + column })
		end
	end

	local lockButton = part({ Name = "LockButton", Size = Vector3.new(1, 6, 6),
		CFrame = CFrame.new(center + Vector3.new(18, 1.5, half - 9)) * UP, Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon }, folder)
	local _, lockText = ArenaBuilder.tagAbove(lockButton, 5, 14, "STEP TO LOCK BASE", Color3.new(1, 1, 1), 120)

	local walls = {}
	for _, spec in {
		{ Vector3.new(size, 12, 0.6), Vector3.new(0, 6, -half) },
		{ Vector3.new(size, 12, 0.6), Vector3.new(0, 6, half) },
		{ Vector3.new(0.6, 12, size), Vector3.new(-half, 6, 0) },
		{ Vector3.new(0.6, 12, size), Vector3.new(half, 6, 0) },
	} do
		table.insert(walls, part({ Name = "LaserWall", Size = spec[1], Position = center + spec[2],
			Color = Color3.fromRGB(255, 40, 60), Material = Enum.Material.ForceField, Transparency = 1,
			CanCollide = false, CanQuery = false, CanTouch = false }, folder))
	end

	local signPart = part({ Name = "Sign", Size = Vector3.new(34, 8, 1), Position = center + Vector3.new(0, 11, -half),
		Color = color }, folder)
	local signLabels = surfaceText(signPart, Enum.NormalId.Back, {
		{ text = "EMPTY BASE", color = Color3.new(1, 1, 1), size = 0.6 },
		{ text = "$0/s", color = Color3.fromRGB(90, 255, 110), size = 0.4 },
	}, color:Lerp(Color3.new(0, 0, 0), 0.35))

	local home = Instance.new("Attachment")
	home.Name = "Home"
	home.Position = Vector3.new(0, 3, 0)
	local homeAnchor = part({ Name = "HomeAnchor", Size = Vector3.one, Position = center, Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false }, folder)
	home.Parent = homeAnchor

	return {
		index = index,
		center = center,
		color = color,
		folder = folder,
		pads = pads,
		fences = fences,
		lockButton = lockButton,
		lockText = lockText,
		walls = walls,
		signTitle = signLabels[1],
		signIncome = signLabels[2],
		home = home,
		spawnCFrame = CFrame.lookAt(center + Vector3.new(0, 4, half - 6), center + Vector3.new(0, 4, half + 20)),
	}
end

-- Textured props made for this game with Roblox's AI mesh generator; loaded with the brainrot meshes.
ArenaBuilder.PROPS = {
	PalmTree = { mesh = "rbxassetid://134713643057911", texture = "rbxassetid://139159004236499" },
	Boulder = { mesh = "rbxassetid://137979105238472", texture = "rbxassetid://136114260408476" },
	LavaCrystals = { mesh = "rbxassetid://135602396567003", texture = "rbxassetid://76592104740672" },
	Mushroom = { mesh = "rbxassetid://110753875468421", texture = "rbxassetid://82925802726940" },
	FlowerBush = { mesh = "rbxassetid://91858229214057", texture = "rbxassetid://72559583399437" },
	Pedestal = { mesh = "rbxassetid://133104771121151", texture = "rbxassetid://88351027716547" },
	Fence = { mesh = "rbxassetid://134968860650361", texture = "rbxassetid://135001026142290" },
}

local propsFolder: Folder

-- Places one prop `height` studs tall standing at `position`; false when its mesh did not load.
local function placeProp(key: string, position: Vector3, height: number, yaw: number, collide: boolean): MeshPart?
	local template = BrainrotModel.meshTemplate(key)
	if not template then
		return nil
	end
	local prop = template:Clone()
	prop.Name = key
	prop.Size = template.Size * (height / template.Size.Y)
	prop.CFrame = CFrame.new(position + Vector3.new(0, prop.Size.Y / 2 - 0.2, 0)) * CFrame.Angles(0, yaw, 0)
	prop.Anchored = true
	prop.CanCollide = collide
	prop.CanQuery = false
	prop.CanTouch = false
	prop.Parent = propsFolder
	return prop
end

local function clearOfDomes(position: Vector3, margin: number): boolean
	for _, dome in ArenaBuilder.domes do
		if (Vector3.new(position.X, 0, position.Z) - dome.position).Magnitude < dome.radius + margin then
			return false
		end
	end
	return true
end

-- Base pads become marble-and-gold pedestals (brainrots stand on top) and the white box fences become
-- picket fences; the box parts stay as invisible collision and tag anchors.
local function dressPlot(plot)
	for _, pad in plot.pads do
		local template = BrainrotModel.meshTemplate("Pedestal")
		if template then
			local pedestal = template:Clone()
			pedestal.Name = "Pedestal"
			pedestal.Size = Vector3.new(6.6, 1.6, 6.6)
			pedestal.CFrame = CFrame.new(pad.base + Vector3.new(0, 0.8, 0))
			pedestal.Anchored = true
			pedestal.CanCollide = true
			pedestal.Parent = plot.folder
			pad.part.Transparency = 1
			pad.cframe += Vector3.new(0, 1.1, 0)
		end
	end
	local fenceTemplate = BrainrotModel.meshTemplate("Fence")
	if not fenceTemplate then
		return
	end
	for _, fence in plot.fences do
		local alongX = fence.Size.X > fence.Size.Z
		local length = if alongX then fence.Size.X else fence.Size.Z
		local count = math.max(1, math.round(length / 8))
		local segment = length / count
		local axis = if alongX then Vector3.xAxis else Vector3.zAxis
		for i = 1, count do
			local piece = fenceTemplate:Clone()
			piece.Name = "Picket"
			piece.Size = Vector3.new(segment, 4.4, 1)
			local offset = axis * ((i - 0.5) * segment - length / 2)
			piece.CFrame = CFrame.new(fence.Position + offset + Vector3.new(0, 0.2, 0)) * (if alongX then CFrame.identity
				else CFrame.Angles(0, math.rad(90), 0))
			piece.Anchored = true
			piece.CanCollide = false
			piece.Parent = plot.folder
		end
		fence.Transparency = 1
	end
end

-- After the meshes load: scatters palm trees, boulders, mushrooms, flower bushes and lava crystals over
-- the map and dresses every base. Props whose mesh failed fall back to simple part trees and rocks.
function ArenaBuilder.decorate()
	propsFolder = Instance.new("Folder")
	propsFolder.Name = "Props"
	local rng = Random.new(11)
	local halfWidth = GameConfig.FIELD_WIDTH / 2

	local function tree(position: Vector3)
		if not placeProp("PalmTree", position, rng:NextNumber(15, 21), rng:NextNumber(0, math.pi * 2), false) then
			buildTree(position, rng:NextNumber(11, 16))
		end
	end
	for x = -160, 160, 24 do
		tree(Vector3.new(x + rng:NextNumber(-5, 5), 0, rng:NextNumber(-140, -128)))
	end
	for _, side in { -1, 1 } do
		for z = -110, -10, 26 do
			tree(Vector3.new(side * rng:NextNumber(142, 160), 0, z + rng:NextNumber(-5, 5)))
		end
		for z = 12, 230, 30 do
			tree(Vector3.new(side * rng:NextNumber(172, 186), 0, z + rng:NextNumber(-6, 6)))
		end
	end

	for x = -150, 150, 9 do
		local position = Vector3.new(x + rng:NextNumber(-2, 2), 0, rng:NextNumber(-104, -86))
		if math.abs(x) > 68 or rng:NextNumber() < 0.6 then
			local key = if rng:NextNumber() < 0.75 then "FlowerBush" else "Mushroom"
			placeProp(key, position, if key == "Mushroom" then rng:NextNumber(5, 8) else rng:NextNumber(2.6, 4),
				rng:NextNumber(0, math.pi * 2), false)
		end
	end

	for _ = 1, 70 do
		local position = Vector3.new(rng:NextNumber(-halfWidth + 6, halfWidth - 6), 0, rng:NextNumber(16, GameConfig.FIELD_LENGTH - 6))
		-- keep clear of the safe domes and of the title screen's showcase stage (z 4..30, |x| < 66)
		if not clearOfDomes(position, 6) or (position.Z < 40 and math.abs(position.X) < 72) then
			continue
		end
		local zone = GameConfig.zoneAt(position.Z)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local roll = rng:NextNumber()
		if zone == 4 then
			local crystal = placeProp("LavaCrystals", position, rng:NextNumber(4, 8), yaw, false)
			if crystal then
				local glow = Instance.new("PointLight")
				glow.Color = Color3.fromRGB(255, 120, 40)
				glow.Range = 14
				glow.Brightness = 1.5
				glow.Parent = crystal
			end
		elseif roll < 0.45 then
			if not placeProp("Boulder", position, rng:NextNumber(3, 7), yaw, true) then
				part({ Name = "Rock", Size = Vector3.new(5, 4, 4), Position = position, Shape = Enum.PartType.Ball,
					Color = Color3.fromRGB(165, 150, 140), Material = Enum.Material.Slate })
			end
		elseif zone and zone <= 2 then
			if roll < 0.75 then
				placeProp("FlowerBush", position, rng:NextNumber(2.6, 4), yaw, false)
			else
				placeProp("Mushroom", position, rng:NextNumber(5, 9), yaw, false)
			end
		end
	end
	for _ = 1, 14 do
		placeProp("LavaCrystals", Vector3.new(rng:NextNumber(-80, 80), 0, rng:NextNumber(362, 372)), rng:NextNumber(5, 10),
			rng:NextNumber(0, math.pi * 2), false)
	end
	for _, side in { -1, 1 } do
		for z = -60, 330, 24 do
			placeProp("Boulder", Vector3.new(side * rng:NextNumber(168, 190), 0, z + rng:NextNumber(-8, 8)), rng:NextNumber(5, 11),
				rng:NextNumber(0, math.pi * 2), true)
		end
	end

	for _, plot in ArenaBuilder.plots do
		dressPlot(plot)
	end
	propsFolder.Parent = worldFolder
end

function ArenaBuilder.isInSafeDome(position: Vector3): boolean
	for _, dome in ArenaBuilder.domes do
		local flat = Vector3.new(position.X - dome.position.X, 0, position.Z - dome.position.Z)
		if flat.Magnitude <= dome.radius then
			return true
		end
	end
	return false
end

return ArenaBuilder
