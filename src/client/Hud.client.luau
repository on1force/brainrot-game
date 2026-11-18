-- The player's HUD over the 3D world, in the game's cartoon UI kit: cash and cash per second, the lava
-- wave countdown, the running event, what you carry, toasts, the zone you stand in, the Speed / Lock /
-- Rebirth buttons, and the background music with its mute button.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage") -- the shared modules sit right in it
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local player = Players.LocalPlayer
local actionRemote = GameConfig.remote("Action")
local C = UiKit.COLORS

local state = nil

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local scale = Instance.new("UIScale")
scale.Parent = gui

-- Cash card (left middle, clear of Roblox's top-left menu buttons)
local cashCard = UiKit.panel(gui, { Name = "Cash", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.42, 0),
	Size = UDim2.fromOffset(300, 184) })
UiKit.text(cashCard, "💰 CASH", { Name = "Caption", Font = UiKit.TITLE_FONT, Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -32, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.orange, outline = 2.5 })
local moneyLabel = UiKit.text(cashCard, "$0", { Name = "Money", Font = UiKit.TITLE_FONT, Position = UDim2.fromOffset(16, 38),
	Size = UDim2.new(1, -32, 0, 56), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.gold, outline = 3.5 })
local incomeLabel = UiKit.text(cashCard, "+$0/s", { Name = "Income", Font = UiKit.TITLE_FONT, Position = UDim2.fromOffset(16, 96),
	Size = UDim2.new(1, -32, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.green, outline = 3 })
local rebirthLabel = UiKit.text(cashCard, "Rebirth 0  -  x1 cash", { Name = "Rebirths", Position = UDim2.fromOffset(16, 132),
	Size = UDim2.new(1, -32, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(150, 70, 230), outline = 0 })
local padsLabel = UiKit.text(cashCard, "Base 0/8 brainrots", { Name = "Pads", Position = UDim2.fromOffset(16, 156),
	Size = UDim2.new(1, -32, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UiKit.INK, outline = 0 })

-- Lava wave countdown (top center)
local wavePanel = UiKit.panel(gui, { Name = "Wave", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(540, 76) }, C.lava)
local waveGradient = wavePanel:FindFirstChildOfClass("UIGradient") :: UIGradient
local waveLabel = UiKit.text(wavePanel, "🌋 LAVA WAVE IN 45s", { Name = "Text", Font = UiKit.TITLE_FONT,
	Position = UDim2.fromOffset(14, 7), Size = UDim2.new(1, -28, 0, 38), outline = 3 })
local waveBarBack = Instance.new("Frame")
waveBarBack.Position = UDim2.new(0, 18, 1, -24)
waveBarBack.Size = UDim2.new(1, -36, 0, 14)
waveBarBack.BackgroundColor3 = UiKit.darken(C.lava, 0.55)
UiKit.corner(waveBarBack, 7)
UiKit.outline(waveBarBack, 2.5)
waveBarBack.Parent = wavePanel
local waveBar = Instance.new("Frame")
waveBar.Size = UDim2.fromScale(0, 1)
UiKit.shade(waveBar, Color3.fromRGB(255, 240, 120), C.gold)
UiKit.corner(waveBar, 7)
waveBar.Parent = waveBarBack

-- Event banner (under the wave panel)
local eventPanel = UiKit.panel(gui, { Name = "Event", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96),
	Size = UDim2.fromOffset(540, 46) }, C.gold)
local eventLabel = UiKit.text(eventPanel, "", { Name = "Text", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12),
	outline = 2.5 })
eventPanel.Visible = false

-- Carry banner (bottom center)
local carryPanel = UiKit.panel(gui, { Name = "Carry", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -112),
	Size = UDim2.fromOffset(640, 56) }, C.red)
local carryGradient = carryPanel:FindFirstChildOfClass("UIGradient") :: UIGradient
local carryLabel = UiKit.text(carryPanel, "", { Name = "Text", Font = UiKit.TITLE_FONT, Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -24, 1, -16), outline = 3 })
carryPanel.Visible = false

-- Buttons (bottom right; Roblox's backpack hotbar with the bat sits bottom center)
local buttonRow = Instance.new("Frame")
buttonRow.Name = "Buttons"
buttonRow.AnchorPoint = Vector2.new(1, 1)
buttonRow.Position = UDim2.new(1, -16, 1, -18)
buttonRow.Size = UDim2.fromOffset(632, 84)
buttonRow.BackgroundTransparency = 1
buttonRow.Parent = gui
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
rowLayout.Padding = UDim.new(0, 12)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = buttonRow

local function actionButton(order: number, icon: string, title: string, color: Color3, action: string)
	local b, titleLabel, subLabel = UiKit.button(buttonRow, { title = title, icon = icon, sub = " ", color = color,
		size = UDim2.fromOffset(200, 80), layoutOrder = order })
	b.Activated:Connect(function()
		actionRemote:FireServer(action)
	end)
	return titleLabel, subLabel :: TextLabel
end

local _, speedSub = actionButton(1, "⚡", "SPEED [U]", C.blue, "BuySpeed")
local lockTitle, lockSub = actionButton(2, "🔒", "LOCK [L]", C.red, "LockBase")
local _, rebirthSub = actionButton(3, "🌀", "REBIRTH", C.purple, "Rebirth")

ContextActionService:BindAction("BrainrotSpeed", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		actionRemote:FireServer("BuySpeed")
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.U)
ContextActionService:BindAction("BrainrotLock", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		actionRemote:FireServer("LockBase")
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.L)

-- Toasts (right side): cream cards with a colored stripe, newest on top
local toastColumn = Instance.new("Frame")
toastColumn.AnchorPoint = Vector2.new(1, 0)
toastColumn.Position = UDim2.new(1, -16, 0, 160)
toastColumn.Size = UDim2.fromOffset(400, 420)
toastColumn.BackgroundTransparency = 1
toastColumn.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 10)
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastColumn
local toastCount = 0

local function toast(message: string, color: Color3?)
	toastCount += 1
	local accent = color or C.orange
	local card = UiKit.panel(toastColumn, { LayoutOrder = -toastCount, Size = UDim2.fromOffset(400, 52) })
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(0, 14, 1, 0)
	stripe.BackgroundColor3 = accent
	stripe.BorderSizePixel = 0
	UiKit.corner(stripe, 18)
	stripe.Parent = card
	local label = UiKit.text(card, message, { Name = "Text", Position = UDim2.fromOffset(24, 6), Size = UDim2.new(1, -34, 1, -12),
		TextColor3 = UiKit.INK, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, outline = 0 })
	UiKit.pop(card)
	for _, child in toastColumn:GetChildren() do
		if child:IsA("Frame") and child.LayoutOrder > -toastCount + 5 then
			child:Destroy()
		end
	end
	task.delay(5, function()
		if not card.Parent then
			return
		end
		for _, item in { card, stripe } do
			TweenService:Create(item, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		end
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		local cardStroke = card:FindFirstChildOfClass("UIStroke")
		if cardStroke then
			TweenService:Create(cardStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		card:Destroy()
	end)
end

-- Zone banner (fades in when you cross into a zone)
local zoneLabel = UiKit.text(gui, "", { Name = "Zone", Font = UiKit.TITLE_FONT, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.22, 0), Size = UDim2.fromOffset(640, 58), outline = 4 })
local zoneStroke = zoneLabel:FindFirstChildOfClass("UIStroke") :: UIStroke
zoneLabel.TextTransparency = 1
zoneStroke.Transparency = 1
local currentZone = -1

local function showZone(index: number?)
	if (index or 0) == currentZone then
		return
	end
	currentZone = index or 0
	zoneLabel.Text = if index then ("ZONE %d  -  %s"):format(index, GameConfig.ZONES[index].name:upper()) else "SAFE ZONE"
	zoneLabel.TextColor3 = if index then GameConfig.ZONES[index].color:Lerp(Color3.new(1, 1, 1), 0.35) else C.green
	zoneLabel.TextTransparency = 0
	zoneStroke.Transparency = 0
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.6)
	TweenService:Create(zoneLabel, info, { TextTransparency = 1 }):Play()
	TweenService:Create(zoneStroke, info, { Transparency = 1 }):Play()
end

-- Background music: a quiet looping playlist of light ukulele tracks from Roblox's licensed music
-- library, with a mute button in the bottom-left corner.
local PLAYLIST = { "rbxassetid://1839580471", "rbxassetid://1839578771", "rbxassetid://1845913205" }
local MUSIC_VOLUME = 0.22
local music = Instance.new("Sound")
music.Name = "BackgroundMusic"
music.Volume = MUSIC_VOLUME
music.Parent = SoundService
local track = 0
local muted = false
local function nextTrack()
	track = track % #PLAYLIST + 1
	music.SoundId = PLAYLIST[track]
	music:Play()
end
music.Ended:Connect(nextTrack)
task.defer(nextTrack)

local muteButton = UiKit.button(gui, { title = "🔊", color = C.green, size = UDim2.fromOffset(64, 64),
	anchor = Vector2.new(0, 1), position = UDim2.new(0, 16, 1, -18) })
local muteTitle = muteButton:FindFirstChild("Title") :: TextLabel
muteButton.Activated:Connect(function()
	muted = not muted
	music.Volume = if muted then 0 else MUSIC_VOLUME
	muteTitle.Text = if muted then "🔇" else "🔊"
	local gradient = muteButton:FindFirstChildOfClass("UIGradient") :: UIGradient
	local tint = if muted then Color3.fromRGB(150, 150, 160) else C.green
	gradient.Color = ColorSequence.new(UiKit.lighten(tint, 0.28), UiKit.darken(tint, 0.12))
end)

local function applyState(newState)
	state = newState
	moneyLabel.Text = GameConfig.formatMoney(state.money)
	incomeLabel.Text = "+" .. GameConfig.formatMoney(state.income) .. "/s"
	rebirthLabel.Text = ("🌀 Rebirth %d  -  x%s cash"):format(state.rebirths, tostring(state.multiplier))
	padsLabel.Text = ("🏠 Base %d/%d brainrots"):format(state.padsUsed, state.padsMax)
	speedSub.Text = if state.speedMax then "MAX" else GameConfig.formatMoney(state.speedCost)
	rebirthSub.Text = GameConfig.formatMoney(state.rebirthCost)
	if state.carrying then
		local rarity = BrainrotCatalog.RARITY_BY_ID[state.carrying.rarity]
		local mutation = if state.carrying.mutation ~= "None" then state.carrying.mutation:upper() .. " " else ""
		carryLabel.Text = (if state.carrying.stolen then "😈 STOLEN " else "🏃 CARRYING ") .. mutation .. state.carrying.name:upper()
			.. " - RUN HOME!"
		local tint = if state.carrying.rarity == "Secret" then Color3.fromRGB(60, 60, 70) else rarity.color
		carryGradient.Color = ColorSequence.new(UiKit.lighten(tint, 0.1), UiKit.darken(tint, 0.3))
		if not carryPanel.Visible then
			carryPanel.Visible = true
			UiKit.pop(carryPanel)
		end
	else
		carryPanel.Visible = false
	end
end

GameConfig.remote("State").OnClientEvent:Connect(applyState)
GameConfig.remote("Notify").OnClientEvent:Connect(toast)
GameConfig.remote("Fx").OnClientEvent:Connect(function(kind)
	if kind == "Income" then
		moneyLabel.TextColor3 = C.green
		TweenService:Create(moneyLabel, TweenInfo.new(0.4), { TextColor3 = C.gold }):Play()
	end
end)

local LAVA_CALM = ColorSequence.new(UiKit.lighten(C.lava, 0.18), UiKit.darken(C.lava, 0.12))
local LAVA_HOT = ColorSequence.new(Color3.fromRGB(255, 70, 50), Color3.fromRGB(170, 20, 20))

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	scale.Scale = math.clamp(camera.ViewportSize.Y / 760, 0.55, 1.4)
	local now = workspace:GetServerTimeNow()

	local phase = workspace:GetAttribute("WavePhase")
	local waveAt = workspace:GetAttribute("WaveAt") or now
	if phase == "surge" then
		local flash = math.floor(now * 4) % 2 == 0
		waveLabel.Text = "🌋 LAVA SURGE! HIDE IN A DOME!"
		waveLabel.TextColor3 = if flash then Color3.new(1, 1, 1) else Color3.fromRGB(255, 240, 120)
		waveGradient.Color = if flash then LAVA_HOT else LAVA_CALM
		waveBar.Size = UDim2.fromScale(1, 1)
	else
		local left = math.max(waveAt - now, 0)
		waveLabel.Text = ("🌋 LAVA WAVE IN %ds"):format(math.ceil(left))
		local warning = phase == "warning" and math.floor(now * 3) % 2 == 0
		waveLabel.TextColor3 = Color3.new(1, 1, 1)
		waveGradient.Color = if warning then LAVA_HOT else LAVA_CALM
		waveBar.Size = UDim2.fromScale(math.clamp(1 - left / GameConfig.WAVE_INTERVAL, 0.04, 1), 1)
	end

	local eventName = workspace:GetAttribute("EventName")
	if eventName then
		local left = math.max((workspace:GetAttribute("EventEndsAt") or now) - now, 0)
		eventLabel.Text = ("✨ %s  -  %s  -  %ds"):format(eventName, workspace:GetAttribute("EventDetail") or "", math.ceil(left))
		if not eventPanel.Visible then
			eventPanel.Visible = true
			UiKit.pop(eventPanel)
		end
	else
		eventPanel.Visible = false
	end

	if state then
		if now < state.lockUntil then
			lockTitle.Text = "🔒 LOCKED"
			lockSub.Text = ("%ds left"):format(math.ceil(state.lockUntil - now))
		elseif now < state.lockReadyAt then
			lockTitle.Text = "⏳ RECHARGE"
			lockSub.Text = ("%ds"):format(math.ceil(state.lockReadyAt - now))
		else
			lockTitle.Text = "🔒 LOCK [L]"
			lockSub.Text = GameConfig.LOCK_DURATION .. "s shield"
		end
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local index = GameConfig.zoneAt(root.Position.Z)
		if index or root.Position.Z < -2 then
			showZone(index)
		end
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
