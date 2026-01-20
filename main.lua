-- WATCHDOG SENTINEL ULTRA [FUSED BUILD 6.0]
-- Heartbeat v5.8.6 + Watchdog Shield v5.2

-- [[ 0. INITIALIZATION & AUTO-LOAD ]] --
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

-- Prevent Double Running
if _G.SentinelRunning then 
    _G.SentinelRunning = false 
    task.wait(0.5) 
end
_G.SentinelRunning = true
local SESSION_ID = tick()
_G.CurrentSession = SESSION_ID

-- [[ 1. CONFIGURATION & DATABASE ]] --
local LOCAL_FILE = "WatchdogSentinel_" .. player.Name .. ".json"
local function loadSettings()
    local default = {
        Timer = 600, 
        Webhook = "PASTE_WEBHOOK_HERE", 
        UserID = "958143880291823647",
        AntiAfkInterval = 300,
        AutoRejoin = false
    }
    if isfile and isfile(LOCAL_FILE) then
        local s, d = pcall(function() return HttpService:JSONDecode(readfile(LOCAL_FILE)) end)
        if s then return d end
    end
    return default
end

local mySettings = loadSettings()
local HEARTBEAT_INTERVAL = mySettings.Timer
local WEBHOOK_URL = mySettings.Webhook:gsub("%s+", "")
local DISCORD_USER_ID = mySettings.UserID
local startTime = os.time()

-- State Variables
local activeAntiAfk = false
local currentAfkInterval = mySettings.AntiAfkInterval
local lastAfkAction = tick()
local isBlocked = false
local blockExpires = 0

-- [[ 2. CORE WEBHOOK LOGIC (HEARTBEAT) ]] --
local function getUptimeString()
    local diff = os.time() - startTime
    return string.format("%dh %dm %ds", math.floor(diff/3600), math.floor((diff%3600)/60), diff%60)
end

local function sendWebhook(title, reason, color)
    if WEBHOOK_URL == "" or WEBHOOK_URL == "PASTE_WEBHOOK_HERE" or not _G.SentinelRunning then return end
    if isBlocked and tick() < blockExpires then return end

    local payload = HttpService:JSONEncode({
        content = (title ~= "🔄 Heartbeat") and "<@" .. DISCORD_USER_ID .. ">" or nil,
        embeds = {{
            title = title,
            color = color or 1752220,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            fields = {
                { name = "🎮 Game", value = MarketplaceService:GetProductInfo(game.PlaceId).Name or "Unknown", inline = true },
                { name = "📊 Session", value = "Uptime: " .. getUptimeString(), inline = true },
                { name = "💬 Status", value = "```" .. reason .. "```", inline = false }
            }
        }}
    })

    local requestFunc = (request or http_request or syn.request or (http and http.request))
    if requestFunc then
        task.spawn(function()
            local success, response = pcall(function()
                return requestFunc({Url = WEBHOOK_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
            end)
            if response and response.StatusCode == 429 then
                isBlocked = true
                blockExpires = tick() + (tonumber(response.Headers["retry-after"]) or 60)
            end
        end)
    end
end

-- [[ 3. CORE MOVEMENT LOGIC (WATCHDOG) ]] --
local function performMovement()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if hum and root then
        local startPos = root.Position
        hum:MoveTo(startPos + (root.CFrame.LookVector * 10))
        task.wait(2)
        hum:MoveTo(startPos)
    end
end

-- [[ 4. MODERN UI CONSTRUCTION ]] --
local screenGui = Instance.new("ScreenGui", (game:GetService("CoreGui") or player.PlayerGui))
screenGui.Name = "WatchdogSentinelUI"
screenGui.ResetOnSpawn = false

local main = Instance.new("Frame", screenGui)
main.Size = UDim2.new(0, 300, 0, 350)
main.Position = UDim2.new(0.5, -150, 0.5, -175)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke", main); stroke.Color = Color3.fromRGB(0, 170, 255); stroke.Thickness = 2

-- Top Bar
local topBar = Instance.new("Frame", main)
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundTransparency = 1

local title = Instance.new("TextLabel", topBar)
title.Size = UDim2.new(1, 0, 1, 0); title.Text = "WATCHDOG SENTINEL ULTRA"; title.TextColor3 = Color3.new(1,1,1); title.Font = Enum.Font.GothamBold; title.TextSize = 12; title.BackgroundTransparency = 1

local minBtn = Instance.new("TextButton", topBar)
minBtn.Size = UDim2.new(0, 30, 0, 30); minBtn.Position = UDim2.new(0, 5, 0, 5); minBtn.Text = "-"; minBtn.TextColor3 = Color3.new(0,1,1); minBtn.BackgroundTransparency = 1; minBtn.TextSize = 25

local closeBtn = Instance.new("TextButton", topBar)
closeBtn.Size = UDim2.new(0, 30, 0, 30); closeBtn.Position = UDim2.new(1, -35, 0, 5); closeBtn.Text = "✕"; closeBtn.TextColor3 = Color3.fromRGB(255, 80, 80); closeBtn.BackgroundTransparency = 1; closeBtn.TextSize = 18

-- Tab System
local tabFrame = Instance.new("Frame", main)
tabFrame.Size = UDim2.new(1, -20, 0, 30); tabFrame.Position = UDim2.new(0, 10, 0, 45); tabFrame.BackgroundTransparency = 1

local function createTabBtn(name, pos)
    local btn = Instance.new("TextButton", tabFrame)
    btn.Size = UDim2.new(0.3, 0, 1, 0); btn.Position = pos; btn.Text = name; btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40); btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.GothamBold; btn.TextSize = 10
    Instance.new("UICorner", btn)
    return btn
end

local t1 = createTabBtn("MONITOR", UDim2.new(0, 0, 0, 0))
local t2 = createTabBtn("SHIELD", UDim2.new(0.35, 0, 0, 0))
local t3 = createTabBtn("CONFIG", UDim2.new(0.7, 0, 0, 0))

-- Containers
local content = Instance.new("Frame", main)
content.Size = UDim2.new(1, -20, 1, -90); content.Position = UDim2.new(0, 10, 0, 80); content.BackgroundTransparency = 1

local monitorPage = Instance.new("Frame", content); monitorPage.Size = UDim2.new(1,0,1,0); monitorPage.BackgroundTransparency = 1
local shieldPage = Instance.new("Frame", content); shieldPage.Size = UDim2.new(1,0,1,0); shieldPage.BackgroundTransparency = 1; shieldPage.Visible = false
local configPage = Instance.new("ScrollingFrame", content); configPage.Size = UDim2.new(1,0,1,0); configPage.BackgroundTransparency = 1; configPage.Visible = false; configPage.CanvasSize = UDim2.new(0,0,1.5,0); configPage.ScrollBarThickness = 0

-- [[ 5. TAB: MONITOR (Heartbeat Features) ]] --
local timerDisp = Instance.new("TextLabel", monitorPage)
timerDisp.Size = UDim2.new(1, 0, 0, 60); timerDisp.Text = "00:00"; timerDisp.TextColor3 = Color3.fromRGB(0, 170, 255); timerDisp.TextSize = 40; timerDisp.Font = Enum.Font.GothamBold; timerDisp.BackgroundTransparency = 1

local testBtn = Instance.new("TextButton", monitorPage)
testBtn.Size = UDim2.new(0.9, 0, 0, 40); testBtn.Position = UDim2.new(0.05, 0, 0.4, 0); testBtn.Text = "SEND TEST HEARTBEAT"; testBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50); testBtn.TextColor3 = Color3.new(1,1,1); testBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", testBtn)

local hubBtn = Instance.new("TextButton", monitorPage)
hubBtn.Size = UDim2.new(0.9, 0, 0, 40); hubBtn.Position = UDim2.new(0.05, 0, 0.6, 0); hubBtn.Text = "COPY HUB LINKS"; hubBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50); hubBtn.TextColor3 = Color3.fromRGB(200, 100, 255); hubBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", hubBtn)

-- [[ 6. TAB: SHIELD (Watchdog Shield Features) ]] --
local shieldStats = Instance.new("TextLabel", shieldPage)
shieldStats.Size = UDim2.new(1, 0, 0, 60); shieldStats.Text = "Status: STANDBY\nRejoin: OFF"; shieldStats.TextColor3 = Color3.new(1,1,1); shieldStats.TextSize = 14; shieldStats.Font = Enum.Font.Code; shieldStats.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Instance.new("UICorner", shieldStats)

local afkToggle = Instance.new("TextButton", shieldPage)
afkToggle.Size = UDim2.new(0.9, 0, 0, 45); afkToggle.Position = UDim2.new(0.05, 0, 0.35, 0); afkToggle.Text = "ANTI-AFK: OFF"; afkToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50); afkToggle.TextColor3 = Color3.new(1,1,1); afkToggle.Font = Enum.Font.GothamBold
Instance.new("UICorner", afkToggle)

local rejoinToggle = Instance.new("TextButton", shieldPage)
rejoinToggle.Size = UDim2.new(0.9, 0, 0, 45); rejoinToggle.Position = UDim2.new(0.05, 0, 0.55, 0); rejoinToggle.Text = "AUTO-REJOIN: OFF"; rejoinToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50); rejoinToggle.TextColor3 = Color3.new(1,1,1); rejoinToggle.Font = Enum.Font.GothamBold
Instance.new("UICorner", rejoinToggle)

local afkTimeInput = Instance.new("TextBox", shieldPage)
afkTimeInput.Size = UDim2.new(0.9, 0, 0, 30); afkTimeInput.Position = UDim2.new(0.05, 0, 0.8, 0); afkTimeInput.PlaceholderText = "Movement Interval (Secs)"; afkTimeInput.Text = tostring(mySettings.AntiAfkInterval); afkTimeInput.BackgroundColor3 = Color3.fromRGB(30, 30, 35); afkTimeInput.TextColor3 = Color3.new(0,1,1)
Instance.new("UICorner", afkTimeInput)

-- [[ 7. TAB: CONFIG (Settings & Reset) ]] --
local function createConfigInput(label, val, pos)
    local lab = Instance.new("TextLabel", configPage); lab.Size = UDim2.new(1, 0, 0, 20); lab.Position = pos; lab.Text = label; lab.TextColor3 = Color3.new(0.7, 0.7, 0.7); lab.TextSize = 10; lab.BackgroundTransparency = 1; lab.Font = Enum.Font.GothamBold
    local inp = Instance.new("TextBox", configPage); inp.Size = UDim2.new(0.9, 0, 0, 30); inp.Position = pos + UDim2.new(0.05, 0, 0, 22); inp.Text = tostring(val); inp.BackgroundColor3 = Color3.fromRGB(30, 30, 35); inp.TextColor3 = Color3.new(1,1,1); inp.ClearTextOnFocus = false
    Instance.new("UICorner", inp); return inp
end

local hbInput = createConfigInput("Heartbeat Interval (Seconds)", HEARTBEAT_INTERVAL, UDim2.new(0, 0, 0, 0))
local webInput = createConfigInput("Webhook URL", WEBHOOK_URL, UDim2.new(0, 0, 0, 60))
local userInput = createConfigInput("Discord User ID", DISCORD_USER_ID, UDim2.new(0, 0, 0, 120))

local saveBtn = Instance.new("TextButton", configPage)
saveBtn.Size = UDim2.new(0.9, 0, 0, 35); saveBtn.Position = UDim2.new(0.05, 0, 0, 185); saveBtn.Text = "SAVE CONFIGURATION"; saveBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 80); saveBtn.TextColor3 = Color3.new(1,1,1); saveBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", saveBtn)

local resetBtn = Instance.new("TextButton", configPage)
resetBtn.Size = UDim2.new(0.9, 0, 0, 35); resetBtn.Position = UDim2.new(0.05, 0, 0, 230); resetBtn.Text = "FACTORY RESET"; resetBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50); resetBtn.TextColor3 = Color3.new(1,1,1); resetBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", resetBtn)

-- [[ 8. UI LOGIC & TWEENING ]] --
local function showPage(page)
    monitorPage.Visible = (page == monitorPage)
    shieldPage.Visible = (page == shieldPage)
    configPage.Visible = (page == configPage)
end
t1.MouseButton1Click:Connect(function() showPage(monitorPage) end)
t2.MouseButton1Click:Connect(function() showPage(shieldPage) end)
t3.MouseButton1Click:Connect(function() showPage(configPage) end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    content.Visible = not minimized
    tabFrame.Visible = not minimized
    main:TweenSize(minimized and UDim2.new(0, 300, 0, 40) or UDim2.new(0, 300, 0, 350), "Out", "Quad", 0.3, true)
    minBtn.Text = minimized and "+" or "-"
end)

closeBtn.MouseButton1Click:Connect(function() _G.SentinelRunning = false; screenGui:Destroy() end)

-- Save Logic
saveBtn.MouseButton1Click:Connect(function()
    mySettings.Timer = tonumber(hbInput.Text) or 600
    mySettings.Webhook = webInput.Text:gsub("%s+", "")
    mySettings.UserID = userInput.Text
    mySettings.AntiAfkInterval = tonumber(afkTimeInput.Text) or 300
    if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
    HEARTBEAT_INTERVAL = mySettings.Timer
    WEBHOOK_URL = mySettings.Webhook
    DISCORD_USER_ID = mySettings.UserID
    saveBtn.Text = "SAVED!"
    task.wait(1)
    saveBtn.Text = "SAVE CONFIGURATION"
end)

resetBtn.MouseButton1Click:Connect(function()
    if isfile(LOCAL_FILE) then delfile(LOCAL_FILE) end
    player:Kick("Sentinel Reset Complete. Please Re-Execute.")
end)

-- Shield Controls
afkToggle.MouseButton1Click:Connect(function()
    activeAntiAfk = not activeAntiAfk
    afkToggle.Text = activeAntiAfk and "ANTI-AFK: ACTIVE" or "ANTI-AFK: OFF"
    afkToggle.BackgroundColor3 = activeAntiAfk and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(50, 50, 50)
    lastAfkAction = tick()
end)

rejoinToggle.MouseButton1Click:Connect(function()
    mySettings.AutoRejoin = not mySettings.AutoRejoin
    rejoinToggle.Text = mySettings.AutoRejoin and "AUTO-REJOIN: ON" or "AUTO-REJOIN: OFF"
    rejoinToggle.BackgroundColor3 = mySettings.AutoRejoin and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(50, 50, 50)
end)

-- [[ 9. CORE LOOPS ]] --

-- Rejoin & Webhook Disconnect Error
GuiService.ErrorMessageChanged:Connect(function()
    if _G.SentinelRunning and _G.CurrentSession == SESSION_ID then
        local msg = GuiService:GetErrorMessage()
        if msg and #msg > 1 and not msg:lower():find("teleport") then 
            sendWebhook("🚨 ALERT: Client Disconnected", "Error: " .. msg, 15548997)
            if mySettings.AutoRejoin then
                task.wait(5)
                TeleportService:Teleport(game.PlaceId, player)
            end
        end
    end
end)

-- Heartbeat Loop
task.spawn(function()
    sendWebhook("🔄 Heartbeat", "Sentinel Active.", 1752220)
    while _G.SentinelRunning and _G.CurrentSession == SESSION_ID do
        local timeLeft = HEARTBEAT_INTERVAL
        while timeLeft > 0 and _G.SentinelRunning and _G.CurrentSession == SESSION_ID do
            timerDisp.Text = string.format("%02d:%02d", math.floor(timeLeft/60), timeLeft%60)
            task.wait(1); timeLeft = timeLeft - 1
        end
        if _G.SentinelRunning then sendWebhook("🔄 Heartbeat", "Stable.", 1752220) end
    end
end)

-- Shield Loop
task.spawn(function()
    while _G.SentinelRunning and _G.CurrentSession == SESSION_ID do
        if activeAntiAfk then
            local timeLeft = math.ceil(mySettings.AntiAfkInterval - (tick() - lastAfkAction))
            if timeLeft <= 0 then
                performMovement()
                lastAfkAction = tick()
            end
            shieldStats.Text = string.format("Next Move: %ds\nRejoin: %s", timeLeft, mySettings.AutoRejoin and "ACTIVE" or "OFF")
        else
            shieldStats.Text = "Status: STANDBY\nClick Start to Protect"
        end
        task.wait(1)
    end
end)

-- Idled Connection
player.Idled:Connect(function()
    if activeAntiAfk then
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(0.1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

-- Hub & Dragging
hubBtn.MouseButton1Click:Connect(function()
    setclipboard("https://discord.gg/c3F7p2ygPJ")
    hubBtn.Text = "COPIED DISCORD!"
    task.wait(1)
    hubBtn.Text = "COPY HUB LINKS"
end)

testBtn.MouseButton1Click:Connect(function()
    sendWebhook("🧪 Test", "Manual Trigger Success", 10181046)
    testBtn.Text = "SENT!"
    task.wait(1)
    testBtn.Text = "SEND TEST HEARTBEAT"
end)

local dragging, dragInput, dragStart, startPos
topBar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragStart = input.Position startPos = main.Position end end)
topBar.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then local delta = input.Position - dragStart main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
