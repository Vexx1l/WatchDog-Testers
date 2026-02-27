-- [[ WATCHDOG INTEGRATED - VERSION 6.4.2 ]] --
-- [[ Auto Boss Crimson Sakura Update ]] --

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

-- PLACE NAME OVERRIDES
local forgePlaces = {
    [76558904092080]  = "The Forge (World 1)",
    [129009554587176] = "The Forge (World 2)",
    [131884594917121] = "The Forge (World 3)",
    [74414241680540]  = "The Forge (Crimson Sakura)"
}
local isInForge = forgePlaces[game.PlaceId] ~= nil
local success, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
local currentGameName = forgePlaces[game.PlaceId] or (success and info.Name) or "Unknown Game"

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
    ThemeColor = {0, 170, 255},
    -- Auto Boss Configs
    AutoBossEnabled = false,
    TweenSpeed = 40,
    SafetyReturn = 90
})

-- Boss Constant
local BOSS_CONFIG = {
    BossCFrame = CFrame.new(92.62, 127.55, 221.76),
    WaitAreaCFrame = CFrame.new(-149.65, 18.56, -592.88),
    SyncInterval = 5
}

local HEARTBEAT_INTERVAL = mySettings.Timer
local WEBHOOK_URL = mySettings.Webhook:gsub("%s+", "")
local DISCORD_USER_ID = mySettings.UserID
local startTime = os.time()
local isBlocked = false
local blockExpires = 0
local monitorActive = mySettings.MonitorEnabled

-- 3. WEBHOOK CORE
local function sendWebhook(title, reason, color, isUpdateLog)

    if not monitorActive or WEBHOOK_URL == "" or WEBHOOK_URL == "PASTE_WEBHOOK_HERE" or not _G.WatchdogRunning then return end
    if isBlocked and tick() < blockExpires then return end
    isBlocked = false

    local currentTime = os.time()
    local fps = math.floor(workspace:GetRealPhysicsFPS())
    local ping = math.floor(player:GetNetworkPing() * 1000)

    local embed = {
        ["title"] = title,
        ["color"] = color or 1752220,
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    if isUpdateLog then
        embed["description"] = "**Change Log:**\n" .. reason .. "\n\n*Integrated Update • Build 6.4.1*"
    else

        embed["description"] = "Status for **" .. webhookCensor(player.Name) .. "**"
        embed["fields"] = {
            { ["name"] = "🎮 Game", ["value"] = currentGameName, ["inline"] = true },
            { ["name"] = "🔢 Server Version", ["value"] = "v" .. game.PlaceVersion, ["inline"] = true },
            { ["name"] = "👥 Players", ["value"] = #Players:GetPlayers() .. " / " .. Players.MaxPlayers, ["inline"] = true },
            { ["name"] = "🛰️ Performance", ["value"] = "FPS: " .. fps .. " | Ping: " .. ping .. "ms", ["inline"] = true },
            { ["name"] = "📊 Session Info", ["value"] = "Uptime: " .. os.date("!%X", os.time() - startTime), ["inline"] = true },
            { ["name"] = "🕒 Updated At", ["value"] = "<t:" .. currentTime .. ":f>", ["inline"] = false },
            { ["name"] = "🔔 Next Update", ["value"] = "<t:" .. (currentTime + HEARTBEAT_INTERVAL) .. ":R>", ["inline"] = true },
            { ["name"] = "💬 Status", ["value"] = "```" .. reason .. "```", ["inline"] = false }
        }
    end

    local payload = HttpService:JSONEncode({
        ["content"] = (not isUpdateLog and title ~= "🔄 Heartbeat") and "<@" .. DISCORD_USER_ID .. ">" or nil,
        ["embeds"] = {embed}
    })

    local requestFunc = (request or http_request or syn.request or (http and http.request))
    if requestFunc then
        task.spawn(function()
            local _, response = pcall(function()
                return requestFunc({
                    Url = WEBHOOK_URL, 
                    Method = "POST", 
                    Headers = {["Content-Type"] = "application/json"}, 
                    Body = payload
                })
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
ScreenGui.Name = "WatchdogIntegratedUI"; ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 300, 0, 320); MainFrame.Position = UDim2.new(0.5, -150, 0.4, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18); MainFrame.BorderSizePixel = 0
local MainCorner = Instance.new("UICorner", MainFrame)

local function getThemeColor() return Color3.fromRGB(unpack(mySettings.ThemeColor)) end
local Stroke = Instance.new("UIStroke", MainFrame); Stroke.Color = getThemeColor(); Stroke.Thickness = 2

-- Top Bar
local TopBar = Instance.new("Frame", MainFrame); TopBar.Size = UDim2.new(1, 0, 0, 35); TopBar.BackgroundTransparency = 1
local Title = Instance.new("TextLabel", TopBar); Title.Size = UDim2.new(1, 0, 1, 0); Title.TextColor3 = Color3.new(1,1,1); Title.Font = Enum.Font.GothamBold; Title.TextSize = 10; Title.BackgroundTransparency = 1; Title.Text = "WATCHDOG v6.4.2 | " .. player.Name:sub(1,2) .. "***"
local CloseBtn = Instance.new("TextButton", TopBar); CloseBtn.Size = UDim2.new(0, 30, 0, 30); CloseBtn.Position = UDim2.new(1, -35, 0, 2); CloseBtn.Text = "X"; CloseBtn.TextColor3 = Color3.new(1,0,0); CloseBtn.BackgroundTransparency = 1
local MinBtn = Instance.new("TextButton", TopBar); MinBtn.Size = UDim2.new(0, 30, 0, 30); MinBtn.Position = UDim2.new(0, 5, 0, 2); MinBtn.Text = "-"; MinBtn.TextColor3 = getThemeColor(); MinBtn.BackgroundTransparency = 1

-- Content
local Content = Instance.new("Frame", MainFrame); Content.Size = UDim2.new(1, 0, 1, -35); Content.Position = UDim2.new(0, 0, 0, 35); Content.BackgroundTransparency = 1
local TabContainer = Instance.new("Frame", Content); TabContainer.Size = UDim2.new(1, -20, 1, -50); TabContainer.Position = UDim2.new(0, 10, 0, 5); TabContainer.BackgroundTransparency = 1
local Nav = Instance.new("CanvasGroup", Content); Nav.Size = UDim2.new(1, 0, 0, 35); Nav.Position = UDim2.new(0, 0, 1, -35); Nav.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Nav.BorderSizePixel = 0; Instance.new("UICorner", Nav)

local navCount = isInForge and 4 or 3
local function navBtn(name, index)
    local b = Instance.new("TextButton", Nav); b.Size = UDim2.new(1/navCount, 0, 1, 0); b.Position = UDim2.new((index-1)/navCount, 0, 0, 0)
    b.Text = name; b.BackgroundTransparency = 1; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamBold; b.TextSize = 8; return b
end

local function createTab()
    local f = Instance.new("Frame", TabContainer); f.Size = UDim2.new(1, 0, 1, 0); f.Visible = false; f.BackgroundTransparency = 1; return f
end

local MonitorTab = createTab()
local ShieldTab = createTab()
local BossTab = createTab()
local SettingsTab = createTab()

-- MONITOR TAB UI
local timerLabel = Instance.new("TextLabel", MonitorTab); timerLabel.Size = UDim2.new(1, 0, 0, 50); timerLabel.Text = "00:00"; timerLabel.TextColor3 = getThemeColor(); timerLabel.TextSize = 35; timerLabel.Font = Enum.Font.GothamBold; timerLabel.BackgroundTransparency = 1
local monToggleBtn = Instance.new("TextButton", MonitorTab); monToggleBtn.Size = UDim2.new(0.6, 0, 0, 30); monToggleBtn.Position = UDim2.new(0.2, 0, 0.25, 0); monToggleBtn.Text = monitorActive and "MONITOR: ON" or "MONITOR: OFF"; monToggleBtn.BackgroundColor3 = monitorActive and Color3.fromRGB(0, 100, 0) or Color3.fromRGB(100, 0, 0); monToggleBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", monToggleBtn)

-- BOSS TAB UI (NEW)
local bossTimerLabel = Instance.new("TextLabel", BossTab); bossTimerLabel.Size = UDim2.new(1, 0, 0, 40); bossTimerLabel.Text = "Next Boss: --:--"; bossTimerLabel.TextColor3 = Color3.new(1,1,1); bossTimerLabel.Font = Enum.Font.GothamBold; bossTimerLabel.BackgroundTransparency = 1
local bossToggleBtn = Instance.new("TextButton", BossTab); bossToggleBtn.Size = UDim2.new(0.9, 0, 0, 35); bossToggleBtn.Position = UDim2.new(0.05, 0, 0.2, 0); bossToggleBtn.Text = mySettings.AutoBossEnabled and "AUTO BOSS: ON" or "AUTO BOSS: OFF"; bossToggleBtn.BackgroundColor3 = mySettings.AutoBossEnabled and Color3.fromRGB(0, 120, 70) or Color3.fromRGB(100, 0, 0); bossToggleBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", bossToggleBtn)

local function createBossInput(placeholder, text, yPos)
    local t = Instance.new("TextBox", BossTab); t.Size = UDim2.new(0.9, 0, 0, 30); t.Position = UDim2.new(0.05, 0, yPos, 0)
    t.PlaceholderText = placeholder; t.Text = tostring(text); t.BackgroundColor3 = Color3.fromRGB(30, 30, 35); t.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", t); return t
end
local speedInput = createBossInput("Tween Speed (Standard: 40)", mySettings.TweenSpeed, 0.45)
local safetyInput = createBossInput("Safety Return (Seconds: 90)", mySettings.SafetyReturn, 0.65)
local bossStatus = Instance.new("TextLabel", BossTab); bossStatus.Size = UDim2.new(0.9, 0, 0, 20); bossStatus.Position = UDim2.new(0.05, 0, 0.85, 0); bossStatus.Text = "Status: Standby"; bossStatus.TextColor3 = Color3.new(0.7,0.7,0.7); bossStatus.BackgroundTransparency = 1; bossStatus.Font = Enum.Font.Code; bossStatus.TextSize = 10

-- SETTINGS TAB UTILS
local function createSetBtn(name, pos, color)
    local b = Instance.new("TextButton", SettingsTab); b.Size = UDim2.new(0.46, 0, 0, 35); b.Position = pos; b.Text = name; b.BackgroundColor3 = Color3.fromRGB(35, 35, 45); b.TextColor3 = color; b.Font = Enum.Font.GothamBold; b.TextSize = 9; Instance.new("UICorner", b); return b
end
local resetB = createSetBtn("FULL RESET", UDim2.new(0.52, 0, 0.5, 0), Color3.new(1, 0.2, 0))

-- NAVIGATION LOGIC
local function showTab(tab)
    MonitorTab.Visible = false; ShieldTab.Visible = false; BossTab.Visible = false; SettingsTab.Visible = false; tab.Visible = true
end
showTab(MonitorTab)

navBtn("MONITOR", 1).MouseButton1Click:Connect(function() showTab(MonitorTab) end)
navBtn("SHIELD", 2).MouseButton1Click:Connect(function() showTab(ShieldTab) end)
if isInForge then
    navBtn("BOSS", 3).MouseButton1Click:Connect(function() showTab(BossTab) end)
    navBtn("SETTINGS", 4).MouseButton1Click:Connect(function() showTab(SettingsTab) end)
else
    navBtn("SETTINGS", 3).MouseButton1Click:Connect(function() showTab(SettingsTab) end)
end

-- BOSS LOGIC FUNCTIONS
local function safeMove(targetCFrame)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local duration = (root.Position - targetCFrame.Position).Magnitude / mySettings.TweenSpeed
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait()
end

local function startBossSequence()
    bossStatus.Text = "Status: Moving to Boss..."
    safeMove(BOSS_CONFIG.BossCFrame)
    task.wait(1)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    task.wait(2)
    local enterButton = nil
    for _, v in pairs(player:WaitForChild("PlayerGui"):GetDescendants()) do
        if v:IsA("TextButton") and (v.Name:find("Enter") or v.Text:find("ENTER")) and v.Visible then
            enterButton = v break
        end
    end
    if enterButton then
        bossStatus.Text = "Status: Entering Party"
        local pos, size = enterButton.AbsolutePosition, enterButton.AbsoluteSize
        VirtualInputManager:SendMouseButtonEvent(pos.X + (size.X/2), pos.Y + (size.Y/2) + 56, 0, true, game, 0)
        task.wait(0.1)
        VirtualInputManager:SendMouseButtonEvent(pos.X + (size.X/2), pos.Y + (size.Y/2) + 56, 0, false, game, 0)
        return true
    end
    return false
end

-- BUTTON CONNECTIONS
bossToggleBtn.MouseButton1Click:Connect(function()
    mySettings.AutoBossEnabled = not mySettings.AutoBossEnabled
    bossToggleBtn.Text = mySettings.AutoBossEnabled and "AUTO BOSS: ON" or "AUTO BOSS: OFF"
    bossToggleBtn.BackgroundColor3 = mySettings.AutoBossEnabled and Color3.fromRGB(0, 120, 70) or Color3.fromRGB(100, 0, 0)
    if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
end)

speedInput.FocusLost:Connect(function()
    mySettings.TweenSpeed = tonumber(speedInput.Text) or 40
    if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
end)

safetyInput.FocusLost:Connect(function()
    mySettings.SafetyReturn = tonumber(safetyInput.Text) or 90
    if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
end)

resetB.MouseButton1Click:Connect(function() if isfile(LOCAL_FILE) then delfile(LOCAL_FILE) end player:Kick("Watchdog Reset complete.") end)
CloseBtn.MouseButton1Click:Connect(function() _G.WatchdogRunning = false; ScreenGui:Destroy() end)

-- MAIN LOOPS
task.spawn(function()
    local hasReturnedThisCycle = false
    while _G.WatchdogRunning do
        local currentTime = os.time()
        local secondsIntoCycle = currentTime % (BOSS_CONFIG.SyncInterval * 60)
        local secondsRemaining = (BOSS_CONFIG.SyncInterval * 60) - secondsIntoCycle
        
        -- Update Timer
        local timeStr = string.format("%02d:%02d", math.floor(secondsRemaining / 60), secondsRemaining % 60)
        bossTimerLabel.Text = "Next Boss: " .. timeStr
        
        if mySettings.AutoBossEnabled and isInForge then
            -- 1. Safety Return
            if secondsRemaining <= mySettings.SafetyReturn and secondsRemaining > 10 and not hasReturnedThisCycle then
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root and (root.Position - BOSS_CONFIG.WaitAreaCFrame.Position).Magnitude > 30 then
                    bossStatus.Text = "Status: Safety Return..."
                    root.CFrame = BOSS_CONFIG.WaitAreaCFrame
                end
                hasReturnedThisCycle = true
            end
            
            -- 2. Trigger Spawn
            if secondsRemaining <= 3 or secondsRemaining >= (BOSS_CONFIG.SyncInterval * 60) - 1 then
                bossStatus.Text = "Status: Spawning!"
                hasReturnedThisCycle = false
                local success = startBossSequence()
                if success then task.wait(60) end
            end
        else
            bossStatus.Text = "Status: Standby"
            hasReturnedThisCycle = false
        end
        task.wait(1)
    end
end)

-- Original Heartbeat Loop
task.spawn(function()
    sendWebhook("🔄 Integrated Watchdog", "System Online v6.4.2", 1752220, false)
    while _G.WatchdogRunning do
        if monitorActive then
            local timeLeft = HEARTBEAT_INTERVAL
            while timeLeft > 0 and _G.WatchdogRunning and monitorActive do
                timerLabel.Text = string.format("%02d:%02d", math.floor(timeLeft/60), timeLeft%60)
                task.wait(1); timeLeft = timeLeft - 1
            end
            if _G.WatchdogRunning and monitorActive then sendWebhook("🔄 Heartbeat", "Stable.", 1752220, false) end
        else
            timerLabel.Text = "PAUSED"; task.wait(1)
        end
    end
end)

-- UI Dragging
local dragging, dragStart, startPos
MainFrame.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragStart = input.Position startPos = MainFrame.Position end end)
MainFrame.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then local delta = input.Position - dragStart MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
