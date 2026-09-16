local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local root = ReplicatedStorage:WaitForChild("SoulGrind")
local Config = require(root.Config)
local Quests = require(root.Quests)
local Model = require(script.Parent.Model)
local Store = require(script.Parent.Store)
local Commerce = require(script.Parent.Commerce)
local World = require(script.Parent.World)

local Action = root:WaitForChild("Action")
local State = root:WaitForChild("State")
local Notice = root:WaitForChild("Notice")
local FX = root:WaitForChild("FX")

local palette = Config.Palette
local sessions = {}
local enemies = {}

local built = World.build()
local world = built.Folder

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

local function abilityCosts(profile)
	local costs = {}
	for _, def in Config.Abilities do
		costs[def.Key] = Model.abilityCost(def.BaseCost, def.Growth, Model.rank(profile, def.Key))
	end
	return costs
end

-- The world signs and the HUD banner read the same active quest, so the answer to
-- "what am I supposed to do" is identical wherever the player looks.
local function publish(player)
	local profile = Store.peek(player.UserId)
	local session = sessions[player]
	if not profile or not session then return end
	updateLeaderstats(player, profile)

	local quests = Quests.snapshot(profile)
	local progress = {}
	for _, row in quests.Rows do progress[row.Id] = row.Value end

	if quests.Active then
		World.setObjective(quests.Active.Title:upper(), `{quests.Active.Detail}\n\n{quests.Active.Hint}`)
	else
		World.setObjective("ALL CHARGES BOUND", "Every quest is complete. Rebirth again or help a friend through the Ash Gate.")
	end

	State:FireClient(player, {
		Revision = profile.Revision,
		Souls = profile.Souls,
		Level = profile.Level,
		Rebirths = profile.Rebirths,
		MaxZone = profile.MaxZone,
		Kills = profile.Kills,
		DeepKills = profile.DeepKills,
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
		Upgrades = profile.Upgrades,
		AbilityCosts = abilityCosts(profile),
		-- Only the numbers travel; titles and hints come from the shared Quests module.
		Quests = {
			Progress = progress,
			ActiveId = quests.Active and quests.Active.Id or nil,
			Completed = quests.Completed,
			Total = quests.Total,
			Rate = quests.Rate,
		},
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
	highlight.FillColor = palette.CrimsonLit
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = palette.GoldLight
	highlight.OutlineTransparency = 0.15
	highlight.Parent = character
end

-- Quest rewards commit inside the same profile write that produced the progress, so a
-- reward can never be granted twice or granted without the progress that earned it.
local function settleQuests(profile, awarded)
	local snapshot = Quests.snapshot(profile)
	for _, row in snapshot.Rows do
		if row.Done and not profile.QuestsPaid[row.Id] then
			profile.QuestsPaid[row.Id] = true
			profile.Souls += row.Reward
			table.insert(awarded, row)
		end
	end
end

local function mutate(player, transform)
	local awarded = {}
	local success, profile = Store.update(player.UserId, function(current)
		-- UpdateAsync may run this more than once; never let an award list accumulate.
		table.clear(awarded)
		transform(current)
		Model.applyMilestones(current)
		settleQuests(current, awarded)
		return current
	end)
	if success then
		publish(player)
		for _, row in awarded do
			showNotice(player, `QUEST COMPLETE — {row.Title}   +{row.Reward} Souls`)
			FX:FireClient(player, { Kind = "Quest", Title = row.Title, Reward = row.Reward })
		end
	else
		showNotice(player, "The Underworld could not save that action. Try again.")
	end
	return success, profile
end

local function teleportToZone(player, zoneId)
	local profile = Store.peek(player.UserId)
	local session = sessions[player]
	if not profile or not session or zoneId < 1 or zoneId > profile.MaxZone then return false end
	session.Zone = zoneId
	local character = player.Character
	if character then character:PivotTo(World.arrivalCFrame(zoneId)) end
	publish(player)
	return true
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
		local profile = Store.peek(player.UserId)
		showNotice(player, `The Ash Gate needs 150 Souls. You hold {profile and profile.Souls or 0}.`)
	else
		if outcome == "unlocked" then showNotice(player, "The Ash Gate is open. The Molten Reliquary lies beyond.") end
		teleportToZone(player, 2)
	end
end

built.GatePrompt.Triggered:Connect(unlockZone)
built.ReturnPrompt.Triggered:Connect(function(player)
	teleportToZone(player, 1)
end)

-- Enemies -------------------------------------------------------------------
-- Bodies are mid-tone on purpose: not black silhouettes, not glowing. They read
-- against the lit floor by contrast and hue, and only the player's current target
-- gets an outline, drawn client-side.

local archetypes = {
	Shade = {
		Name = "CINDER SHADE", Health = 1, Damage = 1, Speed = 11, Reward = 1, Range = 5, Cooldown = 1.15,
		Body = Color3.fromRGB(96, 72, 78), Trim = Color3.fromRGB(255, 96, 86),
	},
	Reaver = {
		Name = "BONE REAVER", Health = 1.75, Damage = 1.35, Speed = 8, Reward = 1.65, Range = 6, Cooldown = 1.55,
		Body = Color3.fromRGB(118, 80, 52), Trim = Color3.fromRGB(255, 158, 70),
	},
	Wisp = {
		Name = "ASH WISP", Health = 0.7, Damage = 0.8, Speed = 14, Reward = 1.25, Range = 4.5, Cooldown = 0.9,
		Body = Color3.fromRGB(206, 190, 146), Trim = Color3.fromRGB(255, 244, 196),
	},
	Warden = {
		Name = "GILDED WARDEN", Health = 4.5, Damage = 1.55, Speed = 7, Reward = 5, Range = 7, Cooldown = 1.4,
		Body = Color3.fromRGB(132, 58, 50), Trim = Color3.fromRGB(255, 196, 92),
	},
}

local postOrder = { "Shade", "Shade", "Wisp", "Reaver", "Shade", "Wisp", "Reaver", "Reaver", "Shade" }

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
	label.TextColor3 = Color3.fromRGB(246, 236, 222)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(12, 6, 8)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Parent = gui

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.new(1, -20, 0, 9)
	back.Position = UDim2.fromOffset(10, 27)
	back.BackgroundColor3 = Color3.fromRGB(18, 10, 12)
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
	return label
end

local function spawnEnemy(zoneId, postIndex)
	local zone = Config.Zones[zoneId]
	local boss = zoneId == 2 and postIndex == 9
	local kind = boss and "Warden" or postOrder[postIndex]
	local archetype = archetypes[kind]
	local home = World.posts(zoneId)[postIndex]

	local model = Instance.new("Model")
	model.Name = kind
	model:SetAttribute("Enemy", true)
	model:SetAttribute("Archetype", kind)
	model:SetAttribute("Zone", zoneId)
	model:SetAttribute("Boss", boss)
	model:SetAttribute("PostIndex", postIndex)
	model:SetAttribute("Home", home)
	model:SetAttribute("State", "Idle")
	model:SetAttribute("AttackDamage", math.floor(zone.EnemyDamage * archetype.Damage))
	model:SetAttribute("AttackRange", archetype.Range)
	model:SetAttribute("AttackCooldown", archetype.Cooldown)
	model:SetAttribute("SoulReward", math.floor(zone.SoulReward * archetype.Reward))

	local bodySize = boss and Vector3.new(5.4, 6.6, 4.4) or (kind == "Reaver" and Vector3.new(3.7, 4.8, 3.2) or Vector3.new(2.9, 4, 2.4))

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = bodySize
	rootPart.Transparency = 1
	rootPart.CanCollide = true
	rootPart.TopSurface = Enum.SurfaceType.Smooth
	rootPart.BottomSurface = Enum.SurfaceType.Smooth
	rootPart.CFrame = CFrame.new(home + Vector3.new(0, bodySize.Y / 2, 0))
	rootPart.Parent = model

	local armor, trim = archetype.Body, archetype.Trim
	enemyPart(model, rootPart, "Torso", bodySize, CFrame.new(), armor, Enum.Material.Slate, kind == "Wisp" and Enum.PartType.Ball or Enum.PartType.Block)
	local headHeight = boss and 4.6 or (kind == "Reaver" and 3.4 or 2.9)
	enemyPart(model, rootPart, "Head", boss and Vector3.new(3.1, 3.1, 3.1) or Vector3.new(2, 2, 2), CFrame.new(0, headHeight, 0), armor, Enum.Material.Slate, Enum.PartType.Ball)
	-- Eyes and a small chest ember are the only bright pixels on an enemy.
	enemyPart(model, rootPart, "Eye", boss and Vector3.new(1.4, 0.4, 0.3) or Vector3.new(0.95, 0.26, 0.22), CFrame.new(0, headHeight + 0.15, -1), trim, Enum.Material.Neon)
	local core = enemyPart(model, rootPart, "SoulCore", boss and Vector3.new(1.5, 1.5, 0.4) or Vector3.new(0.85, 0.85, 0.3), CFrame.new(0, 0.2, -bodySize.Z / 2 - 0.15), trim, Enum.Material.Neon, Enum.PartType.Ball)
	enemyPart(model, rootPart, "Girdle", Vector3.new(bodySize.X + 0.3, 0.7, bodySize.Z + 0.3), CFrame.new(0, -bodySize.Y * 0.18, 0), palette.Iron, Enum.Material.Metal)

	if kind == "Wisp" then
		enemyPart(model, rootPart, "Tail", Vector3.new(1.4, 3.3, 1.4), CFrame.new(0, -2.6, 0) * CFrame.Angles(0, 0, math.rad(45)), armor, Enum.Material.Slate, Enum.PartType.Ball, 0.35)
	else
		for side = -1, 1, 2 do
			local armSize = boss and Vector3.new(1.6, 5.4, 1.6) or Vector3.new(1, kind == "Reaver" and 4.2 or 3.5, 1)
			enemyPart(model, rootPart, "Arm", armSize, CFrame.new(side * (bodySize.X / 2 + 0.7), 0, 0) * CFrame.Angles(0, 0, math.rad(side * -9)), armor, Enum.Material.Slate)
			if boss or kind == "Reaver" then
				enemyPart(model, rootPart, "Horn", Vector3.new(0.7, boss and 3.8 or 2.6, 0.7), CFrame.new(side * 1.2, headHeight + 1.7, 0) * CFrame.Angles(0, 0, math.rad(side * -24)), boss and palette.Gold or palette.Bone, Enum.Material.Metal)
			end
		end
	end

	local glow = Instance.new("PointLight")
	glow.Color = trim
	glow.Brightness = boss and 1.4 or 0.7
	glow.Range = boss and 16 or 9
	glow.Shadows = false
	glow.Parent = core

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

	local titleLabel = addEnemyBar(rootPart, humanoid, archetype.Name, trim, bodySize.Y / 2 + (boss and 5.5 or 3.6))
	model:SetAttribute("BaseSpeed", archetype.Speed)
	enemies[model] = { Title = titleLabel, Name = archetype.Name }

	humanoid.Died:Connect(function()
		enemies[model] = nil
		FX:FireAllClients({ Kind = "Death", Position = rootPart.Position, Color = trim, Boss = boss })
		local userId = model:GetAttribute("LastHitUserId")
		local player = type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
		if player and os.clock() - (model:GetAttribute("LastHitAt") or 0) <= 12 then
			local friendMultiplier = sessions[player] and sessions[player].FriendBonus and 1.1 or 1
			local reward = math.floor((model:GetAttribute("SoulReward") or zone.SoulReward) * friendMultiplier)
			local granted = mutate(player, function(profile)
				profile.Souls += reward
				profile.Kills += 1
				profile.DailyKills += 1
				if zoneId == 2 then profile.DeepKills += 1 end
				if boss then profile.Bosses += 1 end
			end)
			if granted then showNotice(player, `+{reward} Souls{boss and "   •   The Warden falls." or ""}`) end
		end
		Debris:AddItem(model, 1.4)
		task.delay(boss and 14 or 6, function()
			if world.Parent then spawnEnemy(zoneId, postIndex) end
		end)
	end)
end

for zoneId in Config.Zones do
	for postIndex = 1, #postOrder do spawnEnemy(zoneId, postIndex) end
end

-- Combat --------------------------------------------------------------------

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

-- Being hit wakes an enemy regardless of range, so a ranged opener cannot be used to
-- whittle something down from outside its aggro radius.
local function alert(enemy, player)
	if enemy:GetAttribute("State") ~= "Chasing" then
		enemy:SetAttribute("State", "Chasing")
		local entry = enemies[enemy]
		if entry then entry.Title.Text = `! {entry.Name}` end
	end
	enemy:SetAttribute("Target", player.UserId)
end

local function hitEnemy(player, enemy, damage, combo)
	local humanoid = enemy and enemy:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	enemy:SetAttribute("LastHitUserId", player.UserId)
	enemy:SetAttribute("LastHitAt", os.clock())
	alert(enemy, player)

	local flash = Instance.new("Highlight")
	flash.Name = "HitFlash"
	flash.FillColor = palette.GoldPale
	flash.FillTransparency = 0.25
	flash.OutlineColor = palette.GoldPale
	flash.OutlineTransparency = 0.3
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
		if direction.Magnitude > 0 then enemy.PrimaryPart.AssemblyLinearVelocity += direction.Unit * 24 + Vector3.new(0, 8, 0) end
		-- Strike rank 3 turns the finisher into a small shockwave.
		if Model.strikeKnocksBack(profile) then
			for other in enemies do
				if other ~= enemy and other.PrimaryPart and other:GetAttribute("Zone") == session.Zone
					and (other.PrimaryPart.Position - characterRoot.Position).Magnitude <= 16 then
					hitEnemy(player, other, math.floor(Model.damage(profile) * 0.6), 0)
				end
			end
		end
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
	local radius = Model.pulseRange(profile, Config.PulseRange)
	local struck = 0
	for enemy in enemies do
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if enemy.PrimaryPart and humanoid and humanoid.Health > 0 and enemy:GetAttribute("Zone") == session.Zone
			and (enemy.PrimaryPart.Position - playerRoot.Position).Magnitude <= radius then
			hitEnemy(player, enemy, math.floor(Model.damage(profile) * Model.pulseMultiplier(profile)), 0)
			struck += 1
		end
	end
	FX:FireClient(player, { Kind = "Pulse", Position = playerRoot.Position, Hits = struck, Cooldown = Config.Cooldowns.Pulse, Radius = radius })
	showNotice(player, struck > 0 and `Soul Pulse struck {struck}.` or "Soul Pulse found nothing in range.")

	local wave = World.makePart(world, "SoulPulse", Vector3.new(1, 1, 1), CFrame.new(playerRoot.Position), palette.CrimsonLit, Enum.Material.Neon)
	wave.Shape = Enum.PartType.Ball
	wave.CanCollide = false
	task.spawn(function()
		for size = 2, radius * 2, 4 do
			wave.Size = Vector3.new(size, size, size)
			wave.Transparency = 0.3 + size / (radius * 2.8)
			task.wait(0.025)
		end
		wave:Destroy()
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

	local profile = Store.peek(player.UserId)
	local cooldown = profile and Model.dashCooldown(profile, Config.Cooldowns.Dash) or Config.Cooldowns.Dash
	session.NextDash = now + cooldown
	session.DodgeUntil = now + (profile and Model.dodgeWindow(profile) or 0.55)
	session.Combo = 0
	playerRoot.AssemblyLinearVelocity = playerRoot.CFrame.LookVector * 74 + Vector3.new(0, 5, 0)
	FX:FireAllClients({ Kind = "Dash", Player = player, Cooldown = cooldown })
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
	emitter.Color = ColorSequence.new(palette.GoldPale, palette.CrimsonLit)
	emitter.Lifetime = NumberRange.new(1.2, 2)
	emitter.Speed = NumberRange.new(12, 24)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = playerRoot
	emitter:Emit(70)
	Debris:AddItem(emitter, 3)
end

local function refreshFriends()
	for _, session in sessions do session.FriendBonus = false end
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
	Sync = true, Attack = true, Pulse = true, Dash = true, Upgrade = true, UpgradeMove = true,
	UnlockZone = true, Travel = true, Rebirth = true, ClaimDaily = true, Flare = true, Aura = true,
}

Commerce.init(Store, publish, showNotice, applyAura)

local function upgradeMove(player, key)
	local def
	for _, entry in Config.Abilities do
		if entry.Key == key then def = entry end
	end
	if not def then return end

	local outcome, cost
	local success = mutate(player, function(profile)
		local rank = Model.rank(profile, def.Key)
		if profile.Level < def.RequiresLevel then
			outcome = "locked"
			return
		end
		if rank >= def.Max then
			outcome = "max"
			return
		end
		cost = Model.abilityCost(def.BaseCost, def.Growth, rank)
		if profile.Souls < cost then
			outcome = "poor"
			return
		end
		profile.Souls -= cost
		profile.Upgrades[def.Key] = rank + 1
		outcome = "ranked"
	end)
	if not success then return end

	if outcome == "ranked" then
		local profile = Store.peek(player.UserId)
		showNotice(player, `{def.Name} is now rank {profile and Model.rank(profile, def.Key) or "?"}.`)
		FX:FireClient(player, { Kind = "Ranked", Ability = def.Key })
	elseif outcome == "max" then
		showNotice(player, `{def.Name} is already at its highest rank.`)
	elseif outcome == "locked" then
		showNotice(player, `{def.Name} needs Soul Level {def.RequiresLevel}.`)
	else
		showNotice(player, `{def.Name} rank up costs {cost or 0} Souls.`)
	end
end

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
	elseif actionName == "UpgradeMove" then
		if type(payload) == "string" then upgradeMove(player, payload) end
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
			else showNotice(player, `Open the Ash Gate and hold {cost} Souls to rebirth.`) end
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
			billboard.MaxDistance = 140
			billboard.Parent = head
			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextColor3 = palette.GoldLight
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
	showNotice(player, "Read the sign ahead, then strike the nearest shade.")
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
	local center = Vector3.new(enemyRoot.Position.X, zone.Origin.Y + built.FloorY + 0.2, enemyRoot.Position.Z)

	local warning = World.makePart(world, "WardenWarning", Vector3.new(0.22, 2, 2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), palette.CrimsonLit, Enum.Material.Neon)
	warning.Shape = Enum.PartType.Cylinder
	warning.Transparency = 0.5
	warning.CanCollide = false
	FX:FireAllClients({ Kind = "BossCharge", Position = center })

	TweenService:Create(warning, TweenInfo.new(1.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.22, 38, 38), Transparency = 0.22,
	}):Play()

	task.delay(1.15, function()
		if warning.Parent then warning:Destroy() end
		if not enemy.Parent or not enemy.PrimaryPart then return end
		FX:FireAllClients({ Kind = "BossSlam", Position = center })
		for player, session in sessions do
			local character = player.Character
			local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if session.Zone == zoneId and playerRoot and humanoid and humanoid.Health > 0 and (playerRoot.Position - center).Magnitude <= 19 then
				if os.clock() <= session.DodgeUntil then
					FX:FireClient(player, { Kind = "Dodge" })
				else
					humanoid:TakeDamage(math.floor((enemy:GetAttribute("AttackDamage") or zone.EnemyDamage) * 1.7))
					FX:FireClient(player, { Kind = "Struck", Position = center })
				end
			end
		end
		enemy:SetAttribute("SlamCharging", false)
	end)
end

-- Enemy behaviour -----------------------------------------------------------
-- Three states. An enemy holds its post until you come inside Engage, chases while you
-- stay inside Leash, then walks home and heals. Nothing trails the player forever, and
-- nothing attacks from across the arena.

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

local STEP = 0.4

local function setState(enemy, state)
	if enemy:GetAttribute("State") == state then return end
	enemy:SetAttribute("State", state)
	local entry = enemies[enemy]
	if entry then
		entry.Title.Text = state == "Chasing" and `! {entry.Name}` or entry.Name
	end
end

local function stepEnemies()
	local targets = livingTargets()
	local aggro = Config.Aggro

	for enemy in enemies do
		local enemyRoot = enemy.PrimaryPart
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if not enemy.Parent or not enemyRoot or not humanoid or humanoid.Health <= 0 then continue end

		local zoneId = enemy:GetAttribute("Zone")
		local home = enemy:GetAttribute("Home") or enemyRoot.Position
		local baseSpeed = enemy:GetAttribute("BaseSpeed") or 10
		local state = enemy:GetAttribute("State") or "Idle"
		local homeDistance = (enemyRoot.Position - home).Magnitude

		local nearest, nearestDistance
		for _, target in targets do
			if target.Session.Zone == zoneId then
				local distance = (target.Root.Position - enemyRoot.Position).Magnitude
				if not nearestDistance or distance < nearestDistance then
					nearest, nearestDistance = target, distance
				end
			end
		end

		if state == "Chasing" then
			local lost = not nearest or nearestDistance > aggro.Leash or homeDistance > aggro.Leash
			if lost then setState(enemy, "Returning") end
		elseif nearest and nearestDistance <= aggro.Engage and homeDistance <= aggro.Leash then
			setState(enemy, "Chasing")
		end
		state = enemy:GetAttribute("State")

		if state == "Chasing" and nearest then
			humanoid.WalkSpeed = baseSpeed
			humanoid:MoveTo(nearest.Root.Position)

			if enemy:GetAttribute("Boss") and nearestDistance < 34 and os.clock() >= (enemy:GetAttribute("NextSlam") or 0) then
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
		else
			-- Disengaged: walk home a little faster than it chased, and heal on the way.
			humanoid.WalkSpeed = baseSpeed * aggro.ReturnSpeed
			if homeDistance > 4 then
				humanoid:MoveTo(home)
			elseif state == "Returning" then
				setState(enemy, "Idle")
			end
			if humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + aggro.RegenPerSecond * STEP)
			end
		end
	end
end

task.spawn(function()
	while task.wait(STEP) do
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
