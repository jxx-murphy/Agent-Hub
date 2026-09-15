-- Run in the server Command Bar during Play Solo:
-- require(game.ServerStorage.SoulGrindTests.CommerceSpec)()
return function()
	local Receipt = require(game.ServerScriptService.Receipt)
	local catalog = { [42] = { Item = "Flares", Amount = 5 } }
	local profile = {
		Wallet = { Flares = 0 }, Receipts = {}, LastSpendDay = -1, SpendDays = 0,
	}

	local ok, result = Receipt.apply(profile, { PurchaseId = "one", ProductId = 42 }, catalog, 86400)
	assert(ok and result == "granted" and profile.Wallet.Flares == 5, "first receipt must grant")
	ok, result = Receipt.apply(profile, { PurchaseId = "one", ProductId = 42 }, catalog, 86400)
	assert(ok and result == "duplicate" and profile.Wallet.Flares == 5, "duplicate must not grant twice")
	ok = Receipt.apply(profile, { PurchaseId = "two", ProductId = 999 }, catalog, 86400)
	assert(not ok and profile.Wallet.Flares == 5, "unknown product must not grant")
	ok = Receipt.apply(profile, { PurchaseId = "one", ProductId = 999 }, catalog, 86400)
	assert(not ok and profile.Wallet.Flares == 5, "mismatched purchase ID must not grant")
	print("Soul Grind commerce checks passed")
end
