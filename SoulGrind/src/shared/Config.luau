-- Replace the zero IDs after creating the products in Creator Hub.
return {
	DataStoreName = "SoulGrind_v1",
	StudioPersistence = false,

	DailyGoal = 10,
	DailyReward = 3,
	CheckInSeconds = 600,
	CheckInMinKills = 3,

	-- Shared by the server (authority) and the client (target plate, cooldown sweeps).
	-- One source of truth stops the HUD from promising a reach the server will refuse.
	AttackRange = 34,
	PulseRange = 22,
	Cooldowns = { Attack = 0.34, Finisher = 0.52, Pulse = 8, Dash = 3 },

	-- Enemies hold a post. They wake when you come close, chase while you stay inside
	-- the leash, then walk home and heal. Nothing follows you across the map forever.
	Aggro = {
		Engage = 44,
		Leash = 86,
		ReturnSpeed = 1.4,
		RegenPerSecond = 9,
		CalmSeconds = 4,
	},

	-- Crimson and gold. Neon is reserved for flame cores, lava seams and the boss
	-- telegraph; every other surface is a real material lit by real lights.
	Palette = {
		Bedrock = Color3.fromRGB(34, 27, 29),
		Rock = Color3.fromRGB(52, 42, 44),
		RockLight = Color3.fromRGB(74, 60, 60),
		Floor = Color3.fromRGB(96, 78, 76),
		FloorAlt = Color3.fromRGB(116, 95, 90),
		Stone = Color3.fromRGB(134, 112, 106),
		StoneDark = Color3.fromRGB(94, 74, 76),
		Bone = Color3.fromRGB(212, 201, 182),
		Gold = Color3.fromRGB(201, 162, 74),
		GoldLight = Color3.fromRGB(232, 200, 120),
		GoldPale = Color3.fromRGB(255, 233, 168),
		Crimson = Color3.fromRGB(140, 35, 32),
		CrimsonMid = Color3.fromRGB(184, 54, 47),
		CrimsonLit = Color3.fromRGB(217, 82, 74),
		Iron = Color3.fromRGB(58, 52, 54),
		Ember = Color3.fromRGB(224, 138, 60),
	},

	-- Progression spends souls on the moves themselves, not only on a damage number.
	-- Order is the display order in the Journal.
	Abilities = {
		{
			Key = "Strike",
			Name = "Soul Strike",
			Detail = "+14% strike damage per rank. Rank 3 makes the finisher knock back everything nearby.",
			Max = 5,
			BaseCost = 45,
			Growth = 1.6,
			RequiresLevel = 1,
		},
		{
			Key = "Pulse",
			Name = "Soul Pulse",
			Detail = "+4 studs radius and +12% damage per rank.",
			Max = 5,
			BaseCost = 70,
			Growth = 1.65,
			RequiresLevel = 3,
		},
		{
			Key = "Step",
			Name = "Soul Step",
			Detail = "-0.4s cooldown and a longer phase window per rank.",
			Max = 4,
			BaseCost = 55,
			Growth = 1.7,
			RequiresLevel = 1,
		},
	},

	Products = {
		FlarePack = {
			Id = 0,
			Amount = 5,
			Item = "Flares",
			Label = "5 Soul Flares",
			Description = "Five cosmetic bursts. Daily play also earns free flares.",
		},
	},

	Passes = {
		Aura = {
			Id = 0,
			Label = "Eternal Violet Aura",
			Description = "A permanent cosmetic aura with no combat bonus.",
		},
	},

	-- Half-extents of the walkable arena. The old 146x106 pad felt like a waiting room.
	ArenaHalf = Vector3.new(140, 0, 110),

	Zones = {
		[1] = {
			Name = "Cinder Hollow",
			Origin = Vector3.new(0, 0, 0),
			Accent = Color3.fromRGB(184, 54, 47),
			AccentLight = Color3.fromRGB(217, 82, 74),
			Floor = Color3.fromRGB(96, 78, 76),
			FloorAlt = Color3.fromRGB(116, 95, 90),
			Stone = Color3.fromRGB(134, 112, 106),
			EnemyHealth = 36,
			EnemyDamage = 7,
			SoulReward = 10,
		},
		[2] = {
			Name = "Molten Reliquary",
			Origin = Vector3.new(520, 0, 0),
			Accent = Color3.fromRGB(201, 162, 74),
			AccentLight = Color3.fromRGB(232, 200, 120),
			Floor = Color3.fromRGB(104, 84, 70),
			FloorAlt = Color3.fromRGB(126, 102, 82),
			Stone = Color3.fromRGB(142, 120, 96),
			EnemyHealth = 95,
			EnemyDamage = 12,
			SoulReward = 28,
		},
	},
}
