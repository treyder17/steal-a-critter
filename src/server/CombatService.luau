-- Slap-Handschuh: schubst Spieler weg; wer getroffen wird, verliert den getragenen Critter.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CombatService = {}

local S
local template: Tool
local lastSlap: { [Player]: number } = {}

local function buildTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Slap"
	tool.CanBeDropped = false
	tool.ToolTip = "Slap thieves to make them drop your critter!"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.new(1.6, 1.6, 1.6)
	handle.Color = Color3.fromRGB(255, 170, 190)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return tool
end

function CombatService.Init(services)
	S = services
	template = buildTool()
end

function CombatService.GiveSlap(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	if backpack:FindFirstChild("Slap") or (player.Character and player.Character:FindFirstChild("Slap")) then
		return
	end
	local tool = template:Clone()
	tool.Activated:Connect(function()
		CombatService.Slap(player, tool)
	end)
	tool.Parent = backpack
end

function CombatService.Slap(player: Player, tool: Tool)
	local t = os.clock()
	if (lastSlap[player] or 0) + Config.SlapCooldown > t then
		return
	end
	lastSlap[player] = t

	-- Das Standard-Animate-Script spielt bei "toolanim" die Schlag-Animation ab
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	Debris:AddItem(anim, 1)

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherCharacter = other.Character
			local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			local otherHumanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
			if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
				local offset = otherRoot.Position - rootPart.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local distance = flat.Magnitude
				if distance > 0.01 and distance <= Config.SlapRange and rootPart.CFrame.LookVector:Dot(flat.Unit) > 0.2 then
					-- Charaktere gehoeren physikalisch dem Client, darum schubst der Client sich selbst
					S.Remotes.Knockback:FireClient(other, flat.Unit * Config.SlapForce + Vector3.new(0, Config.SlapForce * 0.45, 0))
					if S.StealService.IsCarrying(other) then
						S.StealService.Cancel(other, "slapped")
					end
				end
			end
		end
	end
end

function CombatService.OnPlayerRemoving(player: Player)
	lastSlap[player] = nil
end

return CombatService
