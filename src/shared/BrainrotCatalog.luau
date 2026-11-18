-- The cast of Brainrot Lava Rush: rarities, mutations and 19 original brainrots with their
-- price, cash per second, catchphrase and a part-by-part look that BrainrotModel builds in 3D.
-- Front of every look is -Z; positions are relative to the brainrot's feet.

local BrainrotCatalog = {}

local rgb = Color3.fromRGB
local v3 = Vector3.new

BrainrotCatalog.RARITIES = {
	{ id = "Common", label = "Common", color = rgb(205, 205, 205), scale = 1.0 },
	{ id = "Rare", label = "Rare", color = rgb(72, 156, 255), scale = 1.1 },
	{ id = "Epic", label = "Epic", color = rgb(180, 90, 255), scale = 1.22 },
	{ id = "Legendary", label = "Legendary", color = rgb(255, 196, 40), scale = 1.36 },
	{ id = "Mythic", label = "Mythic", color = rgb(255, 64, 80), scale = 1.52 },
	{ id = "BrainrotGod", label = "Brainrot God", color = rgb(60, 255, 214), scale = 1.72 },
	{ id = "Secret", label = "SECRET", color = rgb(255, 255, 255), scale = 1.95 },
}

BrainrotCatalog.MUTATIONS = {
	{ id = "None", label = "", mult = 1, weight = 780 },
	{ id = "Gold", label = "GOLD", mult = 2, weight = 150, color = rgb(255, 200, 40) },
	{ id = "Diamond", label = "DIAMOND", mult = 3, weight = 60, color = rgb(120, 232, 255) },
	-- Lava is never rolled: the lava wave gives it to wild brainrots it washes over.
	{ id = "Lava", label = "LAVA", mult = 4, weight = 0, color = rgb(255, 96, 24) },
	{ id = "Rainbow", label = "RAINBOW", mult = 6, weight = 8, color = rgb(255, 120, 220) },
	{ id = "Cosmic", label = "COSMIC", mult = 10, weight = 2, color = rgb(150, 90, 255) },
}

-- One part of a look: shape ("Ball" | "Block" | "Cylinder" | "Wedge"), size, position, color, options
-- (mat = material name, rot = degrees, alpha = transparency, light = adds a PointLight).
local function P(shape: string, size: Vector3, pos: Vector3, color: Color3, opts: { [string]: any }?)
	return { shape = shape, size = size, pos = pos, color = color, opts = opts or {} }
end

local UP = v3(0, 0, 90) -- turns a Cylinder (axis X) upright
local FWD = v3(0, 90, 0) -- turns a Cylinder to face forward (axis Z)
local BLACK = rgb(25, 25, 30)
local WHITE = rgb(245, 245, 245)
local GOLD = rgb(255, 196, 50)

BrainrotCatalog.CAST = {
	-- Common
	{ id = "Toastolino", name = "Toastolino Crunchetti", rarity = "Common", price = 60, income = 2,
		quote = "crunch crunch, bro",
		look = { legs = { color = rgb(120, 80, 40) }, eyes = { y = 3.4, z = -0.55, spread = 0.6, size = 0.7 },
			mouth = { y = 2.5, z = -0.53, w = 0.9 },
			parts = {
				P("Block", v3(3, 3.2, 0.9), v3(0, 2.8, 0), rgb(226, 172, 98)),
				P("Ball", v3(3, 1.6, 0.9), v3(0, 4.4, 0), rgb(226, 172, 98)),
				P("Block", v3(2.6, 2.8, 0.1), v3(0, 2.8, -0.46), rgb(246, 214, 150)),
				P("Block", v3(1.1, 0.25, 0.9), v3(0, 5.15, 0), rgb(255, 232, 112), { rot = v3(0, 20, 0) }),
			} } },
	{ id = "Bobo", name = "Bobo Bucketoni", rarity = "Common", price = 110, income = 3,
		quote = "i am 90% puddle",
		look = { legs = { color = rgb(60, 60, 70) }, eyes = { y = 2.9, z = -1.45, spread = 0.6, size = 0.75 },
			mouth = { y = 2.1, z = -1.42, w = 1 },
			parts = {
				P("Cylinder", v3(2.8, 2.8, 2.8), v3(0, 2.6, 0), rgb(70, 110, 220), { rot = UP }),
				P("Cylinder", v3(0.35, 3.1, 3.1), v3(0, 4.05, 0), rgb(170, 180, 190), { rot = UP, mat = "Metal" }),
				P("Cylinder", v3(0.2, 2.6, 2.6), v3(0, 4.1, 0), rgb(90, 190, 255), { rot = UP, alpha = 0.2 }),
				P("Block", v3(0.2, 1.6, 0.2), v3(-1.5, 4.6, 0), rgb(170, 180, 190)),
				P("Block", v3(0.2, 1.6, 0.2), v3(1.5, 4.6, 0), rgb(170, 180, 190)),
				P("Block", v3(3.2, 0.2, 0.2), v3(0, 5.4, 0), rgb(170, 180, 190)),
			} } },
	{ id = "Pebblo", name = "Pebblo Sassolini", rarity = "Common", price = 180, income = 5,
		quote = "a BOULDER in my heart",
		look = { legs = { color = rgb(90, 90, 100) }, eyes = { y = 2.9, z = -1.45, spread = 0.65, size = 0.7 },
			parts = {
				P("Ball", v3(3.6, 2.8, 3.2), v3(0, 2.5, 0), rgb(140, 140, 150), { mat = "Slate" }),
				P("Ball", v3(1.6, 0.7, 1.4), v3(0.5, 3.9, 0.2), rgb(80, 170, 70), { mat = "Grass" }),
				P("Block", v3(0.6, 0.5, 0.2), v3(-0.35, 1.8, -1.45), rgb(220, 40, 50), { rot = v3(0, 0, 20) }),
				P("Block", v3(0.6, 0.5, 0.2), v3(0.35, 1.8, -1.45), rgb(220, 40, 50), { rot = v3(0, 0, -20) }),
			} } },
	{ id = "Sockaccio", name = "Sockaccio Puzzolente", rarity = "Common", price = 260, income = 7,
		quote = "smells like victory (and feet)",
		look = { eyes = { y = 3.0, z = -0.3, spread = 0.5, size = 0.6 }, mouth = { y = 2.4, z = -0.28, w = 0.7 },
			parts = {
				P("Block", v3(1.8, 3.6, 1.3), v3(0, 2.6, 0.4), WHITE),
				P("Block", v3(1.8, 1.3, 3), v3(0, 0.65, -0.45), WHITE),
				P("Block", v3(1.85, 0.35, 1.35), v3(0, 3.7, 0.4), rgb(230, 50, 60)),
				P("Block", v3(1.85, 0.35, 1.35), v3(0, 3.1, 0.4), rgb(60, 110, 230)),
				P("Ball", v3(0.5, 0.5, 0.2), v3(0.4, 0.8, -1.95), BLACK),
				P("Ball", v3(2.6, 1.4, 2.6), v3(0, 5.1, 0.4), rgb(150, 220, 90), { alpha = 0.45, mat = "Neon" }),
			} } },
	-- Rare
	{ id = "Frigorifero", name = "Frigorifero Ronzante", rarity = "Rare", price = 900, income = 18,
		quote = "hmmmmmmmmmmmmmmmm",
		look = { legs = { color = rgb(80, 80, 90) }, eyes = { y = 5.6, z = -1.25, spread = 0.7, size = 0.8 },
			mouth = { y = 5.0, z = -1.25, w = 1.2 },
			parts = {
				P("Block", v3(3, 5, 2.4), v3(0, 3.7, 0), rgb(236, 240, 246), { mat = "SmoothPlastic" }),
				P("Block", v3(3.04, 0.12, 2.44), v3(0, 4.6, 0), rgb(160, 170, 180)),
				P("Block", v3(0.25, 1.2, 0.3), v3(1.1, 3.6, -1.3), rgb(150, 150, 160), { mat = "Metal" }),
				P("Block", v3(0.4, 0.4, 0.1), v3(-0.9, 3.0, -1.23), rgb(230, 50, 50)),
				P("Block", v3(0.4, 0.4, 0.1), v3(-0.3, 2.6, -1.23), rgb(255, 210, 40)),
				P("Block", v3(0.4, 0.4, 0.1), v3(0.4, 3.0, -1.23), rgb(60, 200, 90)),
			} } },
	{ id = "Cactusso", name = "Cactusso Abbracciami", rarity = "Rare", price = 1400, income = 26,
		quote = "free hugs. no refunds.",
		look = { eyes = { y = 4.6, z = -0.95, spread = 0.45, size = 0.6 }, mouth = { y = 3.9, z = -1.0, w = 0.6 },
			parts = {
				P("Cylinder", v3(1.6, 2.6, 2.6), v3(0, 0.8, 0), rgb(196, 104, 64), { rot = UP }),
				P("Cylinder", v3(4, 2, 2), v3(0, 3.6, 0), rgb(64, 164, 74), { rot = UP }),
				P("Ball", v3(2, 2, 2), v3(0, 5.6, 0), rgb(64, 164, 74)),
				P("Block", v3(0.9, 0.8, 0.8), v3(-1.4, 3.4, 0), rgb(64, 164, 74)),
				P("Block", v3(0.8, 1.6, 0.8), v3(-1.8, 4.1, 0), rgb(64, 164, 74)),
				P("Block", v3(0.9, 0.8, 0.8), v3(1.4, 3.0, 0), rgb(64, 164, 74)),
				P("Block", v3(0.8, 1.6, 0.8), v3(1.8, 3.7, 0), rgb(64, 164, 74)),
				P("Ball", v3(0.9, 0.9, 0.9), v3(0.4, 6.6, 0), rgb(255, 110, 200), { mat = "Neon" }),
			} } },
	{ id = "Paperotto", name = "Paperotto Dinamite", rarity = "Rare", price = 2100, income = 38,
		quote = "quack... BOOM",
		look = { legs = { color = rgb(255, 140, 30) }, eyes = { y = 4.3, z = -1.4, spread = 0.45, size = 0.5 },
			parts = {
				P("Ball", v3(2.8, 2.4, 3.2), v3(0, 2.4, 0.3), rgb(255, 218, 52)),
				P("Ball", v3(1.9, 1.9, 1.9), v3(0, 4.0, -0.6), rgb(255, 218, 52)),
				P("Block", v3(1.1, 0.35, 0.9), v3(0, 3.75, -1.65), rgb(255, 140, 30)),
				P("Cylinder", v3(1.9, 0.6, 0.6), v3(1.6, 2.6, -0.6), rgb(220, 40, 40), { rot = UP }),
				P("Block", v3(0.15, 0.5, 0.15), v3(1.6, 3.75, -0.6), rgb(255, 240, 80), { mat = "Neon" }),
			} } },
	-- Epic
	{ id = "Croissantonio", name = "Croissantonio Turbo", rarity = "Epic", price = 6500, income = 95,
		quote = "zero to flaky in 2 seconds",
		look = { legs = { color = rgb(120, 70, 30) }, mouth = { y = 2.2, z = -1.18, w = 0.8 },
			parts = {
				P("Ball", v3(3.8, 2.2, 2.4), v3(0, 2.6, 0), rgb(222, 150, 62)),
				P("Ball", v3(1.8, 1.4, 1.6), v3(-2.1, 2.3, 0), rgb(204, 130, 50), { rot = v3(0, 0, 30) }),
				P("Ball", v3(1.8, 1.4, 1.6), v3(2.1, 2.3, 0), rgb(204, 130, 50), { rot = v3(0, 0, -30) }),
				P("Cylinder", v3(1.8, 1.1, 1.1), v3(0, 2.9, 1.7), rgb(120, 120, 130), { rot = FWD, mat = "Metal" }),
				P("Ball", v3(0.9, 0.9, 1.6), v3(0, 2.9, 3.1), rgb(255, 140, 40), { mat = "Neon", light = true }),
				P("Block", v3(2.4, 0.55, 0.2), v3(0, 2.95, -1.2), BLACK, { mat = "SmoothPlastic" }),
			} } },
	{ id = "Pinguino", name = "Pinguino Lavatrice", rarity = "Epic", price = 9500, income = 135,
		quote = "spin cycle supremacy",
		look = { eyes = { y = 4.75, z = -1.15, spread = 0.4, size = 0.45 },
			parts = {
				P("Block", v3(3.2, 3.6, 3), v3(0, 1.8, 0), rgb(232, 232, 238), { mat = "SmoothPlastic" }),
				P("Cylinder", v3(0.3, 2.4, 2.4), v3(0, 1.6, -1.55), rgb(160, 160, 170), { rot = FWD, mat = "Metal" }),
				P("Cylinder", v3(0.32, 1.9, 1.9), v3(0, 1.6, -1.58), rgb(80, 150, 230), { rot = FWD, mat = "Glass" }),
				P("Block", v3(3.2, 0.5, 0.2), v3(0, 3.2, -1.52), rgb(140, 140, 150)),
				P("Ball", v3(2.4, 2.2, 2.2), v3(0, 4.6, 0), rgb(30, 30, 40)),
				P("Ball", v3(1.7, 1.5, 0.6), v3(0, 4.5, -0.85), WHITE),
				P("Block", v3(0.6, 0.35, 0.6), v3(0, 4.35, -1.25), rgb(255, 150, 30)),
				P("Block", v3(0.9, 0.3, 1.2), v3(-0.8, 0.15, -1.6), rgb(255, 150, 30)),
				P("Block", v3(0.9, 0.3, 1.2), v3(0.8, 0.15, -1.6), rgb(255, 150, 30)),
			} } },
	{ id = "Ananasso", name = "Ananasso Pilota", rarity = "Epic", price = 14000, income = 190,
		quote = "CLEARED FOR TAKEOFF",
		look = { legs = { color = rgb(90, 60, 30) }, mouth = { y = 2.7, z = -1.38, w = 0.8 },
			parts = {
				P("Ball", v3(2.8, 3.4, 2.8), v3(0, 2.9, 0), rgb(242, 190, 40)),
				P("Block", v3(0.5, 2, 0.5), v3(0, 5.2, 0), rgb(50, 160, 60)),
				P("Block", v3(0.5, 2, 0.5), v3(-0.5, 5.0, 0), rgb(50, 160, 60), { rot = v3(0, 0, 25) }),
				P("Block", v3(0.5, 2, 0.5), v3(0.5, 5.0, 0), rgb(50, 160, 60), { rot = v3(0, 0, -25) }),
				P("Cylinder", v3(0.5, 2.9, 2.9), v3(0, 3.6, 0), rgb(110, 70, 40), { rot = UP }),
				P("Cylinder", v3(0.3, 0.9, 0.9), v3(-0.55, 3.6, -1.35), rgb(120, 210, 255), { rot = FWD, mat = "Glass" }),
				P("Cylinder", v3(0.3, 0.9, 0.9), v3(0.55, 3.6, -1.35), rgb(120, 210, 255), { rot = FWD, mat = "Glass" }),
				P("Block", v3(0.5, 1.4, 0.15), v3(1.0, 1.9, -1.2), rgb(220, 40, 40), { rot = v3(0, 0, -20) }),
			} } },
	-- Legendary
	{ id = "Gelatone", name = "Gelatone Gigantesco", rarity = "Legendary", price = 45000, income = 520,
		quote = "brain freeze is my love language",
		look = { eyes = { y = 3.9, z = -1.45, spread = 0.6, size = 0.7 }, mouth = { y = 3.2, z = -1.45, w = 0.8 },
			parts = {
				P("Cylinder", v3(2.6, 1.8, 1.8), v3(0, 1.3, 0), rgb(204, 150, 88), { rot = UP }),
				P("Ball", v3(3, 2.6, 3), v3(0, 3.6, 0), rgb(255, 150, 190)),
				P("Ball", v3(2.7, 2.3, 2.7), v3(0, 5.5, 0), rgb(150, 240, 190)),
				P("Ball", v3(2.3, 2, 2.3), v3(0, 7.2, 0), rgb(110, 70, 50)),
				P("Ball", v3(0.8, 0.8, 0.8), v3(0, 8.5, 0), rgb(230, 20, 40)),
			} } },
	{ id = "Lampadone", name = "Lampadone Filosofo", rarity = "Legendary", price = 70000, income = 780,
		quote = "what if... light... but MORE",
		look = { eyes = { y = 5.6, z = -1.75, spread = 0.65, size = 0.75 },
			parts = {
				P("Cylinder", v3(0.5, 2.8, 2.8), v3(0, 0.25, 0), rgb(200, 160, 60), { rot = UP, mat = "Metal" }),
				P("Cylinder", v3(3.4, 0.5, 0.5), v3(0, 2.2, 0), rgb(200, 160, 60), { rot = UP, mat = "Metal" }),
				P("Ball", v3(1.2, 1.2, 1.2), v3(0, 4.0, 0), rgb(255, 240, 120), { mat = "Neon", light = true }),
				P("Cylinder", v3(2.6, 3.4, 3.4), v3(0, 5.2, 0), rgb(250, 235, 200), { rot = UP, alpha = 0.1 }),
				P("Block", v3(1.6, 0.3, 0.2), v3(0, 4.7, -1.75), BLACK),
			} } },
	{ id = "Tostapane", name = "Tostapane Volante", rarity = "Legendary", price = 100000, income = 1100,
		quote = "i toast, therefore i fly",
		look = { eyes = { y = 2.9, z = -1.15, spread = 0.7, size = 0.7 }, mouth = { y = 2.1, z = -1.12, w = 1 },
			parts = {
				P("Block", v3(3.4, 2.6, 2.2), v3(0, 2.5, 0), rgb(200, 204, 214), { mat = "Metal" }),
				P("Block", v3(2.6, 0.1, 0.35), v3(0, 3.82, -0.45), BLACK),
				P("Block", v3(2.6, 0.1, 0.35), v3(0, 3.82, 0.45), BLACK),
				P("Block", v3(1.2, 1.4, 0.3), v3(-0.5, 4.2, -0.45), rgb(214, 160, 90)),
				P("Block", v3(1.2, 1.4, 0.3), v3(0.5, 4.4, 0.45), rgb(214, 160, 90)),
				P("Block", v3(3, 0.2, 1.4), v3(-2.9, 3.0, 0.2), WHITE, { rot = v3(0, 0, 20) }),
				P("Block", v3(3, 0.2, 1.4), v3(2.9, 3.0, 0.2), WHITE, { rot = v3(0, 0, -20) }),
				P("Ball", v3(2, 0.6, 1.6), v3(0, 0.8, 0), rgb(90, 200, 255), { mat = "Neon", alpha = 0.3 }),
			} } },
	-- Mythic
	{ id = "Lunetta", name = "Lunetta Miaozzi", rarity = "Mythic", price = 350000, income = 3400,
		quote = "meow is just moon spelled wrong",
		look = { eyes = { y = 3.5, z = -1.65, spread = 0.75, size = 0.9 },
			parts = {
				P("Ball", v3(3.8, 3.8, 3.8), v3(0, 3.0, 0), rgb(250, 240, 175), { mat = "Slate" }),
				P("Ball", v3(0.9, 0.9, 0.5), v3(1.1, 4.1, -1.5), rgb(210, 200, 140)),
				P("Ball", v3(0.7, 0.7, 0.5), v3(-1.2, 2.2, -1.45), rgb(210, 200, 140)),
				P("Wedge", v3(0.5, 1.4, 1.1), v3(-1.1, 5.0, 0), rgb(250, 240, 175)),
				P("Wedge", v3(0.5, 1.4, 1.1), v3(1.1, 5.0, 0), rgb(250, 240, 175)),
				P("Block", v3(1.4, 0.08, 0.08), v3(-1.5, 2.6, -1.6), BLACK, { rot = v3(0, 0, 10) }),
				P("Block", v3(1.4, 0.08, 0.08), v3(1.5, 2.6, -1.6), BLACK, { rot = v3(0, 0, -10) }),
				P("Ball", v3(0.4, 0.4, 0.4), v3(0, 2.8, -1.9), rgb(255, 140, 170)),
				P("Ball", v3(0.5, 0.5, 0.5), v3(2.5, 4.6, 0), rgb(255, 240, 90), { mat = "Neon" }),
				P("Ball", v3(0.4, 0.4, 0.4), v3(-2.4, 4.0, 0.5), rgb(255, 240, 90), { mat = "Neon" }),
			} } },
	{ id = "Burgerone", name = "Burgerone Bazooka", rarity = "Mythic", price = 520000, income = 4900,
		quote = "extra cheese. extra BOOM.",
		look = { legs = { color = rgb(110, 60, 40) }, eyes = { y = 4.2, z = -1.65, spread = 0.6, size = 0.7 },
			parts = {
				P("Cylinder", v3(0.9, 3.6, 3.6), v3(0, 1.65, 0), rgb(226, 160, 80), { rot = UP }),
				P("Cylinder", v3(0.8, 3.9, 3.9), v3(0, 2.5, 0), rgb(110, 60, 40), { rot = UP }),
				P("Block", v3(3.6, 0.2, 3.6), v3(0, 2.95, 0), rgb(255, 210, 40), { rot = v3(0, 45, 0) }),
				P("Cylinder", v3(0.3, 4.0, 4.0), v3(0, 3.15, 0), rgb(90, 200, 70), { rot = UP }),
				P("Ball", v3(3.7, 2.2, 3.7), v3(0, 3.9, 0), rgb(226, 160, 80)),
				P("Ball", v3(0.3, 0.3, 0.3), v3(0.6, 4.95, -0.5), WHITE),
				P("Ball", v3(0.3, 0.3, 0.3), v3(-0.5, 4.9, 0.4), WHITE),
				P("Cylinder", v3(3.6, 0.9, 0.9), v3(2.3, 3.0, 0.2), rgb(60, 90, 50), { rot = FWD }),
				P("Cylinder", v3(0.3, 1.1, 1.1), v3(2.3, 3.0, -1.6), BLACK, { rot = FWD }),
			} } },
	-- Brainrot God
	{ id = "Spaghettus", name = "Spaghettus Maximus", rarity = "BrainrotGod", price = 2500000, income = 21000,
		quote = "kneel before the noodle",
		look = { legs = { color = rgb(130, 70, 40) }, eyes = { y = 2.9, z = -1.85, spread = 0.7, size = 0.8 },
			parts = {
				P("Cylinder", v3(0.4, 4.6, 4.6), v3(0, 1.3, 0), WHITE, { rot = UP }),
				P("Ball", v3(3.8, 2.6, 3.8), v3(0, 2.6, 0), rgb(246, 216, 122)),
				P("Ball", v3(2.6, 0.9, 2.6), v3(0, 3.75, 0), rgb(210, 30, 30)),
				P("Ball", v3(0.9, 0.9, 0.9), v3(0.9, 3.9, -0.6), rgb(110, 60, 40)),
				P("Ball", v3(0.9, 0.9, 0.9), v3(-0.8, 3.8, 0.5), rgb(110, 60, 40)),
				P("Cylinder", v3(0.7, 2.0, 2.0), v3(0, 4.5, 0), GOLD, { rot = UP, mat = "Metal" }),
				P("Block", v3(0.3, 0.7, 0.3), v3(0.9, 5.1, 0), GOLD, { mat = "Metal" }),
				P("Block", v3(0.3, 0.7, 0.3), v3(-0.9, 5.1, 0), GOLD, { mat = "Metal" }),
				P("Block", v3(0.3, 0.7, 0.3), v3(0, 5.1, -0.9), GOLD, { mat = "Metal" }),
				P("Ball", v3(0.4, 0.4, 0.4), v3(0, 4.5, -1.0), rgb(255, 40, 60), { mat = "Neon" }),
				P("Block", v3(3.6, 2.8, 0.2), v3(0, 2.4, 2.0), rgb(120, 40, 170), { rot = v3(15, 0, 0) }),
			} } },
	{ id = "Orologio", name = "Orologio Infinito", rarity = "BrainrotGod", price = 4000000, income = 32000,
		quote = "it is always rot o'clock",
		look = { legs = { color = rgb(60, 60, 70) }, eyes = { y = 4.6, z = -0.42, spread = 0.9, size = 0.6 },
			parts = {
				P("Cylinder", v3(0.7, 4, 4), v3(0, 3.6, 0), WHITE, { rot = FWD }),
				P("Cylinder", v3(0.6, 4.4, 4.4), v3(0, 3.6, 0.1), GOLD, { rot = FWD, mat = "Metal" }),
				P("Block", v3(0.18, 1.5, 0.1), v3(0, 4.2, -0.4), BLACK),
				P("Block", v3(1.1, 0.18, 0.1), v3(0.45, 3.6, -0.4), BLACK),
				P("Ball", v3(0.3, 0.3, 0.3), v3(0, 3.6, -0.42), BLACK),
				P("Block", v3(2.6, 1.2, 0.2), v3(-3.0, 4.0, 0.3), WHITE, { rot = v3(0, 0, 25) }),
				P("Block", v3(2.6, 1.2, 0.2), v3(3.0, 4.0, 0.3), WHITE, { rot = v3(0, 0, -25) }),
				P("Ball", v3(1, 1, 1), v3(-1.4, 5.9, 0), GOLD, { mat = "Metal" }),
				P("Ball", v3(1, 1, 1), v3(1.4, 5.9, 0), GOLD, { mat = "Metal" }),
			} } },
	-- Secret
	{ id = "Mucca", name = "La Mucca Cosmica", rarity = "Secret", price = 20000000, income = 150000,
		quote = "moo-ve over, gravity",
		look = { legs = { color = WHITE }, eyes = { y = 3.9, z = -2.62, spread = 0.45, size = 0.45 },
			parts = {
				P("Block", v3(2.2, 2.4, 3.8), v3(0, 2.4, 0.4), WHITE),
				P("Block", v3(0.05, 1, 1.2), v3(1.12, 2.6, 0.8), BLACK),
				P("Block", v3(0.05, 0.9, 1), v3(-1.12, 2.2, -0.2), BLACK),
				P("Block", v3(1.8, 1.6, 1.6), v3(0, 3.6, -1.8), WHITE),
				P("Block", v3(1.4, 0.7, 0.4), v3(0, 3.2, -2.7), rgb(255, 160, 180)),
				P("Block", v3(0.25, 0.6, 0.25), v3(-0.6, 4.65, -1.8), rgb(240, 230, 200)),
				P("Block", v3(0.25, 0.6, 0.25), v3(0.6, 4.65, -1.8), rgb(240, 230, 200)),
				P("Ball", v3(2.8, 2.8, 2.8), v3(0, 3.6, -1.8), rgb(170, 220, 255), { mat = "Glass", alpha = 0.65 }),
				P("Cylinder", v3(0.15, 7.5, 7.5), v3(0, 2.6, 0.4), rgb(170, 80, 255), { rot = UP, mat = "Neon", alpha = 0.3 }),
			} } },
	{ id = "ReCalzini", name = "Il Re dei Calzini", rarity = "Secret", price = 35000000, income = 240000,
		quote = "where is my other half?",
		look = { eyes = { y = 3.4, z = -0.32, spread = 0.55, size = 0.7 }, mouth = { y = 2.7, z = -0.32, w = 0.8 },
			parts = {
				P("Block", v3(2, 4, 1.4), v3(0, 2.8, 0.4), rgb(130, 60, 200)),
				P("Block", v3(2, 1.4, 3.2), v3(0, 0.7, -0.5), rgb(130, 60, 200)),
				P("Block", v3(2.05, 0.35, 1.45), v3(0, 4.2, 0.4), GOLD),
				P("Block", v3(2.05, 0.35, 1.45), v3(0, 1.9, 0.4), GOLD),
				P("Cylinder", v3(0.6, 1.8, 1.8), v3(0, 5.1, 0.4), GOLD, { rot = UP, mat = "Metal" }),
				P("Block", v3(0.3, 0.6, 0.3), v3(0.7, 5.6, 0.4), GOLD, { mat = "Metal" }),
				P("Block", v3(0.3, 0.6, 0.3), v3(-0.7, 5.6, 0.4), GOLD, { mat = "Metal" }),
				P("Block", v3(3, 3.6, 0.2), v3(0, 2.8, 1.3), rgb(200, 20, 40)),
				P("Cylinder", v3(3, 0.25, 0.25), v3(1.6, 2.6, -0.3), GOLD, { rot = UP, mat = "Metal" }),
				P("Ball", v3(0.6, 0.6, 0.6), v3(1.6, 4.2, -0.3), rgb(80, 255, 255), { mat = "Neon", light = true }),
			} } },
}

-- Textured 3D models made for this game with Roblox's AI mesh generator (one prompt per character),
-- keyed by catalog id, plus Furbetto the NPC thief. `height` is the brainrot's height in studs before its
-- rarity scale. BrainrotModel falls back to the part-built `look` if a mesh fails to load.
BrainrotCatalog.MESHES = {
	Toastolino = { mesh = "rbxassetid://120144820278148", texture = "rbxassetid://83630550214885", height = 4 },
	Bobo = { mesh = "rbxassetid://124486779446513", texture = "rbxassetid://107075845304006", height = 3.4 },
	Pebblo = { mesh = "rbxassetid://83322807672071", texture = "rbxassetid://116740062741912", height = 3.8 },
	Sockaccio = { mesh = "rbxassetid://75512449438234", texture = "rbxassetid://90286089750727", height = 4.4 },
	Frigorifero = { mesh = "rbxassetid://105414763045116", texture = "rbxassetid://130798338821834", height = 4.8 },
	Cactusso = { mesh = "rbxassetid://120133337676848", texture = "rbxassetid://121874024698948", height = 4.8 },
	Paperotto = { mesh = "rbxassetid://89213191235899", texture = "rbxassetid://98237085376983", height = 4 },
	Croissantonio = { mesh = "rbxassetid://130322345970102", texture = "rbxassetid://119922156913293", height = 3.6 },
	Pinguino = { mesh = "rbxassetid://128742424315404", texture = "rbxassetid://124297060270224", height = 4.4 },
	Ananasso = { mesh = "rbxassetid://139928747684402", texture = "rbxassetid://127061157122396", height = 4.6 },
	Gelatone = { mesh = "rbxassetid://130187111779992", texture = "rbxassetid://87775657216836", height = 5.6 },
	Lampadone = { mesh = "rbxassetid://137511675057984", texture = "rbxassetid://88806214571205", height = 5.4 },
	Tostapane = { mesh = "rbxassetid://130649834692675", texture = "rbxassetid://123080934606139", height = 3.2 },
	Lunetta = { mesh = "rbxassetid://123293042228956", texture = "rbxassetid://81716111138155", height = 4 },
	Burgerone = { mesh = "rbxassetid://139599393542690", texture = "rbxassetid://126009062909503", height = 4 },
	Spaghettus = { mesh = "rbxassetid://109583554631653", texture = "rbxassetid://78135252609290", height = 4.2 },
	Orologio = { mesh = "rbxassetid://115623033613362", texture = "rbxassetid://129473936281787", height = 3.8 },
	Mucca = { mesh = "rbxassetid://83954721907567", texture = "rbxassetid://76861507977353", height = 3.8 },
	ReCalzini = { mesh = "rbxassetid://111644668818366", texture = "rbxassetid://108207977282323", height = 4.6 },
	Furbetto = { mesh = "rbxassetid://79290989257305", texture = "rbxassetid://106115955836290", height = 7 },
}

BrainrotCatalog.BY_ID = {}
BrainrotCatalog.BY_RARITY = {}
BrainrotCatalog.RARITY_BY_ID = {}
BrainrotCatalog.MUTATION_BY_ID = {}

for _, rarity in BrainrotCatalog.RARITIES do
	BrainrotCatalog.RARITY_BY_ID[rarity.id] = rarity
	BrainrotCatalog.BY_RARITY[rarity.id] = {}
end
for _, mutation in BrainrotCatalog.MUTATIONS do
	BrainrotCatalog.MUTATION_BY_ID[mutation.id] = mutation
end
for _, def in BrainrotCatalog.CAST do
	BrainrotCatalog.BY_ID[def.id] = def
	table.insert(BrainrotCatalog.BY_RARITY[def.rarity], def)
end

-- Weighted pick of a key from { key = weight }.
local function pickWeighted(weights: { [string]: number }, rng: Random): string
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for key, weight in weights do
		roll -= weight
		if roll <= 0 then
			return key
		end
	end
	return next(weights) :: string
end

function BrainrotCatalog.rollRarity(weights: { [string]: number }, rng: Random): string
	return pickWeighted(weights, rng)
end

-- boost multiplies the chance of every mutation except None (Golden Hour uses it).
function BrainrotCatalog.rollMutation(rng: Random, boost: number?): string
	local weights = {}
	for _, mutation in BrainrotCatalog.MUTATIONS do
		if mutation.weight > 0 then
			weights[mutation.id] = if mutation.id == "None" then mutation.weight else mutation.weight * (boost or 1)
		end
	end
	return pickWeighted(weights, rng)
end

function BrainrotCatalog.pickOfRarity(rarityId: string, rng: Random)
	local pool = BrainrotCatalog.BY_RARITY[rarityId]
	return pool[rng:NextInteger(1, #pool)]
end

-- Cash per second of one brainrot with its mutation, before the owner's rebirth multiplier.
function BrainrotCatalog.incomeOf(id: string, mutationId: string): number
	return BrainrotCatalog.BY_ID[id].income * BrainrotCatalog.MUTATION_BY_ID[mutationId].mult
end

function BrainrotCatalog.priceOf(id: string, mutationId: string): number
	return BrainrotCatalog.BY_ID[id].price * BrainrotCatalog.MUTATION_BY_ID[mutationId].mult
end

return BrainrotCatalog
