-- Server entry: builds the world, then starts every service in order. Each module under this
-- script owns one job; PlayerState holds all per-player state.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BrainrotModel = require(game.ReplicatedStorage.Shared.BrainrotModel)
local Net = require(game.ReplicatedStorage.Shared.Net)
local WorldBuilder = require(script.WorldBuilder)
local PlayerState = require(script.PlayerState)
local BaseSlots = require(script.BaseSlots)
local WildSpawner = require(script.WildSpawner)
local CarryAndSteal = require(script.CarryAndSteal)
local LavaWave = require(script.LavaWave)
local FurbettoThief = require(script.FurbettoThief)
local Progression = require(script.Progression)
local BatService = require(script.BatService)

Players.RespawnTime = 3

WorldBuilder.build()
local extraMeshes = table.clone(WorldBuilder.PROPS)
extraMeshes.Bat = BatService.MESH
BrainrotModel.loadMeshTemplates(15, extraMeshes)
WorldBuilder.decorate()
BaseSlots.start()
WildSpawner.start()
CarryAndSteal.start()
LavaWave.start()
FurbettoThief.start()
Progression.start()
BatService.start()

PlayerState.start(function(player)
	BaseSlots.onPlayerReady(player)
	CarryAndSteal.onPlayerReady(player)
end, function(player)
	CarryAndSteal.onPlayerLeaving(player)
	BaseSlots.onPlayerLeaving(player)
end)

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
			Net.event("Knockback"):FireClient(player, Vector3.new(0, 0, 1), 1.6)
		elseif command == "spawn" then
			WildSpawner.spawn(args[1], args[2], args[3])
		end
		return true
	end
	hook.Parent = game:GetService("ServerStorage")
end
