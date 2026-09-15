-- The game already had a progression; it just never told anyone about it. This turns
-- that progression into a named, ordered, checkable list that the server grants from and
-- the client, the world signs and the objective banner all read from.
--
-- Progress is derived from the profile, never stored separately, so a quest can never
-- disagree with the save. Only the "already paid out" set is stored.

local Quests = {}

Quests.list = {
	{
		Id = "FirstSoul",
		Title = "First Blood",
		Detail = "Strike down a single Cinder Shade.",
		Hint = "Walk up to a shade and press F, or click it.",
		Target = 1,
		Reward = 15,
		Progress = function(profile) return profile.Kills end,
	},
	{
		Id = "CullTheHollow",
		Title = "Cull the Hollow",
		Detail = "Defeat 10 of the hollow things in Cinder Hollow.",
		Hint = "Shades are weakest, Reavers hit hardest, Wisps are fastest.",
		Target = 10,
		Reward = 30,
		Progress = function(profile) return profile.Kills end,
	},
	{
		Id = "SoulPower",
		Title = "Kindle the Soul",
		Detail = "Reach Soul Level 3 to unlock Soul Pulse.",
		Hint = "Spend souls on UPGRADE in the Journal.",
		Target = 3,
		Reward = 40,
		Progress = function(profile) return profile.Level end,
	},
	{
		Id = "SharpenTheBlade",
		Title = "Sharpen the Blade",
		Detail = "Buy your first move upgrade.",
		Hint = "The MOVES tab in the Journal ranks up Strike, Pulse and Step.",
		Target = 1,
		Reward = 35,
		Progress = function(profile)
			local total = 0
			for _, rank in profile.Upgrades do total += rank end
			return total
		end,
	},
	{
		Id = "AshGate",
		Title = "Open the Ash Gate",
		Detail = "Gather 150 souls and break the seal on the Ash Gate.",
		Hint = "The gate is the tall arch at the far end of the hollow.",
		Target = 2,
		Reward = 60,
		Progress = function(profile) return profile.MaxZone end,
	},
	{
		Id = "IntoTheDeep",
		Title = "Into the Reliquary",
		Detail = "Defeat 5 of the guardians beyond the gate.",
		Hint = "They hit far harder than anything in the hollow. Soul Step through them.",
		Target = 5,
		Reward = 90,
		Progress = function(profile) return profile.DeepKills end,
	},
	{
		Id = "WardenSigil",
		Title = "Bind the Gilded Warden",
		Detail = "Defeat the Warden at the heart of the Reliquary.",
		Hint = "It telegraphs a slam. Soul Step (E) passes straight through it.",
		Target = 1,
		Reward = 150,
		Progress = function(profile) return profile.Bosses end,
	},
	{
		Id = "Reborn",
		Title = "Rebirth",
		Detail = "Gather 500 souls and be reborn for a permanent +10% damage.",
		Hint = "Rebirth keeps your zones, sigils and move ranks.",
		Target = 1,
		Reward = 200,
		Progress = function(profile) return profile.Rebirths end,
	},
}

Quests.count = #Quests.list

function Quests.byId(id)
	for _, quest in Quests.list do
		if quest.Id == id then return quest end
	end
	return nil
end

-- One pass produces everything any surface needs: the per-quest rows for the guide,
-- the current objective for the banner and the world signs, and the completion rate.
function Quests.snapshot(profile)
	local rows = {}
	local completed = 0
	local active

	for index, quest in Quests.list do
		local raw = quest.Progress(profile)
		local value = math.clamp(type(raw) == "number" and raw or 0, 0, quest.Target)
		local done = value >= quest.Target
		if done then completed += 1 end

		local row = {
			Id = quest.Id,
			Title = quest.Title,
			Detail = quest.Detail,
			Hint = quest.Hint,
			Value = value,
			Target = quest.Target,
			Reward = quest.Reward,
			Done = done,
			Order = index,
		}
		rows[index] = row
		if not done and not active then active = row end
	end

	return {
		Rows = rows,
		Active = active,
		Completed = completed,
		Total = Quests.count,
		-- Task completion rate, as a percentage, for the HUD and the guide header.
		Rate = math.floor(completed / Quests.count * 100 + 0.5),
	}
end

return Quests
