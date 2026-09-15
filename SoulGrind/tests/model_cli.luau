local Model = require("../src/server/Model")

local fresh = Model.normalize(nil, 10 * 86400)
assert(fresh.Level == 1 and fresh.Souls == 0 and fresh.ActiveDays == 1)

fresh.DailyKills = 10
fresh.DailyClaimed = true
fresh.DailyActiveSeconds = 600
fresh.CheckInClaimed = true
fresh.ActiveDays = 19
fresh.LastDay = 10
local returned = Model.normalize(fresh, 11 * 86400)
assert(returned.ActiveDays == 20 and returned.Streak == 2)
assert(returned.DailyKills == 0 and not returned.DailyClaimed)
assert(returned.DailyActiveSeconds == 0 and not returned.CheckInClaimed)
assert(returned.Collection.HollowCrown, "day 20 must unlock the visible crown")

returned.Level = 3
returned.Rebirths = 2
assert(Model.damage(returned) == 24, "damage must include permanent rebirth bonus")
assert(Model.upgradeCost(returned) == 42)

-- Ability ranks: pure arithmetic, so the curves are checkable without Roblox.
local ranked = Model.normalize({ Level = 3, Rebirths = 0, Upgrades = { Strike = 2, Pulse = 1, Step = 3 } }, 10 * 86400)
assert(Model.rank(ranked, "Strike") == 2 and Model.rank(ranked, "Step") == 3)
assert(Model.rank(ranked, "Missing") == 0, "an unknown ability reads as rank zero")

local plain = Model.normalize({ Level = 3 }, 10 * 86400)
assert(Model.damage(plain) == 20, "base damage at level 3 must be unchanged by the rank system")
assert(Model.damage(ranked) > Model.damage(plain), "strike ranks must raise damage")
assert(Model.strikeMultiplier(plain) == 1, "rank zero must be a no-op multiplier")
assert(not Model.strikeKnocksBack(ranked), "the finisher shockwave needs rank 3")
assert(Model.strikeKnocksBack(Model.normalize({ Upgrades = { Strike = 3 } }, 0)), "rank 3 unlocks the shockwave")

assert(Model.pulseRange(plain, 22) == 22 and Model.pulseRange(ranked, 22) == 26, "pulse ranks widen the radius")
assert(Model.dashCooldown(plain, 3) == 3, "rank zero leaves the dash cooldown alone")
local function near(a, b) return math.abs(a - b) < 1e-6 end
assert(near(Model.dashCooldown(ranked, 3), 1.8), "step ranks cut the dash cooldown")
assert(near(Model.dashCooldown(Model.normalize({ Upgrades = { Step = 9 } }, 0), 3), 1.2), "the dash cooldown has a floor")
assert(Model.dodgeWindow(ranked) > Model.dodgeWindow(plain), "step ranks widen the phase window")

assert(Model.abilityCost(45, 1.6, 0) == 45, "the first rank costs the base price")
assert(Model.abilityCost(45, 1.6, 1) == 72, "each rank costs more than the last")

-- A tampered save must never hand out a permanently overpowered ability.
local tampered = Model.normalize({ Upgrades = { Strike = 9999, Pulse = -5, Step = "free" } }, 0)
assert(tampered.Upgrades.Strike == 10, "ranks are clamped on load")
assert(tampered.Upgrades.Pulse == 0 and tampered.Upgrades.Step == 0, "bad rank values fall back to zero")

-- Quest payout bookkeeping survives a reload, so rewards cannot be farmed by rejoining.
local paid = Model.normalize({ QuestsPaid = { FirstSoul = true, [17] = true, Bogus = "yes" } }, 0)
assert(paid.QuestsPaid.FirstSoul == true, "paid quests persist")
assert(paid.QuestsPaid.Bogus == nil, "non-boolean quest flags are dropped")

print("model_cli: all checks passed")
