local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local root = ReplicatedStorage:WaitForChild("SoulGrind")
local Config = require(root.Config)
local Model = require(script.Parent.Model)
local Store = require(script.Parent.Store)
local Commerce = require(script.Parent.Commerce)

local Action = root:WaitForChild("Action")
local State = root:WaitForChild("State")
local Notice = root:WaitForChild("Notice")
local FX = root:WaitForChild("FX")

local sessions = {}
local enemies = {}

local function showNotice(player, message)
	Notice:FireClient(player, message)
end

local function updateLeaderstats(player, profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	leaderstats.Souls.Value = profile.Souls
	leaderstats.Rebirths.Value = profile.Rebirths

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local billboard = head and head:FindFirstChild("SoulRank")
	if billboard then
		local crown = profile.Collection.HollowCrown and "  |  HOLLOW CROWN" or ""
		billboard.Label.Text = `SOUL LV {profile.Level}  |  REBIRTH {profile.Rebirths}{crown}`
	end
end

local function publish(player)
	local profile = Store.peek(player.UserId)
	local session = sessions[player]
	if not profile or not session then return end
	updateLeaderstats(player, profile)
	State:FireClient(player, {
		Revision = profile.Revision,
		Souls = profile.Souls,
		Level = profile.Level,
		Rebirths = profile.Rebirths,
		MaxZone = profile.MaxZone,
		Kills = profile.Kills,
		Bosses = profile.Bosses,
		ActiveDays = profile.ActiveDays,
		Streak = profile.Streak,
		Day = profile.LastDay,
		DailyKills = profile.DailyKills,
		DailyGoal = Config.DailyGoal,
		DailyClaimed = profile.DailyClaimed,
		CheckInClaimed = profile.CheckInClaimed,
		ActiveSeconds = profile.DailyActiveSeconds + session.UnsavedSeconds,
		FlareCount = profile.Wallet.Flares,
		HasAura = player:GetAttribute("HasAura") == true,
		AuraEnabled = session.AuraEnabled,
		FriendBonus = session.FriendBonus,
		Zone = session.Zone,
		UpgradeCost = Model.upgradeCost(profile),
		RebirthCost = Model.rebirthCost(profile),
		Damage = Model.damage(profile),
		PulseUnlocked = profile.Level >= 3,
		NextGoal = Model.nextGoal(profile),
		DailyName = "Bind 10 shades",
		DailyReward = Config.DailyReward,
		Collection = profile.Collection,
		Transient = not Store.isDurable(),
		SaveStatus = Store.isDurable() and "Saved" or "Studio preview: saving off",
	})
end

local function applyAura(player, enabled)
	local character = player.Character
	if not character then return end
	local old = character:FindFirstChild("SoulAura")
	if old then old:Destroy() end
	if not enabled then return end
	local highlight = Instance.new("Highlight")
	highlight.Name = "SoulAura"
	highlight.FillColor = Color3.fromRGB(184, 86, 255)
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Color3.fromRGB(89, 224, 255)
	highlight.OutlineTransparency = 0.1
	highlight.Parent = character
end

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

local function addLabel(part, text, color, height)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WorldLabel"
	billboard.Size = UDim2.fromOffset(300, 54)
	billboard.StudsOffset = Vector3.new(0, height or 5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 600
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.1
	label.TextStrokeColor3 = Color3.fromRGB(6, 4, 12)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = billboard
end

local world = Workspace:FindFirstChild("SoulGrindWorld")
if world then world:Destroy() end
world = Instance.new("Folder")
world.Name = "SoulGrindWorld"
world.Parent = Workspace

-- Readability first: the underworld stays violet and moody, but every surface has to
-- clear the "is that a wall or the void?" bar. Ambient light carries the shapes, the
-- low sun carries the shadows, and fog starts far enough out to leave the arena legible.
-- ClockTime is the taste knob: 5.7 is a violet pre-dawn. Lower is darker, 12 is flat noon.
-- Atmosphere and EnvironmentDiffuseScale need Lighting.Technology of ShadowMap or better,
-- which tools/build-place.mjs pins in the place file because scripts cannot set it.
Lighting.ClockTime = 5.7
Lighting.GeographicLatitude = 18
Lighting.Brightness = 1.9
Lighting.ExposureCompensation = -0.1
Lighting.Ambient = Color3.fromRGB(58, 50, 78)
Lighting.OutdoorAmbient = Color3.fromRGB(70, 64, 92)
Lighting.FogColor = Color3.fromRGB(46, 32, 70)
Lighting.FogStart = 120
Lighting.FogEnd = 620
Lighting.EnvironmentDiffuseScale = 0.35
Lighting.EnvironmentSpecularScale = 0.2
Lighting.GlobalShadows = true

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Haze = 1.2
atmosphere.Glare = 0.03
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(120, 100, 150)
atmosphere.Decay = Color3.fromRGB(46, 30, 70)
atmosphere.Parent = Lighting

local function lightingEffect(className, name, properties)
	local effect = Lighting:FindFirstChild(name) or Instance.new(className)
	effect.Name = name
	for property, value in properties do effect[property] = value end
	effect.Parent = Lighting
end

lightingEffect("BloomEffect", "SoulBloom", { Intensity = 0.22, Size = 18, Threshold = 2.3 })
lightingEffect("ColorCorrectionEffect", "UnderworldGrade", {
	Brightness = -0.01, Contrast = 0.16, Saturation = -0.04, TintColor = Color3.fromRGB(236, 228, 252),
})
-- Depth of field blurred the very silhouettes the player needs to read. Removed on purpose.
local staleDepth = Lighting:FindFirstChild("SoulDepth")
if staleDepth then staleDepth:Destroy() end

local function addEmbers(parent, position, color)
	local anchor = makePart(parent, "DriftingSouls", Vector3.new(1, 1, 1), CFrame.new(position), color, Enum.Material.Neon)
	anchor.Transparency = 1
	anchor.CanCollide = false
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color, Color3.fromRGB(225, 221, 255))
	emitter.LightEmission = 0.8
	emitter.Lifetime = NumberRange.new(3.5, 6)
	emitter.Rate = 22
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-35, 35)
	emitter.Speed = NumberRange.new(1.5, 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = anchor
end

local function addTorch(parent, position, color)
	makePart(parent, "IronBrazier", Vector3.new(1.1, 5.2, 1.1), CFrame.new(position), Color3.fromRGB(78, 70, 92), Enum.Material.Metal)
	makePart(parent, "BrazierBowl", Vector3.new(2.6, 0.8, 2.6), CFrame.new(position + Vector3.new(0, 2.5, 0)), Color3.fromRGB(96, 86, 110), Enum.Material.Metal)
	local flame = makePart(parent, "SoulFlame", Vector3.new(1.7, 2.3, 1.7), CFrame.new(position + Vector3.new(0, 3.4, 0)), color, Enum.Material.Neon)
	flame.Shape = Enum.PartType.Ball
	flame.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 2.2
	light.Range = 30
	light.Shadows = true
	light.Parent = flame
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	fire.LightEmission = 1
	fire.Lifetime = NumberRange.new(0.4, 0.75)
	fire.Rate = 34
	fire.Size = NumberSequence.new(2.2)
	fire.Speed = NumberRange.new(2, 5)
	fire.SpreadAngle = Vector2.new(18, 18)
	fire.Parent = flame
end

local function addRuinedArch(parent, position, color, stone)
	stone = stone or Color3.fromRGB(104, 94, 124)
	makePart(parent, "ArchPillar", Vector3.new(4, 18, 5), CFrame.new(position + Vector3.new(-9, 9, 0)), stone, Enum.Material.Basalt)
	makePart(parent, "ArchPillar", Vector3.new(4, 18, 5), CFrame.new(position + Vector3.new(9, 9, 0)), stone, Enum.Material.Basalt)
	makePart(parent, "ArchLintel", Vector3.new(22, 4, 5), CFrame.new(position + Vector3.new(0, 18, 0)) * CFrame.Angles(0, 0, math.rad(-2)), stone, Enum.Material.Basalt)
	for x = -1, 1, 2 do
		local rune = makePart(parent, "ArchRune", Vector3.new(0.4, 8, 1.4), CFrame.new(position + Vector3.new(x * 9, 10, -2.7)), color, Enum.Material.Neon)
		rune.CanCollide = false
	end
end

-- A glowing grid is the cheapest honest depth cue on a flat arena: it tells the player
-- how far away something is without lighting the whole map like a showroom.
local function addFloorGrid(folder, zone, half)
	for step = -6, 6 do
		local line = makePart(folder, "SoulGrid", Vector3.new(0.5, 0.25, half.Z * 2), CFrame.new(zone.Origin + Vector3.new(step * (half.X / 6.5), 1.2, 0)), zone.Color, Enum.Material.Neon)
		line.Transparency = 0.84
		line.CanCollide = false
		local cross = makePart(folder, "SoulGrid", Vector3.new(half.X * 2, 0.25, 0.5), CFrame.new(zone.Origin + Vector3.new(0, 1.2, step * (half.Z / 6.5))), zone.Color, Enum.Material.Neon)
		cross.Transparency = 0.9
		cross.CanCollide = false
	end
	for side = -1, 1, 2 do
		local edgeX = makePart(folder, "ArenaEdge", Vector3.new(1.2, 0.7, half.Z * 2), CFrame.new(zone.Origin + Vector3.new(side * half.X, 1.4, 0)), zone.Color, Enum.Material.Neon)
		edgeX.CanCollide = false
		edgeX.Transparency = 0.4
		local edgeZ = makePart(folder, "ArenaEdge", Vector3.new(half.X * 2, 0.7, 1.2), CFrame.new(zone.Origin + Vector3.new(0, 1.4, side * half.Z)), zone.Color, Enum.Material.Neon)
		edgeZ.CanCollide = false
		edgeZ.Transparency = 0.4
	end
end

-- The obelisk is the zone's landmark. It is tall enough to see from anywhere in the
-- arena, so the player always knows which way is "back to the middle".
local function addObelisk(folder, zone)
	local base = zone.Origin + Vector3.new(0, 1.1, 0)
	-- Non-collidable on purpose. Enemies steer with Humanoid:MoveTo, which has no
	-- pathfinding, so a solid pillar in the middle of the arena is a trap, not cover.
	local plinth = makePart(folder, "ObeliskBase", Vector3.new(14, 1.2, 14), CFrame.new(base + Vector3.new(0, 0.6, 0)), zone.Stone, Enum.Material.Marble)
	plinth.CanCollide = false
	local shaft = makePart(folder, "ObeliskShaft", Vector3.new(6, 46, 6), CFrame.new(base + Vector3.new(0, 24, 0)), Color3.fromRGB(88, 78, 108), Enum.Material.Basalt)
	shaft.CanCollide = false
	local core = makePart(folder, "ObeliskCore", Vector3.new(2.2, 40, 2.2), CFrame.new(base + Vector3.new(0, 24, -3.1)), zone.Color, Enum.Material.Neon)
	core.CanCollide = false
	local crown = makePart(folder, "ObeliskCrown", Vector3.new(4.4, 4.4, 4.4), CFrame.new(base + Vector3.new(0, 49, 0)), zone.Color, Enum.Material.Neon)
	crown.Shape = Enum.PartType.Ball
	crown.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = zone.Color
	light.Brightness = 3
	light.Range = 45
	light.Parent = crown
	return crown
end

local function buildZone(zoneId, zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.Name:gsub(" ", "")
	folder.Parent = world
	local half = Vector3.new(73, 0, 53)

	makePart(folder, "Bedrock", Vector3.new(154, 7, 114), CFrame.new(zone.Origin - Vector3.new(0, 3.8, 0)), Color3.fromRGB(40, 34, 54), Enum.Material.Basalt)
	makePart(folder, "ArenaFloor", Vector3.new(146, 2.2, 106), CFrame.new(zone.Origin), zone.Ground, Enum.Material.Slate)

	-- Lighter inlay slabs break the floor into readable bands instead of one dark sheet.
	for band = -2, 2 do
		local slab = makePart(folder, "FloorInlay", Vector3.new(146, 0.4, 9), CFrame.new(zone.Origin + Vector3.new(0, 1.1, band * 22)), zone.GroundAlt, Enum.Material.Concrete)
		slab.CanCollide = false
	end
	addFloorGrid(folder, zone, half)

	for step = -5, 5 do
		if step == 0 then continue end
		local offset = Vector3.new((step % 2) * 0.8, 1.45, step * 8)
		makePart(folder, "PilgrimStone", Vector3.new(15, 0.65, 7), CFrame.new(zone.Origin + offset) * CFrame.Angles(0, math.rad(step * 2), 0), zone.Stone, Enum.Material.Cobblestone)
	end

	for side = -1, 1, 2 do
		for index = -2, 2 do
			local position = zone.Origin + Vector3.new(side * (57 + index % 2 * 5), 6 + (index % 2) * 2, index * 21)
			local cliff = makePart(folder, "BrokenCliff", Vector3.new(18, 14 + (index % 2) * 4, 17), CFrame.new(position) * CFrame.Angles(math.rad(index * 3), math.rad(index * 13), math.rad(side * 5)), Color3.fromRGB(60, 52, 76), Enum.Material.Basalt)
			local vein = makePart(folder, "CliffVein", Vector3.new(0.6, cliff.Size.Y * 0.7, 1), cliff.CFrame * CFrame.new(0, 0, -8.6), zone.Color, Enum.Material.Neon)
			vein.CanCollide = false
			vein.Transparency = 0.2
		end
	end

	for index = 1, 12 do
		local angle = index * math.pi * 2 / 12 + zoneId * 0.23
		local radius = 39 + (index % 3) * 9
		local position = zone.Origin + Vector3.new(math.cos(angle) * radius, 4.4, math.sin(angle) * radius)
		local shard = makePart(folder, "SoulShard", Vector3.new(1.6 + index % 2, 7 + index % 5, 1.6 + index % 2), CFrame.new(position) * CFrame.Angles(math.rad(index * 4), 0, math.rad(index % 2 == 0 and 14 or -17)), zone.Color, Enum.Material.Neon)
		shard.Transparency = 0.25
		shard.CanCollide = false
	end

	for _, offset in { Vector3.new(-24, 0, 31), Vector3.new(24, 0, 31), Vector3.new(-31, 0, -27), Vector3.new(31, 0, -27), Vector3.new(-44, 0, 3), Vector3.new(44, 0, 3) } do
		addTorch(folder, zone.Origin + offset + Vector3.new(0, 3.8, 0), zone.Color)
	end
	addRuinedArch(folder, zone.Origin + Vector3.new(0, 1.2, -47), zone.Color, zone.Stone)
	addEmbers(folder, zone.Origin + Vector3.new(0, 14, 0), zone.Color)

	local crown = addObelisk(folder, zone)
	addLabel(crown, zone.Name:upper(), zone.Color, 8)
end

for zoneId, zone in Config.Zones do buildZone(zoneId, zone) end

local spawn = Instance.new("SpawnLocation")
spawn.Name = "UnderworldSpawn"
spawn.Size = Vector3.new(11, 0.8, 11)
spawn.CFrame = CFrame.new(Config.Zones[1].Origin + Vector3.new(0, 2, 38))
spawn.Anchored = true
spawn.Neutral = true
spawn.Color = Color3.fromRGB(148, 132, 176)
spawn.Material = Enum.Material.Marble
spawn.Transparency = 0
spawn.Parent = world
local spawnRune = makePart(world, "SpawnRune", Vector3.new(0.25, 15, 15), spawn.CFrame * CFrame.Angles(0, 0, math.rad(90)), Config.Zones[1].Color, Enum.Material.Neon)
spawnRune.Shape = Enum.PartType.Cylinder
spawnRune.Size = Vector3.new(0.3, 13, 13)
spawnRune.Transparency = 0.45
spawnRune.CanCollide = false
local spawnGlow = Instance.new("PointLight")
spawnGlow.Color = Config.Zones[1].Color
spawnGlow.Brightness = 2
spawnGlow.Range = 30
spawnGlow.Parent = spawnRune

local function makePortal(name, position, color, title, objectText)
	addRuinedArch(world, position - Vector3.new(0, 9, 0), color)
	local portal = makePart(world, name, Vector3.new(14, 14, 0.8), CFrame.new(position), color, Enum.Material.ForceField)
	portal.Transparency = 0.2
	portal.CanCollide = false
	local beacon = makePart(world, "PortalBeacon", Vector3.new(1.6, 150, 1.6), CFrame.new(position + Vector3.new(0, 70, 0)), color, Enum.Material.Neon)
	beacon.Transparency = 0.55
	beacon.CanCollide = false
	local portalLight = Instance.new("PointLight")
	portalLight.Color = color
	portalLight.Brightness = 3
	portalLight.Range = 40
	portalLight.Parent = portal
	addLabel(portal, title, Color3.new(1, 1, 1))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open / Cross"
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal
	addEmbers(world, position, color)
	return prompt
end

local gatePrompt = makePortal("AshGate", Vector3.new(68, 10, 0), Color3.fromRGB(197, 93, 255), "ASH GATE\n150 SOULS", "Frozen Purgatory")
local returnPrompt = makePortal("ReturnGate", Vector3.new(152, 10, 0), Color3.fromRGB(75, 216, 255), "RETURN TO CINDER HOLLOW", "Cinder Hollow")
returnPrompt.ActionText = "Return"
returnPrompt.HoldDuration = 0.2

local function teleportToZone(player, zoneId)
	local profile = Store.peek(player.UserId)
	local session = sessions[player]
	if not profile or not session or zoneId < 1 or zoneId > profile.MaxZone then return false end
	session.Zone = zoneId
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(Config.Zones[zoneId].Origin + Vector3.new(0, 6, 38)))
	end
	publish(player)
	return true
end

local function mutate(player, transform)
	local success, profile = Store.update(player.UserId, function(current)
		transform(current)
		Model.applyMilestones(current)
		return current
	end)
	if success then publish(player) else showNotice(player, "The Underworld could not save that action. Try again.") end
	return success, profile
end

local function unlockZone(player)
	local outcome
	local success = mutate(player, function(profile)
		if profile.MaxZone >= 2 then
			outcome = "open"
			return
		end
		if profile.Souls < 150 then
			outcome = "poor"
			return
		end
		profile.Souls -= 150
		profile.MaxZone = 2
		outcome = "unlocked"
	end)
	if not success then return end
	if outcome == "poor" then
		showNotice(player, "The Ash Gate needs 150 Souls.")
	else
		if outcome == "unlocked" then showNotice(player, "Frozen Purgatory is now permanently open.") end
		teleportToZone(player, 2)
	end
end

gatePrompt.Triggered:Connect(function(player)
	unlockZone(player)
end)
returnPrompt.Triggered:Connect(function(player)
	teleportToZone(player, 1)
end)

-- Y sits on the arena floor (top face at 1.1) so nothing spawns mid-air or half-buried.
local FLOOR_Y = 1.1
local enemyOffsets = {
	Vector3.new(0, FLOOR_Y, 22), Vector3.new(-22, FLOOR_Y, -14), Vector3.new(20, FLOOR_Y, 6),
	Vector3.new(34, FLOOR_Y, -24), Vector3.new(-6, FLOOR_Y, -34),
}

-- Body and Trim are readability, not decoration: each archetype has to be identifiable
-- by colour alone at 40 studs on a dark floor, before any name plate is readable.
local archetypes = {
	Shade = {
		Name = "CINDER SHADE", Health = 1, Damage = 1, Speed = 11, Reward = 1, Range = 5, Cooldown = 1.15,
		Body = Color3.fromRGB(126, 92, 184), Trim = Color3.fromRGB(216, 146, 255),
	},
	Reaver = {
		Name = "BONE REAVER", Health = 1.75, Damage = 1.35, Speed = 8, Reward = 1.65, Range = 6, Cooldown = 1.55,
		Body = Color3.fromRGB(162, 126, 96), Trim = Color3.fromRGB(255, 158, 78),
	},
	Wisp = {
		Name = "SOUL WISP", Health = 0.7, Damage = 0.8, Speed = 14, Reward = 1.25, Range = 4.5, Cooldown = 0.9,
		Body = Color3.fromRGB(88, 176, 206), Trim = Color3.fromRGB(150, 236, 252),
	},
	Warden = {
		Name = "FROZEN WARDEN", Health = 4.5, Damage = 1.55, Speed = 7, Reward = 5, Range = 7, Cooldown = 1.4,
		Body = Color3.fromRGB(158, 188, 214), Trim = Color3.fromRGB(96, 222, 250),
	},
}

local function enemyPart(model, rootPart, name, size, offset, color, material, shape, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = rootPart.CFrame * offset
	part.Color = color
	part.Material = material or Enum.Material.Slate
	part.Shape = shape or Enum.PartType.Block
	part.Transparency = transparency or 0
	part.CanCollide = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function addEnemyBar(rootPart, humanoid, title, color, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "EnemyBar"
	gui.Size = UDim2.fromOffset(190, 44)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 190
	gui.Parent = rootPart
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.new(1, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.Text = title
	label.TextColor3 = Color3.fromRGB(246, 242, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(6, 4, 12)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Parent = gui
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.new(1, -20, 0, 9)
	back.Position = UDim2.fromOffset(10, 27)
	back.BackgroundColor3 = Color3.fromRGB(14, 11, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill
	humanoid.HealthChanged:Connect(function(health)
		fill.Size = UDim2.fromScale(math.clamp(health / humanoid.MaxHealth, 0, 1), 1)
	end)
end

local function spawnEnemy(zoneId, spawnIndex)
	local zone = Config.Zones[zoneId]
	local boss = zoneId == 2 and spawnIndex == 5
	local kind = boss and "Warden" or ({ "Shade", "Reaver", "Wisp", "Shade", "Reaver" })[spawnIndex]
	local archetype = archetypes[kind]
	local model = Instance.new("Model")
	model.Name = kind
	model:SetAttribute("Enemy", true)
	model:SetAttribute("Archetype", kind)
	model:SetAttribute("Zone", zoneId)
	model:SetAttribute("Boss", boss)
	model:SetAttribute("SpawnIndex", spawnIndex)
	model:SetAttribute("AttackDamage", math.floor(zone.EnemyDamage * archetype.Damage))
	model:SetAttribute("AttackRange", archetype.Range)
	model:SetAttribute("AttackCooldown", archetype.Cooldown)
	model:SetAttribute("SoulReward", math.floor(zone.SoulReward * archetype.Reward))

	local bodySize = boss and Vector3.new(5.2, 6.4, 4.2) or (kind == "Reaver" and Vector3.new(3.7, 4.8, 3.2) or Vector3.new(2.9, 4, 2.4))

	-- The root is the only collider and it matches the body, so the Humanoid stands at
	-- the right height instead of scraping half-sunk through the floor.
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = bodySize
	rootPart.Transparency = 1
	rootPart.CanCollide = true
	rootPart.TopSurface = Enum.SurfaceType.Smooth
	rootPart.BottomSurface = Enum.SurfaceType.Smooth
	rootPart.CFrame = CFrame.new(zone.Origin + enemyOffsets[spawnIndex] + Vector3.new(0, bodySize.Y / 2, 0))
	rootPart.Parent = model

	local armor = archetype.Body
	local trim = archetype.Trim
	local bone = Color3.fromRGB(226, 220, 238)
	enemyPart(model, rootPart, "Torso", bodySize, CFrame.new(), armor, boss and Enum.Material.Metal or Enum.Material.SmoothPlastic, kind == "Wisp" and Enum.PartType.Ball or Enum.PartType.Block)
	local headHeight = boss and 4.5 or (kind == "Reaver" and 3.4 or 2.9)
	enemyPart(model, rootPart, "Head", boss and Vector3.new(3.1, 3.1, 3.1) or Vector3.new(2, 2, 2), CFrame.new(0, headHeight, 0), armor, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local core = enemyPart(model, rootPart, "SoulCore", boss and Vector3.new(2.1, 2.1, 0.45) or Vector3.new(1.25, 1.25, 0.35), CFrame.new(0, 0.2, -bodySize.Z / 2 - 0.2), trim, Enum.Material.Neon, Enum.PartType.Ball)
	enemyPart(model, rootPart, "Eye", boss and Vector3.new(1.3, 0.38, 0.28) or Vector3.new(0.9, 0.25, 0.2), CFrame.new(0, headHeight + 0.15, -1), trim, Enum.Material.Neon)
	-- A bright collar reads as a silhouette edge even when the enemy is backlit.
	enemyPart(model, rootPart, "Collar", Vector3.new(bodySize.X + 0.5, 0.4, bodySize.Z + 0.5), CFrame.new(0, bodySize.Y / 2 - 0.3, 0), trim, Enum.Material.Neon)

	if kind == "Wisp" then
		enemyPart(model, rootPart, "Tail", Vector3.new(1.4, 3.3, 1.4), CFrame.new(0, -2.6, 0) * CFrame.Angles(0, 0, math.rad(45)), trim, Enum.Material.Neon, Enum.PartType.Ball, 0.28)
	else
		for side = -1, 1, 2 do
			local armSize = boss and Vector3.new(1.5, 5.3, 1.5) or Vector3.new(1, kind == "Reaver" and 4.2 or 3.5, 1)
			enemyPart(model, rootPart, "Arm", armSize, CFrame.new(side * (bodySize.X / 2 + 0.7), 0, 0) * CFrame.Angles(0, 0, math.rad(side * -9)), armor, Enum.Material.SmoothPlastic)
			if boss or kind == "Reaver" then
				enemyPart(model, rootPart, "Horn", Vector3.new(0.65, boss and 3.7 or 2.6, 0.65), CFrame.new(side * 1.15, headHeight + 1.7, 0) * CFrame.Angles(0, 0, math.rad(side * -24)), bone, Enum.Material.Marble)
			end
		end
	end

	-- The single biggest readability win: an always-visible rim so an enemy never
	-- disappears into the floor, a cliff, or the fog.
	local outline = Instance.new("Highlight")
	outline.Name = "SoulOutline"
	outline.FillColor = trim
	outline.FillTransparency = 0.9
	outline.OutlineColor = trim
	outline.OutlineTransparency = 0.05
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model

	local light = Instance.new("PointLight")
	light.Color = trim
	light.Range = boss and 26 or 14
	light.Brightness = boss and 2.6 or 1.6
	light.Shadows = false
	light.Parent = core

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = math.floor(zone.EnemyHealth * archetype.Health)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = archetype.Speed
	humanoid.HipHeight = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.DisplayName = archetype.Name
	humanoid.Parent = model
	model.PrimaryPart = rootPart
	model.Parent = world
	pcall(rootPart.SetNetworkOwner, rootPart, nil)
	addEnemyBar(rootPart, humanoid, archetype.Name, trim, bodySize.Y / 2 + (boss and 5.5 or 3.6))
	enemies[model] = true

	humanoid.Died:Connect(function()
		enemies[model] = nil
		FX:FireAllClients({ Kind = "Death", Position = rootPart.Position, Color = zone.Color, Boss = boss })
		local userId = model:GetAttribute("LastHitUserId")
		local player = type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
		if player and os.clock() - (model:GetAttribute("LastHitAt") or 0) <= 12 then
			local friendMultiplier = sessions[player] and sessions[player].FriendBonus and 1.1 or 1
			local reward = math.floor((model:GetAttribute("SoulReward") or zone.SoulReward) * friendMultiplier)
			local granted = mutate(player, function(profile)
				profile.Souls += reward
				profile.Kills += 1
				profile.DailyKills += 1
				if boss then profile.Bosses += 1 end
			end)
			if granted then showNotice(player, `+{reward} Souls{boss and "  •  Warden bound!" or ""}`) end
		end
		Debris:AddItem(model, 1.4)
		task.delay(boss and 10 or 4.5, function()
			if world.Parent then spawnEnemy(zoneId, spawnIndex) end
		end)
	end)
end

for zoneId in Config.Zones do
	for spawnIndex = 1, #enemyOffsets do spawnEnemy(zoneId, spawnIndex) end
end

local function nearestEnemy(player, radius)
	local session = sessions[player]
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not session or not playerRoot then return nil end
	local best, bestDistance
	for model in enemies do
		local enemyRoot = model.PrimaryPart
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if enemyRoot and humanoid and humanoid.Health > 0 and model:GetAttribute("Zone") == session.Zone then
			local distance = (enemyRoot.Position - playerRoot.Position).Magnitude
			if distance <= radius and (not bestDistance or distance < bestDistance) then
				best, bestDistance = model, distance
			end
		end
	end
	return best, bestDistance
end

local function hitEnemy(player, enemy, damage, combo)
	local humanoid = enemy and enemy:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	enemy:SetAttribute("LastHitUserId", player.UserId)
	enemy:SetAttribute("LastHitAt", os.clock())
	local flash = Instance.new("Highlight")
	flash.Name = "HitFlash"
	flash.FillColor = Color3.new(1, 1, 1)
	flash.FillTransparency = 0.18
	flash.OutlineTransparency = 1
	flash.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	flash.Parent = enemy
	Debris:AddItem(flash, 0.1)
	humanoid:TakeDamage(damage)
	FX:FireClient(player, { Kind = "Hit", Position = enemy.PrimaryPart.Position, Damage = damage, Combo = combo or 0 })
end

-- Every press of Soul Strike has to produce something the player can see. Silent early
-- returns are why the button felt dead: no swing, no sound, and no reason given.
local function attack(player)
	local session = sessions[player]
	local now = os.clock()
	if not session then return end

	local character = player.Character
	local characterRoot = character and character:FindFirstChild("HumanoidRootPart")
	local body = character and character:FindFirstChildOfClass("Humanoid")
	if not characterRoot or not body or body.Health <= 0 then
		showNotice(player, "Your body is still reforming.")
		return
	end

	local profile = Store.peek(player.UserId)
	if not profile then
		showNotice(player, "Your soul data is still loading. Try again in a moment.")
		return
	end
	if now < session.NextAttack then
		FX:FireClient(player, { Kind = "Cooling", Ability = "Attack", Seconds = session.NextAttack - now })
		return
	end

	if now > session.ComboExpires then session.Combo = 0 end
	session.Combo = session.Combo % 3 + 1
	session.ComboExpires = now + 0.95
	session.NextAttack = now + (session.Combo == 3 and Config.Cooldowns.Finisher or Config.Cooldowns.Attack)

	local enemy, distance = nearestEnemy(player, Config.AttackRange)
	FX:FireClient(player, { Kind = "Swing", Combo = session.Combo, Cooldown = session.NextAttack - now })
	if not enemy then
		session.Combo = 0
		local _, reach = nearestEnemy(player, math.huge)
		FX:FireClient(player, { Kind = "Miss", Distance = reach })
		return
	end

	local multiplier = ({ 1, 1.15, 1.7 })[session.Combo]
	hitEnemy(player, enemy, math.floor(Model.damage(profile) * multiplier), session.Combo)
	if session.Combo == 3 and enemy.PrimaryPart then
		local direction = enemy.PrimaryPart.Position - characterRoot.Position
		if direction.Magnitude > 0 then enemy.PrimaryPart.AssemblyLinearVelocity += direction.Unit * 22 + Vector3.new(0, 8, 0) end
	end
	return distance
end

local function pulse(player)
	local session = sessions[player]
	local profile = Store.peek(player.UserId)
	if not session then return end
	if not profile then
		showNotice(player, "Your soul data is still loading. Try again in a moment.")
		return
	end
	if profile.Level < 3 then
		showNotice(player, `Soul Pulse unlocks at Soul Level 3. You are Level {profile.Level} - upgrade in the Journal.`)
		return
	end
	if os.clock() < session.NextPulse then
		showNotice(player, `Soul Pulse recharges in {math.ceil(session.NextPulse - os.clock())}s.`)
		return
	end
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not playerRoot then
		showNotice(player, "Your body is still reforming.")
		return
	end
	session.NextPulse = os.clock() + Config.Cooldowns.Pulse
	local struck = 0
	for enemy in enemies do
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if enemy.PrimaryPart and humanoid and humanoid.Health > 0 and enemy:GetAttribute("Zone") == session.Zone
			and (enemy.PrimaryPart.Position - playerRoot.Position).Magnitude <= Config.PulseRange then
			hitEnemy(player, enemy, math.floor(Model.damage(profile) * 1.4), 0)
			struck += 1
		end
	end
	FX:FireClient(player, { Kind = "Pulse", Position = playerRoot.Position, Hits = struck, Cooldown = Config.Cooldowns.Pulse })
	showNotice(player, struck > 0 and `Soul Pulse struck {struck}.` or "Soul Pulse found nothing in range.")
	local pulsePart = makePart(world, "SoulPulse", Vector3.new(1, 1, 1), CFrame.new(playerRoot.Position), Color3.fromRGB(185, 85, 255), Enum.Material.Neon)
	pulsePart.Shape = Enum.PartType.Ball
	pulsePart.CanCollide = false
	task.spawn(function()
		for size = 2, Config.PulseRange * 2, 4 do pulsePart.Size = Vector3.new(size, size, size); pulsePart.Transparency = 0.25 + size / (Config.PulseRange * 2.8); task.wait(0.025) end
		pulsePart:Destroy()
	end)
end

local function dash(player)
	local session = sessions[player]
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local now = os.clock()
	if not session then return end
	if not playerRoot or not humanoid or humanoid.Health <= 0 then
		showNotice(player, "Your body is still reforming.")
		return
	end
	if now < session.NextDash then
		showNotice(player, `Soul Step recharges in {math.ceil(session.NextDash - now)}s.`)
		return
	end
	session.NextDash = now + Config.Cooldowns.Dash
	session.DodgeUntil = now + 0.55
	session.Combo = 0
	playerRoot.AssemblyLinearVelocity = playerRoot.CFrame.LookVector * 72 + Vector3.new(0, 5, 0)
	FX:FireAllClients({ Kind = "Dash", Player = player, Cooldown = Config.Cooldowns.Dash })
end

local function useFlare(player)
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not playerRoot then
		showNotice(player, "Your soul must finish forming first.")
		return
	end
	local outcome
	local success = mutate(player, function(profile)
		if profile.Wallet.Flares <= 0 then
			outcome = "empty"
			return
		end
		profile.Wallet.Flares -= 1
		outcome = "used"
	end)
	if not success then return end
	if outcome == "empty" then
		Commerce.offer(player, "FlarePack")
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(174, 67, 255), Color3.fromRGB(70, 230, 255))
	emitter.Lifetime = NumberRange.new(1.2, 2)
	emitter.Speed = NumberRange.new(12, 24)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = playerRoot
	emitter:Emit(70)
	Debris:AddItem(emitter, 3)
end

local function refreshFriends()
	for player, session in sessions do session.FriendBonus = false end
	local currentPlayers = Players:GetPlayers()
	-- ponytail: quadratic only when players join/leave; cache friend pairs if server size grows.
	for i = 1, #currentPlayers do
		for j = i + 1, #currentPlayers do
			local a, b = currentPlayers[i], currentPlayers[j]
			if sessions[a] and sessions[b] then
				local ok, friends = pcall(a.IsFriendsWith, a, b.UserId)
				if ok and friends then sessions[a].FriendBonus = true; sessions[b].FriendBonus = true end
			end
		end
	end
	for player in sessions do publish(player) end
end

local allowedActions = {
	Sync = true, Attack = true, Pulse = true, Dash = true, Upgrade = true, UnlockZone = true,
	Travel = true, Rebirth = true, ClaimDaily = true, Flare = true, Aura = true,
}

Commerce.init(Store, publish, showNotice, applyAura)

Action.OnServerEvent:Connect(function(player, actionName, payload)
	local session = sessions[player]
	if not session or type(actionName) ~= "string" or not allowedActions[actionName] then return end
	if os.clock() < session.NextRemote then return end
	session.NextRemote = os.clock() + 0.08
	session.LastAction = os.clock()

	if actionName == "Sync" then publish(player)
	elseif actionName == "Attack" then attack(player)
	elseif actionName == "Pulse" then pulse(player)
	elseif actionName == "Dash" then dash(player)
	elseif actionName == "Upgrade" then
		local outcome, paid
		local success = mutate(player, function(profile)
			paid = Model.upgradeCost(profile)
			if profile.Souls < paid then
				outcome = "poor"
				return
			end
			profile.Souls -= paid; profile.Level += 1; outcome = "upgraded"
		end)
		if success then showNotice(player, outcome == "upgraded" and "Soul power strengthened." or `You need {paid} Souls.`) end
	elseif actionName == "UnlockZone" then unlockZone(player)
	elseif actionName == "Travel" and (payload == 1 or payload == 2) then
		if not teleportToZone(player, payload) then showNotice(player, "That realm is still sealed.") end
	elseif actionName == "Rebirth" then
		local outcome, cost
		local success = mutate(player, function(profile)
			cost = Model.rebirthCost(profile)
			if profile.MaxZone < 2 or profile.Souls < cost then
				outcome = "blocked"
				return
			end
			profile.Souls = 0; profile.Level = 1; profile.Rebirths += 1; outcome = "reborn"
		end)
		if success then
			if outcome == "reborn" then teleportToZone(player, 1); showNotice(player, "Reborn: permanent damage increased by 10%.")
			else showNotice(player, `Open Zone 2 and hold {cost} Souls to rebirth.`) end
		end
	elseif actionName == "ClaimDaily" then
		local outcome
		local success = mutate(player, function(profile)
			if profile.DailyClaimed then
				outcome = "claimed"
				return
			end
			if profile.DailyKills < Config.DailyGoal then
				outcome = "incomplete"
				return
			end
			profile.DailyClaimed = true
			profile.Wallet.Flares += Config.DailyReward
			outcome = "rewarded"
		end)
		if success then
			local messages = { claimed = "Today's reward is already claimed.", incomplete = "Finish today's shade goal first.", rewarded = `Daily goal complete: +{Config.DailyReward} free Soul Flares.` }
			showNotice(player, messages[outcome])
		end
	elseif actionName == "Flare" then useFlare(player)
	elseif actionName == "Aura" then
		if player:GetAttribute("HasAura") then
			session.AuraEnabled = not session.AuraEnabled
			applyAura(player, session.AuraEnabled)
			publish(player)
		else Commerce.offer(player, "Aura") end
	end
end)

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	for _, statName in { "Souls", "Rebirths" } do
		local stat = Instance.new("IntValue")
		stat.Name = statName
		stat.Parent = leaderstats
	end

	local success = Store.load(player.UserId)
	if not success then player:Kick("Your soul data could not be loaded safely. Please rejoin."); return end
	sessions[player] = {
		Zone = 1, NextAttack = 0, NextPulse = 0, NextDash = 0, NextRemote = 0,
		Combo = 0, ComboExpires = 0, DodgeUntil = 0,
		LastAction = os.clock(), UnsavedSeconds = 0, FriendBonus = false, AuraEnabled = true,
	}

	player.CharacterAdded:Connect(function(character)
		local head = character:WaitForChild("Head", 8)
		if head then
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "SoulRank"
			billboard.Size = UDim2.fromOffset(230, 34)
			billboard.StudsOffset = Vector3.new(0, 2.7, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = head
			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(214, 144, 255)
			label.TextStrokeTransparency = 0.2
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.Parent = billboard
		end
		task.defer(function()
			teleportToZone(player, sessions[player] and sessions[player].Zone or 1)
			applyAura(player, player:GetAttribute("HasAura") == true and sessions[player] and sessions[player].AuraEnabled)
		end)
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
		if humanoid then
			humanoid.Died:Connect(function()
				local session = sessions[player]
				if session then session.Combo = 0; session.DodgeUntil = 0 end
				showNotice(player, "Your body fell. Your Souls and progress remain.")
			end)
		end
	end)

	Commerce.refreshPass(player)
	publish(player)
	showNotice(player, "Defeat the nearby shade. ATTACK is ready now.")
	refreshFriends()
end)

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	if session and session.UnsavedSeconds > 0 then
		local seconds = session.UnsavedSeconds
		Store.update(player.UserId, function(profile) profile.DailyActiveSeconds += seconds; return profile end)
	end
	sessions[player] = nil
	Store.forget(player.UserId)
	task.defer(refreshFriends)
end)

local function bossSlam(enemy)
	local enemyRoot = enemy.PrimaryPart
	if not enemyRoot or enemy:GetAttribute("SlamCharging") then return end
	enemy:SetAttribute("SlamCharging", true)
	enemy:SetAttribute("NextSlam", os.clock() + 7.5)
	local zoneId = enemy:GetAttribute("Zone")
	local zone = Config.Zones[zoneId]
	local center = Vector3.new(enemyRoot.Position.X, zone.Origin.Y + 1.25, enemyRoot.Position.Z)
	local warning = makePart(world, "WardenWarning", Vector3.new(0.22, 2, 2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), zone.Color, Enum.Material.Neon)
	warning.Shape = Enum.PartType.Cylinder
	warning.Transparency = 0.58
	warning.CanCollide = false
	FX:FireAllClients({ Kind = "BossCharge", Position = center })
	local tween = TweenService:Create(warning, TweenInfo.new(1.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.22, 36, 36), Transparency = 0.28,
	})
	tween:Play()
	task.delay(1.15, function()
		if warning.Parent then warning:Destroy() end
		if not enemy.Parent or not enemy.PrimaryPart then return end
		FX:FireAllClients({ Kind = "BossSlam", Position = center })
		for player, session in sessions do
			local character = player.Character
			local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if session.Zone == zoneId and playerRoot and humanoid and humanoid.Health > 0 and (playerRoot.Position - center).Magnitude <= 18 then
				if os.clock() <= session.DodgeUntil then
					FX:FireClient(player, { Kind = "Dodge" })
				else
					humanoid:TakeDamage(math.floor((enemy:GetAttribute("AttackDamage") or zone.EnemyDamage) * 1.7))
				end
			end
		end
		enemy:SetAttribute("SlamCharging", false)
	end)
end

-- Resolved once per tick: repeatedly indexing player.Character mid-loop is how the old
-- version threw, and an error here used to kill the thread and freeze every enemy for
-- the rest of the server's life.
local function livingTargets()
	local targets = {}
	for player, session in sessions do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			table.insert(targets, { Player = player, Session = session, Root = root, Humanoid = humanoid })
		end
	end
	return targets
end

local function stepEnemies()
	local targets = livingTargets()
	if #targets == 0 then return end
	for enemy in enemies do
		local enemyRoot = enemy.PrimaryPart
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if not enemy.Parent or not enemyRoot or not humanoid or humanoid.Health <= 0 then continue end
		local zoneId = enemy:GetAttribute("Zone")
		local nearest, nearestDistance
		for _, target in targets do
			if target.Session.Zone == zoneId then
				local distance = (target.Root.Position - enemyRoot.Position).Magnitude
				if distance < 90 and (not nearestDistance or distance < nearestDistance) then
					nearest, nearestDistance = target, distance
				end
			end
		end
		if not nearest then continue end

		humanoid:MoveTo(nearest.Root.Position)
		if enemy:GetAttribute("Boss") and nearestDistance < 32 and os.clock() >= (enemy:GetAttribute("NextSlam") or 0) then
			bossSlam(enemy)
		end
		local attackRange = enemy:GetAttribute("AttackRange") or 5
		if nearestDistance < attackRange and os.clock() >= (enemy:GetAttribute("NextHit") or 0) then
			enemy:SetAttribute("NextHit", os.clock() + (enemy:GetAttribute("AttackCooldown") or 1.2))
			if os.clock() <= nearest.Session.DodgeUntil then
				FX:FireClient(nearest.Player, { Kind = "Dodge" })
			else
				nearest.Humanoid:TakeDamage(enemy:GetAttribute("AttackDamage") or Config.Zones[zoneId].EnemyDamage)
				FX:FireClient(nearest.Player, { Kind = "Struck", Position = enemyRoot.Position })
			end
		end
	end
end

task.spawn(function()
	while task.wait(0.4) do
		local ok, err = pcall(stepEnemies)
		if not ok then warn(`Soul Grind enemy step failed: {err}`) end
	end
end)

local function stepSessions()
	for player, session in sessions do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and os.clock() - session.LastAction < 90 then
			session.UnsavedSeconds += 1
		end

		if session.UnsavedSeconds >= 60 then
			local seconds = session.UnsavedSeconds
			session.UnsavedSeconds = 0
			local saved = mutate(player, function(profile) profile.DailyActiveSeconds += seconds end)
			if not saved then session.UnsavedSeconds += seconds end
		end

		local profile = Store.peek(player.UserId)
		local totalActive = profile and profile.DailyActiveSeconds + session.UnsavedSeconds or 0
		if profile and not profile.CheckInClaimed and profile.DailyActiveSeconds >= Config.CheckInSeconds and profile.DailyKills >= Config.CheckInMinKills then
			local rewarded = false
			local saved = mutate(player, function(current)
				if not current.CheckInClaimed and current.DailyActiveSeconds >= Config.CheckInSeconds and current.DailyKills >= Config.CheckInMinKills then
					current.CheckInClaimed = true
					current.Wallet.Flares += 2
					rewarded = true
				end
			end)
			if saved and rewarded then showNotice(player, "Active check-in complete: +2 free Soul Flares.") end
		end
		if totalActive % 5 == 0 then publish(player) end
	end
end

task.spawn(function()
	while task.wait(1) do
		local ok, err = pcall(stepSessions)
		if not ok then warn(`Soul Grind session step failed: {err}`) end
	end
end)
