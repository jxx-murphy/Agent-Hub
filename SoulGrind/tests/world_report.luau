--!nocheck
-- Prints what the built world actually contains. Useful when you cannot open Studio
-- and want a number instead of an adjective.
--
--   lune run tests/world_report.luau

local process = require("@lune/process")
local stub = require("./roblox_stub")
stub.build((process.cwd:gsub("[\\/]+$", "")))
stub.runServer()

local world = stub.Workspace:FindFirstChild("SoulGrindWorld")
local Config = stub.loadModule(`{stub.root}/src/shared/Config.luau`, nil)

local counts, parts, lights = {}, 0, 0
for _, node in world:GetDescendants() do
	if node.ClassName == "Part" or node.ClassName == "SpawnLocation" then
		parts += 1
		counts[node.Name] = (counts[node.Name] or 0) + 1
	elseif node.ClassName == "PointLight" then
		lights += 1
	end
end

local names = {}
for name in counts do table.insert(names, name) end
table.sort(names, function(a, b) return counts[a] > counts[b] end)

print("=== Soul Grind world report ===")
print(`arena per zone : {Config.ArenaHalf.X * 2} x {Config.ArenaHalf.Z * 2} studs`)
print(`total parts    : {parts}`)
print(`point lights   : {lights}`)
print(`fog            : starts {stub.Lighting.FogStart}, ends {stub.Lighting.FogEnd}`)
print(`aggro          : engage {Config.Aggro.Engage}, leash {Config.Aggro.Leash}`)
print("")
print("piece counts (top 24):")
for index = 1, math.min(24, #names) do
	print(string.format("  %-16s %4d", names[index], counts[names[index]]))
end

local signs = stub.signText()
print("")
print(`sign faces     : {#signs}`)
if signs[1] then
	print(`  heading      : {signs[1].Heading}`)
	print(`  body         : {(signs[1].Body or ""):gsub("\n", " / ")}`)
end
process.exit(0)
