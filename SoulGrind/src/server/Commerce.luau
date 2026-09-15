local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.SoulGrind.Config)
local Receipt = require(script.Parent.Receipt)

local Commerce = {}
local Store
local publish
local notice
local applyAura

local productsById = {}
for _, product in Config.Products do
	if product.Id > 0 then productsById[product.Id] = product end
end

Commerce.applyReceipt = Receipt.apply

local function processReceipt(receipt)
	if not Store.isDurable() then
		warn("Soul Grind refused a paid receipt because Studio persistence is disabled")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if type(receipt.PlayerId) ~= "number" or type(receipt.ProductId) ~= "number" or type(receipt.PurchaseId) ~= "string" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = productsById[receipt.ProductId]
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not product or not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local success, profile = Store.update(receipt.PlayerId, function(current)
		Receipt.apply(current, receipt, productsById)
		return current
	end)

	if not success or profile.Receipts[receipt.PurchaseId] ~= receipt.ProductId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	publish(player)
	notice(player, `{product.Amount} Soul Flares entered your wallet.`)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Commerce.refreshPass(player)
	local pass = Config.Passes.Aura
	local owns = false
	if pass.Id > 0 then
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
		owns = ok and result == true
	end
	player:SetAttribute("HasAura", owns)
	applyAura(player, owns)
	publish(player)
end

function Commerce.offer(player, kind)
	if kind == "FlarePack" then
		local product = Config.Products.FlarePack
		if product.Id <= 0 then
			notice(player, "Create the Soul Flare developer product, then set its ID in Config.")
			return
		end
		ReplicatedStorage.SoulGrind.Offer:FireClient(player, {
			kind = "Product", id = product.Id, label = product.Label, description = product.Description,
		})
	elseif kind == "Aura" then
		local pass = Config.Passes.Aura
		if pass.Id <= 0 then
			notice(player, "Create the aura pass, then set its ID in Config.")
			return
		end
		ReplicatedStorage.SoulGrind.Offer:FireClient(player, {
			kind = "Pass", id = pass.Id, label = pass.Label, description = pass.Description,
		})
	end
end

function Commerce.init(storeModule, publishState, showNotice, auraFunction)
	Store, publish, notice, applyAura = storeModule, publishState, showNotice, auraFunction
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.Passes.Aura.Id then
			Commerce.refreshPass(player)
		end
	end)
end

Commerce.processReceiptForTest = processReceipt
return Commerce
