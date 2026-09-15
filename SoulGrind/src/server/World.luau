-- Everything the player looks at. Split out of Main because the arena grew past the
-- point where world construction and the game loop belonged in one file.
--
-- Art direction: crimson and gold. Real materials lit by real firelight. Emissive
-- surfaces are rationed to flame cores, lava seams, gold sigils and the boss telegraph,
-- because the previous pass proved that neon on every surface reads as a white smear.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("SoulGrind").Config)

local World = {}
local palette = Config.Palette
local HALF = Config.ArenaHalf
local FLOOR_Y = 1.5

local signBoards = {}

local function makePart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.Slate
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function decor(parent, name, size, cframe, color, material)
	local part = makePart(parent, name, size, cframe, color, material)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

World.makePart = makePart

local function addLabel(part, text, color, height, maxDistance)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WorldLabel"
	billboard.Size = UDim2.fromOffset(320, 56)
	billboard.StudsOffset = Vector3.new(0, height or 5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = maxDistance or 700
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.05
	label.TextStrokeColor3 = Color3.fromRGB(12, 6, 8)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = billboard
	return label
end

-- Lighting ------------------------------------------------------------------
-- Tuned between two failures: a near-black map, and a whiteout caused by stacking
-- ambient, exposure, bloom and two dozen overlapping lights. The floor is bright
-- enough to silhouette an enemy; everything past the colonnade falls into shadow.
function World.applyLighting()
	Lighting.ClockTime = 1.6
	Lighting.GeographicLatitude = 24
	Lighting.Brightness = 1.7
	Lighting.ExposureCompensation = 0.05
	Lighting.Ambient = Color3.fromRGB(64, 52, 52)
	Lighting.OutdoorAmbient = Color3.fromRGB(76, 61, 58)
	Lighting.FogColor = Color3.fromRGB(38, 24, 26)
	Lighting.FogStart = 190
	Lighting.FogEnd = 1150
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.27
	atmosphere.Haze = 1.4
	atmosphere.Glare = 0.05
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(152, 112, 98)
	atmosphere.Decay = Color3.fromRGB(52, 26, 28)
	atmosphere.Parent = Lighting

	local function effect(className, name, properties)
		local instance = Lighting:FindFirstChild(name) or Instance.new(className)
		instance.Name = name
		for property, value in properties do instance[property] = value end
		instance.Parent = Lighting
	end

	effect("BloomEffect", "SoulBloom", { Intensity = 0.2, Size = 20, Threshold = 2.4 })
	effect("ColorCorrectionEffect", "UnderworldGrade", {
		Brightness = 0, Contrast = 0.15, Saturation = 0.02, TintColor = Color3.fromRGB(255, 240, 228),
	})
	-- Depth of field blurs the silhouettes the player needs. Removed on purpose.
	local staleDepth = Lighting:FindFirstChild("SoulDepth")
	if staleDepth then staleDepth:Destroy() end
end

-- Pieces --------------------------------------------------------------------

local function brazier(parent, position, accent)
	makePart(parent, "BrazierColumn", Vector3.new(2.4, 7, 2.4), CFrame.new(position + Vector3.new(0, 3.5, 0)), palette.Stone, Enum.Material.Marble)
	makePart(parent, "BrazierBowl", Vector3.new(4.4, 1.6, 4.4), CFrame.new(position + Vector3.new(0, 7.6, 0)), palette.Iron, Enum.Material.Metal)
	decor(parent, "BrazierRim", Vector3.new(5, 0.5, 5), CFrame.new(position + Vector3.new(0, 8.4, 0)), palette.Gold, Enum.Material.Metal)

	local flame = decor(parent, "BrazierFlame", Vector3.new(2.6, 2.6, 2.6), CFrame.new(position + Vector3.new(0, 9, 0)), palette.Ember, Enum.Material.Neon)
	flame.Shape = Enum.PartType.Ball

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 96)
	light.Brightness = 2.4
	light.Range = 48
	light.Shadows = true
	light.Parent = flame

	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(palette.GoldPale, accent)
	fire.LightEmission = 0.9
	fire.Lifetime = NumberRange.new(0.5, 0.9)
	fire.Rate = 30
	fire.Size = NumberSequence.new(3.4)
	fire.Speed = NumberRange.new(2, 5)
	fire.SpreadAngle = Vector2.new(16, 16)
	fire.Parent = flame
end

-- The colonnade is most of the reason the arena reads as a place rather than a pad.
local function pillar(parent, position, accent, height)
	height = height or 26
	makePart(parent, "PillarBase", Vector3.new(7, 2, 7), CFrame.new(position + Vector3.new(0, 1, 0)), palette.StoneDark, Enum.Material.Marble)
	makePart(parent, "PillarShaft", Vector3.new(5, height, 5), CFrame.new(position + Vector3.new(0, 2 + height / 2, 0)), palette.Stone, Enum.Material.Marble)
	decor(parent, "PillarBand", Vector3.new(5.4, 0.8, 5.4), CFrame.new(position + Vector3.new(0, 2 + height * 0.62, 0)), palette.Gold, Enum.Material.Metal)
	makePart(parent, "PillarCapital", Vector3.new(7.6, 2.4, 7.6), CFrame.new(position + Vector3.new(0, 3.2 + height, 0)), palette.StoneDark, Enum.Material.Marble)

	-- Crimson banner with a gold hem. Cloth reads as civilisation; bare rock does not.
	local banner = decor(parent, "Banner", Vector3.new(4.2, 13, 0.3), CFrame.new(position + Vector3.new(0, 2 + height * 0.5, -2.7)), accent, Enum.Material.Fabric)
	decor(parent, "BannerHem", Vector3.new(4.2, 0.7, 0.4), banner.CFrame * CFrame.new(0, -6.5, 0), palette.Gold, Enum.Material.Metal)
end

local function bonePile(parent, position)
	for index = 1, 5 do
		local angle = index * 1.27
		decor(parent, "Bone", Vector3.new(0.6, 3.2, 0.6),
			CFrame.new(position + Vector3.new(math.cos(angle) * 1.8, 1.2, math.sin(angle) * 1.8))
				* CFrame.Angles(math.rad(70 + index * 9), angle, 0),
			palette.Bone, Enum.Material.Marble)
	end
	local skull = decor(parent, "Skull", Vector3.new(1.6, 1.6, 1.6), CFrame.new(position + Vector3.new(0, 0.9, 0)), palette.Bone, Enum.Material.Marble)
	skull.Shape = Enum.PartType.Ball
end

-- A sign the player can actually read, and that rewrites itself as the quest changes.
local function signPost(parent, cframe, heading, body, accent)
	local post = makePart(parent, "SignPost", Vector3.new(1.2, 9, 1.2), cframe * CFrame.new(0, 4.5, 0), palette.Iron, Enum.Material.Metal)
	local board = makePart(parent, "SignBoard", Vector3.new(17, 9, 0.8), cframe * CFrame.new(0, 11, 0), palette.StoneDark, Enum.Material.Marble)
	decor(parent, "SignFrame", Vector3.new(18, 10, 0.5), cframe * CFrame.new(0, 11, 0.25), palette.Gold, Enum.Material.Metal)
	post.CanCollide = false

	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignFace"
	surface.Face = Enum.NormalId.Back
	surface.CanvasSize = Vector2.new(560, 300)
	surface.LightInfluence = 0.25
	surface.MaxDistance = 320
	surface.Parent = board

	local backing = Instance.new("Frame")
	backing.Size = UDim2.fromScale(1, 1)
	backing.BackgroundColor3 = Color3.fromRGB(26, 16, 18)
	backing.BackgroundTransparency = 0.15
	backing.BorderSizePixel = 0
	backing.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Heading"
	title.Size = UDim2.new(1, -30, 0, 74)
	title.Position = UDim2.fromOffset(15, 14)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = palette.GoldPale
	title.TextScaled = true
	title.Text = heading
	title.Parent = backing

	local rule = Instance.new("Frame")
	rule.Size = UDim2.new(1, -30, 0, 3)
	rule.Position = UDim2.fromOffset(15, 92)
	rule.BackgroundColor3 = palette.Gold
	rule.BorderSizePixel = 0
	rule.Parent = backing

	local detail = Instance.new("TextLabel")
	detail.Name = "Body"
	detail.Size = UDim2.new(1, -30, 1, -118)
	detail.Position = UDim2.fromOffset(15, 106)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.GothamMedium
	detail.TextColor3 = Color3.fromRGB(236, 222, 206)
	detail.TextSize = 30
	detail.TextWrapped = true
	detail.TextYAlignment = Enum.TextYAlignment.Top
	detail.Text = body
	detail.Parent = backing

	local lamp = Instance.new("PointLight")
	lamp.Color = palette.GoldLight
	lamp.Brightness = 1.2
	lamp.Range = 22
	lamp.Parent = board

	decor(parent, "SignGlow", Vector3.new(16, 0.4, 0.4), cframe * CFrame.new(0, 16.2, 0.4), palette.Gold, Enum.Material.Neon)
	addLabel(board, heading, palette.GoldPale, 8, 260)
	return { Heading = title, Body = detail, Board = board, Accent = accent }
end

-- Quest signs all show the same current objective, so wherever the player is standing
-- there is something nearby that answers "what am I supposed to be doing".
function World.registerQuestSign(entry)
	table.insert(signBoards, entry)
end

function World.setObjective(heading, body)
	for _, entry in signBoards do
		entry.Heading.Text = heading
		entry.Body.Text = body
		local label = entry.Board:FindFirstChild("WorldLabel")
		if label and label:FindFirstChildOfClass("TextLabel") then
			label:FindFirstChildOfClass("TextLabel").Text = heading
		end
	end
end

-- Backdrop ------------------------------------------------------------------
-- The old horizon was empty fog. A silhouette ring gives the sky something to cut
-- against, which is most of what "the background is ugly" actually meant.
local function buildBackdrop(parent, center)
	local folder = Instance.new("Folder")
	folder.Name = "Backdrop"
	folder.Parent = parent

	for index = 1, 26 do
		local angle = index * math.pi * 2 / 26
		local radius = 330 + (index % 4) * 46
		local height = 120 + (index % 5) * 74
		local position = center + Vector3.new(math.cos(angle) * radius, height / 2 - 20, math.sin(angle) * radius)
		local spire = decor(folder, "Spire", Vector3.new(26 + (index % 3) * 12, height, 26 + (index % 3) * 12),
			CFrame.new(position) * CFrame.Angles(math.rad((index % 3) - 1), angle, math.rad((index % 5) - 2)),
			index % 2 == 0 and palette.Rock or palette.Bedrock, Enum.Material.Basalt)
		spire.CastShadow = false
		if index % 4 == 0 then
			local seam = decor(folder, "SpireSeam", Vector3.new(2.4, height * 0.5, 2.4), spire.CFrame * CFrame.new(0, -height * 0.2, -14), palette.Crimson, Enum.Material.Neon)
			seam.Transparency = 0.35
			seam.CastShadow = false
		end
	end

	for index = 1, 18 do
		local angle = index * math.pi * 2 / 18 + 0.3
		local radius = 780 + (index % 3) * 180
		local height = 340 + (index % 4) * 150
		local ridge = decor(folder, "FarRidge", Vector3.new(230, height, 230),
			CFrame.new(center + Vector3.new(math.cos(angle) * radius, height / 2 - 90, math.sin(angle) * radius))
				* CFrame.Angles(0, angle, math.rad((index % 3) * 3)),
			palette.Bedrock, Enum.Material.Basalt)
		ridge.CastShadow = false
	end
end

-- Zone ----------------------------------------------------------------------

local function buildZone(zoneId, zone, world)
	local folder = Instance.new("Folder")
	folder.Name = zone.Name:gsub(" ", "")
	folder.Parent = world

	local origin = zone.Origin
	local accent, accentLight = zone.Accent, zone.AccentLight

	makePart(folder, "Bedrock", Vector3.new(HALF.X * 2 + 40, 12, HALF.Z * 2 + 40), CFrame.new(origin - Vector3.new(0, 6, 0)), palette.Bedrock, Enum.Material.Basalt)
	makePart(folder, "ArenaFloor", Vector3.new(HALF.X * 2, 3, HALF.Z * 2), CFrame.new(origin), zone.Floor, Enum.Material.Slate)

	-- Lighter paving bands give distance cues without a glowing grid.
	for band = -3, 3 do
		decor(folder, "Paving", Vector3.new(HALF.X * 2 - 24, 0.4, 16), CFrame.new(origin + Vector3.new(0, FLOOR_Y, band * 32)), zone.FloorAlt, Enum.Material.Concrete)
	end
	-- Lava seams: the only emissive thing on the ground, and they earn it.
	for seam = -2, 2 do
		local crack = decor(folder, "LavaSeam", Vector3.new(1.8, 0.35, HALF.Z * 1.7), CFrame.new(origin + Vector3.new(seam * 52 + 9, FLOOR_Y + 0.05, 0)) * CFrame.Angles(0, math.rad(seam * 3), 0), palette.CrimsonLit, Enum.Material.Neon)
		crack.Transparency = 0.25
		crack.CastShadow = false
	end

	-- Perimeter walls: the arena stops being a floating slab.
	for side = -1, 1, 2 do
		makePart(folder, "RampartX", Vector3.new(14, 42, HALF.Z * 2 + 28), CFrame.new(origin + Vector3.new(side * (HALF.X + 7), 19, 0)), palette.Rock, Enum.Material.Basalt)
		makePart(folder, "RampartZ", Vector3.new(HALF.X * 2 + 28, 42, 14), CFrame.new(origin + Vector3.new(0, 19, side * (HALF.Z + 7))), palette.Rock, Enum.Material.Basalt)
		decor(folder, "RampartCap", Vector3.new(16, 1.4, HALF.Z * 2 + 30), CFrame.new(origin + Vector3.new(side * (HALF.X + 7), 40.5, 0)), palette.Gold, Enum.Material.Metal)
	end

	-- Colonnade down both long sides.
	for index = -3, 3 do
		for side = -1, 1, 2 do
			pillar(folder, origin + Vector3.new(side * (HALF.X - 26), FLOOR_Y, index * 30), accent, 26 + (index % 2) * 5)
		end
	end

	-- Braziers: the arena's actual light. Five a side, evenly spaced.
	for index = -2, 2 do
		for side = -1, 1, 2 do
			brazier(folder, origin + Vector3.new(side * (HALF.X - 62), FLOOR_Y, index * 46), accentLight)
		end
	end

	-- Spawn plaza, raised and gold-rimmed so the entrance reads as the entrance.
	local plazaZ = HALF.Z - 22
	makePart(folder, "Plaza", Vector3.new(74, 2.4, 52), CFrame.new(origin + Vector3.new(0, FLOOR_Y + 1.2, plazaZ)), palette.Stone, Enum.Material.Marble)
	decor(folder, "PlazaTrim", Vector3.new(78, 0.7, 56), CFrame.new(origin + Vector3.new(0, FLOOR_Y + 2.4, plazaZ)), palette.Gold, Enum.Material.Metal)
	for side = -1, 1, 2 do
		pillar(folder, origin + Vector3.new(side * 30, FLOOR_Y + 2.4, plazaZ + 16), accent, 18)
		bonePile(folder, origin + Vector3.new(side * 54, FLOOR_Y, plazaZ - 30))
	end

	-- Central monument. Non-collidable: enemies steer with MoveTo and have no
	-- pathfinding, so a solid block in the middle of the arena is a trap.
	local base = origin + Vector3.new(0, FLOOR_Y, 0)
	decor(folder, "MonumentStep", Vector3.new(26, 1.4, 26), CFrame.new(base + Vector3.new(0, 0.7, 0)), palette.Stone, Enum.Material.Marble)
	decor(folder, "MonumentPlinth", Vector3.new(18, 3, 18), CFrame.new(base + Vector3.new(0, 2.9, 0)), palette.StoneDark, Enum.Material.Marble)
	decor(folder, "MonumentShaft", Vector3.new(9, 54, 9), CFrame.new(base + Vector3.new(0, 31, 0)), palette.Rock, Enum.Material.Basalt)
	for ring = 1, 4 do
		decor(folder, "MonumentSigil", Vector3.new(9.6, 1.1, 9.6), CFrame.new(base + Vector3.new(0, 10 + ring * 11, 0)), palette.Gold, Enum.Material.Metal)
	end
	local heart = decor(folder, "MonumentHeart", Vector3.new(3, 40, 1.2), CFrame.new(base + Vector3.new(0, 30, -4.6)), accent, Enum.Material.Neon)
	heart.Transparency = 0.2
	local crown = decor(folder, "MonumentCrown", Vector3.new(7, 7, 7), CFrame.new(base + Vector3.new(0, 60, 0)), palette.Gold, Enum.Material.Metal)
	crown.Shape = Enum.PartType.Ball
	addLabel(crown, zone.Name:upper(), palette.GoldPale, 9, 900)

	-- Quest signage. One at the spawn plaza where the player lands, one mid-arena.
	World.registerQuestSign(signPost(folder, CFrame.new(origin + Vector3.new(0, FLOOR_Y + 2.4, plazaZ - 22)), "OBJECTIVE", "Loading your charge...", accent))
	World.registerQuestSign(signPost(folder, CFrame.new(origin + Vector3.new(-46, FLOOR_Y, -8)) * CFrame.Angles(0, math.rad(34), 0), "OBJECTIVE", "Loading your charge...", accent))

	return folder, plazaZ
end

-- Gates ---------------------------------------------------------------------

local function archway(parent, position, accent, title)
	makePart(parent, "GatePillar", Vector3.new(9, 34, 10), CFrame.new(position + Vector3.new(-15, 17, 0)), palette.StoneDark, Enum.Material.Marble)
	makePart(parent, "GatePillar", Vector3.new(9, 34, 10), CFrame.new(position + Vector3.new(15, 17, 0)), palette.StoneDark, Enum.Material.Marble)
	makePart(parent, "GateLintel", Vector3.new(42, 8, 10), CFrame.new(position + Vector3.new(0, 36, 0)), palette.Rock, Enum.Material.Basalt)
	decor(parent, "GateTrim", Vector3.new(44, 1.6, 11), CFrame.new(position + Vector3.new(0, 40.4, 0)), palette.Gold, Enum.Material.Metal)
	for side = -1, 1, 2 do
		decor(parent, "GateSigil", Vector3.new(1.4, 22, 1.4), CFrame.new(position + Vector3.new(side * 15, 18, -5.2)), palette.Gold, Enum.Material.Neon)
	end

	local veil = decor(parent, "GateVeil", Vector3.new(28, 30, 1), CFrame.new(position + Vector3.new(0, 17, 0)), accent, Enum.Material.ForceField)
	veil.Transparency = 0.3

	local light = Instance.new("PointLight")
	light.Color = accent
	light.Brightness = 2.2
	light.Range = 46
	light.Parent = veil

	addLabel(veil, title, palette.GoldPale, 19, 900)
	return veil
end

-- Build ---------------------------------------------------------------------

function World.build()
	local existing = Workspace:FindFirstChild("SoulGrindWorld")
	if existing then existing:Destroy() end
	table.clear(signBoards)

	local world = Instance.new("Folder")
	world.Name = "SoulGrindWorld"
	world.Parent = Workspace

	World.applyLighting()

	local plazaZ
	for zoneId, zone in Config.Zones do
		local _, z = buildZone(zoneId, zone, world)
		plazaZ = plazaZ or z
	end

	buildBackdrop(world, (Config.Zones[1].Origin + Config.Zones[2].Origin) / 2)

	local zoneOne, zoneTwo = Config.Zones[1], Config.Zones[2]
	local spawnPosition = zoneOne.Origin + Vector3.new(0, FLOOR_Y + 3.6, plazaZ)

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "UnderworldSpawn"
	spawnPad.Size = Vector3.new(16, 1.2, 16)
	spawnPad.CFrame = CFrame.new(spawnPosition)
	spawnPad.Anchored = true
	spawnPad.Neutral = true
	spawnPad.Color = palette.Gold
	spawnPad.Material = Enum.Material.Metal
	spawnPad.Parent = world

	local gateVeil = archway(world, zoneOne.Origin + Vector3.new(0, FLOOR_Y, -HALF.Z + 16), zoneOne.Accent, "THE ASH GATE   •   150 SOULS")
	local gatePrompt = Instance.new("ProximityPrompt")
	gatePrompt.ActionText = "Open the Ash Gate"
	gatePrompt.ObjectText = "Molten Reliquary"
	gatePrompt.HoldDuration = 0.4
	gatePrompt.MaxActivationDistance = 18
	gatePrompt.RequiresLineOfSight = false
	gatePrompt.Parent = gateVeil

	local returnVeil = archway(world, zoneTwo.Origin + Vector3.new(0, FLOOR_Y, HALF.Z - 16), zoneTwo.Accent, "RETURN TO CINDER HOLLOW")
	local returnPrompt = Instance.new("ProximityPrompt")
	returnPrompt.ActionText = "Return"
	returnPrompt.ObjectText = "Cinder Hollow"
	returnPrompt.HoldDuration = 0.25
	returnPrompt.MaxActivationDistance = 18
	returnPrompt.RequiresLineOfSight = false
	returnPrompt.Parent = returnVeil

	return {
		Folder = world,
		GatePrompt = gatePrompt,
		ReturnPrompt = returnPrompt,
		PlazaZ = plazaZ,
		FloorY = FLOOR_Y,
	}
end

-- Enemy posts. Spread across the bigger arena so the map has fights in it rather
-- than one clump by the spawn.
function World.posts(zoneId)
	local list = {
		Vector3.new(0, FLOOR_Y, 52),
		Vector3.new(-46, FLOOR_Y, 30),
		Vector3.new(48, FLOOR_Y, 26),
		Vector3.new(-82, FLOOR_Y, -12),
		Vector3.new(78, FLOOR_Y, -18),
		Vector3.new(-26, FLOOR_Y, -46),
		Vector3.new(30, FLOOR_Y, -54),
		Vector3.new(-60, FLOOR_Y, -80),
		Vector3.new(0, FLOOR_Y, -86),
	}
	local origin = Config.Zones[zoneId].Origin
	local out = {}
	for index, offset in list do out[index] = origin + offset end
	return out
end

World.spawnCFrame = function()
	return CFrame.new(Config.Zones[1].Origin + Vector3.new(0, FLOOR_Y + 6, HALF.Z - 22))
end

World.arrivalCFrame = function(zoneId)
	return CFrame.new(Config.Zones[zoneId].Origin + Vector3.new(0, FLOOR_Y + 6, HALF.Z - 22))
end

return World
