-- HUD, Robux-Shop, Odds-Anzeige, Benachrichtigungen und Prompt-Sichtbarkeit.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local COLORS = {
	Panel = Color3.fromRGB(30, 32, 44),
	PanelLight = Color3.fromRGB(46, 49, 66),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(180, 185, 205),
	Cash = Color3.fromRGB(120, 255, 140),
	Robux = Color3.fromRGB(60, 185, 90),
	Gold = Color3.fromRGB(255, 205, 70),
	Danger = Color3.fromRGB(255, 80, 90),
	Luck = Color3.fromRGB(90, 230, 120),
	Owned = Color3.fromRGB(95, 98, 115),
}

--------------------------------------------------------------------------------
-- UI-Helfer
--------------------------------------------------------------------------------

local function create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius: number)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function outline(thickness: number)
	return create("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function label(props: { [string]: any }): TextLabel
	local merged = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = COLORS.Text,
		TextStrokeTransparency = 0.5,
		TextSize = 18,
	}
	for key, value in props do
		merged[key] = value
	end
	return create("TextLabel", merged)
end

local gui = create("ScreenGui", {
	Name = "CritterHUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

--------------------------------------------------------------------------------
-- Benachrichtigungen
--------------------------------------------------------------------------------

local toastHolder = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -120),
	Size = UDim2.new(0.9, 0, 0, 260),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	create("UISizeConstraint", { MaxSize = Vector2.new(520, 260) }),
	create("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local toastCounter = 0
local function toast(text: string, color: Color3?)
	toastCounter += 1
	local item = label({
		LayoutOrder = toastCounter,
		Text = text,
		TextColor3 = color or COLORS.Text,
		TextSize = 19,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.15,
		Parent = toastHolder,
	})
	corner(10).Parent = item
	create("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = item,
	})

	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 5 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end

	task.delay(4, function()
		if not item.Parent then
			return
		end
		TweenService:Create(item, TweenInfo.new(0.5), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
		task.wait(0.5)
		item:Destroy()
	end)
end

Remotes.Notify.OnClientEvent:Connect(toast)

--------------------------------------------------------------------------------
-- Cash-Anzeige + Luck-Banner
--------------------------------------------------------------------------------

local cashFrame = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(250, 62),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.15,
	Parent = gui,
}, { corner(14), outline(2) })
local cashLabel = label({
	Text = "$0",
	TextSize = 30,
	TextColor3 = COLORS.Cash,
	Position = UDim2.fromOffset(0, 4),
	Size = UDim2.new(1, 0, 0, 34),
	Parent = cashFrame,
})
local incomeLabel = label({
	Text = "+$0/s",
	TextSize = 18,
	TextColor3 = COLORS.Muted,
	Position = UDim2.fromOffset(0, 36),
	Size = UDim2.new(1, 0, 0, 20),
	Parent = cashFrame,
})

local luckBanner = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 74),
	Size = UDim2.fromOffset(250, 32),
	BackgroundColor3 = COLORS.Luck,
	Font = FONT,
	TextSize = 19,
	TextColor3 = COLORS.Text,
	TextStrokeTransparency = 0.4,
	Text = "",
	Visible = false,
	Parent = gui,
}, { corner(10), outline(2) })

--------------------------------------------------------------------------------
-- Seitenleiste
--------------------------------------------------------------------------------

local sideBar = create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(88, 290),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function sideButton(order: number, icon: string, text: string, color: Color3)
	local button = create("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(88, 88),
		BackgroundColor3 = color,
		Text = "",
		Parent = sideBar,
	}, { corner(18), outline(3) })
	local iconLabel = label({ Text = icon, TextSize = 34, Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 6), Parent = button })
	local caption = label({ Text = text, TextSize = 17, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 56), Parent = button })
	return button, iconLabel, caption
end

local shopButton = sideButton(1, "🛒", "SHOP", Color3.fromRGB(60, 190, 90))
local lockButton, lockIcon, lockCaption = sideButton(2, "🔒", "LOCK", Color3.fromRGB(220, 70, 80))
local oddsButton = sideButton(3, "🎲", "ODDS", Color3.fromRGB(80, 130, 230))

--------------------------------------------------------------------------------
-- Fenster
--------------------------------------------------------------------------------

local windows = {}

local function window(title: string)
	local frame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.78),
		BackgroundColor3 = COLORS.Panel,
		Visible = false,
		Parent = gui,
	}, {
		corner(18),
		outline(3),
		create("UISizeConstraint", { MaxSize = Vector2.new(560, 470) }),
	})
	label({
		Text = title,
		TextSize = 30,
		TextColor3 = COLORS.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(20, 6),
		Size = UDim2.new(1, -80, 0, 50),
		Parent = frame,
	})
	local close = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = COLORS.Danger,
		Font = FONT,
		Text = "X",
		TextSize = 22,
		TextColor3 = COLORS.Text,
		Parent = frame,
	}, { corner(10), outline(2) })
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.new(1, -28, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = frame,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	table.insert(windows, frame)
	return frame, list
end

local function toggleWindow(frame: Frame)
	local open = not frame.Visible
	for _, other in windows do
		other.Visible = false
	end
	frame.Visible = open
end

--------------------------------------------------------------------------------
-- Shop
--------------------------------------------------------------------------------

local shopFrame, shopList = window("SHOP")
local rowOrder = 0
local function nextOrder(): number
	rowOrder += 1
	return rowOrder
end

local function sectionHeader(parent: Instance, text: string)
	label({
		LayoutOrder = nextOrder(),
		Text = text,
		TextSize = 20,
		TextColor3 = COLORS.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = parent,
	})
end

local function shopEntry(parent: Instance, name: string, description: string, onBuy: () -> ())
	local row = create("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -8, 0, 74),
		BackgroundColor3 = COLORS.PanelLight,
		Parent = parent,
	}, { corner(12) })
	label({
		Text = name,
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -150, 0, 26),
		Parent = row,
	})
	local descriptionLabel = label({
		Text = description,
		TextSize = 15,
		TextColor3 = COLORS.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.new(1, -150, 0, 34),
		Parent = row,
	})
	local buy = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(118, 46),
		BackgroundColor3 = COLORS.Robux,
		Font = FONT,
		TextSize = 20,
		TextColor3 = COLORS.Text,
		TextStrokeTransparency = 0.5,
		Text = "",
		Parent = row,
	}, { corner(12), outline(2) })
	buy.Activated:Connect(onBuy)
	return buy, descriptionLabel
end

local function purchase(kind: string, item)
	if item.Id == 0 then
		if RunService:IsStudio() then
			Remotes.DevGrant:FireServer(kind, item.Key)
			toast(`[Studio test] {item.Name} granted (no Robux charged)`, COLORS.Muted)
		else
			toast("Not available yet!", COLORS.Danger)
		end
		return
	end
	if kind == "Pass" then
		MarketplaceService:PromptGamePassPurchase(player, item.Id)
	else
		MarketplaceService:PromptProductPurchase(player, item.Id)
	end
end

local function fetchPrice(id: number, infoType: Enum.InfoType, callback: (number) -> ())
	if id == 0 then
		return
	end
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and info and info.PriceInRobux then
			callback(info.PriceInRobux)
		end
	end)
end

sectionHeader(shopList, "GAME PASSES (forever)")
for _, pass in Config.GamePasses do
	local attribute = "Pass_" .. pass.Key
	local price = pass.Price
	local button
	local function refresh()
		if player:GetAttribute(attribute) then
			button.Text = "OWNED"
			button.BackgroundColor3 = COLORS.Owned
		else
			button.Text = `R$ {price}`
		end
	end
	button = shopEntry(shopList, pass.Name, pass.Description, function()
		if not player:GetAttribute(attribute) then
			purchase("Pass", pass)
		end
	end)
	fetchPrice(pass.Id, Enum.InfoType.GamePass, function(robux)
		price = robux
		refresh()
	end)
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
	refresh()
end

sectionHeader(shopList, "BOOSTS & CASH")
local cashRows = {}
for _, product in Config.Products do
	local button, descriptionLabel = shopEntry(shopList, product.Name, product.Description or "", function()
		purchase("Product", product)
	end)
	button.Text = `R$ {product.Price}`
	fetchPrice(product.Id, Enum.InfoType.Product, function(robux)
		button.Text = `R$ {robux}`
	end)
	if product.Kind == "Cash" then
		table.insert(cashRows, { Product = product, Label = descriptionLabel })
	end
end

local function updateCashRows()
	local income = player:GetAttribute("Income") or 0
	for _, row in cashRows do
		local amount = math.max(row.Product.Minimum, income * row.Product.Minutes * 60)
		row.Label.Text = `+${Util.FormatNumber(amount)} cash ({row.Product.Minutes} min of your income)`
	end
end

--------------------------------------------------------------------------------
-- Odds (Roblox verlangt offene Wahrscheinlichkeiten bei Zufallsmechaniken)
--------------------------------------------------------------------------------

local oddsFrame, oddsList = window("SPAWN ODDS")

local function formatPercent(fraction: number): string
	local percent = fraction * 100
	return if percent >= 1 then string.format("%.1f%%", percent) else string.format("%.2f%%", percent)
end

do
	local normal, normalTotal = Config.GetRarityWeights(false)
	local lucky, luckyTotal = Config.GetRarityWeights(true)

	local header = create("Frame", { LayoutOrder = 0, Size = UDim2.new(1, -8, 0, 26), BackgroundTransparency = 1, Parent = oddsList })
	label({ Text = "Rarity", TextColor3 = COLORS.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.4, 0, 1, 0), Parent = header })
	label({ Text = "Normal", TextColor3 = COLORS.Muted, Position = UDim2.fromScale(0.4, 0), Size = UDim2.fromScale(0.28, 1), Parent = header })
	label({ Text = "Server Luck", TextColor3 = COLORS.Luck, Position = UDim2.fromScale(0.68, 0), Size = UDim2.fromScale(0.3, 1), Parent = header })

	for index, rarity in Config.Rarities do
		local row = create("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, 40),
			BackgroundColor3 = COLORS.PanelLight,
			Parent = oddsList,
		}, { corner(10) })
		label({ Text = rarity.Name, TextSize = 20, TextColor3 = rarity.Color, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.4, 0, 1, 0), Parent = row })
		label({ Text = formatPercent(normal[rarity.Name] / normalTotal), Position = UDim2.fromScale(0.4, 0), Size = UDim2.fromScale(0.28, 1), Parent = row })
		label({ Text = formatPercent(lucky[rarity.Name] / luckyTotal), TextColor3 = COLORS.Luck, Position = UDim2.fromScale(0.68, 0), Size = UDim2.fromScale(0.3, 1), Parent = row })
	end

	label({
		LayoutOrder = 100,
		Text = "Chance for a critter of each rarity to appear on the conveyor. All critters of the same rarity are equally likely. Critters are always bought with in-game cash.",
		TextSize = 14,
		TextColor3 = COLORS.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -8, 0, 54),
		Parent = oddsList,
	})
end

--------------------------------------------------------------------------------
-- Buttons + Live-Werte
--------------------------------------------------------------------------------

shopButton.Activated:Connect(function()
	toggleWindow(shopFrame)
end)
oddsButton.Activated:Connect(function()
	toggleWindow(oddsFrame)
end)
luckBanner.Activated:Connect(function()
	toggleWindow(oddsFrame)
end)
lockButton.Activated:Connect(function()
	Remotes.RequestLock:FireServer()
end)

local function updateCash()
	cashLabel.Text = "$" .. Util.FormatNumber(player:GetAttribute("Cash") or 0)
	incomeLabel.Text = `+${Util.FormatNumber(player:GetAttribute("Income") or 0)}/s`
	updateCashRows()
end
player:GetAttributeChangedSignal("Cash"):Connect(updateCash)
player:GetAttributeChangedSignal("Income"):Connect(updateCash)
updateCash()

task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()

		local lockEnds = player:GetAttribute("LockEndsAt") or 0
		local lockReady = player:GetAttribute("LockReadyAt") or 0
		if now < lockEnds then
			lockIcon.Text = "🔒"
			lockCaption.Text = `{math.ceil(lockEnds - now)}s`
		elseif now < lockReady then
			lockIcon.Text = "⏳"
			lockCaption.Text = `{math.ceil(lockReady - now)}s`
		else
			lockIcon.Text = "🔓"
			lockCaption.Text = "LOCK"
		end

		local luckEnds = workspace:GetAttribute("LuckEndsAt") or 0
		luckBanner.Visible = now < luckEnds
		if luckBanner.Visible then
			luckBanner.Text = `🍀 SERVER LUCK  {Util.FormatTime(luckEnds - now)}`
		end

		task.wait(0.2)
	end
end)

--------------------------------------------------------------------------------
-- Prompts & Tore: Besitzer sieht "Sell", andere sehen "Steal".
-- Das eigene Tor ist lokal immer durchlaessig (Charakter-Physik laeuft beim Client).
--------------------------------------------------------------------------------

local plotsFolder = workspace:WaitForChild("Plots")

local function getPlotModel(instance: Instance): Instance?
	local current = instance.Parent
	while current and current ~= plotsFolder do
		if current:GetAttribute("OwnerId") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function refreshPrompt(prompt: ProximityPrompt)
	local audience = prompt:GetAttribute("Audience")
	if not audience then
		return
	end
	local plot = getPlotModel(prompt)
	local ownerId = if plot then plot:GetAttribute("OwnerId") else 0
	local isOwner = ownerId == player.UserId
	local active = prompt:GetAttribute("Active") == true
	if audience == "Owner" then
		prompt.Enabled = active and isOwner
	else
		prompt.Enabled = active and ownerId ~= 0 and not isOwner
	end
end

local function refreshGate(plot: Instance)
	local gate = plot:FindFirstChild("Gate")
	if gate and plot:GetAttribute("OwnerId") == player.UserId then
		gate.CanCollide = false
	end
end

local function watchPrompt(prompt: ProximityPrompt)
	refreshPrompt(prompt)
	prompt.AttributeChanged:Connect(function()
		refreshPrompt(prompt)
	end)
end

local function watchPlot(plot: Instance)
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			watchPrompt(descendant)
		end
	end
	plot.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			watchPrompt(descendant)
		end
	end)
	plot:GetAttributeChangedSignal("OwnerId"):Connect(function()
		for _, descendant in plot:GetDescendants() do
			if descendant:IsA("ProximityPrompt") then
				refreshPrompt(descendant)
			end
		end
		refreshGate(plot)
	end)
	local gate = plot:WaitForChild("Gate", 10)
	if gate then
		gate:GetPropertyChangedSignal("CanCollide"):Connect(function()
			refreshGate(plot)
		end)
		refreshGate(plot)
	end
end

for _, plot in plotsFolder:GetChildren() do
	task.spawn(watchPlot, plot)
end
plotsFolder.ChildAdded:Connect(watchPlot)

--------------------------------------------------------------------------------
-- Slap-Knockback
--------------------------------------------------------------------------------

Remotes.Knockback.OnClientEvent:Connect(function(velocity: Vector3)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		return
	end
	humanoid.PlatformStand = true
	rootPart.AssemblyLinearVelocity = velocity
	task.delay(0.8, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
end)

task.delay(3, function()
	toast("Welcome! Buy critters on the conveyor - they earn you cash every second.", COLORS.Gold)
	task.wait(1.5)
	toast("Steal critters from other bases, slap thieves, and LOCK your base!", COLORS.Text)
end)
