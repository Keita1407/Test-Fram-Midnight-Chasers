game:GetService("Players").LocalPlayer.Idled:connect(function()
    game:GetService("VirtualUser"):CaptureController()
    game:GetService("VirtualUser"):ClickButton2(Vector2.new())
end)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local IS_SALTFLATS = (game.PlaceId == 139048751758942)
local SAVE_FILE = "Keitaz.json"

local autoFarmActive = false
local carStabilizationConnection = nil
local uiElements = nil
local currentMilestone = 0
local allTimeMilestone = 0
local farmStartCash = 0
local farmStartTime = 0

local totalCashEarned = 0
local lastCashAmount = 0
local allTimeMoney = 0
local longestAFKSeconds = 0
local hideDisplayName = false

local QUESTS = {
    { type = "earn", target = 500000, label = "Earn $500,000" },
    { type = "time", target = 1800, label = "Farm for 30 Minutes" },
    { type = "loops", target = 3, label = "Complete 3 Farm Loops" },
    { type = "earn", target = 1000000, label = "Earn $1,000,000" },
    { type = "time", target = 3600, label = "Farm for 1 Hour" },
    { type = "loops", target = 7, label = "Complete 7 Farm Loops" },
    { type = "earn", target = 2500000, label = "Earn $2,500,000" },
    { type = "time", target = 7200, label = "Farm for 2 Hours" },
    { type = "loops", target = 15, label = "Complete 15 Farm Loops" },
    { type = "earn", target = 5000000, label = "Earn $5,000,000" },
    { type = "time", target = 10800, label = "Farm for 3 Hours" },
    { type = "loops", target = 25, label = "Complete 25 Farm Loops" },
    { type = "earn", target = 7500000, label = "Earn $7,500,000" },
    { type = "time", target = 18000, label = "Farm for 5 Hours" },
    { type = "loops", target = 50, label = "Complete 50 Farm Loops" },
    { type = "earn", target = 10000000, label = "Earn $10,000,000" },
    { type = "time", target = 43200, label = "Farm for 12 Hours" },
    { type = "loops", target = 100, label = "Complete 100 Farm Loops" },
    { type = "earn", target = 15000000, label = "Earn $15,000,000" },
    { type = "time", target = 86400, label = "Farm for 24 Hours" },
    { type = "loops", target = 150, label = "Complete 150 Farm Loops" },
    { type = "earn", target = 20000000, label = "Earn $20,000,000" },
    { type = "time", target = 129600, label = "Farm for 36 Hours" },
    { type = "loops", target = 200, label = "Complete 200 Farm Loops" },
    { type = "earn", target = 30000000, label = "Earn $30,000,000" },
    { type = "time", target = 172800, label = "Farm for 48 Hours" },
    { type = "loops", target = 250, label = "Complete 250 Farm Loops" },
    { type = "earn", target = 50000000, label = "Earn $50,000,000" },
    { type = "time", target = 216000, label = "Farm for 60 Hours" },
    { type = "loops", target = 350, label = "Complete 350 Farm Loops" },
    { type = "earn", target = 75000000, label = "Earn $75,000,000" },
    { type = "time", target = 302400, label = "Farm for 84 Hours" },
    { type = "loops", target = 500, label = "Complete 500 Farm Loops" },
    { type = "earn", target = 100000000, label = "Earn $100,000,000" },
    { type = "time", target = 432000, label = "Farm for 120 Hours" }
}

local questIndex = 1
local questProgress = 0
local questCompleted = false
local questCooldownEnd = 0
local questTotalCompleted = 0
local questSpeedBonus = 0
local questLoopCount = 0
local questStartTime = tick()
local questFarmSeconds = 0
local allQuestsDone = false

local questTaskLabel = nil
local questProgressLabel = nil
local questEtaLabel = nil
local questCooldownLabel = nil
local questClaimButton = nil
local questTotalLabel = nil
local questSpeedLabel = nil
local questNotifBadge = nil
local questShineLoop = nil

local WAYPOINTS = IS_SALTFLATS and {
    Vector3.new(3338, -9, 6035),
    Vector3.new(3397, -6, 6105),
    Vector3.new(2781, -6, 5214),
    Vector3.new(599, 5, 1451),
    Vector3.new(-1313, 5, -1092),
    Vector3.new(-1893, 5, -1692),
    Vector3.new(-15069, 5, -14868),
    Vector3.new(-38681, 5, -38500),
} or {
    Vector3.new(-67850, -14, 10051),
    Vector3.new(-12121, -16, -2788),
}

local function loadData()
    local ok, result = pcall(readfile, SAVE_FILE)
    if not ok or not result then return end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, result)
    if not ok2 or not data then return end
    if data.allTime then allTimeMoney = data.allTime end
    if data.longestAFK then longestAFKSeconds = data.longestAFK end
    if data.questIndex then questIndex = math.max(1, math.min(data.questIndex, #QUESTS)) end
    if data.questProgress then questProgress = data.questProgress end
    if data.questCompleted then questCompleted = data.questCompleted end
    if data.questCooldownEnd then questCooldownEnd = data.questCooldownEnd end
    if data.questTotal then questTotalCompleted = data.questTotal end
    if data.questSpeed then questSpeedBonus = data.questSpeed end
    if data.questLoopCount then questLoopCount = data.questLoopCount end
    if data.allQuestsDone then allQuestsDone = data.allQuestsDone end
end

local function saveData()
    pcall(writefile, SAVE_FILE, HttpService:JSONEncode({
        allTime = allTimeMoney,
        longestAFK = longestAFKSeconds,
        questIndex = questIndex,
        questProgress = questProgress,
        questCompleted = questCompleted,
        questCooldownEnd = questCooldownEnd,
        questTotal = questTotalCompleted,
        questSpeed = questSpeedBonus,
        questLoopCount = questLoopCount,
        allQuestsDone = allQuestsDone,
    }))
end

loadData()

local function disableCollision(model)
    for _, desc in pairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then desc.CanCollide = false end
    end
end

local function setupExistingVehicles()
    local npc = workspace:FindFirstChild("NPCVehicles")
    if not npc then return end
    local vehicles = npc:FindFirstChild("Vehicles")
    if not vehicles then return end
    for _, v in pairs(vehicles:GetChildren()) do
        if v:IsA("Model") or v:IsA("Folder") then disableCollision(v) end
    end
end

local function monitorNewVehicles()
    local npc = workspace:FindFirstChild("NPCVehicles")
    if not npc then return end
    local vehicles = npc:FindFirstChild("Vehicles")
    if not vehicles then return end
    vehicles.ChildAdded:Connect(function(child)
        wait(0.1)
        disableCollision(child)
    end)
end

setupExistingVehicles()
monitorNewVehicles()
spawn(function() while wait(1) do setupExistingVehicles() end end)

if not IS_SALTFLATS then
    spawn(function()
        wait(0.5)
        local SLAB, BASE_X, BASE_Z, BASE_Y = 2048, -36149, 5376, -16.5
        local roadModel = Instance.new("Model")
        roadModel.Name = "FarmRoad"
        for row = -15, 15 do
            for col = -15, 15 do
                local slab = Instance.new("Part")
                slab.Size = Vector3.new(SLAB, 0.2, SLAB)
                slab.CFrame = CFrame.new(BASE_X + col * SLAB, BASE_Y - 0.5, BASE_Z + row * SLAB)
                slab.Anchored = true; slab.CanCollide = true
                slab.Material = Enum.Material.Asphalt
                slab.Color = Color3.fromRGB(50, 50, 50)
                slab.Parent = roadModel
            end
        end
        roadModel.Parent = workspace
    end)
end

local function formatNumber(num)
    local f = tostring(math.floor(num))
    local k
    while true do
        f, k = string.gsub(f, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return f
end

local function formatAbbreviated(num)
    if num >= 1000000000 then return string.format("%.1fB", num / 1000000000)
    elseif num >= 1000000 then return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then return string.format("%.1fK", num / 1000)
    end
    return tostring(math.floor(num))
end

local function formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function formatCooldown(remaining)
    local m = math.floor(remaining / 60)
    local s = math.floor(remaining % 60)
    return string.format("%d:%02d", m, s)
end

local function getMilestoneGradient(amount)
    if amount >= 15000000 then return { Color3.fromRGB(138,43,226), Color3.fromRGB(75,0,130), Color3.fromRGB(138,43,226) }
    elseif amount >= 10000000 then return { Color3.fromRGB(70,130,255), Color3.fromRGB(30,80,200), Color3.fromRGB(70,130,255) }
    elseif amount >= 5000000 then return { Color3.fromRGB(0,191,255), Color3.fromRGB(0,100,200), Color3.fromRGB(0,191,255) }
    elseif amount >= 2500000 then return { Color3.fromRGB(65,105,225), Color3.fromRGB(25,50,150), Color3.fromRGB(65,105,225) }
    elseif amount >= 1000000 then return { Color3.fromRGB(30,144,255), Color3.fromRGB(0,90,180), Color3.fromRGB(30,144,255) }
    elseif amount >= 500000 then return { Color3.fromRGB(100,149,237), Color3.fromRGB(50,100,180), Color3.fromRGB(100,149,237) }
    elseif amount >= 100000 then return { Color3.fromRGB(0,150,255), Color3.fromRGB(0,100,200), Color3.fromRGB(0,150,255) }
    elseif amount >= 50000 then return { Color3.fromRGB(100,180,255), Color3.fromRGB(50,120,200), Color3.fromRGB(100,180,255) }
    end
    return nil
end

local accentA = IS_SALTFLATS and Color3.fromRGB(190, 135, 45) or Color3.fromRGB(55, 105, 215)
local accentB = IS_SALTFLATS and Color3.fromRGB(255, 215, 100) or Color3.fromRGB(140, 195, 255)

local allTimeLabel = nil
local allTimeDetailLabel = nil
local allTimeGradientObj = nil
local longestAFKLabel = nil

local function updateAllTimeUI()
    if allTimeLabel then allTimeLabel.Text = "All-Time Money: $" .. formatAbbreviated(allTimeMoney) end
    if allTimeDetailLabel then allTimeDetailLabel.Text = "Exact: $" .. formatNumber(allTimeMoney) end
end

local function updateAllTimeGradient()
    if not allTimeGradientObj then return end
    local newMilestone = 0
    if allTimeMoney >= 15000000 then newMilestone = 15000000
    elseif allTimeMoney >= 10000000 then newMilestone = 10000000
    elseif allTimeMoney >= 5000000 then newMilestone = 5000000
    elseif allTimeMoney >= 2500000 then newMilestone = 2500000
    elseif allTimeMoney >= 1000000 then newMilestone = 1000000
    elseif allTimeMoney >= 500000 then newMilestone = 500000
    elseif allTimeMoney >= 100000 then newMilestone = 100000
    elseif allTimeMoney >= 50000 then newMilestone = 50000
    end
    if newMilestone ~= allTimeMilestone then
        allTimeMilestone = newMilestone
        local g = getMilestoneGradient(allTimeMoney)
        if g then
            allTimeGradientObj.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, g[1]), 
                ColorSequenceKeypoint.new(0.5, g[2]), 
                ColorSequenceKeypoint.new(1, g[3])
            }
        else
            allTimeGradientObj.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, accentA), 
                ColorSequenceKeypoint.new(0.5, accentB), 
                ColorSequenceKeypoint.new(1, accentA)
            }
        end
    end
end

local function updateLongestAFKUI()
    if longestAFKLabel then longestAFKLabel.Text = "Longest AFK: " .. formatTime(longestAFKSeconds) end
end

local function applyCashGradient(label, gradient)
    local existing = label:FindFirstChild("MilestoneGradient")
    if existing then existing:Destroy() end
    local g = Instance.new("UIGradient")
    g.Name = "MilestoneGradient"
    g.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, gradient[1]), 
        ColorSequenceKeypoint.new(0.5, gradient[2]), 
        ColorSequenceKeypoint.new(1, gradient[3])
    }
    g.Rotation = 0; g.Parent = label
    spawn(function()
        while g.Parent and autoFarmActive do
            for rot = 0, 360, 2 do
                if not g.Parent or not autoFarmActive then break end
                g.Rotation = rot; wait(0.03)
            end
        end
    end)
end

local function updateCashGradient(amount)
    if not uiElements or not uiElements.cashEarnedLabel then return end
    local newMilestone = 0
    if amount >= 15000000 then newMilestone = 15000000
    elseif amount >= 10000000 then newMilestone = 10000000
    elseif amount >= 5000000 then newMilestone = 5000000
    elseif amount >= 2500000 then newMilestone = 2500000
    elseif amount >= 1000000 then newMilestone = 1000000
    elseif amount >= 500000 then newMilestone = 500000
    elseif amount >= 100000 then newMilestone = 100000
    elseif amount >= 50000 then newMilestone = 50000
    end
    if newMilestone ~= currentMilestone then
        currentMilestone = newMilestone
        local gradient = getMilestoneGradient(amount)
        if gradient then applyCashGradient(uiElements.cashEarnedLabel, gradient) end
    end
end

local function popCashLabel()
    if not uiElements or not uiElements.cashEarnedLabel then return end
    TweenService:Create(uiElements.cashEarnedLabel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 26 }):Play()
    wait(0.18)
    TweenService:Create(uiElements.cashEarnedLabel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextSize = 18 }):Play()
end

local function setupUITracking()
    local mainUI = player.PlayerGui:WaitForChild("Main_User_Interface", 5)
    if not mainUI then return nil end
    local afkRewards = mainUI:WaitForChild("AFKRewards")
    local cashEarnedLabel = afkRewards:WaitForChild("CashEarned"):WaitForChild("Label")
    local timeLabel = afkRewards:WaitForChild("Time"):WaitForChild("Label")
    local bottom = mainUI:WaitForChild("UI_Frame"):WaitForChild("Bottom")
    local moneyButton = bottom:WaitForChild("Money")
    local teleportButton = bottom:WaitForChild("Teleport")
    local rewardsButton = bottom:WaitForChild("Rewards")

    afkRewards.Visible = false

    local perSecondLabel = Instance.new("TextLabel")
    perSecondLabel.Name = "PerSecondEarnings"
    perSecondLabel.Size = UDim2.new(0, 180, 0, 40)
    perSecondLabel.Position = UDim2.new(0.5, -90, 0, -45)
    perSecondLabel.BackgroundTransparency = 1
    perSecondLabel.Text = "+$0/s"
    perSecondLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    perSecondLabel.TextSize = 22
    perSecondLabel.Font = Enum.Font.GothamBold
    perSecondLabel.TextStrokeTransparency = 0.5
    perSecondLabel.Visible = false
    perSecondLabel.Parent = moneyButton

    return {
        cashEarnedLabel = cashEarnedLabel, 
        timeLabel = timeLabel,
        afkRewards = afkRewards, 
        perSecondLabel = perSecondLabel,
        teleportButton = teleportButton, 
        rewardsButton = rewardsButton,
    }
end

spawn(function() wait(1); uiElements = setupUITracking() end)

local function updatePerSecondEarnings(diff)
    if not uiElements or diff <= 0 then return end
    local fl = uiElements.perSecondLabel:Clone()
    fl.Text = "+$" .. formatNumber(diff) .. "/s"
    fl.Position = UDim2.new(0.5, -90, 0, -10)
    fl.Visible = true; fl.Parent = uiElements.perSecondLabel.Parent
    local mt = TweenService:Create(fl, TweenInfo.new(1.5), { Position = UDim2.new(0.5, -90, 0, -60), TextTransparency = 1 })
    mt:Play(); mt.Completed:Connect(function() fl:Destroy() end)
end

local function formatQuestRichLabel(q)
    local c = IS_SALTFLATS and "#FFD050" or "#64B4FF"
    if q.type == "earn" then
        return 'Earn <font color="' .. c .. '"><b>$' .. formatNumber(q.target) .. '</b></font>'
    elseif q.type == "time" then
        local h = math.floor(q.target / 3600)
        local m = math.floor((q.target % 3600) / 60)
        local timeStr
        if h > 0 and m > 0 then timeStr = h .. (h == 1 and " Hour " or " Hours ") .. m .. " Min"
        elseif h > 0 then timeStr = h .. (h == 1 and " Hour" or " Hours")
        else timeStr = m .. " Minutes"
        end
        return 'Farm for <font color="' .. c .. '"><b>' .. timeStr .. '</b></font>'
    elseif q.type == "loops" then
        return 'Complete <font color="' .. c .. '"><b>' .. q.target .. '</b></font> Farm Loops'
    end
    return q.label
end

local function updateQuestUI()
    if not questTaskLabel then return end
    if allQuestsDone then
        questTaskLabel.Text = "More Coming Soon..."
        questProgressLabel.Text = "All " .. #QUESTS .. " quests completed!"
        if questEtaLabel then questEtaLabel.Visible = false end
        questClaimButton.Visible = false; questCooldownLabel.Visible = false
        if questNotifBadge then questNotifBadge.Visible = false end
        if questTotalLabel then questTotalLabel.Text = "Total Quests Completed: " .. questTotalCompleted end
        if questSpeedLabel then questSpeedLabel.Text = "Speed Bonus: +" .. questSpeedBonus end
        return
    end
    local q = QUESTS[questIndex]
    if not q then return end
    questTaskLabel.Text = "Task " .. questIndex .. "/" .. #QUESTS .. ": " .. formatQuestRichLabel(q)
    local pct = math.min(math.floor((questProgress / q.target) * 100), 100)
    if q.type == "earn" then
        questProgressLabel.Text = "$" .. formatNumber(questProgress) .. " / $" .. formatNumber(q.target) .. " (" .. pct .. "%)"
    elseif q.type == "time" then
        questProgressLabel.Text = formatTime(questProgress) .. " / " .. formatTime(q.target) .. " (" .. pct .. "%)"
    elseif q.type == "loops" then
        questProgressLabel.Text = questProgress .. " / " .. q.target .. " loops (" .. pct .. "%)"
    end
    if questCompleted then
        if questEtaLabel then questEtaLabel.Visible = false end
        if questCooldownEnd == 0 then
            questClaimButton.Visible = true; questCooldownLabel.Visible = false
            if questNotifBadge then questNotifBadge.Visible = true end
        else
            questClaimButton.Visible = false; questCooldownLabel.Visible = true
            if questNotifBadge then questNotifBadge.Visible = false end
        end
    elseif questCooldownEnd > 0 then
        if questEtaLabel then questEtaLabel.Visible = false end
        questClaimButton.Visible = false; questCooldownLabel.Visible = true
        if questNotifBadge then questNotifBadge.Visible = false end
    else
        if questEtaLabel then questEtaLabel.Visible = true end
        questClaimButton.Visible = false; questCooldownLabel.Visible = false
        if questNotifBadge then questNotifBadge.Visible = false end
    end
    if questTotalLabel then questTotalLabel.Text = "Total Quests Completed: " .. questTotalCompleted end
    if questSpeedLabel then questSpeedLabel.Text = "Speed Bonus: +" .. questSpeedBonus end
end

local function updateQuestEta()
    if not autoFarmActive or not questEtaLabel or not questEtaLabel.Visible then return end
    if questCompleted or questCooldownEnd > 0 or allQuestsDone then return end
    local q = QUESTS[questIndex]
    if not q then return end
    if q.type == "time" then
        questEtaLabel.Text = "Est. Time: " .. formatTime(math.max(0, q.target - questProgress))
    elseif q.type == "earn" then
        if questFarmSeconds < 5 or questProgress <= 0 then questEtaLabel.Text = "Est. Time: calculating..."; return end
        local rate = questProgress / questFarmSeconds
        if rate <= 0 then questEtaLabel.Text = "Est. Time: calculating..."; return end
        questEtaLabel.Text = "Est. Time: " .. formatTime(math.max(0, (q.target - questProgress) / rate))
    elseif q.type == "loops" then
        if questFarmSeconds < 5 or questLoopCount <= 0 then questEtaLabel.Text = "Est. Time: calculating..."; return end
        local rate = questLoopCount / questFarmSeconds
        if rate <= 0 then questEtaLabel.Text = "Est. Time: calculating..."; return end
        questEtaLabel.Text = "Est. Time: " .. formatTime(math.max(0, (q.target - questLoopCount) / rate))
    end
end

local function startQuestShine()
    if questShineLoop then return end
    if not questClaimButton then return end
    questShineLoop = spawn(function()
        while questCompleted and questCooldownEnd == 0 do
            local shine = Instance.new("Frame")
            shine.Size = UDim2.new(0.18, 0, 1.2, 0); shine.Position = UDim2.new(-0.18, 0, -0.1, 0)
            shine.BackgroundColor3 = Color3.fromRGB(255,255,255); shine.BackgroundTransparency = 0.55
            shine.BorderSizePixel = 0; shine.Rotation = 18; shine.ZIndex = 10; shine.Parent = questClaimButton
            local sg = Instance.new("UIGradient")
            sg.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,1), 
                NumberSequenceKeypoint.new(0.4,0.2),
                NumberSequenceKeypoint.new(0.6,0.2), 
                NumberSequenceKeypoint.new(1,1)
            })
            sg.Rotation = 90; sg.Parent = shine
            local st = TweenService:Create(shine, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Position = UDim2.new(1.18,0,-0.1,0) })
            st:Play(); st.Completed:Wait(); shine:Destroy(); wait(1.4)
        end
        questShineLoop = nil
    end)
end

local function markQuestComplete()
    local timeTaken = math.floor(tick() - questStartTime)
    questCompleted = true
    updateQuestUI(); startQuestShine(); saveData()
end

local function pickNewQuest()
    if questIndex >= #QUESTS then
        allQuestsDone = true; questCompleted = false; questCooldownEnd = 0
        updateQuestUI(); saveData(); return
    end
    questIndex = questIndex + 1
    questProgress = 0; questCompleted = false; questCooldownEnd = 0
    questLoopCount = 0; questShineLoop = nil; questStartTime = tick(); questFarmSeconds = 0
    updateQuestUI()
end

-- UI Creation
local guiScreen = Instance.new("ScreenGui")
guiScreen.Name = "AutoFarmGUI"; guiScreen.DisplayOrder = 50000
guiScreen.ResetOnSpawn = false; guiScreen.IgnoreGuiInset = true
guiScreen.Parent = player.PlayerGui

local guiFrame = Instance.new("Frame")
guiFrame.Size = UDim2.new(0, 312, 0, 300)
guiFrame.Position = UDim2.new(0.5, -156, 0.5, -150)
guiFrame.BackgroundColor3 = Color3.fromRGB(16,16,18); guiFrame.BorderSizePixel = 0
guiFrame.Parent = guiScreen
Instance.new("UICorner", guiFrame).CornerRadius = UDim.new(0,14)
local frameStroke = Instance.new("UIStroke", guiFrame)
frameStroke.Color = Color3.fromRGB(44,44,50); frameStroke.Thickness = 1.5

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1,-90,0,30); titleLabel.Position = UDim2.new(0,12,0,10)
titleLabel.BackgroundTransparency = 1; titleLabel.Text = "Keitaz Auto Mechanics"
titleLabel.TextColor3 = Color3.fromRGB(255,255,255); titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.GothamBold; titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = guiFrame

local mapSubtitle = Instance.new("TextLabel")
mapSubtitle.Size = UDim2.new(1,-20,0,22); mapSubtitle.Position = UDim2.new(0,12,0,40)
mapSubtitle.BackgroundTransparency = 1; mapSubtitle.TextSize = 14
mapSubtitle.Font = Enum.Font.GothamBold; mapSubtitle.TextXAlignment = Enum.TextXAlignment.Left
mapSubtitle.Parent = guiFrame

if IS_SALTFLATS then
    mapSubtitle.Text = "Current Map: Boneville Salt Flats"
    mapSubtitle.TextColor3 = Color3.fromRGB(215,170,80)
    local dg = Instance.new("UIGradient")
    dg.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(190,135,45)), 
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255,215,100)),
        ColorSequenceKeypoint.new(0.65, Color3.fromRGB(240,185,75)), 
        ColorSequenceKeypoint.new(1, Color3.fromRGB(190,135,45))
    }
    dg.Offset = Vector2.new(-1,0); dg.Parent = mapSubtitle
    spawn(function()
        while mapSubtitle.Parent do
            local t = TweenService:Create(dg, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1,0) })
            t:Play(); t.Completed:Wait(); dg.Offset = Vector2.new(-1,0); wait(0.4)
        end
    end)
else
    mapSubtitle.Text = "Current Map: Shutoko"
    mapSubtitle.TextColor3 = Color3.fromRGB(100,160,255)
    local cg = Instance.new("UIGradient")
    cg.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(55,105,215)), 
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(140,195,255)),
        ColorSequenceKeypoint.new(0.65, Color3.fromRGB(95,155,250)), 
        ColorSequenceKeypoint.new(1, Color3.fromRGB(55,105,215))
    }
    cg.Offset = Vector2.new(-1,0); cg.Parent = mapSubtitle
    spawn(function()
        while mapSubtitle.Parent do
            local t = TweenService:Create(cg, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1,0) })
            t:Play(); t.Completed:Wait(); cg.Offset = Vector2.new(-1,0); wait(0.4)
        end
    end)
end

local div1 = Instance.new("Frame"); div1.Size = UDim2.new(1,-24,0,1); div1.Position = UDim2.new(0,12,0,68)
div1.BackgroundColor3 = Color3.fromRGB(36,36,42); div1.BorderSizePixel = 0; div1.Parent = guiFrame

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1,-20,0,20); statusText.Position = UDim2.new(0,12,0,76)
statusText.BackgroundTransparency = 1; statusText.Text = "Status: Ready"
statusText.TextColor3 = Color3.fromRGB(175,175,175); statusText.TextSize = 14
statusText.Font = Enum.Font.GothamMedium; statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.Parent = guiFrame

local allTimeFrame = Instance.new("Frame")
allTimeFrame.Size = UDim2.new(1,-20,0,22); allTimeFrame.Position = UDim2.new(0,12,0,100)
allTimeFrame.BackgroundTransparency = 1; allTimeFrame.Parent = guiFrame

allTimeLabel = Instance.new("TextLabel")
allTimeLabel.Size = UDim2.new(1,0,1,0); allTimeLabel.BackgroundTransparency = 1
allTimeLabel.TextColor3 = Color3.fromRGB(255,255,255); allTimeLabel.TextSize = 14
allTimeLabel.Font = Enum.Font.GothamBold; allTimeLabel.TextXAlignment = Enum.TextXAlignment.Left
allTimeLabel.Parent = allTimeFrame

allTimeGradientObj = Instance.new("UIGradient")
allTimeGradientObj.Color = ColorSequence.new{ ColorSequenceKeypoint.new(0,accentA), ColorSequenceKeypoint.new(0.5,accentB), ColorSequenceKeypoint.new(1,accentA) }
allTimeGradientObj.Offset = Vector2.new(-1,0); allTimeGradientObj.Parent = allTimeLabel
spawn(function()
    while allTimeLabel.Parent do
        local t = TweenService:Create(allTimeGradientObj, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1,0) })
        t:Play(); t.Completed:Wait(); allTimeGradientObj.Offset = Vector2.new(-1,0); wait(0.5)
    end
end)

allTimeDetailLabel = Instance.new("TextLabel")
allTimeDetailLabel.Size = UDim2.new(1,0,1,0); allTimeDetailLabel.BackgroundTransparency = 1
allTimeDetailLabel.TextColor3 = Color3.fromRGB(220,220,220); allTimeDetailLabel.TextSize = 16
allTimeDetailLabel.Font = Enum.Font.GothamBold; allTimeDetailLabel.TextXAlignment = Enum.TextXAlignment.Left
allTimeDetailLabel.TextTransparency = 1; allTimeDetailLabel.Parent = allTimeFrame

allTimeFrame.MouseEnter:Connect(function()
    TweenService:Create(allTimeLabel, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
    TweenService:Create(allTimeDetailLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
end)
allTimeFrame.MouseLeave:Connect(function()
    TweenService:Create(allTimeLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
    TweenService:Create(allTimeDetailLabel, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
end)

local longestFrame = Instance.new("Frame")
longestFrame.Size = UDim2.new(1,-20,0,22); longestFrame.Position = UDim2.new(0,12,0,124)
longestFrame.BackgroundTransparency = 1; longestFrame.Parent = guiFrame

longestAFKLabel = Instance.new("TextLabel")
longestAFKLabel.Size = UDim2.new(1,0,1,0); longestAFKLabel.BackgroundTransparency = 1
longestAFKLabel.TextColor3 = Color3.fromRGB(255,255,255); longestAFKLabel.TextSize = 14
longestAFKLabel.Font = Enum.Font.GothamMedium; longestAFKLabel.TextXAlignment = Enum.TextXAlignment.Left
longestAFKLabel.Parent = longestFrame

local lg = Instance.new("UIGradient")
lg.Color = IS_SALTFLATS and ColorSequence.new{ ColorSequenceKeypoint.new(0, Color3.fromRGB(155,125,65)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200,165,90)), ColorSequenceKeypoint.new(1, Color3.fromRGB(155,125,65)) }
or ColorSequence.new{ ColorSequenceKeypoint.new(0, Color3.fromRGB(65,115,185)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(105,160,230)), ColorSequenceKeypoint.new(1, Color3.fromRGB(65,115,185)) }
lg.Offset = Vector2.new(-1,0); lg.Parent = longestAFKLabel
spawn(function()
    while longestAFKLabel.Parent do
        local t = TweenService:Create(lg, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1,0) })
        t:Play(); t.Completed:Wait(); lg.Offset = Vector2.new(-1,0); wait(0.5)
    end
end)

updateAllTimeUI(); updateLongestAFKUI()

local div2 = Instance.new("Frame"); div2.Size = UDim2.new(1,-24,0,1); div2.Position = UDim2.new(0,12,0,152)
div2.BackgroundColor3 = Color3.fromRGB(36,36,42); div2.BorderSizePixel = 0; div2.Parent = guiFrame

local autoFarmToggle = Instance.new("TextButton")
autoFarmToggle.Size = UDim2.new(1,-20,0,58); autoFarmToggle.Position = UDim2.new(0,10,0,160)
autoFarmToggle.Text = "Start AutoFarm"; autoFarmToggle.TextColor3 = Color3.fromRGB(255,255,255)
autoFarmToggle.TextSize = 19; autoFarmToggle.Font = Enum.Font.GothamBold
autoFarmToggle.BackgroundColor3 = Color3.fromRGB(42,42,46); autoFarmToggle.BorderSizePixel = 0
autoFarmToggle.ClipsDescendants = true; autoFarmToggle.Parent = guiFrame
Instance.new("UICorner", autoFarmToggle).CornerRadius = UDim.new(0,12)

local toggleGradient = Instance.new("UIGradient", autoFarmToggle)
toggleGradient.Color = ColorSequence.new{ ColorSequenceKeypoint.new(0, Color3.fromRGB(52,52,57)), ColorSequenceKeypoint.new(1, Color3.fromRGB(32,32,36)) }
toggleGradient.Rotation = 90

local toggleStroke = Instance.new("UIStroke", autoFarmToggle)
toggleStroke.Color = Color3.fromRGB(70,140,220); toggleStroke.Thickness = 2.5; toggleStroke.Transparency = 0.3
toggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local toggleGlow = Instance.new("ImageLabel", autoFarmToggle)
toggleGlow.Size = UDim2.new(1,40,1,40); toggleGlow.Position = UDim2.new(0,-20,0,-20)
toggleGlow.BackgroundTransparency = 1; toggleGlow.Image = "rbxassetid://91493125301731"
toggleGlow.ImageColor3 = Color3.fromRGB(70,140,220); toggleGlow.ImageTransparency = 0.85
toggleGlow.ScaleType = Enum.ScaleType.Slice; toggleGlow.SliceCenter = Rect.new(24,24,276,276); toggleGlow.ZIndex = 0

spawn(function()
    while autoFarmToggle.Parent do
        TweenService:Create(toggleGlow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.7 }):Play(); wait(2)
        TweenService:Create(toggleGlow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.85 }):Play(); wait(2)
    end
end)

autoFarmToggle.MouseEnter:Connect(function()
    TweenService:Create(autoFarmToggle, TweenInfo.new(0.3, Enum.EasingStyle.Sine), { Size = UDim2.new(1,-16,0,62) }):Play()
    TweenService:Create(toggleStroke, TweenInfo.new(0.3), { Transparency = 0, Thickness = 3 }):Play()
    TweenService:Create(toggleGlow, TweenInfo.new(0.3), { ImageTransparency = 0.5 }):Play()
end)
autoFarmToggle.MouseLeave:Connect(function()
    TweenService:Create(autoFarmToggle, TweenInfo.new(0.3, Enum.EasingStyle.Sine), { Size = UDim2.new(1,-20,0,58) }):Play()
    TweenService:Create(toggleStroke, TweenInfo.new(0.3), { Transparency = 0.3, Thickness = 2.5 }):Play()
    TweenService:Create(toggleGlow, TweenInfo.new(0.3), { ImageTransparency = 0.85 }):Play()
end)

local div3 = Instance.new("Frame"); div3.Size = UDim2.new(1,-24,0,1); div3.Position = UDim2.new(0,12,0,226)
div3.BackgroundColor3 = Color3.fromRGB(36,36,42); div3.BorderSizePixel = 0; div3.Parent = guiFrame

local playerIcon = Instance.new("ImageLabel")
playerIcon.Size = UDim2.new(0,40,0,40); playerIcon.Position = UDim2.new(1,-52,1,-52)
playerIcon.BackgroundTransparency = 1
playerIcon.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"
playerIcon.Parent = guiFrame
Instance.new("UICorner", playerIcon).CornerRadius = UDim.new(1,0)
local iconStroke = Instance.new("UIStroke", playerIcon)
iconStroke.Color = Color3.fromRGB(60,60,60); iconStroke.Thickness = 2

local usernameText = Instance.new("TextLabel")
usernameText.Size = UDim2.new(1,-85,0,22); usernameText.Position = UDim2.new(0,12,1,-48)
usernameText.BackgroundTransparency = 1; usernameText.Text = "@" .. player.Name
usernameText.TextColor3 = Color3.fromRGB(135,135,135); usernameText.TextSize = 15
usernameText.Font = Enum.Font.GothamMedium; usernameText.TextXAlignment = Enum.TextXAlignment.Left
usernameText.Parent = guiFrame

-- Quest Button & Panel
local questBtn = Instance.new("ImageButton")
questBtn.Size = UDim2.new(0,46,0,46); questBtn.Position = UDim2.new(1,10,0,70)
questBtn.BackgroundColor3 = Color3.fromRGB(22,22,28); questBtn.BorderSizePixel = 0
questBtn.Image = "rbxassetid://91493125301731"; questBtn.ScaleType = Enum.ScaleType.Fit; questBtn.ZIndex = 5
questBtn.Parent = guiFrame
Instance.new("UICorner", questBtn).CornerRadius = UDim.new(0,12)

local questBtnStroke = Instance.new("UIStroke", questBtn)
questBtnStroke.Color = IS_SALTFLATS and Color3.fromRGB(200,155,60) or Color3.fromRGB(80,140,230); questBtnStroke.Thickness = 2.5

local questBtnGlow = Instance.new("ImageLabel", questBtn)
questBtnGlow.Size = UDim2.new(1,20,1,20); questBtnGlow.Position = UDim2.new(0,-10,0,-10)
questBtnGlow.BackgroundTransparency = 1; questBtnGlow.Image = "rbxassetid://91493125301731"
questBtnGlow.ImageColor3 = IS_SALTFLATS and Color3.fromRGB(200,155,60) or Color3.fromRGB(80,140,230)
questBtnGlow.ImageTransparency = 0.85; questBtnGlow.ScaleType = Enum.ScaleType.Slice
questBtnGlow.SliceCenter = Rect.new(24,24,276,276); questBtnGlow.ZIndex = 0

spawn(function()
    while questBtn.Parent do
        TweenService:Create(questBtnGlow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.65 }):Play(); wait(2)
        TweenService:Create(questBtnGlow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.85 }):Play(); wait(2)
    end
end)

questBtn.MouseEnter:Connect(function()
    TweenService:Create(questBtn, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0,52,0,52) }):Play()
    TweenService:Create(questBtnStroke, TweenInfo.new(0.2), { Transparency = 0, Thickness = 3 }):Play()
    TweenService:Create(questBtnGlow, TweenInfo.new(0.2), { ImageTransparency = 0.45 }):Play()
    TweenService:Create(questBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(32,32,40) }):Play()
end)
questBtn.MouseLeave:Connect(function()
    TweenService:Create(questBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0,46,0,46) }):Play()
    TweenService:Create(questBtnStroke, TweenInfo.new(0.2), { Transparency = 0.3, Thickness = 2.5 }):Play()
    TweenService:Create(questBtnGlow, TweenInfo.new(0.2), { ImageTransparency = 0.85 }):Play()
    TweenService:Create(questBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(22,22,28) }):Play()
end)

questBtn.MouseButton1Down:Connect(function() TweenService:Create(questBtn, TweenInfo.new(0.1), { Size = UDim2.new(0,40,0,40) }):Play() end)
questBtn.MouseButton1Up:Connect(function() TweenService:Create(questBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0,46,0,46) }):Play() end)

local questBtnLabel = Instance.new("TextLabel")
questBtnLabel.Size = UDim2.new(1,10,0,14); questBtnLabel.Position = UDim2.new(0,-5,1,5)
questBtnLabel.BackgroundTransparency = 1; questBtnLabel.Text = "Quests"
questBtnLabel.TextColor3 = Color3.fromRGB(165,165,165); questBtnLabel.TextSize = 11
questBtnLabel.Font = Enum.Font.GothamMedium; questBtnLabel.ZIndex = 5; questBtnLabel.Parent = questBtn

questNotifBadge = Instance.new("Frame")
questNotifBadge.Size = UDim2.new(0,18,0,18); questNotifBadge.Position = UDim2.new(1,-5,0,-5)
questNotifBadge.AnchorPoint = Vector2.new(1,0); questNotifBadge.BackgroundColor3 = Color3.fromRGB(220,55,55)
questNotifBadge.BorderSizePixel = 0; questNotifBadge.Visible = false; questNotifBadge.ZIndex = 6; questNotifBadge.Parent = questBtn
Instance.new("UICorner", questNotifBadge).CornerRadius = UDim.new(1,0)

local badgeNum = Instance.new("TextLabel", questNotifBadge)
badgeNum.Size = UDim2.new(1,0,1,0); badgeNum.BackgroundTransparency = 1; badgeNum.Text = "1"
badgeNum.TextColor3 = Color3.fromRGB(255,255,255); badgeNum.TextSize = 12
badgeNum.Font = Enum.Font.GothamBold; badgeNum.ZIndex = 7

local questFrame = Instance.new("Frame")
questFrame.Size = UDim2.new(0,300,0,332); questFrame.Position = UDim2.new(1,10,0,0)
questFrame.BackgroundColor3 = Color3.fromRGB(16,16,18); questFrame.BorderSizePixel = 0
questFrame.Visible = false; questFrame.ZIndex = 5; questFrame.ClipsDescendants = false; questFrame.Parent = guiFrame
Instance.new("UICorner", questFrame).CornerRadius = UDim.new(0,14)
local questFrameStroke = Instance.new("UIStroke", questFrame)
questFrameStroke.Color = Color3.fromRGB(44,44,50); questFrameStroke.Thickness = 1.5

local questXBtn = Instance.new("TextButton")
questXBtn.Size = UDim2.new(0,28,0,28); questXBtn.Position = UDim2.new(1,-38,0,10)
questXBtn.BackgroundColor3 = Color3.fromRGB(38,38,44); questXBtn.BorderSizePixel = 0
questXBtn.Text = "X"; questXBtn.TextColor3 = Color3.fromRGB(175,175,175); questXBtn.TextSize = 13
questXBtn.Font = Enum.Font.GothamBold; questXBtn.ZIndex = 6; questXBtn.Parent = questFrame
Instance.new("UICorner", questXBtn).CornerRadius = UDim.new(0,7)
Instance.new("UIStroke", questXBtn).Color = Color3.fromRGB(60,60,68)

questXBtn.MouseEnter:Connect(function()
    TweenService:Create(questXBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(55,55,62) }):Play()
end)
questXBtn.MouseLeave:Connect(function()
    TweenService:Create(questXBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(38,38,44) }):Play()
end)
questXBtn.MouseButton1Click:Connect(function()
    questFrame.Visible = false; questBtn.Visible = true; questBtnLabel.Visible = true
end)
questBtn.MouseButton1Click:Connect(function()
    questFrame.Visible = true; questBtn.Visible = false; questBtnLabel.Visible = false
end)

local hideNameBtn = Instance.new("TextButton")
hideNameBtn.Size = UDim2.new(0, 148, 0, 28)
hideNameBtn.Position = UDim2.new(1, 10, 0, 48)
hideNameBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28); hideNameBtn.BorderSizePixel = 0
hideNameBtn.Text = "Hide Display Name"
hideNameBtn.TextColor3 = Color3.fromRGB(160, 160, 175); hideNameBtn.TextSize = 11
hideNameBtn.Font = Enum.Font.GothamMedium; hideNameBtn.ClipsDescendants = true; hideNameBtn.ZIndex = 8; hideNameBtn.Parent = questFrame
Instance.new("UICorner", hideNameBtn).CornerRadius = UDim.new(0, 8)
local hideNameStroke = Instance.new("UIStroke", hideNameBtn)
hideNameStroke.Color = Color3.fromRGB(44, 44, 55); hideNameStroke.Thickness = 1.5

local hideNameTooltipGui = Instance.new("ScreenGui")
hideNameTooltipGui.Name = "HideNameTooltip"; hideNameTooltipGui.DisplayOrder = 300000
hideNameTooltipGui.IgnoreGuiInset = true; hideNameTooltipGui.ResetOnSpawn = false; hideNameTooltipGui.Parent = player.PlayerGui

local hideNameTooltipLabel = Instance.new("TextLabel")
hideNameTooltipLabel.Size = UDim2.new(0, 155, 0, 28); hideNameTooltipLabel.AnchorPoint = Vector2.new(0, 1)
hideNameTooltipLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 26); hideNameTooltipLabel.BorderSizePixel = 0
hideNameTooltipLabel.Text = "Hides Display Name"
hideNameTooltipLabel.TextColor3 = Color3.fromRGB(200, 200, 215); hideNameTooltipLabel.TextSize = 12
hideNameTooltipLabel.Font = Enum.Font.GothamMedium; hideNameTooltipLabel.Visible = false; hideNameTooltipLabel.ZIndex = 20; hideNameTooltipLabel.Parent = hideNameTooltipGui
Instance.new("UICorner", hideNameTooltipLabel).CornerRadius = UDim.new(0, 6)
local hnts = Instance.new("UIStroke", hideNameTooltipLabel)
hnts.Color = Color3.fromRGB(55, 55, 70); hnts.Thickness = 1

local hideNameHovering = false
RunService.RenderStepped:Connect(function()
    if hideNameHovering then
        hideNameTooltipLabel.Position = UDim2.new(0, mouse.X + 14, 0, mouse.Y - 6)
    end
end)

hideNameBtn.MouseEnter:Connect(function()
    hideNameHovering = true; hideNameTooltipLabel.Visible = true
    if not hideDisplayName then
        TweenService:Create(hideNameBtn, TweenInfo.new(0.18), { BackgroundColor3 = Color3.fromRGB(30, 30, 40) }):Play()
    end
end)
hideNameBtn.MouseLeave:Connect(function()
    hideNameHovering = false; hideNameTooltipLabel.Visible = false
    if not hideDisplayName then
        TweenService:Create(hideNameBtn, TweenInfo.new(0.18), { BackgroundColor3 = Color3.fromRGB(22, 22, 28) }):Play()
    end
end)

hideNameBtn.MouseButton1Click:Connect(function()
    hideDisplayName = not hideDisplayName
    if hideDisplayName then
        hideNameBtn.Text = "Show Display Name"
        hideNameBtn.TextColor3 = Color3.fromRGB(255, 105, 105)
        hideNameStroke.Color = Color3.fromRGB(160, 50, 50)
        hideNameBtn.BackgroundColor3 = Color3.fromRGB(50, 18, 18)
    else
        hideNameBtn.Text = "Hide Display Name"
        hideNameBtn.TextColor3 = Color3.fromRGB(160, 160, 175)
        hideNameStroke.Color = Color3.fromRGB(44, 44, 55)
        hideNameBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    end
    local ripple = Instance.new("Frame")
    ripple.Size = UDim2.new(0,0,0,0); ripple.Position = UDim2.new(0.5,0,0.5,0)
    ripple.AnchorPoint = Vector2.new(0.5,0.5); ripple.BackgroundColor3 = Color3.fromRGB(255,255,255)
    ripple.BackgroundTransparency = 0.55; ripple.BorderSizePixel = 0; ripple.ZIndex = 10; ripple.Parent = hideNameBtn
    Instance.new("UICorner", ripple).CornerRadius = UDim.new(1,0)
    local rt = TweenService:Create(ripple, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(3,0,3,0), BackgroundTransparency = 1 })
    rt:Play(); rt.Completed:Connect(function() ripple:Destroy() end)
end)

local questTitle = Instance.new("TextLabel")
questTitle.Size = UDim2.new(1,-50,0,28); questTitle.Position = UDim2.new(0,12,0,10)
questTitle.BackgroundTransparency = 1; questTitle.Text = "Your Quests"
questTitle.TextColor3 = Color3.fromRGB(255,255,255); questTitle.TextSize = 19
questTitle.Font = Enum.Font.GothamBold; questTitle.TextXAlignment = Enum.TextXAlignment.Left; questTitle.ZIndex = 6; questTitle.Parent = questFrame

local questTitleGrad = Instance.new("UIGradient")
questTitleGrad.Color = IS_SALTFLATS and ColorSequence.new{ ColorSequenceKeypoint.new(0, Color3.fromRGB(235,190,80)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,230,130)), ColorSequenceKeypoint.new(1, Color3.fromRGB(235,190,80)) }
or ColorSequence.new{ ColorSequenceKeypoint.new(0, Color3.fromRGB(90,150,255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160,210,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(90,150,255)) }
questTitleGrad.Offset = Vector2.new(-1,0); questTitleGrad.Parent = questTitle
spawn(function()
    while questTitle.Parent do
        local t = TweenService:Create(questTitleGrad, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1,0) })
        t:Play(); t.Completed:Wait(); questTitleGrad.Offset = Vector2.new(-1,0); wait(0.5)
    end
end)

local questDesc = Instance.new("TextLabel")
questDesc.Size = UDim2.new(1,-20,0,20); questDesc.Position = UDim2.new(0,10,0,40)
questDesc.BackgroundTransparency = 1; questDesc.Text = "Complete Quests for cool rewards!"
questDesc.TextColor3 = Color3.fromRGB(155,155,155); questDesc.TextSize = 13
questDesc.Font = Enum.Font.Gotham; questDesc.TextXAlignment = Enum.TextXAlignment.Left; questDesc.ZIndex = 6; questDesc.Parent = questFrame

local questDiv1 = Instance.new("Frame"); questDiv1.Size = UDim2.new(1,-20,0,1); questDiv1.Position = UDim2.new(0,10,0,84)
questDiv1.BackgroundColor3 = Color3.fromRGB(36,36,42); questDiv1.BorderSizePixel = 0; questDiv1.ZIndex = 6; questDiv1.Parent = questFrame

questTaskLabel = Instance.new("TextLabel")
questTaskLabel.Size = UDim2.new(1,-20,0,22); questTaskLabel.Position = UDim2.new(0,10,0,93)
questTaskLabel.BackgroundTransparency = 1; questTaskLabel.Text = "Task: Loading..."
questTaskLabel.TextColor3 = Color3.fromRGB(255,255,255); questTaskLabel.TextSize = 15
questTaskLabel.Font = Enum.Font.GothamBold; questTaskLabel.TextXAlignment = Enum.TextXAlignment.Left
questTaskLabel.RichText = true; questTaskLabel.ZIndex = 6; questTaskLabel.Parent = questFrame

questProgressLabel = Instance.new("TextLabel")
questProgressLabel.Size = UDim2.new(1,-20,0,20); questProgressLabel.Position = UDim2.new(0,10,0,117)
questProgressLabel.BackgroundTransparency = 1; questProgressLabel.Text = ""
questProgressLabel.TextColor3 = Color3.fromRGB(160,160,160); questProgressLabel.TextSize = 13
questProgressLabel.Font = Enum.Font.Gotham; questProgressLabel.TextXAlignment = Enum.TextXAlignment.Left; questProgressLabel.ZIndex = 6; questProgressLabel.Parent = questFrame

questEtaLabel = Instance.new("TextLabel")
questEtaLabel.Size = UDim2.new(1,-20,0,18); questEtaLabel.Position = UDim2.new(0,10,0,139)
questEtaLabel.BackgroundTransparency = 1; questEtaLabel.Text = "Est. Time: calculating..."
questEtaLabel.TextColor3 = Color3.fromRGB(120,120,120); questEtaLabel.TextSize = 12
questEtaLabel.Font = Enum.Font.Gotham; questEtaLabel.TextXAlignment = Enum.TextXAlignment.Left
questEtaLabel.Visible = true; questEtaLabel.ZIndex = 6; questEtaLabel.Parent = questFrame

questClaimButton = Instance.new("TextButton")
questClaimButton.Size = UDim2.new(1,-20,0,46); questClaimButton.Position = UDim2.new(0,10,0,162)
questClaimButton.BackgroundColor3 = IS_SALTFLATS and Color3.fromRGB(180,130,40) or Color3.fromRGB(60,120,220)
questClaimButton.BorderSizePixel = 0; questClaimButton.Text = "Claim +1 Speed"
questClaimButton.TextColor3 = Color3.fromRGB(255,255,255); questClaimButton.TextSize = 16
questClaimButton.Font = Enum.Font.GothamBold; questClaimButton.Visible = false
questClaimButton.ClipsDescendants = true; questClaimButton.ZIndex = 6; questClaimButton.Parent = questFrame
Instance.new("UICorner", questClaimButton).CornerRadius = UDim.new(0,10)

local claimGradient = Instance.new("UIGradient", questClaimButton)
claimGradient.Color = IS_SALTFLATS and ColorSequence.new{ ColorSequenceKeypoint.new(0, Color3.fromRGB(210,155,50)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(245,195,80)), ColorSequenceKeypoint.new(1, Color3.fromRGB(210,155,50)) }
or ColorSequence.new{ ColorSequenceKeypoint.new(0, Color3.fromRGB(70,130,235)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110,170,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(70,130,235)) }
claimGradient.Rotation = 90

questClaimButton.MouseButton1Click:Connect(function()
    if not questCompleted then return end
    questSpeedBonus = questSpeedBonus + 1; questTotalCompleted = questTotalCompleted + 1
    questCompleted = false; questCooldownEnd = tick() + 1800; questShineLoop = nil
    questClaimButton.Visible = false; questCooldownLabel.Visible = true
    if questEtaLabel then questEtaLabel.Visible = false end
    if questNotifBadge then questNotifBadge.Visible = false end
    local ripple = Instance.new("Frame")
    ripple.Size = UDim2.new(0,0,0,0); ripple.Position = UDim2.new(0.5,0,0.5,0)
    ripple.AnchorPoint = Vector2.new(0.5,0.5); ripple.BackgroundColor3 = Color3.fromRGB(255,255,255)
    ripple.BackgroundTransparency = 0.55; ripple.BorderSizePixel = 0; ripple.ZIndex = 10; ripple.Parent = questClaimButton
    Instance.new("UICorner", ripple).CornerRadius = UDim.new(1,0)
    local rt = TweenService:Create(ripple, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(2,0,2,0), BackgroundTransparency = 1 })
    rt:Play(); rt.Completed:Connect(function() ripple:Destroy() end)
    updateQuestUI(); saveData()
end)

questCooldownLabel = Instance.new("TextLabel")
questCooldownLabel.Size = UDim2.new(1,-20,0,46); questCooldownLabel.Position = UDim2.new(0,10,0,162)
questCooldownLabel.BackgroundTransparency = 1; questCooldownLabel.Text = "Another task will appear in: 30:00"
questCooldownLabel.TextColor3 = Color3.fromRGB(160,160,160); questCooldownLabel.TextSize = 14
questCooldownLabel.Font = Enum.Font.GothamMedium; questCooldownLabel.TextWrapped = true
questCooldownLabel.Visible = false; questCooldownLabel.ZIndex = 6; questCooldownLabel.Parent = questFrame

local questDiv2 = Instance.new("Frame"); questDiv2.Size = UDim2.new(1,-20,0,1); questDiv2.Position = UDim2.new(0,10,0,218)
questDiv2.BackgroundColor3 = Color3.fromRGB(36,36,42); questDiv2.BorderSizePixel = 0; questDiv2.ZIndex = 6; questDiv2.Parent = questFrame

questTotalLabel = Instance.new("TextLabel")
questTotalLabel.Size = UDim2.new(1,-20,0,20); questTotalLabel.Position = UDim2.new(0,10,0,228)
questTotalLabel.BackgroundTransparency = 1; questTotalLabel.Text = "Total Quests Completed: 0"
questTotalLabel.TextColor3 = Color3.fromRGB(200,200,200); questTotalLabel.TextSize = 14
questTotalLabel.Font = Enum.Font.GothamMedium; questTotalLabel.TextXAlignment = Enum.TextXAlignment.Left; questTotalLabel.ZIndex = 6; questTotalLabel.Parent = questFrame

local speedHoverFrame = Instance.new("Frame")
speedHoverFrame.Size = UDim2.new(0, 230, 0, 26); speedHoverFrame.Position = UDim2.new(0, 10, 0, 251)
speedHoverFrame.BackgroundTransparency = 1; speedHoverFrame.ZIndex = 6; speedHoverFrame.Parent = questFrame

questSpeedLabel = Instance.new("TextLabel")
questSpeedLabel.Size = UDim2.new(1, 0, 1, 0); questSpeedLabel.BackgroundTransparency = 1
questSpeedLabel.Text = "Speed Bonus: +0"; questSpeedLabel.TextColor3 = Color3.fromRGB(255,255,255)
questSpeedLabel.TextSize = 14; questSpeedLabel.Font = Enum.Font.GothamBold; questSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left; questSpeedLabel.ZIndex = 6; questSpeedLabel.Parent = speedHoverFrame

local speedLabelGrad = Instance.new("UIGradient")
speedLabelGrad.Color = ColorSequence.new{ ColorSequenceKeypoint.new(0, Color3.fromRGB(100,255,160)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160,255,200)), ColorSequenceKeypoint.new(1, Color3.fromRGB(100,255,160)) }
speedLabelGrad.Offset = Vector2.new(-1,0); speedLabelGrad.Parent = questSpeedLabel
spawn(function()
    while questSpeedLabel.Parent do
        local t = TweenService:Create(speedLabelGrad, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1,0) })
        t:Play(); t.Completed:Wait(); speedLabelGrad.Offset = Vector2.new(-1,0); wait(0.5)
    end
end)

local speedBreakdownLabel = Instance.new("TextLabel")
speedBreakdownLabel.Size = UDim2.new(0, 240, 0, 20); speedBreakdownLabel.Position = UDim2.new(0, 0, 1, 3)
speedBreakdownLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 26); speedBreakdownLabel.TextColor3 = Color3.fromRGB(180, 255, 200)
speedBreakdownLabel.TextSize = 12; speedBreakdownLabel.Font = Enum.Font.GothamMedium; speedBreakdownLabel.TextXAlignment = Enum.TextXAlignment.Left
speedBreakdownLabel.Visible = false; speedBreakdownLabel.ZIndex = 15; speedBreakdownLabel.BorderSizePixel = 0; speedBreakdownLabel.Parent = speedHoverFrame
Instance.new("UICorner", speedBreakdownLabel).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", speedBreakdownLabel).Color = Color3.fromRGB(55, 55, 70)
local sbl_pad = Instance.new("UIPadding", speedBreakdownLabel)
sbl_pad.PaddingLeft = UDim.new(0, 8)

speedHoverFrame.MouseEnter:Connect(function()
    speedBreakdownLabel.Text = "Quest Boost: " .. questSpeedBonus
    speedBreakdownLabel.Visible = true
end)
speedHoverFrame.MouseLeave:Connect(function()
    speedBreakdownLabel.Visible = false
end)

updateQuestUI()
if questCompleted and questCooldownEnd == 0 then startQuestShine() end

-- Main Loop Spawn
spawn(function()
    local lastKnownCash = 0
    local lastTimerSec = -1
    while wait(0.1) do
        local now = tick()
        if autoFarmActive and uiElements then
            local elapsed = now - farmStartTime
            local elapsedSec = math.floor(elapsed)
            if elapsedSec ~= lastTimerSec then
                lastTimerSec = elapsedSec
                uiElements.timeLabel.Text = formatTime(elapsedSec)
                uiElements.timeLabel.TextColor3 = Color3.fromRGB(255,255,255)
                if elapsedSec > longestAFKSeconds then 
                    longestAFKSeconds = elapsedSec
                    updateLongestAFKUI() 
                end
                if not allQuestsDone and questCooldownEnd == 0 and not questCompleted then
                    local q = QUESTS[questIndex]
                    if q and q.type == "time" then
                        questProgress = questProgress + 1
                        updateQuestUI()
                        if questProgress >= q.target then markQuestComplete() end
                    end
                end
            end
            questFarmSeconds = questFarmSeconds + 1; updateQuestEta()
            local ok, cashVal = pcall(function() return player.leaderstats.Cash.Value end)
            if ok then
                local gained = math.max(0, cashVal - lastKnownCash)
                if gained > 0 and lastKnownCash > 0 then
                    allTimeMoney = allTimeMoney + gained
                    updateAllTimeUI(); updateAllTimeGradient()
                    local sessionEarned = math.max(0, cashVal - farmStartCash)
                    uiElements.cashEarnedLabel.Text = "$" .. formatNumber(sessionEarned)
                    updateCashGradient(sessionEarned)
                    spawn(popCashLabel); updatePerSecondEarnings(gained)
                    if not allQuestsDone and questCooldownEnd == 0 and not questCompleted then
                        local q = QUESTS[questIndex]
                        if q and q.type == "earn" then
                            questProgress = questProgress + gained
                            updateQuestUI()
                            if questProgress >= q.target then markQuestComplete() end
                        end
                    end
                end
                lastKnownCash = cashVal
            end
            if elapsedSec % 30 == 0 then saveData() end
        elseif not autoFarmActive then
            lastTimerSec = -1
        end
        if questCooldownEnd > 0 then
            if now >= questCooldownEnd then
                questCooldownEnd = 0
                if questIndex >= #QUESTS then
                    allQuestsDone = true; questCompleted = false
                    updateQuestUI(); saveData()
                else
                    pickNewQuest(); saveData()
                end
            else
                if questCooldownLabel then
                    questCooldownLabel.Text = "Another task will appear in: " .. formatCooldown(questCooldownEnd - now)
                end
            end
        end
    end
end)

-- Auto Farm Logic
local function isPlayerSeated()
    local char = player.Character
    if char then 
        local hum = char:FindFirstChild("Humanoid")
        if hum and hum.SeatPart then return true end 
    end
    return false
end

local function stabilizeCar(car)
    if carStabilizationConnection then carStabilizationConnection:Disconnect() end
    carStabilizationConnection = RunService.Heartbeat:Connect(function()
        if not autoFarmActive or not car.Parent or not car.PrimaryPart then
            if carStabilizationConnection then 
                carStabilizationConnection:Disconnect(); carStabilizationConnection = nil 
            end
            return
        end
        local cf = car.PrimaryPart.CFrame; local pos, look = cf.Position, cf.LookVector
        car.PrimaryPart.CFrame = car.PrimaryPart.CFrame:Lerp(CFrame.new(pos, pos + Vector3.new(look.X, 0, look.Z)), 0.15)
        car.PrimaryPart.AssemblyAngularVelocity = Vector3.new(0, car.PrimaryPart.AssemblyAngularVelocity.Y * 0.5, 0)
    end)
end

local function smoothNavigateToCar(car, targetPos, maxSpeed)
    local curSpeed = maxSpeed * 0.4
    while autoFarmActive and isPlayerSeated() do
        if not car.Parent or not car.PrimaryPart then break end
        local currentPos = car.PrimaryPart.Position
        local distance = (targetPos - currentPos).Magnitude
        if distance < 50 then break end
        curSpeed = math.min(curSpeed + (maxSpeed * 0.02), maxSpeed)
        local direction = (targetPos - currentPos).Unit
        car.PrimaryPart.AssemblyLinearVelocity = car.PrimaryPart.AssemblyLinearVelocity:Lerp(direction * curSpeed, 0.1)
        local smoothedLook = car.PrimaryPart.CFrame.LookVector:Lerp(Vector3.new(direction.X, 0, direction.Z).Unit, 0.12)
        car.PrimaryPart.CFrame = car.PrimaryPart.CFrame:Lerp(CFrame.new(currentPos, currentPos + smoothedLook), 0.25)
        local floorY = IS_SALTFLATS and -13 or -30
        local resetY = IS_SALTFLATS and -7 or -17
        if currentPos.Y < floorY then 
            car.PrimaryPart.CFrame = CFrame.new(currentPos.X, resetY, currentPos.Z) 
        end
        task.wait()
    end
end

local function endFarmSession()
    local elapsed = tick() - farmStartTime
    if elapsed > longestAFKSeconds then 
        longestAFKSeconds = elapsed
        updateLongestAFKUI() 
    end
    saveData()
end

spawn(function()
    while wait(0.5) do
        if autoFarmActive and not isPlayerSeated() then
            autoFarmActive = false; autoFarmToggle.Text = "Start AutoFarm"
            toggleStroke.Color = Color3.fromRGB(70,140,220)
            toggleGlow.ImageColor3 = Color3.fromRGB(70,140,220)
            statusText.Text = "Status: Left seat"
            statusText.TextColor3 = Color3.fromRGB(175,175,175)
            endFarmSession()
            if uiElements then
                uiElements.afkRewards.Visible = false
                uiElements.teleportButton.Visible = true
                uiElements.rewardsButton.Visible = true
                local eg = uiElements.cashEarnedLabel:FindFirstChild("MilestoneGradient")
                if eg then eg:Destroy() end
                currentMilestone = 0
            end
            if carStabilizationConnection then 
                carStabilizationConnection:Disconnect(); carStabilizationConnection = nil 
            end
            toggleGradient.Color = ColorSequence.new{ ColorSequenceKeypoint.new(0, Color3.fromRGB(52,52,57)), ColorSequenceKeypoint.new(1, Color3.fromRGB(32,32,36)) }
        end
    end
end)

autoFarmToggle.MouseButton1Click:Connect(function()
    local ripple = Instance.new("Frame")
    ripple.Size = UDim2.new(0,0,0,0); ripple.Position = UDim2.new(0.5,0,0.5,0)
    ripple.AnchorPoint = Vector2.new(0.5,0.5); ripple.BackgroundColor3 = Color3.fromRGB(255,255,255)
    ripple.BackgroundTransparency = 0.55; ripple.BorderSizePixel = 0; ripple.ZIndex = 10; ripple.Parent = autoFarmToggle
    Instance.new("UICorner", ripple).CornerRadius = UDim.new(1,0)
    local rt = TweenService:Create(ripple, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(2,0,2,0), BackgroundTransparency = 1 })
    rt:Play(); rt.Completed:Connect(function() ripple:Destroy() end)
    TweenService:Create(autoFarmToggle, TweenInfo.new(0.1), { Size = UDim2.new(1,-24,0,54) }):Play()
    wait(0.1); TweenService:Create(autoFarmToggle, TweenInfo.new(0.2, Enum.EasingStyle.Elastic), { Size = UDim2.new(1,-20,0,58) }):Play()

    if not autoFarmActive and not isPlayerSeated() then
        statusText.Text = "Status: Sit in a vehicle first"
        statusText.TextColor3 = Color3.fromRGB(255,130,130); return
    end

    autoFarmActive = not autoFarmActive
    if autoFarmActive then
        autoFarmToggle.Text = "Stop AutoFarm"
        toggleStroke.Color = Color3.fromRGB(100,255,150)
        toggleGlow.ImageColor3 = Color3.fromRGB(100,255,150)
        statusText.Text = "Status: Running"
        statusText.TextColor3 = Color3.fromRGB(100,255,150)
        farmStartCash = player.leaderstats.Cash.Value
        farmStartTime = tick()
        lastCashAmount = farmStartCash
        totalCashEarned = 0
        if uiElements then
            uiElements.afkRewards.Visible = true
            uiElements.cashEarnedLabel.Text = "$0"
            uiElements.timeLabel.Text = "00:00:00"
            uiElements.timeLabel.TextColor3 = Color3.fromRGB(255,255,255)
            uiElements.teleportButton.Visible = false
            uiElements.rewardsButton.Visible = false
        end
        toggleGradient.Color = ColorSequence.new{ ColorSequenceKeypoint.new(0, Color3.fromRGB(26,74,36)), ColorSequenceKeypoint.new(1, Color3.fromRGB(17,54,26)) }
       spawn(function()
            while autoFarmActive do
                for _, v in pairs(workspace:GetChildren()) do
                    if v:IsA("Model") and (v:FindFirstChild("Container") or v.Name == "PortCraneOversized") then 
                        v:Destroy() 
                    end
                end; wait(1)
            end
        end)
        spawn(function()
            while autoFarmActive do
                if not isPlayerSeated() then break end
                local hum = player.Character.Humanoid
                local car = hum.SeatPart:FindFirstAncestorWhichIsA("Model")
                if not car then break end
                local primary = (car:FindFirstChild("Body") and car.Body:FindFirstChild("#Weight")) or car.PrimaryPart
                if not primary then break end
                car.PrimaryPart = primary

                if workspace:FindFirstChild("Workspace") and workspace.Workspace:FindFirstChild("Buildings") then 
                    workspace.Workspace.Buildings:Destroy() 
                end
                for _, part in pairs(car:GetDescendants()) do
                    if part:IsA("BasePart") then 
                        part.CustomPhysicalProperties = PhysicalProperties.new(0.7,0.3,0.5,100,1) 
                    end
                end
                car.PrimaryPart.Anchored = true
                car:PivotTo(CFrame.new(WAYPOINTS[1])); wait(0.15)
                car.PrimaryPart.Anchored = false
                car.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
                car.PrimaryPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
                stabilizeCar(car); wait(0.3)
                for waypointIndex = 2, #WAYPOINTS do
                    if not autoFarmActive or not isPlayerSeated() then break end
                    local baseSpeed = 460
                    local carSpeed = baseSpeed + (questSpeedBonus * 3)
                    smoothNavigateToCar(car, WAYPOINTS[waypointIndex], carSpeed)
                end
                if autoFarmActive and isPlayerSeated() then
                    if not allQuestsDone and questCooldownEnd == 0 and not questCompleted then
                        local q = QUESTS[questIndex]
                        if q and q.type == "loops" then
                            questLoopCount = questLoopCount + 1
                            questProgress = questLoopCount
                            updateQuestUI()
                            if questProgress >= q.target then markQuestComplete() end
                        end
                    end
                end
                if not autoFarmActive then break end
            end
            if carStabilizationConnection then 
                carStabilizationConnection:Disconnect(); carStabilizationConnection = nil 
            end
        end)
    else
        autoFarmToggle.Text = "Start AutoFarm"
        toggleStroke.Color = Color3.fromRGB(70,140,220)
        toggleGlow.ImageColor3 = Color3.fromRGB(70,140,220)
        statusText.Text = "Status: Stopped"
        statusText.TextColor3 = Color3.fromRGB(175,175,175)
        endFarmSession()
        if uiElements then
            uiElements.afkRewards.Visible = false
            uiElements.teleportButton.Visible = true
            uiElements.rewardsButton.Visible = true
            local eg = uiElements.cashEarnedLabel:FindFirstChild("MilestoneGradient")
            if eg then eg:Destroy() end
            currentMilestone = 0
        end
        toggleGradient.Color = ColorSequence.new{ ColorSequenceKeypoint.new(0, Color3.fromRGB(52,52,57)), ColorSequenceKeypoint.new(1, Color3.fromRGB(32,32,36)) }
        if carStabilizationConnection then 
            carStabilizationConnection:Disconnect(); carStabilizationConnection = nil 
        end
    end
end)

-- Dragging Logic
local dragging, dragInput, dragStart, startPos
local dragConnection
guiFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = guiFrame.Position
        if dragConnection then dragConnection:Disconnect() end
        dragConnection = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then 
                dragging = false 
                if dragConnection then 
                    dragConnection:Disconnect(); dragConnection = nil 
                end
            end 
        end)
    end
end)

guiFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then 
        dragInput = input 
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        guiFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
