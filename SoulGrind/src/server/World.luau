-- Everything the player looks at.
--
-- Art direction: dark stylised anime. Cold charcoal/indigo world, warm fire accents,
-- heavy contrast, soft glow. Zone 1 is a fallen walled town, zone 2 the keep behind it.
--
-- On geometry: there is no Blender step here, so nothing is a .fbx MeshPart. Curvature
-- comes from Roblox's own smooth primitives instead - WedgePart and CornerWedgePart for
-- every roof and spire, SpecialMesh cylinders for towers and columns, spheres for caps.
-- Faceted low-poly is the target, not bevelled organic; a real mesh pipeline would need
-- Blender plus an asset upload.
--
-- Rules:
--   1. Structural surfaces are SmoothPlastic. No Concrete, Slate or Brick noise.
--   2. Glow is Glass/Neon at 0.6-0.85 transparency, never an opaque bright slab.
--   3. Small detail never casts a shadow; jagged shadow maps are what read as cheap.
--   4. You must not see the whole map from the gate.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("SoulGrind").Config)

local World = {}
local palette = Config.Palette
local HALF = Config.ArenaHalf
local FLOOR_Y = 1.5

local signBoards = {}

local function mix(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function shape(parent, className, name, size, cframe, color, material)
	local part = Instance.new(className)
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makePart(parent, name, size, cframe, color, material)
	return shape(parent, "Part", name, size, cframe, color, material)
end

-- Detail: no collision, no query, and crucially no shadow.
local function decor(parent, name, size, cframe, color, material)
	local part = makePart(parent, name, size, cframe, color, material)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function wedge(parent, name, size, cframe, color, material, solid)
	local part = shape(parent, "WedgePart", name, size, cframe, color, material)
	if not solid then
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
	end
	return part
end

local function cornerWedge(parent, name, size, cframe, color, material)
	local part = shape(parent, "CornerWedgePart", name, size, cframe, color, material)
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

-- A real cylinder, not a box pretending. SpecialMesh keeps the axis upright.
local function cylinder(parent, name, diameter, height, cframe, color, material, solid)
	local part = makePart(parent, name, Vector3.new(diameter, height, diameter), cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = part
	if not solid then
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
	end
	return part
end

local function sphere(parent, name, diameter, cframe, color, material)
	local part = makePart(parent, name, Vector3.new(diameter, diameter, diameter), cframe, color, material)
	part.Shape = Enum.PartType.Ball
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

-- Glow is always translucent. An opaque Neon slab is the whiteout mistake.
local function glow(parent, name, size, cframe, color, transparency, material)
	local part = decor(parent, name, size, cframe, color, material or Enum.Material.Neon)
	part.Transparency = transparency or 0.72
	return part
end

World.makePart = makePart

local function addLabel(part, text, color, height, maxDistance)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WorldLabel"
	billboard.Size = UDim2.fromOffset(240, 44)
	billboard.StudsOffset = Vector3.new(0, height or 5, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = maxDistance or 90
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.05
	label.TextStrokeColor3 = Color3.fromRGB(8, 6, 12)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = billboard
	return label
end

-- Lighting ------------------------------------------------------------------
-- Clear, not cloudy. Five separate things were adding haze and they are all off now:
-- distance fog, Atmosphere haze, Atmosphere glare, depth-of-field blur, and a bloom
-- threshold so low that every lit surface glowed. Visibility comes from ambient light
-- alone, which is what keeps the image crisp.

-- The only four values worth touching. Nudge EXPOSURE first: +0.1 is brighter,
-- -0.1 is darker, and it changes nothing else about the look.
local EXPOSURE = 0
local SUN = 1.8
local AMBIENT = Color3.fromRGB(78, 75, 88)
local OUTDOOR = Color3.fromRGB(92, 89, 104)

function World.applyLighting()
	Lighting.ClockTime = 6.6
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = SUN
	Lighting.ExposureCompensation = EXPOSURE
	Lighting.Ambient = AMBIENT
	Lighting.OutdoorAmbient = OUTDOOR
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true

	-- Fog pushed past the far ridge. Nothing in play is ever veiled.
	Lighting.FogColor = Color3.fromRGB(38, 34, 48)
	Lighting.FogStart = 4000
	Lighting.FogEnd = 100000

	-- Haze is the milky look, glare is the bloom-on-everything look. Both to zero.
	-- Density stays just above zero so the sky is not a flat plate.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.05
	atmosphere.Haze = 0
	atmosphere.Glare = 0
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(196, 192, 212)
	atmosphere.Decay = Color3.fromRGB(88, 82, 104)
	atmosphere.Parent = Lighting

	local function effect(className, name, properties)
		local instance = Lighting:FindFirstChild(name) or Instance.new(className)
		instance.Name = name
		for property, value in properties do instance[property] = value end
		instance.Parent = Lighting
	end

	-- Threshold raised well above 1 so only genuine emissives bloom: flames, runes,
	-- portals. At 0.9 every lit wall bloomed, and that haze read as fog.
	effect("BloomEffect", "SoulBloom", { Intensity = 0.25, Size = 16, Threshold = 1.9 })
	-- Near-neutral tint. The old near-black tint muddied every surface; the cool cast
	-- now comes from a slight blue lean, not from crushing the image.
	effect("ColorCorrectionEffect", "UnderworldGrade", {
		Contrast = 0.2, Saturation = -0.08, Brightness = 0, TintColor = Color3.fromRGB(228, 230, 246),
	})

	-- Depth of field is the other half of "cloudy". Gone.
	local staleDepth = Lighting:FindFirstChild("SoulDepth")
	if staleDepth then staleDepth:Destroy() end
end

-- Ambience ------------------------------------------------------------------

local function dust(parent, position, color, rate, size)
	local anchor = decor(parent, "DustAnchor", Vector3.new(1, 1, 1), CFrame.new(position), color, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color, mix(color, Color3.new(1, 1, 1), 0.6))
	emitter.LightEmission = 0.75
	emitter.Lifetime = NumberRange.new(4, 9)
	emitter.Rate = rate or 8
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-24, 24)
	emitter.Size = NumberSequence.new(size or 0.9)
	emitter.Speed = NumberRange.new(0.6, 2.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Transparency = NumberSequence.new(0.35)
	emitter.Parent = anchor
	return anchor
end

-- Ground sigil. Translucent neon ring, never an opaque disc.
local function runeCircle(parent, position, diameter, color)
	local ring = cylinder(parent, "RuneCircle", diameter, 0.25, CFrame.new(position + Vector3.new(0, 0.12, 0)), color, Enum.Material.Neon)
	ring.Transparency = 0.78
	local inner = cylinder(parent, "RuneInner", diameter * 0.6, 0.25, CFrame.new(position + Vector3.new(0, 0.16, 0)), color, Enum.Material.Neon)
	inner.Transparency = 0.86
	for index = 0, 5 do
		local angle = index * math.pi / 3
		local mark = glow(parent, "RuneMark", Vector3.new(1.1, 0.2, diameter * 0.34),
			CFrame.new(position + Vector3.new(math.cos(angle) * diameter * 0.34, 0.2, math.sin(angle) * diameter * 0.34)) * CFrame.Angles(0, -angle, 0),
			color, 0.7)
		mark.Material = Enum.Material.Neon
	end
end

-- Floating ruin fragments. No shadows, deliberately off-axis.
local function shards(parent, position, count, color)
	for index = 1, count or 6 do
		local angle = index * 1.9
		local radius = 6 + (index % 3) * 5
		local size = 1.6 + (index % 4) * 0.9
		local fragment = decor(parent, "SoulShard", Vector3.new(size, size * 1.6, size * 0.7),
			CFrame.new(position + Vector3.new(math.cos(angle) * radius, 6 + (index % 5) * 4, math.sin(angle) * radius))
				* CFrame.Angles(index * 0.7, angle, index * 0.4),
			color, Enum.Material.Glass)
		fragment.Transparency = 0.55
		fragment.Reflectance = 0.15
	end
end

-- Pieces --------------------------------------------------------------------

local function pitchedRoof(parent, cf, width, depth, height, color)
	-- Two wedges back to back. This one change is most of the "not blocky".
	for side = -1, 1, 2 do
		wedge(parent, "Roof", Vector3.new(depth, height, width / 2),
			cf * CFrame.new(side * width / 4, height / 2, 0) * CFrame.Angles(0, side > 0 and math.rad(90) or math.rad(-90), 0),
			color, Enum.Material.SmoothPlastic)
	end
	decor(parent, "RoofRidge", Vector3.new(1.2, 0.8, depth + 1), cf * CFrame.new(0, height, 0), mix(color, palette.Bone, 0.25))
end

local function pyramidSpire(parent, position, width, height, color)
	-- Four corner wedges make a clean faceted spire with no stair-stepping.
	for index = 0, 3 do
		local angle = index * math.pi / 2
		cornerWedge(parent, "SpireFace", Vector3.new(width / 2, height, width / 2),
			CFrame.new(position + Vector3.new(math.cos(angle) * width / 4, height / 2, math.sin(angle) * width / 4)) * CFrame.Angles(0, -angle, 0),
			color, Enum.Material.SmoothPlastic)
	end
	sphere(parent, "SpireFinial", width * 0.22, CFrame.new(position + Vector3.new(0, height + 1, 0)), palette.Gold, Enum.Material.SmoothPlastic)
end

local function roundTower(parent, position, diameter, height, accent)
	cylinder(parent, "TowerBase", diameter + 4, 3, CFrame.new(position + Vector3.new(0, 1.5, 0)), palette.StoneDark, Enum.Material.SmoothPlastic, true)
	-- Three stacked segments with a subtle vertical ramp instead of one flat colour.
	for tier = 0, 2 do
		local segment = height / 3
		cylinder(parent, "TowerShaft", diameter, segment,
			CFrame.new(position + Vector3.new(0, 3 + segment / 2 + tier * segment, 0)),
			mix(palette.Rock, palette.SlateLight, tier * 0.22), Enum.Material.SmoothPlastic, true)
	end
	cylinder(parent, "TowerBand", diameter + 2, 1.4, CFrame.new(position + Vector3.new(0, 3 + height * 0.62, 0)), palette.StoneDark)
	cylinder(parent, "TowerCrown", diameter + 3.4, 2.2, CFrame.new(position + Vector3.new(0, height + 4, 0)), palette.StoneDark)

	for index = 0, 7 do
		local angle = index * math.pi / 4
		decor(parent, "Merlon", Vector3.new(2.6, 3, 2.6),
			CFrame.new(position + Vector3.new(math.cos(angle) * (diameter / 2 + 1), height + 6.5, math.sin(angle) * (diameter / 2 + 1))) * CFrame.Angles(0, -angle, 0),
			palette.Rock)
	end
	pyramidSpire(parent, position + Vector3.new(0, height + 7.5, 0), diameter + 3, diameter * 1.5, palette.Roof)

	-- Arrow slits glow faintly from within.
	for index = 0, 3 do
		local angle = index * math.pi / 2
		glow(parent, "SlitGlow", Vector3.new(0.9, 4.5, 0.6),
			CFrame.new(position + Vector3.new(math.cos(angle) * (diameter / 2), height * 0.55, math.sin(angle) * (diameter / 2))) * CFrame.Angles(0, -angle, 0),
			accent or palette.Amber, 0.62)
	end
end

local function column(parent, position, diameter, height)
	cylinder(parent, "ColumnBase", diameter + 1.8, 1.6, CFrame.new(position + Vector3.new(0, 0.8, 0)), palette.StoneDark, Enum.Material.SmoothPlastic, true)
	cylinder(parent, "ColumnShaft", diameter, height, CFrame.new(position + Vector3.new(0, height / 2 + 1.6, 0)), palette.Stone, Enum.Material.SmoothPlastic, true)
	cylinder(parent, "ColumnCap", diameter + 2, 1.8, CFrame.new(position + Vector3.new(0, height + 2.4, 0)), palette.StoneDark)
	sphere(parent, "ColumnFinial", diameter * 0.7, CFrame.new(position + Vector3.new(0, height + 4, 0)), palette.SlateLight)
end

local function lamp(parent, position, height)
	height = height or 9
	cylinder(parent, "LampPost", 0.7, height, CFrame.new(position + Vector3.new(0, height / 2, 0)), palette.Iron, Enum.Material.SmoothPlastic, true)
	decor(parent, "LampArm", Vector3.new(2.2, 0.35, 0.35), CFrame.new(position + Vector3.new(0.9, height, 0)), palette.Iron)
	local cage = sphere(parent, "LampCage", 2.1, CFrame.new(position + Vector3.new(1.7, height - 0.9, 0)), palette.Amber, Enum.Material.Glass)
	cage.Transparency = 0.68
	cage.Reflectance = 0.1
	local flame = sphere(parent, "LampFlame", 1.1, cage.CFrame, palette.Amber, Enum.Material.Neon)
	flame.Transparency = 0.25

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 176, 104)
	light.Brightness = 1.9
	light.Range = 34
	light.Shadows = false
	light.Parent = flame
end

local function brazier(parent, position, accent)
	cylinder(parent, "BrazierColumn", 1.8, 4.5, CFrame.new(position + Vector3.new(0, 2.25, 0)), palette.StoneDark, Enum.Material.SmoothPlastic, true)
	cylinder(parent, "BrazierBowl", 3.6, 1.4, CFrame.new(position + Vector3.new(0, 5.1, 0)), palette.Iron, Enum.Material.SmoothPlastic, true)
	local flame = sphere(parent, "BrazierFlame", 2.4, CFrame.new(position + Vector3.new(0, 6.4, 0)), accent or palette.Ember, Enum.Material.Neon)
	flame.Transparency = 0.3

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 166, 92)
	light.Brightness = 2.3
	light.Range = 42
	light.Shadows = true
	light.Parent = flame

	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(palette.GoldPale, accent or palette.CrimsonMid)
	fire.LightEmission = 1
	fire.Lifetime = NumberRange.new(0.45, 0.85)
	fire.Rate = 26
	fire.Size = NumberSequence.new(3)
	fire.Speed = NumberRange.new(2, 4)
	fire.SpreadAngle = Vector2.new(14, 14)
	fire.Parent = flame
end

-- Wall with a vertical colour ramp, a smooth coping and wedge-capped merlons.
local function wallRun(parent, from, to, height, thickness)
	height = height or 22
	thickness = thickness or 6
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then return end
	local mid = from + delta * 0.5
	local angle = math.atan2(delta.X, delta.Z)
	local base = CFrame.new(mid) * CFrame.Angles(0, angle, 0)

	for tier = 0, 2 do
		local segment = height / 3
		local body = shape(parent, "Part", "CurtainWall", Vector3.new(thickness, segment, length),
			base * CFrame.new(0, segment / 2 + tier * segment, 0),
			mix(palette.Obsidian, palette.Slate, 0.25 + tier * 0.3), Enum.Material.SmoothPlastic)
		body.CastShadow = tier > 0
	end
	decor(parent, "WallCoping", Vector3.new(thickness + 1.8, 1, length), base * CFrame.new(0, height, 0), palette.SlateLight)

	local merlons = math.max(2, math.floor(length / 7))
	for index = 0, merlons do
		local along = -length / 2 + index * (length / merlons)
		local merlon = decor(parent, "Merlon", Vector3.new(thickness, 3, 2.8), base * CFrame.new(0, height + 2, along), palette.Slate)
		-- Wedge caps stop the battlements reading as a row of cubes.
		for side = -1, 1, 2 do
			wedge(parent, "MerlonCap", Vector3.new(2.8, 1.4, thickness / 2),
				base * CFrame.new(side * thickness / 4, height + 4.2, along) * CFrame.Angles(0, side > 0 and 0 or math.rad(180), 0),
				palette.SlateLight)
		end
		merlon.Name = "Merlon"
	end
end

local function house(parent, cf, width, depth, height, ruined)
	width = width or 18
	depth = depth or 16
	height = height or 14

	makePart(parent, "HouseBase", Vector3.new(width, 4, depth), cf * CFrame.new(0, 2, 0), palette.StoneDark)
	makePart(parent, "HouseWall", Vector3.new(width - 1, height, depth - 1), cf * CFrame.new(0, 4 + height / 2, 0), palette.Plaster)
	-- Upper storey slightly lighter: a hand-painted ramp rather than one flat tone.
	decor(parent, "HouseUpper", Vector3.new(width - 0.6, height * 0.4, depth - 0.6), cf * CFrame.new(0, 4 + height * 0.8, 0), mix(palette.Plaster, palette.SlateLight, 0.35))

	for index = -1, 1 do
		decor(parent, "Timber", Vector3.new(0.7, height, 0.5), cf * CFrame.new(index * (width / 3), 4 + height / 2, depth / 2 - 0.25), palette.Timber)
		decor(parent, "Timber", Vector3.new(0.7, height, 0.5), cf * CFrame.new(index * (width / 3), 4 + height / 2, -depth / 2 + 0.25), palette.Timber)
	end

	decor(parent, "Door", Vector3.new(4, 7, 0.4), cf * CFrame.new(0, 7.5, depth / 2 - 0.2), palette.Timber)
	wedge(parent, "DoorArch", Vector3.new(0.5, 2.2, 5), cf * CFrame.new(0, 11.2, depth / 2 - 0.2) * CFrame.Angles(0, math.rad(90), 0), palette.StoneDark)
	for side = -1, 1, 2 do
		-- Lit windows: warm glass, never a bright opaque square.
		local pane = decor(parent, "Window", Vector3.new(3.2, 3.2, 0.4), cf * CFrame.new(side * (width / 4), 4 + height * 0.68, depth / 2 - 0.2), palette.Amber, Enum.Material.Glass)
		pane.Transparency = 0.66
		decor(parent, "Shutter", Vector3.new(1.5, 3.4, 0.3), cf * CFrame.new(side * (width / 4) + 2.2, 4 + height * 0.68, depth / 2 - 0.35), palette.Timber)
	end

	pitchedRoof(parent, cf * CFrame.new(0, 4 + height, 0), width + 2.5, depth + 2.5, height * 0.62, palette.Roof)
	cylinder(parent, "Chimney", 2.6, 12, cf * CFrame.new(width / 2 - 3, 4 + height + 6, -depth / 4), palette.StoneDark)

	if ruined then
		for index = 1, 3 do
			decor(parent, "Rubble", Vector3.new(4 + index, 3 + index * 0.6, 4 + index),
				cf * CFrame.new(width / 2 - 1 + index, 2, -depth / 2 + index * 1.4) * CFrame.Angles(index * 0.3, index * 0.6, index * 0.2),
				mix(palette.Rock, palette.Charcoal, 0.3))
		end
	end
end

local function marketStall(parent, cf)
	makePart(parent, "StallCounter", Vector3.new(10, 3.5, 4), cf * CFrame.new(0, 1.75, 0), palette.Timber)
	for side = -1, 1, 2 do
		cylinder(parent, "StallPost", 0.7, 9, cf * CFrame.new(side * 4.6, 4.5, 0), palette.Timber, Enum.Material.SmoothPlastic, true)
	end
	for side = -1, 1, 2 do
		wedge(parent, "StallAwning", Vector3.new(7, 2.4, 6), cf * CFrame.new(side * 3, 9.6, 1.4) * CFrame.Angles(0, side > 0 and math.rad(90) or math.rad(-90), 0), palette.CrimsonMid)
	end
end

local function props(parent, position, count)
	for index = 1, count or 3 do
		local angle = index * 2.3
		local offset = Vector3.new(math.cos(angle) * 3.2, 0, math.sin(angle) * 3.2)
		if index % 2 == 0 then
			cylinder(parent, "Barrel", 3, 4, CFrame.new(position + offset + Vector3.new(0, 2, 0)), palette.Timber, Enum.Material.SmoothPlastic, true)
			cylinder(parent, "BarrelBand", 3.2, 0.4, CFrame.new(position + offset + Vector3.new(0, 2.6, 0)), palette.Iron)
		else
			makePart(parent, "Crate", Vector3.new(3.4, 3.4, 3.4), CFrame.new(position + offset + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, index * 0.4, 0), palette.Timber)
		end
	end
end

local function well(parent, position)
	cylinder(parent, "WellRing", 9, 4, CFrame.new(position + Vector3.new(0, 2, 0)), palette.Stone, Enum.Material.SmoothPlastic, true)
	local water = cylinder(parent, "WellWater", 7, 0.4, CFrame.new(position + Vector3.new(0, 3.7, 0)), palette.Indigo, Enum.Material.Glass)
	water.Transparency = 0.5
	water.Reflectance = 0.3
	for side = -1, 1, 2 do
		cylinder(parent, "WellPost", 0.8, 9, CFrame.new(position + Vector3.new(side * 4, 8, 0)), palette.Timber, Enum.Material.SmoothPlastic, true)
	end
	decor(parent, "WellBeam", Vector3.new(10, 0.8, 0.8), CFrame.new(position + Vector3.new(0, 12.4, 0)), palette.Timber)
	pitchedRoof(parent, CFrame.new(position + Vector3.new(0, 12.8, 0)), 11, 8, 4, palette.Roof)
end

local function banner(parent, cf, height)
	decor(parent, "Banner", Vector3.new(5, height or 16, 0.25), cf, palette.CrimsonMid, Enum.Material.SmoothPlastic)
	wedge(parent, "BannerTail", Vector3.new(0.3, 2.4, 5), cf * CFrame.new(0, -(height or 16) / 2 - 1.2, 0) * CFrame.Angles(0, math.rad(90), 0), palette.CrimsonMid)
	decor(parent, "BannerRod", Vector3.new(6, 0.4, 0.4), cf * CFrame.new(0, (height or 16) / 2 + 0.4, 0), palette.Iron)
end

local function cobbleRoad(parent, from, to, width)
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then return end
	local mid = from + delta * 0.5
	local angle = math.atan2(delta.X, delta.Z)
	local cf = CFrame.new(mid + Vector3.new(0, FLOOR_Y, 0)) * CFrame.Angles(0, angle, 0)
	decor(parent, "Cobble", Vector3.new(width or 22, 0.5, length), cf, palette.Cobble)
	for side = -1, 1, 2 do
		decor(parent, "Kerb", Vector3.new(1.4, 0.9, length), cf * CFrame.new(side * ((width or 22) / 2), 0.2, 0), palette.StoneDark)
	end
end

local function signPost(parent, cframe, heading, body)
	cylinder(parent, "SignPost", 1.4, 10, cframe * CFrame.new(0, 5, 0), palette.Timber, Enum.Material.SmoothPlastic, true)
	local board = makePart(parent, "SignBoard", Vector3.new(20, 11, 1), cframe * CFrame.new(0, 13, 0), palette.Timber)
	decor(parent, "SignFrame", Vector3.new(21.4, 12.4, 0.6), cframe * CFrame.new(0, 13, -0.3), palette.Iron)

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Name = "SignFace"
		surface.Face = face
		surface.CanvasSize = Vector2.new(640, 352)
		-- Zero light influence: on a night map a lit SurfaceGui is an unreadable one.
		surface.LightInfluence = 0
		surface.MaxDistance = 260
		surface.Parent = board

		local backing = Instance.new("Frame")
		backing.Size = UDim2.fromScale(1, 1)
		backing.BackgroundColor3 = Color3.fromRGB(20, 16, 26)
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
		detail.TextColor3 = Color3.fromRGB(238, 232, 244)
		detail.TextSize = 34
		detail.TextWrapped = true
		detail.TextYAlignment = Enum.TextYAlignment.Top
		detail.Text = body
		detail.Parent = backing

		table.insert(signBoards, { Heading = title, Body = detail, Board = board })
	end

	local lantern = sphere(parent, "SignLantern", 1.8, cframe * CFrame.new(0, 19.6, 0), palette.Amber, Enum.Material.Neon)
	lantern.Transparency = 0.3
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

-- Backdrop: faceted monoliths, softened by fog and depth of field.
local function buildBackdrop(parent, center)
	local folder = Instance.new("Folder")
	folder.Name = "Backdrop"
	folder.Parent = parent
	for index = 1, 20 do
		local angle = index * math.pi * 2 / 20
		local radius = 900 + (index % 3) * 220
		local height = 420 + (index % 5) * 190
		local position = center + Vector3.new(math.cos(angle) * radius, height / 2 - 140, math.sin(angle) * radius)
		local ridge = decor(folder, "FarRidge", Vector3.new(300, height, 300),
			CFrame.new(position) * CFrame.Angles(0, angle, math.rad((index % 3) * 4)),
			mix(palette.Bedrock, palette.Indigo, (index % 4) * 0.15))
		ridge.CastShadow = false
		pyramidSpire(folder, position + Vector3.new(0, height / 2, 0), 300, 220, mix(palette.Obsidian, palette.Indigo, 0.4))
	end
end

-- Zone 1: the fallen town ------------------------------------------------------

local function buildVillage(zone, world)
	local folder = Instance.new("Folder")
	folder.Name = "AshenfallVillage"
	folder.Parent = world
	local origin = zone.Origin

	makePart(folder, "Bedrock", Vector3.new(HALF.X * 2 + 60, 14, HALF.Z * 2 + 60), CFrame.new(origin - Vector3.new(0, 7, 0)), palette.Bedrock)
	makePart(folder, "ArenaFloor", Vector3.new(HALF.X * 2, 3, HALF.Z * 2), CFrame.new(origin), zone.Floor)

	cobbleRoad(folder, origin + Vector3.new(0, 0, HALF.Z - 24), origin + Vector3.new(0, 0, -HALF.Z + 40), 24)
	cobbleRoad(folder, origin + Vector3.new(-HALF.X + 40, 0, 6), origin + Vector3.new(HALF.X - 40, 0, 6), 18)

	local cx, cz = HALF.X - 6, HALF.Z - 6
	local corners = {
		origin + Vector3.new(-cx, FLOOR_Y, -cz), origin + Vector3.new(cx, FLOOR_Y, -cz),
		origin + Vector3.new(cx, FLOOR_Y, cz), origin + Vector3.new(-cx, FLOOR_Y, cz),
	}
	for index = 1, 4 do
		local from, to = corners[index], corners[index % 4 + 1]
		if index == 3 then
			wallRun(folder, from, origin + Vector3.new(22, FLOOR_Y, cz), 24, 7)
			wallRun(folder, origin + Vector3.new(-22, FLOOR_Y, cz), to, 24, 7)
		else
			wallRun(folder, from, to, 24, 7)
		end
		roundTower(folder, from, 16, 34, palette.Amber)
	end
	roundTower(folder, origin + Vector3.new(-cx, FLOOR_Y, 0), 14, 30, palette.Amber)
	roundTower(folder, origin + Vector3.new(cx, FLOOR_Y, 0), 14, 30, palette.Amber)

	-- Gatehouse.
	local gatePos = origin + Vector3.new(0, FLOOR_Y, cz)
	for side = -1, 1, 2 do
		roundTower(folder, gatePos + Vector3.new(side * 22, 0, 0), 16, 36, palette.CrimsonLit)
		banner(folder, CFrame.new(gatePos + Vector3.new(side * 22, 26, -9.2)), 18)
	end
	makePart(folder, "GateArch", Vector3.new(44, 10, 12), CFrame.new(gatePos + Vector3.new(0, 30, 0)), palette.Rock)
	for side = -1, 1, 2 do
		wedge(folder, "GateHaunch", Vector3.new(12, 8, 11), CFrame.new(gatePos + Vector3.new(side * 16, 21, 0)) * CFrame.Angles(0, side > 0 and 0 or math.rad(180), 0), palette.Rock)
	end
	for bar = -3, 3 do
		cylinder(folder, "Portcullis", 0.8, 14, CFrame.new(gatePos + Vector3.new(bar * 5, 22, 0)), palette.Iron)
	end

	-- Houses and alleys.
	for _, side in { -1, 1 } do
		for index = 0, 4 do
			local z = HALF.Z - 62 - index * 34
			local jitter = (index % 2) * 4
			house(folder, CFrame.new(origin + Vector3.new(side * (30 + jitter), FLOOR_Y, z)) * CFrame.Angles(0, side > 0 and math.pi or 0, 0),
				20 + (index % 3) * 3, 18, 13 + (index % 2) * 4, index % 3 == 0)
			if index % 2 == 0 then lamp(folder, origin + Vector3.new(side * 15, FLOOR_Y, z + 8)) end
		end
	end

	-- Market square: rune circle, well, stalls, drifting dust.
	local market = origin + Vector3.new(0, FLOOR_Y, 6)
	decor(folder, "Plaza", Vector3.new(76, 0.6, 62), CFrame.new(market + Vector3.new(0, 0.3, 0)), palette.Cobble)
	runeCircle(folder, market + Vector3.new(0, 0.6, 0), 34, palette.CrimsonLit)
	well(folder, market)
	shards(folder, market, 8, palette.CrimsonLit)
	dust(folder, market + Vector3.new(0, 10, 0), palette.Ember, 10, 1.1)
	for index = -1, 1 do
		marketStall(folder, CFrame.new(market + Vector3.new(index * 24, 0, -24)))
		props(folder, market + Vector3.new(index * 22, 0, 20), 4)
	end
	for side = -1, 1, 2 do
		brazier(folder, market + Vector3.new(side * 34, 0, 0), palette.Ember)
	end

	-- Chapel and forge.
	local chapel = origin + Vector3.new(-72, FLOOR_Y, -40)
	house(folder, CFrame.new(chapel), 26, 34, 22, false)
	roundTower(folder, chapel + Vector3.new(0, 0, -24), 11, 42, palette.Amber)
	for index = -1, 1, 2 do
		column(folder, chapel + Vector3.new(index * 15, 0, 19), 3, 14)
	end
	banner(folder, CFrame.new(chapel + Vector3.new(0, 20, 17.4)), 14)

	local forge = origin + Vector3.new(74, FLOOR_Y, -36)
	house(folder, CFrame.new(forge) * CFrame.Angles(0, math.rad(180), 0), 24, 20, 14, false)
	local coals = glow(folder, "ForgeCoals", Vector3.new(6, 0.8, 5), CFrame.new(forge + Vector3.new(0, 1.2, 13)), palette.CrimsonLit, 0.35)
	local forgeLight = Instance.new("PointLight")
	forgeLight.Color = Color3.fromRGB(255, 120, 60)
	forgeLight.Brightness = 2.2
	forgeLight.Range = 30
	forgeLight.Parent = coals
	props(folder, forge + Vector3.new(-12, 0, 12), 3)

	for index = -2, 2 do
		for side = -1, 1, 2 do
			lamp(folder, origin + Vector3.new(side * 14, FLOOR_Y, index * 36 - 20))
		end
		banner(folder, CFrame.new(origin + Vector3.new(index * 46, 16, -cz + 4.6)), 14)
		banner(folder, CFrame.new(origin + Vector3.new(-cx + 4.6, 16, index * 40)) * CFrame.Angles(0, math.rad(90), 0), 14)
	end

	dust(folder, origin + Vector3.new(0, 18, -60), palette.Indigo, 6, 1.4)
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

	makePart(folder, "Bedrock", Vector3.new(HALF.X * 2 + 60, 14, HALF.Z * 2 + 60), CFrame.new(origin - Vector3.new(0, 7, 0)), palette.Bedrock)
	makePart(folder, "ArenaFloor", Vector3.new(HALF.X * 2, 3, HALF.Z * 2), CFrame.new(origin), zone.Floor)

	local cx, cz = HALF.X - 6, HALF.Z - 6
	local corners = {
		origin + Vector3.new(-cx, FLOOR_Y, -cz), origin + Vector3.new(cx, FLOOR_Y, -cz),
		origin + Vector3.new(cx, FLOOR_Y, cz), origin + Vector3.new(-cx, FLOOR_Y, cz),
	}
	for index = 1, 4 do
		local from, to = corners[index], corners[index % 4 + 1]
		if index == 3 then
			wallRun(folder, from, origin + Vector3.new(20, FLOOR_Y, cz), 30, 8)
			wallRun(folder, origin + Vector3.new(-20, FLOOR_Y, cz), to, 30, 8)
		else
			wallRun(folder, from, to, 30, 8)
		end
		roundTower(folder, from, 18, 44, palette.CrimsonLit)
	end

	cobbleRoad(folder, origin + Vector3.new(0, 0, cz - 10), origin + Vector3.new(0, 0, -40), 26)

	for side = -1, 1, 2 do
		for index = 0, 2 do
			house(folder, CFrame.new(origin + Vector3.new(side * 46, FLOOR_Y, 60 - index * 38)) * CFrame.Angles(0, side > 0 and math.pi or 0, 0), 22, 26, 16, false)
		end
		lamp(folder, origin + Vector3.new(side * 18, FLOOR_Y, 40))
		lamp(folder, origin + Vector3.new(side * 18, FLOOR_Y, -4))
		for index = -1, 1 do
			banner(folder, CFrame.new(origin + Vector3.new(side * 34, 22, index * 38 + 20)), 18)
		end
	end

	-- The keep, raised on a plinth with a wedge-roofed hall and flanking towers.
	local keepPos = origin + Vector3.new(0, FLOOR_Y, -66)
	makePart(folder, "KeepPlinth", Vector3.new(120, 6, 76), CFrame.new(keepPos + Vector3.new(0, 3, 0)), palette.StoneDark)
	for step = 1, 5 do
		makePart(folder, "KeepStair", Vector3.new(44, 1.4, 4), CFrame.new(keepPos + Vector3.new(0, step * 1.2, 40 - step * 3.4)), palette.Stone)
	end
	for tier = 0, 2 do
		makePart(folder, "KeepHall", Vector3.new(84, 46 / 3, 52), CFrame.new(keepPos + Vector3.new(0, 6 + 46 / 6 + tier * (46 / 3), -8)),
			mix(palette.Obsidian, palette.Slate, 0.2 + tier * 0.28))
	end
	pitchedRoof(folder, CFrame.new(keepPos + Vector3.new(0, 52, -8)), 88, 56, 26, palette.Roof)
	for side = -1, 1, 2 do
		roundTower(folder, keepPos + Vector3.new(side * 50, 6, -8), 20, 56, palette.CrimsonLit)
		column(folder, keepPos + Vector3.new(side * 26, 6, 20), 4, 20)
	end
	local door = glow(folder, "KeepDoor", Vector3.new(16, 22, 1), CFrame.new(keepPos + Vector3.new(0, 17, 18.2)), palette.CrimsonLit, 0.6, Enum.Material.Glass)
	door.Reflectance = 0.2
	runeCircle(folder, keepPos + Vector3.new(0, 6.2, 26), 40, palette.Amber)
	shards(folder, keepPos + Vector3.new(0, 8, 10), 10, palette.Amber)
	dust(folder, keepPos + Vector3.new(0, 16, 6), palette.CrimsonLit, 12, 1.2)

	for side = -1, 1, 2 do
		brazier(folder, keepPos + Vector3.new(side * 32, 6, 26), palette.Amber)
		brazier(folder, origin + Vector3.new(side * 30, 0, -10), palette.Ember)
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
	spawnPad.Material = Enum.Material.SmoothPlastic
	spawnPad.Parent = world
	runeCircle(world, spawnPosition + Vector3.new(0, 0.7, 0), 22, palette.Amber)

	local function portal(position, accent, title, objectText, actionText, hold)
		local veil = makePart(world, "GateVeil", Vector3.new(30, 34, 1.4), CFrame.new(position + Vector3.new(0, 18, 0)), accent, Enum.Material.Neon)
		veil.Transparency = 0.8
		veil.CanCollide = false
		veil.CastShadow = false
		for side = -1, 1, 2 do
			roundTower(world, position + Vector3.new(side * 24, 0, 0), 16, 40, accent)
		end
		makePart(world, "GateLintel", Vector3.new(50, 10, 12), CFrame.new(position + Vector3.new(0, 38, 0)), palette.Rock)
		runeCircle(world, position + Vector3.new(0, FLOOR_Y, 10), 26, accent)
		shards(world, position + Vector3.new(0, 4, 0), 6, accent)
		addLabel(veil, title, palette.GoldPale, 22, 130)

		local light = Instance.new("PointLight")
		light.Color = accent
		light.Brightness = 2.2
		light.Range = 40
		light.Parent = veil

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = actionText
		prompt.ObjectText = objectText
		prompt.HoldDuration = hold
		prompt.MaxActivationDistance = 18
		prompt.RequiresLineOfSight = false
		prompt.Parent = veil
		return prompt
	end

	local gatePrompt = portal(zoneOne.Origin + Vector3.new(0, FLOOR_Y, -HALF.Z + 26), zoneOne.Accent,
		"THE ASH GATE", "Blackspire Keep", "Open the Ash Gate", 0.4)
	local returnPrompt = portal(zoneTwo.Origin + Vector3.new(0, FLOOR_Y, HALF.Z - 26), zoneTwo.Accent,
		"BACK TO ASHENFALL", "Ashenfall Village", "Return", 0.25)

	return {
		Folder = world,
		GatePrompt = gatePrompt,
		ReturnPrompt = returnPrompt,
		FloorY = FLOOR_Y,
	}
end

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
