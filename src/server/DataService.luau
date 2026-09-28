-- Speichert Spielerdaten im DataStore (Cash, Slots, Kauf-Belege, Stats).
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local DataService = {}

local STORE_NAME = "StealACritter_PlayerData_v1"
local AUTOSAVE_INTERVAL = 60
DataService.MaxReceipts = 100

local store: DataStore? = nil
do
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable:", result)
	end
end

type Session = { Data: any, CanSave: boolean }
local sessions: { [Player]: Session } = {}

local function defaultData()
	return {
		Cash = Config.StartCash,
		Slots = {}, -- ["1"] = critterId (String-Keys, damit der DataStore keine Arrays mit Loechern bekommt)
		Receipts = {}, -- bereits gutgeschriebene PurchaseIds
		Stats = { Bought = 0, Stolen = 0, TimesRobbed = 0, RobuxSpent = 0 },
	}
end

local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
	return data
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

function DataService.Load(player: Player)
	local data, canSave = nil, false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(store.GetAsync, store, keyFor(player))
			if ok then
				data = result
				canSave = true
				break
			end
			warn(`[DataService] Load failed for {player.Name} ({attempt}/3): {result}`)
			if RunService:IsStudio() then
				warn("[DataService] Tip: Game Settings > Security > Enable Studio Access to API Services")
				break
			end
			task.wait(2)
		end
	end
	if not player.Parent then
		return
	end
	if not canSave and not RunService:IsStudio() then
		-- Nie mit leeren Daten weiterspielen lassen, sonst ueberschreiben wir den echten Spielstand.
		player:Kick("Could not load your data. Please rejoin in a minute!")
		return
	end

	data = reconcile(if type(data) == "table" then data else defaultData(), defaultData())
	sessions[player] = { Data = data, CanSave = canSave }

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	local steals = Instance.new("IntValue")
	steals.Name = "Steals"
	steals.Parent = leaderstats
	leaderstats.Parent = player

	DataService.Sync(player)
end

function DataService.Get(player: Player)
	local session = sessions[player]
	return session and session.Data
end

function DataService.WaitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 20)
	while not sessions[player] and player.Parent and os.clock() < deadline do
		task.wait(0.2)
	end
	return DataService.Get(player)
end

-- Schreibt Cash/Stats in Attribute + leaderstats (fuer HUD und Spielerliste)
function DataService.Sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("Cash", data.Cash)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Cash.Value = "$" .. Util.FormatNumber(data.Cash)
		leaderstats.Steals.Value = data.Stats.Stolen
	end
end

function DataService.Save(player: Player): boolean
	local session = sessions[player]
	if not session or not session.CanSave or not store then
		return false
	end
	local ok, err = pcall(store.SetAsync, store, keyFor(player), session.Data, { player.UserId })
	if not ok then
		warn(`[DataService] Save failed for {player.Name}: {err}`)
	end
	return ok
end

function DataService.Release(player: Player)
	if sessions[player] then
		DataService.Save(player)
		sessions[player] = nil
	end
end

function DataService.Start()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in sessions do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
