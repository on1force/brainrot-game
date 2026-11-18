-- Wild brainrots: keeps every field zone stocked with brainrots of that zone's rarities (rarer toward
-- the volcano), rolls their mutations, makes them wander and sells them through a Grab prompt.

local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local BrainrotCatalog = require(Shared.BrainrotCatalog)
local BrainrotModel = require(Shared.BrainrotModel)
local GameConfig = require(Shared.GameConfig)
local WorldBuilder = require(script.Parent.WorldBuilder)

local WildSpawner = {}

local rng = Random.new()
local folder: Folder
-- each wild: { model, id, mutation, zone, target, speed, bornAt, nextWander }
local wilds: { any } = {}

-- Set by Progression: the mutation boost Golden Hour gives.
WildSpawner.mutationBoost = 1
-- Set by CarryAndSteal: called as onGrab(player, wild) when a Grab prompt fires.
WildSpawner.onGrab = nil :: ((Player, any) -> ())?

-- The strip in front of the safe line where the title screen's showcase stage stands stays clear.
local function inShowcaseArea(spot: Vector3): boolean
	return spot.Z < 44 and math.abs(spot.X) < 74
end

local function randomSpot(zone): Vector3
	local halfWidth = GameConfig.FIELD_WIDTH / 2 - 10
	for _ = 1, 12 do
		local spot = Vector3.new(rng:NextNumber(-halfWidth, halfWidth), 0, rng:NextNumber(zone.from + 8, zone.to - 8))
		if not WorldBuilder.isInSafeDome(spot) and not inShowcaseArea(spot) then
			return spot
		end
	end
	return Vector3.new(0, 0, (zone.from + zone.to) / 2)
end

local function labelWild(wild)
	BrainrotModel.label(wild.model, GameConfig.formatMoney(BrainrotCatalog.priceOf(wild.id, wild.mutation)))
	local prompt = (wild.model.PrimaryPart :: BasePart):FindFirstChild("GrabPrompt") :: ProximityPrompt?
	if prompt then
		prompt.ActionText = "Buy " .. GameConfig.formatMoney(BrainrotCatalog.priceOf(wild.id, wild.mutation))
	end
end

-- Spawns one wild brainrot in zone `zoneIndex`; `rarity` and `spot` default to a roll.
function WildSpawner.spawn(zoneIndex: number, rarity: string?, spot: Vector3?)
	local zone = GameConfig.ZONES[zoneIndex]
	local rarityId = rarity or BrainrotCatalog.rollRarity(zone.weights, rng)
	local def = BrainrotCatalog.pickOfRarity(rarityId, rng)
	local mutationId = BrainrotCatalog.rollMutation(rng, WildSpawner.mutationBoost)
	local model = BrainrotModel.build(def.id, mutationId)
	local position = spot or randomSpot(zone)
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))

	local wild = { model = model, id = def.id, mutation = mutationId, zone = zoneIndex, target = position,
		speed = rng:NextNumber(3, 6), bornAt = os.clock(), nextWander = os.clock() + rng:NextNumber(1, 4) }

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ObjectText = def.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		if WildSpawner.onGrab and wild.model.Parent then
			WildSpawner.onGrab(player, wild)
		end
	end)
	labelWild(wild)
	model.Parent = folder
	table.insert(wilds, wild)
	return wild
end

function WildSpawner.remove(wild)
	local index = table.find(wilds, wild)
	if index then
		table.remove(wilds, index)
	end
	wild.model:Destroy()
end

-- The lava wave front at z washes over wild brainrots: some turn into Lava mutations.
function WildSpawner.lavaTouch(frontZ: number, depth: number)
	for _, wild in wilds do
		local z = wild.model:GetPivot().Position.Z
		if math.abs(z - frontZ) < depth / 2 and not wild.lavaChecked then
			wild.lavaChecked = true
			if wild.mutation == "None" and rng:NextNumber() < GameConfig.WAVE_LAVA_MUTATE_CHANCE then
				wild.mutation = "Lava"
				BrainrotModel.applyMutation(wild.model, "Lava")
				labelWild(wild)
			end
		end
	end
end

function WildSpawner.resetLavaChecks()
	for _, wild in wilds do
		wild.lavaChecked = nil
	end
end

local function countInZone(zoneIndex: number): number
	local count = 0
	for _, wild in wilds do
		if wild.zone == zoneIndex then
			count += 1
		end
	end
	return count
end

-- Moves wanderers a step toward their target, turning to face where they walk.
local function stepWanderers(dt: number)
	local now = os.clock()
	for _, wild in wilds do
		local pivot = wild.model:GetPivot()
		local offset = wild.target - pivot.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local moving = flat.Magnitude > 0.5
		if wild.model:GetAttribute("Moving") ~= moving then
			wild.model:SetAttribute("Moving", moving) -- clients waddle while true (Animator.client)
		end
		if moving then
			local step = math.min(flat.Magnitude, wild.speed * dt)
			local position = pivot.Position + flat.Unit * step
			-- the root glides flat; each client animates the waddle on the body (Animator.client)
			wild.model:PivotTo(CFrame.lookAt(Vector3.new(position.X, 0, position.Z), Vector3.new(position.X, 0, position.Z) + flat.Unit))
		elseif pivot.Position.Y > 0.01 then
			wild.model:PivotTo(pivot - Vector3.new(0, pivot.Position.Y, 0))
		elseif now >= wild.nextWander then
			local zone = GameConfig.ZONES[wild.zone]
			local nudge = Vector3.new(rng:NextNumber(-18, 18), 0, rng:NextNumber(-12, 12))
			local target = pivot.Position + nudge
			local halfWidth = GameConfig.FIELD_WIDTH / 2 - 8
			target = Vector3.new(math.clamp(target.X, -halfWidth, halfWidth), 0, math.clamp(target.Z, zone.from + 6, zone.to - 6))
			if not inShowcaseArea(target) then
				wild.target = target
			end
			wild.nextWander = now + rng:NextNumber(3, 7)
		end
	end
end

function WildSpawner.start()
	folder = Instance.new("Folder")
	folder.Name = "WildBrainrots"
	folder.Parent = workspace
	for zoneIndex in GameConfig.ZONES do
		for _ = 1, GameConfig.WILD_PER_ZONE do
			WildSpawner.spawn(zoneIndex)
		end
	end
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 40 then
			return
		end
		stepWanderers(accumulator)
		accumulator = 0
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			local now = os.clock()
			for i = #wilds, 1, -1 do
				local wild = wilds[i]
				if now - wild.bornAt > GameConfig.WILD_LIFETIME then
					WildSpawner.remove(wild)
				end
			end
			for zoneIndex in GameConfig.ZONES do
				if countInZone(zoneIndex) < GameConfig.WILD_PER_ZONE then
					WildSpawner.spawn(zoneIndex)
				end
			end
		end
	end)
end

return WildSpawner
