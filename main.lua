-- [[ WATCHDOG INTEGRATED - VERSION 6.4.2 ]] --
-- [[ Boss Farmer Integration Added ]] --

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- PLACE NAME OVERRIDES & DETECTION
local forgePlaceIds = {
    [76558904092080]  = "The Forge (World 1)",
    [129009554587176] = "The Forge (World 2)",
    [131884594917121] = "The Forge (World 3)",
    [74414241680540]  = "The Forge (World 4)"
}
local isInForge = forgePlaceIds[game.PlaceId] ~= nil
local success, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
local currentGameName = forgePlaceIds[game.PlaceId] or (success and info.Name) or "Unknown Game"

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

local LOCAL_FILE = "Watchdog_" .. player.Name .. ".json"

local function loadData(file, default)
    if isfile and isfile(file) then
        local s, d = pcall(function() return HttpService:JSONDecode(readfile(file)) end)
        if s then return d end
    end
    return default
end

local mySettings = loadData(LOCAL_FILE, {
    Timer = 600, 
    Webhook = "PASTE_WEBHOOK_HERE", 
    UserID = "958143880291823647",
    AntiAfkTime = 300,
    AutoRejoin = false,
    MonitorEnabled = true,
    ThemeColor = {0, 170, 255},
    -- Boss Settings
    BossEnabled = false,
    SpamEnabled = false,
    BossQuantity = 5,
    TweenSpeed = 40,
    SafetyTime = 90
})

local HEARTBEAT_INTERVAL = mySettings.Timer
local WEBHOOK_URL = mySettings.Webhook:gsub("%s+", "")
local DISCORD_USER_ID = mySettings.UserID
local startTime = os.time()
local monitorActive = mySettings.MonitorEnabled

-- Boss Config Constants
local BOSS_CONFIG = {
    BossCFrame = CFrame.new(92.62, 127.55, 221.76),
    WaitAreaCFrame = CFrame.new(-149.65, 18.56, -592.88),
    SyncInterval = 5
}

-- 3. WEBHOOK CORE
local function sendWebhook(title, reason, color)
    if not monitorActive or WEBHOOK_URL == "" or WEBHOOK_URL == "PASTE_WEBHOOK_HERE" then return end
    
    local embed = {
        ["title"] = title,
        ["description"] = "Status for **" .. player.Name .. "**\n```" .. reason .. "```",
        ["color"] = color or 1752220,
        ["fields"] = {
            { ["name"] = "🎮 Game", ["value"] = currentGameName, ["inline"] = true },
            { ["name"] = "📊 Uptime", ["value"] = os.date("!%X", os.time() - startTime), ["inline"] = true }
        },
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local requestFunc = (request or http_request or syn.request)
    if requestFunc then
        task.spawn(function()
            pcall(function()
                requestFunc({
                    Url = WEBHOOK_URL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({["content"] = "<@" .. DISCORD_USER_ID .. ">", ["embeds"] = {embed}})
                })
            end)
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
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

local function getThemeColor() return Color3.fromRGB(unpack(mySettings.ThemeColor)) end
local Stroke = Instance.new("UIStroke", MainFrame); Stroke.Color = getThemeColor(); Stroke.Thickness = 2

-- Top Bar
local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 35); TopBar.BackgroundTransparency = 1
local Title = Instance.new("TextLabel", TopBar)
Title.Size = UDim2.new(1, 0, 1, 0); Title.Text = "WATCHDOG v6.4.2"; Title.TextColor3 = Color3.new(1,1,1); Title.Font = Enum.Font.GothamBold; Title.TextSize = 10; Title.BackgroundTransparency = 1

-- Tabs
local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1, 0, 1, -70); Content.Position = UDim2.new(0, 0, 0, 35); Content.BackgroundTransparency = 1
local Nav = Instance.new("Frame", MainFrame)
Nav.Size = UDim2.new(1, 0, 0, 35); Nav.Position = UDim2.new(0, 0, 1, -35); Nav.BackgroundColor3 = Color3.fromRGB(25, 25, 30)

local TabContainer = Instance.new("Frame", Content)
TabContainer.Size = UDim2.new(1, -20, 1, 0); TabContainer.Position = UDim2.new(0, 10, 0, 5); TabContainer.BackgroundTransparency = 1

local function createTab()
    local f = Instance.new("Frame", TabContainer); f.Size = UDim2.new(1, 0, 1, 0); f.Visible = false; f.BackgroundTransparency = 1; return f
end

local MonitorTab = createTab()
local ShieldTab = createTab()
local SettingsTab = createTab()
local BossTab = createTab()

-- Navigation Logic
local navCount = isInForge and 4 or 3
local function navBtn(name, idx)
    local b = Instance.new("TextButton", Nav)
    b.Size = UDim2.new(1/navCount, 0, 1, 0)
    b.Position = UDim2.new((idx-1)/navCount, 0, 0, 0)
    b.Text = name; b.BackgroundTransparency = 1; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamBold; b.TextSize = 8; return b
end

navBtn("MONITOR", 1).MouseButton1Click:Connect(function() 
    MonitorTab.Visible = true; ShieldTab.Visible = false; SettingsTab.Visible = false; BossTab.Visible = false 
end)
navBtn("SHIELD", 2).MouseButton1Click:Connect(function() 
    MonitorTab.Visible = false; ShieldTab.Visible = true; SettingsTab.Visible = false; BossTab.Visible = false 
end)
navBtn("SETTINGS", 3).MouseButton1Click:Connect(function() 
    MonitorTab.Visible = false; ShieldTab.Visible = false; SettingsTab.Visible = true; BossTab.Visible = false 
end)

if isInForge then
    navBtn("BOSS", 4).MouseButton1Click:Connect(function() 
        MonitorTab.Visible = false; ShieldTab.Visible = false; SettingsTab.Visible = false; BossTab.Visible = true 
    end)
end
MonitorTab.Visible = true

-- BOSS TAB CONTENT
local bossTimer = Instance.new("TextLabel", BossTab)
bossTimer.Size = UDim2.new(1, 0, 0, 40); bossTimer.Text = "Boss: --:--"; bossTimer.TextColor3 = Color3.new(1, 0.8, 0); bossTimer.Font = Enum.Font.GothamBold; bossTimer.TextSize = 20; bossTimer.BackgroundTransparency = 1

local bossToggle = Instance.new("TextButton", BossTab)
bossToggle.Size = UDim2.new(1, 0, 0, 30); bossToggle.Position = UDim2.new(0, 0, 0, 45); bossToggle.BackgroundColor3 = mySettings.BossEnabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
bossToggle.Text = "AUTO BOSS: " .. (mySettings.BossEnabled and "ON" or "OFF"); bossToggle.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", bossToggle)

local spamToggle = Instance.new("TextButton", BossTab)
spamToggle.Size = UDim2.new(1, 0, 0, 30); spamToggle.Position = UDim2.new(0, 0, 0, 80); spamToggle.BackgroundColor3 = mySettings.SpamEnabled and Color3.fromRGB(0, 120, 120) or Color3.fromRGB(80, 80, 80)
spamToggle.Text = "MULTI-SPAM: " .. (mySettings.SpamEnabled and "ON" or "OFF"); spamToggle.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", spamToggle)

local function createInput(placeholder, text, pos)
    local i = Instance.new("TextBox", BossTab); i.Size = UDim2.new(1, 0, 0, 25); i.Position = pos; i.PlaceholderText = placeholder; i.Text = tostring(text)
    i.BackgroundColor3 = Color3.fromRGB(30,30,35); i.TextColor3 = Color3.new(1,1,1); i.TextSize = 10; Instance.new("UICorner", i); return i
end

local qtyIn = createInput("Quantity (Multi-Summon)", mySettings.BossQuantity, UDim2.new(0,0,0,115))
local speedIn = createInput("Tween Speed", mySettings.TweenSpeed, UDim2.new(0,0,0,145))
local safeIn = createInput("Safety Time (Secs)", mySettings.SafetyTime, UDim2.new(0,0,0,175))

-- 5. BOSS LOGIC
local function saveBoss()
    mySettings.BossQuantity = tonumber(qtyIn.Text) or 5
    mySettings.TweenSpeed = tonumber(speedIn.Text) or 40
    mySettings.SafetyTime = tonumber(safeIn.Text) or 90
    if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
end

bossToggle.MouseButton1Click:Connect(function()
    mySettings.BossEnabled = not mySettings.BossEnabled
    bossToggle.Text = "AUTO BOSS: " .. (mySettings.BossEnabled and "ON" or "OFF")
    bossToggle.BackgroundColor3 = mySettings.BossEnabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    saveBoss()
end)

spamToggle.MouseButton1Click:Connect(function()
    mySettings.SpamEnabled = not mySettings.SpamEnabled
    spamToggle.Text = "MULTI-SPAM: " .. (mySettings.SpamEnabled and "ON" or "OFF")
    spamToggle.BackgroundColor3 = mySettings.SpamEnabled and Color3.fromRGB(0, 120, 120) or Color3.fromRGB(80, 80, 80)
    saveBoss()
end)

qtyIn.FocusLost:Connect(saveBoss)
speedIn.FocusLost:Connect(saveBoss)
safeIn.FocusLost:Connect(saveBoss)

local function ultraSummon()
    local count = mySettings.SpamEnabled and mySettings.BossQuantity or 1
    for i = 1, count do
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        
        task.wait(0.15) 
        local enterBtn = nil
        for _, v in pairs(player.PlayerGui:GetDescendants()) do
            if v:IsA("TextButton") and v.Text:upper():find("ENTER") and v.Visible then enterBtn = v break end
        end

        if enterBtn then
            GuiService.SelectedObject = enterBtn
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
            GuiService.SelectedObject = nil
        end
        task.wait(0.05)
    end
end

-- 6. MAIN LOOPS
task.spawn(function()
    local hasReturned = false
    while _G.WatchdogRunning do
        local currentTime = os.time()
        local secondsRemaining = (BOSS_CONFIG.SyncInterval * 60) - (currentTime % (BOSS_CONFIG.SyncInterval * 60))
        
        if isInForge then
            bossTimer.Text = string.format("Boss: %02d:%02d", math.floor(secondsRemaining/60), secondsRemaining%60)
            
            if mySettings.BossEnabled then
                -- Safety Return
                if secondsRemaining <= mySettings.SafetyTime and secondsRemaining > 10 and not hasReturned then
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        player.Character.HumanoidRootPart.CFrame = BOSS_CONFIG.WaitAreaCFrame
                    end
                    hasReturned = true
                end

                -- Arrival and Summon
                if secondsRemaining <= 3 or secondsRemaining >= (BOSS_CONFIG.SyncInterval * 60) - 1 then
                    hasReturned = false
                    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local dist = (root.Position - BOSS_CONFIG.BossCFrame.Position).Magnitude
                        TweenService:Create(root, TweenInfo.new(dist/mySettings.TweenSpeed, Enum.EasingStyle.Linear), {CFrame = BOSS_CONFIG.BossCFrame}):Play()
                        task.wait(dist/mySettings.TweenSpeed + 0.5)
                    end
                    ultraSummon()
                    sendWebhook("⚔️ Boss Entry", "Successfully entered " .. (mySettings.SpamEnabled and mySettings.BossQuantity or 1) .. " fight(s).", 15105570)
                    task.wait(10)
                end
            end
        end
        task.wait(1)
    end
end)

-- (The rest of your Monitor/Shield logic from v6.4.1 continues here...)
sendWebhook("🔄 Watchdog v6.4.2", "System Loaded with Boss Integration.", 1752220)
