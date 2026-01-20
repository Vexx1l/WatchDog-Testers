-- [[ WATCHDOG SENTINEL V6.0 - THE UNIFIED UPDATE ]] --
-- Combining Heartbeat V2 + Watchdog Shield + New UI Architecture

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
if _G.SentinelRunning then 
    _G.SentinelRunning = false 
    task.wait(0.5) 
end
_G.SentinelRunning = true
local SESSION_ID = tick()
_G.CurrentSession = SESSION_ID

-- 1. DATA MANAGEMENT
local SETTINGS_FILE = "WatchdogSentinel_" .. player.Name .. ".json"
local defaultSettings = {
    Webhook = "PASTE_WEBHOOK_HERE",
    UserID = "958143880291823647",
    HeartbeatTimer = 600,
    AntiAfkTimer = 300,
    AutoRejoin = false,
    AntiAfkActive = false
}

local function loadSettings()
    if isfile and isfile(SETTINGS_FILE) then
        local s, d = pcall(function() return HttpService:JSONDecode(readfile(SETTINGS_FILE)) end)
        if s then return d end
    end
    return defaultSettings
end

local function saveSettings(data)
    if writefile then writefile(SETTINGS_FILE, HttpService:JSONEncode(data)) end
end

local mySettings = loadSettings()

-- 2. CORE VARIABLES
local startTime = os.time()
local isBlocked = false
local blockExpires = 0
local lastAfkAction = tick()
local currentAfkInterval = mySettings.AntiAfkTimer

-- 3. UTILITY FUNCTIONS
local function getUptime()
    local diff = os.time() - startTime
    return string.format("%dh %dm %ds", math.floor(diff/3600), math.floor((diff%3600)/60), diff%60)
end

-- Webhook Logic (Integrated Rate-Limit)
local function sendWebhook(title, reason, color)
    if mySettings.Webhook == "" or mySettings.Webhook == "PASTE_WEBHOOK_HERE" then return end
    if isBlocked and tick() < blockExpires then return end

    local payload = HttpService:JSONEncode({
        content = (title ~= "🔄 Heartbeat") and "<@" .. mySettings.UserID .. ">" or nil,
        embeds = {{
            title = title,
            color = color or 1752220,
            description = "Status for **" .. player.Name .. "**",
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            fields = {
                {name = "🎮 Game", value = MarketplaceService:GetProductInfo(game.PlaceId).Name, inline = true},
                {name = "📊 Uptime", value = getUptime(), inline = true},
                {name = "💬 Status", value = "```" .. reason .. "```", inline = false}
            }
        }}
    })

    local requestFunc = (request or http_request or syn.request or (http and http.request))
    if requestFunc then
        task.spawn(function()
            local success, response = pcall(function()
                return requestFunc({
                    Url = mySettings.Webhook,
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

-- 4. UI CONSTRUCTION (RENOVATED)
local ScreenGui = Instance.new("ScreenGui", (game:GetService("CoreGui") or player.PlayerGui))
ScreenGui.Name = "WatchdogSentinel_UI"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 400, 0, 280)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -140)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(0, 170, 255)

-- Sidebar
local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size = UDim2.new(0, 100, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 10)

-- Header Title
local Header = Instance.new("TextLabel", MainFrame)
Header.Size = UDim2.new(1, -110, 0, 30)
Header.Position = UDim2.new(0, 110, 0, 5)
Header.Text = "SENTINEL v6.0"
Header.TextColor3 = Color3.fromRGB(0, 170, 255)
Header.Font = Enum.Font.GothamBold
Header.BackgroundTransparency = 1
Header.TextXAlignment = Enum.TextXAlignment.Left

-- Container for Tabs
local TabContainer = Instance.new("Frame", MainFrame)
TabContainer.Size = UDim2.new(1, -120, 1, -45)
TabContainer.Position = UDim2.new(0, 110, 0, 35)
TabContainer.BackgroundTransparency = 1

-- Min/Close Buttons
local CloseBtn = Instance.new("TextButton", MainFrame)
CloseBtn.Size = UDim2.new(0, 25, 0, 25); CloseBtn.Position = UDim2.new(1, -30, 0, 5)
CloseBtn.Text = "✕"; CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80); CloseBtn.BackgroundTransparency = 1

local MinBtn = Instance.new("TextButton", MainFrame)
MinBtn.Size = UDim2.new(0, 25, 0, 25); MinBtn.Position = UDim2.new(0, 5, 0, 5)
MinBtn.Text = "-"; MinBtn.TextColor3 = Color3.fromRGB(0, 255, 255); MinBtn.BackgroundTransparency = 1

-- 5. TAB SYSTEM LOGIC
local tabs = {}
local function createTab(name, icon)
    local btn = Instance.new("TextButton", Sidebar)
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, #Sidebar:GetChildren() * 35 + 10)
    btn.Text = name; btn.Font = Enum.Font.Gotham; btn.TextSize = 10
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40); btn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", btn)

    local page = Instance.new("ScrollingFrame", TabContainer)
    page.Size = UDim2.new(1, 0, 1, 0); page.Visible = false; page.BackgroundTransparency = 1
    page.ScrollBarThickness = 2; page.CanvasSize = UDim2.new(0,0,1.5,0)
    local layout = Instance.new("UIListLayout", page); layout.Padding = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(tabs) do p.Visible = false end
        page.Visible = true
    end)
    tabs[name] = page
    return page
end

-- TABS CREATION
local dashPage = createTab("DASHBOARD")
local configPage = createTab("CONFIG")
local watchdogPage = createTab("WATCHDOG")
local hubPage = createTab("HUB")

-- [DASHBOARD TAB]
local statusLbl = Instance.new("TextLabel", dashPage)
statusLbl.Size = UDim2.new(1, 0, 0, 60); statusLbl.BackgroundColor3 = Color3.fromRGB(20,20,30)
statusLbl.TextColor3 = Color3.new(1,1,1); statusLbl.Font = Enum.Font.Code; statusLbl.TextSize = 12
statusLbl.Text = "Uptime: 0s\nHeartbeat: Waiting..."; Instance.new("UICorner", statusLbl)

local testBtn = Instance.new("TextButton", dashPage)
testBtn.Size = UDim2.new(1,0,0,30); testBtn.Text = "SEND TEST WEBHOOK"; testBtn.BackgroundColor3 = Color3.fromRGB(40,40,60)
testBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", testBtn)
testBtn.MouseButton1Click:Connect(function() sendWebhook("🧪 Test", "Manual Trigger", 10181046) end)

-- [CONFIG TAB]
local function createInput(parent, label, default)
    local lbl = Instance.new("TextLabel", parent); lbl.Size = UDim2.new(1,0,0,15); lbl.Text = label; lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.new(0.7,0.7,0.7); lbl.TextXAlignment = 0; lbl.TextSize = 10
    local box = Instance.new("TextBox", parent); box.Size = UDim2.new(1,0,0,30); box.Text = tostring(default); box.BackgroundColor3 = Color3.fromRGB(25,25,35); box.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", box)
    return box
end

local webhookBox = createInput(configPage, "Webhook URL", mySettings.Webhook)
local userIdBox = createInput(configPage, "Discord User ID", mySettings.UserID)
local hbBox = createInput(configPage, "Heartbeat Interval (Sec)", mySettings.HeartbeatTimer)

local saveBtn = Instance.new("TextButton", configPage)
saveBtn.Size = UDim2.new(1,0,0,35); saveBtn.Text = "SAVE CONFIG"; saveBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
saveBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", saveBtn)
saveBtn.MouseButton1Click:Connect(function()
    mySettings.Webhook = webhookBox.Text:gsub("%s+", "")
    mySettings.UserID = userIdBox.Text
    mySettings.HeartbeatTimer = tonumber(hbBox.Text) or 600
    saveSettings(mySettings)
    saveBtn.Text = "SAVED!"
    task.wait(1); saveBtn.Text = "SAVE CONFIG"
end)

-- [WATCHDOG TAB]
local afkBox = createInput(watchdogPage, "AFK Interval (Sec)", mySettings.AntiAfkTimer)
local afkToggle = Instance.new("TextButton", watchdogPage)
afkToggle.Size = UDim2.new(1,0,0,40); afkToggle.Text = "ANTI-AFK: " .. (mySettings.AntiAfkActive and "ON" or "OFF")
afkToggle.BackgroundColor3 = mySettings.AntiAfkActive and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(50, 50, 60)
afkToggle.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", afkToggle)

local rejoinToggle = Instance.new("TextButton", watchdogPage)
rejoinToggle.Size = UDim2.new(1,0,0,40); rejoinToggle.Text = "AUTO-REJOIN: " .. (mySettings.AutoRejoin and "ON" or "OFF")
rejoinToggle.BackgroundColor3 = mySettings.AutoRejoin and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(50, 50, 60)
rejoinToggle.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", rejoinToggle)

afkToggle.MouseButton1Click:Connect(function()
    mySettings.AntiAfkActive = not mySettings.AntiAfkActive
    afkToggle.Text = "ANTI-AFK: " .. (mySettings.AntiAfkActive and "ON" or "OFF")
    afkToggle.BackgroundColor3 = mySettings.AntiAfkActive and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(50, 50, 60)
    saveSettings(mySettings)
end)

rejoinToggle.MouseButton1Click:Connect(function()
    mySettings.AutoRejoin = not mySettings.AutoRejoin
    rejoinToggle.Text = "AUTO-REJOIN: " .. (mySettings.AutoRejoin and "ON" or "OFF")
    rejoinToggle.BackgroundColor3 = mySettings.AutoRejoin and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(50, 50, 60)
    saveSettings(mySettings)
end)

-- [HUB TAB]
local function createLink(txt, link)
    local b = Instance.new("TextButton", hubPage); b.Size = UDim2.new(1,0,0,30); b.Text = txt; b.BackgroundColor3 = Color3.fromRGB(35,35,45); b.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function() setclipboard(link); b.Text = "COPIED!"; task.wait(1); b.Text = txt end)
end
createLink("Discord Server", "https://discord.gg/c3F7p2ygPJ")
createLink("Bot Invite", "https://discord.com/oauth2/authorize?client_id=1460862231926407252&permissions=8&integration_type=0&scope=bot")

-- 6. CORE LOGIC INTEGRATION
local function performMovement()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if hum and root then
        local start = root.Position
        hum:MoveTo(start + (root.CFrame.LookVector * 10))
        task.wait(2)
        hum:MoveTo(start)
    end
end

-- REJOIN HANDLER
GuiService.ErrorMessageChanged:Connect(function()
    if mySettings.AutoRejoin then
        task.wait(5)
        TeleportService:Teleport(game.PlaceId, player)
    end
end)

-- AFK BLOCKER
player.Idled:Connect(function()
    if mySettings.AntiAfkActive then
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(0.1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

-- 7. EXECUTION LOOPS
tabs["DASHBOARD"].Visible = true -- Start at Dashboard

task.spawn(function()
    sendWebhook("🛡️ Sentinel Active", "Unified Monitor Loaded.", 1752220)
    local hbTick = 0
    while _G.SentinelRunning and _G.CurrentSession == SESSION_ID do
        -- Update Dashboard Text
        local afkTimeLeft = math.ceil(mySettings.AntiAfkTimer - (tick() - lastAfkAction))
        statusLbl.Text = string.format("Uptime: %s\nNext HB: %ds\nNext AFK Move: %ds", 
            getUptime(), 
            math.ceil(mySettings.HeartbeatTimer - hbTick),
            mySettings.AntiAfkActive and afkTimeLeft or 0
        )

        -- Heartbeat Logic
        hbTick = hbTick + 1
        if hbTick >= mySettings.HeartbeatTimer then
            sendWebhook("🔄 Heartbeat", "Stable.", 1752220)
            hbTick = 0
        end

        -- Anti-AFK Logic
        if mySettings.AntiAfkActive and tick() - lastAfkAction >= mySettings.AntiAfkTimer then
            performMovement()
            lastAfkAction = tick()
        end

        task.wait(1)
    end
end)

-- Draggable Logic
local d, ds, sp
MainFrame.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = true ds = i.Position sp = MainFrame.Position end end)
MainFrame.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)
UserInputService.InputChanged:Connect(function(i) if d and i.UserInputType == Enum.UserInputType.MouseMovement then local delta = i.Position - ds MainFrame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + delta.X, sp.Y.Scale, sp.Y.Offset + delta.Y) end end)

-- Min/Close Logic
local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    TabContainer.Visible = not isMinimized
    Sidebar.Visible = not isMinimized
    Header.Visible = not isMinimized
    MainFrame:TweenSize(isMinimized and UDim2.new(0, 100, 0, 35) or UDim2.new(0, 400, 0, 280), "Out", "Quad", 0.3, true)
end)
CloseBtn.MouseButton1Click:Connect(function() _G.SentinelRunning = false; ScreenGui:Destroy() end)
