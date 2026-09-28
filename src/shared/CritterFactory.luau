-- Baut Critter-Modelle komplett aus Parts (keine Assets noetig).
-- Das Modell hat einen unsichtbaren "Root" (PrimaryPart) am Boden-Mittelpunkt;
-- alle anderen Parts sind daran geweldet und schauen nach -Z.
local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local CritterFactory = {}

local EYE_WHITE = Color3.fromRGB(255, 255, 255)
local DARK = Color3.fromRGB(25, 25, 30)
local GOLD = Color3.fromRGB(255, 205, 60)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- Zylinder-Achse (X) nach oben

local function newPart(shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Z-Position der Koerper-Vorderseite an lokaler Hoehe y (ab Koerper-Unterkante)
local function frontZ(shape: string, s: number, x: number, y: number): number
	if shape == "Ball" then
		local r = s / 2
		local dy = y - r
		return -math.sqrt(math.max(r * r - x * x - dy * dy, 0))
	elseif shape == "Cylinder" then
		local r = s * 0.45
		return -math.sqrt(math.max(r * r - x * x, 0))
	end
	return -(s * 0.8) / 2
end

export type BuildOptions = {
	Scale: number?,
	Label: string?, -- "Shop" (mit Preis) | "Base" | nil
}

function CritterFactory.Build(critterId: string, options: BuildOptions?): Model
	local opts = options or {}
	local def = Config.CritterById[critterId]
	assert(def, `Unknown critter "{critterId}"`)
	local rarity = Config.RarityByName[def.Rarity]
	local rarityIndex = Config.RarityIndex[def.Rarity]
	local s = def.Size * (opts.Scale or 1)

	local model = Instance.new("Model")
	model.Name = def.Name
	model:SetAttribute("CritterId", def.Id)

	local root = newPart(Enum.PartType.Block, Vector3.one, DARK)
	root.Name = "Root"
	root.Transparency = 1
	root.Anchored = true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local function add(part: BasePart, cf: CFrame): BasePart
		part.CFrame = cf
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end

	-- Koerper
	local lift = s * 0.12
	local height, bodySize, bodyRotation
	if def.Shape == "Ball" then
		height = s
		bodySize = Vector3.new(s, s, s)
		bodyRotation = CFrame.identity
	elseif def.Shape == "Cylinder" then
		height = s * 1.2
		bodySize = Vector3.new(height, s * 0.9, s * 0.9)
		bodyRotation = UPRIGHT
	else
		height = s * 0.9
		bodySize = Vector3.new(s, height, s * 0.8)
		bodyRotation = CFrame.identity
	end
	local bodyMaterial = if rarityIndex >= 7 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local body = add(
		newPart(Enum.PartType[def.Shape], bodySize, def.Color, bodyMaterial),
		CFrame.new(0, lift + height / 2, 0) * bodyRotation
	)
	body.Name = "Body"

	-- Fuesse
	local footColor = def.Color:Lerp(DARK, 0.45)
	for _, side in { -1, 1 } do
		add(newPart(Enum.PartType.Ball, Vector3.one * s * 0.32, footColor), CFrame.new(side * s * 0.22, s * 0.14, -s * 0.05))
	end

	-- Augen
	local eyeSize = s * 0.26
	local eyeY = height * 0.64
	for _, side in { -1, 1 } do
		local x = side * s * 0.2
		local z = frontZ(def.Shape, s, x, eyeY) + eyeSize * 0.25
		add(newPart(Enum.PartType.Ball, Vector3.one * eyeSize, EYE_WHITE), CFrame.new(x, lift + eyeY, z))
		add(newPart(Enum.PartType.Ball, Vector3.one * eyeSize * 0.5, DARK), CFrame.new(x, lift + eyeY, z - eyeSize * 0.32))
	end

	-- Mund
	local mouthY = height * 0.4
	add(
		newPart(Enum.PartType.Block, Vector3.new(s * 0.34, s * 0.08, s * 0.1), DARK),
		CFrame.new(0, lift + mouthY, frontZ(def.Shape, s, 0, mouthY) + s * 0.03)
	)

	-- Accessoires nach Seltenheit
	local top = lift + height - (if def.Shape == "Ball" then s * 0.05 else 0)
	if rarityIndex >= 5 then
		local radius = s * 0.28
		add(newPart(Enum.PartType.Cylinder, Vector3.new(s * 0.18, radius * 2, radius * 2), GOLD, Enum.Material.Metal), CFrame.new(0, top + s * 0.06, 0) * UPRIGHT)
		for i = 1, 5 do
			local angle = (i / 5) * math.pi * 2
			add(
				newPart(Enum.PartType.Block, Vector3.new(s * 0.1, s * 0.2, s * 0.1), GOLD, Enum.Material.Metal),
				CFrame.new(math.cos(angle) * radius * 0.85, top + s * 0.22, math.sin(angle) * radius * 0.85)
			)
		end
	elseif rarityIndex >= 3 then
		add(newPart(Enum.PartType.Cylinder, Vector3.new(s * 0.05, s * 0.7, s * 0.7), DARK), CFrame.new(0, top + s * 0.01, 0) * UPRIGHT)
		add(newPart(Enum.PartType.Cylinder, Vector3.new(s * 0.4, s * 0.42, s * 0.42), DARK), CFrame.new(0, top + s * 0.21, 0) * UPRIGHT)
		add(newPart(Enum.PartType.Cylinder, Vector3.new(s * 0.08, s * 0.44, s * 0.44), rarity.Color), CFrame.new(0, top + s * 0.08, 0) * UPRIGHT)
	end

	if rarityIndex >= 6 then
		local halo = add(
			newPart(Enum.PartType.Cylinder, Vector3.new(s * 0.06, s * 0.75, s * 0.75), rarity.Color, Enum.Material.Neon),
			CFrame.new(0, top + s * 0.55, 0) * UPRIGHT
		)
		halo.Transparency = 0.15
	end
	if rarityIndex >= 4 then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = s * 2.5
		light.Brightness = 2
		light.Parent = body
	end
	if rarityIndex >= 5 then
		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(rarity.Color)
		particles.LightEmission = 1
		particles.Size = NumberSequence.new(s * 0.12, 0)
		particles.Rate = 8
		particles.Lifetime = NumberRange.new(0.8, 1.4)
		particles.Speed = NumberRange.new(1, 2.5)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Parent = body
	end
	if rarityIndex >= 7 then
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = rarity.Color
		highlight.Parent = model
	end

	-- Anker fuer ProximityPrompts (Koerpermitte)
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Position = Vector3.new(0, lift + height / 2, 0)
	center.Parent = root

	if opts.Label then
		local isShop = opts.Label == "Shop"
		local gui = Instance.new("BillboardGui")
		gui.Name = "Label"
		gui.Size = UDim2.fromOffset(200, if isShop then 92 else 70)
		gui.StudsOffsetWorldSpace = Vector3.new(0, top + s * 0.9 + 1.5, 0)
		gui.MaxDistance = if isShop then 110 else 60
		gui.LightInfluence = 0
		gui.Parent = root

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		layout.Parent = gui

		local order = 0
		local function line(text: string, color: Color3, size: number)
			order += 1
			local label = Instance.new("TextLabel")
			label.LayoutOrder = order
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, 0, 0, size + 4)
			label.Font = Enum.Font.FredokaOne
			label.Text = text
			label.TextColor3 = color
			label.TextSize = size
			label.TextStrokeTransparency = 0
			label.Parent = gui
		end
		line(def.Rarity, rarity.Color, 16)
		line(def.Name, Color3.new(1, 1, 1), 20)
		if isShop then
			line(`${Util.FormatNumber(def.Price)}`, Color3.fromRGB(255, 220, 80), 20)
		end
		line(`${Util.FormatNumber(def.Income)}/s`, Color3.fromRGB(120, 255, 140), 18)
	end

	return model
end

return CritterFactory
