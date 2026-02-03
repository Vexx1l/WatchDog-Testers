-- [[ WATCHDOG INTEGRATED - VERSION 6.4.0 ]] --
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
local Stats = game:GetService("Stats")

-- CENSORSHIP UTILS
local function censorName(name)
    return name:sub(1, 2) .. string.rep("*", #name - 2)
end

local function webhookCensor(name)
    return "||" .. name .. "||"
end

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
    MonitorEnabled = true,
    ThemeColor = {0, 170, 255}
})

local HEARTBEAT_INTERVAL = mySettings.Timer
local WEBHOOK_URL = mySettings.Webhook:gsub("%s+", "")
local DISCORD_USER_ID = mySettings.UserID
local startTime = os.time()
local isBlocked = false
local blockExpires = 0
local forceRestartLoop = false
local monitorActive = mySettings.MonitorEnabled

local antiAfkActive = false
local autoRejoinActive = mySettings.AutoRejoin
local lastAfkAction = tick()
local currentAfkInterval = mySettings.AntiAfkTime

-- 3. WEBHOOK CORE
local function sendWebhook(title, reason, color, isUpdateLog)
    if not monitorActive or WEBHOOK_URL == "" or WEBHOOK_URL == "PASTE_WEBHOOK_HERE" or not _G.WatchdogRunning then return end
    if isBlocked and tick() < blockExpires then return end
    isBlocked = false

    local currentTime = os.time()
    local fps = math.floor(workspace:GetRealPhysicsFPS())
    local ping = math.floor(player:GetNetworkPing() * 1000)
    
    -- Correctly formatted Thumbnail URL for Discord
    local thumbUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=420&height=420&format=png"

    local embed = {
        ["title"] = title,
        ["color"] = color or 1752220,
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        ["thumbnail"] = {
            ["url"] = thumbUrl
        }
    }

    if isUpdateLog then
        embed.description = "**Change Log:**\n" .. reason .. "\n\n*Integrated Update • Build 6.4.0*"
    else
        embed.description = "Status for **" .. webhookCensor(player.Name) .. "**"
        embed.fields = {
            { name = "🎮 Game", value = currentGameName, inline = true },
            { name = "🔢 Server Version", value = "v" .. game.PlaceVersion, inline = true },
            { name = "👥 Players", value = #Players:GetPlayers() .. " / " .. Players.MaxPlayers, inline = true },
            { name = "🛰️ Performance", value = "FPS: " .. fps .. " | Ping: " .. ping .. "ms", inline = true },
            { name = "📊 Session Info", value = "Uptime: " .. os.date("!%X", os.time() - startTime), inline = true },
            { name = "🕒 Updated At", value = "<t:" .. currentTime .. ":f>", inline = false },
            { name = "🔔 Next Update", value = "<t:" .. (currentTime + HEARTBEAT_INTERVAL) .. ":R>", inline = true },
            { name = "💬 Status", value = "```" .. reason .. "```", inline = false }
        }
    end

    local payload = HttpService:JSONEncode({
        content = (not isUpdateLog and title ~= "🔄 Heartbeat") and "<@" .. DISCORD_USER_ID .. ">" or nil,
        embeds = {embed}
    })

    -- HTTP Request execution remains the same...
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

-- 4. UI CREATION
local ScreenGui = Instance.new("ScreenGui", (game:GetService("CoreGui") or player.PlayerGui))
ScreenGui.Name = "WatchdogIntegratedUI"
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 300, 0, 320)
MainFrame.Position = UDim2.new(0.5, -150, 0.4, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 12)

local function getThemeColor()
    if mySettings.ThemeColor and type(mySettings.ThemeColor) == "table" and #mySettings.ThemeColor == 3 then
        return Color3.fromRGB(unpack(mySettings.ThemeColor))
    end
    return Color3.fromRGB(0, 170, 255)
end

local Stroke = Instance.new("UIStroke", MainFrame); 
Stroke.Color = getThemeColor(); Stroke.Thickness = 2

-- Top Bar
local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 35)
TopBar.BackgroundTransparency = 1

local Title = Instance.new("TextLabel", TopBar)
Title.Size = UDim2.new(1, 0, 1, 0); Title.Text = "WATCHDOG v6.4.0 | " .. censorName(player.Name); Title.TextColor3 = Color3.new(1,1,1)
Title.Font = Enum.Font.GothamBold; Title.TextSize = 10; Title.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton", TopBar); CloseBtn.Size = UDim2.new(0, 30, 0, 30); CloseBtn.Position = UDim2.new(1, -35, 0, 2)
CloseBtn.Text = "X"; CloseBtn.TextColor3 = Color3.new(1,0,0); CloseBtn.BackgroundTransparency = 1; CloseBtn.Font = Enum.Font.GothamBold

local MinBtn = Instance.new("TextButton", TopBar); MinBtn.Size = UDim2.new(0, 30, 0, 30); MinBtn.Position = UDim2.new(0, 5, 0, 2)
MinBtn.Text = "-"; MinBtn.TextColor3 = getThemeColor(); MinBtn.BackgroundTransparency = 1; MinBtn.Font = Enum.Font.GothamBold

-- Content Wrapper
local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1, 0, 1, -35); Content.Position = UDim2.new(0, 0, 0, 35); Content.BackgroundTransparency = 1

local TabContainer = Instance.new("Frame", Content)
TabContainer.Size = UDim2.new(1, -20, 1, -50); TabContainer.Position = UDim2.new(0, 10, 0, 5); TabContainer.BackgroundTransparency = 1

local Nav = Instance.new("CanvasGroup", Content)
Nav.Size = UDim2.new(1, 0, 0, 35); Nav.Position = UDim2.new(0, 0, 1, -35); Nav.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Nav.BorderSizePixel = 0
local NavCorner = Instance.new("UICorner", Nav); NavCorner.CornerRadius = UDim.new(0, 12)

local function navBtn(name, x)
    local b = Instance.new("TextButton", Nav); b.Size = UDim2.new(0.334, 0, 1, 0); b.Position = UDim2.new(x, 0, 0, 0); b.Text = name; b.BackgroundTransparency = 1; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamBold; b.TextSize = 10; b.BorderSizePixel = 0; return b
end

local function createTab()
    local f = Instance.new("Frame", TabContainer); f.Size = UDim2.new(1, 0, 1, 0); f.Visible = false; f.BackgroundTransparency = 1; return f
end

local MonitorTab = createTab()
local ShieldTab = createTab()
local SettingsTab = createTab()

-- MONITOR TAB
local timerLabel = Instance.new("TextLabel", MonitorTab)
timerLabel.Size = UDim2.new(1, 0, 0, 50); timerLabel.Position = UDim2.new(0, 0, 0, 0)
timerLabel.Text = "00:00"; timerLabel.TextColor3 = getThemeColor(); timerLabel.TextSize = 35; timerLabel.Font = Enum.Font.GothamBold; timerLabel.BackgroundTransparency = 1

local monToggleBtn = Instance.new("TextButton", MonitorTab)
monToggleBtn.Size = UDim2.new(0.6, 0, 0, 30); monToggleBtn.Position = UDim2.new(0.2, 0, 0.25, 0)
monToggleBtn.Text = monitorActive and "MONITOR: ON" or "MONITOR: OFF"
monToggleBtn.BackgroundColor3 = monitorActive and Color3.fromRGB(0, 100, 0) or Color3.fromRGB(100, 0, 0)
monToggleBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", monToggleBtn)

local monitorStatus = Instance.new("TextLabel", MonitorTab)
monitorStatus.Size = UDim2.new(0.95, 0, 0, 45); monitorStatus.Position = UDim2.new(0.025, 0, 0.45, 0)
monitorStatus.BackgroundColor3 = Color3.fromRGB(30, 30, 35); monitorStatus.TextColor3 = Color3.new(0.8, 0.8, 0.8)
monitorStatus.Text = "Heartbeat: Active\nUptime: 0h 0m"; monitorStatus.Font = Enum.Font.Code; monitorStatus.TextSize = 10
Instance.new("UICorner", monitorStatus)

local testBtn = Instance.new("TextButton", MonitorTab)
testBtn.Size = UDim2.new(0.5, 0, 0, 30); testBtn.Position = UDim2.new(0.25, 0, 0.75, 0)
testBtn.Text = "🧪 SEND TEST"; testBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50); testBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", testBtn)

-- SHIELD TAB
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
afkInput.PlaceholderText = "AFK Interval (Seconds)"; afkInput.Text = tostring(mySettings.AntiAfkTime); afkInput.BackgroundColor3 = Color3.fromRGB(30, 30, 35); afkInput.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", afkInput)

local feed = Instance.new("ScrollingFrame", ShieldTab)
feed.Size = UDim2.new(0.95, 0, 0, 60); feed.Position = UDim2.new(0.025, 0, 0.65, 0); feed.BackgroundColor3 = Color3.new(0,0,0); feed.CanvasSize = UDim2.new(0,0,0,0)
local feedList = Instance.new("UIListLayout", feed)

-- SETTINGS TAB
local function createSetBtn(name, pos, color)
    local b = Instance.new("TextButton", SettingsTab); b.Size = UDim2.new(0.46, 0, 0, 35); b.Position = pos; b.Text = name; b.BackgroundColor3 = Color3.fromRGB(35, 35, 45); b.TextColor3 = color; b.Font = Enum.Font.GothamBold; b.TextSize = 9; Instance.new("UICorner", b); return b
end

local timeB = createSetBtn("HB TIMER", UDim2.new(0.02, 0, 0, 0), Color3.new(0, 1, 0.5))
local cfgB = createSetBtn("WEBHOOK/ID", UDim2.new(0.52, 0, 0, 0), Color3.new(1, 0.7, 0))
local botB = createSetBtn("COPY BOT LINK", UDim2.new(0.02, 0, 0.25, 0), Color3.new(0, 0.7, 1))
local themeB = createSetBtn("THEME", UDim2.new(0.52, 0, 0.25, 0), getThemeColor())
local dscB = createSetBtn("COPY DISCORD", UDim2.new(0.02, 0, 0.5, 0), Color3.new(0.5, 0.5, 1))
local resetB = createSetBtn("FULL RESET", UDim2.new(0.52, 0, 0.5, 0), Color3.new(1, 0.2, 0))

local function setOverlayState(visible)
    TabContainer.Visible = not visible
    Nav.Visible = not visible
end

local function createOverlay(placeholder)
    local o = Instance.new("Frame", MainFrame); o.Size = UDim2.new(1,0,1,0); o.BackgroundColor3 = Color3.fromRGB(15, 15, 20); o.Visible = false; o.ZIndex = 10; Instance.new("UICorner", o)
    o.Active = true
    local t = Instance.new("TextBox", o); t.Size = UDim2.new(0.8, 0, 0.25, 0); t.Position = UDim2.new(0.1, 0, 0.25, 0); t.PlaceholderText = placeholder; t.BackgroundColor3 = Color3.fromRGB(30,30,40); t.TextColor3 = Color3.new(1,1,1); t.ZIndex = 11; t.TextScaled = true; t.ClearTextOnFocus = false; Instance.new("UICorner", t)
    local c = Instance.new("TextButton", o); c.Size = UDim2.new(0.8, 0, 0.2, 0); c.Position = UDim2.new(0.1, 0, 0.6, 0); c.Text = "CONFIRM"; c.BackgroundColor3 = getThemeColor(); c.ZIndex = 11; Instance.new("UICorner", c)
    local b = Instance.new("TextButton", o); b.Size = UDim2.new(0, 30, 0, 30); b.Position = UDim2.new(0, 10, 0, 5); b.Text = "<-"; b.TextColor3 = Color3.new(1,1,1); b.BackgroundTransparency = 1; b.ZIndex = 11
    b.MouseButton1Click:Connect(function() o.Visible = false; setOverlayState(false) end)
    return o, t, c
end

local timeO, timeI, timeC = createOverlay("Interval in Minutes")
local webO, webI, webC = createOverlay("Webhook URL")
local idO, idI, idC = createOverlay("Discord User ID")

local function showTab(tab)
    MonitorTab.Visible = false; ShieldTab.Visible = false; SettingsTab.Visible = false; tab.Visible = true
end
showTab(MonitorTab)
navBtn("MONITOR", 0).MouseButton1Click:Connect(function() showTab(MonitorTab) end)
navBtn("SHIELD", 0.333).MouseButton1Click:Connect(function() showTab(ShieldTab) end)
navBtn("SETTINGS", 0.666).MouseButton1Click:Connect(function() showTab(SettingsTab) end)

local function shieldLog(msg, col)
    local l = Instance.new("TextLabel", feed); l.Size = UDim2.new(1, 0, 0, 18); l.Text = "[" .. os.date("%X") .. "] " .. msg; l.TextColor3 = col or Color3.new(1,1,1); l.BackgroundTransparency = 1; l.TextSize = 10; l.Font = Enum.Font.Code
    feed.CanvasSize = UDim2.new(0, 0, 0, feedList.AbsoluteContentSize.Y)
    feed.CanvasPosition = Vector2.new(0, feed.CanvasSize.Y.Offset)
end

-- CONNECTIONS
monToggleBtn.MouseButton1Click:Connect(function()
    monitorActive = not monitorActive
    monToggleBtn.Text = monitorActive and "MONITOR: ON" or "MONITOR: OFF"
    monToggleBtn.BackgroundColor3 = monitorActive and Color3.fromRGB(0, 100, 0) or Color3.fromRGB(100, 0, 0)
    mySettings.MonitorEnabled = monitorActive
    if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
end)

local themes = {{0, 170, 255}, {255, 50, 50}, {255, 200, 0}, {170, 0, 255}, {0, 255, 100}}
local themeIdx = 1
themeB.MouseButton1Click:Connect(function()
    themeIdx = (themeIdx % #themes) + 1
    local newCol = themes[themeIdx]
    mySettings.ThemeColor = newCol
    local c3 = Color3.fromRGB(unpack(newCol))
    Stroke.Color = c3; timerLabel.TextColor3 = c3; MinBtn.TextColor3 = c3; themeB.TextColor3 = c3;
    timeC.BackgroundColor3 = c3; webC.BackgroundColor3 = c3; idC.BackgroundColor3 = c3
    if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
end)

local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    Content.Visible = not isMinimized
    MainFrame:TweenSize(isMinimized and UDim2.new(0, 300, 0, 35) or UDim2.new(0, 300, 0, 320), "Out", "Quart", 0.3, true)
    MinBtn.Text = isMinimized and "+" or "-"
    if not isMinimized then Title.Text = "WATCHDOG v6.4.0 | " .. censorName(player.Name) end
end)

CloseBtn.MouseButton1Click:Connect(function() _G.WatchdogRunning = false; ScreenGui:Destroy() end)
testBtn.MouseButton1Click:Connect(function() sendWebhook("🧪 Test", "Integrated System Working!", 10181046, false) end)

afkBtn.MouseButton1Click:Connect(function()
    antiAfkActive = not antiAfkActive
    afkBtn.Text = antiAfkActive and "AFK: ON" or "AFK: OFF"
    afkBtn.BackgroundColor3 = antiAfkActive and Color3.fromRGB(0, 120, 70) or Color3.fromRGB(50, 50, 60)
    lastAfkAction = tick()
end)

rjnBtn.MouseButton1Click:Connect(function()
    autoRejoinActive = not autoRejoinActive
    rjnBtn.Text = autoRejoinActive and "REJOIN: ON" or "REJOIN: OFF"
    rjnBtn.BackgroundColor3 = autoRejoinActive and Color3.fromRGB(0, 80, 150) or Color3.fromRGB(50, 50, 60)
    mySettings.AutoRejoin = autoRejoinActive
    if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
end)

afkInput.FocusLost:Connect(function()
    local n = tonumber(afkInput.Text)
    if n then
        mySettings.AntiAfkTime = math.clamp(n, 15, 1100)
        currentAfkInterval = mySettings.AntiAfkTime
        shieldLog("AFK set to " .. n .. "s", Color3.new(0,1,1))
        if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
    end
end)

botB.MouseButton1Click:Connect(function() setclipboard("https://discord.com/oauth2/authorize?client_id=1460862231926407252&permissions=8&integration_type=0&scope=bot") shieldLog("Bot link copied!", Color3.new(0,1,0)) end)
dscB.MouseButton1Click:Connect(function() setclipboard("https://discord.gg/c3F7p2ygPJ") shieldLog("Discord link copied!", Color3.new(0,1,0)) end)

timeB.MouseButton1Click:Connect(function() timeO.Visible = true; setOverlayState(true) end)
timeC.MouseButton1Click:Connect(function() 
    local n = tonumber(timeI.Text); if n then HEARTBEAT_INTERVAL = n * 60; mySettings.Timer = n * 60; forceRestartLoop = true end
    timeO.Visible = false; setOverlayState(false); if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
end)

cfgB.MouseButton1Click:Connect(function() webO.Visible = true; setOverlayState(true) end)
webC.MouseButton1Click:Connect(function() 
    WEBHOOK_URL = webI.Text:gsub("%s+", ""); mySettings.Webhook = WEBHOOK_URL; webO.Visible = false; idO.Visible = true 
end)
idC.MouseButton1Click:Connect(function() 
    DISCORD_USER_ID = idI.Text; mySettings.UserID = idI.Text; idO.Visible = false; setOverlayState(false)
    if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
    sendWebhook("✅ Watchdog Config", "System Linked Successfully.", 3066993, false)
end)

resetB.MouseButton1Click:Connect(function() if isfile(LOCAL_FILE) then delfile(LOCAL_FILE) end player:Kick("Watchdog Reset complete.") end)

-- LOOPS
player.Idled:Connect(function()
    if antiAfkActive then
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(0.1); VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

GuiService.ErrorMessageChanged:Connect(function()
    if _G.WatchdogRunning and _G.CurrentSession == SESSION_ID then
        local msg = GuiService:GetErrorMessage()
        if not msg:lower():find("teleport") then
            sendWebhook("🚨 Watchdog Alert", "Client Disconnected: " .. msg, 15548997, false)
            if autoRejoinActive then task.wait(5); TeleportService:Teleport(game.PlaceId, player) end
        end
    end
end)

task.spawn(function()
    if globalSet.LastBuild ~= "6.4.0" then
        sendWebhook("📜 System Updated: 6.4.0", "• Added Player Avatar Thumbnails to Webhooks\n• Added Real-time FPS and Ping monitoring\n• Enhanced privacy features and bug fixes", 16763904, true)
        globalSet.LastBuild = "6.4.0"
        if writefile then writefile(GLOBAL_FILE, HttpService:JSONEncode(globalSet)) end
    end
    
    sendWebhook("🔄 Integrated Watchdog", "System Online v6.4.0", 1752220, false)
    while _G.WatchdogRunning and _G.CurrentSession == SESSION_ID do
        if monitorActive then
            local timeLeft = HEARTBEAT_INTERVAL; forceRestartLoop = false
            while timeLeft > 0 and _G.WatchdogRunning and not forceRestartLoop and monitorActive do
                local timeStr = string.format("%02d:%02d", math.floor(timeLeft/60), timeLeft%60)
                timerLabel.Text = timeStr
                if isMinimized then Title.Text = "HeartBeat: " .. timeStr .. " | " .. censorName(player.Name) end
                monitorStatus.Text = "Heartbeat: Active\nUptime: " .. os.date("!%X", os.time() - startTime)
                task.wait(1); timeLeft = timeLeft - 1
            end
            if _G.WatchdogRunning and not forceRestartLoop and monitorActive then sendWebhook("🔄 Heartbeat", "Stable.", 1752220, false) end
        else
            timerLabel.Text = "PAUSED"
            if isMinimized then Title.Text = "HEARTBEAT: PAUSED" end
            monitorStatus.Text = "Heartbeat: DISABLED"
            task.wait(1)
        end
    end
end)

task.spawn(function()
    while _G.WatchdogRunning do
        if antiAfkActive then
            local afkRemaining = math.ceil(currentAfkInterval - (tick() - lastAfkAction))
            shieldStatus.Text = string.format("Shield: ACTIVE | Move: %ds\nRejoin: %s", afkRemaining, autoRejoinActive and "ON" or "OFF")
            if afkRemaining <= 0 then
                pcall(function()
                    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if hum and root then
                        shieldLog("Humanoid Movement...", getThemeColor())
                        local cam = workspace.CurrentCamera
                        local dir = {cam.CFrame.LookVector, -cam.CFrame.LookVector, -cam.CFrame.RightVector, cam.CFrame.RightVector}
                        local target = root.Position + (dir[math.random(1, #dir)] * 5)
                        hum:MoveTo(target); task.wait(1.5); hum:MoveTo(root.Position)
                    end
                end)
                lastAfkAction = tick(); currentAfkInterval = mySettings.AntiAfkTime + math.random(-5, 5)
            end
        else shieldStatus.Text = "Shield: STANDBY\nAuto-Rejoin: " .. (autoRejoinActive and "ON" or "OFF") end
        task.wait(1)
    end
end)

local dragging, dragStart, startPos
MainFrame.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragStart = input.Position startPos = MainFrame.Position end end)
MainFrame.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then local delta = input.Position - dragStart MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)

shieldLog("Watchdog Integrated v6.4.0 Loaded", Color3.new(1,1,1))
