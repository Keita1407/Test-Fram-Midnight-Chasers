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
end

local function saveData()
    pcall(writefile, SAVE_FILE, HttpService:JSONEncode({
        allTime = allTimeMoney,
        longestAFK = longestAFKSeconds,
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
        local g = getMilestoneGradient(amount)
        if g then applyCashGradient(uiElements.cashEarnedLabel, g) end
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
toggleStroke.Color = Color3.fromRGB(70,140,220); toggleStroke.Thickness = 2.5
toggleStroke.Transparency = 0.3
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

local hideNameBtn = Instance.new("TextButton")
hideNameBtn.Size = UDim2.new(0, 148, 0, 28)
hideNameBtn.Position = UDim2.new(0, 12, 1, -28)
hideNameBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28); hideNameBtn.BorderSizePixel = 0
hideNameBtn.Text = "Hide Display Name"
hideNameBtn.TextColor3 = Color3.fromRGB(160, 160, 175); hideNameBtn.TextSize = 11
hideNameBtn.Font = Enum.Font.GothamMedium; hideNameBtn.ClipsDescendants = true; hideNameBtn.ZIndex = 8
hideNameBtn.Parent = guiFrame
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
hideNameTooltipLabel.Font = Enum.Font.GothamMedium; hideNameTooltipLabel.Visible = false; hideNameTooltipLabel.ZIndex = 20
hideNameTooltipLabel.Parent = hideNameTooltipGui
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
            end
        end
        
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
            end
            lastKnownCash = cashVal
        end
        if elapsedSec and elapsedSec % 30 == 0 then saveData() end
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
                    local baseSpeed = 736
                    local carSpeed = baseSpeed
                    smoothNavigateToCar(car, WAYPOINTS[waypointIndex], carSpeed)
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
