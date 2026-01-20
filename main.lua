-- [[ WATCHDOG FUSION - BUILD 6.0 ]] --
-- [[ HEARTBEAT V2 + SHIELD V5.2 FUSION ]] --

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

-- 0. SINGLETON PROTECTION
if _G.FusionRunning then 
    _G.FusionRunning = false 
    task.wait(0.5) 
end
_G.FusionRunning = true
local SESSION_ID = tick()
_G.CurrentSession = SESSION_ID

-- 1. UNIFIED DATABASE
local SETTINGS_FILE = "WatchdogFusion_" .. player.Name .. ".json"
local defaultSettings = {
    Webhook = "PASTE_WEBHOOK_HERE",
    UserID = "958143880291823647",
    HeartbeatTimer = 600,
    AntiAfkInterval = 300,
    AutoRejoin = false,
    AntiAfkEnabled = false
}

local function loadSettings()
    if isfile and isfile(SETTINGS_FILE) then
        local s, d = pcall(function() return HttpService:JSONDecode(readfile(SETTINGS_FILE)) end)
        if s then return d end
    end
    return defaultSettings
end

local function saveSettings(tbl)
    if writefile then writefile(SETTINGS_FILE, HttpService:JSONEncode(tbl)) end
end

local FusionSettings = loadSettings()
local startTime = os.time()
local isBlocked = false
local blockExpires = 0

-- 2. CORE WEBHOOK ENGINE
local function getUptimeString()
    local diff = os.time() - startTime
    local hours = math.floor(diff / 3600)
    local mins = math.floor((diff % 3600) / 60)
    return string.format("%dh %dm", hours, mins)
end

local function sendWebhook(title, reason, color)
    local url = FusionSettings.Webhook:gsub("%s+", "")
    if url == "" or url == "PASTE_WEBHOOK_HERE" or not _G.FusionRunning then return end
    if isBlocked and tick() < blockExpires then return end

    local payload = HttpService:JSONEncode({
        content = (title ~= "🔄 Heartbeat") and "<@" .. FusionSettings.UserID .. ">" or nil,
        embeds = {{
            title = title,
            color = color or 1752220,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            fields = {
                { name = "👤 Player", value = player.Name, inline = true },
                { name = "📊 Session", value = getUptimeString(), inline = true },
                { name = "💬 Status", value = "```" .. reason .. "```", inline = false }
            }
        }}
    })

    local requestFunc = (request or http_request or syn.request or (http and http.request))
    if requestFunc then
        task.spawn(function()
            local success, response = pcall(function()
                return requestFunc({
                    Url = url, Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = payload
                })
            end)
            if response and response.StatusCode == 429 then
                isBlocked = true
                blockExpires = tick() + 60
            end
        end)
    end
end

-- 3. MODERN TABBED UI
local screenGui = Instance.new("ScreenGui", (game:GetService("CoreGui") or player.PlayerGui))
screenGui.Name = "WatchdogFusion"; screenGui.ResetOnSpawn = false

local Main = Instance.new("Frame", screenGui)
Main.Size = UDim2.new(0, 300, 0, 350); Main.Position = UDim2.new(0.5, -150, 0.5, -175)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Main.BorderSizePixel = 0
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)
local Stroke = Instance.new("UIStroke", Main); Stroke.Color = Color3.fromRGB(0, 170, 255); Stroke.Thickness = 2

-- UI DRAGGING
local dragging, dragStart, startPos
Main.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragStart = input.Position startPos = Main.Position end end)
Main.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then local delta = input.Position - dragStart Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)

-- TOP NAV
local Nav = Instance.new("Frame", Main)
Nav.Size = UDim2.new(1, 0, 0, 40); Nav.BackgroundColor3 = Color3.fromRGB(30, 30, 35); Nav.BorderSizePixel = 0
Instance.new("UICorner", Nav)

local function createTabBtn(text, pos)
    local b = Instance.new("TextButton", Nav)
    b.Size = UDim2.new(0.5, 0, 1, 0); b.Position = pos; b.Text = text
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 45); b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.BorderSizePixel = 0
    return b
end

local monitorTabBtn = createTabBtn("MONITOR", UDim2.new(0, 0, 0, 0))
local shieldTabBtn = createTabBtn("SHIELD", UDim2.new(0.5, 0, 0, 0))

-- PAGES
local MonitorPage = Instance.new("Frame", Main)
MonitorPage.Size = UDim2.new(1, 0, 1, -40); MonitorPage.Position = UDim2.new(0, 0, 0, 40); MonitorPage.BackgroundTransparency = 1

local ShieldPage = Instance.new("Frame", Main)
ShieldPage.Size = UDim2.new(1, 0, 1, -40); ShieldPage.Position = UDim2.new(0, 0, 0, 40); ShieldPage.BackgroundTransparency = 1; ShieldPage.Visible = false

monitorTabBtn.MouseButton1Click:Connect(function() MonitorPage.Visible = true; ShieldPage.Visible = false end)
shieldTabBtn.MouseButton1Click:Connect(function() MonitorPage.Visible = false; ShieldPage.Visible = true end)

-- 4. MONITOR PAGE CONTENT
local heartTimerLabel = Instance.new("TextLabel", MonitorPage)
heartTimerLabel.Size = UDim2.new(1, 0, 0, 60); heartTimerLabel.Text = "00:00"; heartTimerLabel.TextColor3 = Color3.fromRGB(0, 170, 255)
heartTimerLabel.Font = Enum.Font.GothamBold; heartTimerLabel.TextSize = 40; heartTimerLabel.BackgroundTransparency = 1

local cfgBtn = Instance.new("TextButton", MonitorPage)
cfgBtn.Size = UDim2.new(0.8, 0, 0, 40); cfgBtn.Position = UDim2.new(0.1, 0, 0.5, 0)
cfgBtn.Text = "EDIT CONFIG (WEBHOOK/ID)"; cfgBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55); cfgBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", cfgBtn)

-- 5. SHIELD PAGE CONTENT
local function createToggle(text, pos, enabled)
    local b = Instance.new("TextButton", ShieldPage)
    b.Size = UDim2.new(0.8, 0, 0, 45); b.Position = pos; b.Text = text .. (enabled and ": ON" or ": OFF")
    b.BackgroundColor3 = enabled and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(50, 50, 55)
    b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamBold
    Instance.new("UICorner", b); return b
end

local antiAfkBtn = createToggle("ANTI-AFK", UDim2.new(0.1, 0, 0.1, 0), FusionSettings.AntiAfkEnabled)
local rejoinBtn = createToggle("AUTO-REJOIN", UDim2.new(0.1, 0, 0.3, 0), FusionSettings.AutoRejoin)

local shieldStats = Instance.new("TextLabel", ShieldPage)
shieldStats.Size = UDim2.new(0.8, 0, 0, 50); shieldStats.Position = UDim2.new(0.1, 0, 0.6, 0)
shieldStats.Text = "System Standby"; shieldStats.TextColor3 = Color3.new(0.7, 0.7, 0.7); shieldStats.BackgroundTransparency = 1

-- 6. CORE LOGIC FUSION
local lastMove = tick()

antiAfkBtn.MouseButton1Click:Connect(function()
    FusionSettings.AntiAfkEnabled = not FusionSettings.AntiAfkEnabled
    antiAfkBtn.Text = "ANTI-AFK" .. (FusionSettings.AntiAfkEnabled and ": ON" or ": OFF")
    antiAfkBtn.BackgroundColor3 = FusionSettings.AntiAfkEnabled and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(50, 50, 55)
    saveSettings(FusionSettings)
end)

rejoinBtn.MouseButton1Click:Connect(function()
    FusionSettings.AutoRejoin = not FusionSettings.AutoRejoin
    rejoinBtn.Text = "AUTO-REJOIN" .. (FusionSettings.AutoRejoin and ": ON" or ": OFF")
    rejoinBtn.BackgroundColor3 = FusionSettings.AutoRejoin and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(50, 50, 55)
    saveSettings(FusionSettings)
end)

-- AFK BLOCKER
player.Idled:Connect(function()
    if FusionSettings.AntiAfkEnabled then
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(0.1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

-- ERROR/REJOIN HANDLER
GuiService.ErrorMessageChanged:Connect(function()
    local msg = GuiService:GetErrorMessage()
    if #msg > 1 and not msg:lower():find("teleport") then
        if FusionSettings.AutoRejoin then
            sendWebhook("🚨 DISCONNECT", "Critical error detected. Attempting Rejoin...", 15548997)
            task.wait(5)
            TeleportService:Teleport(game.PlaceId, player)
        else
            sendWebhook("🚨 DISCONNECT", "Error: " .. msg, 15548997)
        end
    end
end)

-- MAIN LOOPS
task.spawn(function() -- Heartbeat Loop
    sendWebhook("✅ FUSION LOADED", "Build 6.0 Active.\nShield & Monitor Synchronized.", 3066993)
    while _G.FusionRunning and _G.CurrentSession == SESSION_ID do
        local timer = FusionSettings.HeartbeatTimer
        while timer > 0 and _G.FusionRunning do
            heartTimerLabel.Text = string.format("%02d:%02d", math.floor(timer/60), timer%60)
            task.wait(1); timer = timer - 1
        end
        if _G.FusionRunning then sendWebhook("🔄 Heartbeat", "Stable.", 1752220) end
    end
end)

task.spawn(function() -- Shield Loop
    while _G.FusionRunning and _G.CurrentSession == SESSION_ID do
        if FusionSettings.AntiAfkEnabled then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            
            local nextMove = math.ceil(FusionSettings.AntiAfkInterval - (tick() - lastMove))
            shieldStats.Text = "Next AFK Check: " .. nextMove .. "s"
            
            if nextMove <= 0 and hum and root then
                local start = root.Position
                hum:MoveTo(start + (root.CFrame.LookVector * 10))
                task.wait(2)
                hum:MoveTo(start)
                lastMove = tick()
            end
        else
            shieldStats.Text = "Anti-AFK is Paused"
        end
        task.wait(1)
    end
end)
