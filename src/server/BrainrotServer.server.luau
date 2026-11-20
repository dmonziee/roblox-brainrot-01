-- Brainrot Blast server: money ticks, the conveyor, buying, stealing,
-- base locks, rebirths and the tsunami wave. All player state lives in
-- one table here; the client only asks through RemoteEvents and shows
-- what the server tells it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotCatalog"))

-- Conveyor: brainrots enter at one end and stroll to the other.
local CONVEYOR_START = Vector3.new(-70, 3, 0)
local CONVEYOR_END = Vector3.new(70, 3, 0)
local CONVEYOR_SPEED = 6
local SPAWN_EVERY = 5
local MAX_ON_BELT = 8

-- Four base plots, one per player slot, each with six brainrot pads.
local BASE_CENTERS = {
	Vector3.new(-45, 0, -35),
	Vector3.new(45, 0, -35),
	Vector3.new(-45, 0, 35),
	Vector3.new(45, 0, 35),
}
local BASE_COLORS = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(90, 160, 255),
	Color3.fromRGB(90, 220, 120),
	Color3.fromRGB(255, 200, 60),
}
local SLOTS_PER_BASE = 6
local START_CASH = 100
local STEAL_RETURN_SECONDS = 10
local LOCK_SECONDS = 30
local LOCK_COOLDOWN = 60
local WAVE_EVERY = 90
local WAVE_WARNING = 10

local state = {} -- player -> { cash, rebirths, owned = {brainrot}, baseIndex, lockUntil, lockReadyAt, carrying }

local remotes = Instance.new("Folder")
remotes.Name = "BrainrotRemotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local buyRemote = makeRemote("BuyBrainrot")
local stealRemote = makeRemote("StealBrainrot")
local lockRemote = makeRemote("LockBase")
local rebirthRemote = makeRemote("Rebirth")
local dropRemote = makeRemote("DropCarried")
local cashRemote = makeRemote("CashUpdate")
local feedRemote = makeRemote("FeedMessage")
local waveRemote = makeRemote("WaveEvent")

local belt = {} -- live brainrots walking the conveyor
local waveActive = false
local waveEndsAt = 0

local function announce(text, color)
	feedRemote:FireAllClients(text, color)
end

local function baseSlots(center)
	local slots = {}
	for index = 1, SLOTS_PER_BASE do
		local row = math.floor((index - 1) / 3)
		local col = (index - 1) % 3
		slots[index] = center + Vector3.new((col - 1) * 8, 0, (row - 0.5) * 8)
	end
	return slots
end

local function earningsPerSecond(playerState)
	local total = 0
	for _, owned in ipairs(playerState.owned) do
		total += Catalog.earningsFor(owned.entry, owned.mutationMultiplier, playerState.rebirths)
	end
	return total
end

local function sendCash(player, playerState)
	cashRemote:FireClient(player, math.floor(playerState.cash), earningsPerSecond(playerState), #playerState.owned, playerState.rebirths)
end

local function findFreeSlot(playerState)
	for index, owned in ipairs(playerState.owned) do
		if owned.slot == nil then
			return index
		end
	end
	if #playerState.owned < SLOTS_PER_BASE then
		return #playerState.owned + 1
	end
	return nil
end

-- A brainrot on the belt or on a base: a chunky body, a head, eyes and a
-- floating label with its name, rarity and dollars per second.
local function buildBrainrotModel(entry, mutation, multiplier)
	local model = Instance.new("Model")
	model.Name = entry.name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3, 3.4, 3)
	body.Color = entry.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.2, 2.2, 2.2)
	head.Color = entry.color
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model

	for _, side in ipairs({ -0.55, 0.55 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.5, 0.6, 0.3)
		eye.Color = Color3.fromRGB(255, 255, 255)
		eye.Material = Enum.Material.SmoothPlastic
		eye.Anchored = true
		eye.CanCollide = false
		eye.Parent = model
	end

	if mutation == "Gold" then
		body.Material = Enum.Material.Metal
		head.Material = Enum.Material.Metal
		body.Color = Color3.fromRGB(255, 215, 0)
		head.Color = Color3.fromRGB(255, 215, 0)
	elseif mutation == "Diamond" then
		body.Material = Enum.Material.Glass
		head.Material = Enum.Material.Glass
		body.Color = Color3.fromRGB(140, 220, 255)
		head.Color = Color3.fromRGB(140, 220, 255)
	elseif mutation == "Rainbow" then
		body.Material = Enum.Material.Neon
		head.Material = Enum.Material.Neon
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "BrainrotTag"
	tag.Size = UDim2.fromOffset(140, 64)
	tag.StudsOffset = Vector3.new(0, 3.4, 0)
	tag.AlwaysOnTop = true
	tag.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 0.4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = entry.name
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Parent = tag

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Position = UDim2.fromScale(0, 0.4)
	rarityLabel.Size = UDim2.fromScale(1, 0.3)
	rarityLabel.BackgroundTransparency = 1
	local mutationText = mutation ~= "None" and (" " .. mutation) or ""
	rarityLabel.Text = entry.rarity .. mutationText
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextColor3 = Catalog.rarityColor(entry.rarity)
	rarityLabel.TextStrokeTransparency = 0.4
	rarityLabel.Parent = tag

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashLabel"
	cashLabel.Position = UDim2.fromScale(0, 0.7)
	cashLabel.Size = UDim2.fromScale(1, 0.3)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Text = "$" .. tostring(entry.cashPerSecond * multiplier) .. "/s"
	cashLabel.TextScaled = true
	cashLabel.Font = Enum.Font.GothamBold
	cashLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	cashLabel.TextStrokeTransparency = 0.4
	cashLabel.Parent = tag

	return model
end

local function placeModel(model, position)
	local body = model:FindFirstChild("Body")
	local head = model:FindFirstChild("Head")
	local eyeLeft = model:FindFirstChild("Eye")
	if body then
		body.Position = position + Vector3.new(0, 1.7, 0)
	end
	if head then
		head.Position = position + Vector3.new(0, 4.2, 0)
	end
	local eyeIndex = 0
	for _, child in ipairs(model:GetChildren()) do
		if child.Name == "Eye" then
			eyeIndex += 1
			local side = eyeIndex == 1 and -0.55 or 0.55
			child.Position = position + Vector3.new(side, 4.4, 1.05)
		end
	end
end

local function spawnOnBelt()
	if #belt >= MAX_ON_BELT then
		return
	end
	local entry = Catalog.pickRandom()
	local mutation, multiplier = Catalog.rollMutation()
	local model = buildBrainrotModel(entry, mutation, multiplier)
	model.Parent = workspace
	placeModel(model, CONVEYOR_START)
	local brainrot = {
		entry = entry,
		mutation = mutation,
		multiplier = multiplier,
		model = model,
		position = CONVEYOR_START,
		price = Catalog.priceFor(entry, multiplier),
	}
	table.insert(belt, brainrot)
end

local function nearestOnBelt(player)
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestDistance = nil, 12
	for _, brainrot in ipairs(belt) do
		local distance = (brainrot.position - root.Position).Magnitude
		if distance < bestDistance then
			best, bestDistance = brainrot, distance
		end
	end
	return best
end

buyRemote.OnServerEvent:Connect(function(player)
	local playerState = state[player]
	if not playerState then
		return
	end
	local brainrot = nearestOnBelt(player)
	if not brainrot then
		return
	end
	if playerState.cash < brainrot.price then
		announce(player.Name .. " needs $" .. tostring(brainrot.price) .. " for " .. brainrot.entry.name .. "!", Color3.fromRGB(255, 120, 120))
		return
	end
	local slot = findFreeSlot(playerState)
	if not slot then
		announce(player.Name .. "'s base is full! Rebirth or steal smarter.", Color3.fromRGB(255, 200, 80))
		return
	end
	playerState.cash -= brainrot.price
	for index, other in ipairs(belt) do
		if other == brainrot then
			table.remove(belt, index)
			break
		end
	end
	local slots = baseSlots(BASE_CENTERS[playerState.baseIndex])
	local owned = {
		entry = brainrot.entry,
		mutation = brainrot.mutation,
		multiplier = brainrot.multiplier,
		model = brainrot.model,
		slot = slot,
		position = slots[slot],
	}
	placeModel(owned.model, owned.position)
	playerState.owned[slot] = owned
	sendCash(player, playerState)
	announce(player.Name .. " bought " .. brainrot.entry.name .. " for $" .. tostring(brainrot.price) .. "!", Color3.fromRGB(120, 255, 120))
end)

-- Stealing: grab a brainrot off someone else's base and carry it home.
-- A locked base cannot be stolen from, and the thief has 10 seconds to
-- reach their own base before the brainrot snaps back.
stealRemote.OnServerEvent:Connect(function(player, targetPlayer, slotIndex)
	local thief = state[player]
	local victim = state[targetPlayer]
	if not thief or not victim or player == targetPlayer then
		return
	end
	if thief.carrying then
		return
	end
	if os.clock() < victim.lockUntil then
		announce(targetPlayer.Name .. "'s base is LOCKED!", Color3.fromRGB(255, 200, 80))
		return
	end
	local owned = victim.owned[slotIndex]
	if not owned then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or (owned.position - root.Position).Magnitude > 12 then
		return
	end
	victim.owned[slotIndex] = nil
	thief.carrying = { owned = owned, fromPlayer = targetPlayer, deadline = os.clock() + STEAL_RETURN_SECONDS }
	owned.model.Parent = workspace
	announce(player.Name .. " stole " .. owned.entry.name .. " from " .. targetPlayer.Name .. "! Run home!", Color3.fromRGB(255, 120, 120))
end)

dropRemote.OnServerEvent:Connect(function(player)
	local playerState = state[player]
	if not playerState or not playerState.carrying then
		return
	end
	local carried = playerState.carrying
	playerState.carrying = nil
	local victim = state[carried.fromPlayer]
	if victim then
		victim.owned[carried.owned.slot] = carried.owned
		placeModel(carried.owned.model, carried.owned.position)
	end
end)

lockRemote.OnServerEvent:Connect(function(player)
	local playerState = state[player]
	if not playerState then
		return
	end
	local now = os.clock()
	if now < playerState.lockReadyAt then
		return
	end
	playerState.lockUntil = now + LOCK_SECONDS
	playerState.lockReadyAt = now + LOCK_SECONDS + LOCK_COOLDOWN
	announce(player.Name .. " locked their base for " .. tostring(LOCK_SECONDS) .. "s!", Color3.fromRGB(120, 200, 255))
end)

rebirthRemote.OnServerEvent:Connect(function(player)
	local playerState = state[player]
	if not playerState then
		return
	end
	if playerState.cash < Catalog.REBIRTH_COST then
		announce(player.Name .. " needs $" .. tostring(Catalog.REBIRTH_COST) .. " to rebirth!", Color3.fromRGB(255, 120, 120))
		return
	end
	for _, owned in ipairs(playerState.owned) do
		if owned.model then
			owned.model:Destroy()
		end
	end
	playerState.owned = {}
	playerState.cash = START_CASH
	playerState.rebirths += 1
	sendCash(player, playerState)
	announce(player.Name .. " REBIRTHED! +" .. tostring(math.floor(Catalog.REBIRTH_BONUS * 100)) .. "% earnings forever!", Color3.fromRGB(255, 215, 0))
end)

local function knockBack(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.AssemblyLinearVelocity = Vector3.new(0, 40, 0) + (root.Position - Vector3.new(0, 0, 0)).Unit * 30
end

local function runWave()
	waveActive = true
	waveEndsAt = os.clock() + 8
	waveRemote:FireAllClients("wave", WAVE_WARNING)
	announce("TSUNAMI INCOMING! Get back to your base!", Color3.fromRGB(120, 200, 255))
	task.wait(WAVE_WARNING)
	waveRemote:FireAllClients("hit", 0)
	for _, player in ipairs(Players:GetPlayers()) do
		local playerState = state[player]
		if not playerState then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		local center = BASE_CENTERS[playerState.baseIndex]
		local home = (root.Position - center).Magnitude < 22
		if not home then
			knockBack(character)
			if playerState.carrying then
				local carried = playerState.carrying
				playerState.carrying = nil
				local victim = state[carried.fromPlayer]
				if victim then
					victim.owned[carried.owned.slot] = carried.owned
					placeModel(carried.owned.model, carried.owned.position)
				end
				announce(player.Name .. " got swept away and dropped the stolen brainrot!", Color3.fromRGB(120, 200, 255))
			end
		end
	end
	task.wait(8)
	waveActive = false
	waveRemote:FireAllClients("clear", 0)
end

Players.PlayerAdded:Connect(function(player)
	local taken = {}
	for _, playerState in pairs(state) do
		taken[playerState.baseIndex] = true
	end
	local baseIndex = 1
	for index = 1, #BASE_CENTERS do
		if not taken[index] then
			baseIndex = index
			break
		end
	end
	state[player] = {
		cash = START_CASH,
		rebirths = 0,
		owned = {},
		baseIndex = baseIndex,
		lockUntil = 0,
		lockReadyAt = 0,
		carrying = nil,
	}
	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(BASE_CENTERS[baseIndex] + Vector3.new(0, 5, 12))
		end
	end)
	sendCash(player, state[player])
	announce(player.Name .. " joined Brainrot Blast!", Color3.fromRGB(200, 220, 255))
end)

Players.PlayerRemoving:Connect(function(player)
	local playerState = state[player]
	if playerState then
		for _, owned in ipairs(playerState.owned) do
			if owned.model then
				owned.model:Destroy()
			end
		end
	end
	state[player] = nil
end)

-- Money ticks once a second; the belt strolls forward every frame.
local lastTick = os.clock()
local lastSpawn = os.clock()
local nextWaveAt = os.clock() + WAVE_EVERY

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastTick >= 1 then
		lastTick = now
		for player, playerState in pairs(state) do
			playerState.cash += earningsPerSecond(playerState)
			sendCash(player, playerState)
			-- A thief who reaches home in time keeps the catch.
			if playerState.carrying then
				local carried = playerState.carrying
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local home = root and (root.Position - BASE_CENTERS[playerState.baseIndex]).Magnitude < 22
				if home then
					local slot = findFreeSlot(playerState)
					if slot then
						local slots = baseSlots(BASE_CENTERS[playerState.baseIndex])
						carried.owned.slot = slot
						carried.owned.position = slots[slot]
						placeModel(carried.owned.model, carried.owned.position)
						playerState.owned[slot] = carried.owned
						playerState.carrying = nil
						announce(player.Name .. " got away with " .. carried.owned.entry.name .. "!", Color3.fromRGB(255, 120, 120))
					end
				elseif now > carried.deadline then
					playerState.carrying = nil
					local victim = state[carried.fromPlayer]
					if victim then
						victim.owned[carried.owned.slot] = carried.owned
						placeModel(carried.owned.model, carried.owned.position)
					end
					announce(player.Name .. " was too slow — " .. carried.owned.entry.name .. " ran home!", Color3.fromRGB(255, 200, 80))
				end
			end
		end
	end
	if now - lastSpawn >= SPAWN_EVERY then
		lastSpawn = now
		spawnOnBelt()
	end
	if now >= nextWaveAt and not waveActive then
		nextWaveAt = now + WAVE_EVERY
		task.spawn(runWave)
	end
	for index = #belt, 1, -1 do
		local brainrot = belt[index]
		brainrot.position += Vector3.new(CONVEYOR_SPEED * 0.05, 0, 0)
		placeModel(brainrot.model, brainrot.position)
		if brainrot.position.X >= CONVEYOR_END.X then
			brainrot.model:Destroy()
			table.remove(belt, index)
		end
end)

-- Carried models ride with their thief: updated on a separate loop so
-- the belt loop stays simple.
task.spawn(function()
	while true do
		task.wait(0.1)
		for player, playerState in pairs(state) do
			if playerState.carrying then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					placeModel(playerState.carrying.owned.model, root.Position + Vector3.new(0, 2, 0))
				end
			end
		end
	end
end)

spawnOnBelt()
spawnOnBelt()
