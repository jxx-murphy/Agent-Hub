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

print("model_cli: all checks passed")
