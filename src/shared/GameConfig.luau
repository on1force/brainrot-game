-- Every tunable number of Brainrot Lava Rush, plus the money formatter both sides use.

local GameConfig = {}

GameConfig.GAME_NAME = "BRAINROT LAVA RUSH"

-- Economy
GameConfig.START_MONEY = 200
GameConfig.SELL_SHARE = 0.5
GameConfig.REBIRTH_BASE_COST = 75000
GameConfig.REBIRTH_COST_GROWTH = 6
GameConfig.REBIRTH_INCOME_BONUS = 0.5 -- each rebirth adds +50% cash
GameConfig.CASH_FRENZY_MULT = 2

-- Movement upgrades
GameConfig.BASE_WALKSPEED = 26
GameConfig.SPEED_STEP = 3
GameConfig.SPEED_MAX_LEVEL = 10
GameConfig.SPEED_BASE_COST = 300
GameConfig.SPEED_COST_GROWTH = 2.4

-- Bases
GameConfig.PLOT_COUNT = 4
GameConfig.PLOT_SIZE = 56
GameConfig.PLOT_SPACING = 64
GameConfig.PLOT_CENTER_Z = -50
GameConfig.PADS_START = 8
GameConfig.PADS_MAX = 12
GameConfig.LOCK_DURATION = 40
GameConfig.LOCK_COOLDOWN = 25

-- The field: four zones running north (+Z) from the safe zone to the volcano
GameConfig.FIELD_WIDTH = 248
GameConfig.FIELD_LENGTH = 360
GameConfig.WILD_PER_ZONE = 7
GameConfig.WILD_LIFETIME = 120
GameConfig.ZONES = {
	{ name = "Snack Meadow", from = 0, to = 90, color = Color3.fromRGB(126, 206, 92),
		weights = { Common = 72, Rare = 25, Epic = 3 } },
	{ name = "Goober Gulch", from = 90, to = 180, color = Color3.fromRGB(232, 196, 92),
		weights = { Common = 15, Rare = 50, Epic = 28, Legendary = 7 } },
	{ name = "Chaos Canyon", from = 180, to = 270, color = Color3.fromRGB(226, 128, 74),
		weights = { Rare = 15, Epic = 42, Legendary = 33, Mythic = 10 } },
	{ name = "Volcano Rim", from = 270, to = 360, color = Color3.fromRGB(122, 74, 70),
		weights = { Epic = 18, Legendary = 38, Mythic = 30, BrainrotGod = 12, Secret = 2 } },
}

-- The lava wave
GameConfig.WAVE_INTERVAL = 45
GameConfig.WAVE_WARNING = 8
GameConfig.WAVE_TRAVEL_TIME = 14
GameConfig.WAVE_HEIGHT = 16
GameConfig.WAVE_DEPTH = 22
GameConfig.WAVE_LAVA_MUTATE_CHANCE = 0.2
GameConfig.SAFE_DOME_RADIUS = 11

-- Furbetto the snack bandit (NPC thief)
GameConfig.THIEF_FIRST_RAID = 40
GameConfig.THIEF_INTERVAL = 70
GameConfig.THIEF_SPEED = 18
GameConfig.THIEF_ESCAPE_SPEED = 15
GameConfig.THIEF_BOUNTY_SHARE = 0.25

-- The bonk bat every player carries
GameConfig.BAT_REACH = 10
GameConfig.BAT_COOLDOWN = 0.7
GameConfig.BAT_KNOCKBACK = 38 -- launch speed of a player hit by a bat
GameConfig.BAT_STUN = 1.6 -- seconds the hit player loses control
GameConfig.BAT_IMMUNITY = 3 -- seconds after a stun before the same player can be stunned again

-- Timed events
GameConfig.EVENT_FIRST = 60
GameConfig.EVENT_INTERVAL = 100
GameConfig.EVENT_DURATION = 40
GameConfig.GOLDEN_HOUR_MUTATION_BOOST = 4

function GameConfig.speedCost(level: number): number
	return math.floor(GameConfig.SPEED_BASE_COST * GameConfig.SPEED_COST_GROWTH ^ level)
end

function GameConfig.walkSpeed(level: number): number
	return GameConfig.BASE_WALKSPEED + GameConfig.SPEED_STEP * level
end

function GameConfig.rebirthCost(rebirths: number): number
	return math.floor(GameConfig.REBIRTH_BASE_COST * GameConfig.REBIRTH_COST_GROWTH ^ rebirths)
end

function GameConfig.rebirthMultiplier(rebirths: number): number
	return 1 + GameConfig.REBIRTH_INCOME_BONUS * rebirths
end

function GameConfig.padsFor(rebirths: number): number
	return math.min(GameConfig.PADS_START + rebirths, GameConfig.PADS_MAX)
end

function GameConfig.zoneAt(z: number): (number?, any)
	for index, zone in GameConfig.ZONES do
		if z >= zone.from and z < zone.to then
			return index, zone
		end
	end
	return nil, nil
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function GameConfig.formatMoney(amount: number): string
	local value = math.floor(amount)
	if value < 1000 then
		return "$" .. tostring(value)
	end
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	value = math.floor(value * 100) / 100
	local text = if value >= 100 then string.format("%d", value)
		elseif value >= 10 then string.format("%.1f", value)
		else string.format("%.2f", value)
	if text:find("%.") then
		text = (text:gsub("0+$", ""))
		text = (text:gsub("%.$", ""))
	end
	return "$" .. text .. SUFFIXES[index]
end

return GameConfig
