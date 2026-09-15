local Receipt = require("../src/server/Receipt")
local catalog = { [42] = { Item = "Flares", Amount = 5 } }
local profile = { Wallet = { Flares = 0 }, Receipts = {}, LastSpendDay = -1, SpendDays = 0 }

local ok, result = Receipt.apply(profile, { PurchaseId = "one", ProductId = 42 }, catalog, 86400)
assert(ok and result == "granted" and profile.Wallet.Flares == 5)

ok, result = Receipt.apply(profile, { PurchaseId = "one", ProductId = 42 }, catalog, 86400)
assert(ok and result == "duplicate" and profile.Wallet.Flares == 5)

ok, result = Receipt.apply(profile, { PurchaseId = "two", ProductId = 42 }, catalog, 86400)
assert(ok and result == "granted" and profile.Wallet.Flares == 10)
assert(profile.SpendDays == 1, "two purchases on one day count as one spend day")

ok = Receipt.apply(profile, { PurchaseId = "unknown", ProductId = 999 }, catalog, 86400)
assert(not ok and profile.Wallet.Flares == 10)

ok = Receipt.apply(profile, { PurchaseId = "one", ProductId = 999 }, catalog, 86400)
assert(not ok and profile.Wallet.Flares == 10)

print("receipt_cli: all checks passed")
