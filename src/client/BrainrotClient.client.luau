-- Brainrot Blast client: builds the HUD, the buy prompt, the Lock and
-- Rebirth buttons, the wave warning and the event feed. It never trusts
-- its own numbers: cash and earnings arrive from the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local buyRemote = remotes:WaitForChild("BuyBrainrot")
local stealRemote = remotes:WaitForChild("StealBrainrot")
local lockRemote = remotes:WaitForChild("LockBase")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local cashRemote = remotes:WaitForChild("CashUpdate")
local feedRemote = remotes:WaitForChild("FeedMessage")
local waveRemote = remotes:WaitForChild("WaveEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(name, parent, position, size, text, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = parent
	return label
end

local function makeButton(name, parent, position, size, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Text = text
	button.TextSize = 18
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	return button
end

-- Top bar, kept right of the Roblox menu buttons in the top-left corner.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 12)
topBar.Size = UDim2.new(0, 560, 0, 64)
topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
topBar.BackgroundTransparency = 0.25
topBar.BorderSizePixel = 0
topBar.Parent = gui

local cashLabel = makeLabel("CashLabel", topBar, UDim2.new(0, 16, 0, 6), UDim2.new(0, 260, 0, 30), "$100", 26, Color3.fromRGB(120, 255, 120))
local rateLabel = makeLabel("RateLabel", topBar, UDim2.new(0, 16, 0, 36), UDim2.new(0, 260, 0, 22), "$0/s  •  0 brainrots", 16, Color3.fromRGB(220, 220, 255))
local rebirthLabel = makeLabel("RebirthLabel", topBar, UDim2.new(0, 290, 0, 6), UDim2.new(0, 250, 0, 30), "Rebirths: 0", 20, Color3.fromRGB(255, 215, 0))
local waveLabel = makeLabel("WaveLabel", topBar, UDim2.new(0, 290, 0, 36), UDim2.new(0, 250, 0, 22), "Next wave: ~90s", 16, Color3.fromRGB(140, 210, 255))

-- Buttons along the bottom: buy, lock the base, rebirth.
local buyButton = makeButton("BuyButton", gui, UDim2.new(0.5, -260, 1, -84), UDim2.new(0, 160, 0, 56), "BUY  [E]", Color3.fromRGB(40, 180, 80))
local lockButton = makeButton("LockButton", gui, UDim2.new(0.5, -80, 1, -84), UDim2.new(0, 160, 0, 56), "LOCK BASE", Color3.fromRGB(60, 110, 220))
local rebirthButton = makeButton("RebirthButton", gui, UDim2.new(0.5, 100, 1, -84), UDim2.new(0, 160, 0, 56), "REBIRTH $100K", Color3.fromRGB(200, 140, 20))

-- Big centre warning when the tsunami is coming.
local warningLabel = makeLabel("WaveWarning", gui, UDim2.new(0.5, -300, 0, 100), UDim2.new(0, 600, 0, 60), "", 34, Color3.fromRGB(255, 80, 80))
warningLabel.Visible = false

-- Event feed down the right side.
local feedFrame = Instance.new("Frame")
feedFrame.Name = "Feed"
feedFrame.AnchorPoint = Vector2.new(1, 0)
feedFrame.Position = UDim2.new(1, -12, 0, 92)
feedFrame.Size = UDim2.new(0, 300, 0, 220)
feedFrame.BackgroundTransparency = 1
feedFrame.Parent = gui

local feedLines = {}
local function addFeedLine(text, color)
	local line = Instance.new("TextLabel")
	line.Size = UDim2.new(1, 0, 0, 24)
	line.BackgroundTransparency = 1
	line.Text = text
	line.TextSize = 15
	line.Font = Enum.Font.GothamBold
	line.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	line.TextStrokeTransparency = 0.3
	line.TextXAlignment = Enum.TextXAlignment.Right
	line.Parent = feedFrame
	table.insert(feedLines, 1, line)
	for index, other in ipairs(feedLines) do
		other.Position = UDim2.new(0, 0, 0, (index - 1) * 26)
	end
	if #feedLines > 8 then
		feedLines[9]:Destroy()
		table.remove(feedLines, 9)
	end
end

local function formatCash(amount)
	if amount >= 1000000 then
		return "$" .. string.format("%.2fM", amount / 1000000)
	elseif amount >= 1000 then
		return "$" .. string.format("%.1fK", amount / 1000)
	end
	return "$" .. tostring(math.floor(amount))
end

cashRemote.OnClientEvent:Connect(function(cash, perSecond, ownedCount, rebirths)
	cashLabel.Text = formatCash(cash)
	rateLabel.Text = formatCash(perSecond) .. "/s  •  " .. tostring(ownedCount) .. " brainrots"
	rebirthLabel.Text = "Rebirths: " .. tostring(rebirths) .. "  (+" .. tostring(rebirths * 25) .. "% earnings)"
end)

feedRemote.OnClientEvent:Connect(function(text, color)
	addFeedLine(text, color)
end)

local waveCountdown = 90
waveRemote.OnClientEvent:Connect(function(kind, seconds)
	if kind == "wave" then
		warningLabel.Text = "🌊 TSUNAMI IN " .. tostring(seconds) .. "s — RUN HOME!"
		warningLabel.Visible = true
		waveCountdown = 90
	elseif kind == "hit" then
		warningLabel.Text = "🌊 TSUNAMI! HOLD ON!"
	elseif kind == "clear" then
		warningLabel.Visible = false
		waveLabel.Text = "Next wave: ~90s"
	end
end)

buyButton.MouseButton1Click:Connect(function()
	buyRemote:FireServer()
end)

lockButton.MouseButton1Click:Connect(function()
	lockRemote:FireServer()
	addFeedLine("Base lock requested…", Color3.fromRGB(140, 210, 255))
end)

rebirthButton.MouseButton1Click:Connect(function()
	rebirthRemote:FireServer()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		buyRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.L then
		lockRemote:FireServer()
	end
end)

-- The wave timer ticks down locally between server warnings.
task.spawn(function()
	while true do
		task.wait(1)
		if not warningLabel.Visible then
			waveCountdown = math.max(0, waveCountdown - 1)
			waveLabel.Text = "Next wave: ~" .. tostring(waveCountdown) .. "s"
		end
	end
end)

addFeedLine("Welcome to Brainrot Blast!", Color3.fromRGB(120, 255, 120))
addFeedLine("Walk to the conveyor, press E to buy.", Color3.fromRGB(255, 255, 255))
addFeedLine("Steal from rivals — but watch for the wave!", Color3.fromRGB(255, 200, 80))
