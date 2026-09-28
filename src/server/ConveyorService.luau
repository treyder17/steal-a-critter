-- Laesst Critters ueber das Laufband laufen; Spieler kaufen sie mit Cash.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local CritterFactory = require(ReplicatedStorage.Shared.CritterFactory)

local ConveyorService = {}

local S
local rng = Random.new()
local FACING = CFrame.Angles(0, -math.pi / 2, 0) -- Blickrichtung +X (Laufrichtung)

local function isLuckActive(): boolean
	return workspace:GetServerTimeNow() < (workspace:GetAttribute("LuckEndsAt") or 0)
end

local function pickCritter()
	local weights, total = Config.GetRarityWeights(isLuckActive())
	local roll = rng:NextNumber() * total
	for _, rarity in Config.Rarities do
		roll -= weights[rarity.Name]
		if roll <= 0 then
			local list = Config.CrittersByRarity[rarity.Name]
			return list[rng:NextInteger(1, #list)]
		end
	end
	return Config.Critters[1]
end

local function tryBuy(player: Player, def): boolean
	local data = S.DataService.Get(player)
	local plot = S.BaseService.GetPlot(player)
	if not data or not plot then
		return false
	end
	if data.Cash < def.Price then
		S.Notify(player, `Not enough cash! You need ${Util.FormatNumber(def.Price)}`, Color3.fromRGB(255, 90, 90))
		return false
	end
	local slot = S.BaseService.FindFreeSlot(player)
	if not slot then
		S.Notify(player, "Your base is full! Sell a critter or get VIP for +4 slots.", Color3.fromRGB(255, 200, 80))
		return false
	end

	data.Cash -= def.Price
	data.Slots[tostring(slot)] = def.Id
	data.Stats.Bought += 1
	S.DataService.Sync(player)
	S.BaseService.RenderSlot(plot, slot)
	S.Notify(player, `You bought {def.Name}!`, Color3.fromRGB(120, 255, 140))

	local rarity = Config.RarityByName[def.Rarity]
	if Config.RarityIndex[def.Rarity] >= Config.RarityIndex.Legendary then
		S.NotifyAll(`{player.DisplayName} bought a {def.Rarity} {def.Name}!`, rarity.Color)
	end
	return true
end

local function spawnCritter()
	local def = pickCritter()
	local rarity = Config.RarityByName[def.Rarity]
	local model = CritterFactory.Build(def.Id, { Label = "Shop" })
	local root = model.PrimaryPart
	model:PivotTo(CFrame.new(S.MapService.ConveyorStart) * FACING)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Buy ${Util.FormatNumber(def.Price)}`
	prompt.ObjectText = def.Name
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root:FindFirstChild("Center") or root

	model.Parent = workspace.ConveyorCritters

	local tween = TweenService:Create(
		root,
		TweenInfo.new(Config.ConveyorTravelTime, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(S.MapService.ConveyorEnd) * FACING }
	)
	local sold = false
	prompt.Triggered:Connect(function(player)
		if sold then
			return
		end
		if tryBuy(player, def) then
			sold = true
			tween:Cancel()
			model:Destroy()
		end
	end)
	tween.Completed:Connect(function()
		if model.Parent then
			model:Destroy()
		end
	end)
	tween:Play()

	if Config.RarityIndex[def.Rarity] >= Config.RarityIndex.Mythic then
		S.NotifyAll(`A {string.upper(def.Rarity)} {def.Name} appeared on the conveyor!`, rarity.Color)
	end
end

function ConveyorService.Init(services)
	S = services
end

function ConveyorService.Start()
	task.spawn(function()
		while true do
			local ok, err = pcall(spawnCritter)
			if not ok then
				warn("[ConveyorService] Spawn failed:", err)
			end
			task.wait(Config.ConveyorSpawnInterval)
		end
	end)
end

return ConveyorService
