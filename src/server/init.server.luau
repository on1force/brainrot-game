-- Server entry and round clock: builds the world, starts every service in order, then runs the three
-- clocks that keep a round tense (lava waves, Furbetto's raids, timed events) and routes the HUD's
-- requests. Each module under this script owns one job; PlayerState holds all per-player state.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage -- the shared modules sit right in it
local BrainrotModel = require(Shared.BrainrotModel)
local GameConfig = require(Shared.GameConfig)
local ArenaBuilder = require(script.ArenaBuilder)
local PlayerState = require(script.PlayerState)
local BaseSlots = require(script.BaseSlots)
local WildSpawner = require(script.WildSpawner)
local CarryAndSteal = require(script.CarryAndSteal)
local LavaWave = require(script.LavaWave)
local FurbettoThief = require(script.FurbettoThief)
local Progression = require(script.Progression)
local BatService = require(script.BatService)

-- The hazard to outrun: every WAVE_INTERVAL seconds, after a warning, lava sweeps the whole field.
local function sendLavaWaves()
	while true do
		LavaWave.countDown()
		LavaWave.surge()
	end
end

-- Furbetto the NPC thief raids a base that holds brainrots every THIEF_INTERVAL seconds.
local function sendThiefRaids()
	task.wait(GameConfig.THIEF_FIRST_RAID)
	while true do
		local victim = FurbettoThief.pickVictim()
		if victim then
			FurbettoThief.raid(victim)
			task.wait(GameConfig.THIEF_INTERVAL)
		else
			task.wait(5)
		end
	end
end

-- Golden Hour, Cash Frenzy or Meteor Shower, one at random every EVENT_INTERVAL seconds.
local function runTimedEvents()
	task.wait(GameConfig.EVENT_FIRST)
	while true do
		Progression.runEvent()
		task.wait(GameConfig.EVENT_INTERVAL - GameConfig.EVENT_DURATION)
	end
end

-- The HUD's buttons: each request names its action, and only these three are answered.
local HUD_ACTIONS: { [string]: (Player) -> () } = {
	LockBase = CarryAndSteal.lockBase,
	Rebirth = Progression.rebirth,
	BuySpeed = Progression.buySpeed,
}

local function onHudAction(player: Player, action: any)
	local handler = if typeof(action) == "string" then HUD_ACTIONS[action] else nil
	if handler and PlayerState.get(player) then
		handler(player)
	end
end

Players.RespawnTime = 3

ArenaBuilder.buildWorld()
local extraMeshes = table.clone(ArenaBuilder.PROPS)
extraMeshes.Bat = BatService.MESH
BrainrotModel.loadMeshTemplates(15, extraMeshes)
ArenaBuilder.decorate()
BaseSlots.start()
WildSpawner.start()
CarryAndSteal.start()
LavaWave.start()
BatService.start()

PlayerState.start(function(player)
	BaseSlots.onPlayerReady(player)
	CarryAndSteal.onPlayerReady(player)
end, function(player)
	CarryAndSteal.onPlayerLeaving(player)
	BaseSlots.onPlayerLeaving(player)
end)

GameConfig.remote("Action").OnServerEvent:Connect(onHudAction)
task.spawn(sendLavaWaves)
task.spawn(sendThiefRaids)
task.spawn(runTimedEvents)

-- Studio-only play-test hook (never created in a live server): lets a tester grant cash, place or
-- carry brainrots, call a raid, a slow lava surge, an event or a bat knockback on yourself from the command bar.
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "StudioTestHook"
	hook.OnInvoke = function(command: string, player: Player, ...)
		local args = { ... }
		if command == "money" then
			PlayerState.addMoney(player, args[1])
		elseif command == "place" then
			return BaseSlots.placeBrainrot(player, args[1], args[2] or "None")
		elseif command == "carry" then
			CarryAndSteal.startCarry(player, args[1], args[2] or "None")
		elseif command == "raid" then
			task.spawn(FurbettoThief.raid, player)
		elseif command == "surge" then
			task.spawn(LavaWave.surge, args[1])
		elseif command == "event" then
			task.spawn(Progression.runEvent)
		elseif command == "bonkme" then
			GameConfig.remote("Knockback"):FireClient(player, Vector3.new(0, 0, 1), 1.6)
		elseif command == "spawn" then
			WildSpawner.spawn(args[1], args[2], args[3])
		end
		return true
	end
	hook.Parent = game:GetService("ServerStorage")
end
