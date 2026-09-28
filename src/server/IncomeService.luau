-- Jede Sekunde: Einkommen aller Critters in der Basis gutschreiben.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local IncomeService = {}

local S

function IncomeService.Init(services)
	S = services
end

function IncomeService.GetIncome(player: Player): number
	local data = S.DataService.Get(player)
	if not data then
		return 0
	end
	local plot = S.BaseService.GetPlot(player)
	local total = 0
	for key, critterId in data.Slots do
		local def = Config.CritterById[critterId]
		local slot = plot and plot.Slots[tonumber(key)]
		if def and not (slot and slot.StolenBy) then
			total += def.Income
		end
	end
	if player:GetAttribute("Pass_DoubleCash") then
		total *= 2
	end
	return total
end

function IncomeService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = S.DataService.Get(player)
				if data then
					local income = IncomeService.GetIncome(player)
					if income > 0 then
						data.Cash += income
						S.DataService.Sync(player)
					end
					player:SetAttribute("Income", income)
				end
			end
		end
	end)
end

return IncomeService
