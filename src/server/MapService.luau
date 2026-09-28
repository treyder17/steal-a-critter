-- Baut die komplette Map per Code: Boden, Laufband, 8 Basen mit Waenden,
-- Laser-Tor, 12 Sockeln und Lock-Knopf.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapService = {}

MapService.PlotWidth = 72
MapService.PlotDepth = 58
MapService.WallHeight = 9
MapService.ConveyorStart = Vector3.new(-178, 1, 0)
MapService.ConveyorEnd = Vector3.new(178, 1, 0)
MapService.Plots = {}

local GATE_WIDTH = 16
local WHITE = Color3.new(1, 1, 1)
local PLOT_COLORS = {
	Color3.fromRGB(255, 99, 99),
	Color3.fromRGB(99, 160, 255),
	Color3.fromRGB(120, 220, 120),
	Color3.fromRGB(255, 200, 80),
	Color3.fromRGB(190, 120, 255),
	Color3.fromRGB(255, 150, 210),
	Color3.fromRGB(90, 220, 220),
	Color3.fromRGB(255, 150, 80),
}

-- Slots 1-8 = vordere zwei Reihen, 9-12 = hintere VIP-Reihe
local SLOT_OFFSETS = {}
for _, z in { -10, 4, 18 } do
	for _, x in { -24, -8, 8, 24 } do
		table.insert(SLOT_OFFSETS, Vector3.new(x, 0, z))
	end
end
assert(#SLOT_OFFSETS == Config.BaseSlots + Config.VipExtraSlots, "Slot layout does not match Config")

local function newPart(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		part.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Shape" then
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

local function anchorPart(parent: Instance, name: string, cf: CFrame): Part
	return newPart(parent, {
		Name = name,
		Size = Vector3.one,
		CFrame = cf,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
end

-- Billboard mit Groesse in Studs (skaliert mit der Entfernung)
local function billboard(parent: Instance, studs: Vector2, maxDistance: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(studs.X, studs.Y)
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Parent = parent
	return gui
end

local function textLabel(parent: Instance, text: string, color: Color3, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.Position = position
	label.Size = size
	label.Parent = parent
	return label
end

-- Server setzt nur "Active"; der Client entscheidet mit "Audience", wer den Prompt sieht.
local function makePrompt(parent: Instance, action: string, audience: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("Audience", audience)
	prompt:SetAttribute("Active", false)
	prompt.Parent = parent
	return prompt
end

local function buildPlot(index: number, cf: CFrame, parent: Instance)
	local W, D, H = MapService.PlotWidth, MapService.PlotDepth, MapService.WallHeight
	local color = PLOT_COLORS[index]

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("OwnerId", 0)

	newPart(model, {
		Name = "Floor",
		Size = Vector3.new(W, 0.4, D),
		CFrame = cf * CFrame.new(0, 0.2, 0),
		Color = color:Lerp(WHITE, 0.6),
	})

	local function wall(name: string, size: Vector3, offset: Vector3)
		newPart(model, { Name = name, Size = size, CFrame = cf * CFrame.new(offset), Color = color })
	end
	local segment = (W - GATE_WIDTH) / 2
	wall("BackWall", Vector3.new(W, H, 2), Vector3.new(0, H / 2, D / 2 - 1))
	wall("LeftWall", Vector3.new(2, H, D), Vector3.new(-W / 2 + 1, H / 2, 0))
	wall("RightWall", Vector3.new(2, H, D), Vector3.new(W / 2 - 1, H / 2, 0))
	wall("FrontLeft", Vector3.new(segment, H, 2), Vector3.new(-(GATE_WIDTH + segment) / 2, H / 2, -D / 2 + 1))
	wall("FrontRight", Vector3.new(segment, H, 2), Vector3.new((GATE_WIDTH + segment) / 2, H / 2, -D / 2 + 1))

	local gate = newPart(model, {
		Name = "Gate",
		Size = Vector3.new(GATE_WIDTH, H, 1),
		CFrame = cf * CFrame.new(0, H / 2, -D / 2 + 1),
		Color = Color3.fromRGB(255, 50, 60),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	local slotsFolder = Instance.new("Folder")
	slotsFolder.Name = "Slots"
	slotsFolder.Parent = model

	local slots = {}
	for i, offset in SLOT_OFFSETS do
		local isVip = i > Config.BaseSlots
		newPart(slotsFolder, {
			Name = "Pedestal" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 7.5, 7.5),
			CFrame = cf * CFrame.new(offset + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if isVip then Color3.fromRGB(255, 215, 90) else Color3.fromRGB(240, 240, 245),
		})
		local promptPart = anchorPart(slotsFolder, "Slot" .. i, cf * CFrame.new(offset + Vector3.new(0, 3, 0)))

		local vipGui = billboard(promptPart, Vector2.new(6, 1.6), 80)
		vipGui.Enabled = false
		textLabel(vipGui, "VIP SLOT", Color3.fromRGB(255, 215, 90), UDim2.new(), UDim2.fromScale(1, 1))

		slots[i] = {
			Index = i,
			CFrame = cf * CFrame.new(offset + Vector3.new(0, 1.2, 0)),
			StealPrompt = makePrompt(promptPart, "Steal", "Others", 1.5),
			SellPrompt = makePrompt(promptPart, "Sell", "Owner", 0.6),
			VipLabel = vipGui,
			Model = nil,
			StolenBy = nil,
		}
	end

	local lockButton = newPart(model, {
		Name = "LockButton",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 5, 5),
		CFrame = cf * CFrame.new(0, 0.6, D / 2 - 7) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 60, 60),
		Material = Enum.Material.Neon,
	})
	local lockPrompt = makePrompt(lockButton, "Lock Base", "Owner", 0)
	lockPrompt:SetAttribute("Active", true)

	local signPart = anchorPart(model, "Sign", cf * CFrame.new(0, H + 4, -D / 2 + 1))
	local signGui = billboard(signPart, Vector2.new(28, 7), 400)
	local title = textLabel(signGui, "Empty Base", WHITE, UDim2.new(), UDim2.fromScale(1, 0.62))
	local status = textLabel(signGui, "", Color3.fromRGB(255, 230, 120), UDim2.fromScale(0, 0.62), UDim2.fromScale(1, 0.38))

	model.Parent = parent

	return {
		Index = index,
		CFrame = cf,
		Model = model,
		Gate = gate,
		Slots = slots,
		LockPrompt = lockPrompt,
		SignTitle = title,
		SignStatus = status,
		SpawnCFrame = cf * CFrame.new(0, 3, 8),
	}
end

function MapService.Init()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	newPart(map, {
		Name = "Ground",
		Size = Vector3.new(440, 2, 260),
		CFrame = CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(106, 178, 86),
		Material = Enum.Material.Grass,
	})
	for _, info in {
		{ Vector3.new(0, 20, 131), Vector3.new(440, 40, 2) },
		{ Vector3.new(0, 20, -131), Vector3.new(440, 40, 2) },
		{ Vector3.new(221, 20, 0), Vector3.new(2, 40, 260) },
		{ Vector3.new(-221, 20, 0), Vector3.new(2, 40, 260) },
	} do
		newPart(map, { Name = "Boundary", Size = info[2], CFrame = CFrame.new(info[1]), Transparency = 1 })
	end

	-- Laufband
	local length = (MapService.ConveyorEnd - MapService.ConveyorStart).Magnitude + 8
	newPart(map, {
		Name = "Conveyor",
		Size = Vector3.new(length, 1, 14),
		CFrame = CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(45, 46, 54),
		Material = Enum.Material.DiamondPlate,
	})
	for _, z in { -7.4, 7.4 } do
		newPart(map, {
			Name = "Rail",
			Size = Vector3.new(length, 0.8, 0.8),
			CFrame = CFrame.new(0, 1.2, z),
			Color = Color3.fromRGB(255, 210, 60),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	for _, portal in {
		{ "SpawnPortal", MapService.ConveyorStart.X - 4, Color3.fromRGB(80, 170, 255) },
		{ "ExitPortal", MapService.ConveyorEnd.X + 4, Color3.fromRGB(255, 80, 80) },
	} do
		newPart(map, {
			Name = portal[1],
			Size = Vector3.new(3, 12, 16),
			CFrame = CFrame.new(portal[2], 6, 0),
			Color = portal[3],
			Material = Enum.Material.ForceField,
			CanCollide = false,
		})
	end

	local titlePart = anchorPart(map, "Title", CFrame.new(0, 26, 0))
	local titleGui = billboard(titlePart, Vector2.new(70, 12), 1000)
	textLabel(titleGui, string.upper(Config.GameName), Color3.fromRGB(255, 220, 70), UDim2.new(), UDim2.fromScale(1, 1))

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 22)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(240, 240, 245)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = map

	-- Basen: 4 noerdlich, 4 suedlich vom Laufband, Tor zeigt jeweils zum Band
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace
	local index = 0
	for _, side in { 1, -1 } do
		for _, x in { -126, -42, 42, 126 } do
			index += 1
			local center = Vector3.new(x, 0, side * (34 + MapService.PlotDepth / 2))
			local cf = CFrame.lookAt(center, center + Vector3.new(0, 0, -side))
			table.insert(MapService.Plots, buildPlot(index, cf, plotsFolder))
		end
	end

	local critters = Instance.new("Folder")
	critters.Name = "ConveyorCritters"
	critters.Parent = workspace
end

return MapService
