-- Zentrale Spiel-Konfiguration.
-- IDs mit 0 = noch nicht auf create.roblox.com angelegt. In Studio werden
-- Kaeufe dann simuliert, im Live-Spiel steht "Not available yet".
local Config = {}

Config.GameName = "Steal a Critter"

-- Wirtschaft
Config.StartCash = 100
Config.SellRatio = 0.5

-- Basis
Config.BaseSlots = 8
Config.VipExtraSlots = 4
Config.LockDuration = 60
Config.LockCooldown = 30
Config.InstantLockDuration = 120

-- Bewegung
Config.WalkSpeed = 18
Config.CarryWalkSpeed = 11
Config.SpeedPassWalkSpeed = 24

-- Laufband
Config.ConveyorSpawnInterval = 2.2
Config.ConveyorTravelTime = 45

-- Slap
Config.SlapCooldown = 1.2
Config.SlapRange = 9
Config.SlapForce = 70

-- Server-Glueck (Developer Product)
Config.LuckDuration = 15 * 60

Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(205, 205, 205), Weight = 60, LuckMultiplier = 1 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 220, 110), Weight = 24, LuckMultiplier = 1 },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255), Weight = 10, LuckMultiplier = 2 },
	{ Name = "Epic", Color = Color3.fromRGB(180, 90, 255), Weight = 4, LuckMultiplier = 3 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40), Weight = 1.5, LuckMultiplier = 4 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 70, 90), Weight = 0.45, LuckMultiplier = 5 },
	{ Name = "Secret", Color = Color3.fromRGB(255, 60, 220), Weight = 0.05, LuckMultiplier = 6 },
}

-- Shape: "Ball" | "Block" | "Cylinder"
Config.Critters = {
	{ Id = "toastodile", Name = "Toastodile", Rarity = "Common", Price = 25, Income = 1, Shape = "Block", Color = Color3.fromRGB(214, 160, 90), Size = 3 },
	{ Id = "sockgoblin", Name = "Sock Goblin", Rarity = "Common", Price = 60, Income = 2, Shape = "Ball", Color = Color3.fromRGB(120, 200, 120), Size = 2.8 },
	{ Id = "beanbandit", Name = "Bean Bandit", Rarity = "Common", Price = 120, Income = 4, Shape = "Ball", Color = Color3.fromRGB(150, 90, 50), Size = 3 },
	{ Id = "pickleknight", Name = "Pickle Knight", Rarity = "Uncommon", Price = 350, Income = 10, Shape = "Cylinder", Color = Color3.fromRGB(90, 160, 60), Size = 3.4 },
	{ Id = "cactuscowboy", Name = "Cactus Cowboy", Rarity = "Uncommon", Price = 750, Income = 20, Shape = "Cylinder", Color = Color3.fromRGB(60, 140, 80), Size = 3.6 },
	{ Id = "wafflewizard", Name = "Waffle Wizard", Rarity = "Rare", Price = 2000, Income = 45, Shape = "Block", Color = Color3.fromRGB(230, 180, 90), Size = 3.6 },
	{ Id = "discollama", Name = "Disco Llama", Rarity = "Rare", Price = 4500, Income = 90, Shape = "Ball", Color = Color3.fromRGB(240, 120, 200), Size = 3.8 },
	{ Id = "turbotoaster", Name = "Turbo Toaster", Rarity = "Epic", Price = 12000, Income = 220, Shape = "Block", Color = Color3.fromRGB(170, 170, 185), Size = 4 },
	{ Id = "moonmoose", Name = "Moon Moose", Rarity = "Epic", Price = 25000, Income = 420, Shape = "Ball", Color = Color3.fromRGB(120, 130, 220), Size = 4.2 },
	{ Id = "pizzakraken", Name = "Pizza Kraken", Rarity = "Legendary", Price = 80000, Income = 1200, Shape = "Ball", Color = Color3.fromRGB(255, 140, 50), Size = 4.6 },
	{ Id = "goldengloop", Name = "Golden Gloop", Rarity = "Legendary", Price = 160000, Income = 2200, Shape = "Ball", Color = Color3.fromRGB(255, 210, 60), Size = 4.6 },
	{ Id = "thunderfrog", Name = "Thunder Frog", Rarity = "Mythic", Price = 600000, Income = 7000, Shape = "Ball", Color = Color3.fromRGB(60, 220, 255), Size = 5 },
	{ Id = "galaxygorilla", Name = "Galaxy Gorilla", Rarity = "Mythic", Price = 1500000, Income = 15000, Shape = "Block", Color = Color3.fromRGB(90, 40, 160), Size = 5.2 },
	{ Id = "cosmicburrito", Name = "Cosmic Burrito", Rarity = "Secret", Price = 8000000, Income = 70000, Shape = "Cylinder", Color = Color3.fromRGB(255, 255, 255), Size = 5.5 },
}

-- Monetarisierung: Id nach dem Anlegen auf create.roblox.com eintragen.
-- Price ist nur der Anzeige-Fallback, der echte Preis kommt von Roblox.
Config.GamePasses = {
	{ Key = "DoubleCash", Id = 0, Name = "2x Cash", Description = "Doubles all income. Forever.", Price = 199 },
	{ Key = "VIP", Id = 0, Name = "VIP Base", Description = "+4 extra base slots.", Price = 299 },
	{ Key = "Speed", Id = 0, Name = "Speed Runner", Description = "Run faster and no slowdown while carrying.", Price = 149 },
}

-- Kind: "Cash" | "Luck" | "Lock"
Config.Products = {
	{ Key = "CashSmall", Id = 0, Kind = "Cash", Name = "Cash Bag", Minutes = 10, Minimum = 2500, Price = 29 },
	{ Key = "CashMedium", Id = 0, Kind = "Cash", Name = "Cash Chest", Minutes = 60, Minimum = 25000, Price = 99 },
	{ Key = "CashLarge", Id = 0, Kind = "Cash", Name = "Cash Vault", Minutes = 300, Minimum = 250000, Price = 349 },
	{ Key = "ServerLuck", Id = 0, Kind = "Luck", Name = "Server Luck (15 min)", Description = "Boosts Rare+ spawns for EVERYONE on this server. See ODDS.", Price = 149 },
	{ Key = "InstantLock", Id = 0, Kind = "Lock", Name = "Instant Lock (2 min)", Description = "Lock your base right now, ignores cooldown.", Price = 19 },
}

-- Abgeleitete Lookups
Config.RarityByName = {}
Config.RarityIndex = {}
for index, rarity in Config.Rarities do
	Config.RarityByName[rarity.Name] = rarity
	Config.RarityIndex[rarity.Name] = index
end

Config.CritterById = {}
Config.CrittersByRarity = {}
for _, critter in Config.Critters do
	Config.CritterById[critter.Id] = critter
	Config.CrittersByRarity[critter.Rarity] = Config.CrittersByRarity[critter.Rarity] or {}
	table.insert(Config.CrittersByRarity[critter.Rarity], critter)
end

Config.GamePassByKey = {}
for _, pass in Config.GamePasses do
	Config.GamePassByKey[pass.Key] = pass
end

Config.ProductByKey = {}
for _, product in Config.Products do
	Config.ProductByKey[product.Key] = product
end

-- Gewichte pro Seltenheit (fuer Spawns und die ODDS-Anzeige)
function Config.GetRarityWeights(luckActive: boolean): ({ [string]: number }, number)
	local weights = {}
	local total = 0
	for _, rarity in Config.Rarities do
		local weight = rarity.Weight * (if luckActive then rarity.LuckMultiplier else 1)
		weights[rarity.Name] = weight
		total += weight
	end
	return weights, total
end

return Config
