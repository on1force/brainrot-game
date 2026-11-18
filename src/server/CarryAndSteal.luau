-- The dash home: buying a wild brainrot puts it over your head until you reach your base, where it
-- lands on a free pad. Other players can steal from an unlocked base and must carry the loot home
-- too; dying drops whatever you carry. The base lock (button or HUD) blocks every thief for a while.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local BrainrotCatalog = require(Shared.BrainrotCatalog)
local BrainrotModel = require(Shared.BrainrotModel)
local GameConfig = require(Shared.GameConfig)
local BaseSlots = require(script.Parent.BaseSlots)
local PlayerState = require(script.Parent.PlayerState)
local WildSpawner = require(script.Parent.WildSpawner)

local CarryAndSteal = {}

local carriedModels: { [Player]: Model } = {}
local fullWarnedAt: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function clearCarryModel(player: Player)
	local model = carriedModels[player]
	if model then
		model:Destroy()
		carriedModels[player] = nil
	end
end

-- Hoists a brainrot over the player's head and records it as carried.
function CarryAndSteal.startCarry(player: Player, id: string, mutationId: string, fromUserId: number?)
	local state = PlayerState.get(player)
	state.carrying = { id = id, mutation = mutationId, fromUserId = fromUserId }
	clearCarryModel(player)
	local root = rootOf(player)
	if root then
		local model = BrainrotModel.build(id, mutationId)
		model:ScaleTo(model:GetScale() * 0.5)
		local modelRoot = model.PrimaryPart :: BasePart
		model:PivotTo(root.CFrame * CFrame.new(0, 2.6, 0))
		modelRoot.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = modelRoot
		weld.Parent = modelRoot
		model.Parent = player.Character
		carriedModels[player] = model
	end
	PlayerState.push(player)
end

-- Drops what the player carries (death, lava). Stolen loot goes back to its owner's base.
function CarryAndSteal.dropCarry(player: Player, reason: string)
	local state = PlayerState.get(player)
	if not state or not state.carrying then
		return
	end
	local item = state.carrying
	state.carrying = nil
	clearCarryModel(player)
	local name = BrainrotCatalog.BY_ID[item.id].name
	if item.fromUserId then
		local owner = Players:GetPlayerByUserId(item.fromUserId)
		if owner and BaseSlots.placeBrainrot(owner, item.id, item.mutation) then
			PlayerState.notify(owner, name .. " came back home!", Color3.fromRGB(120, 255, 140))
		end
	end
	PlayerState.notify(player, "You dropped " .. name .. " (" .. reason .. ")", Color3.fromRGB(255, 110, 90))
	PlayerState.push(player)
end

-- Grab prompt on a wild brainrot: pay its price and carry it home.
function CarryAndSteal.buyBrainrot(player: Player, wild)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	if state.carrying then
		PlayerState.notify(player, "Your hands are full - run home first!")
		return
	end
	local price = BrainrotCatalog.priceOf(wild.id, wild.mutation)
	if not PlayerState.spend(player, price) then
		PlayerState.notify(player, "Need " .. GameConfig.formatMoney(price) .. " for that one", Color3.fromRGB(255, 110, 90))
		return
	end
	WildSpawner.remove(wild)
	CarryAndSteal.startCarry(player, wild.id, wild.mutation, nil)
	PlayerState.fx(player, "Grab", { rarity = BrainrotCatalog.BY_ID[wild.id].rarity })
end

-- Steal prompt on another player's pad.
function CarryAndSteal.stealFromBase(thief: Player, owner: Player, padIndex: number)
	local thiefState = PlayerState.get(thief)
	if not thiefState or not PlayerState.get(owner) then
		return
	end
	if thiefState.carrying then
		PlayerState.notify(thief, "Drop off what you carry first!")
		return
	end
	if PlayerState.isLocked(owner) then
		PlayerState.notify(thief, owner.DisplayName .. "'s base is LOCKED", Color3.fromRGB(255, 110, 90))
		return
	end
	local item = BaseSlots.removeAt(owner, padIndex)
	if not item then
		return
	end
	CarryAndSteal.startCarry(thief, item.id, item.mutation, owner.UserId)
	local name = BrainrotCatalog.BY_ID[item.id].name
	PlayerState.notify(owner, thief.DisplayName .. " is STEALING your " .. name .. "! Catch them!", Color3.fromRGB(255, 70, 70))
	PlayerState.fx(owner, "Alarm")
	PlayerState.notify(thief, "Stole " .. name .. "! Run to your base!", Color3.fromRGB(255, 220, 80))
end

-- Locks the player's base for LOCK_DURATION seconds if the lock has cooled down.
function CarryAndSteal.lockBase(player: Player)
	local state = PlayerState.get(player)
	if not state or not state.plot then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now < state.lockUntil then
		return
	end
	if now < state.lockReadyAt then
		PlayerState.notify(player, ("Lock recharging: %ds"):format(math.ceil(state.lockReadyAt - now)))
		return
	end
	state.lockUntil = now + GameConfig.LOCK_DURATION
	state.lockReadyAt = state.lockUntil + GameConfig.LOCK_COOLDOWN
	BaseSlots.showLock(player, true)
	PlayerState.notify(player, "Base locked for " .. GameConfig.LOCK_DURATION .. "s", Color3.fromRGB(120, 255, 140))
	PlayerState.fx(player, "Lock")
	PlayerState.push(player)
end

-- Lands carried brainrots on the carrier's base and keeps the lock buttons' text current.
local function checkCarriersAtHome()
	local now = workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local state = PlayerState.get(player)
		if not state then
			continue
		end
		if state.plot then
			if now < state.lockUntil then
				BaseSlots.setLockText(player, ("LOCKED %ds"):format(math.ceil(state.lockUntil - now)))
			else
				if state.lockUntil > 0 then
					BaseSlots.showLock(player, false)
				end
				BaseSlots.setLockText(player, if now < state.lockReadyAt
					then ("RECHARGING %ds"):format(math.ceil(state.lockReadyAt - now)) else "STEP TO LOCK BASE")
			end
		end
		local root = rootOf(player)
		if not (state.carrying and root and BaseSlots.isInsideOwnPlot(player, root.Position)) then
			continue
		end
		local item = state.carrying
		if BaseSlots.placeBrainrot(player, item.id, item.mutation) then
			state.carrying = nil
			clearCarryModel(player)
			local def = BrainrotCatalog.BY_ID[item.id]
			PlayerState.notify(player, def.name .. " now earns " .. GameConfig.formatMoney(
				BrainrotCatalog.incomeOf(item.id, item.mutation) * PlayerState.multiplier(player)) .. "/s for you!",
				BrainrotCatalog.RARITY_BY_ID[def.rarity].color)
			PlayerState.fx(player, "Placed", { rarity = def.rarity })
			if item.fromUserId then
				local owner = Players:GetPlayerByUserId(item.fromUserId)
				if owner then
					PlayerState.notify(owner, player.DisplayName .. " got away with your " .. def.name .. "!", Color3.fromRGB(255, 70, 70))
				end
			end
			PlayerState.push(player)
		elseif (fullWarnedAt[player] or 0) < os.clock() - 4 then
			fullWarnedAt[player] = os.clock()
			PlayerState.notify(player, "Base full! Sell a brainrot (F) or rebirth for more pads", Color3.fromRGB(255, 160, 80))
		end
	end
end

function CarryAndSteal.onPlayerReady(player: Player)
	local function hookDeath(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			CarryAndSteal.dropCarry(player, "you got wiped out")
		end)
	end
	player.CharacterAdded:Connect(hookDeath)
	if player.Character then
		task.spawn(hookDeath, player.Character)
	end
	local state = PlayerState.get(player)
	local plot = state.plot and BaseSlots.plotOf(player)
	if plot then
		plot.lockButton.Touched:Connect(function(hit)
			if hit.Parent == player.Character then
				CarryAndSteal.lockBase(player)
			end
		end)
	end
end

function CarryAndSteal.onPlayerLeaving(player: Player)
	CarryAndSteal.dropCarry(player, "left")
	fullWarnedAt[player] = nil
end

function CarryAndSteal.start()
	WildSpawner.onGrab = CarryAndSteal.buyBrainrot
	BaseSlots.onSteal = CarryAndSteal.stealFromBase
	task.spawn(function()
		while true do
			task.wait(0.2)
			checkCarriersAtHome()
		end
	end)
end

return CarryAndSteal
