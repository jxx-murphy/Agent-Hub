local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.SoulGrind.Config)
local Model = require(script.Parent.Model)

local volatile = RunService:IsStudio() and not Config.StudioPersistence
local dataStore = if volatile then nil else DataStoreService:GetDataStore(Config.DataStoreName)
local memory = {}
local cache = {}
local locks = {}

local Store = {}

local function key(userId)
	return `u_{userId}`
end

-- A plain flag beats a BindableEvent here: firing and destroying a BindableEvent in
-- the same resumption cycle can drop the queued :Wait() resumption under deferred
-- signal behaviour, which deadlocks every later write for that player.
local function acquire(userId)
	while locks[userId] do
		task.wait()
	end
	locks[userId] = true
end

local function release(userId)
	locks[userId] = nil
end

function Store.isDurable()
	return not volatile
end

function Store.load(userId)
	return Store.update(userId, function(profile)
		return profile
	end)
end

function Store.update(userId, transform)
	acquire(userId)
	local saved
	local ok, err = pcall(function()
		if volatile then
			local current = Model.normalize(memory[userId], os.time())
			saved = transform(current)
			if saved then
				saved = Model.normalize(saved, os.time())
				saved.Revision = current.Revision + 1
				memory[userId] = saved
			end
		else
			saved = assert(dataStore):UpdateAsync(key(userId), function(raw)
				local current = Model.normalize(raw, os.time())
				local nextProfile = transform(current)
				if not nextProfile then return nil end
				nextProfile = Model.normalize(nextProfile, os.time())
				nextProfile.Revision = current.Revision + 1
				return nextProfile
			end)
		end
	end)
	if ok and saved then cache[userId] = saved end
	release(userId)
	if not ok then warn(`Soul Grind data update failed for {userId}: {err}`) end
	return ok and saved ~= nil, saved
end

function Store.peek(userId)
	return cache[userId]
end

function Store.forget(userId)
	cache[userId] = nil
	if volatile then memory[userId] = nil end
end

return Store
