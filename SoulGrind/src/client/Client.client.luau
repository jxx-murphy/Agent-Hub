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
local Action = remotes:WaitForChild("Action")
local State = remotes:WaitForChild("State")
local Notice = remotes:WaitForChild("Notice")
local Offer = remotes:WaitForChild("Offer")
local FX = remotes:WaitForChild("FX")
-- Ranges, cooldowns, ability definitions and quest text all come from the same modules
-- the server reads, so the HUD can never promise something the server will refuse.
local Config = require(remotes:WaitForChild("Config"))
local Quests = require(remotes:WaitForChild("Quests"))

local ink = Color3.fromRGB(20, 13, 14)
local panelColor = Color3.fromRGB(38, 25, 26)
local gold = Color3.fromRGB(201, 162, 74)
local goldLight = Color3.fromRGB(232, 200, 120)
local goldPale = Color3.fromRGB(255, 233, 168)
local crimson = Color3.fromRGB(184, 54, 47)
local crimsonLit = Color3.fromRGB(217, 82, 74)
local pale = Color3.fromRGB(238, 228, 214)
local muted = Color3.fromRGB(168, 148, 136)
local ember = Color3.fromRGB(224, 138, 60)

local gui = Instance.new("ScreenGui")
gui.Name = "SoulGrindUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Helpers --------------------------------------------------------------------

local function round(object, radius, strokeColor)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = object
	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor or gold
	stroke.Transparency = 0.55
	stroke.Thickness = 1
	stroke.Parent = object
	return stroke
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
	round(control, 8)
	return control
end

local function bar(parent, name, size, position, fillColor, backColor)
	local back = Instance.new("Frame")
	back.Name = name
	back.Size = size
	back.Position = position
	back.BackgroundColor3 = backColor or Color3.fromRGB(46, 30, 32)
	back.BorderSizePixel = 0
	back.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = fillColor or gold
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill
	return back, fill
end

-- HUD ------------------------------------------------------------------------

local hud = Instance.new("Frame")
hud.Name = "HUD"
hud.Size = UDim2.new(0, 372, 0, 196)
hud.Position = UDim2.fromOffset(18, 18)
hud.BackgroundColor3 = ink
hud.BackgroundTransparency = 0.06
hud.Parent = gui
round(hud, 12)
gradient(hud, Color3.fromRGB(38, 23, 24), Color3.fromRGB(16, 11, 12), 20)
local hudScale = Instance.new("UIScale")
hudScale.Parent = hud

local accent = Instance.new("Frame")
accent.Name = "Accent"
accent.Size = UDim2.new(0, 4, 1, -24)
accent.Position = UDim2.fromOffset(0, 12)
accent.BackgroundColor3 = gold
accent.BorderSizePixel = 0
accent.Parent = hud
local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(1, 0)
accentCorner.Parent = accent
gradient(accent, gold, crimson, 90)

local title = textLabel(hud, "Title", "SOUL GRIND", UDim2.new(0, 200, 0, 26), UDim2.fromOffset(16, 10), 20, gold)
title.Font = Enum.Font.GothamBlack
local zoneTag = textLabel(hud, "Zone", "AWAKENING", UDim2.fromOffset(142, 24), UDim2.new(1, -155, 0, 10), 11, crimsonLit, Enum.TextXAlignment.Right)
zoneTag.Font = Enum.Font.GothamBold
local stats = textLabel(hud, "Stats", "Loading your soul...", UDim2.new(1, -32, 0, 48), UDim2.fromOffset(16, 40), 16, pale)
local questRate = textLabel(hud, "Rate", "QUESTS 0 / 8   •   0% COMPLETE", UDim2.new(1, -32, 0, 18), UDim2.fromOffset(16, 92), 12, goldLight)
questRate.Font = Enum.Font.GothamBold
local _, rateFill = bar(hud, "RateTrack", UDim2.new(1, -32, 0, 7), UDim2.fromOffset(16, 114), gold)
local dailyLine = textLabel(hud, "DailyLine", "", UDim2.new(1, -32, 0, 18), UDim2.fromOffset(16, 128), 11, muted)
local _, goalFill = bar(hud, "GoalTrack", UDim2.new(1, -32, 0, 6), UDim2.fromOffset(16, 148), crimsonLit)
local save = textLabel(hud, "Save", "", UDim2.new(1, -32, 0, 16), UDim2.fromOffset(16, 158), 11, muted)
local controls = textLabel(hud, "Controls", "F or CLICK strike   •   Q pulse   •   E step   •   WASD move", UDim2.new(1, -32, 0, 16), UDim2.fromOffset(16, 174), 11, goldLight)

-- Objective banner -----------------------------------------------------------
-- The single most important element on screen. It answers "what am I supposed to do"
-- without the player opening anything, and it matches the stone signs in the world.

local objective = Instance.new("Frame")
objective.Name = "Objective"
objective.Size = UDim2.fromOffset(440, 104)
objective.Position = UDim2.new(0.5, -220, 0, 16)
objective.BackgroundColor3 = ink
objective.BackgroundTransparency = 0.05
objective.Parent = gui
round(objective, 12)
gradient(objective, Color3.fromRGB(44, 26, 24), Color3.fromRGB(18, 12, 13), 90)
local objectiveScale = Instance.new("UIScale")
objectiveScale.Parent = objective

local objectiveTag = textLabel(objective, "Tag", "OBJECTIVE", UDim2.new(1, -24, 0, 15), UDim2.fromOffset(16, 9), 11, gold, Enum.TextXAlignment.Center)
objectiveTag.Font = Enum.Font.GothamBold
local objectiveTitle = textLabel(objective, "Title", "Finding your charge...", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 26), 20, goldPale, Enum.TextXAlignment.Center)
objectiveTitle.Font = Enum.Font.GothamBlack
local objectiveHint = textLabel(objective, "Hint", "", UDim2.new(1, -30, 0, 18), UDim2.fromOffset(15, 54), 12, pale, Enum.TextXAlignment.Center)
local _, objectiveFill = bar(objective, "Track", UDim2.new(1, -32, 0, 8), UDim2.fromOffset(16, 78), goldLight)
local objectiveCount = textLabel(objective, "Count", "", UDim2.new(1, -32, 0, 14), UDim2.fromOffset(16, 86), 11, muted, Enum.TextXAlignment.Center)

-- Target plate ---------------------------------------------------------------

local targetFrame = Instance.new("Frame")
targetFrame.Name = "Target"
targetFrame.Size = UDim2.fromOffset(330, 70)
targetFrame.Position = UDim2.new(0.5, -165, 0, 128)
targetFrame.BackgroundColor3 = ink
targetFrame.BackgroundTransparency = 0.1
targetFrame.Visible = false
targetFrame.Parent = gui
round(targetFrame, 10)
local targetName = textLabel(targetFrame, "Name", "", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 6), 14, pale, Enum.TextXAlignment.Center)
targetName.Font = Enum.Font.GothamBold
local _, targetFill = bar(targetFrame, "Track", UDim2.new(1, -32, 0, 8), UDim2.fromOffset(16, 32), crimsonLit)
targetFill.Size = UDim2.fromScale(1, 1)
local targetRange = textLabel(targetFrame, "Range", "", UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 45), 12, muted, Enum.TextXAlignment.Center)

-- Only the current target is outlined. Nothing else in the world glows.
local targetOutline = Instance.new("Highlight")
targetOutline.Name = "TargetOutline"
targetOutline.FillColor = goldPale
targetOutline.FillTransparency = 0.94
targetOutline.OutlineColor = goldPale
targetOutline.OutlineTransparency = 0.05
targetOutline.DepthMode = Enum.HighlightDepthMode.Occluded
targetOutline.Enabled = false
targetOutline.Parent = gui

-- Ability bar ----------------------------------------------------------------

local function addCooldownOverlay(control)
	control.ClipsDescendants = true
	local cool = Instance.new("Frame")
	cool.Name = "Cool"
	cool.AnchorPoint = Vector2.new(0, 1)
	cool.Position = UDim2.fromScale(0, 1)
	cool.Size = UDim2.fromScale(1, 0)
	cool.BackgroundColor3 = Color3.fromRGB(8, 5, 6)
	cool.BackgroundTransparency = 0.45
	cool.BorderSizePixel = 0
	cool.Visible = false
	cool.ZIndex = 3
	cool.Parent = control
	return control
end

local abilityBar = Instance.new("Frame")
abilityBar.Name = "Abilities"
abilityBar.AnchorPoint = Vector2.new(0.5, 1)
abilityBar.Position = UDim2.new(0.5, 0, 1, -18)
abilityBar.Size = UDim2.fromOffset(444, 84)
abilityBar.BackgroundTransparency = 1
abilityBar.Parent = gui
local abilityScale = Instance.new("UIScale")
abilityScale.Parent = abilityBar

local attackButton = addCooldownOverlay(button(abilityBar, "Attack", "F / CLICK\nSOUL STRIKE", UDim2.fromOffset(140, 84), UDim2.fromOffset(0, 0), Color3.fromRGB(132, 40, 36)))
gradient(attackButton, Color3.fromRGB(168, 52, 44), Color3.fromRGB(94, 28, 26), 90)
local pulseButton = addCooldownOverlay(button(abilityBar, "Pulse", "Q\nSOUL PULSE", UDim2.fromOffset(140, 84), UDim2.fromOffset(152, 0), Color3.fromRGB(150, 110, 44)))
gradient(pulseButton, Color3.fromRGB(184, 140, 56), Color3.fromRGB(104, 76, 30), 90)
local dashButton = addCooldownOverlay(button(abilityBar, "Dash", "E\nSOUL STEP", UDim2.fromOffset(140, 84), UDim2.fromOffset(304, 0), Color3.fromRGB(122, 82, 44)))
gradient(dashButton, Color3.fromRGB(156, 106, 56), Color3.fromRGB(86, 58, 32), 90)

local rankPips = {}
for key, control in { Strike = attackButton, Pulse = pulseButton, Step = dashButton } do
	local pips = textLabel(control, "Rank", "", UDim2.new(1, -12, 0, 14), UDim2.fromOffset(6, 66), 11, goldPale, Enum.TextXAlignment.Center)
	pips.ZIndex = 4
	rankPips[key] = pips
end

local function sweep(control, seconds)
	local cool = control:FindFirstChild("Cool")
	if not cool or type(seconds) ~= "number" or seconds <= 0.01 then return end
	cool.Size = UDim2.fromScale(1, 1)
	cool.Visible = true
	local token = os.clock()
	cool:SetAttribute("Token", token)
	TweenService:Create(cool, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 0) }):Play()
	task.delay(seconds, function()
		if cool:GetAttribute("Token") == token then cool.Visible = false end
	end)
end

local function press(control)
	local stroke = control:FindFirstChildOfClass("UIStroke")
	if not stroke then return end
	stroke.Transparency = 0
	stroke.Thickness = 3
	TweenService:Create(stroke, TweenInfo.new(0.22), { Transparency = 0.55, Thickness = 1 }):Play()
end

-- Health + damage ------------------------------------------------------------

local healthPanel = Instance.new("Frame")
healthPanel.Name = "Health"
healthPanel.Size = UDim2.fromOffset(215, 28)
healthPanel.Position = UDim2.new(0, 18, 1, -118)
healthPanel.BackgroundColor3 = ink
healthPanel.BackgroundTransparency = 0.08
healthPanel.Parent = gui
round(healthPanel, 9)
local healthFill = Instance.new("Frame")
healthFill.Name = "Fill"
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.BackgroundColor3 = crimson
healthFill.BorderSizePixel = 0
healthFill.Parent = healthPanel
local healthCorner = Instance.new("UICorner")
healthCorner.CornerRadius = UDim.new(0, 8)
healthCorner.Parent = healthFill
gradient(healthFill, Color3.fromRGB(150, 30, 28), ember)
local healthText = textLabel(healthPanel, "Text", "BODY 100 / 100", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 12, pale, Enum.TextXAlignment.Center)
healthText.ZIndex = 2

local damageFlash = Instance.new("Frame")
damageFlash.Name = "DamageFlash"
damageFlash.Size = UDim2.fromScale(1, 1)
damageFlash.BackgroundColor3 = Color3.fromRGB(150, 18, 24)
damageFlash.BackgroundTransparency = 1
damageFlash.BorderSizePixel = 0
damageFlash.ZIndex = 50
damageFlash.Active = false
damageFlash.Selectable = false
damageFlash.Parent = gui

local comboLabel = textLabel(gui, "Combo", "", UDim2.fromOffset(360, 48), UDim2.new(0.5, -180, 0.68, 0), 22, pale, Enum.TextXAlignment.Center)
comboLabel.Font = Enum.Font.GothamBlack
comboLabel.TextStrokeTransparency = 0.2
comboLabel.Visible = false

-- Journal --------------------------------------------------------------------

local menuButton = button(gui, "MenuToggle", "JOURNAL", UDim2.fromOffset(120, 42), UDim2.new(1, -136, 0, 18), panelColor)
local inviteButton = button(gui, "Invite", "INVITE FRIEND", UDim2.fromOffset(140, 42), UDim2.new(1, -286, 0, 18), panelColor)
gradient(menuButton, Color3.fromRGB(58, 38, 34), Color3.fromRGB(28, 18, 19), 90)
gradient(inviteButton, Color3.fromRGB(70, 44, 36), Color3.fromRGB(32, 20, 20), 90)

local menu = Instance.new("Frame")
menu.Name = "Journal"
menu.Size = UDim2.fromOffset(392, 540)
menu.AnchorPoint = Vector2.new(1, 0)
menu.Position = UDim2.new(1, -16, 0, 70)
menu.BackgroundColor3 = ink
menu.BackgroundTransparency = 0.04
menu.Visible = false
menu.Parent = gui
round(menu, 12)
gradient(menu, Color3.fromRGB(40, 24, 24), Color3.fromRGB(16, 11, 12), 35)
local menuScale = Instance.new("UIScale")
menuScale.Parent = menu

local menuTitle = textLabel(menu, "Title", "UNDERWORLD JOURNAL", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(14, 10), 18, gold)
menuTitle.Font = Enum.Font.GothamBlack

local tabs = {}
local pages = {}
local function showTab(name)
	for tabName, tabButton in tabs do
		local on = tabName == name
		tabButton.BackgroundColor3 = on and Color3.fromRGB(96, 60, 30) or panelColor
		tabButton.TextColor3 = on and goldPale or muted
		pages[tabName].Visible = on
	end
end

local tabNames = { "QUESTS", "MOVES", "REALM" }
for index, name in tabNames do
	local tab = button(menu, name, name, UDim2.fromOffset(118, 32), UDim2.fromOffset(14 + (index - 1) * 122, 44), panelColor)
	tab.TextSize = 13
	tabs[name] = tab

	local page = Instance.new("Frame")
	page.Name = name .. "Page"
	page.Size = UDim2.new(1, -28, 1, -96)
	page.Position = UDim2.fromOffset(14, 86)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = menu
	pages[name] = page

	tab.Activated:Connect(function() showTab(name) end)
end

-- Quests page: one row per quest, so the whole chain is visible, not just the next step.
local questHeader = textLabel(pages.QUESTS, "Header", "0 OF 8 COMPLETE   •   0%", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 0), 13, goldLight)
questHeader.Font = Enum.Font.GothamBold

local questScroll = Instance.new("ScrollingFrame")
questScroll.Size = UDim2.new(1, 0, 1, -28)
questScroll.Position = UDim2.fromOffset(0, 26)
questScroll.BackgroundTransparency = 1
questScroll.BorderSizePixel = 0
questScroll.ScrollBarThickness = 4
questScroll.ScrollBarImageColor3 = gold
questScroll.CanvasSize = UDim2.new()
questScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
questScroll.Parent = pages.QUESTS
local questLayout = Instance.new("UIListLayout")
questLayout.Padding = UDim.new(0, 8)
questLayout.SortOrder = Enum.SortOrder.LayoutOrder
questLayout.Parent = questScroll

local questRows = {}
for index, quest in Quests.list do
	local row = Instance.new("Frame")
	row.Name = quest.Id
	row.Size = UDim2.new(1, -8, 0, 74)
	row.BackgroundColor3 = panelColor
	row.BackgroundTransparency = 0.3
	row.LayoutOrder = index
	row.Parent = questScroll
	local stroke = round(row, 8)

	local rowTitle = textLabel(row, "Title", `{index}. {quest.Title}`, UDim2.new(1, -74, 0, 18), UDim2.fromOffset(10, 7), 13, pale)
	rowTitle.Font = Enum.Font.GothamBold
	local rowCount = textLabel(row, "Count", "", UDim2.fromOffset(62, 18), UDim2.new(1, -70, 0, 7), 12, goldLight, Enum.TextXAlignment.Right)
	local rowDetail = textLabel(row, "Detail", quest.Detail, UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 26), 11, muted)
	local _, rowFill = bar(row, "Track", UDim2.new(1, -20, 0, 6), UDim2.fromOffset(10, 58), gold)

	questRows[quest.Id] = { Row = row, Stroke = stroke, Title = rowTitle, Count = rowCount, Detail = rowDetail, Fill = rowFill }
end

-- Moves page: soul level plus a rank track for each ability.
local levelCard = Instance.new("Frame")
levelCard.Size = UDim2.new(1, 0, 0, 60)
levelCard.BackgroundColor3 = panelColor
levelCard.BackgroundTransparency = 0.3
levelCard.Parent = pages.MOVES
round(levelCard, 8)
local levelText = textLabel(levelCard, "Text", "", UDim2.new(1, -140, 1, -12), UDim2.fromOffset(10, 6), 12, pale)
local upgrade = button(levelCard, "Upgrade", "UPGRADE", UDim2.fromOffset(120, 42), UDim2.new(1, -130, 0, 9), Color3.fromRGB(120, 78, 34))

local moveCards = {}
for index, def in Config.Abilities do
	local card = Instance.new("Frame")
	card.Name = def.Key
	card.Size = UDim2.new(1, 0, 0, 84)
	card.Position = UDim2.fromOffset(0, 68 + (index - 1) * 92)
	card.BackgroundColor3 = panelColor
	card.BackgroundTransparency = 0.3
	card.Parent = pages.MOVES
	round(card, 8)

	local name = textLabel(card, "Name", def.Name, UDim2.new(1, -140, 0, 18), UDim2.fromOffset(10, 7), 13, goldPale)
	name.Font = Enum.Font.GothamBold
	local detail = textLabel(card, "Detail", def.Detail, UDim2.new(1, -140, 0, 40), UDim2.fromOffset(10, 26), 11, muted)
	local _, rankFill = bar(card, "Track", UDim2.new(1, -140, 0, 6), UDim2.fromOffset(10, 68), goldLight)
	local rankUp = button(card, "Rank", "RANK UP", UDim2.fromOffset(120, 62), UDim2.new(1, -130, 0, 11), Color3.fromRGB(120, 78, 34))
	rankUp.TextSize = 13

	rankUp.Activated:Connect(function()
		press(rankUp)
		Action:FireServer("UpgradeMove", def.Key)
	end)
	moveCards[def.Key] = { Def = def, Card = card, Name = name, Detail = detail, Fill = rankFill, Button = rankUp }
end

-- Realm page: everything that is not a quest or a move.
local daily = textLabel(pages.REALM, "Daily", "", UDim2.new(1, 0, 0, 74), UDim2.fromOffset(0, 0), 12, pale)
local checkIn = textLabel(pages.REALM, "CheckIn", "", UDim2.new(1, 0, 0, 48), UDim2.fromOffset(0, 80), 11, goldLight)
for _, card in { daily, checkIn } do
	card.BackgroundColor3 = panelColor
	card.BackgroundTransparency = 0.35
	round(card, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = card
end

local claim = button(pages.REALM, "Claim", "CLAIM DAILY", UDim2.new(0.5, -6, 0, 42), UDim2.fromOffset(0, 136), Color3.fromRGB(104, 66, 30))
local gateButton = button(pages.REALM, "Gate", "OPEN ASH GATE\n150 SOULS", UDim2.new(0.5, -6, 0, 42), UDim2.new(0.5, 6, 0, 136), Color3.fromRGB(126, 46, 40))
local travelButton = button(pages.REALM, "Travel", "TRAVEL\nZONE 2", UDim2.new(0.5, -6, 0, 50), UDim2.fromOffset(0, 186), Color3.fromRGB(96, 62, 30))
local rebirth = button(pages.REALM, "Rebirth", "REBIRTH", UDim2.new(0.5, -6, 0, 50), UDim2.new(0.5, 6, 0, 186), Color3.fromRGB(126, 40, 54))
local flare = button(pages.REALM, "Flare", "SOUL FLARE", UDim2.new(0.5, -6, 0, 50), UDim2.fromOffset(0, 244), Color3.fromRGB(110, 70, 36))
local aura = button(pages.REALM, "Aura", "VIOLET AURA", UDim2.new(0.5, -6, 0, 50), UDim2.new(0.5, 6, 0, 244), Color3.fromRGB(96, 46, 84))
local collection = textLabel(pages.REALM, "Collection", "", UDim2.new(1, 0, 0, 90), UDim2.fromOffset(0, 302), 11, muted)

showTab("QUESTS")

-- Dialogs --------------------------------------------------------------------

local rebirthConfirm = Instance.new("Frame")
rebirthConfirm.Size = UDim2.fromOffset(340, 176)
rebirthConfirm.Position = UDim2.new(0.5, -170, 0.5, -88)
rebirthConfirm.BackgroundColor3 = ink
rebirthConfirm.Visible = false
rebirthConfirm.ZIndex = 20
rebirthConfirm.Parent = gui
round(rebirthConfirm, 12)
local confirmText = textLabel(rebirthConfirm, "Warning", "REBIRTH?\nSouls and Soul Level reset. Zones, sigils, move ranks and +10% permanent damage remain.", UDim2.new(1, -24, 0, 100), UDim2.fromOffset(12, 12), 14, pale, Enum.TextXAlignment.Center)
confirmText.ZIndex = 21
local confirm = button(rebirthConfirm, "Confirm", "REBIRTH", UDim2.fromOffset(145, 44), UDim2.fromOffset(18, 118), Color3.fromRGB(126, 37, 52))
confirm.ZIndex = 21
local cancel = button(rebirthConfirm, "Cancel", "CANCEL", UDim2.fromOffset(145, 44), UDim2.fromOffset(177, 118), panelColor)
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
local offerTitle = textLabel(offerPanel, "Title", "", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 14), 19, gold, Enum.TextXAlignment.Center)
offerTitle.ZIndex = 31
local offerDescription = textLabel(offerPanel, "Description", "", UDim2.new(1, -30, 0, 95), UDim2.fromOffset(15, 55), 14, pale, Enum.TextXAlignment.Center)
offerDescription.ZIndex = 31
local buy = button(offerPanel, "Buy", "VIEW ROBUX PRICE", UDim2.fromOffset(180, 48), UDim2.fromOffset(20, 170), Color3.fromRGB(122, 78, 34))
buy.ZIndex = 31
local closeOffer = button(offerPanel, "Close", "KEEP PLAYING", UDim2.fromOffset(125, 48), UDim2.fromOffset(210, 170), panelColor)
closeOffer.ZIndex = 31

local toast = textLabel(gui, "Toast", "", UDim2.new(0, 460, 0, 52), UDim2.new(0.5, -230, 0, 208), 16, pale, Enum.TextXAlignment.Center)
toast.BackgroundColor3 = ink
toast.BackgroundTransparency = 0.08
toast.Visible = false
toast.ZIndex = 40
round(toast, 10)

-- State ----------------------------------------------------------------------

local latestState
local latestRevision = -1
local currentOffer
local toastToken = 0

local function resize()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
	hudScale.Scale = math.min(1, (viewport.X - 24) / 372)
	abilityScale.Scale = math.min(1, (viewport.X - 32) / 444)
	objectiveScale.Scale = math.min(1, (viewport.X - 420) / 440, 1)
	menuScale.Scale = math.min(1, (viewport.X - 24) / 392, (viewport.Y - 96) / 540)
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
	task.delay(2.6, function()
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
	return #names == 0 and "SIGILS\nNone bound yet" or `SIGILS ({#names})\n{table.concat(names, ", ")}`
end

local function render(state)
	latestState = state
	local zoneNames = { "CINDER HOLLOW", "MOLTEN RELIQUARY" }
	zoneTag.Text = zoneNames[state.Zone] or `ZONE {state.Zone}`
	stats.Text = `{state.Souls} SOULS     LV {state.Level}     {state.Damage} DMG\n{state.Rebirths} REBIRTHS{state.FriendBonus and "     +10% CO-PLAY" or ""}`

	local quests = state.Quests or { Progress = {}, Completed = 0, Total = Quests.count, Rate = 0 }
	questRate.Text = `QUESTS {quests.Completed} / {quests.Total}   •   {quests.Rate}% COMPLETE`
	rateFill.Size = UDim2.fromScale(quests.Rate / 100, 1)
	questHeader.Text = `{quests.Completed} OF {quests.Total} COMPLETE   •   {quests.Rate}%`

	local active = quests.ActiveId and Quests.byId(quests.ActiveId)
	if active then
		local value = quests.Progress[active.Id] or 0
		objectiveTitle.Text = active.Title
		objectiveHint.Text = active.Hint
		objectiveFill.Size = UDim2.fromScale(math.clamp(value / active.Target, 0, 1), 1)
		objectiveCount.Text = `{active.Detail}     ({value} / {active.Target})`
	else
		objectiveTitle.Text = "All charges bound"
		objectiveHint.Text = "Rebirth again, or take a friend through the Ash Gate."
		objectiveFill.Size = UDim2.fromScale(1, 1)
		objectiveCount.Text = ""
	end

	for _, quest in Quests.list do
		local row = questRows[quest.Id]
		local value = quests.Progress[quest.Id] or 0
		local done = value >= quest.Target
		row.Count.Text = done and "DONE" or `{value} / {quest.Target}`
		row.Count.TextColor3 = done and goldPale or muted
		row.Fill.Size = UDim2.fromScale(math.clamp(value / quest.Target, 0, 1), 1)
		row.Fill.BackgroundColor3 = done and gold or crimsonLit
		row.Title.TextColor3 = done and muted or pale
		row.Detail.Text = quests.ActiveId == quest.Id and quest.Hint or quest.Detail
		row.Stroke.Transparency = quests.ActiveId == quest.Id and 0 or 0.75
		row.Row.BackgroundTransparency = quests.ActiveId == quest.Id and 0.1 or 0.45
	end

	dailyLine.Text = `DAILY  {math.min(state.DailyKills, state.DailyGoal)} / {state.DailyGoal} shades`
	goalFill.Size = UDim2.fromScale(math.clamp(state.DailyKills / state.DailyGoal, 0, 1), 1)
	save.Text = `{state.SaveStatus}   |   Ember Chain {state.Streak} days`

	pulseButton.Text = state.PulseUnlocked and "Q\nSOUL PULSE" or "Q\nLOCKED - LV 3"
	pulseButton.BackgroundColor3 = state.PulseUnlocked and Color3.fromRGB(150, 110, 44) or Color3.fromRGB(64, 54, 50)

	local upgrades = state.Upgrades or {}
	local costs = state.AbilityCosts or {}
	for key, entry in moveCards do
		local rank = upgrades[key] or 0
		local def = entry.Def
		entry.Name.Text = `{def.Name}   —   RANK {rank} / {def.Max}`
		entry.Fill.Size = UDim2.fromScale(rank / def.Max, 1)
		if state.Level < def.RequiresLevel then
			entry.Button.Text = `NEEDS\nLV {def.RequiresLevel}`
			entry.Button.BackgroundColor3 = Color3.fromRGB(64, 54, 50)
		elseif rank >= def.Max then
			entry.Button.Text = "MAX\nRANK"
			entry.Button.BackgroundColor3 = Color3.fromRGB(96, 78, 40)
		else
			entry.Button.Text = `RANK UP\n{costs[key] or "?"} SOULS`
			entry.Button.BackgroundColor3 = (state.Souls >= (costs[key] or math.huge)) and Color3.fromRGB(140, 92, 38) or Color3.fromRGB(78, 58, 38)
		end
		if rankPips[key] then
			rankPips[key].Text = rank > 0 and string.rep("•", rank) or ""
		end
	end

	levelText.Text = `SOUL LEVEL {state.Level}\nRaises base damage and unlocks Soul Pulse at 3.`
	upgrade.Text = `UPGRADE\n{state.UpgradeCost} SOULS`

	daily.Text = `DAILY — {state.DailyName}\n{math.min(state.DailyKills, state.DailyGoal)}/{state.DailyGoal} shades  •  Reward: {state.DailyReward} free flares\n{state.DailyClaimed and "Claimed today" or "Missed days never erase your chain."}`
	local seconds = math.min(state.ActiveSeconds, 600)
	checkIn.Text = `ACTIVE CHECK-IN  {math.floor(seconds / 60)}:{string.format("%02d", seconds % 60)} / 10:00\nRequires 3 shades today • Reward: 2 free flares{state.CheckInClaimed and " • Complete" or ""}`
	claim.Text = state.DailyClaimed and "DAILY CLAIMED" or "CLAIM DAILY"
	gateButton.Text = state.MaxZone >= 2 and "ENTER\nRELIQUARY" or "OPEN ASH GATE\n150 SOULS"
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

-- Effects --------------------------------------------------------------------

local function floatingDamage(position, damage, combo)
	local anchor = Instance.new("Part")
	anchor.Name = "DamageNumber"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position + Vector3.new(0, 3.5, 0)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Parent = workspace
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(130, 52)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor
	local label = textLabel(billboard, "Damage", `-{damage}`, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), combo == 3 and 28 or 21, combo == 3 and goldPale or pale, Enum.TextXAlignment.Center)
	label.Font = Enum.Font.GothamBlack
	label.TextStrokeTransparency = 0.15
	TweenService:Create(anchor, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = anchor.Position + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.7)
end

local function burst(position, color, amount)
	local anchor = Instance.new("Part")
	anchor.Name = "SoulBurst"
	anchor.Size = Vector3.new(0.25, 0.25, 0.25)
	anchor.Position = position
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color, goldPale)
	emitter.LightEmission = 0.9
	emitter.Lifetime = NumberRange.new(0.35, 0.8)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(8, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = anchor
	emitter:Emit(amount or 30)
	Debris:AddItem(anchor, 1.2)
end

local function flashCombo(text, color, seconds)
	comboLabel.Text = text
	comboLabel.TextColor3 = color
	comboLabel.TextTransparency = 0
	comboLabel.Visible = true
	local token = os.clock()
	comboLabel:SetAttribute("Token", token)
	task.delay(seconds or 0.7, function()
		if comboLabel:GetAttribute("Token") == token then comboLabel.Visible = false end
	end)
end

FX.OnClientEvent:Connect(function(effect)
	if type(effect) ~= "table" or type(effect.Kind) ~= "string" then return end

	if effect.Kind == "Hit" and effect.Position then
		floatingDamage(effect.Position, tonumber(effect.Damage) or 0, tonumber(effect.Combo) or 0)
		burst(effect.Position, effect.Combo == 3 and goldPale or crimsonLit, effect.Combo == 3 and 46 or 22)
		if effect.Combo and effect.Combo > 0 then
			flashCombo(effect.Combo == 3 and "SOUL BREAK  x3" or `CHAIN  x{effect.Combo}`, effect.Combo == 3 and goldPale or pale)
		end
	elseif effect.Kind == "Swing" then
		press(attackButton)
		sweep(attackButton, effect.Cooldown)
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			burst(rootPart.Position + rootPart.CFrame.LookVector * 4 + Vector3.new(0, 1.5, 0), effect.Combo == 3 and goldPale or crimsonLit, effect.Combo == 3 and 34 or 14)
		end
	elseif effect.Kind == "Cooling" then
		press(attackButton)
	elseif effect.Kind == "Miss" then
		-- A miss says why. Silence here is what made Soul Strike feel broken.
		local distance = tonumber(effect.Distance)
		flashCombo(distance and `TOO FAR - {math.floor(distance)} STUDS TO NEAREST` or "NOTHING STIRS HERE", muted, 0.8)
	elseif effect.Kind == "Struck" then
		damageFlash.BackgroundTransparency = 0.7
		TweenService:Create(damageFlash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	elseif effect.Kind == "Death" and effect.Position then
		burst(effect.Position, effect.Color or crimsonLit, effect.Boss and 100 or 52)
	elseif effect.Kind == "Dash" and effect.Player then
		local character = effect.Player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then burst(rootPart.Position, ember, 26) end
		if effect.Player == player then
			press(dashButton)
			sweep(dashButton, effect.Cooldown)
			if workspace.CurrentCamera then
				local camera = workspace.CurrentCamera
				TweenService:Create(camera, TweenInfo.new(0.1), { FieldOfView = 78 }):Play()
				task.delay(0.12, function() TweenService:Create(camera, TweenInfo.new(0.25), { FieldOfView = 70 }):Play() end)
			end
		end
	elseif effect.Kind == "Dodge" then
		flashCombo("PHASED", goldPale, 0.55)
	elseif effect.Kind == "BossCharge" then
		toastMessage("WARDEN SLAM — SOUL STEP (E) THROUGH IT")
	elseif effect.Kind == "BossSlam" and effect.Position then
		burst(effect.Position, crimsonLit, 90)
	elseif effect.Kind == "Pulse" and effect.Position then
		burst(effect.Position, goldLight, 65)
		press(pulseButton)
		sweep(pulseButton, effect.Cooldown)
	elseif effect.Kind == "Quest" then
		flashCombo(`QUEST COMPLETE — {effect.Title}`, goldPale, 2)
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart then burst(rootPart.Position + Vector3.new(0, 3, 0), gold, 70) end
	elseif effect.Kind == "Ranked" then
		flashCombo("RANK UP", goldPale, 1)
	end
end)

-- Health ---------------------------------------------------------------------

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

-- Targeting ------------------------------------------------------------------

local targetClock = 0
RunService.RenderStepped:Connect(function(delta)
	targetClock += delta
	if targetClock < 0.12 then return end
	targetClock = 0
	local characterRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local soulWorld = workspace:FindFirstChild("SoulGrindWorld")
	if not characterRoot or not soulWorld then
		targetFrame.Visible = false
		targetOutline.Enabled = false
		return
	end

	local nearest, nearestDistance
	for _, candidate in soulWorld:GetChildren() do
		if candidate:IsA("Model") and candidate:GetAttribute("Enemy") and candidate.PrimaryPart then
			local humanoid = candidate:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local distance = (candidate.PrimaryPart.Position - characterRoot.Position).Magnitude
				if distance <= 110 and (not nearestDistance or distance < nearestDistance) then
					nearest, nearestDistance = candidate, distance
				end
			end
		end
	end

	if not nearest then
		targetFrame.Visible = false
		targetOutline.Enabled = false
		return
	end

	local humanoid = nearest:FindFirstChildOfClass("Humanoid")
	local inRange = nearestDistance <= Config.AttackRange
	targetFrame.Visible = true
	targetName.Text = `{nearest:GetAttribute("Boss") and "BOSS  -  " or ""}{humanoid.DisplayName}`
	targetFill.BackgroundColor3 = nearest:GetAttribute("Boss") and gold or crimsonLit
	targetFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
	targetRange.Text = inRange and `IN RANGE  -  {math.floor(nearestDistance)} studs` or `MOVE CLOSER  -  {math.floor(nearestDistance)} studs`
	targetRange.TextColor3 = inRange and goldPale or muted

	targetOutline.Adornee = nearest
	targetOutline.OutlineColor = inRange and goldPale or muted
	targetOutline.Enabled = true
end)

-- Offers ---------------------------------------------------------------------

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

-- Input ----------------------------------------------------------------------
-- Every route funnels through these three, so a key, a tap, a click and the on-screen
-- button are literally the same code path.

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
