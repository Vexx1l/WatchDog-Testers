-- [[ WATCHDOG ULTIMATE HUB: HEARTBEAT + SHIELD FUSION ]] --
-- VERSION: 6.0 (TABBED UI REVOLUTION)

if not game:IsLoaded() then game.Loaded:Wait() end

-- 0. PREVENT DOUBLE EXECUTION
if _G.WatchdogRunning then 
    _G.WatchdogRunning = false 
    task.wait(0.5) 
end
_G.WatchdogRunning = true
local SESSION_ID = tick()
_G.CurrentSession = SESSION_ID

-- SERVICES
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

-- 1. DATA MANAGEMENT
local GLOBAL_FILE = "WatchdogHub_GLOBAL.json"
local LOCAL_FILE = "WatchdogHub_" .. player.Name .. ".json"

local function loadData(file, default)
    if isfile and isfile(file) then
        local s, d = pcall(function() return HttpService:JSONDecode(readfile(file)) end)
        if s then return d end
    end
    return default
end

local globalSet = loadData(GLOBAL_FILE, {LastBuild = "0"})
local mySettings = loadData(LOCAL_FILE, {Timer = 600, Webhook = "PASTE_WEBHOOK_HERE", UserID = "958143880291823647"})

-- 2. CORE VARIABLES
local HEARTBEAT_INTERVAL = mySettings.Timer
local WEBHOOK_URL = mySettings.Webhook:gsub("%s+", "")
local DISCORD_USER_ID = mySettings.UserID
local startTime = os.time()
local forceRestartLoop = false
local isBlocked = false
local blockExpires = 0

-- SHIELD CONFIG
local shieldActive = false 
local autoRejoin = false
local shieldBaseInterval = 300 
local shieldCurrentInterval = 300
local lastShieldAction = tick()

-- 3. CORE LOGIC FUNCTIONS
local function getUptimeString()
    local diff = os.time() - startTime
    local hours = math.floor(diff / 3600)
    local mins = math.floor((diff % 3600) / 60)
    local secs = diff % 60
    return string.format("%dh %dm %ds", hours, mins, secs)
end

local function sendWebhook(title, reason, color, isUpdateLog)
    if WEBHOOK_URL == "" or WEBHOOK_URL == "PASTE_WEBHOOK_HERE" or not _G.WatchdogRunning then return end
    if isBlocked and tick() < blockExpires then return end

    local embed = {
        title = title,
        color = color or 1752220,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    if isUpdateLog then
        embed.description = "**Change Log:**\n" .. reason .. "\n\n*Watchdog Ultimate Build 6.0*"
    else
        embed.description = "Status for **" .. player.Name .. "**"
        embed.fields = {
            { name = "🎮 Game", value = MarketplaceService:GetProductInfo(game.PlaceId).Name or "Unknown", inline = true },
            { name = "📊 Session Info", value = "Uptime: " .. getUptimeString(), inline = false },
            { name = "💬 Status", value = "```" .. reason .. "```", inline = false }
        }
    end
    
    local payload = HttpService:JSONEncode({ 
        content = (not isUpdateLog and title ~= "🔄 Heartbeat") and "<@" .. DISCORD_USER_ID .. ">" or nil, 
        embeds = {embed} 
    })
    
    local requestFunc = (request or http_request or syn.request or (http and http.request))
    if requestFunc then 
        task.spawn(function()
            local success, response = pcall(function()
                return requestFunc({Url = WEBHOOK_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
            end)
            if response and response.StatusCode == 429 then
                isBlocked = true
                blockExpires = tick() + (tonumber(response.Headers and response.Headers["retry-after"]) or 60)
            end
        end)
    end
end

-- 4. UI CONSTRUCTION (MODERN TABBED)
local screenGui = Instance.new("ScreenGui", (game:GetService("CoreGui") or player.PlayerGui))
screenGui.Name = "WatchdogUltimate"
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 300, 0, 380)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -190)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
local corner = Instance.new("UICorner", mainFrame)
local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color = Color3.fromRGB(0, 170, 255)
stroke.Thickness = 2

-- TOP BAR
local topBar = Instance.new("Frame", mainFrame)
topBar.Size = UDim2.new(1, 0, 0, 35)
topBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Instance.new("UICorner", topBar)

local title = Instance.new("TextLabel", topBar)
title.Size = UDim2.new(1, 0, 1, 0)
title.Text = "WATCHDOG ULTIMATE V6.0"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.BackgroundTransparency = 1
title.TextSize = 14

local closeBtn = Instance.new("TextButton", topBar)
closeBtn.Size = UDim2.new(0, 30, 0, 30); closeBtn.Position = UDim2.new(1, -35, 0, 2.5); closeBtn.Text = "✕"; closeBtn.TextColor3 = Color3.new(1, 0, 0); closeBtn.BackgroundTransparency = 1; closeBtn.TextSize = 20; closeBtn.Font = Enum.Font.GothamBold

local minBtn = Instance.new("TextButton", topBar)
minBtn.Size = UDim2.new(0, 30, 0, 30); minBtn.Position = UDim2.new(0, 5, 0, 2.5); minBtn.Text = "—"; minBtn.TextColor3 = Color3.new(0.5, 0.8, 1); minBtn.BackgroundTransparency = 1; minBtn.TextSize = 20; minBtn.Font = Enum.Font.GothamBold

-- NAVIGATION
local nav = Instance.new("Frame", mainFrame)
nav.Size = UDim2.new(1, -20, 0, 30); nav.Position = UDim2.new(0, 10, 0, 45); nav.BackgroundTransparency = 1

local heartbeatTabBtn = Instance.new("TextButton", nav)
heartbeatTabBtn.Size = UDim2.new(0.5, -5, 1, 0); heartbeatTabBtn.Text = "HEARTBEAT"; heartbeatTabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45); heartbeatTabBtn.TextColor3 = Color3.new(1,1,1); heartbeatTabBtn.Font = Enum.Font.GothamBold; heartbeatTabBtn.TextSize = 10
Instance.new("UICorner", heartbeatTabBtn)

local shieldTabBtn = Instance.new("TextButton", nav)
shieldTabBtn.Size = UDim2.new(0.5, -5, 1, 0); shieldTabBtn.Position = UDim2.new(0.5, 5, 0, 0); shieldTabBtn.Text = "SHIELD"; shieldTabBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30); shieldTabBtn.TextColor3 = Color3.new(0.6, 0.6, 0.6); shieldTabBtn.Font = Enum.Font.GothamBold; shieldTabBtn.TextSize = 10
Instance.new("UICorner", shieldTabBtn)

-- CONTAINERS
local hbPage = Instance.new("Frame", mainFrame)
hbPage.Size = UDim2.new(1, -20, 1, -90); hbPage.Position = UDim2.new(0, 10, 0, 80); hbPage.BackgroundTransparency = 1

local shieldPage = Instance.new("Frame", mainFrame)
shieldPage.Size = UDim2.new(1, -20, 1, -90); shieldPage.Position = UDim2.new(0, 10, 0, 80); shieldPage.BackgroundTransparency = 1; shieldPage.Visible = false

-- HEARTBEAT ELEMENTS
local timerLabel = Instance.new("TextLabel", hbPage)
timerLabel.Size = UDim2.new(1, 0, 0, 60); timerLabel.Text = "LOADING"; timerLabel.TextColor3 = Color3.fromRGB(0, 170, 255); timerLabel.BackgroundTransparency = 1; timerLabel.TextSize = 40; timerLabel.Font = Enum.Font.GothamBold

local function quickBtn(name, pos, color, parent)
    local b = Instance.new("TextButton", parent); b.Size = UDim2.new(0.48, 0, 0, 35); b.Position = pos; b.Text = name; b.BackgroundColor3 = Color3.fromRGB(35, 35, 50); b.TextColor3 = color; b.Font = Enum.Font.GothamBold; b.TextSize = 10; Instance.new("UICorner", b)
    return b
end

local hbTime = quickBtn("TIME", UDim2.new(0, 0, 0, 70), Color3.new(0, 1, 0.5), hbPage)
local hbCfg = quickBtn("CONFIG", UDim2.new(0.52, 0, 0, 70), Color3.new(1, 0.7, 0), hbPage)
local hbTest = quickBtn("TEST", UDim2.new(0, 0, 0, 115), Color3.new(1, 0.4, 1), hbPage)
local hbHub = quickBtn("HUB", UDim2.new(0.52, 0, 0, 115), Color3.new(0.7, 0.5, 1), hbPage)
local hbReset = quickBtn("RESET SYSTEM", UDim2.new(0, 0, 0, 160), Color3.new(1, 0.2, 0.2), hbPage)
hbReset.Size = UDim2.new(1,0,0,35)

-- SHIELD ELEMENTS
local shieldStatus = Instance.new("TextLabel", shieldPage)
shieldStatus.Size = UDim2.new(1, 0, 0, 50); shieldStatus.BackgroundColor3 = Color3.fromRGB(20, 20, 30); shieldStatus.TextColor3 = Color3.new(1,1,1); shieldStatus.TextSize = 12; shieldStatus.Font = Enum.Font.Code; shieldStatus.Text = "Status: STANDBY"; Instance.new("UICorner", shieldStatus)

local intervalBox = Instance.new("TextBox", shieldPage)
intervalBox.Size = UDim2.new(1, 0, 0, 35); intervalBox.Position = UDim2.new(0, 0, 0, 60); intervalBox.PlaceholderText = "Shield Interval (Seconds)"; intervalBox.Text = tostring(shieldBaseInterval); intervalBox.BackgroundColor3 = Color3.fromRGB(30, 30, 45); intervalBox.TextColor3 = Color3.new(0, 0.8, 1); Instance.new("UICorner", intervalBox)

local antiAfkBtn = quickBtn("ANTI-AFK: OFF", UDim2.new(0, 0, 0, 105), Color3.new(1,1,1), shieldPage)
local autoReBtn = quickBtn("AUTO-REJOIN: OFF", UDim2.new(0.52, 0, 0, 105), Color3.new(1,1,1), shieldPage)

local feed = Instance.new("ScrollingFrame", shieldPage)
feed.Size = UDim2.new(1, 0, 0, 120); feed.Position = UDim2.new(0, 0, 0, 150); feed.BackgroundColor3 = Color3.fromRGB(10, 10, 15); feed.CanvasSize = UDim2.new(0,0,0,0); Instance.new("UICorner", feed)
local layout = Instance.new("UIListLayout", feed)

-- 5. FUNCTIONALITY FUSION
local function logShield(msg, color)
    local l = Instance.new("TextLabel", feed); l.Size = UDim2.new(1, 0, 0, 18); l.Text = "[" .. os.date("%X") .. "] " .. msg; l.TextColor3 = color or Color3.new(0, 1, 0.8); l.BackgroundTransparency = 1; l.TextSize = 10; feed.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y); feed.CanvasPosition = Vector2.new(0, feed.CanvasSize.Y.Offset)
end

-- Tab Switching
heartbeatTabBtn.MouseButton1Click:Connect(function()
    hbPage.Visible = true; shieldPage.Visible = false
    heartbeatTabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45); shieldTabBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
end)
shieldTabBtn.MouseButton1Click:Connect(function()
    hbPage.Visible = false; shieldPage.Visible = true
    shieldTabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45); heartbeatTabBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
end)

-- Shield Logic
antiAfkBtn.MouseButton1Click:Connect(function()
    shieldActive = not shieldActive
    antiAfkBtn.Text = shieldActive and "ANTI-AFK: ACTIVE" or "ANTI-AFK: OFF"
    antiAfkBtn.BackgroundColor3 = shieldActive and Color3.fromRGB(0, 100, 50) or Color3.fromRGB(35, 35, 50)
    lastShieldAction = tick()
end)

autoReBtn.MouseButton1Click:Connect(function()
    autoRejoin = not autoRejoin
    autoReBtn.Text = autoRejoin and "REJOIN: ON" or "REJOIN: OFF"
    autoReBtn.BackgroundColor3 = autoRejoin and Color3.fromRGB(0, 80, 150) or Color3.fromRGB(35, 35, 50)
end)

-- Heartbeat Logic
hbTest.MouseButton1Click:Connect(function() sendWebhook("🧪 Test", "System fused and working!", 10181046, false) end)

-- Rejoin Handler
GuiService.ErrorMessageChanged:Connect(function()
    if autoRejoin then
        task.wait(3)
        TeleportService:Teleport(game.PlaceId, player)
    end
end)

-- Core Heartbeat Loop
task.spawn(function()
    sendWebhook("🔄 Heartbeat", "FUSION HUB ACTIVE.", 1752220, false)
    while _G.WatchdogRunning and _G.CurrentSession == SESSION_ID do
        local timeLeft = HEARTBEAT_INTERVAL
        while timeLeft > 0 and _G.WatchdogRunning and _G.CurrentSession == SESSION_ID do
            timerLabel.Text = string.format("%02d:%02d", math.floor(timeLeft/60), timeLeft%60)
            task.wait(1); timeLeft = timeLeft - 1
        end
        if _G.WatchdogRunning then sendWebhook("🔄 Heartbeat", "FUSION STABLE.", 1752220, false) end
    end
end)

-- Shield Movement Loop
task.spawn(function()
    while _G.WatchdogRunning do
        if shieldActive then
            local timeLeft = math.ceil(shieldCurrentInterval - (tick() - lastShieldAction))
            if timeLeft <= 0 then
                pcall(function()
                    local char = player.Character
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then 
                        hrp.CFrame = hrp.CFrame * CFrame.new(0, 0, 1)
                        task.wait(0.5)
                        hrp.CFrame = hrp.CFrame * CFrame.new(0, 0, -1)
                        logShield("Anti-AFK Movement Fired", Color3.new(1,1,0))
                    end
                end)
                lastShieldAction = tick()
                shieldCurrentInterval = shieldBaseInterval + math.random(-15, 15)
            end
            shieldStatus.Text = "Next Move: " .. timeLeft .. "s\nRejoin: " .. (autoRejoin and "ON" or "OFF")
        else
            shieldStatus.Text = "Status: STANDBY"
        end
        task.wait(1)
    end
end)

-- Draggable UI
local dragStart, startPos
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStart = input.Position; startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragStart = nil end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragStart then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Minimize/Close Logic
closeBtn.MouseButton1Click:Connect(function() _G.WatchdogRunning = false; screenGui:Destroy() end)
local isMin = false
minBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    hbPage.Visible = not isMin and (heartbeatTabBtn.BackgroundColor3 == Color3.fromRGB(30,30,45))
    shieldPage.Visible = not isMin and (shieldTabBtn.BackgroundColor3 == Color3.fromRGB(30,30,45))
    nav.Visible = not isMin
    mainFrame.Size = isMin and UDim2.new(0, 300, 0, 35) or UDim2.new(0, 300, 0, 380)
end)

logShield("Watchdog Fusion Loaded", Color3.new(1,1,1))
