-- Robux-Kaeufe: Gamepasses (einmalig) und Developer Products (beliebig oft).
-- ProcessReceipt ist idempotent: jede PurchaseId wird in den Spielerdaten
-- gespeichert und nur einmal gutgeschrieben.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local MonetizationService = {}

local S
local GOLD = Color3.fromRGB(255, 210, 70)
local productById: { [number]: any } = {}
local passById: { [number]: any } = {}

local grants = {}

grants.Cash = function(player: Player, product)
	local data = S.DataService.Get(player)
	local amount = math.max(product.Minimum, S.IncomeService.GetIncome(player) * product.Minutes * 60)
	data.Cash += amount
	S.DataService.Sync(player)
	S.Notify(player, `+${Util.FormatNumber(amount)} cash! Thanks for supporting the game!`, GOLD)
end

grants.Luck = function(player: Player, _product)
	local t = workspace:GetServerTimeNow()
	local current = workspace:GetAttribute("LuckEndsAt") or 0
	workspace:SetAttribute("LuckEndsAt", math.max(t, current) + Config.LuckDuration)
	S.NotifyAll(
		`{player.DisplayName} activated SERVER LUCK for {Config.LuckDuration // 60} minutes! Rare critters incoming!`,
		Color3.fromRGB(90, 230, 120)
	)
end

grants.Lock = function(player: Player, _product)
	if not S.BaseService.ForceLock(player, Config.InstantLockDuration) then
		error("Player has no base")
	end
	S.Notify(player, `Base locked for {Config.InstantLockDuration}s!`, GOLD)
end

local function grantProduct(player: Player, product)
	local handler = grants[product.Kind]
	assert(handler, `No grant handler for kind "{product.Kind}"`)
	handler(player, product)
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = S.DataService.WaitFor(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if table.find(data.Receipts, receipt.PurchaseId) then
		-- Schon gutgeschrieben, nur das Speichern hatte vorher nicht geklappt
		return if S.DataService.Save(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = productById[receipt.ProductId]
	if not product then
		warn(`[Monetization] Unknown product id {receipt.ProductId} - add it to Config.Products`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(grantProduct, player, product)
	if not ok then
		warn(`[Monetization] Grant failed for {player.Name}: {err}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(data.Receipts, receipt.PurchaseId)
	while #data.Receipts > S.DataService.MaxReceipts do
		table.remove(data.Receipts, 1)
	end
	data.Stats.RobuxSpent += receipt.CurrencySpent or 0

	if S.DataService.Save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationService.Init(services)
	S = services

	for _, product in Config.Products do
		if product.Id ~= 0 then
			productById[product.Id] = product
		end
	end
	for _, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			passById[pass.Id] = pass
		end
	end

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passById[passId]
		if purchased and pass then
			player:SetAttribute("Pass_" .. pass.Key, true)
			S.Notify(player, `Thanks! {pass.Name} unlocked!`, GOLD)
		end
	end)

	-- Nur in Studio: Kaeufe von Produkten ohne ID simulieren, damit man alles testen kann.
	S.Remotes.DevGrant.OnServerEvent:Connect(function(player, kind, key)
		if not RunService:IsStudio() then
			return
		end
		if kind == "Pass" and Config.GamePassByKey[key] then
			player:SetAttribute("Pass_" .. key, true)
		elseif kind == "Product" and Config.ProductByKey[key] then
			local ok, err = pcall(grantProduct, player, Config.ProductByKey[key])
			if not ok then
				warn("[Monetization] Studio grant failed:", err)
			end
		end
	end)
end

function MonetizationService.CheckPasses(player: Player)
	for _, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			task.spawn(function()
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
				if ok and owns and player.Parent then
					player:SetAttribute("Pass_" .. pass.Key, true)
				end
			end)
		end
	end
end

return MonetizationService
