-- Basen-Zuweisung, Sockel-Anzeige, Verkaufen und Base-Lock.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local CritterFactory = require(ReplicatedStorage.Shared.CritterFactory)

local BaseService = {}

local S -- Service-Registry aus Main
local plotByPlayer: { [Player]: any } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

function BaseService.Init(services)
	S = services
	for _, plot in S.MapService.Plots do
		plot.Owner = nil
		plot.LockEndsAt = 0
		plot.LockReadyAt = 0
		plot.GateLocked = false
		plot.Connections = {}
		for _, slot in plot.Slots do
			slot.SellPrompt.Triggered:Connect(function(player)
				BaseService.Sell(player, plot, slot.Index)
			end)
			slot.StealPrompt.Triggered:Connect(function(player)
				S.StealService.TryStart(player, plot, slot.Index)
			end)
		end
		plot.LockPrompt.Triggered:Connect(function(player)
			if plot.Owner == player then
				BaseService.TryLock(player)
			end
		end)
	end
	S.Remotes.RequestLock.OnServerEvent:Connect(function(player)
		BaseService.TryLock(player)
	end)
end

function BaseService.Start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, plot in S.MapService.Plots do
				BaseService.UpdatePlotVisuals(plot)
			end
		end
	end)
end

function BaseService.GetPlot(player: Player)
	return plotByPlayer[player]
end

function BaseService.GetSlotCount(player: Player): number
	return Config.BaseSlots + (if player:GetAttribute("Pass_VIP") then Config.VipExtraSlots else 0)
end

function BaseService.FindFreeSlot(player: Player): number?
	local data = S.DataService.Get(player)
	if not data then
		return nil
	end
	for i = 1, BaseService.GetSlotCount(player) do
		if data.Slots[tostring(i)] == nil then
			return i
		end
	end
	return nil
end

function BaseService.IsInsidePlot(plot, position: Vector3): boolean
	local localPos = plot.CFrame:PointToObjectSpace(position)
	return math.abs(localPos.X) < S.MapService.PlotWidth / 2
		and math.abs(localPos.Z) < S.MapService.PlotDepth / 2
		and localPos.Y < 30
end

function BaseService.IsLocked(plot): boolean
	return now() < plot.LockEndsAt
end

function BaseService.RenderSlot(plot, index: number)
	local slot = plot.Slots[index]
	if slot.Model then
		slot.Model:Destroy()
		slot.Model = nil
	end

	local owner = plot.Owner
	local data = owner and S.DataService.Get(owner)
	local critterId = data and data.Slots[tostring(index)]
	local def = critterId and Config.CritterById[critterId]
	local visible = def ~= nil and slot.StolenBy == nil

	slot.VipLabel.Enabled = owner ~= nil and index > BaseService.GetSlotCount(owner)
	if visible then
		local model = CritterFactory.Build(def.Id, { Label = "Base" })
		model:PivotTo(slot.CFrame)
		model.Parent = plot.Model
		slot.Model = model
		slot.StealPrompt.ObjectText = `{def.Name} ({def.Rarity})`
		slot.SellPrompt.ObjectText = def.Name
		slot.SellPrompt.ActionText = `Sell ${Util.FormatNumber(def.Price * Config.SellRatio)}`
	end
	slot.StealPrompt:SetAttribute("Active", visible)
	slot.SellPrompt:SetAttribute("Active", visible)
end

function BaseService.RenderAll(plot)
	for index in plot.Slots do
		BaseService.RenderSlot(plot, index)
	end
end

function BaseService.Assign(player: Player)
	for _, plot in S.MapService.Plots do
		if plot.Owner == nil then
			plot.Owner = player
			plot.LockEndsAt = 0
			plot.LockReadyAt = 0
			plot.Model:SetAttribute("OwnerId", player.UserId)
			plot.SignTitle.Text = `{player.DisplayName}'s Base`
			plotByPlayer[player] = plot
			player:SetAttribute("PlotIndex", plot.Index)
			player:SetAttribute("LockEndsAt", 0)
			player:SetAttribute("LockReadyAt", 0)
			table.insert(plot.Connections, player:GetAttributeChangedSignal("Pass_VIP"):Connect(function()
				BaseService.RenderAll(plot)
			end))
			BaseService.RenderAll(plot)
			return plot
		end
	end
	warn(`[BaseService] No free plot for {player.Name} - set Max Players to 8`)
	return nil
end

function BaseService.Release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	for _, connection in plot.Connections do
		connection:Disconnect()
	end
	table.clear(plot.Connections)
	plot.Owner = nil
	plot.LockEndsAt = 0
	plot.LockReadyAt = 0
	plot.Model:SetAttribute("OwnerId", 0)
	plot.SignTitle.Text = "Empty Base"
	for _, slot in plot.Slots do
		slot.StolenBy = nil
	end
	BaseService.RenderAll(plot)
	BaseService.UpdatePlotVisuals(plot)
end

function BaseService.Sell(player: Player, plot, index: number)
	if plot.Owner ~= player then
		return
	end
	local slot = plot.Slots[index]
	if slot.StolenBy then
		return
	end
	local data = S.DataService.Get(player)
	local key = tostring(index)
	local def = data and Config.CritterById[data.Slots[key] or ""]
	if not def then
		return
	end
	local value = math.floor(def.Price * Config.SellRatio)
	data.Slots[key] = nil
	data.Cash += value
	S.DataService.Sync(player)
	BaseService.RenderSlot(plot, index)
	S.Notify(player, `Sold {def.Name} for ${Util.FormatNumber(value)}`, Color3.fromRGB(120, 255, 140))
end

local function applyLock(plot, duration: number)
	local t = now()
	plot.LockEndsAt = math.max(t, plot.LockEndsAt) + duration
	plot.LockReadyAt = plot.LockEndsAt + Config.LockCooldown
	if plot.Owner then
		plot.Owner:SetAttribute("LockEndsAt", plot.LockEndsAt)
		plot.Owner:SetAttribute("LockReadyAt", plot.LockReadyAt)
	end
	BaseService.UpdatePlotVisuals(plot)
end

function BaseService.TryLock(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	local t = now()
	if t < plot.LockEndsAt then
		S.Notify(player, "Your base is already locked!")
		return
	end
	if t < plot.LockReadyAt then
		S.Notify(player, `Lock ready in {math.ceil(plot.LockReadyAt - t)}s`, Color3.fromRGB(255, 200, 80))
		return
	end
	applyLock(plot, Config.LockDuration)
	S.Notify(player, `Base locked for {Config.LockDuration}s!`, Color3.fromRGB(120, 255, 140))
end

-- Fuer das "Instant Lock"-Produkt: ignoriert Cooldown, verlaengert laufenden Lock.
function BaseService.ForceLock(player: Player, duration: number): boolean
	local plot = plotByPlayer[player]
	if not plot then
		return false
	end
	applyLock(plot, duration)
	return true
end

function BaseService.UpdatePlotVisuals(plot)
	local remaining = plot.LockEndsAt - now()
	local locked = remaining > 0
	if locked ~= plot.GateLocked then
		plot.GateLocked = locked
		plot.Gate.Transparency = if locked then 0 else 1
		plot.Gate.CanCollide = locked
	end
	if plot.Owner then
		plot.SignStatus.Text = if locked then `LOCKED {math.ceil(remaining)}s` else "OPEN"
	else
		plot.SignStatus.Text = ""
	end
end

return BaseService
