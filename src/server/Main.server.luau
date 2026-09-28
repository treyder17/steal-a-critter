-- Einstiegspunkt: erstellt Remotes, startet alle Services, verwaltet Join/Leave.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "Notify", "Knockback", "RequestLock", "DevGrant" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

local ORDER = {
	"DataService",
	"MapService",
	"BaseService",
	"ConveyorService",
	"StealService",
	"CharacterService",
	"CombatService",
	"IncomeService",
	"MonetizationService",
}

local Services: { [string]: any } = { Remotes = remotes }
for _, name in ORDER do
	Services[name] = require(script.Parent[name])
end

function Services.Notify(player: Player, text: string, color: Color3?)
	remotes.Notify:FireClient(player, text, color)
end

function Services.NotifyAll(text: string, color: Color3?)
	remotes.Notify:FireAllClients(text, color)
end

for _, name in ORDER do
	local service = Services[name]
	if service.Init then
		service.Init(Services)
	end
end
for _, name in ORDER do
	local service = Services[name]
	if service.Start then
		service.Start()
	end
end

local function onPlayerAdded(player: Player)
	Services.MonetizationService.CheckPasses(player)
	Services.DataService.Load(player)
	if not player.Parent or not Services.DataService.Get(player) then
		return
	end
	if not Services.BaseService.Assign(player) then
		player:Kick("This server is full. Please join another server!")
		return
	end
	Services.CharacterService.Setup(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Services.StealService.OnPlayerRemoving(player)
	Services.CombatService.OnPlayerRemoving(player)
	Services.BaseService.Release(player)
	Services.DataService.Release(player)
end)
