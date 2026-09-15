--!nocheck
-- A minimum Roblox API, just large enough to run the real Main and Client scripts
-- outside Studio. It exists so the ability wiring, cooldowns, targeting and RemoteEvent
-- round trip can be tested on every change instead of by hand in Play Solo.
-- It is not an emulator: geometry is translation-only and rendering is not modelled.

local luau = require("@lune/luau")
local fs = require("@lune/fs")
local task = require("@lune/task")

local stub = {}

-- ---------------------------------------------------------------- signals ---
local Signal = {}
Signal.__index = Signal

local function newSignal()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(handler)
	table.insert(self.handlers, handler)
	local connection = { Connected = true }
	function connection:Disconnect()
		for index, candidate in self.handlers or {} do
			if candidate == handler then table.remove(self.handlers, index) break end
		end
	end
	connection.handlers = self.handlers
	return connection
end
Signal.Once = Signal.Connect

function Signal:Fire(...)
	for _, handler in table.clone(self.handlers) do
		local ok, err = pcall(handler, ...)
		if not ok then warn(`signal handler error: {err}`) end
	end
end

function Signal:Wait()
	return nil
end

-- ------------------------------------------------------------- math types ---
local Vector3 = {}
Vector3.__index = Vector3

local function vec3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end

Vector3.__add = function(a, b) return vec3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__sub = function(a, b) return vec3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__unm = function(a) return vec3(-a.X, -a.Y, -a.Z) end
Vector3.__mul = function(a, b)
	if type(b) == "number" then return vec3(a.X * b, a.Y * b, a.Z * b) end
	if type(a) == "number" then return vec3(b.X * a, b.Y * a, b.Z * a) end
	return vec3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__div = function(a, b)
	if type(b) == "number" then return vec3(a.X / b, a.Y / b, a.Z / b) end
	return vec3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3.__tostring = function(a) return `({a.X}, {a.Y}, {a.Z})` end
Vector3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(rawget(self, "X") ^ 2 + rawget(self, "Y") ^ 2 + rawget(self, "Z") ^ 2)
	elseif key == "Unit" then
		local magnitude = (self :: any).Magnitude
		if magnitude == 0 then return vec3(0, 0, 0) end
		return vec3(rawget(self, "X") / magnitude, rawget(self, "Y") / magnitude, rawget(self, "Z") / magnitude)
	end
	return rawget(Vector3, key)
end

local Vector3Lib = { new = function(x, y, z) return vec3(x, y, z) end, zero = vec3(0, 0, 0), one = vec3(1, 1, 1) }

local Vector2Lib = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }

-- Rotation is deliberately ignored: these tests care about distance and reach, and a
-- translation-only CFrame keeps every position in the world exactly where Roblox puts it.
local CFrameMeta = {}
CFrameMeta.__index = function(self, key)
	if key == "Position" or key == "p" then return rawget(self, "_position") end
	if key == "LookVector" then return rawget(self, "_look") end
	if key == "X" then return rawget(self, "_position").X end
	if key == "Y" then return rawget(self, "_position").Y end
	if key == "Z" then return rawget(self, "_position").Z end
	return rawget(CFrameMeta, key)
end

local function newCFrame(position, look)
	return setmetatable({ _position = position, _look = look or vec3(0, 0, -1) }, CFrameMeta)
end

CFrameMeta.__mul = function(a, b)
	if getmetatable(b) == Vector3 then return a._position + b end
	return newCFrame(a._position + b._position, a._look)
end

local CFrameLib = {
	new = function(x, y, z)
		if type(x) == "table" then return newCFrame(x) end
		return newCFrame(vec3(x or 0, y or 0, z or 0))
	end,
	Angles = function() return newCFrame(vec3(0, 0, 0)) end,
	fromEulerAnglesXYZ = function() return newCFrame(vec3(0, 0, 0)) end,
	lookAt = function(from) return newCFrame(from) end,
	identity = newCFrame(vec3(0, 0, 0)),
}

local Color3Lib = {
	new = function(r, g, b) return { R = r or 0, G = g or 0, B = b or 0 } end,
	fromRGB = function(r, g, b) return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 } end,
}

local function simple(...)
	local values = { ... }
	return { unpack = values }
end

local ColorSequenceLib = { new = simple }
local NumberSequenceLib = { new = simple }
local NumberRangeLib = { new = function(min, max) return { Min = min, Max = max or min } end }
local TweenInfoLib = { new = function(time, ...) return { Time = time or 1 } end }
local UDimLib = { new = function(scale, offset) return { Scale = scale or 0, Offset = offset or 0 } end }
local UDim2Lib = {}
UDim2Lib.new = function(sx, ox, sy, oy)
	return { X = { Scale = sx or 0, Offset = ox or 0 }, Y = { Scale = sy or 0, Offset = oy or 0 } }
end
UDim2Lib.fromOffset = function(x, y) return UDim2Lib.new(0, x, 0, y) end
UDim2Lib.fromScale = function(x, y) return UDim2Lib.new(x, 0, y, 0) end

-- Enum tokens memoise so identity comparison (`state == Enum.UserInputState.Begin`) holds.
local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		if not enumCache[enumName] then
			local items = {}
			enumCache[enumName] = setmetatable({}, {
				__index = function(_, itemName)
					if not items[itemName] then
						items[itemName] = { Name = itemName, EnumType = enumName, Value = 0 }
					end
					return items[itemName]
				end,
			})
		end
		return enumCache[enumName]
	end,
})

-- ------------------------------------------------------------- instances ---
local instanceMethods = {}
local Instance = {}

local classParents = {
	Part = "BasePart", SpawnLocation = "Part", MeshPart = "BasePart",
	Script = "LuaSourceContainer", LocalScript = "LuaSourceContainer", ModuleScript = "LuaSourceContainer",
	TextLabel = "GuiObject", TextButton = "GuiObject", Frame = "GuiObject", ImageLabel = "GuiObject",
}

local function isA(self, className)
	local current = self.ClassName
	while current do
		if current == className then return true end
		current = classParents[current]
	end
	return className == "Instance"
end

local signalNames = {
	Event = true, OnServerEvent = true, OnClientEvent = true, Triggered = true, Touched = true,
	Died = true, HealthChanged = true, CharacterAdded = true, CharacterRemoving = true,
	PlayerAdded = true, PlayerRemoving = true, Activated = true, MouseButton1Click = true,
	Changed = true, Completed = true, AncestryChanged = true, ChildAdded = true, ChildRemoved = true,
}

local function newInstance(className)
	local self
	local properties = { ClassName = className, Name = className, Archivable = true }
	local children = {}
	local attributes = {}
	local signals = {}

	local proxy = {}

	self = setmetatable({}, {
		__index = function(_, key)
			if instanceMethods[key] then return instanceMethods[key] end
			if signalNames[key] then
				if not signals[key] then signals[key] = newSignal() end
				return signals[key]
			end
			if key == "_children" then return children end
			if key == "_attributes" then return attributes end
			if key == "_signals" then return signals end
			local child = properties[key]
			if child ~= nil then return child end
			for _, candidate in children do
				if candidate.Name == key then return candidate end
			end
			return nil
		end,
		__newindex = function(_, key, value)
			if key == "Parent" then
				local old = properties.Parent
				if old then
					for index, candidate in old._children do
						if candidate == self then table.remove(old._children, index) break end
					end
				end
				properties.Parent = value
				if value then table.insert(value._children, self) end
				return
			end
			if key == "Health" and className == "Humanoid" then
				local clamped = math.clamp(value, 0, properties.MaxHealth or 100)
				properties.Health = clamped
				self.HealthChanged:Fire(clamped)
				if clamped <= 0 and not properties._dead then
					properties._dead = true
					self.Died:Fire()
				end
				return
			end
			if key == "CFrame" then
				properties.CFrame = value
				properties.Position = value.Position
				return
			end
			if key == "Position" and (className == "Part" or className == "SpawnLocation" or className == "MeshPart") then
				properties.Position = value
				properties.CFrame = CFrameLib.new(value)
				return
			end
			properties[key] = value
		end,
		__tostring = function() return properties.Name end,
	})

	properties.Position = vec3(0, 0, 0)
	properties.CFrame = newCFrame(vec3(0, 0, 0))
	properties.Size = vec3(1, 1, 1)
	properties.AssemblyLinearVelocity = vec3(0, 0, 0)
	-- Roblox part defaults, so palette and material sweeps never read nil.
	properties.Color = Color3Lib.fromRGB(163, 162, 165)
	properties.Material = Enum.Material.Plastic
	properties.Transparency = 0
	properties.CanCollide = true
	if className == "Humanoid" then
		properties.MaxHealth = 100
		properties.Health = 100
		properties.WalkSpeed = 16
	end
	proxy.self = self
	return self
end

function instanceMethods:IsA(className) return isA(self, className) end
function instanceMethods:GetChildren() return table.clone(self._children) end
function instanceMethods:GetDescendants()
	local out = {}
	for _, child in self._children do
		table.insert(out, child)
		for _, deep in child:GetDescendants() do table.insert(out, deep) end
	end
	return out
end
function instanceMethods:FindFirstChild(name)
	for _, child in self._children do
		if child.Name == name then return child end
	end
	return nil
end
function instanceMethods:FindFirstChildOfClass(className)
	for _, child in self._children do
		if child.ClassName == className then return child end
	end
	return nil
end
function instanceMethods:FindFirstChildWhichIsA(className)
	for _, child in self._children do
		if child:IsA(className) then return child end
	end
	return nil
end
function instanceMethods:WaitForChild(name)
	return self:FindFirstChild(name)
end
function instanceMethods:Destroy()
	self.Parent = nil
	for _, child in table.clone(self._children) do child:Destroy() end
end
instanceMethods.ClearAllChildren = function(self)
	for _, child in table.clone(self._children) do child:Destroy() end
end
function instanceMethods:SetAttribute(name, value) self._attributes[name] = value end
function instanceMethods:GetAttribute(name) return self._attributes[name] end
function instanceMethods:GetPropertyChangedSignal() return newSignal() end
function instanceMethods:Clone()
	local copy = newInstance(self.ClassName)
	copy.Name = self.Name
	return copy
end
function instanceMethods:PivotTo(cframe)
	local root = self:FindFirstChild("HumanoidRootPart")
	if root then root.CFrame = cframe end
	self.WorldPivot = cframe
end
function instanceMethods:GetPivot()
	local root = self:FindFirstChild("HumanoidRootPart")
	return root and root.CFrame or self.CFrame
end
function instanceMethods:MoveTo(position) self.MoveTarget = position end
function instanceMethods:TakeDamage(amount)
	if self.ClassName ~= "Humanoid" then return end
	self.Health = math.max(0, self.Health - amount)
end
function instanceMethods:SetNetworkOwner() end
function instanceMethods:Emit() end
function instanceMethods:FireServer(...)
	self.OnServerEvent:Fire(stub.localPlayer, ...)
end
function instanceMethods:FireClient(player, ...)
	if player == stub.localPlayer then self.OnClientEvent:Fire(...) end
	table.insert(stub.clientEvents, { Remote = self.Name, Player = player, Args = { ... } })
end
function instanceMethods:FireAllClients(...)
	self.OnClientEvent:Fire(...)
	table.insert(stub.clientEvents, { Remote = self.Name, Player = "all", Args = { ... } })
end
function instanceMethods:Play() self.Completed:Fire() end
function instanceMethods:Cancel() end
function instanceMethods:Kick(reason) stub.kicked = reason or true end
function instanceMethods:IsFriendsWith() return false end
function instanceMethods:LoadCharacter() end

Instance.new = function(className, parent)
	local created = newInstance(className)
	if parent then created.Parent = parent end
	return created
end

-- --------------------------------------------------------------- services ---
local game = newInstance("DataModel")
game.Name = "Game"

local services = {}
local function service(className, name)
	local created = newInstance(className)
	created.Name = name or className
	created.Parent = game
	services[name or className] = created
	return created
end

local Workspace = service("Workspace", "Workspace")
local ReplicatedStorage = service("ReplicatedStorage", "ReplicatedStorage")
local ServerScriptService = service("ServerScriptService", "ServerScriptService")
local ServerStorage = service("ServerStorage", "ServerStorage")
local StarterPlayer = service("StarterPlayer", "StarterPlayer")
local Lighting = service("Lighting", "Lighting")
local PlayersService = service("Players", "Players")

local camera = newInstance("Camera")
camera.ViewportSize = Vector2Lib.new(1280, 720)
camera.FieldOfView = 70
camera.Parent = Workspace
Workspace.CurrentCamera = camera

local renderStepped = newSignal()
local inputBegan = newSignal()

services.RunService = {
	IsStudio = function() return true end,
	IsServer = function() return true end,
	IsClient = function() return true end,
	RenderStepped = renderStepped,
	Heartbeat = newSignal(),
	Stepped = newSignal(),
}
services.Debris = {
	AddItem = function(_, item, lifetime)
		task.delay(lifetime or 1, function() pcall(function() item:Destroy() end) end)
	end,
}
services.TweenService = {
	Create = function(_, object, _info, goals)
		local tween = newInstance("Tween")
		function tween.Play()
			for key, value in goals do pcall(function() object[key] = value end) end
			tween.Completed:Fire()
		end
		tween.Cancel = function() end
		return tween
	end,
}
services.DataStoreService = {
	GetDataStore = function() error("DataStore must not be reached in the stub run", 2) end,
}
services.MarketplaceService = {
	PromptGamePassPurchaseFinished = newSignal(),
	PromptProductPurchaseFinished = newSignal(),
	UserOwnsGamePassAsync = function() return false end,
	GetProductInfoAsync = function() return { PriceInRobux = 49 } end,
	PromptProductPurchase = function() end,
	PromptGamePassPurchase = function() end,
}
services.SocialService = {
	CanSendGameInviteAsync = function() return false end,
	PromptGameInvite = function() end,
}
stub.boundActions = {}
services.ContextActionService = {
	BindAction = function(_, name, handler, createTouchButton, ...)
		stub.boundActions[name] = { Handler = handler, Touch = createTouchButton, Keys = { ... } }
	end,
	UnbindAction = function(_, name) stub.boundActions[name] = nil end,
}
services.UserInputService = {
	InputBegan = inputBegan,
	InputEnded = newSignal(),
	TouchEnabled = false,
	KeyboardEnabled = true,
}

function game.GetService(_, name)
	local found = services[name]
	if not found then error(`stub is missing service {name}`, 2) end
	return found
end
game.FindService = game.GetService
game.BindToClose = function() end

PlayersService.GetPlayers = function()
	local out = {}
	for _, child in PlayersService._children do
		if child.ClassName == "Player" then table.insert(out, child) end
	end
	return out
end
PlayersService.GetPlayerByUserId = function(_, userId)
	for _, candidate in PlayersService:GetPlayers() do
		if candidate.UserId == userId then return candidate end
	end
	return nil
end

-- ----------------------------------------------------------- module loader ---
stub.clientEvents = {}
stub.notices = {}
stub.warnings = {}

local loaded = {}

local function sandboxRequire(target)
	if type(target) == "table" and target._modulePath then
		if loaded[target] == nil then
			loaded[target] = stub.loadModule(target._modulePath, target)
		end
		return loaded[target]
	end
	error(`stub require received an unsupported target: {tostring(target)}`, 2)
end

-- A virtual os.clock lets the tests step through real server cooldowns in microseconds
-- instead of sleeping through them.
stub.clock = 1000
local osProxy = setmetatable({}, {
	__index = function(_, key)
		if key == "clock" then return function() return stub.clock end end
		return os[key]
	end,
})

function stub.advance(seconds)
	stub.clock += seconds
end

local function environment(scriptInstance)
	return {
		game = game,
		os = osProxy,
		workspace = Workspace,
		script = scriptInstance,
		Instance = Instance,
		Enum = Enum,
		Vector3 = Vector3Lib,
		Vector2 = Vector2Lib,
		CFrame = CFrameLib,
		Color3 = Color3Lib,
		ColorSequence = ColorSequenceLib,
		NumberSequence = NumberSequenceLib,
		NumberRange = NumberRangeLib,
		TweenInfo = TweenInfoLib,
		UDim = UDimLib,
		UDim2 = UDim2Lib,
		task = task,
		require = sandboxRequire,
		warn = function(...)
			table.insert(stub.warnings, table.concat({ ... }, " "))
		end,
		print = print,
	}
end

function stub.loadModule(path, scriptInstance)
	local source = fs.readFile(path)
	local chunk = luau.load(source, {
		debugName = path,
		environment = environment(scriptInstance),
		injectGlobals = true,
	})
	return chunk()
end

-- Build the same instance tree default.project.json describes, then run the real files.
function stub.build(root)
	local folder = Instance.new("Folder", ReplicatedStorage)
	folder.Name = "SoulGrind"

	local config = Instance.new("ModuleScript", folder)
	config.Name = "Config"
	config._modulePath = `{root}/src/shared/Config.luau`

	local quests = Instance.new("ModuleScript", folder)
	quests.Name = "Quests"
	quests._modulePath = `{root}/src/shared/Quests.luau`

	for _, name in { "Action", "State", "Notice", "Offer", "FX" } do
		local remote = Instance.new("RemoteEvent", folder)
		remote.Name = name
	end

	for _, entry in { { "Model", "Model" }, { "Receipt", "Receipt" }, { "Store", "Store" }, { "Commerce", "Commerce" }, { "World", "World" } } do
		local module = Instance.new("ModuleScript", ServerScriptService)
		module.Name = entry[1]
		module._modulePath = `{root}/src/server/{entry[2]}.luau`
	end

	local testsFolder = Instance.new("Folder", ServerStorage)
	testsFolder.Name = "SoulGrindTests"

	stub.root = root
	stub.game = game
	stub.services = services
	stub.Instance = Instance
	stub.Enum = Enum
	stub.Vector3 = Vector3Lib
	stub.CFrame = CFrameLib
	stub.remotes = folder
	stub.renderStepped = renderStepped
	stub.inputBegan = inputBegan
	stub.Players = PlayersService
	stub.Workspace = Workspace
	stub.Lighting = Lighting
	stub.StarterPlayer = StarterPlayer
	return stub
end

function stub.runServer()
	local mainScript = Instance.new("Script", ServerScriptService)
	mainScript.Name = "Main"
	stub.loadModule(`{stub.root}/src/server/Main.server.luau`, mainScript)
end

function stub.runClient()
	local playerScripts = Instance.new("StarterPlayerScripts", StarterPlayer)
	local clientScript = Instance.new("LocalScript", playerScripts)
	clientScript.Name = "Client"
	stub.loadModule(`{stub.root}/src/client/Client.client.luau`, clientScript)
end

-- A player plus a character rig the server scripts can actually reach into.
function stub.addPlayer(name, userId)
	local player = newInstance("Player")
	player.Name = name
	player.UserId = userId
	local playerGui = Instance.new("PlayerGui", player)
	playerGui.Name = "PlayerGui"
	player.Parent = PlayersService
	stub.localPlayer = player
	PlayersService.LocalPlayer = player
	PlayersService.PlayerAdded:Fire(player)
	return player
end

function stub.spawnCharacter(player, position)
	local character = Instance.new("Model", Workspace)
	character.Name = player.Name
	local root = Instance.new("Part", character)
	root.Name = "HumanoidRootPart"
	root.Size = vec3(2, 2, 1)
	root.CFrame = CFrameLib.new(position or vec3(0, 6, 38))
	local humanoid = Instance.new("Humanoid", character)
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	local head = Instance.new("Part", character)
	head.Name = "Head"
	character.PrimaryPart = root
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end

function stub.moveTo(player, position)
	player.Character:FindFirstChild("HumanoidRootPart").CFrame = CFrameLib.new(position)
end

-- Test helpers ---------------------------------------------------------------
function stub.takeClientEvents(remoteName, kind)
	local out = {}
	for _, entry in stub.clientEvents do
		if entry.Remote == remoteName then
			local payload = entry.Args[1]
			if not kind or (type(payload) == "table" and payload.Kind == kind) then
				table.insert(out, payload)
			end
		end
	end
	return out
end

function stub.clearClientEvents()
	stub.clientEvents = {}
end

-- Advance past the server's remote throttle and the client's own repeat guard, the way
-- a real player's hands would.
function stub.fireKey(actionName, keyName)
	stub.advance(0.2)
	local binding = stub.boundActions[actionName]
	assert(binding, `no action bound under {actionName}`)
	local matched = false
	for _, key in binding.Keys do
		if key.Name == keyName then matched = true end
	end
	assert(matched, `{actionName} is not bound to {keyName}`)
	binding.Handler(actionName, Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode[keyName] })
end

function stub.clickButton(pathName)
	stub.advance(0.2)
	local found
	local function walk(node)
		for _, child in node._children do
			if child.Name == pathName and (child.ClassName == "TextButton" or child.ClassName == "ImageButton") then
				found = child
			end
			walk(child)
		end
	end
	walk(stub.localPlayer:FindFirstChild("PlayerGui"))
	assert(found, `no on-screen button named {pathName}`)
	found.Activated:Fire()
	return found
end

function stub.findGui(name)
	local found
	local function walk(node)
		for _, child in node._children do
			if child.Name == name then found = found or child end
			walk(child)
		end
	end
	walk(stub.localPlayer:FindFirstChild("PlayerGui"))
	return found
end

function stub.enemies(zoneId)
	local out = {}
	local world = Workspace:FindFirstChild("SoulGrindWorld")
	if not world then return out end
	for _, child in world:GetDescendants() do
		if child.ClassName == "Model" and child:GetAttribute("Enemy") then
			if not zoneId or child:GetAttribute("Zone") == zoneId then table.insert(out, child) end
		end
	end
	return out
end

function stub.livingEnemies(zoneId)
	local out = {}
	for _, enemy in stub.enemies(zoneId) do
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then table.insert(out, enemy) end
	end
	return out
end

-- Every PointLight in the world, for the "did the lighting wash out again" budget.
function stub.lightBudget()
	local world = Workspace:FindFirstChild("SoulGrindWorld")
	local count, load, brightest, longest = 0, 0, 0, 0
	if not world then return { Count = 0, Load = 0, Brightest = 0, Longest = 0 } end
	for _, node in world:GetDescendants() do
		if node.ClassName == "PointLight" or node.ClassName == "SpotLight" then
			count += 1
			load += node.Brightness * node.Range
			brightest = math.max(brightest, node.Brightness)
			longest = math.max(longest, node.Range)
		end
	end
	return { Count = count, Load = load, Brightest = brightest, Longest = longest }
end

-- Collect the text currently shown on the stone signs standing in the world.
function stub.signText()
	local world = Workspace:FindFirstChild("SoulGrindWorld")
	local out = {}
	if not world then return out end
	for _, node in world:GetDescendants() do
		if node.ClassName == "SurfaceGui" and node.Name == "SignFace" then
			local heading, body
			for _, deep in node:GetDescendants() do
				if deep.Name == "Heading" then heading = deep.Text end
				if deep.Name == "Body" then body = deep.Text end
			end
			table.insert(out, { Heading = heading, Body = body })
		end
	end
	return out
end

stub.require = sandboxRequire
stub.newSignal = newSignal
stub.vec3 = vec3
return stub
