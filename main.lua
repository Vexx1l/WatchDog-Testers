-- [[ WATCHDOG INTEGRATED - VERSION 6.2.0 ]] --
-- [[ Fused Heartbeat V2 + Watchdog Shield ]] --

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")

-- 0. PLACE NAME OVERRIDES
local placeNameOverrides = {
    [76558904092080]  = "The Forge (World 1)",
    [129009554587176] = "The Forge (World 2)",
    [131884594917121] = "The Forge (World 3)"
}
local success, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
local currentGameName = placeNameOverrides[game.PlaceId] or (success and info.Name) or "Unknown Game"

-- 1. PRE-EXECUTION CLEANUP
local function deepClean()
    pcall(function()
        for _, p in pairs({game:GetService("CoreGui"), player:FindFirstChild("PlayerGui")}) do
            if p then 
                for _, c in pairs(p:GetChildren()) do
                    if c.Name == "WatchdogIntegratedUI" then c:Destroy() end
                end 
            end
        end
    end)
end
deepClean()

-- 2. GLOBAL STATE & CONFIG
if _G.WatchdogRunning then _G.WatchdogRunning = false task.wait(0.5) end
_G.WatchdogRunning = true
local SESSION_ID = tick()
_G.CurrentSession = SESSION_ID

local GLOBAL_FILE = "Watchdog_GLOBAL.json"
local LOCAL_FILE = "Watchdog_" .. player.Name .. ".json"

local function loadData(file, default)
    if isfile and isfile(file) then
        local s, d = pcall(function() return HttpService:JSONDecode(readfile(file)) end)
        if s then return d end
    end
    return default
end

local globalSet = loadData(GLOBAL_FILE, {LastBuild = "0"})
local mySettings = loadData(LOCAL_FILE, {
    Timer = 600, 
    Webhook = "PASTE_WEBHOOK_HERE", 
    UserID = "958143880291823647",
    AntiAfkTime = 300,
    AutoRejoin = false,
    ThemeColor = {0, 170, 255},
    HeartbeatEnabled = true
})

-- State Variables
local HEARTBEAT_INTERVAL = mySettings.Timer
local WEBHOOK_URL = mySettings.Webhook:gsub("%s+", "")
local DISCORD_USER_ID = mySettings.UserID
local startTime = os.time()
local isBlocked = false
local blockExpires = 0
local forceRestartLoop = false
local heartbeatEnabled = mySettings.HeartbeatEnabled

local antiAfkActive = false
local autoRejoinActive = mySettings.AutoRejoin
local lastAfkAction = tick()
local currentAfkInterval = mySettings.AntiAfkTime

-- 3. THEME ENGINE
local themes = {
    {Name = "Watchdog Blue", Color = Color3.fromRGB(0, 170, 255)},
    {Name = "Crimson", Color = Color3.fromRGB(255, 50, 50)},
    {Name = "Emerald", Color = Color3.fromRGB(50, 255, 150)},
    {Name = "Gold", Color = Color3.fromRGB(255, 200, 50)},
    {Name = "Amethyst", Color = Color3.fromRGB(180, 100, 255)}
}
local currentThemeIdx = 1
local accentColor = Color3.fromRGB(unpack(mySettings.ThemeColor))

-- 4. WEBHOOK CORE
local function sendWebhook(title, reason, color, isUpdateLog)
    if not heartbeatEnabled and not isUpdateLog then return end
    if WEBHOOK_URL == "" or WEBHOOK_URL == "PASTE_WEBHOOK_HERE" or not _G.WatchdogRunning then return end
    if isBlocked and tick() < blockExpires then return end

    local currentTime = os.time()
    local embed = {
        title = title,
        color = color or 1752220,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    if isUpdateLog then
        embed.description = "**Change Log v6.2.0:**\n" .. reason
    else
        embed.description = "Status for **" .. player.Name .. "**"
        embed.fields = {
            { name = "🎮 Game", value = currentGameName, inline = true },
            { name = "🔢 Server", value = "v" .. game.PlaceVersion, inline = true },
            { name = "👥 Players", value = #Players:GetPlayers() .. " / " .. Players.MaxPlayers, inline = true },
            { name = "📊 Session", value = "Uptime: " .. os.date("!%X", os.time() - startTime), inline = false },
            { name = "🕒 Next Update", value = "<t:" .. (currentTime + HEARTBEAT_INTERVAL) .. ":R>", inline = true },
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
                blockExpires = tick() + (tonumber(response.Headers["retry-after"]) or 60)
            end
        end)
    end
end

-- 5. UI CREATION
local ScreenGui = Instance.new("ScreenGui", (game:GetService("CoreGui") or player.PlayerGui))
ScreenGui.Name = "WatchdogIntegratedUI"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 300, 0, 320)
MainFrame.Position = UDim2.new(0.5, -150, 0.4, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = accentColor
MainStroke.Thickness = 2

local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1, 0, 1, -35); Content.Position = UDim2.new(0, 0, 0, 35); Content.BackgroundTransparency = 1

local TabContainer = Instance.new("Frame", Content)
TabContainer.Size = UDim2.new(1, -20, 1, -50); TabContainer.Position = UDim2.new(0, 10, 0, 5); TabContainer.BackgroundTransparency = 1

local Nav = Instance.new("Frame", Content)
Nav.Size = UDim2.new(1, 0, 0, 35); Nav.Position = UDim2.new(0, 0, 1, -35); Nav.BackgroundColor3 = Color3.fromRGB(25, 25, 30)

local function createTab()
    local f = Instance.new("Frame", TabContainer); f.Size = UDim2.new(1, 0, 1, 0); f.Visible = false; f.BackgroundTransparency = 1
    return f
end

local MonitorTab = createTab()
local ShieldTab = createTab()
local SettingsTab = createTab()

-- UI ACCENT UPDATER
local function updateAccents(color)
    accentColor = color
    MainStroke.Color = color
    mySettings.ThemeColor = {math.floor(color.R*255), math.floor(color.G*255), math.floor(color.B*255)}
    if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
end

-- 6. CONTENT: MONITOR TAB
local timerLabel = Instance.new("TextLabel", MonitorTab)
timerLabel.Size = UDim2.new(1, 0, 0, 60); timerLabel.Position = UDim2.new(0, 0, 0.02, 0)
timerLabel.Text = "00:00"; timerLabel.TextColor3 = accentColor; timerLabel.TextSize = 40; timerLabel.Font = Enum.Font.GothamBold; timerLabel.BackgroundTransparency = 1

local monitorStatus = Instance.new("TextLabel", MonitorTab)
monitorStatus.Size = UDim2.new(0.95, 0, 0, 50); monitorStatus.Position = UDim2.new(0.025, 0, 0.35, 0)
monitorStatus.BackgroundColor3 = Color3.fromRGB(30, 30, 35); monitorStatus.TextColor3 = Color3.new(0.8, 0.8, 0.8)
monitorStatus.Text = "Heartbeat: Active\nUptime: 0h 0m"; monitorStatus.Font = Enum.Font.Code; monitorStatus.TextSize = 11
Instance.new("UICorner", monitorStatus)

local hbToggleBtn = Instance.new("TextButton", MonitorTab)
hbToggleBtn.Size = UDim2.new(0.95, 0, 0, 35); hbToggleBtn.Position = UDim2.new(0.025, 0, 0.58, 0)
hbToggleBtn.Text = heartbeatEnabled and "MONITOR: ON" or "MONITOR: OFF"
hbToggleBtn.BackgroundColor3 = heartbeatEnabled and Color3.fromRGB(0, 120, 70) or Color3.fromRGB(120, 40, 40)
hbToggleBtn.TextColor3 = Color3.new(1, 1, 1); Instance.new("UICorner", hbToggleBtn)

local testBtn = Instance.new("TextButton", MonitorTab)
testBtn.Size = UDim2.new(0.5, 0, 0, 30); testBtn.Position = UDim2.new(0.25, 0, 0.78, 0)
testBtn.Text = "🧪 SEND TEST"; testBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50); testBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", testBtn)

-- 7. CONTENT: SHIELD TAB
local shieldStatus = Instance.new("TextLabel", ShieldTab)
shieldStatus.Size = UDim2.new(0.95, 0, 0, 40); shieldStatus.Position = UDim2.new(0.025, 0, 0, 0)
shieldStatus.BackgroundColor3 = Color3.fromRGB(20, 20, 25); shieldStatus.TextColor3 = Color3.new(0, 1, 0.8); shieldStatus.Text = "Shield: STANDBY"; shieldStatus.Font = Enum.Font.Code; shieldStatus.TextSize = 11

local afkBtn = Instance.new("TextButton", ShieldTab)
afkBtn.Size = UDim2.new(0.46, 0, 0, 40); afkBtn.Position = UDim2.new(0.02, 0, 0.25, 0)
afkBtn.Text = "AFK: OFF"; afkBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60); afkBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", afkBtn)

local rjnBtn = Instance.new("TextButton", ShieldTab)
rjnBtn.Size = UDim2.new(0.46, 0, 0, 40); rjnBtn.Position = UDim2.new(0.52, 0, 0.25, 0)
rjnBtn.Text = "REJOIN: OFF"; rjnBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60); rjnBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", rjnBtn)

local afkInput = Instance.new("TextBox", ShieldTab)
afkInput.Size = UDim2.new(0.95, 0, 0, 30); afkInput.Position = UDim2.new(0.025, 0, 0.45, 0)
afkInput.PlaceholderText = "AFK Seconds"; afkInput.Text = tostring(mySettings.AntiAfkTime); afkInput.BackgroundColor3 = Color3.fromRGB(30, 30, 35); afkInput.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", afkInput)

local feed = Instance.new("ScrollingFrame", ShieldTab)
feed.Size = UDim2.new(0.95, 0, 0, 60); feed.Position = UDim2.new(0.025, 0, 0.65, 0); feed.BackgroundColor3 = Color3.new(0,0,0); feed.CanvasSize = UDim2.new(0,0,0,0); feed.ScrollBarThickness = 2
local feedList = Instance.new("UIListLayout", feed)

-- 8. CONTENT: SETTINGS TAB
local function createSetBtn(name, pos, color)
    local b = Instance.new("TextButton", SettingsTab); b.Size = UDim2.new(0.46, 0, 0, 35); b.Position = pos; b.Text = name; b.BackgroundColor3 = Color3.fromRGB(35, 35, 45); b.TextColor3 = color; b.Font = Enum.Font.GothamBold; b.TextSize = 9; Instance.new("UICorner", b); return b
end

local timeB = createSetBtn("HB TIMER", UDim2.new(0.02, 0, 0, 0), Color3.new(0, 1, 0.5))
local cfgB = createSetBtn("WEBHOOK/ID", UDim2.new(0.52, 0, 0, 0), Color3.new(1, 0.7, 0))
local botB = createSetBtn("COPY BOT LINK", UDim2.new(0.02, 0, 0.25, 0), Color3.new(0, 0.7, 1))
local dscB = createSetBtn("COPY DISCORD", UDim2.new(0.52, 0, 0.25, 0), Color3.new(0.5, 0.5, 1))
local themeB = createSetBtn("THEME: BLUE", UDim2.new(0.02, 0, 0.5, 0), Color3.new(1,1,1))
local resetB = createSetBtn("FULL RESET", UDim2.new(0.52, 0, 0.5, 0), Color3.new(1, 0.2, 0))

-- 9. LOGIC: HUMANIZED MOVEMENT
local function shieldLog(msg, col)
    local l = Instance.new("TextLabel", feed); l.Size = UDim2.new(1, 0, 0, 18); l.Text = "[" .. os.date("%X") .. "] " .. msg; l.TextColor3 = col or Color3.new(1,1,1); l.BackgroundTransparency = 1; l.TextSize = 10; l.Font = Enum.Font.Code
    feed.CanvasSize = UDim2.new(0, 0, 0, feedList.AbsoluteContentSize.Y)
    feed.CanvasPosition = Vector2.new(0, feed.CanvasSize.Y.Offset)
end

local function performHumanMovement()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    if hum and root then
        shieldLog("Humanizing: Walking...", accentColor)
        
        -- Pick a random nearby spot
        local angle = math.rad(math.random(0, 360))
        local dist = math.random(5, 12)
        local targetPos = root.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
        
        hum:MoveTo(targetPos)
        
        -- Micro-camera jitter
        local cam = workspace.CurrentCamera
        local originalCFrame = cam.CFrame
        task.spawn(function()
            for i = 1, 10 do
                cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(math.random(-1,1)/10), math.rad(math.random(-1,1)/10), 0)
                task.wait(0.1)
            end
        end)
        
        hum.MoveToFinished:Wait()
        shieldLog("Movement Complete", Color3.new(0.7, 0.7, 0.7))
    end
end

-- 10. CONNECTIONS & BUTTONS
hbToggleBtn.MouseButton1Click:Connect(function()
    heartbeatEnabled = not heartbeatEnabled
    mySettings.HeartbeatEnabled = heartbeatEnabled
    hbToggleBtn.Text = heartbeatEnabled and "MONITOR: ON" or "MONITOR: OFF"
    hbToggleBtn.BackgroundColor3 = heartbeatEnabled and Color3.fromRGB(0, 120, 70) or Color3.fromRGB(120, 40, 40)
    if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
end)

themeB.MouseButton1Click:Connect(function()
    currentThemeIdx = (currentThemeIdx % #themes) + 1
    local t = themes[currentThemeIdx]
    themeB.Text = "THEME: " .. t.Name:upper()
    updateAccents(t.Color)
    timerLabel.TextColor3 = t.Color
end)

afkBtn.MouseButton1Click:Connect(function()
    antiAfkActive = not antiAfkActive
    afkBtn.Text = antiAfkActive and "AFK: ON" or "AFK: OFF"
    afkBtn.BackgroundColor3 = antiAfkActive and Color3.fromRGB(0, 120, 70) or Color3.fromRGB(50, 50, 60)
    lastAfkAction = tick()
end)

-- Tab Navigation
local function navBtn(name, x, tab)
    local b = Instance.new("TextButton", Nav); b.Size = UDim2.new(0.33, 0, 1, 0); b.Position = UDim2.new(x, 0, 0, 0)
    b.Text = name; b.BackgroundColor3 = Color3.fromRGB(30, 30, 35); b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamBold; b.TextSize = 10; b.BorderSizePixel = 0
    b.MouseButton1Click:Connect(function()
        MonitorTab.Visible = false; ShieldTab.Visible = false; SettingsTab.Visible = false
        tab.Visible = true
    end)
    return b
end
navBtn("MONITOR", 0, MonitorTab)
navBtn("SHIELD", 0.33, ShieldTab)
navBtn("SETTINGS", 0.66, SettingsTab)
MonitorTab.Visible = true

-- (Rest of buttons: testBtn, rjnBtn, botB, dscB, timeB, cfgB, resetB from previous version maintained)
testBtn.MouseButton1Click:Connect(function() sendWebhook("🧪 Test", "Integrated System Working!", 10181046, false) end)
botB.MouseButton1Click:Connect(function() setclipboard("https://discord.com/oauth2/authorize?client_id=1460862231926407252&permissions=8&integration_type=0&scope=bot") shieldLog("Bot link copied!", Color3.new(0,1,0)) end)
dscB.MouseButton1Click:Connect(function() setclipboard("https://discord.gg/Gzqm7NKJUM") shieldLog("Discord link copied!", Color3.new(0,1,0)) end)

-- 11. CORE LOOPS
-- Heartbeat Loop
task.spawn(function()
    if globalSet.LastBuild ~= "6.2.0" then
        sendWebhook("📜 System Updated: 6.2.0", "• New Humanized Movement Engine\n• Heartbeat ON/OFF Toggle\n• Dynamic UI Theme System\n• Micro-Camera Jitters", 16763904, true)
        globalSet.LastBuild = "6.2.0"; if writefile then writefile(GLOBAL_FILE, HttpService:JSONEncode(globalSet)) end
    end
    
    while _G.WatchdogRunning and _G.CurrentSession == SESSION_ID do
        local timeLeft = HEARTBEAT_INTERVAL
        forceRestartLoop = false
        while timeLeft > 0 and _G.WatchdogRunning and not forceRestartLoop do
            if heartbeatEnabled then
                timerLabel.Text = string.format("%02d:%02d", math.floor(timeLeft/60), timeLeft%60)
                timeLeft = timeLeft - 1
            else
                timerLabel.Text = "PAUSED"
            end
            monitorStatus.Text = "Heartbeat: " .. (heartbeatEnabled and "Active" or "Disabled") .. "\nUptime: " .. os.date("!%X", os.time() - startTime)
            task.wait(1)
        end
        if _G.WatchdogRunning and not forceRestartLoop and heartbeatEnabled then 
            sendWebhook("🔄 Heartbeat", "Stable Tracking.", 1752220, false) 
        end
    end
end)

-- Shield Loop
task.spawn(function()
    while _G.WatchdogRunning do
        if antiAfkActive then
            local afkRemaining = math.ceil(currentAfkInterval - (tick() - lastAfkAction))
            shieldStatus.Text = string.format("Shield: ACTIVE | Move: %ds\nRejoin: %s", afkRemaining, autoRejoinActive and "ON" or "OFF")
            if afkRemaining <= 0 then
                performHumanMovement()
                lastAfkAction = tick()
                currentAfkInterval = mySettings.AntiAfkTime + math.random(-15, 15)
            end
        else
            shieldStatus.Text = "Shield: STANDBY\nAuto-Rejoin: " .. (autoRejoinActive and "ON" or "OFF")
        end
        task.wait(1)
    end
end)

-- (Dragging, Min/Close Logic maintained from v6.1.0)
local TopBar = MainFrame:WaitForChild("Frame") -- Assumes hierarchy from previous creation
local isMinimized = false
local MinBtn = MainFrame.TopBar.MinBtn
local CloseBtn = MainFrame.TopBar.CloseBtn

MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    Content.Visible = not isMinimized
    MainFrame:TweenSize(isMinimized and UDim2.new(0, 300, 0, 35) or UDim2.new(0, 300, 0, 320), "Out", "Quart", 0.3, true)
    MinBtn.Text = isMinimized and "+" or "-"
end)
CloseBtn.MouseButton1Click:Connect(function() _G.WatchdogRunning = false; ScreenGui:Destroy() end)

shieldLog("Watchdog Integrated v6.2.0 Loaded", Color3.new(1,1,1))
