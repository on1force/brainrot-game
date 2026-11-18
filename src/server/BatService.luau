-- The bonk bat: every player spawns with one in their backpack. A swing knocks out Furbetto, or knocks
-- another player back and stuns them for a moment (no damage). A thief who is bonked while carrying a
-- stolen brainrot drops it and it flies home to its owner.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage -- the shared modules sit right in it
local BrainrotModel = require(Shared.BrainrotModel)
local GameConfig = require(Shared.GameConfig)
local CarryAndSteal = require(script.Parent.CarryAndSteal)
local FurbettoThief = require(script.Parent.FurbettoThief)
local PlayerState = require(script.Parent.PlayerState)

local BatService = {}

-- AI-generated bat model made for this game; loaded with the brainrot meshes.
BatService.MESH = { mesh = "rbxassetid://122577951089011", texture = "rbxassetid://119378743391413" }

local BAT_LENGTH = 4.5
local knockbackRemote = GameConfig.remote("Knockback")
local lastSwing: { [Player]: number } = {}
local immuneUntil: { [Player]: number } = {}

local function makeBat(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bonk Bat"
	tool.ToolTip = "Click to BONK thieves"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local template = BrainrotModel.meshTemplate("Bat")
	local handle: BasePart
	if template then
		handle = template:Clone()
		handle.Size = template.Size * (BAT_LENGTH / template.Size.Y)
	else
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.6, BAT_LENGTH, 0.6)
		p.Color = Color3.fromRGB(200, 150, 90)
		p.Material = Enum.Material.Wood
		handle = p
	end
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	-- the hand holds the grip end (the bat's bottom) with the barrel resting back over the shoulder
	tool.Grip = CFrame.new(0, -BAT_LENGTH * 0.35, 0) * CFrame.Angles(math.rad(-60), 0, 0)
	local swoosh = Instance.new("Sound")
	swoosh.Name = "Swing"
	swoosh.SoundId = "rbxasset://sounds/swordslash.wav"
	swoosh.Volume = 0.6
	swoosh.Parent = handle
	local bonk = Instance.new("Sound")
	bonk.Name = "Bonk"
	bonk.SoundId = "rbxasset://sounds/collide.wav"
	bonk.Volume = 1
	bonk.Parent = handle
	return tool
end

-- Dizzy stars spinning over a stunned player's head, seen by everyone, for `seconds`.
local function showStun(character: Model, seconds: number)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "StunStars"
	tag.Size = UDim2.fromScale(6, 2)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	tag.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = "* BONKED! *"
	text.TextColor3 = Color3.fromRGB(255, 230, 80)
	text.TextStrokeTransparency = 0
	text.Parent = tag
	tag.Parent = head
	task.delay(seconds, function()
		tag:Destroy()
	end)
end

-- Knocks `target` back away from `attacker` and stuns them; a stolen brainrot they carry goes home.
function BatService.bonkPlayer(attacker: Player, target: Player)
	local now = os.clock()
	if (immuneUntil[target] or 0) > now then
		return
	end
	local attackerRoot = attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (attackerRoot and targetRoot) then
		return
	end
	immuneUntil[target] = now + GameConfig.BAT_STUN + GameConfig.BAT_IMMUNITY
	local away = Vector3.new(targetRoot.Position.X - attackerRoot.Position.X, 0, targetRoot.Position.Z - attackerRoot.Position.Z)
	local direction = if away.Magnitude > 0.1 then away.Unit else attackerRoot.CFrame.LookVector
	knockbackRemote:FireClient(target, direction, GameConfig.BAT_STUN)
	showStun(target.Character :: Model, GameConfig.BAT_STUN)

	local state = PlayerState.get(target)
	if state and state.carrying and state.carrying.fromUserId then
		CarryAndSteal.dropCarry(target, "bonked by " .. attacker.DisplayName)
		PlayerState.notify(attacker, "BONK! " .. target.DisplayName .. " dropped the stolen brainrot!", Color3.fromRGB(255, 220, 80))
	else
		PlayerState.notify(target, "BONKED by " .. attacker.DisplayName .. "!", Color3.fromRGB(255, 160, 80))
		PlayerState.notify(attacker, "BONK! " .. target.DisplayName .. " is seeing stars", Color3.fromRGB(255, 220, 80))
	end
end

-- One swing: the slash animation and sound, then the first thing in reach in front of the swinger.
function BatService.swing(player: Player, tool: Tool)
	local now = os.clock()
	if now - (lastSwing[player] or 0) < GameConfig.BAT_COOLDOWN then
		return
	end
	lastSwing[player] = now
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	-- the default Animate script plays its tool slash animation when it sees this value
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:FindFirstChild("Swing") then
		(handle :: any).Swing:Play()
	end

	local origin = root.Position + root.CFrame.LookVector * 3.5
	local hit = FurbettoThief.tryHit(player, origin, GameConfig.BAT_REACH)
	if not hit then
		for _, other in Players:GetPlayers() do
			local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = otherRoot and other.Character:FindFirstChildOfClass("Humanoid")
			if otherRoot and humanoid and humanoid.Health > 0 and (otherRoot.Position - origin).Magnitude <= GameConfig.BAT_REACH * 0.7 then
				BatService.bonkPlayer(player, other)
				hit = true
				break
			end
		end
	end
	if hit and handle and handle:FindFirstChild("Bonk") then
		(handle :: any).Bonk:Play()
	end
end

local function giveBat(player: Player)
	local backpack = player:WaitForChild("Backpack")
	if backpack:FindFirstChild("Bonk Bat") or (player.Character and player.Character:FindFirstChild("Bonk Bat")) then
		return
	end
	local tool = makeBat()
	tool.Activated:Connect(function()
		BatService.swing(player, tool)
	end)
	tool.Parent = backpack
	if not player:GetAttribute("BatHintShown") then
		player:SetAttribute("BatHintShown", true)
		PlayerState.notify(player, "🏏 Press 1 for your BONK BAT, click to swing at Furbetto and thieves!", Color3.fromRGB(255, 180, 60))
	end
end

function BatService.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			giveBat(player)
		end)
		if player.Character then
			task.spawn(giveBat, player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		immuneUntil[player] = nil
	end)
end

return BatService
