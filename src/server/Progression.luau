-- Climbing the ladder: speed upgrades, rebirths (reset for a permanent cash multiplier and more pads)
-- and the timed server events (Golden Hour, Cash Frenzy, Meteor Shower). Also routes HUD actions.

local Shared = game.ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Net = require(Shared.Net)
local BaseSlots = require(script.Parent.BaseSlots)
local CarryAndSteal = require(script.Parent.CarryAndSteal)
local PlayerState = require(script.Parent.PlayerState)
local WildSpawner = require(script.Parent.WildSpawner)

local Progression = {}

local rng = Random.new()

function Progression.buySpeed(player: Player)
	local state = PlayerState.get(player)
	if state.speedLevel >= GameConfig.SPEED_MAX_LEVEL then
		PlayerState.notify(player, "Max speed reached!")
		return
	end
	local cost = GameConfig.speedCost(state.speedLevel)
	if not PlayerState.spend(player, cost) then
		PlayerState.notify(player, "Speed upgrade costs " .. GameConfig.formatMoney(cost), Color3.fromRGB(255, 110, 90))
		return
	end
	state.speedLevel += 1
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = GameConfig.walkSpeed(state.speedLevel)
	end
	PlayerState.notify(player, "Speed " .. state.speedLevel .. "! Walk speed " .. GameConfig.walkSpeed(state.speedLevel),
		Color3.fromRGB(120, 220, 255))
	PlayerState.fx(player, "Upgrade")
	PlayerState.push(player)
end

-- Rebirth: costs rebirthCost, wipes money, base and speed, grants +50% cash forever and one more pad.
function Progression.rebirth(player: Player)
	local state = PlayerState.get(player)
	local cost = GameConfig.rebirthCost(state.rebirths)
	if state.money < cost then
		PlayerState.notify(player, "Rebirth needs " .. GameConfig.formatMoney(cost), Color3.fromRGB(255, 110, 90))
		return
	end
	if state.carrying then
		CarryAndSteal.dropCarry(player, "rebirth")
	end
	state.rebirths += 1
	state.money = GameConfig.START_MONEY
	state.speedLevel = 0
	table.clear(state.base)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = GameConfig.walkSpeed(0)
	end
	local leaderstats = player:FindFirstChild("leaderstats") :: any
	if leaderstats then
		leaderstats.Rebirths.Value = state.rebirths
	end
	BaseSlots.render(player)
	PlayerState.addMoney(player, 0)
	PlayerState.notifyAll(player.DisplayName .. " REBIRTHED! (x" .. GameConfig.rebirthMultiplier(state.rebirths) .. " cash)",
		Color3.fromRGB(255, 120, 255))
	PlayerState.fx(player, "Rebirth")
end

local EVENTS = {
	{ name = "GOLDEN HOUR", detail = "4x mutation chance on new spawns",
		begin = function()
			WildSpawner.mutationBoost = GameConfig.GOLDEN_HOUR_MUTATION_BOOST
		end,
		finish = function()
			WildSpawner.mutationBoost = 1
		end },
	{ name = "CASH FRENZY", detail = "every base earns 2x",
		begin = function()
			PlayerState.globalCashMultiplier = GameConfig.CASH_FRENZY_MULT
		end,
		finish = function()
			PlayerState.globalCashMultiplier = 1
		end },
	{ name = "METEOR SHOWER", detail = "Mythic+ brainrots crash into Snack Meadow",
		begin = function()
			for _ = 1, 3 do
				local rarity = if rng:NextNumber() < 0.25 then "BrainrotGod" else "Mythic"
				WildSpawner.spawn(1, rarity)
			end
			PlayerState.fxAll("Meteor")
		end,
		finish = function() end },
}

-- Runs one random event for EVENT_DURATION seconds; HUDs read the workspace attributes.
function Progression.runEvent()
	local event = EVENTS[rng:NextInteger(1, #EVENTS)]
	event.begin()
	workspace:SetAttribute("EventName", event.name)
	workspace:SetAttribute("EventDetail", event.detail)
	workspace:SetAttribute("EventEndsAt", workspace:GetServerTimeNow() + GameConfig.EVENT_DURATION)
	PlayerState.notifyAll("EVENT: " .. event.name .. " - " .. event.detail, Color3.fromRGB(255, 220, 80))
	task.wait(GameConfig.EVENT_DURATION)
	event.finish()
	workspace:SetAttribute("EventName", nil)
end

function Progression.start()
	Net.event("Action").OnServerEvent:Connect(function(player, action)
		if not PlayerState.get(player) then
			return
		end
		if action == "BuySpeed" then
			Progression.buySpeed(player)
		elseif action == "Rebirth" then
			Progression.rebirth(player)
		elseif action == "LockBase" then
			CarryAndSteal.lockBase(player)
		end
	end)
	task.spawn(function()
		task.wait(GameConfig.EVENT_FIRST)
		while true do
			Progression.runEvent()
			task.wait(GameConfig.EVENT_INTERVAL - GameConfig.EVENT_DURATION)
		end
	end)
end

return Progression
