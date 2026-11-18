-- The game's cartoon UI kit, matching the sunny toy-like world: cream panels and candy-colored buttons
-- with chunky dark outlines, soft drop shadows, gradient shading, outlined text and bouncy presses.
-- Every client screen (HUD, Brainrot Index, title screen) builds from these pieces.

local TweenService = game:GetService("TweenService")

local UiKit = {}

UiKit.TITLE_FONT = Enum.Font.LuckiestGuy
UiKit.BODY_FONT = Enum.Font.FredokaOne

UiKit.INK = Color3.fromRGB(58, 32, 30) -- outlines and dark text
UiKit.CREAM = Color3.fromRGB(255, 249, 234)
UiKit.CREAM_SHADE = Color3.fromRGB(255, 225, 176)
UiKit.COLORS = {
	green = Color3.fromRGB(96, 214, 84),
	blue = Color3.fromRGB(64, 168, 255),
	red = Color3.fromRGB(255, 88, 82),
	purple = Color3.fromRGB(176, 104, 255),
	orange = Color3.fromRGB(255, 156, 44),
	gold = Color3.fromRGB(255, 206, 54),
	lava = Color3.fromRGB(255, 104, 40),
}

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end
UiKit.lighten = lighten
UiKit.darken = darken

function UiKit.corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

function UiKit.outline(parent: GuiObject, thickness: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Thickness = thickness or 3.5
	s.Color = color or UiKit.INK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

-- Vertical shading from `top` to `bottom` on a white-filled GuiObject.
function UiKit.shade(parent: GuiObject, top: Color3, bottom: Color3)
	parent.BackgroundColor3 = Color3.new(1, 1, 1)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
	return g
end

-- A soft dark copy behind `frame`, offset down, so panels look like they float.
local function addShadow(frame: GuiObject, radius: number)
	local parent = frame.Parent
	if not parent or parent:FindFirstChildWhichIsA("UIGridStyleLayout") then
		return nil -- a shadow would become a layout item; laid-out pieces go without
	end
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = frame.AnchorPoint
	shadow.Position = frame.Position + UDim2.fromOffset(0, 6)
	shadow.Size = frame.Size
	shadow.BackgroundColor3 = UiKit.INK
	shadow.BackgroundTransparency = 0.55
	shadow.ZIndex = frame.ZIndex - 1
	shadow.Visible = frame.Visible
	UiKit.corner(shadow, radius)
	shadow.Parent = frame.Parent
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		shadow.Visible = frame.Visible
	end)
	frame:GetPropertyChangedSignal("Position"):Connect(function()
		shadow.Position = frame.Position + UDim2.fromOffset(0, 6)
	end)
	frame:GetPropertyChangedSignal("Size"):Connect(function()
		shadow.Size = frame.Size
	end)
	return shadow
end

-- Text with a thick ink outline that scales to its box. `props` may set any TextLabel property.
function UiKit.text(parent: Instance, value: string, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = UiKit.BODY_FONT
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = value
	label.Size = UDim2.fromScale(1, 1)
	local outlineThickness = 2.5
	for key, v in props or {} do
		if key == "outline" then
			outlineThickness = v
		else
			(label :: any)[key] = v
		end
	end
	if outlineThickness > 0 then
		local s = Instance.new("UIStroke")
		s.Thickness = outlineThickness
		s.Color = UiKit.INK
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = label
	end
	label.Parent = parent
	return label
end

-- A panel: shaded fill (cream by default), chunky outline, rounded corners and a drop shadow.
function UiKit.panel(parent: Instance, props: { [string]: any }, fill: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	for key, v in props do
		(frame :: any)[key] = v
	end
	local base = fill or UiKit.CREAM
	if fill then
		UiKit.shade(frame, lighten(base, 0.18), darken(base, 0.12))
	else
		UiKit.shade(frame, UiKit.CREAM, UiKit.CREAM_SHADE)
	end
	UiKit.corner(frame, 18)
	UiKit.outline(frame, 4)
	frame.Parent = parent
	addShadow(frame, 18)
	return frame
end

-- Squishes `object` slightly while pressed and grows it a touch on hover.
function UiKit.bouncy(object: GuiButton)
	local s = Instance.new("UIScale")
	s.Parent = object
	local function to(value: number, time: number)
		TweenService:Create(s, TweenInfo.new(time, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = value }):Play()
	end
	object.MouseEnter:Connect(function()
		to(1.06, 0.15)
	end)
	object.MouseLeave:Connect(function()
		to(1, 0.15)
	end)
	object.MouseButton1Down:Connect(function()
		to(0.9, 0.08)
	end)
	object.MouseButton1Up:Connect(function()
		to(1.06, 0.2)
	end)
end

-- A candy button: icon and title on top, an optional sub line under, shaded in `color`.
-- Returns the button, its title label and its sub label.
function UiKit.button(parent: Instance, spec: { title: string, icon: string?, sub: string?, color: Color3, size: UDim2,
	position: UDim2?, anchor: Vector2?, layoutOrder: number? }): (TextButton, TextLabel, TextLabel?)
	local b = Instance.new("TextButton")
	b.Text = ""
	b.AutoButtonColor = false
	b.Size = spec.size
	b.Position = spec.position or UDim2.new()
	b.AnchorPoint = spec.anchor or Vector2.zero
	b.LayoutOrder = spec.layoutOrder or 0
	UiKit.shade(b, lighten(spec.color, 0.28), darken(spec.color, 0.12))
	UiKit.corner(b, 16)
	UiKit.outline(b, 4)
	-- glossy highlight along the top
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.AnchorPoint = Vector2.new(0.5, 0)
	gloss.Position = UDim2.new(0.5, 0, 0, 5)
	gloss.Size = UDim2.new(1, -16, 0.3, 0)
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.72
	gloss.BorderSizePixel = 0
	UiKit.corner(gloss, 10)
	gloss.Parent = b
	local hasSub = spec.sub ~= nil
	local title = UiKit.text(b, (if spec.icon then spec.icon .. " " else "") .. spec.title, {
		Name = "Title",
		Font = UiKit.TITLE_FONT,
		Position = UDim2.fromScale(0.06, if hasSub then 0.1 else 0.18),
		Size = UDim2.fromScale(0.88, if hasSub then 0.5 else 0.64),
		outline = 3,
	})
	local sub = nil
	if hasSub then
		sub = UiKit.text(b, spec.sub :: string, {
			Name = "Sub",
			Position = UDim2.fromScale(0.08, 0.58),
			Size = UDim2.fromScale(0.84, 0.32),
			TextColor3 = Color3.fromRGB(255, 248, 200),
			outline = 2,
		})
	end
	b.Parent = parent
	addShadow(b, 16)
	UiKit.bouncy(b)
	return b, title, sub
end

-- A quick scale-in pop for something that just appeared.
function UiKit.pop(object: GuiObject)
	local s = object:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Scale = 0.6
	s.Parent = object
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return UiKit
