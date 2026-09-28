-- Klauen: Critter aus fremder Basis aufnehmen, ueber dem Kopf tragen und
-- in die eigene Basis bringen. Der Critter bleibt bis zur Ablieferung in den
-- Daten des Besitzers, damit bei Abbruch/Disconnect nichts verloren geht.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CritterFactory = require(ReplicatedStorage.Shared.CritterFactory)

local StealService = {}

local S
local carrying: { [Player]: any } = {}

local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(120, 255, 140)

local CANCEL_MESSAGES = {
	died = { Thief = "You dropped the critter!", Victim = "Your %s was returned!" },
	slapped = { Thief = "You got slapped! The critter went back.", Victim = "You saved your %s!" },
	ownerLeft = { Thief = "The owner left - the critter vanished.", Victim = nil },
	failed = { Thief = "Steal failed - your base is full.", Victim = "Your %s was returned!" },
}

function StealService.Init(services)
	S = services
end

function StealService.Start()
	task.spawn(function()
		while true do
			task.wait(0.1)
			for thief in carrying do
				local character = thief.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				local home = S.BaseService.GetPlot(thief)
				if rootPart and home and S.BaseService.IsInsidePlot(home, rootPart.Position) then
					StealService.Complete(thief)
				end
			end
		end
	end)
end

function StealService.IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function StealService.TryStart(thief: Player, plot, index: number)
	local victim = plot.Owner
	if not victim or victim == thief or carrying[thief] then
		return
	end
	local slot = plot.Slots[index]
	local victimData = S.DataService.Get(victim)
	local critterId = victimData and victimData.Slots[tostring(index)]
	if slot.StolenBy or not critterId or not Config.CritterById[critterId] then
		return
	end
	if S.BaseService.IsLocked(plot) then
		S.Notify(thief, "This base is locked!", RED)
		return
	end
	if not S.BaseService.GetPlot(thief) then
		return
	end
	if not S.BaseService.FindFreeSlot(thief) then
		S.Notify(thief, "Your base is full! Sell a critter or get VIP for +4 slots.", Color3.fromRGB(255, 200, 80))
		return
	end
	local character = thief.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid or humanoid.Health <= 0 then
		return
	end

	slot.StolenBy = thief
	S.BaseService.RenderSlot(plot, index)

	local model = CritterFactory.Build(critterId, { Scale = 0.55 })
	local root = model.PrimaryPart
	root.Anchored = false
	model:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.1, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = root
	weld.Parent = root
	model.Parent = character

	local entry = {
		Plot = plot,
		SlotIndex = index,
		CritterId = critterId,
		Victim = victim,
		Model = model,
		Connections = {},
	}
	carrying[thief] = entry
	table.insert(entry.Connections, humanoid.Died:Connect(function()
		StealService.Cancel(thief, "died")
	end))
	table.insert(entry.Connections, thief.CharacterRemoving:Connect(function()
		StealService.Cancel(thief, "died")
	end))

	S.CharacterService.UpdateSpeed(thief)
	local def = Config.CritterById[critterId]
	S.Notify(thief, `You grabbed {def.Name}! Run back to your base!`, GREEN)
	S.Notify(victim, `{thief.DisplayName} is stealing your {def.Name}! Slap them!`, RED)
end

local function finish(thief: Player, entry)
	carrying[thief] = nil
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
	if entry.Model then
		entry.Model:Destroy()
	end
	local slot = entry.Plot.Slots[entry.SlotIndex]
	if slot.StolenBy == thief then
		slot.StolenBy = nil
	end
	S.CharacterService.UpdateSpeed(thief)
end

function StealService.Cancel(thief: Player, reason: string?)
	local entry = carrying[thief]
	if not entry then
		return
	end
	finish(thief, entry)
	if entry.Plot.Owner == entry.Victim then
		S.BaseService.RenderSlot(entry.Plot, entry.SlotIndex)
	end

	local messages = reason and CANCEL_MESSAGES[reason]
	if messages then
		local def = Config.CritterById[entry.CritterId]
		if thief.Parent then
			S.Notify(thief, messages.Thief, RED)
		end
		if messages.Victim and entry.Victim.Parent then
			S.Notify(entry.Victim, string.format(messages.Victim, def.Name), GREEN)
		end
	end
end

function StealService.Complete(thief: Player)
	local entry = carrying[thief]
	if not entry then
		return
	end
	local victim = entry.Victim
	local key = tostring(entry.SlotIndex)
	local victimData = S.DataService.Get(victim)
	local thiefData = S.DataService.Get(thief)
	local freeSlot = S.BaseService.FindFreeSlot(thief)
	local stillValid = victimData ~= nil
		and thiefData ~= nil
		and entry.Plot.Owner == victim
		and victimData.Slots[key] == entry.CritterId
	if not stillValid or not freeSlot then
		StealService.Cancel(thief, "failed")
		return
	end

	finish(thief, entry)
	victimData.Slots[key] = nil
	thiefData.Slots[tostring(freeSlot)] = entry.CritterId
	thiefData.Stats.Stolen += 1
	victimData.Stats.TimesRobbed += 1
	S.DataService.Sync(thief)
	S.BaseService.RenderSlot(entry.Plot, entry.SlotIndex)
	S.BaseService.RenderSlot(S.BaseService.GetPlot(thief), freeSlot)

	local def = Config.CritterById[entry.CritterId]
	S.Notify(thief, `You stole {def.Name}!`, GREEN)
	S.Notify(victim, `{thief.DisplayName} stole your {def.Name}! Lock your base!`, RED)
	if Config.RarityIndex[def.Rarity] >= Config.RarityIndex.Epic then
		S.NotifyAll(`{thief.DisplayName} stole a {def.Rarity} {def.Name} from {victim.DisplayName}!`, Config.RarityByName[def.Rarity].Color)
	end
end

function StealService.OnPlayerRemoving(player: Player)
	StealService.Cancel(player)
	for thief, entry in carrying do
		if entry.Victim == player then
			StealService.Cancel(thief, "ownerLeft")
		end
	end
end

return StealService
