local Receipt = {}

function Receipt.apply(profile, receipt, productCatalog, now)
	if type(profile) ~= "table" or type(receipt) ~= "table" then return false, "invalid" end
	if type(receipt.PurchaseId) ~= "string" or type(receipt.ProductId) ~= "number" then return false, "invalid" end
	local recorded = profile.Receipts[receipt.PurchaseId]
	if recorded then
		return recorded == receipt.ProductId, recorded == receipt.ProductId and "duplicate" or "mismatch"
	end
	local product = productCatalog[receipt.ProductId]
	if not product then return false, "unknown" end
	profile.Wallet[product.Item] = (profile.Wallet[product.Item] or 0) + product.Amount
	profile.Receipts[receipt.PurchaseId] = receipt.ProductId
	local day = math.floor((now or os.time()) / 86400)
	if profile.LastSpendDay ~= day then
		profile.LastSpendDay = day
		profile.SpendDays += 1
	end
	return true, "granted"
end

return Receipt
