-- Furbetto the Snack Bandit: an NPC thief that raids a player's base every THIEF_INTERVAL seconds.
-- A locked base bonks him away; otherwise he grabs the best brainrot and runs for the volcano. A bat
-- hit knocks him out (he spins away and vanishes in a puff), returns the loot and pays a bounty.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local BrainrotCatalog = require(Shared.BrainrotCatalog)
local BrainrotModel = require(Shared.BrainrotModel)
local GameConfig = require(Shared.GameConfig)
local BaseSlots = require(script.Parent.BaseSlots)
local PlayerState = require(script.Parent.PlayerState)

local FurbettoThief = {}

local rng = Random.new()
local UP = CFrame.Angles(0, 0, math.rad(90))

local function bodyPart(model: Model, root: BasePart, shape: Enum.PartType, size: Vector3, offset: CFrame, color: Color3)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = root.CFrame * offset
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
end

local function buildFurbetto(): Model
	local model = Instance.new("Model")
	model.Name = "Furbetto"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 0.2, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root
	local template = BrainrotModel.meshTemplate("Furbetto")
	if template then
		BrainrotModel.addMesh(model, root, template, BrainrotCatalog.MESHES.Furbetto.height)
	else
		local skin = Color3.fromRGB(120, 200, 80)
		local ball, block, cyl = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Cylinder
		bodyPart(model, root, ball, Vector3.new(3, 3.4, 2.6), CFrame.new(0, 3, 0), Color3.fromRGB(90, 60, 110))
		bodyPart(model, root, ball, Vector3.new(2.6, 2.4, 2.4), CFrame.new(0, 5.6, 0), skin)
		bodyPart(model, root, block, Vector3.new(2.7, 0.6, 0.4), CFrame.new(0, 5.8, -1.05), Color3.fromRGB(20, 20, 25))
		bodyPart(model, root, ball, Vector3.new(0.45, 0.45, 0.2), CFrame.new(-0.5, 5.8, -1.3), Color3.fromRGB(255, 240, 80))
		bodyPart(model, root, ball, Vector3.new(0.45, 0.45, 0.2), CFrame.new(0.5, 5.8, -1.3), Color3.fromRGB(255, 240, 80))
		bodyPart(model, root, block, Vector3.new(1.8, 0.4, 0.8), CFrame.new(-1.6, 6.3, 0) * CFrame.Angles(0, 0, math.rad(25)), skin)
		bodyPart(model, root, block, Vector3.new(1.8, 0.4, 0.8), CFrame.new(1.6, 6.3, 0) * CFrame.Angles(0, 0, math.rad(-25)), skin)
		bodyPart(model, root, ball, Vector3.new(2.6, 2.6, 2.6), CFrame.new(0, 3.6, 1.6), Color3.fromRGB(170, 120, 70))
		for _, side in { -0.6, 0.6 } do
			bodyPart(model, root, cyl, Vector3.new(1.4, 0.5, 0.5), CFrame.new(side, 0.7, 0) * UP, Color3.fromRGB(60, 40, 70))
		end
	end

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromScale(16, 3)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	tag.LightInfluence = 0
	tag.MaxDistance = 250
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 90, 90)
	text.TextStrokeTransparency = 0
	text.Text = "FURBETTO THE SNACK BANDIT"
	text.Parent = tag
	tag.Parent = root
	return model
end

-- The raid in progress: its model and the player whose bat struck him (nil until someone does).
local current: { model: Model, struckBy: Player? }? = nil

-- Bat swing check from BatService: true when Furbetto stands within `reach` of `origin` and takes the hit.
function FurbettoThief.tryHit(player: Player, origin: Vector3, reach: number): boolean
	local raid = current
	if not raid or raid.struckBy then
		return false
	end
	local body = raid.model:GetPivot().Position + Vector3.new(0, 3, 0)
	if (body - origin).Magnitude > reach then
		return false
	end
	raid.struckBy = player
	return true
end

-- Walks the model to `target` at `speed`; returns the player whose bat struck him on the way, if any.
local function walkTo(model: Model, target: Vector3, speed: number, carried: Model?): Player?
	while true do
		local dt = RunService.Heartbeat:Wait()
		if current and current.struckBy then
			return current.struckBy
		end
		local pivot = model:GetPivot()
		local flat = Vector3.new(target.X - pivot.Position.X, 0, target.Z - pivot.Position.Z)
		if flat.Magnitude < 1 then
			return nil
		end
		local position = pivot.Position + flat.Unit * math.min(flat.Magnitude, speed * dt)
		-- the root glides flat; each client animates the waddle on the body (Animator.client)
		local cframe = CFrame.lookAt(Vector3.new(position.X, 0, position.Z), Vector3.new(position.X, 0, position.Z) + flat.Unit)
		model:PivotTo(cframe)
		if carried then
			carried:PivotTo(cframe * CFrame.new(0, 8.5, 0))
		end
	end
end

local function burst(parent: BasePart, texture: string, color: Color3, size: NumberSequence, count: number, glow: boolean)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.Size = size
	emitter.Transparency = NumberSequence.new(if glow then 0 else 0.2, 1)
	emitter.LightEmission = if glow then 1 else 0
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = parent
	emitter:Emit(count)
end

-- Knockout: Furbetto is flung away from the hit, spinning, with OUCH! over his head, then shrinks into a
-- puff of smoke and stars and is gone.
local function knockOut(model: Model, from: Vector3)
	model:SetAttribute("Dying", true)
	local root = model.PrimaryPart :: BasePart
	local tag = root:FindFirstChild("BillboardGui")
	if tag then
		local text = (tag :: any).Text
		text.Text = "OUCH!"
		text.TextColor3 = Color3.fromRGB(255, 230, 80)
	end
	local start = model:GetPivot()
	local away = Vector3.new(start.Position.X - from.X, 0, start.Position.Z - from.Z)
	away = if away.Magnitude > 0.1 then away.Unit else -start.LookVector
	local began = os.clock()
	while true do
		local alpha = math.min((os.clock() - began) / 0.75, 1)
		local position = start.Position + away * alpha * 16 + Vector3.new(0, math.sin(alpha * math.pi) * 7, 0)
		model:PivotTo(CFrame.new(position) * start.Rotation * CFrame.Angles(alpha * math.pi * 0.6, alpha * math.pi * 4, 0))
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	burst(root, "rbxasset://textures/particles/smoke_main.dds", Color3.fromRGB(240, 240, 255), NumberSequence.new(3, 7), 30, false)
	burst(root, "rbxasset://textures/particles/sparkles_main.dds", Color3.fromRGB(255, 230, 80), NumberSequence.new(1.2, 0), 40, true)
	local startScale = model:GetScale()
	local shrinkStart = os.clock()
	while true do
		local alpha = math.min((os.clock() - shrinkStart) / 0.35, 1)
		model:ScaleTo(math.max(startScale * (1 - alpha), 0.02))
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Transparency = 1
		elseif item:IsA("BillboardGui") then
			item.Enabled = false
		end
	end
	task.delay(1.2, function()
		model:Destroy()
	end)
end

-- One raid on `victim`'s base.
function FurbettoThief.raid(victim: Player)
	local plot = BaseSlots.plotOf(victim)
	if not plot then
		return
	end
	local half = GameConfig.PLOT_SIZE / 2
	local model = buildFurbetto()
	model:SetAttribute("Moving", true) -- he never stops until he is home free or knocked out
	model:PivotTo(CFrame.new(plot.center.X + rng:NextNumber(-30, 30), 0, 70))
	model.Parent = workspace
	current = { model = model, struckBy = nil }
	PlayerState.notify(victim, "FURBETTO is raiding your base! LOCK IT or BONK him with your bat!", Color3.fromRGB(255, 70, 70))
	PlayerState.fx(victim, "Alarm")

	local function finish()
		model:Destroy()
		current = nil
	end

	-- A bat hit: knockout, then the hitter's reward (and the loot goes home if he had any).
	local function struck(by: Player, item, def)
		local hitFrom = if by.Character then by.Character:GetPivot().Position else model:GetPivot().Position
		current = nil
		PlayerState.fx(by, "Bonk")
		task.spawn(knockOut, model, hitFrom)
		local byState = PlayerState.get(by)
		if not item then
			local reward = 150 * (1 + (if byState then byState.rebirths else 0))
			PlayerState.addMoney(by, reward)
			PlayerState.notify(by, "BONK! You knocked out Furbetto! +" .. GameConfig.formatMoney(reward), Color3.fromRGB(255, 220, 80))
			return
		end
		local bounty = math.floor(BrainrotCatalog.priceOf(item.id, item.mutation) * GameConfig.THIEF_BOUNTY_SHARE)
		PlayerState.addMoney(by, bounty)
		PlayerState.notify(by, "BONK! Furbetto dropped the loot! Bounty " .. GameConfig.formatMoney(bounty), Color3.fromRGB(255, 220, 80))
		if PlayerState.get(victim) and BaseSlots.placeBrainrot(victim, item.id, item.mutation) then
			PlayerState.notify(victim, def.name .. " is back on your base!", Color3.fromRGB(120, 255, 140))
		end
	end

	local gate = plot.center + Vector3.new(0, 0, half + 3)
	local striker = walkTo(model, gate, GameConfig.THIEF_SPEED)
	if striker then
		struck(striker, nil, nil)
		return
	end
	if not PlayerState.get(victim) then
		finish()
		return
	end
	if PlayerState.isLocked(victim) then
		PlayerState.notify(victim, "BONK! Furbetto bounced off your base lock", Color3.fromRGB(120, 255, 140))
		PlayerState.fx(victim, "Bonk", { position = gate })
		striker = walkTo(model, gate + Vector3.new(0, 0, 120), GameConfig.THIEF_SPEED * 1.4)
		if striker then
			struck(striker, nil, nil)
		else
			finish()
		end
		return
	end
	local padIndex = BaseSlots.bestPad(victim)
	local padModel = if padIndex then BaseSlots.padModel(victim, padIndex) else nil
	if padModel then
		striker = walkTo(model, padModel:GetPivot().Position + Vector3.new(0, 0, 4), GameConfig.THIEF_SPEED)
		if striker then
			struck(striker, nil, nil)
			return
		end
	end
	local item = if padIndex and PlayerState.get(victim) then BaseSlots.removeAt(victim, padIndex) else nil
	if not item then
		finish()
		return
	end
	local def = BrainrotCatalog.BY_ID[item.id]
	local loot = BrainrotModel.build(item.id, item.mutation)
	loot:ScaleTo(loot:GetScale() * 0.6)
	loot.Parent = model
	PlayerState.notify(victim, "Furbetto grabbed your " .. def.name .. "! CHASE HIM and BONK him!", Color3.fromRGB(255, 70, 70))
	local label = (model.PrimaryPart :: BasePart):FindFirstChild("BillboardGui")
	if label then
		(label :: any).Text.Text = "FURBETTO HAS " .. def.name:upper() .. "!"
	end

	local escapeTo = Vector3.new(model:GetPivot().Position.X, 0, GameConfig.FIELD_LENGTH)
	striker = walkTo(model, escapeTo, GameConfig.THIEF_ESCAPE_SPEED, loot)
	if striker then
		loot:Destroy()
		struck(striker, item, def)
		return
	end
	finish()
	if PlayerState.get(victim) then
		PlayerState.notify(victim, "Furbetto escaped with your " .. def.name .. "... lock your base next time!", Color3.fromRGB(255, 70, 70))
	end
end

local function pickVictim(): Player?
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local state = PlayerState.get(player)
		if state and state.plot and next(state.base) then
			table.insert(candidates, player)
		end
	end
	return if #candidates > 0 then candidates[rng:NextInteger(1, #candidates)] else nil
end

function FurbettoThief.start()
	task.spawn(function()
		task.wait(GameConfig.THIEF_FIRST_RAID)
		while true do
			local victim = pickVictim()
			if victim then
				FurbettoThief.raid(victim)
				task.wait(GameConfig.THIEF_INTERVAL)
			else
				task.wait(5)
			end
		end
	end)
end

return FurbettoThief
