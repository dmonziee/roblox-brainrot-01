-- Brainrot Blast: the cast of collectable brainrots, their rarities,
-- earnings and mutations. One table drives the server spawner, the
-- client labels and the rebirth maths, so a balance tweak lands here.

local BrainrotCatalog = {}

BrainrotCatalog.REBIRTH_COST = 100000
BrainrotCatalog.REBIRTH_BONUS = 0.25

-- Rarity ladder, cheapest first. Price is what a brainrot costs on the
-- conveyor; cashPerSecond is what it pays once it stands on a base.
BrainrotCatalog.CAST = {
	{ name = "Noobini Pizzanini", rarity = "Common", cashPerSecond = 5, price = 50, color = Color3.fromRGB(120, 200, 90) },
	{ name = "Chimpanzini Bananini", rarity = "Common", cashPerSecond = 12, price = 120, color = Color3.fromRGB(240, 210, 60) },
	{ name = "Tung Tung Sahur", rarity = "Rare", cashPerSecond = 30, price = 300, color = Color3.fromRGB(150, 110, 60) },
	{ name = "Lirili Larila", rarity = "Rare", cashPerSecond = 55, price = 550, color = Color3.fromRGB(90, 180, 220) },
	{ name = "Tralalero Tralala", rarity = "Epic", cashPerSecond = 120, price = 1200, color = Color3.fromRGB(80, 140, 255) },
	{ name = "Trippi Troppi", rarity = "Epic", cashPerSecond = 200, price = 2000, color = Color3.fromRGB(255, 140, 60) },
	{ name = "Bombardiro Crocodilo", rarity = "Legendary", cashPerSecond = 450, price = 4500, color = Color3.fromRGB(255, 70, 70) },
	{ name = "Cappuccino Assassino", rarity = "Legendary", cashPerSecond = 700, price = 7000, color = Color3.fromRGB(190, 130, 60) },
	{ name = "Brr Brr Patapim", rarity = "Mythic", cashPerSecond = 1200, price = 12000, color = Color3.fromRGB(170, 90, 255) },
	{ name = "La Vaca Saturno Saturnita", rarity = "Brainrot God", cashPerSecond = 2500, price = 25000, color = Color3.fromRGB(255, 215, 0) },
}

BrainrotCatalog.RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(80, 180, 255),
	Epic = Color3.fromRGB(170, 90, 255),
	Legendary = Color3.fromRGB(255, 170, 0),
	Mythic = Color3.fromRGB(255, 60, 120),
	["Brainrot God"] = Color3.fromRGB(255, 215, 0),
}

-- Spawn weights: common faces show up constantly, gods almost never.
local SPAWN_WEIGHTS = { 26, 22, 15, 12, 9, 6, 4, 3, 2, 1 }

function BrainrotCatalog.pickRandom()
	local total = 0
	for _, weight in ipairs(SPAWN_WEIGHTS) do
		total += weight
	end
	local roll = math.random() * total
	for index, weight in ipairs(SPAWN_WEIGHTS) do
		roll -= weight
		if roll <= 0 then
			return BrainrotCatalog.CAST[index]
		end
	end
	return BrainrotCatalog.CAST[1]
end

-- Mutations multiply earnings: Gold x2 (8%), Diamond x5 (3%),
-- Rainbow x10 (1%). Most spawns are plain.
function BrainrotCatalog.rollMutation()
	local roll = math.random()
	if roll < 0.01 then
		return "Rainbow", 10
	elseif roll < 0.04 then
		return "Diamond", 5
	elseif roll < 0.12 then
		return "Gold", 2
	end
	return "None", 1
end

function BrainrotCatalog.priceFor(entry, mutationMultiplier)
	return math.floor(entry.price * mutationMultiplier)
end

function BrainrotCatalog.earningsFor(entry, mutationMultiplier, rebirths)
	return entry.cashPerSecond * mutationMultiplier * (1 + rebirths * BrainrotCatalog.REBIRTH_BONUS)
end

function BrainrotCatalog.rarityColor(rarity)
	return BrainrotCatalog.RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
end

return BrainrotCatalog
