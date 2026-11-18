-- Builds a brainrot's 3D model from its catalog look, paints its mutation on it and hangs its
-- name / rarity / cash-per-second label over it.

local CollectionService = game:GetService("CollectionService")

local BrainrotCatalog = require(script.Parent.BrainrotCatalog)
local GameConfig = require(script.Parent.GameConfig)

local BrainrotModel = {}

-- Every brainrot is built this much larger than its look's numbers, then by its rarity's scale.
BrainrotModel.BASE_SCALE = 1.4

-- A brainrot of catalog id `id` wearing mutation `mutationId`, standing on its Root at the origin: its
-- AI-generated mesh when that loaded, else its part-built look, scaled by its rarity. The steps it calls
-- are the functions below it.
function BrainrotModel.build(id: string, mutationId: string): Model
	local def = BrainrotCatalog.BY_ID[id]
	local model = Instance.new("Model")
	model.Name = def.name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(3, 0.2, 3)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local template = BrainrotModel.meshTemplate(id)
	if template then
		BrainrotModel.addMesh(model, root, template, BrainrotCatalog.MESHES[id].height)
	else
		BrainrotModel.addPartLook(model, root, def.look)
	end

	local rarity = BrainrotCatalog.RARITY_BY_ID[def.rarity]
	model:ScaleTo(rarity.scale * BrainrotModel.BASE_SCALE)
	local _, extents = model:GetBoundingBox()
	model:SetAttribute("BrainrotId", id)
	model:SetAttribute("Mutation", mutationId)
	model:SetAttribute("Height", extents.Y)
	BrainrotModel.applyMutation(model, mutationId)
	CollectionService:AddTag(model, "Brainrot")
	return model
end

local SHAPES = {
	Ball = Enum.PartType.Ball,
	Block = Enum.PartType.Block,
	Cylinder = Enum.PartType.Cylinder,
}

local UP = Vector3.new(0, 0, 90)
local LABEL_FONT = Enum.Font.FredokaOne

local function weldTo(part: BasePart, root: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function addPart(model: Model, root: BasePart, shape: string, size: Vector3, pos: Vector3, color: Color3, opts: { [string]: any })
	local part: BasePart
	if shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local p = Instance.new("Part")
		p.Shape = SHAPES[shape]
		part = p
	end
	local rot = opts.rot or Vector3.zero
	part.Name = opts.name or "Body"
	part.Size = size
	part.Color = color
	part.Material = Enum.Material[opts.mat or "SmoothPlastic"]
	part.Transparency = opts.alpha or 0
	part.CFrame = root.CFrame * CFrame.new(pos) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
	if opts.light then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10
		light.Brightness = 2
		light.Parent = part
	end
	weldTo(part, root)
	part.Parent = model
	return part
end

local TEMPLATE_FOLDER = "BrainrotMeshes"
local templates: Folder? = nil

-- Server: loads every AI-generated mesh of BrainrotCatalog.MESHES (and of `extraAssets`, such as the
-- world's props) into ReplicatedStorage, all at once, so the server and every client clone from the same
-- textured MeshParts. Waits at most `timeout` seconds; a mesh that fails or is late leaves its brainrot
-- on its part-built look.
function BrainrotModel.loadMeshTemplates(timeout: number, extraAssets: { [string]: { mesh: string, texture: string } }?)
	local AssetService = game:GetService("AssetService")
	local folder = Instance.new("Folder")
	folder.Name = TEMPLATE_FOLDER
	local assets = table.clone(BrainrotCatalog.MESHES) :: { [string]: any }
	for key, asset in extraAssets or {} do
		assets[key] = asset
	end
	local pending = 0
	for key, asset in assets do
		pending += 1
		task.spawn(function()
			local ok, meshPart = pcall(function()
				return AssetService:CreateMeshPartAsync(Content.fromUri(asset.mesh), {
					CollisionFidelity = Enum.CollisionFidelity.Box,
					RenderFidelity = Enum.RenderFidelity.Precise,
				})
			end)
			if ok and meshPart then
				meshPart.Name = key
				meshPart.TextureID = asset.texture
				meshPart.Anchored = true
				meshPart.CanCollide = false
				meshPart.Parent = folder
			else
				warn("Brainrot mesh failed to load, using its part look:", key, meshPart)
			end
			pending -= 1
		end)
	end
	local deadline = os.clock() + timeout
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	folder.Parent = game:GetService("ReplicatedStorage")
	templates = folder
end

-- The loaded mesh template for a catalog id (or "Furbetto"), nil when there is none.
function BrainrotModel.meshTemplate(key: string): MeshPart?
	if not templates then
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		templates = if game:GetService("RunService"):IsServer() then ReplicatedStorage:FindFirstChild(TEMPLATE_FOLDER) :: Folder?
			else ReplicatedStorage:WaitForChild(TEMPLATE_FOLDER, 20) :: Folder?
	end
	return templates and templates:FindFirstChild(key) :: MeshPart?
end

-- Welds a clone of a mesh template onto `root`, standing on it, `height` studs tall.
function BrainrotModel.addMesh(model: Model, root: BasePart, template: MeshPart, height: number): MeshPart
	local body = template:Clone()
	body.Name = "Body"
	body.Size = template.Size * (height / template.Size.Y)
	body.CFrame = root.CFrame * CFrame.new(0, body.Size.Y / 2, 0)
	body.Anchored = false
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.Massless = true
	-- a Weld (not a WeldConstraint) so each client can animate the body by moving its C0 locally while
	-- the server only ever moves the root
	local joint = Instance.new("Weld")
	joint.Name = "BodyJoint"
	joint.Part0 = root
	joint.Part1 = body
	joint.C0 = CFrame.new(0, body.Size.Y / 2, 0)
	joint.Parent = body
	body.Parent = model
	CollectionService:AddTag(model, "Waddler")
	return body
end

-- The fallback look: the catalog's primitive parts, legs, eyes and mouth.
function BrainrotModel.addPartLook(model: Model, root: BasePart, look)
	for _, spec in look.parts do
		addPart(model, root, spec.shape, spec.size, spec.pos, spec.color, spec.opts)
	end
	if look.legs then
		for _, side in { -0.6, 0.6 } do
			addPart(model, root, "Cylinder", Vector3.new(1.3, 0.45, 0.45), Vector3.new(side, 0.75, 0), look.legs.color, { rot = UP })
			addPart(model, root, "Ball", Vector3.new(0.7, 0.45, 1), Vector3.new(side, 0.2, -0.2), look.legs.color, {})
		end
	end
	local eyes = look.eyes
	if eyes then
		for _, side in { -1, 1 } do
			local x = side * eyes.spread
			addPart(model, root, "Ball", Vector3.one * eyes.size, Vector3.new(x, eyes.y, eyes.z), Color3.new(1, 1, 1), { name = "Eye" })
			addPart(model, root, "Ball", Vector3.one * eyes.size * 0.5, Vector3.new(x, eyes.y, eyes.z - eyes.size * 0.36),
				Color3.fromRGB(20, 20, 25), { name = "Eye" })
		end
	end
	if look.mouth then
		addPart(model, root, "Block", Vector3.new(look.mouth.w, 0.18, 0.1), Vector3.new(0, look.mouth.y, look.mouth.z),
			Color3.fromRGB(60, 20, 20), { name = "Eye" })
	end
end

-- Wraps a textured mesh in a slightly larger shimmering shell of the mutation's color, so the character
-- keeps its face and details under a gold, diamond, lava, rainbow or cosmic glow.
local function addMutationShell(model: Model, root: BasePart, body: MeshPart, mutation)
	local shell = body:Clone()
	shell:ClearAllChildren()
	shell.Name = "MutationShell"
	shell.TextureID = ""
	shell.Size = body.Size * 1.04
	shell.CFrame = body.CFrame
	shell.Color = mutation.color
	shell.Material = if mutation.id == "Diamond" then Enum.Material.Glass else Enum.Material.ForceField
	shell.Transparency = if mutation.id == "Diamond" then 0.55 else 0
	shell.CastShadow = false
	weldTo(shell, body) -- rides on the body so it waddles with it
	shell.Parent = model
	local glow = Instance.new("PointLight")
	glow.Color = mutation.color
	glow.Range = 12
	glow.Brightness = 1.5
	glow.Parent = body
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "MutationSparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(mutation.color)
	sparkle.LightEmission = 1
	sparkle.Rate = 8
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Parent = body
end

-- Paints a model's mutation: a mesh keeps its texture under a colored shell; a part look is tinted
-- (its eyes and mouth keep their colors).
function BrainrotModel.applyMutation(model: Model, mutationId: string)
	model:SetAttribute("Mutation", mutationId)
	local mutation = BrainrotCatalog.MUTATION_BY_ID[mutationId]
	if mutationId == "None" then
		return
	end
	local root = model.PrimaryPart :: BasePart
	local body = model:FindFirstChild("Body")
	if body and body:IsA("MeshPart") then
		local old = model:FindFirstChild("MutationShell")
		if old then
			old:Destroy()
		end
		addMutationShell(model, root, body, mutation)
	end
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") or part.Name == "Root" or part.Name == "Eye" or part:IsA("MeshPart") then
			continue
		end
		if mutationId == "Gold" then
			part.Color = part.Color:Lerp(mutation.color, 0.75)
			part.Material = Enum.Material.Metal
			part.Reflectance = 0.25
		elseif mutationId == "Diamond" then
			part.Color = part.Color:Lerp(mutation.color, 0.7)
			part.Material = Enum.Material.Glass
			part.Reflectance = 0.3
			part.Transparency = math.max(part.Transparency, 0.12)
		elseif mutationId == "Lava" then
			part.Color = part.Color:Lerp(mutation.color, 0.85)
			part.Material = Enum.Material.CrackedLava
		elseif mutationId == "Cosmic" then
			part.Color = part.Color:Lerp(Color3.fromRGB(70, 30, 150), 0.65)
			part.Material = Enum.Material.Glass
		end
	end
	if mutationId == "Lava" and not root:FindFirstChild("LavaFire") then
		local fire = Instance.new("Fire")
		fire.Name = "LavaFire"
		fire.Size = 4
		fire.Heat = 4
		fire.Color = Color3.fromRGB(255, 120, 30)
		fire.Parent = root
	elseif mutationId == "Cosmic" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(190, 120, 255)
		sparkles.Parent = root
	elseif mutationId == "Rainbow" then
		CollectionService:AddTag(model, "RainbowBrainrot")
	end
end

local function line(parent: Instance, order: number, height: number, text: string, color: Color3)
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.fromScale(1, height)
	label.BackgroundTransparency = 1
	label.Font = LABEL_FONT
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(20, 10, 30)
	label.Parent = parent
	return label
end

-- Hangs the label over a brainrot: mutation, name, rarity, cash per second, then `footer` (its price
-- in the field) and its catchphrase. A compact label (on a base pad) drops the catchphrase.
function BrainrotModel.label(model: Model, footer: string?, footerColor: Color3?, compact: boolean?): BillboardGui
	local id = model:GetAttribute("BrainrotId") :: string
	local mutationId = model:GetAttribute("Mutation") :: string
	local def = BrainrotCatalog.BY_ID[id]
	local rarity = BrainrotCatalog.RARITY_BY_ID[def.rarity]
	local mutation = BrainrotCatalog.MUTATION_BY_ID[mutationId]

	local old = model:FindFirstChild("Label")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = model.PrimaryPart
	-- sized in studs (big next to you, smaller far away) and hidden past MaxDistance so the field never clutters
	gui.Size = if compact then UDim2.fromScale(13, 5.6) else UDim2.fromScale(15, 7.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, (model:GetAttribute("Height") :: number) + 1, 0)
	gui.SizeOffset = Vector2.new(0, 0.5)
	gui.MaxDistance = if compact then 70 else 60
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = gui

	local unit = if compact then 1.45 else 1
	if mutationId ~= "None" then
		line(gui, 1, 0.15 * unit, mutation.label, mutation.color)
	end
	line(gui, 2, 0.22 * unit, def.name, Color3.new(1, 1, 1))
	line(gui, 3, 0.17 * unit, rarity.label, rarity.color)
	line(gui, 4, 0.17 * unit, GameConfig.formatMoney(BrainrotCatalog.incomeOf(id, mutationId)) .. "/s", Color3.fromRGB(90, 255, 110))
	if footer then
		line(gui, 5, 0.15, footer, footerColor or Color3.fromRGB(255, 225, 80))
	end
	if not compact then
		line(gui, 6, 0.12, '"' .. def.quote .. '"', Color3.fromRGB(215, 215, 230))
	end
	gui.Parent = model
	return gui
end

return BrainrotModel
