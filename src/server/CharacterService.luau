-- Spawn in der eigenen Basis, Laufgeschwindigkeit, Slap-Tool.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CharacterService = {}

local S

function CharacterService.Init(services)
	S = services
end

function CharacterService.UpdateSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local fast = player:GetAttribute("Pass_Speed") == true
	if S.StealService.IsCarrying(player) then
		humanoid.WalkSpeed = if fast then Config.WalkSpeed else Config.CarryWalkSpeed
	else
		humanoid.WalkSpeed = if fast then Config.SpeedPassWalkSpeed else Config.WalkSpeed
	end
end

function CharacterService.Setup(player: Player)
	local function onCharacter(character: Model)
		local rootPart = character:WaitForChild("HumanoidRootPart", 10)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not rootPart or not humanoid then
			return
		end
		task.wait()
		local plot = S.BaseService.GetPlot(player)
		if plot and character.Parent then
			character:PivotTo(plot.SpawnCFrame)
		end
		CharacterService.UpdateSpeed(player)
		S.CombatService.GiveSlap(player)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player:GetAttributeChangedSignal("Pass_Speed"):Connect(function()
		CharacterService.UpdateSpeed(player)
	end)
end

return CharacterService
