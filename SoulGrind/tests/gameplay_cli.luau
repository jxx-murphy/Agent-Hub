--!nocheck
-- End-to-end checks. Runs the real Main.server.luau, World.luau and Client.client.luau
-- against tests/roblox_stub.luau, so a broken keybind, a dead RemoteEvent, a wrong attack
-- range, a silent cooldown, an unreadable palette, a runaway enemy or a free ability rank
-- fails here instead of in Play Solo.
--
--   lune run tests/gameplay_cli.luau

local process = require("@lune/process")
local task = require("@lune/task")

local stub = require("./roblox_stub")
stub.build((process.cwd:gsub("[\\/]+$", "")))

local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end

local function luminance(color)
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
end

local function band(value, low, high, label)
	check(value >= low, `{label} is too low at {value}, needs at least {low}`)
	check(value <= high, `{label} is too high at {value}, needs at most {high}`)
end

-- ---------------------------------------------------------------- startup ---
stub.runServer()

local world = stub.Workspace:FindFirstChild("SoulGrindWorld")
check(world ~= nil, "the world folder must be built at startup")

local Config = stub.loadModule(`{stub.root}/src/shared/Config.luau`, nil)
local QuestDefs = stub.loadModule(`{stub.root}/src/shared/Quests.luau`, nil)

check(#stub.enemies(1) == 9, `zone 1 must hold nine enemies, saw {#stub.enemies(1)}`)
check(#stub.enemies(2) == 9, `zone 2 must hold nine enemies, saw {#stub.enemies(2)}`)

local boss
for _, enemy in stub.enemies(2) do
	if enemy:GetAttribute("Boss") then boss = enemy end
end
check(boss ~= nil, "zone 2 must contain the Warden")

-- ----------------------------------------------------------- the map size ---
-- "Bigger map" is a requirement, so it gets a number rather than a vibe.
local zoneArea = Config.ArenaHalf.X * 2 * Config.ArenaHalf.Z * 2
check(zoneArea >= 50000, `each arena must be far larger than the old pad, saw {math.floor(zoneArea)} sq studs`)
local gap = (Config.Zones[2].Origin - Config.Zones[1].Origin).Magnitude
check(gap > Config.ArenaHalf.X * 2, "the two zones must not overlap")

local posts = {}
for _, enemy in stub.enemies(1) do table.insert(posts, enemy:GetAttribute("Home")) end
local widest = 0
for _, a in posts do
	for _, b in posts do widest = math.max(widest, (a - b).Magnitude) end
end
check(widest > 120, `enemies must be spread across the arena, widest gap was {math.floor(widest)} studs`)

-- ------------------------------------------------------------ readability ---
-- A band, not a floor. Too dark reads as a black screen; too bright washed the whole
-- arena into a magenta smear. Both walls are asserted so neither mistake returns.
band(luminance(stub.Lighting.Ambient), 0.16, 0.32, "ambient luminance")
band(luminance(stub.Lighting.OutdoorAmbient), 0.2, 0.38, "outdoor ambient luminance")
band(stub.Lighting.Brightness, 1.5, 2.4, "global brightness")
band(stub.Lighting.ExposureCompensation, -0.4, 0.15, "exposure compensation")
-- Tight on purpose: the map has to reveal itself as you walk into it.
band(stub.Lighting.FogStart, 55, 200, "fog start")

local atmosphere = stub.Lighting:FindFirstChildOfClass("Atmosphere")
check(atmosphere ~= nil, "the underworld needs an Atmosphere")
band(atmosphere.Density, 0.15, 0.36, "atmosphere density")
check(stub.Lighting:FindFirstChild("SoulDepth") == nil, "depth of field blurs the silhouettes players need")

local bloom = stub.Lighting:FindFirstChild("SoulBloom")
check(bloom ~= nil and bloom.Intensity <= 0.3, "bloom this strong turns every lit edge into a white halo")
check(bloom.Threshold >= 2, "a low bloom threshold blooms surfaces that are not meant to glow")
local grade = stub.Lighting:FindFirstChild("UnderworldGrade")
check(grade ~= nil and grade.Brightness <= 0.02, "colour grading must not stack more exposure on top")
check(grade.Saturation <= 0.05, "the palette is already saturated; grading must not push it further")

-- Light budget as density, so it scales with the map instead of being re-tuned by hand.
local budget = stub.lightBudget()
check(budget.Count >= 12, "an arena this size needs local light sources, not just ambient")
check(budget.Brightest <= 3, `a light at brightness {budget.Brightest} blows out everything near it`)
check(budget.Longest <= 52, `a light with range {budget.Longest} floods the whole arena`)
local density = budget.Load / (zoneArea * 2)
check(density <= 0.12, `light density {string.format("%.3f", density)} per sq stud washes the arena out`)

-- -------------------------------------------------------------- palette ---
-- Crimson and gold. No blue, and nothing neon outside flame, lava and the telegraph.
local function isBlue(color)
	return color.B > color.R + 0.08 and color.B > color.G + 0.08
end

-- Enemies are measured separately: their eyes and chest ember are deliberate, and
-- counting them alongside scenery would hide a glowing floor behind a good average.
local inEnemy = {}
for _, enemy in stub.enemies() do
	for _, node in enemy:GetDescendants() do inEnemy[node] = true end
end

local floors, blueParts, neonScenery, scenery, widestGlow = 0, 0, 0, 0, 0
local floorLuminance
for _, node in world:GetDescendants() do
	if node.ClassName == "Part" or node.ClassName == "SpawnLocation" then
		if isBlue(node.Color) then blueParts += 1 end
		local neon = node.Material and node.Material.Name == "Neon"
		if neon then
			-- The magenta whiteout was caused by big glowing slabs, so cap the face area
			-- of any one emissive surface rather than just counting them.
			local size = node.Size
			local face = math.max(size.X * size.Y, size.Y * size.Z, size.X * size.Z)
			widestGlow = math.max(widestGlow, face)
		end
		if not inEnemy[node] then
			scenery += 1
			if neon then neonScenery += 1 end
		end
		if node.Name == "ArenaFloor" then
			floors += 1
			floorLuminance = floorLuminance or luminance(node.Color)
			band(luminance(node.Color), 0.22, 0.45, "arena floor luminance")
		end
	end
end
check(floors == 2, "both zones need a readable arena floor")
check(blueParts == 0, `the palette must carry no blue surfaces, found {blueParts}`)
check(neonScenery / scenery < 0.12, `neon is on {math.floor(neonScenery / scenery * 100)}% of scenery; it is meant to be rationed`)
check(widestGlow <= 900, `a single emissive face of {math.floor(widestGlow)} sq studs is a glowing slab, not an accent`)

for _, enemy in stub.enemies(1) do
	local glowing = 0
	for _, node in enemy:GetDescendants() do
		if node.ClassName == "Part" and node.Material and node.Material.Name == "Neon" then glowing += 1 end
	end
	check(glowing <= 2, `{enemy.Name} has {glowing} glowing parts; eyes and a core are the budget`)
end

-- --------------------------------------------- aesthetics beyond the pad ---
local function countNamed(name)
	local total = 0
	for _, node in world:GetDescendants() do
		if node.Name == name then total += 1 end
	end
	return total
end
check(countNamed("CurtainWall") >= 8, "both zones must be walled, not floating pads")
check(countNamed("Merlon") >= 60, "battlements are what make a wall read as a fortification")
check(countNamed("TowerShaft") >= 12, "the kingdom needs towers on its walls and gates")
check(countNamed("HouseWall") >= 18, "a village means buildings, not an empty arena")
check(countNamed("Roof") >= 60, "pitched roofs are most of the medieval silhouette")
check(countNamed("Door") >= 18, "buildings need doors to read as buildings")
check(countNamed("Cobble") >= 3, "streets give the town a shape to walk along")
check(countNamed("Banner") >= 10, "banners make the ruin read as inhabited")
check(countNamed("FarRidge") >= 10, "a distant ridge gives the sky something to cut against")
check(countNamed("Portcullis") >= 5, "the gatehouse needs a gate")

-- Buildings must actually stand between the spawn and the far end of the map, or the
-- player can read the whole level from the entrance.
local blockers, spawnZ = 0, Config.ArenaHalf.Z - 30
for _, node in world:GetDescendants() do
	if node.Name == "HouseWall" or node.Name == "TowerShaft" or node.Name == "CurtainWall" then
		if node.Size.Y >= 12 and node.CanCollide then blockers += 1 end
	end
end
check(blockers >= 25, `only {blockers} tall solid structures; sightlines stay wide open`)

-- ------------------------------------------------------ enemy readability ---
-- Mid-tone bodies: not black silhouettes, not blown out. They read by contrast and hue.
floorLuminance = floorLuminance or 0.32
local seen = {}
for _, enemy in stub.enemies(1) do
	seen[enemy:GetAttribute("Archetype")] = true
	local torso = enemy:FindFirstChild("Torso")
	check(torso ~= nil, `{enemy.Name} has no body`)
	local tone = luminance(torso.Color)
	band(tone, 0.25, 0.72, `{enemy.Name} body tone`)
	check(math.abs(tone - floorLuminance) > 0.07, `{enemy.Name} is too close to the floor tone to read`)
	check(enemy:FindFirstChild("SoulOutline") == nil, "enemies must not carry a permanent outline any more")
	check(enemy:FindFirstChild("Eye") ~= nil, `{enemy.Name} needs eyes to read at distance`)
	check(enemy.PrimaryPart.CanCollide == true, `{enemy.Name} must stand on the floor, not sink through it`)
end
check(seen.Shade and seen.Reaver and seen.Wisp, "zone 1 must mix archetypes")

-- ----------------------------------------------------------- player join ---
local player = stub.addPlayer("Tester", 7001)
check(stub.kicked == nil, `the join path kicked the player: {tostring(stub.kicked)}`)
check(player:FindFirstChild("leaderstats") ~= nil, "leaderstats must exist after joining")

stub.runClient()
local character = stub.spawnCharacter(player, stub.vec3(0, 6, 88))
check(character ~= nil, "character rig must spawn")

local Action = stub.remotes:FindFirstChild("Action")
for _, name in { "Action", "State", "Notice", "Offer", "FX" } do
	check(stub.remotes:FindFirstChild(name) ~= nil, `the {name} RemoteEvent must exist`)
end

local function syncState()
	stub.advance(0.2)
	stub.clearClientEvents()
	Action.OnServerEvent:Fire(player, "Sync")
	local states = stub.takeClientEvents("State")
	return states[#states]
end

local latest = syncState()
check(latest ~= nil, "the client never received a State payload")
check(latest.UpgradeCost == 20, `first upgrade must cost 20 souls, saw {latest.UpgradeCost}`)

-- -------------------------------------------------------- the objective ---
-- The number one complaint was "what is the point". It has to be answerable from the
-- state payload, from the HUD, and from a sign standing in the world.
check(latest.Quests ~= nil, "state must carry the quest chain")
check(latest.Quests.Total == QuestDefs.count, "the quest total must match the shared definitions")
check(latest.Quests.Completed == 0, "a fresh profile has completed nothing")
check(latest.Quests.Rate == 0, "task completion rate must start at zero")
check(latest.Quests.ActiveId == "FirstSoul", `the first objective must be the first kill, saw {tostring(latest.Quests.ActiveId)}`)

local signs = stub.signText()
check(#signs >= 2, `the world needs readable signs, found {#signs}`)
local firstQuest = QuestDefs.byId("FirstSoul")
check(signs[1].Heading == firstQuest.Title:upper(), `the sign must show the active objective, showed "{tostring(signs[1].Heading)}"`)
check(tostring(signs[1].Body):find(firstQuest.Hint, 1, true) ~= nil, "the sign must carry the hint that teaches the objective")
check(stub.findGui("Objective") ~= nil, "the HUD needs an always-visible objective banner")

-- --------------------------------------------------------------- strike ---
for actionName, key in { SoulAttack = "F", SoulPulse = "Q", SoulStep = "E" } do
	local binding = stub.boundActions[actionName]
	check(binding ~= nil and binding.Keys[1].Name == key, `{actionName} must sit on {key}`)
end

local target = stub.livingEnemies(1)[1]
local targetRoot = target.PrimaryPart
local targetHumanoid = target:FindFirstChildOfClass("Humanoid")

local function readyTarget()
	targetHumanoid.Health = targetHumanoid.MaxHealth
	stub.moveTo(player, targetRoot.Position + stub.vec3(0, 0, 8))
	stub.advance(1)
end

readyTarget()
local startHealth = targetHumanoid.Health
stub.clearClientEvents()
stub.fireKey("SoulAttack", "F")
check(targetHumanoid.Health < startHealth, "pressing F must damage the enemy in front of the player")
check(#stub.takeClientEvents("FX", "Hit") == 1, "one F press must send exactly one Hit effect")
local swings = stub.takeClientEvents("FX", "Swing")
check(#swings == 1, "every strike must send a visible Swing, hit or miss")
check(swings[1].Cooldown > 0, "the swing must carry its cooldown so the button can drain")

stub.clearClientEvents()
stub.fireKey("SoulAttack", "F")
check(#stub.takeClientEvents("FX", "Hit") == 0, "the attack cooldown must reject a second immediate strike")
check(#stub.takeClientEvents("FX", "Cooling") == 1, "a cooling strike must still say why nothing happened")

readyTarget()
local beforeButton = targetHumanoid.Health
stub.clickButton("Attack")
check(targetHumanoid.Health < beforeButton, "the on-screen ATTACK button must land a hit")

readyTarget()
local beforeClick = targetHumanoid.Health
stub.inputBegan:Fire({ UserInputType = stub.Enum.UserInputType.MouseButton1 }, false)
check(targetHumanoid.Health < beforeClick, "a left click must strike")

readyTarget()
local beforeTouch = targetHumanoid.Health
stub.inputBegan:Fire({ UserInputType = stub.Enum.UserInputType.Touch }, false)
check(targetHumanoid.Health < beforeTouch, "a touch tap must strike")

readyTarget()
local beforeProcessed = targetHumanoid.Health
stub.inputBegan:Fire({ UserInputType = stub.Enum.UserInputType.MouseButton1 }, true)
check(targetHumanoid.Health == beforeProcessed, "a click consumed by the HUD must not also strike the world")

readyTarget()
stub.moveTo(player, targetRoot.Position + stub.vec3(0, 0, Config.AttackRange + 10))
stub.clearClientEvents()
stub.fireKey("SoulAttack", "F")
local misses = stub.takeClientEvents("FX", "Miss")
check(#misses == 1, "a strike with nothing in reach must report a miss, not fail silently")
check(type(misses[1].Distance) == "number", "the miss must say how far the nearest enemy is")

readyTarget()
stub.moveTo(player, targetRoot.Position + stub.vec3(0, 0, Config.AttackRange - 3))
stub.clearClientEvents()
stub.fireKey("SoulAttack", "F")
check(#stub.takeClientEvents("FX", "Hit") == 1, "an enemy inside Config.AttackRange must be hittable")

-- ------------------------------------------------------------- soul step ---
stub.advance(6)
stub.clearClientEvents()
local root = character:FindFirstChild("HumanoidRootPart")
root.AssemblyLinearVelocity = stub.vec3(0, 0, 0)
stub.fireKey("SoulStep", "E")
check(root.AssemblyLinearVelocity.Magnitude > 20, "Soul Step must move the player")
local dashes = stub.takeClientEvents("FX", "Dash")
check(#dashes == 1 and dashes[1].Cooldown == Config.Cooldowns.Dash, "the dash must carry the shared cooldown")

stub.clearClientEvents()
stub.fireKey("SoulStep", "E")
check(#stub.takeClientEvents("FX", "Dash") == 0, "Soul Step must respect its server cooldown")
check(tostring(stub.takeClientEvents("Notice")[1] or ""):find("recharge"), "a blocked Soul Step must say it is recharging")

-- ------------------------------------------------------------ first quest ---
-- Completing the opening objective must pay out, exactly once, and move the banner on.
local function strikeUntilDead(enemy)
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	local enemyRoot = enemy.PrimaryPart
	for _ = 1, 80 do
		if humanoid.Health <= 0 then return true end
		stub.moveTo(player, enemyRoot.Position + stub.vec3(0, 0, 6))
		stub.advance(1)
		Action.OnServerEvent:Fire(player, "Attack")
	end
	return humanoid.Health <= 0
end

local beforeQuest = syncState()
stub.clearClientEvents()
check(strikeUntilDead(stub.livingEnemies(1)[1]), "an enemy must be killable with repeated strikes")
local questEffects = stub.takeClientEvents("FX", "Quest")
check(#questEffects == 1, `the first kill must complete exactly one quest, saw {#questEffects}`)
check(questEffects[1].Title == firstQuest.Title, "the completed quest must be the active one")

local afterQuest = syncState()
check(afterQuest.Quests.Completed == 1, "one quest must be recorded as complete")
check(afterQuest.Quests.Rate > 0, "the task completion rate must move")
check(afterQuest.Quests.ActiveId ~= "FirstSoul", "the banner must advance to the next objective")
check(afterQuest.Souls >= beforeQuest.Souls + firstQuest.Reward, "the quest reward must be paid")

local signsAfter = stub.signText()
check(signsAfter[1].Heading ~= firstQuest.Title:upper(), "the world signs must advance with the quest")

-- Paying twice is the classic bug here, so it gets its own check.
local soulsBefore = syncState().Souls
for _ = 1, 3 do
	stub.advance(0.5)
	Action.OnServerEvent:Fire(player, "Sync")
end
check(syncState().Souls == soulsBefore, "a completed quest must never pay out a second time")

-- ------------------------------------------------------ ability upgrades ---
-- Ranks are bought on the server, capped there, and must actually change the numbers.
local strikeDef
for _, def in Config.Abilities do
	if def.Key == "Strike" then strikeDef = def end
end

stub.advance(0.5)
Action.OnServerEvent:Fire(player, "UpgradeMove", "Strike")
check(syncState().Upgrades.Strike == 0, "a rank the player cannot afford must not be granted")

for _ = 1, 6 do
	local alive = stub.livingEnemies(1)
	if #alive == 0 then break end
	strikeUntilDead(alive[1])
	if syncState().Souls >= strikeDef.BaseCost then break end
end

local beforeRank = syncState()
check(beforeRank.Souls >= strikeDef.BaseCost, "combat must be able to fund the first rank")
check(beforeRank.AbilityCosts.Strike == strikeDef.BaseCost, "the first rank must cost the base price")

stub.advance(0.5)
Action.OnServerEvent:Fire(player, "UpgradeMove", "Strike")
local ranked = syncState()
check(ranked.Upgrades.Strike == 1, `buying a rank must raise it, saw {ranked.Upgrades.Strike}`)
-- Buying the first rank also completes "Sharpen the Blade", which pays out in the same
-- write, so the expected balance has to account for whatever quests just landed.
local expected = beforeRank.Souls - strikeDef.BaseCost
for _, quest in QuestDefs.list do
	local was = (beforeRank.Quests.Progress[quest.Id] or 0) >= quest.Target
	local now = (ranked.Quests.Progress[quest.Id] or 0) >= quest.Target
	if now and not was then expected += quest.Reward end
end
check(ranked.Souls == expected, `a rank must cost exactly its price, expected {expected} saw {ranked.Souls}`)
check(ranked.Damage > beforeRank.Damage, "a Strike rank must actually raise damage")
check(ranked.AbilityCosts.Strike > strikeDef.BaseCost, "the next rank must cost more")

stub.advance(0.5)
Action.OnServerEvent:Fire(player, "UpgradeMove", "Pulse")
check(syncState().Upgrades.Pulse == 0, "a rank gated behind a soul level must stay locked")

stub.advance(0.5)
Action.OnServerEvent:Fire(player, "UpgradeMove", "NotAnAbility")
stub.advance(0.5)
Action.OnServerEvent:Fire(player, "UpgradeMove", 42)
stub.advance(0.5)
check(syncState().Upgrades.Strike == 1, "an unknown ability key must change nothing")

-- --------------------------------------------------- engage and disengage ---
-- The complaint was that enemies attack forever. They hold a post now.
local guard = stub.livingEnemies(1)[1]
local guardRoot = guard.PrimaryPart
local guardHumanoid = guard:FindFirstChildOfClass("Humanoid")
local home = guard:GetAttribute("Home")
check(home ~= nil, "every enemy must remember the post it holds")

stub.moveTo(player, home + stub.vec3(0, 0, Config.Aggro.Leash + 80))
guard:SetAttribute("State", "Idle")
task.wait(0.7)
check(guard:GetAttribute("State") == "Idle", "an enemy must ignore a player far outside its aggro radius")

stub.moveTo(player, home + stub.vec3(0, 0, Config.Aggro.Engage - 10))
task.wait(0.7)
check(guard:GetAttribute("State") == "Chasing", "an enemy must wake when the player enters its aggro radius")

stub.moveTo(player, home + stub.vec3(0, 0, Config.Aggro.Leash + 80))
task.wait(0.7)
check(guard:GetAttribute("State") ~= "Chasing", "an enemy must disengage once the player leaves the leash")

guardHumanoid.Health = guardHumanoid.MaxHealth * 0.4
local wounded = guardHumanoid.Health
task.wait(1.4)
check(guardHumanoid.Health > wounded, "a disengaged enemy must heal back at its post")

-- Being hit from outside the aggro radius must still wake it, or ranged pulls are free.
guard:SetAttribute("State", "Idle")
stub.moveTo(player, guardRoot.Position + stub.vec3(0, 0, 6))
stub.advance(2)
Action.OnServerEvent:Fire(player, "Attack")
check(guard:GetAttribute("State") == "Chasing", "an enemy that is struck must wake regardless of range")

-- ------------------------------------------------------- action allowlist ---
local beforeJunk = syncState()
stub.advance(0.5)
Action.OnServerEvent:Fire(player, "GiveMeSouls", 9999)
stub.advance(0.5)
Action.OnServerEvent:Fire(player, { Souls = 9999 })
stub.advance(0.5)
local afterJunk = syncState()
check(afterJunk.Souls == beforeJunk.Souls, "unknown actions must not change the profile")
check(afterJunk.Level == beforeJunk.Level, "unknown actions must not change the level")

-- --------------------------------------------------------------- commerce ---
local MarketplaceService = stub.services.MarketplaceService
check(type(MarketplaceService.ProcessReceipt) == "function", "Commerce must own MarketplaceService.ProcessReceipt")
local decision = MarketplaceService.ProcessReceipt({
	PlayerId = player.UserId, ProductId = 4242, PurchaseId = "test-purchase-1", CurrencySpent = 49,
})
check(decision == stub.Enum.ProductPurchaseDecision.NotProcessedYet,
	"a receipt must stay unresolved while saving is off, so Roblox can redeliver it")

local Receipt = stub.require(stub.services.ServerScriptService:FindFirstChild("Receipt"))
local catalog = { [4242] = { Item = "Flares", Amount = 5 } }
local ledger = { Wallet = { Flares = 0 }, Receipts = {}, LastSpendDay = -1, SpendDays = 0 }
local granted, outcome = Receipt.apply(ledger, { PurchaseId = "p1", ProductId = 4242 }, catalog, 86400)
check(granted and outcome == "granted" and ledger.Wallet.Flares == 5, "a first receipt must grant once")
granted, outcome = Receipt.apply(ledger, { PurchaseId = "p1", ProductId = 4242 }, catalog, 86400)
check(granted and outcome == "duplicate" and ledger.Wallet.Flares == 5, "a redelivered receipt must not grant twice")

-- ------------------------------------------------------- HUD wiring check ---
check(stub.findGui("HUD") ~= nil, "the HUD must exist")
check(stub.findGui("Controls") ~= nil, "the HUD must tell the player which keys do what")
check(stub.findGui("Abilities") ~= nil, "the three abilities must live in one scaling bar")
check(stub.findGui("QUESTSPage") ~= nil, "the Journal needs a quest guide page")
check(stub.findGui("MOVESPage") ~= nil, "the Journal needs a move upgrade page")
for _, name in { "Attack", "Pulse", "Dash" } do
	local control = stub.findGui(name)
	check(control ~= nil and control:FindFirstChild("Cool") ~= nil, `{name} needs a visible cooldown drain`)
end
for _, quest in QuestDefs.list do
	check(stub.findGui(quest.Id) ~= nil, `the quest guide is missing a row for {quest.Title}`)
end

local outline = stub.findGui("TargetOutline")
check(outline ~= nil, "the client must own a single target outline")

stub.moveTo(player, stub.livingEnemies(1)[1].PrimaryPart.Position + stub.vec3(0, 0, 10))
stub.renderStepped:Fire(1)
local plate = stub.findGui("Target")
check(plate ~= nil and plate.Visible == true, "a nearby enemy must show the target plate")
check(outline.Enabled == true and outline.Adornee ~= nil, "the current target must be the only outlined enemy")
local rangeLabel = stub.findGui("Range")
check(tostring(rangeLabel.Text):find("IN RANGE"), "the plate must say when the target is reachable")

-- Enemies die and respawn during this run, so the spot has to be found rather than
-- hardcoded: somewhere an enemy is still tracked but genuinely out of reach.
local function nearestLivingDistance()
	local characterRoot = character:FindFirstChild("HumanoidRootPart")
	local best
	for _, enemy in stub.livingEnemies(1) do
		local distance = (enemy.PrimaryPart.Position - characterRoot.Position).Magnitude
		if not best or distance < best then best = distance end
	end
	return best
end

local spot
for _, candidate in {
	stub.vec3(0, 6, 108), stub.vec3(0, 6, 124), stub.vec3(126, 6, 0),
	stub.vec3(-126, 6, 0), stub.vec3(0, 6, -132), stub.vec3(100, 6, 90),
} do
	stub.moveTo(player, candidate)
	local distance = nearestLivingDistance()
	if distance and distance > Config.AttackRange + 4 and distance <= 100 then
		spot = candidate
		break
	end
end
check(spot ~= nil, "could not find a spot where an enemy is visible but out of reach")
stub.renderStepped:Fire(1)
check(plate.Visible == true, "the plate must keep tracking an enemy the player can see but not reach")
check(tostring(rangeLabel.Text):find("MOVE CLOSER"), `the plate must say when the target is out of reach, said "{rangeLabel.Text}"`)

stub.moveTo(player, stub.vec3(0, 6, 900))
stub.renderStepped:Fire(1)
check(plate.Visible == false, "the target plate must clear when nothing is nearby")
check(outline.Enabled == false, "the outline must clear with the plate")

-- ---------------------------------------------------------- loop survival ---
stub.warnings = {}
stub.moveTo(player, stub.vec3(0, 6, 40))
player.Character = nil
task.wait(0.9)
player.Character = character
task.wait(0.9)
check(#stub.warnings == 0, `a loop warned during a missing character: {tostring(stub.warnings[1])}`)
check(#stub.livingEnemies(1) > 0, "enemies must keep existing after a character drops out")

local survivor = stub.livingEnemies(1)[1]
local survivorHealth = survivor:FindFirstChildOfClass("Humanoid").Health
stub.advance(6)
stub.moveTo(player, survivor.PrimaryPart.Position + stub.vec3(0, 0, 6))
stub.fireKey("SoulAttack", "F")
check(survivor:FindFirstChildOfClass("Humanoid").Health < survivorHealth, "combat must still work after the loop recovery")

print(`gameplay_cli: {checks} checks passed`)
process.exit(0)
