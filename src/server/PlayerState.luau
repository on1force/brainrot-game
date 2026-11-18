-- The one place each player's state lives: money, rebirths, speed level, the brainrots on their base,
-- what they carry and their base lock. Saves to a DataStore when one is available and pushes a
-- snapshot to the player's HUD whenever something changes.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local BrainrotCatalog = require(Shared.BrainrotCatalog)
local GameConfig = require(Shared.GameConfig)
local Net = require(Shared.Net)

local PlayerState = {}

local stateRemote = Net.event("State")
local notifyRemote = Net.event("Notify")
local fxRemote = Net.event("Fx")

local states: { [Player]: any } = {}
local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("BrainrotLavaRush_v1")
end)

-- Cash multiplier from events (Cash Frenzy sets it).
PlayerState.globalCashMultiplier = 1

local function blankState()
	return {
		money = GameConfig.START_MONEY,
		rebirths = 0,
		speedLevel = 0,
		base = {}, -- [padIndex] = { id = string, mutation = string }
		carrying = nil, -- { id, mutation, fromUserId? }
		plot = nil,
		lockUntil = 0,
		lockReadyAt = 0,
		totalEarned = 0,
		discovered = {}, -- [id] = true for every brainrot that ever reached this player's base
	}
end

function PlayerState.get(player: Player)
	return states[player]
end

function PlayerState.multiplier(player: Player): number
	local state = states[player]
	return GameConfig.rebirthMultiplier(state.rebirths) * PlayerState.globalCashMultiplier
end

function PlayerState.incomePerSecond(player: Player): number
	local state = states[player]
	if not state then
		return 0
	end
	local total = 0
	for _, item in state.base do
		total += BrainrotCatalog.incomeOf(item.id, item.mutation)
	end
	return total * PlayerState.multiplier(player)
end

function PlayerState.isLocked(player: Player): boolean
	local state = states[player]
	return state ~= nil and workspace:GetServerTimeNow() < state.lockUntil
end

function PlayerState.push(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local used = 0
	for _ in state.base do
		used += 1
	end
	local carrying = nil
	if state.carrying then
		local def = BrainrotCatalog.BY_ID[state.carrying.id]
		carrying = { name = def.name, rarity = def.rarity, mutation = state.carrying.mutation, stolen = state.carrying.fromUserId ~= nil }
	end
	stateRemote:FireClient(player, {
		money = state.money,
		income = PlayerState.incomePerSecond(player),
		multiplier = PlayerState.multiplier(player),
		rebirths = state.rebirths,
		rebirthCost = GameConfig.rebirthCost(state.rebirths),
		speedLevel = state.speedLevel,
		speedCost = GameConfig.speedCost(state.speedLevel),
		speedMax = state.speedLevel >= GameConfig.SPEED_MAX_LEVEL,
		padsUsed = used,
		padsMax = GameConfig.padsFor(state.rebirths),
		carrying = carrying,
		discovered = state.discovered,
		lockUntil = state.lockUntil,
		lockReadyAt = state.lockReadyAt,
		plot = state.plot,
	})
end

function PlayerState.addMoney(player: Player, amount: number)
	local state = states[player]
	if not state then
		return
	end
	state.money += amount
	if amount > 0 then
		state.totalEarned += amount
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats :: any).Cash.Value = GameConfig.formatMoney(state.money)
	end
	PlayerState.push(player)
end

function PlayerState.spend(player: Player, amount: number): boolean
	local state = states[player]
	if not state or state.money < amount then
		return false
	end
	PlayerState.addMoney(player, -amount)
	return true
end

function PlayerState.notify(player: Player, text: string, color: Color3?)
	notifyRemote:FireClient(player, text, color)
end

function PlayerState.notifyAll(text: string, color: Color3?)
	notifyRemote:FireAllClients(text, color)
end

function PlayerState.fx(player: Player, kind: string, data: any?)
	fxRemote:FireClient(player, kind, data)
end

function PlayerState.fxAll(kind: string, data: any?)
	fxRemote:FireAllClients(kind, data)
end

local function serialize(state)
	local base = {}
	for padIndex, item in state.base do
		table.insert(base, { pad = padIndex, id = item.id, mutation = item.mutation })
	end
	local discovered = {}
	for id in state.discovered do
		table.insert(discovered, id)
	end
	return { money = state.money, rebirths = state.rebirths, speedLevel = state.speedLevel, base = base,
		totalEarned = state.totalEarned, discovered = discovered }
end

local function save(player: Player)
	local state = states[player]
	if not (store and state) then
		return
	end
	local data = serialize(state)
	pcall(function()
		(store :: DataStore):SetAsync(tostring(player.UserId), data)
	end)
end

local function load(player: Player)
	local state = blankState()
	if store then
		local ok, data = pcall(function()
			return (store :: DataStore):GetAsync(tostring(player.UserId))
		end)
		if ok and type(data) == "table" then
			state.money = tonumber(data.money) or state.money
			state.rebirths = tonumber(data.rebirths) or 0
			state.speedLevel = tonumber(data.speedLevel) or 0
			state.totalEarned = tonumber(data.totalEarned) or 0
			for _, item in data.base or {} do
				if BrainrotCatalog.BY_ID[item.id] and BrainrotCatalog.MUTATION_BY_ID[item.mutation] then
					state.base[item.pad] = { id = item.id, mutation = item.mutation }
				end
			end
			for _, id in data.discovered or {} do
				if BrainrotCatalog.BY_ID[id] then
					state.discovered[id] = true
				end
			end
		end
	end
	return state
end

-- onReady(player) runs once the player's state is loaded; onLeaving(player) before it is dropped.
function PlayerState.start(onReady: (Player) -> (), onLeaving: (Player) -> ())
	local function join(player: Player)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		local cash = Instance.new("StringValue")
		cash.Name = "Cash"
		cash.Parent = leaderstats
		local rebirths = Instance.new("IntValue")
		rebirths.Name = "Rebirths"
		rebirths.Parent = leaderstats
		leaderstats.Parent = player

		states[player] = load(player)
		cash.Value = GameConfig.formatMoney(states[player].money)
		rebirths.Value = states[player].rebirths
		onReady(player)
		PlayerState.push(player)
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if states[player] then
			onLeaving(player)
			save(player)
			states[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for player in states do
				save(player)
			end
		end
	end)
	game:BindToClose(function()
		for player in states do
			save(player)
		end
	end)
end

return PlayerState
