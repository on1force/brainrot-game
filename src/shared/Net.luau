-- Named RemoteEvents shared by server and client. The server creates them; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- State: server -> client snapshot of the player's own state
-- Notify: server -> client toast message
-- Fx: server -> client one-shot effect (cash popup, shake, sound)
-- Action: client -> server request ("BuySpeed", "Rebirth", "LockBase")
-- Knockback: server -> client, launch your own character (direction, stun seconds) after a bat hit
local EVENT_NAMES = { "State", "Notify", "Fx", "Action", "Knockback" }

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for _, name in EVENT_NAMES do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
