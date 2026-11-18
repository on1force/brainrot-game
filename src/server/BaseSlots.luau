-- Player bases: hands each player a plot, shows their brainrots on its pads with sell and steal
-- prompts, pays every base's cash per second, and draws the base lock's laser walls.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage -- the shared modules sit right in it
local BrainrotCatalog = require(Shared.BrainrotCatalog)
local BrainrotModel = require(Shared.BrainrotModel)
local GameConfig = require(Shared.GameConfig)
local PlayerState = require(script.Parent.PlayerState)
local ArenaBuilder = require(script.Parent.ArenaBuilder)

local BaseSlots = {}

local plotOwners: { [number]: Player } = {}
local padModels: { [number]: { [number]: Model } } = {}
local padLocks: { [number]: { [number]: BillboardGui } } = {}

-- Set by StealAndLock: called as onSteal(thief, owner, padIndex) when a Steal prompt fires.
BaseSlots.onSteal = nil :: ((Player, Player, number) -> ())?

function BaseSlots.plotOf(player: Player)
	local state = PlayerState.get(player)
	return state and state.plot and ArenaBuilder.plots[state.plot]
end

function BaseSlots.ownerOfPlot(index: number): Player?
	return plotOwners[index]
end

function BaseSlots.isInsideOwnPlot(player: Player, position: Vector3): boolean
	local plot = BaseSlots.plotOf(player)
	if not plot then
		return false
	end
	local offset = position - plot.center
	local half = GameConfig.PLOT_SIZE / 2 + 1
	return math.abs(offset.X) <= half and math.abs(offset.Z) <= half
end

function BaseSlots.firstFreePad(player: Player): number?
	local state = PlayerState.get(player)
	for padIndex = 1, GameConfig.padsFor(state.rebirths) do
		if not state.base[padIndex] then
			return padIndex
		end
	end
	return nil
end

local function makePrompt(parent: Instance, name: string, action: string, objectText: string, key: Enum.KeyCode, hold: number)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function showPad(player: Player, padIndex: number)
	local state = PlayerState.get(player)
	local plot = ArenaBuilder.plots[state.plot]
	local old = padModels[plot.index][padIndex]
	if old then
		old:Destroy()
		padModels[plot.index][padIndex] = nil
	end
	local item = state.base[padIndex]
	if not item then
		return
	end
	local pad = plot.pads[padIndex]
	local model = BrainrotModel.build(item.id, item.mutation)
	model:PivotTo(pad.cframe)
	local sellValue = math.floor(BrainrotCatalog.priceOf(item.id, item.mutation) * GameConfig.SELL_SHARE)
	BrainrotModel.label(model, nil, nil, true)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PadIndex", padIndex)

	local root = model.PrimaryPart :: BasePart
	local sell = makePrompt(root, "SellPrompt", "Sell " .. GameConfig.formatMoney(sellValue), model.Name, Enum.KeyCode.F, 0.6)
	sell:SetAttribute("OwnerOnly", true)
	sell.Triggered:Connect(function(who)
		if who == player then
			BaseSlots.sell(player, padIndex)
		end
	end)
	local steal = makePrompt(root, "StealPrompt", "STEAL", model.Name, Enum.KeyCode.E, 1.2)
	steal:SetAttribute("OthersOnly", true)
	steal.Triggered:Connect(function(who)
		if who ~= player and BaseSlots.onSteal then
			BaseSlots.onSteal(who, player, padIndex)
		end
	end)

	model.Parent = plot.folder
	padModels[plot.index][padIndex] = model
end

-- Shows which pads are still locked behind rebirths.
local function showPadLocks(player: Player)
	local state = PlayerState.get(player)
	local plot = ArenaBuilder.plots[state.plot]
	local unlocked = GameConfig.padsFor(state.rebirths)
	for padIndex, pad in plot.pads do
		local tag = padLocks[plot.index][padIndex]
		if padIndex > unlocked and not tag then
			tag = ArenaBuilder.tagAbove(pad.part, 3.2, 8, "REBIRTH TO UNLOCK", Color3.fromRGB(255, 180, 255), 70)
			padLocks[plot.index][padIndex] = tag
		elseif padIndex <= unlocked and tag then
			(tag.Adornee :: Instance):Destroy()
			padLocks[plot.index][padIndex] = nil
		end
	end
end

function BaseSlots.refreshSign(player: Player)
	local plot = BaseSlots.plotOf(player)
	if plot then
		plot.signTitle.Text = player.DisplayName:upper() .. "'S BASE"
		plot.signIncome.Text = GameConfig.formatMoney(PlayerState.incomePerSecond(player)) .. "/s"
	end
end

-- Redraws a player's whole base (after joining, a rebirth or a steal).
function BaseSlots.render(player: Player)
	local state = PlayerState.get(player)
	if not state or not state.plot then
		return
	end
	for padIndex = 1, GameConfig.PADS_MAX do
		showPad(player, padIndex)
	end
	showPadLocks(player)
	BaseSlots.refreshSign(player)
end

-- Puts a brainrot on the first free pad of the player's base; false when the base is full.
function BaseSlots.placeBrainrot(player: Player, id: string, mutationId: string): boolean
	local padIndex = BaseSlots.firstFreePad(player)
	if not padIndex then
		return false
	end
	local state = PlayerState.get(player)
	state.base[padIndex] = { id = id, mutation = mutationId }
	if not state.discovered[id] then
		state.discovered[id] = true
		PlayerState.notify(player, "NEW in your Brainrot Index: " .. BrainrotCatalog.BY_ID[id].name .. "!",
			BrainrotCatalog.RARITY_BY_ID[BrainrotCatalog.BY_ID[id].rarity].color)
	end
	showPad(player, padIndex)
	BaseSlots.refreshSign(player)
	PlayerState.push(player)
	return true
end

-- Takes a brainrot off a pad and returns it ({ id, mutation }), or nil when the pad is empty.
function BaseSlots.removeAt(player: Player, padIndex: number)
	local state = PlayerState.get(player)
	local item = state and state.base[padIndex]
	if not item then
		return nil
	end
	state.base[padIndex] = nil
	showPad(player, padIndex)
	BaseSlots.refreshSign(player)
	PlayerState.push(player)
	return item
end

-- The pad holding the player's most valuable brainrot.
function BaseSlots.bestPad(player: Player): number?
	local state = PlayerState.get(player)
	local best, bestIncome = nil, -1
	for padIndex, item in state.base do
		local income = BrainrotCatalog.incomeOf(item.id, item.mutation)
		if income > bestIncome then
			best, bestIncome = padIndex, income
		end
	end
	return best
end

function BaseSlots.padModel(player: Player, padIndex: number): Model?
	local plot = BaseSlots.plotOf(player)
	return plot and padModels[plot.index][padIndex]
end

function BaseSlots.sell(player: Player, padIndex: number)
	local item = BaseSlots.removeAt(player, padIndex)
	if item then
		local value = math.floor(BrainrotCatalog.priceOf(item.id, item.mutation) * GameConfig.SELL_SHARE)
		PlayerState.addMoney(player, value)
		PlayerState.notify(player, "Sold " .. BrainrotCatalog.BY_ID[item.id].name .. " for " .. GameConfig.formatMoney(value))
		PlayerState.fx(player, "Sell", { amount = value })
	end
end

function BaseSlots.showLock(player: Player, locked: boolean)
	local plot = BaseSlots.plotOf(player)
	if not plot then
		return
	end
	for _, wall in plot.walls do
		wall.Transparency = if locked then 0.25 else 1
	end
	plot.lockButton.Color = if locked then Color3.fromRGB(80, 255, 120) else Color3.fromRGB(255, 60, 60)
end

function BaseSlots.setLockText(player: Player, text: string)
	local plot = BaseSlots.plotOf(player)
	if plot then
		plot.lockText.Text = text
	end
end

local function claimPlot(player: Player)
	for index = 1, GameConfig.PLOT_COUNT do
		if not plotOwners[index] then
			plotOwners[index] = player
			PlayerState.get(player).plot = index
			return index
		end
	end
	return nil
end

local function spawnAtPlot(player: Player, character: Model)
	local plot = BaseSlots.plotOf(player)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = GameConfig.walkSpeed(PlayerState.get(player).speedLevel)
	if plot then
		task.defer(function()
			character:PivotTo(plot.spawnCFrame)
		end)
	end
end

function BaseSlots.onPlayerReady(player: Player)
	local index = claimPlot(player)
	if not index then
		PlayerState.notify(player, "All bases are taken - you can still steal!")
		return
	end
	player.CharacterAdded:Connect(function(character)
		spawnAtPlot(player, character)
	end)
	if player.Character then
		spawnAtPlot(player, player.Character)
	end
	BaseSlots.render(player)
end

function BaseSlots.onPlayerLeaving(player: Player)
	local state = PlayerState.get(player)
	if not state or not state.plot then
		return
	end
	local index = state.plot
	for padIndex, model in padModels[index] do
		model:Destroy()
		padModels[index][padIndex] = nil
	end
	for padIndex, tag in padLocks[index] do
		(tag.Adornee :: Instance):Destroy()
		padLocks[index][padIndex] = nil
	end
	for _, wall in ArenaBuilder.plots[index].walls do
		wall.Transparency = 1
	end
	ArenaBuilder.plots[index].signTitle.Text = "EMPTY BASE"
	ArenaBuilder.plots[index].signIncome.Text = "$0/s"
	plotOwners[index] = nil
end

-- Pays every player their base's cash per second, once a second.
function BaseSlots.tickIncomePerSecond()
	for _, player in Players:GetPlayers() do
		local income = PlayerState.incomePerSecond(player)
		if income > 0 then
			PlayerState.addMoney(player, income)
			PlayerState.fx(player, "Income", { amount = income })
		end
	end
end

function BaseSlots.start()
	for index = 1, GameConfig.PLOT_COUNT do
		padModels[index] = {}
		padLocks[index] = {}
	end
	task.spawn(function()
		while true do
			task.wait(1)
			BaseSlots.tickIncomePerSecond()
		end
	end)
end

return BaseSlots
