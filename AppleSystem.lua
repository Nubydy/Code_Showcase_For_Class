local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local pickAppleEvent = ReplicatedStorage:FindFirstChild("PickApple")
local sellApplesEvent = ReplicatedStorage:FindFirstChild("SellApples")


-- values for everything regarding the apple system
local APPLE_SELL_PRICE = 200
local PICK_COOLDOWN = 0.25
local MAX_PICK_DISTANCE = 15
local WORKER_COST = 250
local MAX_WORKERS = 8
local AUTO_PICK_INTERVAL = 2

-- Share the pick cooldown with clients so the GUI can use the same value
local sharedCooldown = ReplicatedStorage:FindFirstChild("Pick_Cooldown")
if not sharedCooldown then
	sharedCooldown = Instance.new("NumberValue")
	sharedCooldown.Name = "Pick_Cooldown"
	sharedCooldown.Parent = ReplicatedStorage
end
sharedCooldown.Value = PICK_COOLDOWN

local playerCooldowns = {}
local workerNPCs = {}
local buyDebounce = {}

local function getTreePositions()
	local positions = {}
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and string.match(child.Name, "^AppleTree") then
			table.insert(positions, child:GetPivot().Position)
		end
	end
	return positions
end

-- Update the buy button label with the current cost (or maxed out)
local function updateWorkerButtonLabel(player)
	local buyButton = Workspace:FindFirstChild("BuyWorkerButton")
	if not buyButton then return end
	local billboard = buyButton:FindFirstChild("BuyLabel")
	local label = billboard and billboard:FindFirstChildOfClass("TextLabel")
	if not label then return end

	if player then
		local leaderstats = player:FindFirstChild("leaderstats")
		local workers = leaderstats and leaderstats:FindFirstChild("Workers")
		if workers then
			if workers.Value >= MAX_WORKERS then
				label.Text = "Workers MAXED (" .. MAX_WORKERS .. ")"
				return
			end
			label.Text = "Buy Worker\n$" .. WORKER_COST
			return
		end
	end
	label.Text = "Buy Worker\n$" .. WORKER_COST
end


-- ##############################################################################

-- CODE USED FOR THE VIDEO BELOW

-- ##############################################################################



-- Handle picking apples
if pickAppleEvent then
	pickAppleEvent.OnServerEvent:Connect(function(player)
		-- Cooldown check
		local lastPick = playerCooldowns[player]
		if lastPick and (os.clock() - lastPick) < PICK_COOLDOWN then
			return
		end

		-- Distance check (player must be near any apple tree)
		local character = player.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local nearTree = false
		for _, treePos in getTreePositions() do
			if (hrp.Position - treePos).Magnitude <= MAX_PICK_DISTANCE then
				nearTree = true
				break
			end
		end
		if not nearTree then return end

		playerCooldowns[player] = os.clock()

		-- Add 1 apple to leaderstats
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local apples = leaderstats:FindFirstChild("Apples")
			if apples then
				apples.Value = apples.Value + 1
			end
		end
	end)
end



-- ##############################################################################

-- ##############################################################################

-- Handle selling apples
if sellApplesEvent then
	sellApplesEvent.OnServerEvent:Connect(function(player)
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local apples = leaderstats:FindFirstChild("Apples")
			local money = leaderstats:FindFirstChild("Money")
			if apples and money and apples.Value > 0 then
				money.Value = money.Value + (apples.Value * APPLE_SELL_PRICE)
				apples.Value = 0
			end
		end
	end)
end

-- Create a worker NPC that looks like the owner's actual player model
local function createWorkerNPC(owner, index)
	local angle = index * 0.8
	local radius = 8
	local positions = getTreePositions()
	local treePos = positions[1] or Vector3.new(0, 0, 0)
	local x = treePos.X + math.cos(angle) * radius
	local z = treePos.Z + math.sin(angle) * radius

	local worker
	local ok = pcall(function()
		worker = Players:CreateHumanoidModelFromUserId(owner.UserId)
	end)

	if ok and worker then
		worker.Name = owner.Name .. "_Worker_" .. index

		-- Anchor so the NPC stays put
		local hrp = worker:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = true
		end

		-- Hide the default name display
		local humanoid = worker:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end

		worker:PivotTo(CFrame.new(x, 3, z) * CFrame.Angles(0, -angle, 0))

		local head = worker:FindFirstChild("Head")
		if head then
			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.new(0, 150, 0, 30)
			billboard.StudsOffset = Vector3.new(0, 2.5, 0)
			billboard.Parent = head

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, 0, 1, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = owner.Name .. "'s Worker"
			nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			nameLabel.Font = Enum.Font.GothamSemibold
			nameLabel.TextSize = 14
			nameLabel.Parent = billboard
		end

		worker.Parent = workspace
		return worker
	end

	-- Fallback: simple blocky worker if the player model can't be loaded
	worker = Instance.new("Model")
	worker.Name = owner.Name .. "_Worker_" .. index

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 2, 1)
	body.Color = Color3.fromRGB(70, 130, 180)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CFrame = CFrame.new(x, 1, z) * CFrame.Angles(0, -angle, 0)
	body.Parent = worker

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Color = Color3.fromRGB(255, 200, 150)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CFrame = body.CFrame * CFrame.new(0, 1.6, 0)
	head.Parent = worker

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 150, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = owner.Name .. "'s Worker"
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.GothamSemibold
	nameLabel.TextSize = 14
	nameLabel.Parent = billboard

	worker.Parent = workspace
	return worker
end

-- Buy Worker button 
local buyButton = Workspace:FindFirstChild("BuyWorkerButton")
if buyButton then
	buyButton.Touched:Connect(function(otherPart)
		local character = otherPart.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		if buyDebounce[player] then return end
		buyDebounce[player] = true
		task.delay(1, function()
			buyDebounce[player] = nil
		end)

		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then return end

		local money = leaderstats:FindFirstChild("Money")
		local workers = leaderstats:FindFirstChild("Workers")
		if not money or not workers then return end

		-- Max worker cap
		if workers.Value >= MAX_WORKERS then
			updateWorkerButtonLabel(player)
			return
		end

		local cost = WORKER_COST
		if money.Value >= cost then
			money.Value = money.Value - cost
			workers.Value = workers.Value + 1

			-- Play the purchase sound
			local sound = buyButton:FindFirstChildOfClass("Sound")
			if sound then
				sound:Play()
			end

			if not workerNPCs[player] then
				workerNPCs[player] = {}
			end
			local npc = createWorkerNPC(player, #workerNPCs[player] + 1)
			table.insert(workerNPCs[player], npc)

			-- Show the next worker's price (or MAXED)
			updateWorkerButtonLabel(player)
		end
	end)
end

-- Keep the button label fresh for players joining
Players.PlayerAdded:Connect(function(player)
	task.delay(2, function()
		if player.Parent then
			updateWorkerButtonLabel(player)
		end
	end)
end)

-- Auto-pick loop, workers generate apples over time
task.spawn(function()
	while task.wait(AUTO_PICK_INTERVAL) do
		for _, player in Players:GetPlayers() do
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local workers = leaderstats:FindFirstChild("Workers")
				local apples = leaderstats:FindFirstChild("Apples")
				if workers and apples and workers.Value > 0 then
					apples.Value = apples.Value + workers.Value
				end
			end
		end
	end
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player] = nil
	buyDebounce[player] = nil

	if workerNPCs[player] then
		for _, npc in ipairs(workerNPCs[player]) do
			npc:Destroy()
		end
		workerNPCs[player] = nil
	end
end)