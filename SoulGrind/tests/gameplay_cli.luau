--!nocheck
-- End-to-end ability checks. Runs the real Main.server.luau and Client.client.luau
-- against tests/roblox_stub.luau, so a broken keybind, a dead RemoteEvent, a wrong
-- attack range or a silent cooldown fails here instead of in Play Solo.
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

-- ---------------------------------------------------------------- startup ---
stub.runServer()

local world = stub.Workspace:FindFirstChild("SoulGrindWorld")
check(world ~= nil, "the world folder must be built at startup")
check(#stub.enemies(1) == 5, `zone 1 must hold five enemies, saw {#stub.enemies(1)}`)
check(#stub.enemies(2) == 5, `zone 2 must hold five enemies, saw {#stub.enemies(2)}`)

local boss
for _, enemy in stub.enemies(2) do
	if enemy:GetAttribute("Boss") then boss = enemy end
end
check(boss ~= nil, "zone 2 must contain the Warden")

-- Readability is a band, not a floor. The first fix for "the map is a black screen" was
-- to raise everything, which turned the arena into a magenta whiteout: just as unplayable.
-- Both walls are asserted so neither mistake can come back.
local function band(value, low, high, label)
	check(value >= low, `{label} is too low at {value}, needs at least {low}`)
	check(value <= high, `{label} is too high at {value}, needs at most {high}`)
end

band(luminance(stub.Lighting.Ambient), 0.16, 0.32, "ambient luminance")
band(luminance(stub.Lighting.OutdoorAmbient), 0.2, 0.38, "outdoor ambient luminance")
band(stub.Lighting.Brightness, 1.5, 2.4, "global brightness")
band(stub.Lighting.ExposureCompensation, -0.4, 0.15, "exposure compensation")
band(stub.Lighting.FogStart, 100, 260, "fog start")
local atmosphere = stub.Lighting:FindFirstChildOfClass("Atmosphere")
check(atmosphere ~= nil, "the underworld needs an Atmosphere")
band(atmosphere.Density, 0.15, 0.36, "atmosphere density")
check(stub.Lighting:FindFirstChild("SoulDepth") == nil, "depth of field blurs the silhouettes players need")

local bloom = stub.Lighting:FindFirstChild("SoulBloom")
check(bloom ~= nil, "the neon accents need a bloom pass")
check(bloom.Intensity <= 0.3, "bloom this strong turns every neon edge into a white halo")
check(bloom.Threshold >= 2, "a low bloom threshold blooms surfaces that are not meant to glow")
local grade = stub.Lighting:FindFirstChild("UnderworldGrade")
check(grade ~= nil and grade.Brightness <= 0.02, "colour grading must not add more exposure on top")
check(grade.Saturation <= 0.05, "the palette is already saturated; grading must not push it further")

-- Additive light budget. Twenty-five overlapping PointLights is what actually caused the
-- whiteout, not any single value, so the total load is what gets capped.
local lights, lightLoad, brightest, longest = 0, 0, 0, 0
for _, node in world:GetDescendants() do
	if node.ClassName == "PointLight" or node.ClassName == "SpotLight" then
		lights += 1
		lightLoad += node.Brightness * node.Range
		brightest = math.max(brightest, node.Brightness)
		longest = math.max(longest, node.Range)
	end
end
check(lights >= 8, "the arena needs local light sources, not just ambient")
check(lights <= 34, `{lights} dynamic lights is past what the arena can stay readable under`)
check(brightest <= 3.5, `a single light at brightness {brightest} blows out everything near it`)
check(longest <= 48, `a light with range {longest} floods the whole arena`)
check(lightLoad <= 2600, `total light load {math.floor(lightLoad)} washes the arena out`)

local floors, grids, obelisks = 0, 0, 0
for _, zoneFolder in world:GetChildren() do
	for _, part in zoneFolder:GetChildren() do
		if part.Name == "ArenaFloor" then
			floors += 1
			check(luminance(part.Color) > 0.16, `{zoneFolder.Name} floor is too dark to stand out from the void`)
		elseif part.Name == "SoulGrid" then
			grids += 1
		elseif part.Name == "ObeliskCrown" then
			obelisks += 1
		end
	end
end
check(floors == 2, "both zones need a readable arena floor")
check(grids >= 20, "the floor grid gives the only distance cue on a flat arena")
check(obelisks == 2, "each zone needs a landmark that is visible from anywhere in it")

-- Enemies must be legible against that floor: bright body, bright trim, and an outline.
local archetypesSeen = {}
for _, enemy in stub.enemies(1) do
	archetypesSeen[enemy:GetAttribute("Archetype")] = true
	local torso = enemy:FindFirstChild("Torso")
	local outline = enemy:FindFirstChild("SoulOutline")
	check(torso and luminance(torso.Color) > 0.15, `{enemy.Name} body blends into the floor`)
	check(outline ~= nil and outline.OutlineTransparency < 0.4, `{enemy.Name} has no readable silhouette`)
	check(enemy:FindFirstChild("Collar") ~= nil, `{enemy.Name} is missing its rim highlight`)
	check(enemy.PrimaryPart.CanCollide == true, `{enemy.Name} must stand on the floor, not sink through it`)
end
check(archetypesSeen.Shade and archetypesSeen.Reaver and archetypesSeen.Wisp, "zone 1 must mix archetypes")

-- Distinct colours, not three shades of the same dark.
local shadeColor, wispColor
for _, enemy in stub.enemies(1) do
	if enemy:GetAttribute("Archetype") == "Shade" then shadeColor = enemy:FindFirstChild("Torso").Color end
	if enemy:GetAttribute("Archetype") == "Wisp" then wispColor = enemy:FindFirstChild("Torso").Color end
end
local separation = math.abs(shadeColor.R - wispColor.R) + math.abs(shadeColor.G - wispColor.G) + math.abs(shadeColor.B - wispColor.B)
check(separation > 0.4, "archetypes must be distinguishable by colour at a glance")

-- ------------------------------------------------------------ player join ---
local player = stub.addPlayer("Tester", 7001)
check(stub.kicked == nil, `the join path kicked the player: {tostring(stub.kicked)}`)
check(player:FindFirstChild("leaderstats") ~= nil, "leaderstats must exist after joining")

stub.runClient()
local character = stub.spawnCharacter(player, stub.vec3(0, 6, 38))
check(character ~= nil, "character rig must spawn")

local Action = stub.remotes:FindFirstChild("Action")
check(Action ~= nil, "the Action RemoteEvent must exist")
for _, name in { "State", "Notice", "Offer", "FX" } do
	check(stub.remotes:FindFirstChild(name) ~= nil, `the {name} RemoteEvent must exist`)
end

local Config = stub.loadModule(`{stub.root}/src/shared/Config.luau`, nil)

local function syncState()
	stub.advance(0.2)
	stub.clearClientEvents()
	Action.OnServerEvent:Fire(player, "Sync")
	local states = stub.takeClientEvents("State")
	return states[#states]
end

-- The client's Sync retry has to produce state without a manual nudge.
local latest = syncState()
check(latest ~= nil, "the client never received a State payload")
check(latest.Damage and latest.Damage > 0, "state must carry a damage value")
check(latest.UpgradeCost == 20, `first upgrade must cost 20 souls, saw {latest.UpgradeCost}`)
check(latest.PulseUnlocked == false, "pulse must start locked at level 1")

-- ------------------------------------------------------ keyboard bindings ---
for actionName, key in { SoulAttack = "F", SoulPulse = "Q", SoulStep = "E" } do
	local binding = stub.boundActions[actionName]
	check(binding ~= nil, `{actionName} must be bound to a key`)
	check(binding.Keys[1].Name == key, `{actionName} must sit on {key}`)
end

-- ------------------------------------------------- F: strike from the key ---
local function livingEnemies(zoneId)
	local out = {}
	for _, enemy in stub.enemies(zoneId) do
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then table.insert(out, enemy) end
	end
	return out
end

local target = livingEnemies(1)[1]
local targetRoot = target.PrimaryPart
local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
stub.moveTo(player, targetRoot.Position + stub.vec3(0, 0, 8))

-- Keep the dummy alive across the input-route checks: this section is about whether the
-- input reaches the server, not about how many hits a shade survives.
local function readyTarget()
	targetHumanoid.Health = targetHumanoid.MaxHealth
	stub.moveTo(player, targetRoot.Position + stub.vec3(0, 0, 8))
	stub.advance(1)
end

local startHealth = targetHumanoid.Health
stub.clearClientEvents()
stub.fireKey("SoulAttack", "F")
check(targetHumanoid.Health < startHealth, "pressing F must damage the enemy standing in front of the player")
local hits = stub.takeClientEvents("FX", "Hit")
check(#hits == 1, `one F press must send exactly one Hit effect, saw {#hits}`)
check(hits[1].Damage == latest.Damage, "hit damage must match the published damage value")
local swings = stub.takeClientEvents("FX", "Swing")
check(#swings == 1, "every strike must send a visible Swing, hit or miss")
check(swings[1].Cooldown > 0, "the swing must carry its cooldown so the button can drain")

-- Server-side cooldown: a second press inside the window must not land a second hit.
stub.clearClientEvents()
stub.fireKey("SoulAttack", "F")
check(#stub.takeClientEvents("FX", "Hit") == 0, "the attack cooldown must reject a second immediate strike")
check(#stub.takeClientEvents("FX", "Cooling") == 1, "a cooling strike must still tell the player why nothing happened")

-- ------------------------------------------ F: strike from the HUD button ---
readyTarget()
local beforeButton = targetHumanoid.Health
stub.clickButton("Attack")
check(targetHumanoid.Health < beforeButton, "the on-screen ATTACK button must land a hit")

-- --------------------------------------------- F: click and tap to strike ---
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

-- ----------------------------------------------- F: an out-of-range press ---
readyTarget()
stub.moveTo(player, stub.vec3(0, 6, 400))
stub.clearClientEvents()
stub.fireKey("SoulAttack", "F")
local misses = stub.takeClientEvents("FX", "Miss")
check(#misses == 1, "a strike with nothing in reach must report a miss, not fail silently")
check(type(misses[1].Distance) == "number", "the miss must say how far away the nearest enemy is")
check(#stub.takeClientEvents("FX", "Swing") == 1, "a miss must still swing so the input feels received")

-- Reach parity: the HUD and the server must agree on what "in range" means.
readyTarget()
stub.moveTo(player, targetRoot.Position + stub.vec3(0, 0, Config.AttackRange - 3))
stub.clearClientEvents()
stub.fireKey("SoulAttack", "F")
check(#stub.takeClientEvents("FX", "Hit") == 1, "an enemy inside Config.AttackRange must be hittable")

readyTarget()
stub.moveTo(player, targetRoot.Position + stub.vec3(0, 0, Config.AttackRange + 8))
stub.clearClientEvents()
stub.fireKey("SoulAttack", "F")
check(#stub.takeClientEvents("FX", "Miss") == 1, "an enemy beyond Config.AttackRange must miss")

-- ----------------------------------------------------------- E: soul step ---
stub.advance(5)
stub.clearClientEvents()
local root = character:FindFirstChild("HumanoidRootPart")
root.AssemblyLinearVelocity = stub.vec3(0, 0, 0)
stub.fireKey("SoulStep", "E")
check(root.AssemblyLinearVelocity.Magnitude > 20, "Soul Step must move the player")
local dashes = stub.takeClientEvents("FX", "Dash")
check(#dashes == 1, "Soul Step must broadcast its effect")
check(dashes[1].Cooldown == Config.Cooldowns.Dash, "the dash effect must carry the shared cooldown")

stub.clearClientEvents()
stub.fireKey("SoulStep", "E")
check(#stub.takeClientEvents("FX", "Dash") == 0, "Soul Step must respect its server cooldown")
local stepNotices = stub.takeClientEvents("Notice")
check(#stepNotices > 0 and tostring(stepNotices[1]):find("recharge"), "a blocked Soul Step must say it is recharging")

stub.clearClientEvents()
stub.clickButton("Dash")
check(#stub.takeClientEvents("Notice") > 0, "the on-screen STEP button must reach the server")

-- ---------------------------------------------------------- Q: soul pulse ---
stub.advance(5)
stub.clearClientEvents()
stub.fireKey("SoulPulse", "Q")
local locked = stub.takeClientEvents("Notice")
check(#locked == 1 and tostring(locked[1]):find("Level 3"), "a locked pulse must explain the level gate")

stub.clearClientEvents()
stub.clickButton("Pulse")
check(#stub.takeClientEvents("Notice") == 1, "the on-screen PULSE button must reach the server")

-- Earn level 3 the honest way: fight for it.
local function strikeUntilDead(enemy)
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	local enemyRoot = enemy.PrimaryPart
	for _ = 1, 60 do
		if humanoid.Health <= 0 then return true end
		stub.moveTo(player, enemyRoot.Position + stub.vec3(0, 0, 6))
		stub.advance(1)
		Action.OnServerEvent:Fire(player, "Attack")
	end
	return humanoid.Health <= 0
end

local kills = 0
for _ = 1, 10 do
	local alive = livingEnemies(1)
	if #alive == 0 then break end
	check(strikeUntilDead(alive[1]), "an enemy must be killable with repeated strikes")
	kills += 1
	local snapshot = syncState()
	if snapshot.Souls >= snapshot.UpgradeCost then
		stub.advance(0.5)
		Action.OnServerEvent:Fire(player, "Upgrade")
	end
	if syncState().Level >= 3 then break end
end

local levelled = syncState()
check(levelled.Kills == kills, `kills must be recorded on the server, expected {kills} saw {levelled.Kills}`)
check(levelled.Level >= 3, `combat must be able to reach level 3, stopped at {levelled.Level}`)
check(levelled.PulseUnlocked == true, "level 3 must unlock pulse")
check(levelled.Collection.FirstSoul == true, "the first kill must award its sigil")

-- Enemies respawn, so an emptied arena refills instead of stranding the player.
task.wait(5.2)
check(#livingEnemies(1) > 0, "defeated enemies must respawn")

local pulseTarget = livingEnemies(1)[1]
local pulseHumanoid = pulseTarget:FindFirstChildOfClass("Humanoid")
stub.moveTo(player, pulseTarget.PrimaryPart.Position + stub.vec3(0, 0, 5))
local beforePulse = pulseHumanoid.Health
stub.advance(20)
stub.clearClientEvents()
stub.fireKey("SoulPulse", "Q")
check(pulseHumanoid.Health < beforePulse, "an unlocked pulse must damage nearby enemies")
local pulses = stub.takeClientEvents("FX", "Pulse")
check(#pulses == 1, "pulse must send its effect")
check(pulses[1].Hits >= 1, "the pulse effect must report how many it struck")
check(pulses[1].Cooldown == Config.Cooldowns.Pulse, "the pulse effect must carry the shared cooldown")

stub.clearClientEvents()
stub.fireKey("SoulPulse", "Q")
check(#stub.takeClientEvents("FX", "Pulse") == 0, "pulse must respect its server cooldown")
check(#stub.takeClientEvents("Notice") == 1, "a blocked pulse must say when it recharges")

-- ------------------------------------------------------- action allowlist ---
local beforeJunk = syncState()
Action.OnServerEvent:Fire(player, "GiveMeSouls", 9999)
Action.OnServerEvent:Fire(player, { Souls = 9999 })
Action.OnServerEvent:Fire(player, "Upgrade\0")
stub.advance(1)
local afterJunk = syncState()
check(afterJunk.Souls == beforeJunk.Souls, "unknown actions must not change the profile")
check(afterJunk.Level == beforeJunk.Level, "unknown actions must not change the level")

-- Progression stays server-side: an unaffordable gate must refuse and cost nothing.
local beforeGate = syncState()
if beforeGate.Souls < 150 then
	stub.advance(0.5)
	Action.OnServerEvent:Fire(player, "UnlockZone")
	stub.advance(0.5)
	local afterGate = syncState()
	check(afterGate.MaxZone == 1, "the ash gate must stay shut below 150 souls")
	check(afterGate.Souls == beforeGate.Souls, "a refused gate must not spend souls")
end

-- Commerce must stay exactly as designed: one ProcessReceipt owner, and no paid receipt
-- acknowledged while the profile store is volatile.
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
for _, name in { "Attack", "Pulse", "Dash" } do
	local control = stub.findGui(name)
	check(control ~= nil and control:FindFirstChild("Cool") ~= nil, `{name} needs a visible cooldown drain`)
end

-- The nearest-enemy plate must refresh off RenderStepped and agree with the server reach.
stub.moveTo(player, livingEnemies(1)[1].PrimaryPart.Position + stub.vec3(0, 0, 10))
stub.renderStepped:Fire(1)
local plate = stub.findGui("Target")
check(plate ~= nil and plate.Visible == true, "a nearby enemy must show the target plate")
local rangeLabel = stub.findGui("Range")
check(rangeLabel ~= nil and tostring(rangeLabel.Text):find("IN RANGE"), "the plate must say when the target is reachable")

-- Far enough that nothing is in reach, close enough that the plate still tracks it.
stub.moveTo(player, stub.vec3(0, 6, 100))
stub.renderStepped:Fire(1)
check(plate.Visible == true, "the plate must still track an enemy the player can see but not reach")
check(tostring(rangeLabel.Text):find("MOVE CLOSER"), `the plate must say when the target is out of reach, said "{rangeLabel.Text}"`)

stub.moveTo(player, stub.vec3(0, 6, 800))
stub.renderStepped:Fire(1)
check(plate.Visible == false, "the target plate must clear when nothing is nearby")

-- ---------------------------------------------------------- loop survival ---
-- A character that vanishes mid-tick used to throw inside the AI loop and kill enemy
-- behaviour for the rest of the server's life.
stub.warnings = {}
stub.moveTo(player, stub.vec3(0, 6, 20))
player.Character = nil
task.wait(1)
player.Character = character
task.wait(1)
check(#stub.warnings == 0, `a loop warned during a missing character: {tostring(stub.warnings[1])}`)
check(#livingEnemies(1) > 0, "enemies must keep existing after a character drops out")

local survivor = livingEnemies(1)[1]
local survivorHealth = survivor:FindFirstChildOfClass("Humanoid").Health
stub.advance(5)
stub.moveTo(player, survivor.PrimaryPart.Position + stub.vec3(0, 0, 6))
stub.clearClientEvents()
stub.fireKey("SoulAttack", "F")
check(survivor:FindFirstChildOfClass("Humanoid").Health < survivorHealth, "combat must still work after the loop recovery")

print(`gameplay_cli: {checks} checks passed`)
process.exit(0)
