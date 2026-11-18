-- Walk and idle animation for every brainrot and for Furbetto. They are single sculpted meshes with no
-- skeleton, so the waddle is procedural: the server glides each model's root along the ground (in steps,
-- at network rate) and this script, every frame, moves the body's joint locally so the body
--   1. follows a smoothed copy of the root's position and facing, hiding the network steps, and
--   2. waddles while the server marks the model Moving (a gentle hop with a side-to-side rock), or
--      breathes and sways while it stands still.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MAX_DISTANCE = 220 -- skip animating models this far from the camera
local FOLLOW_RATE = 9 -- how quickly the smoothed body catches up with its root (per second)
local SNAP_DISTANCE = 12 -- a root that jumps further than this (a teleport) is snapped to, not chased

type Rig = { joint: Weld, base: CFrame, height: number, phase: number, visual: CFrame?, walk: number, cycle: number }
local rigs: { [Model]: Rig } = {}

local function track(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local body = model:FindFirstChild("Body")
	local joint = body and body:FindFirstChild("BodyJoint")
	if not (joint and joint:IsA("Weld")) then
		-- the body may still be streaming in
		task.delay(0.5, function()
			if model.Parent and not rigs[model] and model:FindFirstChild("Body") then
				track(model)
			end
		end)
		return
	end
	rigs[model] = {
		joint = joint,
		base = joint.C0,
		height = (model:GetAttribute("Height") :: number?) or 4,
		phase = math.random() * 10,
		visual = nil,
		walk = 0,
		cycle = math.random() * math.pi * 2,
	}
end

CollectionService:GetInstanceAddedSignal("Waddler"):Connect(track)
CollectionService:GetInstanceRemovedSignal("Waddler"):Connect(function(model)
	rigs[model :: Model] = nil
end)
for _, model in CollectionService:GetTagged("Waddler") do
	track(model)
end

-- Is the model walking? The server marks wild brainrots and Furbetto with a Moving attribute; a brainrot
-- carried over a player's head walks when that player does.
local function isWalking(model: Model, root: BasePart): boolean
	local flag = model:GetAttribute("Moving")
	if flag ~= nil then
		return flag == true
	end
	if not root.Anchored then
		local velocity = root.AssemblyLinearVelocity
		return Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2
	end
	return false
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local cameraPosition = workspace.CurrentCamera.CFrame.Position
	local follow = 1 - math.exp(-FOLLOW_RATE * dt)
	for model, rig in rigs do
		-- a knocked-out Furbetto is animated by the server (spin and shrink); hands off
		if not model.Parent or not rig.joint.Parent or model:GetAttribute("Dying") then
			rigs[model] = nil
			continue
		end
		local root = model.PrimaryPart
		if not root then
			continue
		end
		local target = root.CFrame
		if (target.Position - cameraPosition).Magnitude > MAX_DISTANCE then
			rig.visual = target
			continue
		end

		-- 1. smoothed follow of an anchored root (an unanchored one, carried by a player, already moves smoothly)
		if root.Anchored and rig.visual and (rig.visual.Position - target.Position).Magnitude < SNAP_DISTANCE then
			rig.visual = (rig.visual :: CFrame):Lerp(target, follow)
		else
			rig.visual = target
		end

		-- 2. walk blend and a steady stride clock (advanced only while walking, so steps never jump)
		local walking = isWalking(model, root)
		rig.walk += ((if walking then 1 else 0) - rig.walk) * (1 - math.exp(-5 * dt))
		rig.cycle += dt * 6.5 * rig.walk

		local h = rig.height
		local step = math.sin(rig.cycle)
		local hop = (1 - math.cos(rig.cycle * 2)) * 0.5 * h * 0.05 * rig.walk -- one smooth lift per step
		local rock = step * math.rad(6) * rig.walk -- weight shifts from foot to foot
		local lean = math.rad(-5) * rig.walk
		local t = now + rig.phase
		local breathe = math.sin(t * 2) * h * 0.012 * (1 - rig.walk)
		local sway = math.sin(t * 1.1) * math.rad(2.5) * (1 - rig.walk)

		-- rotate about the feet (the root), then lift, all expressed from the smoothed position
		local anim = CFrame.new(0, hop + breathe, 0) * CFrame.Angles(lean, sway, rock) * rig.base
		rig.joint.C0 = target:ToObjectSpace(rig.visual :: CFrame) * anim
	end
end)
