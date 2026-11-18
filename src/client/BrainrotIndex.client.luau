-- The Brainrot Index: a collection book of the whole cast, each with a live 3D portrait, its rarity,
-- cash per second and catchphrase. Brainrots you have not landed on your base yet show as silhouettes.
-- Toggle with the INDEX button or the B key.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage") -- the shared modules sit right in it
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local BrainrotModel = require(Shared:WaitForChild("BrainrotModel"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotIndex"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
local scale = Instance.new("UIScale")
scale.Parent = gui

local function label(parent: Instance, position: UDim2, size: UDim2, text: string, color: Color3, outline: number?)
	return UiKit.text(parent, text, { Position = position, Size = size, TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left, outline = outline or 2 })
end

local openButton = UiKit.button(gui, { title = "INDEX [B]", icon = "📖", color = UiKit.COLORS.orange,
	size = UDim2.fromOffset(300, 54), position = UDim2.new(0, 16, 0.42, 104) })
openButton.Name = "IndexButton"

local panel = UiKit.panel(gui, { Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromOffset(1010, 650), Visible = false })

local banner = UiKit.panel(panel, { Name = "Banner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 4),
	Size = UDim2.fromOffset(600, 60) }, UiKit.COLORS.orange)
local title = UiKit.text(banner, "📖 BRAINROT INDEX", { Font = UiKit.TITLE_FONT, Position = UDim2.fromOffset(14, 8),
	Size = UDim2.new(1, -28, 1, -16), outline = 3.5 })

local closeButton = UiKit.button(panel, { title = "X", color = UiKit.COLORS.red, size = UDim2.fromOffset(52, 52),
	anchor = Vector2.new(0.5, 0.5), position = UDim2.new(1, -8, 0, 8) })

local grid = Instance.new("Frame")
grid.Position = UDim2.fromOffset(18, 48)
grid.Size = UDim2.new(1, -36, 1, -60)
grid.BackgroundTransparency = 1
grid.Parent = panel
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.fromOffset(236, 106)
layout.CellPadding = UDim2.fromOffset(9, 9)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

local cards = {}

-- One card: a 3D portrait in a ViewportFrame beside the name, rarity, cash per second and catchphrase,
-- shaded in its rarity's color.
local function buildCard(order: number, def)
	local rarity = BrainrotCatalog.RARITY_BY_ID[def.rarity]
	local tint = if def.rarity == "Secret" then Color3.fromRGB(70, 70, 82) else rarity.color
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	UiKit.shade(card, UiKit.lighten(tint, 0.15), UiKit.darken(tint, 0.35))
	UiKit.corner(card, 14)
	UiKit.outline(card, 3)

	local viewport = Instance.new("ViewportFrame")
	viewport.Position = UDim2.fromOffset(4, 5)
	viewport.Size = UDim2.fromOffset(96, 96)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.Parent = card
	local model = BrainrotModel.build(def.id, "None")
	local _, size = model:GetBoundingBox()
	model.Parent = viewport
	local camera = Instance.new("Camera")
	local height = size.Y
	local distance = math.max(size.X, size.Y) * 1.25 + 2
	camera.CFrame = CFrame.lookAt(Vector3.new(distance * 0.45, height * 0.65, -distance), Vector3.new(0, height * 0.48, 0))
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local name = label(card, UDim2.fromOffset(104, 7), UDim2.new(1, -112, 0, 26), def.name, Color3.new(1, 1, 1), 2.5)
	label(card, UDim2.fromOffset(104, 34), UDim2.new(1, -112, 0, 20), rarity.label, UiKit.lighten(tint, 0.55))
	label(card, UDim2.fromOffset(104, 55), UDim2.new(1, -112, 0, 20), GameConfig.formatMoney(def.income) .. "/s",
		Color3.fromRGB(150, 255, 140))
	local quote = label(card, UDim2.fromOffset(104, 78), UDim2.new(1, -112, 0, 19), '"' .. def.quote .. '"',
		Color3.fromRGB(255, 250, 230), 1.5)
	card.Parent = grid
	cards[def.id] = { viewport = viewport, name = name, quote = quote, def = def, model = model, phase = order * 0.7 }
end

for order, def in BrainrotCatalog.CAST do
	buildCard(order, def)
end

local function applyDiscovered(discovered: { [string]: boolean })
	local found = 0
	for id, card in cards do
		local known = discovered[id] == true
		if known then
			found += 1
		end
		card.viewport.ImageColor3 = if known then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		card.name.Text = if known then card.def.name else "???"
		card.quote.Visible = known
	end
	title.Text = ("📖 BRAINROT INDEX  %d / %d"):format(found, #BrainrotCatalog.CAST)
end
applyDiscovered({})

GameConfig.remote("State").OnClientEvent:Connect(function(state)
	applyDiscovered(state.discovered or {})
end)

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		UiKit.pop(panel)
	end
end
openButton.Activated:Connect(toggle)
closeButton.Activated:Connect(toggle)
ContextActionService:BindAction("BrainrotIndex", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		toggle()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.B)

RunService.RenderStepped:Connect(function()
	scale.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.Y / 760, 0.55, 1.4)
	if panel.Visible then
		-- portraits sway on their turntables; moving them also redraws any mesh that finished loading late
		local t = os.clock()
		for _, card in cards do
			card.model:PivotTo(CFrame.Angles(0, math.sin(t * 1.2 + card.phase) * 0.45, 0))
		end
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
