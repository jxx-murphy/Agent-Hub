-- Everything the player looks at.
--
-- Art direction: a dark medieval kingdom. Zone 1 is a walled village gone to ruin,
-- zone 2 is the keep behind its gate. Original geometry in that genre, built from
-- parametric pieces (walls, towers, houses, roofs) rather than one authored blob.
--
-- Two rules drive the layout:
--   1. Nothing glows that is not fire. Stone is stone; light comes from lamps.
--   2. You must not be able to see the whole map from the gate. Buildings break the
--      sightlines, the wall hides the outside, and the fog closes in at 70 studs.

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
	part.CastShadow = false
	return part
end

World.makePart = makePart

local function addLabel(part, text, color, height, maxDistance)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WorldLabel"
	billboard.Size = UDim2.fromOffset(240, 44)
	billboard.StudsOffset = Vector3.new(0, height or 5, 0)
	billboard.AlwaysOnTop = false
	-- Deliberately short. Labels visible across the whole map were most of the reason
	-- every location was known before the player had walked anywhere.
	billboard.MaxDistance = maxDistance or 90
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.05
	label.TextStrokeColor3 = Color3.fromRGB(10, 6, 8)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = billboard
	return label
end

-- Lighting ------------------------------------------------------------------
function World.applyLighting()
	Lighting.ClockTime = 0.2
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 1.6
	Lighting.ExposureCompensation = 0.05
	Lighting.Ambient = Color3.fromRGB(58, 48, 50)
	Lighting.OutdoorAmbient = Color3.fromRGB(68, 56, 58)
	Lighting.FogColor = Color3.fromRGB(26, 18, 22)
	-- The map reveals itself as you walk into it.
	Lighting.FogStart = 70
	Lighting.FogEnd = 300
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.15
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.34
	atmosphere.Haze = 2.2
	atmosphere.Glare = 0.04
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(128, 96, 92)
	atmosphere.Decay = Color3.fromRGB(40, 24, 28)
	atmosphere.Parent = Lighting

	local function effect(className, name, properties)
		local instance = Lighting:FindFirstChild(name) or Instance.new(className)
		instance.Name = name
		for property, value in properties do instance[property] = value end
		instance.Parent = Lighting
	end

	effect("BloomEffect", "SoulBloom", { Intensity = 0.18, Size = 18, Threshold = 2.5 })
	effect("ColorCorrectionEffect", "UnderworldGrade", {
		Brightness = 0, Contrast = 0.14, Saturation = -0.02, TintColor = Color3.fromRGB(255, 242, 232),
	})
	local staleDepth = Lighting:FindFirstChild("SoulDepth")
	if staleDepth then staleDepth:Destroy() end
end

-- Pieces --------------------------------------------------------------------

local function lamp(parent, position, height)
	height = height or 9
	makePart(parent, "LampPost", Vector3.new(0.7, height, 0.7), CFrame.new(position + Vector3.new(0, height / 2, 0)), palette.Iron, Enum.Material.Metal)
	decor(parent, "LampArm", Vector3.new(2.2, 0.4, 0.4), CFrame.new(position + Vector3.new(0.8, height, 0)), palette.Iron, Enum.Material.Metal)
	local cage = decor(parent, "LampCage", Vector3.new(1.5, 2, 1.5), CFrame.new(position + Vector3.new(1.6, height - 1, 0)), palette.Iron, Enum.Material.Metal)
	cage.Transparency = 0.5
	local flame = decor(parent, "LampFlame", Vector3.new(0.9, 1.1, 0.9), cage.CFrame, palette.Ember, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 176, 104)
	light.Brightness = 1.9
	light.Range = 34
	light.Shadows = false
	light.Parent = flame
end

local function brazier(parent, position)
	makePart(parent, "BrazierColumn", Vector3.new(1.8, 4.5, 1.8), CFrame.new(position + Vector3.new(0, 2.25, 0)), palette.StoneDark, Enum.Material.Marble)
	makePart(parent, "BrazierBowl", Vector3.new(3.4, 1.3, 3.4), CFrame.new(position + Vector3.new(0, 5.1, 0)), palette.Iron, Enum.Material.Metal)
	local flame = decor(parent, "BrazierFlame", Vector3.new(2.2, 2.2, 2.2), CFrame.new(position + Vector3.new(0, 6.3, 0)), palette.Ember, Enum.Material.Neon)
	flame.Shape = Enum.PartType.Ball

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 166, 92)
	light.Brightness = 2.3
	light.Range = 42
	light.Shadows = true
	light.Parent = flame

	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(palette.GoldPale, palette.CrimsonMid)
	fire.LightEmission = 0.9
	fire.Lifetime = NumberRange.new(0.45, 0.85)
	fire.Rate = 26
	fire.Size = NumberSequence.new(3)
	fire.Speed = NumberRange.new(2, 4)
	fire.SpreadAngle = Vector2.new(14, 14)
	fire.Parent = flame
end

-- A wall run with real battlements. Merlons are what make stone read as fortification.
local function wallRun(parent, from, to, height, thickness)
	height = height or 22
	thickness = thickness or 6
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then return end
	local mid = from + delta * 0.5
	local angle = math.atan2(delta.X, delta.Z)
	local cf = CFrame.new(mid + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, angle, 0)

	makePart(parent, "CurtainWall", Vector3.new(thickness, height, length), cf, palette.Rock, Enum.Material.Brick)
	decor(parent, "WallLedge", Vector3.new(thickness + 1.6, 1, length), cf * CFrame.new(0, height / 2 - 0.5, 0), palette.StoneDark, Enum.Material.Marble)

	local merlons = math.max(2, math.floor(length / 7))
	for index = 0, merlons do
		local along = -length / 2 + index * (length / merlons)
		decor(parent, "Merlon", Vector3.new(thickness, 3.4, 3), cf * CFrame.new(0, height / 2 + 1.7, along), palette.Rock, Enum.Material.Brick)
	end
end

local function tower(parent, position, width, height, withRoof)
	width = width or 14
	height = height or 34
	makePart(parent, "TowerBase", Vector3.new(width + 3, 3, width + 3), CFrame.new(position + Vector3.new(0, 1.5, 0)), palette.StoneDark, Enum.Material.Marble)
	makePart(parent, "TowerShaft", Vector3.new(width, height, width), CFrame.new(position + Vector3.new(0, height / 2 + 2, 0)), palette.Rock, Enum.Material.Brick)
	decor(parent, "TowerBand", Vector3.new(width + 1.6, 1.2, width + 1.6), CFrame.new(position + Vector3.new(0, height * 0.62, 0)), palette.StoneDark, Enum.Material.Marble)
	decor(parent, "TowerCrown", Vector3.new(width + 3, 1.6, width + 3), CFrame.new(position + Vector3.new(0, height + 2.8, 0)), palette.StoneDark, Enum.Material.Marble)

	for side = 0, 3 do
		local angle = side * math.pi / 2
		local offset = Vector3.new(math.sin(angle) * (width / 2), height + 5, math.cos(angle) * (width / 2))
		decor(parent, "Merlon", Vector3.new(width * 0.9, 3, 2.4), CFrame.new(position + offset) * CFrame.Angles(0, angle, 0), palette.Rock, Enum.Material.Brick)
	end

	if withRoof then
		for tier = 1, 5 do
			local scale = (width + 4) * (1 - tier / 6)
			decor(parent, "TowerRoof", Vector3.new(scale, 2.6, scale), CFrame.new(position + Vector3.new(0, height + 5 + tier * 2.4, 0)), palette.CrimsonDeep, Enum.Material.Slate)
		end
	end

	-- Arrow slits read as windows without needing glass.
	for side = -1, 1, 2 do
		decor(parent, "ArrowSlit", Vector3.new(0.8, 4, 0.5), CFrame.new(position + Vector3.new(side * (width / 2 + 0.1), height * 0.55, 0)), Color3.fromRGB(16, 10, 12), Enum.Material.Slate)
	end
	return position + Vector3.new(0, height + 2, 0)
end

-- Timber-framed house: stone base, plaster upper, pitched roof, door, shutters.
local function house(parent, cf, width, depth, height, ruined)
	width = width or 18
	depth = depth or 16
	height = height or 14

	makePart(parent, "HouseBase", Vector3.new(width, 4, depth), cf * CFrame.new(0, 2, 0), palette.Rock, Enum.Material.Cobblestone)
	local body = makePart(parent, "HouseWall", Vector3.new(width - 1, height, depth - 1), cf * CFrame.new(0, 4 + height / 2, 0), palette.Plaster, Enum.Material.Concrete)

	-- Timber framing.
	for index = -1, 1 do
		decor(parent, "Timber", Vector3.new(0.8, height, 0.6), cf * CFrame.new(index * (width / 3), 4 + height / 2, depth / 2 - 0.3), palette.Timber, Enum.Material.WoodPlanks)
		decor(parent, "Timber", Vector3.new(0.8, height, 0.6), cf * CFrame.new(index * (width / 3), 4 + height / 2, -depth / 2 + 0.3), palette.Timber, Enum.Material.WoodPlanks)
	end
	decor(parent, "Timber", Vector3.new(width - 1, 0.9, 0.6), cf * CFrame.new(0, 4 + height, depth / 2 - 0.3), palette.Timber, Enum.Material.WoodPlanks)

	-- Door and shuttered windows.
	decor(parent, "Door", Vector3.new(4, 7, 0.5), cf * CFrame.new(0, 7.5, depth / 2 - 0.2), palette.Timber, Enum.Material.WoodPlanks)
	decor(parent, "DoorFrame", Vector3.new(5, 8, 0.4), cf * CFrame.new(0, 7.8, depth / 2 - 0.45), palette.StoneDark, Enum.Material.Marble)
	for side = -1, 1, 2 do
		decor(parent, "Window", Vector3.new(3.4, 3.4, 0.4), cf * CFrame.new(side * (width / 4), 4 + height * 0.68, depth / 2 - 0.2), Color3.fromRGB(18, 12, 14), Enum.Material.Slate)
		decor(parent, "Shutter", Vector3.new(1.6, 3.6, 0.35), cf * CFrame.new(side * (width / 4) + 2.2, 4 + height * 0.68, depth / 2 - 0.35), palette.Timber, Enum.Material.WoodPlanks)
	end

	-- Pitched roof from stacked slabs.
	local tiers = 6
	for tier = 1, tiers do
		local shrink = (tier - 1) / tiers
		decor(parent, "Roof", Vector3.new(width + 2 - shrink * (width - 2), 1.8, depth + 2), cf * CFrame.new(0, 4 + height + tier * 1.5, 0), palette.Roof, Enum.Material.Slate)
	end
	decor(parent, "RoofRidge", Vector3.new(2, 1, depth + 2.4), cf * CFrame.new(0, 4 + height + tiers * 1.5 + 0.9, 0), palette.StoneDark, Enum.Material.Marble)

	local chimney = makePart(parent, "Chimney", Vector3.new(3, 12, 3), cf * CFrame.new(width / 2 - 3, 4 + height + 6, -depth / 4), palette.Rock, Enum.Material.Brick)
	chimney.CanCollide = false

	if ruined then
		-- Knock a corner out so the village reads as fallen, not merely empty.
		body.Transparency = 0.02
		decor(parent, "Rubble", Vector3.new(6, 5, 6), cf * CFrame.new(width / 2 - 2, 2.5, -depth / 2 + 2) * CFrame.Angles(0.2, 0.5, 0.3), palette.Rock, Enum.Material.Cobblestone)
		decor(parent, "Rubble", Vector3.new(4, 3.5, 4), cf * CFrame.new(width / 2 + 3, 1.8, -depth / 2 - 1) * CFrame.Angles(0.4, 0.2, 0.1), palette.StoneDark, Enum.Material.Cobblestone)
	end
end

local function marketStall(parent, cf)
	makePart(parent, "StallCounter", Vector3.new(10, 3.5, 4), cf * CFrame.new(0, 1.75, 0), palette.Timber, Enum.Material.WoodPlanks)
	for side = -1, 1, 2 do
		makePart(parent, "StallPost", Vector3.new(0.7, 9, 0.7), cf * CFrame.new(side * 4.6, 4.5, 0), palette.Timber, Enum.Material.WoodPlanks)
	end
	decor(parent, "StallAwning", Vector3.new(12, 0.6, 7), cf * CFrame.new(0, 9.2, 1.4) * CFrame.Angles(math.rad(-12), 0, 0), palette.CrimsonMid, Enum.Material.Fabric)
	decor(parent, "StallTrim", Vector3.new(12, 0.5, 0.5), cf * CFrame.new(0, 8.6, 4.6), palette.Gold, Enum.Material.Metal)
end

local function props(parent, position, count)
	for index = 1, count or 3 do
		local angle = index * 2.3
		local offset = Vector3.new(math.cos(angle) * 3.2, 0, math.sin(angle) * 3.2)
		if index % 2 == 0 then
			local barrel = makePart(parent, "Barrel", Vector3.new(3, 4, 3), CFrame.new(position + offset + Vector3.new(0, 2, 0)), palette.Timber, Enum.Material.WoodPlanks)
			barrel.Shape = Enum.PartType.Cylinder
			barrel.CFrame = CFrame.new(position + offset + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			decor(parent, "BarrelBand", Vector3.new(3.2, 0.4, 3.2), CFrame.new(position + offset + Vector3.new(0, 2, 0)), palette.Iron, Enum.Material.Metal)
		else
			makePart(parent, "Crate", Vector3.new(3.4, 3.4, 3.4), CFrame.new(position + offset + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, index * 0.4, 0), palette.Timber, Enum.Material.WoodPlanks)
		end
	end
end

local function well(parent, position)
	makePart(parent, "WellRing", Vector3.new(9, 4, 9), CFrame.new(position + Vector3.new(0, 2, 0)), palette.Rock, Enum.Material.Cobblestone)
	decor(parent, "WellWater", Vector3.new(7, 0.4, 7), CFrame.new(position + Vector3.new(0, 3.6, 0)), Color3.fromRGB(20, 16, 20), Enum.Material.Slate)
	for side = -1, 1, 2 do
		makePart(parent, "WellPost", Vector3.new(0.8, 9, 0.8), CFrame.new(position + Vector3.new(side * 4, 8, 0)), palette.Timber, Enum.Material.WoodPlanks)
	end
	decor(parent, "WellBeam", Vector3.new(10, 0.9, 0.9), CFrame.new(position + Vector3.new(0, 12.4, 0)), palette.Timber, Enum.Material.WoodPlanks)
	decor(parent, "WellRoof", Vector3.new(11, 0.8, 8), CFrame.new(position + Vector3.new(0, 13.2, 0)), palette.Roof, Enum.Material.Slate)
	decor(parent, "WellBucket", Vector3.new(2, 2, 2), CFrame.new(position + Vector3.new(0, 9.6, 0)), palette.Timber, Enum.Material.WoodPlanks)
end

local function banner(parent, cf, height)
	decor(parent, "Banner", Vector3.new(5, height or 16, 0.3), cf, palette.CrimsonMid, Enum.Material.Fabric)
	decor(parent, "BannerHem", Vector3.new(5.2, 0.8, 0.45), cf * CFrame.new(0, -(height or 16) / 2, 0), palette.Gold, Enum.Material.Metal)
	decor(parent, "BannerRod", Vector3.new(6, 0.5, 0.5), cf * CFrame.new(0, (height or 16) / 2 + 0.4, 0), palette.Iron, Enum.Material.Metal)
end

local function cobbleRoad(parent, from, to, width)
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then return end
	local mid = from + delta * 0.5
	local angle = math.atan2(delta.X, delta.Z)
	decor(parent, "Cobble", Vector3.new(width or 22, 0.5, length), CFrame.new(mid + Vector3.new(0, FLOOR_Y, 0)) * CFrame.Angles(0, angle, 0), palette.Cobble, Enum.Material.Cobblestone)
	for side = -1, 1, 2 do
		decor(parent, "Kerb", Vector3.new(1.6, 1, length), CFrame.new(mid + Vector3.new(0, FLOOR_Y + 0.3, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(side * ((width or 22) / 2), 0, 0), palette.StoneDark, Enum.Material.Cobblestone)
	end
end

-- The sign the whole quest system writes to.
local function signPost(parent, cframe, heading, body)
	makePart(parent, "SignPost", Vector3.new(1.4, 10, 1.4), cframe * CFrame.new(0, 5, 0), palette.Timber, Enum.Material.WoodPlanks)
	local board = makePart(parent, "SignBoard", Vector3.new(20, 11, 1), cframe * CFrame.new(0, 13, 0), palette.Timber, Enum.Material.WoodPlanks)
	decor(parent, "SignFrame", Vector3.new(21.4, 12.4, 0.6), cframe * CFrame.new(0, 13, -0.3), palette.Iron, Enum.Material.Metal)

	-- Both faces carry the text, so the sign reads from either side of the road.
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Name = "SignFace"
		surface.Face = face
		surface.CanvasSize = Vector2.new(640, 352)
		-- Zero light influence: in a night map, a lit SurfaceGui is an unreadable one.
		surface.LightInfluence = 0
		surface.MaxDistance = 260
		surface.Parent = board

		local backing = Instance.new("Frame")
		backing.Size = UDim2.fromScale(1, 1)
		backing.BackgroundColor3 = Color3.fromRGB(24, 15, 16)
		backing.BorderSizePixel = 0
		backing.Parent = surface

		local edge = Instance.new("UIStroke")
		edge.Color = palette.Gold
		edge.Thickness = 5
		edge.Parent = backing

		local title = Instance.new("TextLabel")
		title.Name = "Heading"
		title.Size = UDim2.new(1, -40, 0, 84)
		title.Position = UDim2.fromOffset(20, 18)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.TextColor3 = palette.GoldPale
		title.TextScaled = true
		title.Text = heading
		title.Parent = backing

		local rule = Instance.new("Frame")
		rule.Size = UDim2.new(1, -40, 0, 4)
		rule.Position = UDim2.fromOffset(20, 108)
		rule.BackgroundColor3 = palette.Gold
		rule.BorderSizePixel = 0
		rule.Parent = backing

		local detail = Instance.new("TextLabel")
		detail.Name = "Body"
		detail.Size = UDim2.new(1, -40, 1, -136)
		detail.Position = UDim2.fromOffset(20, 124)
		detail.BackgroundTransparency = 1
		detail.Font = Enum.Font.GothamMedium
		detail.TextColor3 = Color3.fromRGB(240, 228, 212)
		detail.TextSize = 34
		detail.TextWrapped = true
		detail.TextYAlignment = Enum.TextYAlignment.Top
		detail.Text = body
		detail.Parent = backing

		table.insert(signBoards, { Heading = title, Body = detail, Board = board })
	end

	local lantern = decor(parent, "SignLantern", Vector3.new(1.4, 1.8, 1.4), cframe * CFrame.new(0, 19.6, 0), palette.Ember, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 120)
	light.Brightness = 1.6
	light.Range = 26
	light.Parent = lantern
end

function World.setObjective(heading, body)
	for _, entry in signBoards do
		entry.Heading.Text = heading
		entry.Body.Text = body
	end
end

-- Backdrop: a far ridge only. The old spire ring put scenery everywhere and was part
-- of why the whole map was legible from the spawn.
local function buildBackdrop(parent, center)
	local folder = Instance.new("Folder")
	folder.Name = "Backdrop"
	folder.Parent = parent
	for index = 1, 20 do
		local angle = index * math.pi * 2 / 20
		local radius = 900 + (index % 3) * 220
		local height = 420 + (index % 5) * 190
		local ridge = decor(folder, "FarRidge", Vector3.new(300, height, 300),
			CFrame.new(center + Vector3.new(math.cos(angle) * radius, height / 2 - 140, math.sin(angle) * radius))
				* CFrame.Angles(0, angle, math.rad((index % 3) * 4)),
			palette.Bedrock, Enum.Material.Basalt)
		ridge.CastShadow = false
	end
end

-- Zone 1: the village ---------------------------------------------------------

local function buildVillage(zone, world)
	local folder = Instance.new("Folder")
	folder.Name = "AshenfallVillage"
	folder.Parent = world
	local origin = zone.Origin

	makePart(folder, "Bedrock", Vector3.new(HALF.X * 2 + 60, 14, HALF.Z * 2 + 60), CFrame.new(origin - Vector3.new(0, 7, 0)), palette.Bedrock, Enum.Material.Basalt)
	makePart(folder, "ArenaFloor", Vector3.new(HALF.X * 2, 3, HALF.Z * 2), CFrame.new(origin), zone.Floor, Enum.Material.Ground)

	-- Main street running north from the gate, with a fork at the market.
	cobbleRoad(folder, origin + Vector3.new(0, 0, HALF.Z - 24), origin + Vector3.new(0, 0, -HALF.Z + 40), 24)
	cobbleRoad(folder, origin + Vector3.new(-HALF.X + 40, 0, 6), origin + Vector3.new(HALF.X - 40, 0, 6), 18)

	-- Curtain wall with corner and mid towers.
	local cx, cz = HALF.X - 6, HALF.Z - 6
	local corners = {
		origin + Vector3.new(-cx, FLOOR_Y, -cz), origin + Vector3.new(cx, FLOOR_Y, -cz),
		origin + Vector3.new(cx, FLOOR_Y, cz), origin + Vector3.new(-cx, FLOOR_Y, cz),
	}
	for index = 1, 4 do
		local from = corners[index]
		local to = corners[index % 4 + 1]
		-- Leave a gap in the south wall for the gatehouse.
		if index == 3 then
			wallRun(folder, from, origin + Vector3.new(22, FLOOR_Y, cz), 24, 7)
			wallRun(folder, origin + Vector3.new(-22, FLOOR_Y, cz), to, 24, 7)
		else
			wallRun(folder, from, to, 24, 7)
		end
		tower(folder, from, 16, 38, true)
	end
	tower(folder, origin + Vector3.new(-cx, FLOOR_Y, 0), 14, 32, true)
	tower(folder, origin + Vector3.new(cx, FLOOR_Y, 0), 14, 32, true)

	-- Gatehouse the player walks in through.
	local gatePos = origin + Vector3.new(0, FLOOR_Y, cz)
	for side = -1, 1, 2 do
		tower(folder, gatePos + Vector3.new(side * 22, 0, 0), 16, 40, true)
		banner(folder, CFrame.new(gatePos + Vector3.new(side * 22, 26, -8.2)), 18)
	end
	makePart(folder, "GateArch", Vector3.new(44, 10, 12), CFrame.new(gatePos + Vector3.new(0, 30, 0)), palette.Rock, Enum.Material.Brick)
	decor(folder, "GateTrim", Vector3.new(46, 1.6, 13), CFrame.new(gatePos + Vector3.new(0, 35.6, 0)), palette.Gold, Enum.Material.Metal)
	for bar = -3, 3 do
		decor(folder, "Portcullis", Vector3.new(0.7, 14, 0.7), CFrame.new(gatePos + Vector3.new(bar * 5, 22, 0)), palette.Iron, Enum.Material.Metal)
	end

	-- Houses down both sides of the street. Gaps between them are alleys, and they are
	-- what stops the market and the keep gate being visible from the entrance.
	local rows = { -1, 1 }
	for _, side in rows do
		for index = 0, 4 do
			local z = HALF.Z - 62 - index * 34
			local jitter = (index % 2) * 4
			house(folder, CFrame.new(origin + Vector3.new(side * (30 + jitter), FLOOR_Y, z)) * CFrame.Angles(0, side > 0 and math.pi or 0, 0),
				20 + (index % 3) * 3, 18, 13 + (index % 2) * 4, index % 3 == 0)
			if index % 2 == 0 then
				lamp(folder, origin + Vector3.new(side * 15, FLOOR_Y, z + 8))
			end
		end
	end

	-- Market square at the fork.
	local market = origin + Vector3.new(0, FLOOR_Y, 6)
	decor(folder, "Plaza", Vector3.new(76, 0.6, 62), CFrame.new(market + Vector3.new(0, 0.3, 0)), palette.Cobble, Enum.Material.Cobblestone)
	well(folder, market)
	for index = -1, 1 do
		marketStall(folder, CFrame.new(market + Vector3.new(index * 24, 0, -24)))
		props(folder, market + Vector3.new(index * 22, 0, 20), 4)
	end
	for side = -1, 1, 2 do
		brazier(folder, market + Vector3.new(side * 34, 0, 0))
	end

	-- Chapel off the west side, blacksmith off the east.
	local chapel = origin + Vector3.new(-72, FLOOR_Y, -40)
	house(folder, CFrame.new(chapel), 26, 34, 22, false)
	tower(folder, chapel + Vector3.new(0, 0, -22), 10, 46, true)
	banner(folder, CFrame.new(chapel + Vector3.new(0, 20, 17.4)), 14)

	local forge = origin + Vector3.new(74, FLOOR_Y, -36)
	house(folder, CFrame.new(forge) * CFrame.Angles(0, math.rad(180), 0), 24, 20, 14, false)
	local coals = decor(folder, "ForgeCoals", Vector3.new(6, 0.8, 5), CFrame.new(forge + Vector3.new(0, 1.2, 13)), palette.CrimsonLit, Enum.Material.Neon)
	local forgeLight = Instance.new("PointLight")
	forgeLight.Color = Color3.fromRGB(255, 120, 60)
	forgeLight.Brightness = 2.2
	forgeLight.Range = 30
	forgeLight.Parent = coals
	props(folder, forge + Vector3.new(-12, 0, 12), 3)

	-- Street lamps along the main road.
	for index = -2, 2 do
		for side = -1, 1, 2 do
			lamp(folder, origin + Vector3.new(side * 14, FLOOR_Y, index * 36 - 20))
		end
	end

	-- Colours hung along the inner wall faces. A walled town without banners reads as
	-- a quarry with a fence around it.
	for index = -2, 2 do
		banner(folder, CFrame.new(origin + Vector3.new(index * 46, 16, -cz + 4.2)), 14)
		banner(folder, CFrame.new(origin + Vector3.new(-cx + 4.2, 16, index * 40)) * CFrame.Angles(0, math.rad(90), 0), 14)
	end

	-- Signs: one inside the gatehouse, one in the market.
	signPost(folder, CFrame.new(origin + Vector3.new(-18, FLOOR_Y, cz - 26)), "OBJECTIVE", "Loading your charge...")
	signPost(folder, CFrame.new(market + Vector3.new(26, 0, 22)) * CFrame.Angles(0, math.rad(-35), 0), "OBJECTIVE", "Loading your charge...")

	return folder, cz
end

-- Zone 2: the keep ------------------------------------------------------------

local function buildKeep(zone, world)
	local folder = Instance.new("Folder")
	folder.Name = "BlackspireKeep"
	folder.Parent = world
	local origin = zone.Origin

	makePart(folder, "Bedrock", Vector3.new(HALF.X * 2 + 60, 14, HALF.Z * 2 + 60), CFrame.new(origin - Vector3.new(0, 7, 0)), palette.Bedrock, Enum.Material.Basalt)
	makePart(folder, "ArenaFloor", Vector3.new(HALF.X * 2, 3, HALF.Z * 2), CFrame.new(origin), zone.Floor, Enum.Material.Cobblestone)

	local cx, cz = HALF.X - 6, HALF.Z - 6
	local corners = {
		origin + Vector3.new(-cx, FLOOR_Y, -cz), origin + Vector3.new(cx, FLOOR_Y, -cz),
		origin + Vector3.new(cx, FLOOR_Y, cz), origin + Vector3.new(-cx, FLOOR_Y, cz),
	}
	for index = 1, 4 do
		local from = corners[index]
		local to = corners[index % 4 + 1]
		if index == 3 then
			wallRun(folder, from, origin + Vector3.new(20, FLOOR_Y, cz), 30, 8)
			wallRun(folder, origin + Vector3.new(-20, FLOOR_Y, cz), to, 30, 8)
		else
			wallRun(folder, from, to, 30, 8)
		end
		tower(folder, from, 18, 48, true)
	end

	cobbleRoad(folder, origin + Vector3.new(0, 0, cz - 10), origin + Vector3.new(0, 0, -40), 26)

	-- Inner bailey: barracks flanking the approach.
	for side = -1, 1, 2 do
		for index = 0, 2 do
			house(folder, CFrame.new(origin + Vector3.new(side * 46, FLOOR_Y, 60 - index * 38)) * CFrame.Angles(0, side > 0 and math.pi or 0, 0), 22, 26, 16, false)
		end
		lamp(folder, origin + Vector3.new(side * 18, FLOOR_Y, 40))
		lamp(folder, origin + Vector3.new(side * 18, FLOOR_Y, -4))
	end

	-- The keep itself, raised on a plinth at the north end.
	local keepPos = origin + Vector3.new(0, FLOOR_Y, -66)
	makePart(folder, "KeepPlinth", Vector3.new(120, 6, 76), CFrame.new(keepPos + Vector3.new(0, 3, 0)), palette.StoneDark, Enum.Material.Marble)
	for step = 1, 5 do
		makePart(folder, "KeepStair", Vector3.new(44, 1.4, 4), CFrame.new(keepPos + Vector3.new(0, step * 1.2, 40 - step * 3.4)), palette.Stone, Enum.Material.Marble)
	end
	makePart(folder, "KeepHall", Vector3.new(84, 46, 52), CFrame.new(keepPos + Vector3.new(0, 29, -8)), palette.Rock, Enum.Material.Brick)
	decor(folder, "KeepBand", Vector3.new(88, 2, 56), CFrame.new(keepPos + Vector3.new(0, 44, -8)), palette.StoneDark, Enum.Material.Marble)
	for tier = 1, 7 do
		decor(folder, "KeepRoof", Vector3.new(88 - tier * 10, 3, 56 - tier * 6), CFrame.new(keepPos + Vector3.new(0, 52 + tier * 2.6, -8)), palette.Roof, Enum.Material.Slate)
	end
	for side = -1, 1, 2 do
		tower(folder, keepPos + Vector3.new(side * 50, 6, -8), 20, 62, true)
		banner(folder, CFrame.new(keepPos + Vector3.new(side * 22, 30, 18.2)), 24)
	end
	decor(folder, "KeepDoor", Vector3.new(16, 22, 1), CFrame.new(keepPos + Vector3.new(0, 17, 18.2)), palette.Timber, Enum.Material.WoodPlanks)
	decor(folder, "KeepDoorTrim", Vector3.new(18, 24, 0.6), CFrame.new(keepPos + Vector3.new(0, 18, 18.5)), palette.Gold, Enum.Material.Metal)

	-- Boss ground, lit hard so the fight is readable.
	for side = -1, 1, 2 do
		brazier(folder, keepPos + Vector3.new(side * 32, 6, 26))
		brazier(folder, origin + Vector3.new(side * 30, 0, -10))
	end

	for index = -1, 1 do
		for side = -1, 1, 2 do
			banner(folder, CFrame.new(origin + Vector3.new(side * 34, 22, index * 38 + 20)), 18)
		end
	end

	signPost(folder, CFrame.new(origin + Vector3.new(-24, FLOOR_Y, cz - 26)), "OBJECTIVE", "Loading your charge...")
	signPost(folder, CFrame.new(origin + Vector3.new(26, FLOOR_Y, -18)) * CFrame.Angles(0, math.rad(30), 0), "OBJECTIVE", "Loading your charge...")

	return folder, cz
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

	local _, villageEdge = buildVillage(Config.Zones[1], world)
	buildKeep(Config.Zones[2], world)
	buildBackdrop(world, (Config.Zones[1].Origin + Config.Zones[2].Origin) / 2)

	local zoneOne, zoneTwo = Config.Zones[1], Config.Zones[2]
	local spawnPosition = zoneOne.Origin + Vector3.new(0, FLOOR_Y + 3, villageEdge - 30)

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "UnderworldSpawn"
	spawnPad.Size = Vector3.new(18, 1.2, 18)
	spawnPad.CFrame = CFrame.new(spawnPosition)
	spawnPad.Anchored = true
	spawnPad.Neutral = true
	spawnPad.Color = palette.Cobble
	spawnPad.Material = Enum.Material.Cobblestone
	spawnPad.Parent = world

	-- The Ash Gate at the far end of the village. You cannot see it from the spawn.
	local gatePosition = zoneOne.Origin + Vector3.new(0, FLOOR_Y, -HALF.Z + 26)
	local veil = makePart(world, "AshGate", Vector3.new(30, 34, 1.4), CFrame.new(gatePosition + Vector3.new(0, 18, 0)), zoneOne.Accent, Enum.Material.ForceField)
	veil.Transparency = 0.35
	veil.CanCollide = false
	for side = -1, 1, 2 do
		tower(world, gatePosition + Vector3.new(side * 24, 0, 0), 16, 44, true)
	end
	makePart(world, "AshGateLintel", Vector3.new(50, 10, 12), CFrame.new(gatePosition + Vector3.new(0, 38, 0)), palette.Rock, Enum.Material.Brick)
	addLabel(veil, "THE ASH GATE", palette.GoldPale, 22, 130)
	local gateLight = Instance.new("PointLight")
	gateLight.Color = zoneOne.Accent
	gateLight.Brightness = 2.2
	gateLight.Range = 40
	gateLight.Parent = veil

	local gatePrompt = Instance.new("ProximityPrompt")
	gatePrompt.ActionText = "Open the Ash Gate"
	gatePrompt.ObjectText = "Blackspire Keep"
	gatePrompt.HoldDuration = 0.4
	gatePrompt.MaxActivationDistance = 18
	gatePrompt.RequiresLineOfSight = false
	gatePrompt.Parent = veil

	local returnPosition = zoneTwo.Origin + Vector3.new(0, FLOOR_Y, HALF.Z - 26)
	local returnVeil = makePart(world, "ReturnGate", Vector3.new(30, 34, 1.4), CFrame.new(returnPosition + Vector3.new(0, 18, 0)), zoneTwo.Accent, Enum.Material.ForceField)
	returnVeil.Transparency = 0.35
	returnVeil.CanCollide = false
	addLabel(returnVeil, "BACK TO ASHENFALL", palette.GoldPale, 22, 130)
	local returnLight = Instance.new("PointLight")
	returnLight.Color = zoneTwo.Accent
	returnLight.Brightness = 2
	returnLight.Range = 36
	returnLight.Parent = returnVeil

	local returnPrompt = Instance.new("ProximityPrompt")
	returnPrompt.ActionText = "Return"
	returnPrompt.ObjectText = "Ashenfall Village"
	returnPrompt.HoldDuration = 0.25
	returnPrompt.MaxActivationDistance = 18
	returnPrompt.RequiresLineOfSight = false
	returnPrompt.Parent = returnVeil

	return {
		Folder = world,
		GatePrompt = gatePrompt,
		ReturnPrompt = returnPrompt,
		FloorY = FLOOR_Y,
	}
end

-- Enemy posts sit in the streets, the market and the bailey, never inside a building.
function World.posts(zoneId)
	local village = {
		Vector3.new(0, FLOOR_Y, 62), Vector3.new(-16, FLOOR_Y, 30), Vector3.new(18, FLOOR_Y, 34),
		Vector3.new(-30, FLOOR_Y, 6), Vector3.new(30, FLOOR_Y, 6), Vector3.new(0, FLOOR_Y, -24),
		Vector3.new(-56, FLOOR_Y, -44), Vector3.new(58, FLOOR_Y, -40), Vector3.new(0, FLOOR_Y, -66),
	}
	local keep = {
		Vector3.new(0, FLOOR_Y, 78), Vector3.new(-22, FLOOR_Y, 50), Vector3.new(22, FLOOR_Y, 48),
		Vector3.new(-24, FLOOR_Y, 10), Vector3.new(24, FLOOR_Y, 8), Vector3.new(0, FLOOR_Y, -14),
		Vector3.new(-30, FLOOR_Y, -34), Vector3.new(30, FLOOR_Y, -34), Vector3.new(0, FLOOR_Y, -44),
	}
	local list = zoneId == 2 and keep or village
	local origin = Config.Zones[zoneId].Origin
	local out = {}
	for index, offset in list do out[index] = origin + offset end
	return out
end

World.arrivalCFrame = function(zoneId)
	return CFrame.new(Config.Zones[zoneId].Origin + Vector3.new(0, FLOOR_Y + 6, HALF.Z - 30))
end

return World
