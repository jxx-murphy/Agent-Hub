local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SoulGrind")
-- Ranges and cooldowns come from the same module the server reads, so the target plate
-- can never promise a reach the server will refuse.
local Config = require(remotes:WaitForChild("Config"))
local Action = remotes:WaitForChild("Action")
local State = remotes:WaitForChild("State")
local Notice = remotes:WaitForChild("Notice")
local Offer = remotes:WaitForChild("Offer")
local FX = remotes:WaitForChild("FX")

local ink = Color3.fromRGB(10, 9, 19)
local panelColor = Color3.fromRGB(23, 18, 38)
local purple = Color3.fromRGB(181, 82, 255)
local cyan = Color3.fromRGB(74, 220, 255)
local pale = Color3.fromRGB(238, 230, 255)
local muted = Color3.fromRGB(170, 157, 194)
local ember = Color3.fromRGB(255, 126, 71)

local gui = Instance.new("ScreenGui")
gui.Name = "SoulGrindUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function round(object, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = object
	local stroke = Instance.new("UIStroke")
	stroke.Color = purple
	stroke.Transparency = 0.45
	stroke.Thickness = 1
	stroke.Parent = object
end

local function gradient(object, first, second, rotation)
	local fill = Instance.new("UIGradient")
	fill.Color = ColorSequence.new(first, second)
	fill.Rotation = rotation or 0
	fill.Parent = object
	return fill
end

local function textLabel(parent, name, text, size, position, fontSize, color, align)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Text = text
	label.TextColor3 = color or pale
	label.TextSize = fontSize or 16
	label.Font = Enum.Font.GothamMedium
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function button(parent, name, text, size, position, color)
	local control = Instance.new("TextButton")
	control.Name = name
	control.Size = size
	control.Position = position
	control.BackgroundColor3 = color or panelColor
	control.AutoButtonColor = true
	control.Text = text
	control.TextColor3 = pale
	control.TextSize = 15
	control.TextWrapped = true
	control.Font = Enum.Font.GothamBold
	control.Parent = parent
	round(control, 9)
	return control
end

local hud = Instance.new("Frame")
hud.Name = "HUD"
hud.Size = UDim2.new(0, 370, 0, 206)
hud.Position = UDim2.fromOffset(18, 18)
hud.BackgroundColor3 = ink
hud.BackgroundTransparency = 0.06
hud.Parent = gui
round(hud, 14)
gradient(hud, Color3.fromRGB(18, 14, 29), Color3.fromRGB(8, 10, 18), 18)
local hudScale = Instance.new("UIScale")
hudScale.Parent = hud

local accent = Instance.new("Frame")
accent.Name = "Accent"
accent.Size = UDim2.new(0, 4, 1, -24)
accent.Position = UDim2.fromOffset(0, 12)
accent.BackgroundColor3 = purple
accent.BorderSizePixel = 0
accent.Parent = hud
local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(1, 0)
accentCorner.Parent = accent
gradient(accent, purple, cyan, 90)

local title = textLabel(hud, "Title", "SOUL GRIND", UDim2.new(0, 190, 0, 26), UDim2.fromOffset(16, 10), 20, purple)
title.Font = Enum.Font.GothamBlack
local zoneTag = textLabel(hud, "Zone", "AWAKENING", UDim2.fromOffset(142, 24), UDim2.new(1, -155, 0, 10), 11, cyan, Enum.TextXAlignment.Right)
zoneTag.Font = Enum.Font.GothamBold
local stats = textLabel(hud, "Stats", "Loading your soul...", UDim2.new(1, -32, 0, 48), UDim2.fromOffset(16, 40), 16, pale)
local goal = textLabel(hud, "Goal", "", UDim2.new(1, -32, 0, 34), UDim2.fromOffset(16, 94), 13, pale)
goal.Font = Enum.Font.GothamBold
local goalBack = Instance.new("Frame")
goalBack.Name = "GoalTrack"
goalBack.Size = UDim2.new(1, -32, 0, 7)
goalBack.Position = UDim2.fromOffset(16, 133)
goalBack.BackgroundColor3 = Color3.fromRGB(40, 34, 52)
goalBack.BorderSizePixel = 0
goalBack.Parent = hud
local goalCorner = Instance.new("UICorner")
goalCorner.CornerRadius = UDim.new(1, 0)
goalCorner.Parent = goalBack
local goalFill = Instance.new("Frame")
goalFill.Name = "Fill"
goalFill.Size = UDim2.fromScale(0, 1)
goalFill.BackgroundColor3 = purple
goalFill.BorderSizePixel = 0
goalFill.Parent = goalBack
local goalFillCorner = goalCorner:Clone()
goalFillCorner.Parent = goalFill
gradient(goalFill, purple, cyan)
local save = textLabel(hud, "Save", "", UDim2.new(1, -32, 0, 18), UDim2.fromOffset(16, 149), 11, muted)
local controls = textLabel(hud, "Controls", "F or CLICK strike   •   Q pulse   •   E step   •   WASD move", UDim2.new(1, -32, 0, 16), UDim2.fromOffset(16, 167), 11, cyan)

-- The drain overlay is the whole point: a button that visibly recharges tells the player
-- "the input landed, wait" instead of leaving them convinced the key is broken.
local function addCooldownOverlay(control)
	control.ClipsDescendants = true
	local cool = Instance.new("Frame")
	cool.Name = "Cool"
	cool.AnchorPoint = Vector2.new(0, 1)
	cool.Position = UDim2.fromScale(0, 1)
	cool.Size = UDim2.fromScale(1, 0)
	cool.BackgroundColor3 = Color3.fromRGB(6, 5, 12)
	cool.BackgroundTransparency = 0.45
	cool.BorderSizePixel = 0
	cool.Visible = false
	cool.ZIndex = 3
	cool.Parent = control
	return control
end

-- One bar, one UIScale: the three controls shrink together on a phone instead of
-- sliding off the edge of the screen.
local abilityBar = Instance.new("Frame")
abilityBar.Name = "Abilities"
abilityBar.AnchorPoint = Vector2.new(0.5, 1)
abilityBar.Position = UDim2.new(0.5, 0, 1, -18)
abilityBar.Size = UDim2.fromOffset(444, 82)
abilityBar.BackgroundTransparency = 1
abilityBar.Parent = gui
local abilityScale = Instance.new("UIScale")
abilityScale.Parent = abilityBar

local attackButton = addCooldownOverlay(button(abilityBar, "Attack", "F / CLICK\nSOUL STRIKE", UDim2.fromOffset(140, 82), UDim2.fromOffset(0, 0), Color3.fromRGB(122, 44, 180)))
gradient(attackButton, Color3.fromRGB(158, 60, 226), Color3.fromRGB(88, 32, 136), 90)
local pulseButton = addCooldownOverlay(button(abilityBar, "Pulse", "Q\nSOUL PULSE", UDim2.fromOffset(140, 82), UDim2.fromOffset(152, 0), Color3.fromRGB(32, 120, 156)))
gradient(pulseButton, Color3.fromRGB(46, 160, 196), Color3.fromRGB(26, 88, 124), 90)
local dashButton = addCooldownOverlay(button(abilityBar, "Dash", "E\nSOUL STEP", UDim2.fromOffset(140, 82), UDim2.fromOffset(304, 0), Color3.fromRGB(132, 72, 54)))
gradient(dashButton, Color3.fromRGB(196, 96, 60), Color3.fromRGB(96, 46, 52), 90)

local function sweep(control, seconds)
	local cool = control:FindFirstChild("Cool")
	if not cool or type(seconds) ~= "number" or seconds <= 0.01 then return end
	cool.Size = UDim2.fromScale(1, 1)
	cool.Visible = true
	local token = os.clock()
	cool:SetAttribute("Token", token)
	local tween = TweenService:Create(cool, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 0) })
	tween:Play()
	task.delay(seconds, function()
		if cool:GetAttribute("Token") == token then cool.Visible = false end
	end)
end

local function press(control)
	local stroke = control:FindFirstChildOfClass("UIStroke")
	if not stroke then return end
	stroke.Transparency = 0
	stroke.Thickness = 3
	TweenService:Create(stroke, TweenInfo.new(0.22), { Transparency = 0.45, Thickness = 1 }):Play()
end

local menuButton = button(gui, "MenuToggle", "JOURNAL", UDim2.fromOffset(115, 42), UDim2.new(1, -131, 0, 84), panelColor)
local inviteButton = button(gui, "Invite", "INVITE FRIEND", UDim2.fromOffset(140, 42), UDim2.new(1, -286, 0, 84), panelColor)
gradient(menuButton, Color3.fromRGB(38, 29, 58), Color3.fromRGB(20, 18, 31), 90)
gradient(inviteButton, Color3.fromRGB(51, 30, 67), Color3.fromRGB(24, 18, 35), 90)

local targetFrame = Instance.new("Frame")
targetFrame.Name = "Target"
targetFrame.Size = UDim2.fromOffset(330, 74)
targetFrame.Position = UDim2.new(0.5, -165, 0, 18)
targetFrame.BackgroundColor3 = ink
targetFrame.BackgroundTransparency = 0.08
targetFrame.Visible = false
targetFrame.Parent = gui
round(targetFrame, 12)
gradient(targetFrame, Color3.fromRGB(31, 20, 42), Color3.fromRGB(12, 12, 20))
local targetName = textLabel(targetFrame, "Name", "", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 6), 14, pale, Enum.TextXAlignment.Center)
targetName.Font = Enum.Font.GothamBold
local targetBack = Instance.new("Frame")
targetBack.Size = UDim2.new(1, -32, 0, 8)
targetBack.Position = UDim2.fromOffset(16, 37)
targetBack.BackgroundColor3 = Color3.fromRGB(45, 35, 49)
targetBack.BorderSizePixel = 0
targetBack.Parent = targetFrame
local targetCorner = Instance.new("UICorner")
targetCorner.CornerRadius = UDim.new(1, 0)
targetCorner.Parent = targetBack
local targetFill = Instance.new("Frame")
targetFill.Size = UDim2.fromScale(1, 1)
targetFill.BackgroundColor3 = purple
targetFill.BorderSizePixel = 0
targetFill.Parent = targetBack
local targetFillCorner = targetCorner:Clone()
targetFillCorner.Parent = targetFill
local targetRange = textLabel(targetFrame, "Range", "", UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 48), 12, muted, Enum.TextXAlignment.Center)

local comboLabel = textLabel(gui, "Combo", "", UDim2.fromOffset(300, 48), UDim2.new(0.5, -150, 0.68, 0), 22, pale, Enum.TextXAlignment.Center)
comboLabel.Font = Enum.Font.GothamBlack
comboLabel.TextStrokeTransparency = 0.2
comboLabel.Visible = false

local healthPanel = Instance.new("Frame")
healthPanel.Name = "Health"
healthPanel.Size = UDim2.fromOffset(215, 28)
healthPanel.Position = UDim2.new(0, 18, 1, -116)
healthPanel.BackgroundColor3 = ink
healthPanel.BackgroundTransparency = 0.08
healthPanel.Parent = gui
round(healthPanel, 10)
local healthFill = Instance.new("Frame")
healthFill.Name = "Fill"
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.BackgroundColor3 = ember
healthFill.BorderSizePixel = 0
healthFill.Parent = healthPanel
local healthCorner = Instance.new("UICorner")
healthCorner.CornerRadius = UDim.new(0, 9)
healthCorner.Parent = healthFill
gradient(healthFill, Color3.fromRGB(229, 61, 76), ember)
local healthText = textLabel(healthPanel, "Text", "BODY 100 / 100", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 12, pale, Enum.TextXAlignment.Center)
healthText.ZIndex = 2

local damageFlash = Instance.new("Frame")
damageFlash.Name = "DamageFlash"
damageFlash.Size = UDim2.fromScale(1, 1)
damageFlash.BackgroundColor3 = Color3.fromRGB(170, 15, 35)
damageFlash.BackgroundTransparency = 1
damageFlash.BorderSizePixel = 0
damageFlash.ZIndex = 50
damageFlash.Active = false
damageFlash.Selectable = false
damageFlash.Parent = gui

local menu = Instance.new("Frame")
menu.Name = "Journal"
menu.Size = UDim2.fromOffset(360, 490)
menu.AnchorPoint = Vector2.new(1, 0)
menu.Position = UDim2.new(1, -16, 0, 136)
menu.BackgroundColor3 = ink
menu.BackgroundTransparency = 0.04
menu.Visible = false
menu.Parent = gui
round(menu, 12)
gradient(menu, Color3.fromRGB(20, 15, 32), Color3.fromRGB(8, 10, 18), 35)
local menuScale = Instance.new("UIScale")
menuScale.Parent = menu

local menuTitle = textLabel(menu, "Title", "UNDERWORLD JOURNAL", UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 10), 19, purple)
menuTitle.Font = Enum.Font.GothamBlack
local daily = textLabel(menu, "Daily", "", UDim2.new(1, -24, 0, 82), UDim2.fromOffset(12, 48), 14, pale)
local checkIn = textLabel(menu, "CheckIn", "", UDim2.new(1, -24, 0, 52), UDim2.fromOffset(12, 126), 13, cyan)
for _, card in { daily, checkIn } do
	card.BackgroundColor3 = panelColor
	card.BackgroundTransparency = 0.35
	round(card, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = card
end

local claim = button(menu, "Claim", "CLAIM DAILY", UDim2.new(0.5, -18, 0, 42), UDim2.fromOffset(12, 184), Color3.fromRGB(64, 80, 126))
local upgrade = button(menu, "Upgrade", "UPGRADE", UDim2.new(0.5, -18, 0, 54), UDim2.new(0.5, 6, 0, 184), Color3.fromRGB(91, 42, 133))
local gateButton = button(menu, "Gate", "OPEN / ENTER\nASH GATE", UDim2.new(0.5, -18, 0, 54), UDim2.fromOffset(12, 246), Color3.fromRGB(109, 48, 139))
local travelButton = button(menu, "Travel", "TRAVEL\nZONE 1", UDim2.new(0.5, -18, 0, 54), UDim2.new(0.5, 6, 0, 246), Color3.fromRGB(35, 92, 118))
local rebirth = button(menu, "Rebirth", "REBIRTH", UDim2.new(0.5, -18, 0, 54), UDim2.fromOffset(12, 308), Color3.fromRGB(121, 42, 78))
local flare = button(menu, "Flare", "SOUL FLARE", UDim2.new(0.5, -18, 0, 54), UDim2.new(0.5, 6, 0, 308), Color3.fromRGB(66, 54, 122))
local aura = button(menu, "Aura", "VIOLET AURA", UDim2.new(0.5, -18, 0, 54), UDim2.fromOffset(12, 370), Color3.fromRGB(87, 38, 125))
local collection = textLabel(menu, "Collection", "", UDim2.new(0.5, -18, 0, 88), UDim2.new(0.5, 6, 0, 370), 12, muted)

local rebirthConfirm = Instance.new("Frame")
rebirthConfirm.Size = UDim2.fromOffset(330, 170)
rebirthConfirm.Position = UDim2.new(0.5, -165, 0.5, -85)
rebirthConfirm.BackgroundColor3 = ink
rebirthConfirm.Visible = false
rebirthConfirm.ZIndex = 20
rebirthConfirm.Parent = gui
round(rebirthConfirm, 12)
local confirmText = textLabel(rebirthConfirm, "Warning", "REBIRTH?\nSouls and Soul Level reset. Zones, collection, and +10% permanent damage remain.", UDim2.new(1, -24, 0, 95), UDim2.fromOffset(12, 12), 15, pale, Enum.TextXAlignment.Center)
confirmText.ZIndex = 21
local confirm = button(rebirthConfirm, "Confirm", "REBIRTH", UDim2.fromOffset(140, 44), UDim2.fromOffset(18, 112), Color3.fromRGB(126, 37, 72))
confirm.ZIndex = 21
local cancel = button(rebirthConfirm, "Cancel", "CANCEL", UDim2.fromOffset(140, 44), UDim2.fromOffset(172, 112), panelColor)
cancel.ZIndex = 21

local offerPanel = Instance.new("Frame")
offerPanel.Size = UDim2.fromOffset(350, 235)
offerPanel.Position = UDim2.new(0.5, -175, 0.5, -118)
offerPanel.BackgroundColor3 = ink
offerPanel.Visible = false
offerPanel.ZIndex = 30
offerPanel.Parent = gui
round(offerPanel, 12)
local offerScale = Instance.new("UIScale")
offerScale.Parent = offerPanel
local offerTitle = textLabel(offerPanel, "Title", "", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 14), 19, purple, Enum.TextXAlignment.Center)
offerTitle.ZIndex = 31
local offerDescription = textLabel(offerPanel, "Description", "", UDim2.new(1, -30, 0, 95), UDim2.fromOffset(15, 55), 14, pale, Enum.TextXAlignment.Center)
offerDescription.ZIndex = 31
local buy = button(offerPanel, "Buy", "VIEW ROBUX PRICE", UDim2.fromOffset(180, 48), UDim2.fromOffset(20, 170), Color3.fromRGB(92, 43, 138))
buy.ZIndex = 31
local closeOffer = button(offerPanel, "Close", "KEEP PLAYING", UDim2.fromOffset(125, 48), UDim2.fromOffset(210, 170), panelColor)
closeOffer.ZIndex = 31

local toast = textLabel(gui, "Toast", "", UDim2.new(0, 430, 0, 52), UDim2.new(0.5, -215, 0, 102), 16, pale, Enum.TextXAlignment.Center)
toast.BackgroundColor3 = ink
toast.BackgroundTransparency = 0.08
toast.Visible = false
toast.ZIndex = 40
round(toast, 10)

local latestState
local latestRevision = -1
local currentOffer
local toastToken = 0

local function resize()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
	hudScale.Scale = math.min(1, (viewport.X - 24) / 370)
	abilityScale.Scale = math.min(1, (viewport.X - 32) / 444)
	menuScale.Scale = math.min(1, (viewport.X - 24) / 360, (viewport.Y - 84) / 490)
	offerScale.Scale = math.min(1, (viewport.X - 24) / 350, (viewport.Y - 40) / 235)
end

resize()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end

local function toastMessage(message)
	toastToken += 1
	local token = toastToken
	toast.Text = tostring(message)
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.08
	toast.Visible = true
	task.delay(2.4, function()
		if token ~= toastToken then return end
		local tween = TweenService:Create(toast, TweenInfo.new(0.35), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		if token == toastToken then toast.Visible = false end
	end)
end

local function collectionText(items)
	local names = {}
	for name, owned in items or {} do if owned then table.insert(names, name) end end
	table.sort(names)
	return #names == 0 and "COLLECTION\nNo sigils yet" or `COLLECTION ({#names})\n{table.concat(names, ", ")}`
end

local function render(state)
	latestState = state
	local zoneNames = { "CINDER HOLLOW", "FROZEN PURGATORY" }
	zoneTag.Text = zoneNames[state.Zone] or `ZONE {state.Zone}`
	stats.Text = `{state.Souls} SOULS     LV {state.Level}     {state.Damage} DMG\n{state.Rebirths} REBIRTHS{state.FriendBonus and "     +10% CO-PLAY" or ""}`
	goal.Text = `NEXT - {state.NextGoal}`
	goalFill.Size = UDim2.fromScale(math.clamp(state.DailyKills / state.DailyGoal, 0, 1), 1)
	save.Text = `{state.SaveStatus}   |   Ember Chain {state.Streak} days`
	pulseButton.Text = state.PulseUnlocked and "Q\nSOUL PULSE" or "Q\nLOCKED - LV 3"
	pulseButton.BackgroundColor3 = state.PulseUnlocked and Color3.fromRGB(32, 120, 156) or Color3.fromRGB(62, 60, 76)
	daily.Text = `DAILY — {state.DailyName}\n{math.min(state.DailyKills, state.DailyGoal)}/{state.DailyGoal} shades  •  Reward: {state.DailyReward} free flares\n{state.DailyClaimed and "Claimed today" or "Returns daily; missed days do not erase your chain."}`
	local seconds = math.min(state.ActiveSeconds, 600)
	checkIn.Text = `ACTIVE CHECK-IN  {math.floor(seconds / 60)}:{string.format("%02d", seconds % 60)} / 10:00\nRequires 3 shades today • Reward: 2 free flares{state.CheckInClaimed and " • Complete" or ""}`
	claim.Text = state.DailyClaimed and "DAILY CLAIMED" or "CLAIM DAILY"
	upgrade.Text = `UPGRADE TO LV {state.Level + 1}\n{state.UpgradeCost} SOULS`
	gateButton.Text = state.MaxZone >= 2 and "ENTER\nFROZEN PURGATORY" or "OPEN ASH GATE\n150 SOULS"
	travelButton.Text = state.Zone == 1 and "TRAVEL\nZONE 2" or "TRAVEL\nZONE 1"
	rebirth.Text = `REBIRTH\n{state.RebirthCost} SOULS`
	flare.Text = `SOUL FLARE\n{state.FlareCount} READY`
	aura.Text = state.HasAura and (state.AuraEnabled and "VIOLET AURA\nON" or "VIOLET AURA\nOFF") or "VIOLET AURA\nPERMANENT"
	collection.Text = collectionText(state.Collection)
end

State.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" or type(state.Revision) ~= "number" or state.Revision < latestRevision then return end
	latestRevision = state.Revision
	render(state)
end)
Notice.OnClientEvent:Connect(toastMessage)

local function floatingDamage(position, damage, combo)
	local anchor = Instance.new("Part")
	anchor.Name = "DamageNumber"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position + Vector3.new(0, 3.5, 0)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = workspace
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(130, 52)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor
	local label = textLabel(billboard, "Damage", `-{damage}`, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), combo == 3 and 28 or 21, combo == 3 and ember or pale, Enum.TextXAlignment.Center)
	label.Font = Enum.Font.GothamBlack
	label.TextStrokeTransparency = 0.15
	local travel = TweenService:Create(anchor, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = anchor.Position + Vector3.new(0, 3, 0) })
	local fade = TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.3), { TextTransparency = 1, TextStrokeTransparency = 1 })
	travel:Play()
	fade:Play()
	Debris:AddItem(anchor, 0.7)
end

local function burst(position, color, amount, scale)
	local anchor = Instance.new("Part")
	anchor.Name = "SoulBurst"
	anchor.Size = Vector3.new(0.25, 0.25, 0.25)
	anchor.Position = position
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.35, 0.8)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(8, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = anchor
	emitter:Emit(amount or 30)
	Debris:AddItem(anchor, 1.2)
end

FX.OnClientEvent:Connect(function(effect)
	if type(effect) ~= "table" or type(effect.Kind) ~= "string" then return end
	if effect.Kind == "Hit" and effect.Position then
		floatingDamage(effect.Position, tonumber(effect.Damage) or 0, tonumber(effect.Combo) or 0)
		burst(effect.Position, effect.Combo == 3 and ember or purple, effect.Combo == 3 and 46 or 22, effect.Combo == 3 and 0.65 or 0.38)
		if effect.Combo and effect.Combo > 0 then
			comboLabel.Text = effect.Combo == 3 and "SOUL BREAK  x3" or `CHAIN  x{effect.Combo}`
			comboLabel.TextColor3 = effect.Combo == 3 and ember or pale
			comboLabel.Visible = true
			comboLabel.TextTransparency = 0
			local comboToken = os.clock()
			comboLabel:SetAttribute("Token", comboToken)
			task.delay(0.7, function()
				if comboLabel:GetAttribute("Token") ~= comboToken then return end
				TweenService:Create(comboLabel, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
				task.wait(0.22)
				if comboLabel:GetAttribute("Token") == comboToken then comboLabel.Visible = false end
			end)
		end
	elseif effect.Kind == "Death" and effect.Position then
		burst(effect.Position, effect.Color or purple, effect.Boss and 100 or 52, effect.Boss and 1.15 or 0.7)
	elseif effect.Kind == "Swing" then
		press(attackButton)
		sweep(attackButton, effect.Cooldown)
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			burst(rootPart.Position + rootPart.CFrame.LookVector * 4 + Vector3.new(0, 1.5, 0), effect.Combo == 3 and ember or purple, effect.Combo == 3 and 34 or 14, 0.3)
		end
	elseif effect.Kind == "Cooling" then
		press(attackButton)
	elseif effect.Kind == "Struck" then
		damageFlash.BackgroundTransparency = 0.7
		TweenService:Create(damageFlash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	elseif effect.Kind == "Dash" and effect.Player then
		local character = effect.Player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then burst(rootPart.Position, cyan, 26, 0.35) end
		if effect.Player == player then sweep(dashButton, effect.Cooldown); press(dashButton) end
		if effect.Player == player and workspace.CurrentCamera then
			local camera = workspace.CurrentCamera
			TweenService:Create(camera, TweenInfo.new(0.1), { FieldOfView = 78 }):Play()
			task.delay(0.12, function() TweenService:Create(camera, TweenInfo.new(0.25), { FieldOfView = 70 }):Play() end)
		end
	elseif effect.Kind == "Dodge" then
		comboLabel.Text = "PHASED"
		comboLabel.TextColor3 = cyan
		comboLabel.TextTransparency = 0
		comboLabel.Visible = true
		task.delay(0.55, function() comboLabel.Visible = false end)
	elseif effect.Kind == "BossCharge" then
		toastMessage("WARDEN SLAM - SOUL STEP THROUGH IT")
	elseif effect.Kind == "BossSlam" and effect.Position then
		burst(effect.Position, cyan, 90, 0.9)
	elseif effect.Kind == "Pulse" and effect.Position then
		burst(effect.Position, cyan, 65, 0.65)
		press(pulseButton)
		sweep(pulseButton, effect.Cooldown)
	elseif effect.Kind == "Miss" then
		-- A miss now says why. Silence here is what made Soul Strike feel broken.
		local distance = tonumber(effect.Distance)
		comboLabel.Text = distance and `TOO FAR - {math.floor(distance)} STUDS TO NEAREST` or "NO SOULS IN THIS REALM"
		comboLabel.TextColor3 = muted
		comboLabel.TextTransparency = 0
		comboLabel.Visible = true
		local missToken = os.clock()
		comboLabel:SetAttribute("Token", missToken)
		task.delay(0.8, function()
			if comboLabel:GetAttribute("Token") == missToken then comboLabel.Visible = false end
		end)
	end
end)

local lastHealth
local function bindHealth(character)
	local humanoid = character:WaitForChild("Humanoid", 8)
	if not humanoid then return end
	lastHealth = humanoid.Health
	local function updateHealth(health)
		healthFill.Size = UDim2.fromScale(math.clamp(health / humanoid.MaxHealth, 0, 1), 1)
		healthText.Text = `BODY  {math.ceil(health)} / {math.ceil(humanoid.MaxHealth)}`
		if lastHealth and health < lastHealth then
			damageFlash.BackgroundTransparency = 0.78
			TweenService:Create(damageFlash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		end
		lastHealth = health
	end
	humanoid.HealthChanged:Connect(updateHealth)
	updateHealth(humanoid.Health)
end

player.CharacterAdded:Connect(bindHealth)
if player.Character then task.spawn(bindHealth, player.Character) end

local targetClock = 0
RunService.RenderStepped:Connect(function(delta)
	targetClock += delta
	if targetClock < 0.12 then return end
	targetClock = 0
	local characterRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local soulWorld = workspace:FindFirstChild("SoulGrindWorld")
	if not characterRoot or not soulWorld then targetFrame.Visible = false; return end
	local nearest, nearestDistance
	for _, candidate in soulWorld:GetChildren() do
		if candidate:IsA("Model") and candidate:GetAttribute("Enemy") and candidate.PrimaryPart then
			local humanoid = candidate:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local distance = (candidate.PrimaryPart.Position - characterRoot.Position).Magnitude
				if distance <= 90 and (not nearestDistance or distance < nearestDistance) then nearest, nearestDistance = candidate, distance end
			end
		end
	end
	if not nearest then targetFrame.Visible = false; return end
	local humanoid = nearest:FindFirstChildOfClass("Humanoid")
	local inRange = nearestDistance <= Config.AttackRange
	targetFrame.Visible = true
	targetName.Text = `{nearest:GetAttribute("Boss") and "BOSS  -  " or ""}{humanoid.DisplayName}`
	targetFill.BackgroundColor3 = nearest:GetAttribute("Zone") == 2 and cyan or purple
	targetFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
	targetRange.Text = inRange and `IN RANGE  -  {math.floor(nearestDistance)} studs` or `MOVE CLOSER  -  {math.floor(nearestDistance)} studs`
	targetRange.TextColor3 = inRange and cyan or ember
end)

Offer.OnClientEvent:Connect(function(offer)
	if type(offer) ~= "table" or (offer.kind ~= "Product" and offer.kind ~= "Pass") or type(offer.id) ~= "number" then return end
	currentOffer = offer
	offerTitle.Text = offer.label or "Optional cosmetic"
	offerDescription.Text = `{offer.description or ""}\n\nFree Soul Flares remain earnable from daily play.`
	buy.Text = "VIEW ROBUX PRICE"
	offerPanel.Visible = true
	task.spawn(function()
		local infoType = offer.kind == "Product" and Enum.InfoType.Product or Enum.InfoType.GamePass
		local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, offer.id, infoType)
		if ok and info and currentOffer == offer and type(info.PriceInRobux) == "number" then
			buy.Text = `BUY FOR {info.PriceInRobux} R$`
		end
	end)
end)

-- Every input route funnels through these three so a key, a tap, a click and the
-- on-screen button are literally the same code path.
local nextLocalAttack = 0
local function requestAttack()
	if os.clock() < nextLocalAttack then return false end
	nextLocalAttack = os.clock() + Config.Cooldowns.Attack * 0.5
	Action:FireServer("Attack")
	return true
end
local function requestPulse()
	press(pulseButton)
	Action:FireServer("Pulse")
end
local function requestDash()
	press(dashButton)
	Action:FireServer("Dash")
end

attackButton.Activated:Connect(requestAttack)
pulseButton.Activated:Connect(requestPulse)
dashButton.Activated:Connect(requestDash)
menuButton.Activated:Connect(function() menu.Visible = not menu.Visible end)
claim.Activated:Connect(function() Action:FireServer("ClaimDaily") end)
upgrade.Activated:Connect(function() Action:FireServer("Upgrade") end)
gateButton.Activated:Connect(function() Action:FireServer(latestState and latestState.MaxZone >= 2 and "Travel" or "UnlockZone", 2) end)
travelButton.Activated:Connect(function() if latestState then Action:FireServer("Travel", latestState.Zone == 1 and 2 or 1) end end)
rebirth.Activated:Connect(function() rebirthConfirm.Visible = true end)
confirm.Activated:Connect(function() rebirthConfirm.Visible = false; Action:FireServer("Rebirth") end)
cancel.Activated:Connect(function() rebirthConfirm.Visible = false end)
flare.Activated:Connect(function() Action:FireServer("Flare") end)
aura.Activated:Connect(function() Action:FireServer("Aura") end)
closeOffer.Activated:Connect(function() currentOffer = nil; offerPanel.Visible = false end)

buy.Activated:Connect(function()
	local offer = currentOffer
	if not offer then return end
	if offer.kind == "Product" then MarketplaceService:PromptProductPurchase(player, offer.id)
	else MarketplaceService:PromptGamePassPurchase(player, offer.id) end
end)

inviteButton.Activated:Connect(function()
	task.spawn(function()
		local ok, allowed = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and allowed then SocialService:PromptGameInvite(player)
		else toastMessage("Friend invites are unavailable on this device right now.") end
	end)
end)

ContextActionService:BindAction("SoulAttack", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then requestAttack() end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.F)

ContextActionService:BindAction("SoulPulse", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then requestPulse() end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Q)

ContextActionService:BindAction("SoulStep", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then requestDash() end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E)

-- Click and tap to strike. gameProcessed is true when the input landed on the HUD, so
-- the on-screen buttons keep working without firing the action twice.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		requestAttack()
	end
end)

-- One Sync can lose the race against the server's session setup; a short retry until
-- the first State arrives costs nothing and stops the HUD from hanging on "Loading".
task.spawn(function()
	for _ = 1, 12 do
		Action:FireServer("Sync")
		if latestState then return end
		task.wait(0.5)
	end
end)
