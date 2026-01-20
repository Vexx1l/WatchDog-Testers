-- [[ WATCHDOG & HEARTBEAT FUSION V6.0 ]] --
-- [[ ALL-IN-ONE PERFORMANCE SUITE ]] --

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
while not player do task.wait(0.1) player = Players.LocalPlayer end

-- 1. PREVENT DOUBLE EXECUTION
if _G.FusionRunning then 
    _G.FusionRunning = false 
    task.wait(0.5) 
end
_G.FusionRunning = true
local SESSION_ID = tick()
_G.CurrentSession = SESSION_ID

-- 2. DATA / JSON SYSTEM
local GLOBAL_FILE = "FusionSuite_GLOBAL.json"
local LOCAL_FILE = "FusionSuite_" .. player.Name .. ".json"

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
local antiAfkActive = false
local autoRejoinActive = mySettings.AutoRejoin
local afkBaseInterval = mySettings.AntiAfkInterval
local startTime = os.time()

-- 3. UTILITIES
local function save()
    if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
end

local function getUptimeString()
    local diff = os.time() - startTime
    return string.format("%dh %dm %ds", math.floor(diff/3600), math.floor((diff%3600)/60), diff%60)
end

-- Webhook Rate Limit Logic
local isBlocked = false
local blockExpires = 0

local function sendWebhook(title, reason, color)
    if WEBHOOK_URL == "" or WEBHOOK_URL == "PASTE_WEBHOOK_HERE" or not _G.FusionRunning then return end
    if isBlocked and tick() < blockExpires then return end

    local payload = HttpService:JSONEncode({
        content = (title ~= "🔄 Heartbeat") and "<@" .. DISCORD_USER_ID .. ">" or nil,
        embeds = {{
            title = title,
            color = color or 1752220,
            description = "Status for **" .. player.Name .. "**",
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            fields = {
                { name = "🎮 Game", value = "The Forge", inline = true },
                { name = "📊 Session", value = getUptimeString(), inline = true },
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

-- 4. UI CREATION (Modernized)
local ScreenGui = Instance.new("ScreenGui", (game:GetService("CoreGui") or player.PlayerGui))
ScreenGui.Name = "FusionMonitor_V6"

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 300, 0, 350)
Main.Position = UDim2.new(0.5, -150, 0.5, -175)
Main.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
Main.BorderSizePixel = 0
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
local Stroke = Instance.new("UIStroke", Main)
Stroke.Color = Color3.fromRGB(45, 52, 71)
Stroke.Thickness = 2

-- Top Bar
local TopBar = Instance.new("Frame", Main)
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Color3.fromRGB(22, 25, 38)
TopBar.BorderSizePixel = 0
local TCorner = Instance.new("UICorner", TopBar)

local Title = Instance.new("TextLabel", TopBar)
Title.Size = UDim2.new(1, 0, 1, 0)
Title.Text = "WATCHDOG FUSION V6.0"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 5)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseBtn.BackgroundTransparency = 1
CloseBtn.TextSize = 18

local MinBtn = Instance.new("TextButton", TopBar)
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -65, 0, 5)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
MinBtn.BackgroundTransparency = 1
MinBtn.TextSize = 18

-- Tab System
local TabContainer = Instance.new("Frame", Main)
TabContainer.Size = UDim2.new(1, -20, 0, 30)
TabContainer.Position = UDim2.new(0, 10, 0, 45)
TabContainer.BackgroundTransparency = 1

local function createTabBtn(name, pos)
    local b = Instance.new("TextButton", TabContainer)
    b.Size = UDim2.new(0.48, 0, 1, 0)
    b.Position = pos
    b.Text = name
    b.BackgroundColor3 = Color3.fromRGB(30, 35, 54)
    b.TextColor3 = Color3.fromRGB(200, 200, 200)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local monitorTabBtn = createTabBtn("MONITOR", UDim2.new(0, 0, 0, 0))
local shieldTabBtn = createTabBtn("SHIELD", UDim2.new(0.52, 0, 0, 0))

-- Pages
local MonitorPage = Instance.new("Frame", Main)
MonitorPage.Size = UDim2.new(1, -20, 1, -100)
MonitorPage.Position = UDim2.new(0, 10, 0, 85)
MonitorPage.BackgroundTransparency = 1

local ShieldPage = Instance.new("Frame", Main)
ShieldPage.Size = UDim2.new(1, -20, 1, -100)
ShieldPage.Position = UDim2.new(0, 10, 0, 85)
ShieldPage.BackgroundTransparency = 1
ShieldPage.Visible = false

-- [[ MONITOR PAGE CONTENT ]] --
local TimerDisplay = Instance.new("TextLabel", MonitorPage)
TimerDisplay.Size = UDim2.new(1, 0, 0, 60)
TimerDisplay.Text = "00:00"
TimerDisplay.TextColor3 = Color3.fromRGB(0, 180, 255)
TimerDisplay.Font = Enum.Font.GothamBold
TimerDisplay.TextSize = 40
TimerDisplay.BackgroundTransparency = 1

local function createActionBtn(text, pos, color, parent)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0.3, 0, 0, 30)
    b.Position = pos
    b.Text = text
    b.BackgroundColor3 = Color3.fromRGB(30, 35, 54)
    b.TextColor3 = color
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    Instance.new("UICorner", b)
    return b
end

local bTime = createActionBtn("TIME", UDim2.new(0, 0, 0.4, 0), Color3.fromRGB(0, 255, 150), MonitorPage)
local bCfg = createActionBtn("CONFIG", UDim2.new(0.35, 0, 0.4, 0), Color3.fromRGB(255, 180, 0), MonitorPage)
local bTest = createActionBtn("TEST", UDim2.new(0.7, 0, 0.4, 0), Color3.fromRGB(200, 100, 255), MonitorPage)
local bHub = createActionBtn("HUB", UDim2.new(0, 0, 0.55, 0), Color3.fromRGB(255, 255, 255), MonitorPage)
local bReset = createActionBtn("RESET", UDim2.new(0.35, 0, 0.55, 0), Color3.fromRGB(255, 80, 80), MonitorPage)

-- [[ SHIELD PAGE CONTENT ]] --
local StatusWindow = Instance.new("TextLabel", ShieldPage)
StatusWindow.Size = UDim2.new(1, 0, 0, 50)
StatusWindow.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
StatusWindow.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusWindow.Text = "Status: STANDBY\nRejoin: OFF"
StatusWindow.Font = Enum.Font.Code
StatusWindow.TextSize = 12
Instance.new("UICorner", StatusWindow)

local AfkInput = Instance.new("TextBox", ShieldPage)
AfkInput.Size = UDim2.new(1, 0, 0, 35)
AfkInput.Position = UDim2.new(0, 0, 0.25, 0)
AfkInput.PlaceholderText = "Movement Interval (Seconds)"
AfkInput.Text = tostring(afkBaseInterval)
AfkInput.BackgroundColor3 = Color3.fromRGB(30, 35, 54)
AfkInput.TextColor3 = Color3.fromRGB(0, 200, 255)
Instance.new("UICorner", AfkInput)

local bAntiAfk = Instance.new("TextButton", ShieldPage)
bAntiAfk.Size = UDim2.new(1, 0, 0, 40)
bAntiAfk.Position = UDim2.new(0, 0, 0.42, 0)
bAntiAfk.Text = "ANTI-AFK: OFF"
bAntiAfk.BackgroundColor3 = Color3.fromRGB(40, 45, 65)
bAntiAfk.TextColor3 = Color3.new(1,1,1)
bAntiAfk.Font = Enum.Font.GothamBold
Instance.new("UICorner", bAntiAfk)

local bRejoin = Instance.new("TextButton", ShieldPage)
bRejoin.Size = UDim2.new(1, 0, 0, 40)
bRejoin.Position = UDim2.new(0, 0, 0.58, 0)
bRejoin.Text = "AUTO-REJOIN: OFF"
bRejoin.BackgroundColor3 = Color3.fromRGB(40, 45, 65)
bRejoin.TextColor3 = Color3.new(1,1,1)
bRejoin.Font = Enum.Font.GothamBold
Instance.new("UICorner", bRejoin)

-- 5. LOGIC & CONNECTIONS

-- Tab Switching
monitorTabBtn.MouseButton1Click:Connect(function()
    MonitorPage.Visible = true; ShieldPage.Visible = false
    monitorTabBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 71)
    shieldTabBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 54)
end)

shieldTabBtn.MouseButton1Click:Connect(function()
    ShieldPage.Visible = true; MonitorPage.Visible = false
    shieldTabBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 71)
    monitorTabBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 54)
end)

-- Shield Controls
bAntiAfk.MouseButton1Click:Connect(function()
    antiAfkActive = not antiAfkActive
    bAntiAfk.Text = antiAfkActive and "ANTI-AFK: ACTIVE" or "ANTI-AFK: OFF"
    bAntiAfk.BackgroundColor3 = antiAfkActive and Color3.fromRGB(0, 120, 80) or Color3.fromRGB(40, 45, 65)
end)

bRejoin.MouseButton1Click:Connect(function()
    autoRejoinActive = not autoRejoinActive
    mySettings.AutoRejoin = autoRejoinActive
    bRejoin.Text = autoRejoinActive and "AUTO-REJOIN: ON" or "AUTO-REJOIN: OFF"
    bRejoin.BackgroundColor3 = autoRejoinActive and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(40, 45, 65)
    save()
end)

AfkInput.FocusLost:Connect(function()
    local val = tonumber(AfkInput.Text)
    if val then afkBaseInterval = math.clamp(val, 15, 2000); mySettings.AntiAfkInterval = afkBaseInterval; save() end
end)

-- Monitor Controls (Config, Test, etc)
bTest.MouseButton1Click:Connect(function() sendWebhook("🧪 Test", "Manual test successful!", 10181046) end)
bReset.MouseButton1Click:Connect(function() if isfile(LOCAL_FILE) then delfile(LOCAL_FILE) end player:Kick("Resetting Settings...") end)
CloseBtn.MouseButton1Click:Connect(function() _G.FusionRunning = false; ScreenGui:Destroy() end)

-- Anti-Idle Logic
player.Idled:Connect(function()
    if antiAfkActive then
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(0.1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

-- Auto-Rejoin Logic
GuiService.ErrorMessageChanged:Connect(function()
    if autoRejoinActive then
        task.wait(3)
        TeleportService:Teleport(game.PlaceId, player)
    end
end)

-- 6. MAIN LOOPS
task.spawn(function()
    sendWebhook("🔄 Fusion Suite Online", "System v6.0 Initialized.", 1752220)
    local lastAfkMove = tick()
    
    while _G.FusionRunning and _G.CurrentSession == SESSION_ID do
        local heartbeatLeft = HEARTBEAT_INTERVAL
        while heartbeatLeft > 0 and _G.FusionRunning do
            -- Update UI Timer
            TimerDisplay.Text = string.format("%02d:%02d", math.floor(heartbeatLeft/60), heartbeatLeft%60)
            
            -- Shield Status Update
            local afkLeft = math.ceil(afkBaseInterval - (tick() - lastAfkMove))
            if antiAfkActive then
                StatusWindow.Text = string.format("Status: PROTECTED\nNext Move: %ds", afkLeft)
                if afkLeft <= 0 then
                    -- Physical Movement
                    local char = player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum then hum:MoveTo(char.PrimaryPart.Position + Vector3.new(math.random(-5,5), 0, math.random(-5,5))) end
                    lastAfkMove = tick()
                end
            else
                StatusWindow.Text = "Status: STANDBY\nAnti-AFK is OFF"
            end
            
            task.wait(1)
            heartbeatLeft = heartbeatLeft - 1
        end
        
        if _G.FusionRunning then
            sendWebhook("🔄 Heartbeat", "Session Stable.", 1752220)
        end
    end
end)

-- Draggable UI
local dragging, dragInput, dragStart, startPos
Main.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragStart = input.Position startPos = Main.Position end end)
Main.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then 
    local delta = input.Position - dragStart 
    Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) 
end end)

print("Watchdog Fusion V6.0 Loaded Successfully.")
