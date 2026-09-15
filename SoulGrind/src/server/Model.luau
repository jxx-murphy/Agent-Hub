local Model = {}

local function number(value, fallback, minimum)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.max(minimum or 0, math.floor(value))
end

local function utcDay(now)
	return math.floor(now / 86400)
end

function Model.new(now)
	local day = utcDay(now)
	return {
		Version = 1,
		Revision = 0,
		Souls = 0,
		Level = 1,
		Rebirths = 0,
		MaxZone = 1,
		Kills = 0,
		Bosses = 0,
		ActiveDays = 1,
		Streak = 1,
		LastDay = day,
		DailyKills = 0,
		DailyClaimed = false,
		DailyActiveSeconds = 0,
		CheckInClaimed = false,
		SpendDays = 0,
		LastSpendDay = -1,
		Wallet = { Flares = 3 },
		Collection = {},
		Receipts = {},
	}
end

function Model.normalize(raw, now)
	local base = Model.new(now)
	if type(raw) ~= "table" then
		return base
	end

	base.Revision = number(raw.Revision, 0)
	base.Souls = number(raw.Souls, 0)
	base.Level = number(raw.Level, 1, 1)
	base.Rebirths = number(raw.Rebirths, 0)
	base.MaxZone = math.clamp(number(raw.MaxZone, 1, 1), 1, 2)
	base.Kills = number(raw.Kills, 0)
	base.Bosses = number(raw.Bosses, 0)
	base.ActiveDays = number(raw.ActiveDays, 1, 1)
	base.Streak = number(raw.Streak, 1, 1)
	base.LastDay = number(raw.LastDay, utcDay(now))
	base.DailyKills = number(raw.DailyKills, 0)
	base.DailyClaimed = raw.DailyClaimed == true
	base.DailyActiveSeconds = number(raw.DailyActiveSeconds, 0)
	base.CheckInClaimed = raw.CheckInClaimed == true
	base.SpendDays = number(raw.SpendDays, 0)
	base.LastSpendDay = number(raw.LastSpendDay, -1, -1)
	base.Wallet.Flares = number(type(raw.Wallet) == "table" and raw.Wallet.Flares, 3)

	if type(raw.Collection) == "table" then
		for key, value in raw.Collection do
			if type(key) == "string" and value == true and #key <= 40 then
				base.Collection[key] = true
			end
		end
	end
	if type(raw.Receipts) == "table" then
		for purchaseId, productId in raw.Receipts do
			if type(purchaseId) == "string" and #purchaseId <= 100 and type(productId) == "number" then
				base.Receipts[purchaseId] = productId
			end
		end
	end

	local day = utcDay(now)
	if day > base.LastDay then
		base.ActiveDays += 1
		-- The ember chain never falls; missing a day does not erase progress.
		base.Streak += 1
		base.LastDay = day
		base.DailyKills = 0
		base.DailyClaimed = false
		base.DailyActiveSeconds = 0
		base.CheckInClaimed = false
	end
	Model.applyMilestones(base)

	return base
end

function Model.upgradeCost(profile)
	return math.floor(20 * (1.45 ^ (profile.Level - 1)))
end

function Model.rebirthCost(profile)
	return 500 + profile.Rebirths * 250
end

function Model.damage(profile)
	return math.floor((8 + profile.Level * 4) * (1 + profile.Rebirths * 0.1))
end

function Model.applyMilestones(profile)
	if profile.Kills >= 1 then profile.Collection.FirstSoul = true end
	if profile.Kills >= 25 then profile.Collection.ShadeHunter = true end
	if profile.MaxZone >= 2 then profile.Collection.Gatebreaker = true end
	if profile.Bosses >= 1 then profile.Collection.WardenSigil = true end
	if profile.Rebirths >= 1 then profile.Collection.Reborn = true end
	if profile.ActiveDays >= 7 then profile.Collection.EmberVeteran = true end
	if profile.ActiveDays >= 20 then profile.Collection.HollowCrown = true end
end

function Model.nextGoal(profile)
	if profile.Kills < 1 then return "Defeat your first shade" end
	if profile.Level < 3 then return "Reach Soul Level 3 to unlock Pulse" end
	if profile.MaxZone < 2 then return "Gather 150 Souls and open the Ash Gate" end
	if profile.Bosses < 1 then return "Defeat the Frozen Warden" end
	if profile.Rebirths < 1 then return "Gather 500 Souls and rebirth" end
	if profile.Kills < 25 then return "Bind 25 shades into your collection" end
	if profile.ActiveDays < 7 then return `Return on {7 - profile.ActiveDays} more days for the Ember Veteran sigil` end
	if profile.ActiveDays < 20 then return `Return on {20 - profile.ActiveDays} more days for the Hollow Crown` end
	return "Grow your rebirth rank and help a friend through the Ash Gate"
end

return Model
