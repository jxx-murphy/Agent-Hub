-- Replace the zero IDs after creating the products in Creator Hub.
return {
	DataStoreName = "SoulGrind_v1",
	StudioPersistence = false,

	DailyGoal = 10,
	DailyReward = 3,
	CheckInSeconds = 600,
	CheckInMinKills = 3,

	-- Shared by the server (authority) and the client (target plate, cooldown sweeps).
	-- One source of truth stops the HUD from promising a reach the server will not honour.
	AttackRange = 34,
	PulseRange = 22,
	Cooldowns = { Attack = 0.34, Finisher = 0.52, Pulse = 8, Dash = 3 },

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

	Zones = {
		[1] = {
			Name = "Cinder Hollow",
			Origin = Vector3.new(0, 0, 0),
			Color = Color3.fromRGB(168, 96, 226),
			Ground = Color3.fromRGB(62, 53, 78),
			GroundAlt = Color3.fromRGB(78, 68, 98),
			Stone = Color3.fromRGB(104, 94, 124),
			EnemyHealth = 36,
			EnemyDamage = 7,
			SoulReward = 10,
		},
		[2] = {
			Name = "Frozen Purgatory",
			Origin = Vector3.new(220, 0, 0),
			Color = Color3.fromRGB(86, 186, 226),
			Ground = Color3.fromRGB(50, 66, 86),
			GroundAlt = Color3.fromRGB(64, 82, 104),
			Stone = Color3.fromRGB(104, 122, 142),
			EnemyHealth = 95,
			EnemyDamage = 12,
			SoulReward = 28,
		},
	},
}
