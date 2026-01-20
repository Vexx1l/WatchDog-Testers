-- [[ PROJECT AEGIS: UNIFIED MONITOR & SHIELD ]] --
-- VERSION: 6.0.0 (FUSION UPDATE)
-- Features: Heartbeat v2 + Watchdog Shield + Rate Limit Pro

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
while not player do task.wait(0.1) player = Players.LocalPlayer end

-- 0. PREVENT DOUBLE EXECUTION
if _G.AegisLoaded then _G.AegisLoaded = false task.wait(0.5) end
_G.AegisLoaded = true
local SESSION_ID = tick()
_G.CurrentSession = SESSION_ID

-- 1. DATA & SETTINGS
local GLOBAL_FILE = "Aegis_GLOBAL.json"
local LOCAL_FILE = "Aegis_" .. player.Name .. ".json"

local function loadSettings()
    local default = {
        Timer = 600, 
        Webhook = "PASTE_WEBHOOK_HERE", 
        UserID = "958143880291823647",
        AntiAfk = false,
        AutoRejoin = false,
        Interval = 300
    }
    if isfile and isfile(LOCAL_FILE) then
        local s, d = pcall(function() return HttpService:JSONDecode(readfile(LOCAL_FILE)) end)
        if s then return d end
    end
    return default
end

local mySettings = loadSettings()
local blockExpires = 0
local isBlocked = false
local startTime = os.time()
local lastAfkAction = tick()

-- 2. WEBHOOK SYSTEM (WITH RATE-LIMIT PROTECTION)
local function sendAegisWebhook(title, reason, color, isUpdateLog)
    local url = mySettings.Webhook:gsub("%s+", "")
    if url == "" or url == "PASTE_WEBHOOK_HERE" or not _G.AegisLoaded then return end
    if isBlocked and tick() < blockExpires then return end

    local embed = {
        title = title,
        color = color or 1752220,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        description = isUpdateLog and reason or "Status for **" .. player.Name .. "**",
        fields = not isUpdateLog and {
            { name = "🎮 Game", value = MarketplaceService:GetProductInfo(game.PlaceId).Name, inline = true },
            { name = "📊 Uptime", value = string.format("%dh %dm", math.floor((os.time()-startTime)/3600), math.floor(((os.time()-startTime)%3600)/60)), inline = true },
            { name = "🛡️ Shield", value = mySettings.AntiAfk and "ACTIVE" or "OFF", inline = true },
            { name = "💬 Status", value = "```" .. reason .. "```", inline = false }
        } or nil
    }

    local payload = HttpService:JSONEncode({
        content = (not isUpdateLog) and "<@" .. mySettings.UserID .. ">" or nil,
        embeds = {embed}
    })

    local req = (request or http_request or syn.request or (http and http.request))
    if req then
        task.spawn(function()
            local s, res = pcall(function() return req({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload}) end)
            if res and res.StatusCode == 429 then
                isBlocked = true
                blockExpires = tick() + (tonumber(res.Headers["retry-after"]) or 60)
            end
        end)
    end
end

-- 3. UI CONSTRUCTION (BEAUTIFIED)
local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
ScreenGui.Name = "AegisUI"

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 350, 0, 220)
Main.Position = UDim2.new(0.5, -175, 0.5, -110)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 0
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)
local Stroke = Instance.new("UIStroke", Main)
Stroke.Color = Color3.fromRGB(0, 170, 255)
Stroke.Thickness = 1.5

-- Sidebar
local Side = Instance.new("Frame", Main)
Side.Size = UDim2.new(0, 80, 1, 0)
Side.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
Instance.new("UICorner", Side).CornerRadius = UDim.new(0, 8)

local function createTabBtn(text, pos)
    local btn = Instance.new("TextButton", Side)
    btn.Size = UDim2.new(1, -10, 0, 30)
    btn.Position = UDim2.new(0, 5, 0, pos)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    Instance.new("UICorner", btn)
    return btn
end

local t1 = createTabBtn("DASH", 10)
local t2 = createTabBtn("SHIELD", 45)
local t3 = createTabBtn("CONFIG", 80)

-- Pages
local Pages = Instance.new("Frame", Main)
Pages.Position = UDim2.new(0, 90, 0, 10)
Pages.Size = UDim2.new(1, -100, 1, -20)
Pages.BackgroundTransparency = 1

local function createPage()
    local p = Instance.new("Frame", Pages)
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.Visible = false
    return p
end

local pDash = createPage(); pDash.Visible = true
local pShield = createPage()
local pConfig = createPage()

-- DASHBOARD ELEMENTS
local TimerLbl = Instance.new("TextLabel", pDash)
TimerLbl.Size = UDim2.new(1, 0, 0, 50)
TimerLbl.Text = "00:00"
TimerLbl.Font = Enum.Font.GothamBold
TimerLbl.TextSize = 40
TimerLbl.TextColor3 = Color3.fromRGB(0, 170, 255)
TimerLbl.BackgroundTransparency = 1

local StatusLbl = Instance.new("TextLabel", pDash)
StatusLbl.Position = UDim2.new(0, 0, 0.6, 0)
StatusLbl.Size = UDim2.new(1, 0, 0, 20)
StatusLbl.Text = "SYSTEM: READY"
StatusLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.BackgroundTransparency = 1

-- SHIELD ELEMENTS
local function createToggle(parent, text, pos, settingKey)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, 0, 0, 35)
    btn.Position = UDim2.new(0, 0, 0, pos)
    btn.BackgroundColor3 = mySettings[settingKey] and Color3.fromRGB(0, 100, 50) or Color3.fromRGB(40, 40, 45)
    btn.Text = text .. ": " .. (mySettings[settingKey] and "ON" or "OFF")
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", btn)
    
    btn.MouseButton1Click:Connect(function()
        mySettings[settingKey] = not mySettings[settingKey]
        btn.Text = text .. ": " .. (mySettings[settingKey] and "ON" or "OFF")
        btn.BackgroundColor3 = mySettings[settingKey] and Color3.fromRGB(0, 100, 50) or Color3.fromRGB(40, 40, 45)
        if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
    end)
end

createToggle(pShield, "ANTI-AFK", 10, "AntiAfk")
createToggle(pShield, "AUTO-REJOIN", 50, "AutoRejoin")

-- CONFIG ELEMENTS
local function createInput(parent, placeholder, text, pos, key)
    local box = Instance.new("TextBox", parent)
    box.Size = UDim2.new(1, 0, 0, 30)
    box.Position = UDim2.new(0, 0, 0, pos)
    box.PlaceholderText = placeholder
    box.Text = tostring(text)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    box.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", box)
    box.FocusLost:Connect(function()
        mySettings[key] = box.Text
        if key == "Timer" or key == "Interval" then mySettings[key] = tonumber(box.Text) or text end
        if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(mySettings)) end
    end)
end

createInput(pConfig, "Webhook URL", mySettings.Webhook, 0, "Webhook")
createInput(pConfig, "Discord User ID", mySettings.UserID, 40, "UserID")
createInput(pConfig, "AFK Timer (Sec)", mySettings.Interval, 80, "Interval")

-- TAB LOGIC
t1.MouseButton1Click:Connect(function() pDash.Visible = true; pShield.Visible = false; pConfig.Visible = false end)
t2.MouseButton1Click:Connect(function() pDash.Visible = false; pShield.Visible = true; pConfig.Visible = false end)
t3.MouseButton1Click:Connect(function() pDash.Visible = false; pShield.Visible = false; pConfig.Visible = true end)

-- 4. CORE LOGIC (FUSED)

-- Anti-AFK Internal
player.Idled:Connect(function()
    if mySettings.AntiAfk then
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(0.1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

-- Rejoin Logic
GuiService.ErrorMessageChanged:Connect(function()
    if mySettings.AutoRejoin then
        task.wait(5)
        TeleportService:Teleport(game.PlaceId, player)
    end
end)

-- Master Loop
task.spawn(function()
    sendAegisWebhook("🛡️ Aegis Initialized", "System Online & Protected.", 3066993)
    
    while _G.AegisLoaded and _G.CurrentSession == SESSION_ID do
        local timeLeft = mySettings.Timer
        
        while timeLeft > 0 and _G.AegisLoaded do
            -- Update UI
            TimerLbl.Text = string.format("%02d:%02d", math.floor(timeLeft/60), timeLeft%60)
            
            -- Anti-AFK Movement Logic
            if mySettings.AntiAfk and (tick() - lastAfkAction) >= mySettings.Interval then
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:Move(Vector3.new(0,0,1))
                    task.wait(0.5)
                    hum:Move(Vector3.new(0,0,0))
                end
                lastAfkAction = tick()
            end
            
            task.wait(1)
            timeLeft = timeLeft - 1
        end
        
        if _G.AegisLoaded then
            sendAegisWebhook("🔄 Heartbeat", "Status: Stable.", 1752220)
        end
    end
end)

-- Dragging logic
local dragStart, startPos
Main.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragStart = i.Position startPos = Main.Position end end)
UserInputService.InputChanged:Connect(function(i) if dragStart and i.UserInputType == Enum.UserInputType.MouseMovement then
    local delta = i.Position - dragStart
    Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragStart = nil end end)

print("Aegis Unified System Loaded.")
