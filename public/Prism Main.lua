if not getgenv().PrismLoaded then
    return
end

getgenv().PrismMain = {
    Svc = {
        Players = game:GetService("Players"),
        TweenService = game:GetService("TweenService"),
        RunService = game:GetService("RunService"),
        CoreGui = game:GetService("CoreGui"),
    },
    UI = {},
}

local PM = getgenv().PrismMain
local LP = PM.Svc.Players.LocalPlayer


local HttpService = game:GetService("HttpService")

-- Early settings loading (before UI creation)
local SETTINGS_FILE = "prism/prism_settings.json"
if readfile then
    pcall(function()
        local data = readfile(SETTINGS_FILE)
        if data then
            local settings = game:GetService("HttpService"):JSONDecode(data)
            PM.autoExecutePrism = settings.autoExecutePrism or false
            PM.autoExecuteCommands = settings.autoExecuteCommands ~= false
            PM.terminalKeybind = settings.terminalKeybind or "F6"
        end
    end)
end

PM.mk = function(class, parent, props)
    local i = Instance.new(class)
    i.Parent = parent
    for k, v in pairs(props or {}) do i[k] = v end
    return i
end

PM.corner = function(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

PM.stroke = function(p, c, t, trans)
    local s = Instance.new("UIStroke")
    s.Color = c or Color3.fromRGB(40, 40, 40)
    s.Thickness = t or 1
    s.Transparency = trans or 0
    s.Parent = p
    return s
end

PM.tween = function(obj, time, props, style)
    return PM.Svc.TweenService:Create(obj, TweenInfo.new(time or 0.3, style or Enum.EasingStyle.Quad), props):Play()
end

PM.C = {
    bg = Color3.fromRGB(15, 15, 15),
    card = Color3.fromRGB(28, 28, 28),
    accent = Color3.fromRGB(180, 180, 180),
    text = Color3.fromRGB(230, 230, 230),
    textDim = Color3.fromRGB(90, 90, 90),
    border = Color3.fromRGB(45, 45, 45),
    green = Color3.fromRGB(70, 170, 70),
    red = Color3.fromRGB(170, 70, 70),
    sep = Color3.fromRGB(60, 60, 70),
}
local C = PM.C

-- Prism Nametag System Integration
local API_BASE_URL = "https://prismscript.vercel.app"
local API_ENDPOINT = API_BASE_URL .. "/api/nametags"

-- SPECIAL table: custom backgrounds per userId
local SPECIAL_CUSTOM_BGS = {
    -- Add userId -> image URL mappings here
    -- Example: [12345678] = "https://prismscript.vercel.app/images/coolbg.png",
}

local nametagEnabled = true
local nametagGui = nil
local nametagConnection = nil
local otherNametags = {}
local autoSyncEnabled = true
local autoSyncInterval = 2

local function clearAllNametags()
    local player = PM.Svc.Players.LocalPlayer
    local playerGui = player:FindFirstChild("PlayerGui")
    
    -- Clear own nametag from PlayerGui
    if playerGui then
        for _, child in ipairs(playerGui:GetChildren()) do
            if child.Name == "PrismNametag" then
                pcall(function() child:Destroy() end)
            end
        end
    end
    
    -- Clear other players' nametags from PlayerGui
    if playerGui then
        for _, child in ipairs(playerGui:GetChildren()) do
            if child.Name:sub(1, 13) == "PrismNametag_" then
                pcall(function() child:Destroy() end)
            end
        end
    end
    
    -- Also clear from heads (cleanup from old version)
    if player.Character then
        local head = player.Character:FindFirstChild("Head")
        if head then
            for _, child in ipairs(head:GetChildren()) do
                if child.Name == "PrismNametag" then
                    pcall(function() child:Destroy() end)
                end
            end
        end
    end
    
    for _, plr in ipairs(PM.Svc.Players:GetPlayers()) do
        if plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                for _, child in ipairs(head:GetChildren()) do
                    if child.Name:sub(1, 13) == "PrismNametag_" then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
    end
    
    for userId, tagData in pairs(otherNametags) do
        if tagData.connection then
            tagData.connection:Disconnect()
        end
    end
    otherNametags = {}
    
    if nametagConnection then
        nametagConnection:Disconnect()
        nametagConnection = nil
    end
    nametagGui = nil
end

local function createNametag()
    local player = PM.Svc.Players.LocalPlayer
    if not player.Character then return end
    
    local head = player.Character:FindFirstChild("Head")
    if not head then return end
    
    if nametagGui then
        pcall(function() nametagGui:Destroy() end)
        nametagGui = nil
    end
    
    for _, child in ipairs(head:GetChildren()) do
        if child.Name == "PrismNametag" then
            pcall(function() child:Destroy() end)
        end
    end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PrismNametag"
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 9999
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.Parent = PM.Svc.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Background frame for border (fixes corner gaps) - added first to be behind
    local bgFrame = Instance.new("Frame")
    bgFrame.Name = "BgFrame"
    bgFrame.Size = UDim2.new(1, 4, 1, 4)
    bgFrame.Position = UDim2.new(0, -2, 0, -2)
    bgFrame.BackgroundColor3 = C.sep
    bgFrame.BackgroundTransparency = 0
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = billboard
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 10)
    bgCorner.Parent = bgFrame
    
    local bgGradient = Instance.new("UIGradient")
    bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.25, C.sep),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 20)),
        ColorSequenceKeypoint.new(0.75, C.sep),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    bgGradient.Parent = bgFrame
    
    local frame = Instance.new("Frame")
    frame.Name = "TagFrame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = C.card
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = billboard
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local displayNameLabel = Instance.new("TextLabel")
    displayNameLabel.Name = "DisplayName"
    displayNameLabel.Size = UDim2.new(1, -10, 0, 20)
    displayNameLabel.Position = UDim2.new(0, 5, 0, 5)
    displayNameLabel.BackgroundTransparency = 1
    displayNameLabel.Text = player.DisplayName
    displayNameLabel.TextColor3 = C.text
    displayNameLabel.TextSize = 14
    displayNameLabel.Font = Enum.Font.GothamBold
    displayNameLabel.TextXAlignment = Enum.TextXAlignment.Center
    displayNameLabel.Parent = frame
    
    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Name = "Username"
    usernameLabel.Size = UDim2.new(1, -10, 0, 16)
    usernameLabel.Position = UDim2.new(0, 5, 0, 25)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = "@ " .. player.Name
    usernameLabel.TextColor3 = C.textDim
    usernameLabel.TextSize = 11
    usernameLabel.Font = Enum.Font.Gotham
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Center
    usernameLabel.Parent = frame
    
    local smallLabel = Instance.new("TextLabel")
    smallLabel.Name = "SmallLabel"
    smallLabel.Size = UDim2.new(1, 0, 1, 0)
    smallLabel.BackgroundTransparency = 1
    smallLabel.Text = "P"
    smallLabel.TextColor3 = C.text
    smallLabel.TextSize = 20
    smallLabel.Font = Enum.Font.GothamBold
    smallLabel.TextXAlignment = Enum.TextXAlignment.Center
    smallLabel.TextYAlignment = Enum.TextYAlignment.Center
    smallLabel.Visible = false
    smallLabel.Parent = frame
    
    nametagConnection = PM.Svc.RunService.Heartbeat:Connect(function(dt)
        if not billboard or not billboard.Parent then return end
        if bgGradient and bgGradient.Parent then
            bgGradient.Rotation = (bgGradient.Rotation + 120 * dt) % 360
        end
        
        -- Track head
        local currentHead = player.Character and player.Character:FindFirstChild("Head")
        if currentHead then
            billboard.Adornee = currentHead
        end
    end)
    
    nametagGui = billboard
end

local function removeNametag()
    if nametagConnection then
        nametagConnection:Disconnect()
        nametagConnection = nil
    end
    if nametagGui then
        pcall(function() nametagGui:Destroy() end)
        nametagGui = nil
    end
end

local function toggleNametag()
    nametagEnabled = not nametagEnabled
    if nametagEnabled then
        if nametagGui then
            nametagGui.Enabled = true
        else
            createNametag()
        end
        for userId, tagData in pairs(otherNametags) do
            if tagData.gui then
                tagData.gui.Enabled = true
            end
        end
    else
        if nametagGui then
            nametagGui.Enabled = false
        end
        for userId, tagData in pairs(otherNametags) do
            if tagData.gui then
                tagData.gui.Enabled = false
            end
        end
    end
    return nametagEnabled
end

local function createOtherNametag(plrObj)
    if not plrObj.Character then return end
    
    local head = plrObj.Character:FindFirstChild("Head")
    if not head then return end
    
    -- Check SPECIAL table for custom background
    local customBg = SPECIAL_CUSTOM_BGS[plrObj.UserId]
    
    if otherNametags[plrObj.UserId] then
        if otherNametags[plrObj.UserId].connection then
            otherNametags[plrObj.UserId].connection:Disconnect()
        end
        pcall(function() otherNametags[plrObj.UserId].gui:Destroy() end)
        otherNametags[plrObj.UserId] = nil
    end
    
    for _, child in ipairs(head:GetChildren()) do
        if child.Name == "PrismNametag_" .. plrObj.UserId then
            pcall(function() child:Destroy() end)
        end
    end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PrismNametag_" .. plrObj.UserId
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 9999
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.Active = true
    billboard.Parent = PM.Svc.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local bgFrame = Instance.new("Frame")
    bgFrame.Name = "BgFrame"
    bgFrame.Size = UDim2.new(1, 4, 1, 4)
    bgFrame.Position = UDim2.new(0, -2, 0, -2)
    bgFrame.BackgroundColor3 = C.sep
    bgFrame.BackgroundTransparency = 0
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = billboard
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 10)
    bgCorner.Parent = bgFrame
    
    local bgGradient = Instance.new("UIGradient")
    bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.25, C.sep),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 20)),
        ColorSequenceKeypoint.new(0.75, C.sep),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    bgGradient.Parent = bgFrame
    
    -- Custom background image if provided
    if customBg then
        local bgImage = Instance.new("ImageLabel")
        bgImage.Name = "CustomBg"
        bgImage.Size = UDim2.new(1, 0, 1, 0)
        bgImage.Position = UDim2.new(0, 0, 0, 0)
        bgImage.BackgroundTransparency = 1
        bgImage.Image = customBg
        bgImage.ScaleType = Enum.ScaleType.Stretch
        bgImage.ZIndex = 0
        bgImage.Parent = bgFrame
        
        -- Hide gradient when using custom image
        bgGradient.Enabled = false
    end
    
    local frame = Instance.new("Frame")
    frame.Name = "TagFrame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = C.card
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = billboard
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local displayNameLabel = Instance.new("TextLabel")
    displayNameLabel.Name = "DisplayName"
    displayNameLabel.Size = UDim2.new(1, -10, 0, 20)
    displayNameLabel.Position = UDim2.new(0, 5, 0, 5)
    displayNameLabel.BackgroundTransparency = 1
    displayNameLabel.Text = plrObj.DisplayName
    displayNameLabel.TextColor3 = C.text
    displayNameLabel.TextSize = 14
    displayNameLabel.Font = Enum.Font.GothamBold
    displayNameLabel.TextXAlignment = Enum.TextXAlignment.Center
    displayNameLabel.Parent = frame
    
    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Name = "Username"
    usernameLabel.Size = UDim2.new(1, -10, 0, 16)
    usernameLabel.Position = UDim2.new(0, 5, 0, 25)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = "@ " .. plrObj.Name
    usernameLabel.TextColor3 = C.textDim
    usernameLabel.TextSize = 11
    usernameLabel.Font = Enum.Font.Gotham
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Center
    usernameLabel.Parent = frame
    
    local smallLabel = Instance.new("TextLabel")
    smallLabel.Name = "SmallLabel"
    smallLabel.Size = UDim2.new(1, 0, 1, 0)
    smallLabel.BackgroundTransparency = 1
    smallLabel.Text = "P"
    smallLabel.TextColor3 = C.text
    smallLabel.TextSize = 20
    smallLabel.Font = Enum.Font.GothamBold
    smallLabel.TextXAlignment = Enum.TextXAlignment.Center
    smallLabel.TextYAlignment = Enum.TextYAlignment.Center
    smallLabel.Visible = false
    smallLabel.Parent = frame
    
    -- Click to teleport behind target
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local myChar = PM.Svc.Players.LocalPlayer.Character
            local targetChar = plrObj.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") and targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
                local myHRP = myChar.HumanoidRootPart
                local targetHRP = targetChar.HumanoidRootPart
                local behind = targetHRP.CFrame * CFrame.new(0, 0, 3)
                myHRP.CFrame = CFrame.new(behind.Position, behind.Position + targetHRP.CFrame.LookVector)
            end
        end
    end)
    
    local connection = PM.Svc.RunService.Heartbeat:Connect(function(dt)
        if not billboard or not billboard.Parent then return end
        if bgGradient and bgGradient.Parent then
            bgGradient.Rotation = (bgGradient.Rotation + 120 * dt) % 360
        end
        
        -- Track head
        local targetHead = plrObj.Character and plrObj.Character:FindFirstChild("Head")
        if targetHead then
            billboard.Adornee = targetHead
        end
        
        local myChar = PM.Svc.Players.LocalPlayer.Character
        local targetChar = plrObj.Character
        if myChar and myChar:FindFirstChild("HumanoidRootPart") and targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
            local myHRP = myChar.HumanoidRootPart
            local targetHRP = targetChar.HumanoidRootPart
            local dist = (myHRP.Position - targetHRP.Position).Magnitude
            local isFar = dist > 50
            
            displayNameLabel.Visible = not isFar
            usernameLabel.Visible = not isFar
            smallLabel.Visible = isFar
            
            if isFar then
                PM.tween(billboard, 0.1, {Size = UDim2.new(0, 40, 0, 40)})
            else
                PM.tween(billboard, 0.1, {Size = UDim2.new(0, 150, 0, 50)})
            end
        end
    end)
    
    otherNametags[plrObj.UserId] = {
        gui = billboard,
        connection = connection
    }
end

local function removeOtherNametag(userId)
    if otherNametags[userId] then
        if otherNametags[userId].connection then
            otherNametags[userId].connection:Disconnect()
        end
        pcall(function() otherNametags[userId].gui:Destroy() end)
        otherNametags[userId] = nil
    end
end

local function readFromAPI()
    local HttpService = game:GetService("HttpService")
    local requestFunction = request or (HttpService and HttpService.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        return nil
    end
    
    local requestTable = {
        Url = API_ENDPOINT,
        Method = "GET"
    }
    
    local success, result = pcall(function()
        return requestFunction(requestTable)
    end)
    
    if not success then
        return nil
    end
    
    local responseBody = result.Body or result.body or result
    
    if responseBody then
        local responseSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        
        if responseSuccess and responseData.success then
            return responseData.data
        end
    end
    
    return nil
end

local function updateOtherNametags()
    local data = readFromAPI()
    if not data or not data.users then return end
    
    local myJobId = game.JobId
    local myUserId = PM.Svc.Players.LocalPlayer.UserId
    
    local prismUsers = {}
    for _, user in ipairs(data.users) do
        if user.jobId == myJobId and tostring(user.userId) ~= tostring(myUserId) then
            prismUsers[user.userId] = user
        end
    end
    
    for userId, userData in pairs(prismUsers) do
        local plrObj = PM.Svc.Players:GetPlayerByUserId(tonumber(userId))
        if plrObj and not otherNametags[tonumber(userId)] then
            if plrObj.Character then
                createOtherNametag(plrObj)
            else
                plrObj.CharacterAdded:Connect(function(char)
                    task.wait(0.5)
                    if prismUsers[userId] and not otherNametags[tonumber(userId)] then
                        createOtherNametag(plrObj)
                    end
                end)
            end
        end
    end
    
    for userId, tagData in pairs(otherNametags) do
        if not prismUsers[tostring(userId)] then
            removeOtherNametag(userId)
        end
    end
end

local function getUserInfo()
    local player = PM.Svc.Players.LocalPlayer
    if not player then
        return nil
    end
    
    local jobId = game.JobId
    local userId = player.UserId
    local username = player.Name
    local displayName = player.DisplayName or username
    
    return {
        username = username,
        displayName = displayName,
        userId = tostring(userId),
        jobId = jobId ~= "" and jobId or "unknown"
    }
end

local function sendToAPI(userInfo)
    local HttpService = game:GetService("HttpService")
    local requestFunction = request or (HttpService and HttpService.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        return false, "No HTTP function available"
    end
    
    local requestBody = HttpService:JSONEncode(userInfo)
    local requestTable = {
        Url = API_ENDPOINT,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = requestBody
    }
    
    local success, result = pcall(function()
        return requestFunction(requestTable)
    end)
    
    if not success then
        return false, result
    end
    
    local responseBody = result.Body or result.body or result
    
    if responseBody then
        local responseSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        
        if responseSuccess then
            if responseData.success then
                return true, responseData
            else
                return false, responseData.error
            end
        else
            return false, "Parse error"
        end
    else
        return false, "No response"
    end
end

local function deleteFromAPI(userId)
    local HttpService = game:GetService("HttpService")
    local requestFunction = request or (HttpService and HttpService.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        return false, "No HTTP function available"
    end
    
    local requestBody = HttpService:JSONEncode({userId = tostring(userId)})
    local requestTable = {
        Url = API_ENDPOINT,
        Method = "DELETE",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = requestBody
    }
    
    local success, result = pcall(function()
        return requestFunction(requestTable)
    end)
    
    if not success then
        return false, result
    end
    
    local responseBody = result.Body or result.body or result
    
    if responseBody then
        local responseSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        
        if responseSuccess then
            if responseData.success then
                return true, responseData
            else
                return false, responseData.error
            end
        else
            return false, "Parse error"
        end
    else
        return false, "No response"
    end
end

local function sendNametagData()
    local userInfo = getUserInfo()
    if not userInfo then
        return
    end
    
    local success, result = sendToAPI(userInfo)
    
    if success then
        updateOtherNametags()
    end
end

local function startAutoSync()
    while autoSyncEnabled and PM.Svc.RunService.Heartbeat:Wait() do
        task.wait(autoSyncInterval)
        if autoSyncEnabled then
            sendNametagData()
        end
    end
end

PM.PrismNametags = {
    toggle = toggleNametag,
    create = createNametag,
    remove = removeNametag,
    isEnabled = function()
        return nametagEnabled
    end,
    cleanup = function()
        -- Stop auto-sync
        autoSyncEnabled = false
        
        -- Clear all nametags
        clearAllNametags()
        
        -- Disconnect heartbeat connections
        if nametagConnection then
            nametagConnection:Disconnect()
            nametagConnection = nil
        end
        
        for userId, tagData in pairs(otherNametags) do
            if tagData.connection then
                tagData.connection:Disconnect()
            end
        end
        otherNametags = {}
        
        -- Remove self from API
        local player = PM.Svc.Players.LocalPlayer
        if player then
            task.spawn(function()
                deleteFromAPI(player.UserId)
            end)
        end
        
        -- Reset flags
        nametagGui = nil
        nametagEnabled = false
    end
}

PM.createMainGUI = function()
    if PM.Svc.CoreGui:FindFirstChild("PrismMainGui") then return end
    
    PM.UI.Gui = PM.mk("ScreenGui", PM.Svc.CoreGui, {
        Name = "PrismMainGui",
        DisplayOrder = 1000,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    
    PM.UI.Main = PM.mk("Frame", PM.UI.Gui, {
        Name = "MainFrame",
        Size = UDim2.new(0, 460, 0, 56),
        Position = UDim2.new(0.5, -230, 0, -30),
        BackgroundColor3 = C.bg,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    PM.corner(PM.UI.Main, 14)
    PM.stroke(PM.UI.Main, C.border, 1, 0.4)
    
    PM.UI.StatsFrame = PM.mk("Frame", PM.UI.Main, {
        Name = "StatsFrame",
        Size = UDim2.new(0, 75, 0, 44),
        Position = UDim2.new(0, 14, 0.5, -22),
        BackgroundTransparency = 1,
        ZIndex = 10,
    })
    
    PM.UI.FPSLabelText = PM.mk("TextLabel", PM.UI.StatsFrame, {
        Name = "FPSLabelText",
        Size = UDim2.new(0, 35, 0, 14),
        Position = UDim2.new(0, 0, 0, 2),
        BackgroundTransparency = 1,
        Text = "FPS",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    PM.UI.FPSLabel = PM.mk("TextLabel", PM.UI.StatsFrame, {
        Name = "FPSLabel",
        Size = UDim2.new(0, 40, 0, 14),
        Position = UDim2.new(0, 35, 0, 2),
        BackgroundTransparency = 1,
        Text = " ",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    PM.UI.PingLabelText = PM.mk("TextLabel", PM.UI.StatsFrame, {
        Name = "PingLabelText",
        Size = UDim2.new(0, 35, 0, 14),
        Position = UDim2.new(0, 0, 0, 23),
        BackgroundTransparency = 1,
        Text = "PING",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    PM.UI.PingLabel = PM.mk("TextLabel", PM.UI.StatsFrame, {
        Name = "PingLabel",
        Size = UDim2.new(0, 40, 0, 14),
        Position = UDim2.new(0, 35, 0, 23),
        BackgroundTransparency = 1,
        Text = " ",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    PM.UI.ButtonsFrame = PM.mk("Frame", PM.UI.Main, {
        Name = "ButtonsFrame",
        Size = UDim2.new(0, 220, 0, 36),
        Position = UDim2.new(0.5, -110, 0.5, -18),
        BackgroundTransparency = 1,
        ZIndex = 10,
    })
    
    PM.UI.ButtonsList = PM.mk("UIListLayout", PM.UI.ButtonsFrame, {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    
    local buttonData = {
        {name = "Commands", layout = 1, image = "rbxassetid://132440478962916"},
        {name = "Terminal", layout = 3, image = "rbxassetid://73577105416536"},
        {name = "NameTags", layout = 5, image = "rbxassetid://99892550804409"},
        {name = "Join", layout = 7, image = "rbxassetid://84437305519060"},
        {name = "Servers", layout = 9, image = "rbxassetid://138470287250966"},
        {name = "Settings", layout = 11, image = "rbxassetid://101119408272746"},
    }
    
    PM.UI.Buttons = {}
    for i, btn in ipairs(buttonData) do
        local button = PM.mk("ImageButton", PM.UI.ButtonsFrame, {
            Name = "Btn_" .. btn.name,
            Size = UDim2.new(0, 32, 0, 28),
            BackgroundColor3 = Color3.fromRGB(20, 20, 26),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            LayoutOrder = btn.layout,
            ZIndex = 10,
        })
        PM.corner(button, 3)
        
        local icon = PM.mk("ImageLabel", button, {
            Name = "Icon",
            Size = UDim2.new(0, 18, 0, 18),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = btn.image,
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            ZIndex = 2,
        })
        
        PM.clickSoundEnabled = true
        PM.clickVolume = 0.75
        PM.clickSoundID = "94859356677805"
        PM.hoverSoundEnabled = true
        PM.hoverVolume = 0.75
        PM.hoverSoundID = "107511012621133"

        if not PM.UI.HoverSound then
            PM.UI.HoverSound = PM.mk("Sound", PM.UI.Gui, {
                SoundId = "rbxassetid://" .. PM.hoverSoundID,
                Volume = PM.hoverVolume,
            })
        end

        if not PM.UI.ClickSound then
            PM.UI.ClickSound = PM.mk("Sound", PM.UI.Gui, {
                SoundId = "rbxassetid://" .. PM.clickSoundID,
                Volume = PM.clickVolume,
            })
        end

        PM.playClickSound = function()
            if PM.clickSoundEnabled and PM.UI.ClickSound then
                pcall(function() PM.UI.ClickSound:Play() end)
            end
        end

        PM.playHoverSound = function()
            if PM.hoverSoundEnabled and PM.UI.HoverSound then
                pcall(function() PM.UI.HoverSound:Play() end)
            end
        end
        
        local isHovering = false
        button.MouseEnter:Connect(function()
            isHovering = true
            PM.isHoveringAnyButton = true
            PM.tween(icon, 0.15, {Size = UDim2.new(0, 22, 0, 22), ImageColor3 = Color3.fromRGB(180, 180, 190)})
            PM.playHoverSound()
        end)
        button.MouseLeave:Connect(function()
            isHovering = false
            PM.isHoveringAnyButton = false
            PM.tween(icon, 0.15, {Size = UDim2.new(0, 18, 0, 18), ImageColor3 = Color3.fromRGB(255, 255, 255)})
        end)
        button.MouseButton1Down:Connect(function()
            PM.tween(icon, 0.08, {Size = UDim2.new(0, 16, 0, 16)})
        end)
        button.MouseButton1Up:Connect(function()
            local targetSize = isHovering and UDim2.new(0, 22, 0, 22) or UDim2.new(0, 18, 0, 18)
            PM.tween(icon, 0.08, {Size = targetSize})
        end)
        if btn.name == "Terminal" then
            PM.isTerminalOpen = false
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
                if PM.isTerminalOpen then
                    PM.isTerminalOpen = false
                    PM.hideTerminalPanel()
                else
                    PM.isTerminalOpen = true
                    if PM.isCommandsOpen then
                        PM.isCommandsOpen = false
                        PM.hideCommandsPanel()
                    end
                    if PM.isServersOpen then
                        PM.isServersOpen = false
                        PM.hideServersPanel()
                    end
                    if PM.UI.NameTagsPanel and PM.UI.NameTagsPanel.Visible then
                        PM.UI.NameTagsPanel.Visible = false
                    end
                    if PM.isJoinOpen then
                        PM.isJoinOpen = false
                        PM.hideJoinPanel()
                    end
                    if PM.isSettingsOpen then
                        PM.isSettingsOpen = false
                        PM.hideSettingsPanel()
                    end
                    PM.toggleTerminalPanel()
                end
            end)
        elseif btn.name == "Commands" then
            PM.isCommandsOpen = false
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
                if PM.isCommandsOpen then
                    PM.isCommandsOpen = false
                    PM.closeCommandsPanel()
                else
                    PM.isCommandsOpen = true
                    if PM.isTerminalOpen then
                        PM.isTerminalOpen = false
                        PM.hideTerminalPanel()
                    end
                    if PM.isServersOpen then
                        PM.isServersOpen = false
                        PM.hideServersPanel()
                    end
                    if PM.UI.NameTagsPanel and PM.UI.NameTagsPanel.Visible then
                        PM.UI.NameTagsPanel.Visible = false
                    end
                    if PM.isJoinOpen then
                        PM.isJoinOpen = false
                        PM.hideJoinPanel()
                    end
                    if PM.isSettingsOpen then
                        PM.isSettingsOpen = false
                        PM.hideSettingsPanel()
                    end
                    PM.openCommandsPanel()
                end
            end)
        elseif btn.name == "NameTags" then
            PM.isNameTagsEnabled = false
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
                PM.isNameTagsEnabled = PM.PrismNametags.toggle()
                if PM.isTerminalOpen then
                    PM.isTerminalOpen = false
                    PM.hideTerminalPanel()
                end
                if PM.isCommandsOpen then
                    PM.isCommandsOpen = false
                    PM.hideCommandsPanel()
                end
                if PM.isServersOpen then
                    PM.isServersOpen = false
                    PM.hideServersPanel()
                end
                if PM.isJoinOpen then
                    PM.isJoinOpen = false
                    PM.hideJoinPanel()
                end
                if PM.isSettingsOpen then
                    PM.isSettingsOpen = false
                    PM.hideSettingsPanel()
                end
                PM.toggleNameTagsPanel()
            end)
        elseif btn.name == "Servers" then
            PM.isServersOpen = false
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
                if PM.isServersOpen then
                    PM.isServersOpen = false
                    PM.closeServersPanel()
                else
                    PM.isServersOpen = true
                    if PM.isTerminalOpen then
                        PM.isTerminalOpen = false
                        PM.hideTerminalPanel()
                    end
                    if PM.isCommandsOpen then
                        PM.isCommandsOpen = false
                        PM.hideCommandsPanel()
                    end
                    if PM.UI.NameTagsPanel and PM.UI.NameTagsPanel.Visible then
                        PM.UI.NameTagsPanel.Visible = false
                    end
                    if PM.isJoinOpen then
                        PM.isJoinOpen = false
                        PM.hideJoinPanel()
                    end
                    if PM.isSettingsOpen then
                        PM.isSettingsOpen = false
                        PM.hideSettingsPanel()
                    end
                    PM.openServersPanel()
                end
            end)
        elseif btn.name == "Join" then
            PM.isJoinOpen = false
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
                if PM.isJoinOpen then
                    PM.isJoinOpen = false
                    PM.closeJoinPanel()
                else
                    PM.isJoinOpen = true
                    if PM.isTerminalOpen then
                        PM.isTerminalOpen = false
                        PM.hideTerminalPanel()
                    end
                    if PM.isCommandsOpen then
                        PM.isCommandsOpen = false
                        PM.hideCommandsPanel()
                    end
                    if PM.isServersOpen then
                        PM.isServersOpen = false
                        PM.hideServersPanel()
                    end
                    if PM.UI.NameTagsPanel and PM.UI.NameTagsPanel.Visible then
                        PM.UI.NameTagsPanel.Visible = false
                    end
                    if PM.isSettingsOpen then
                        PM.isSettingsOpen = false
                        PM.hideSettingsPanel()
                    end
                    PM.openJoinPanel()
                end
            end)
        elseif btn.name == "Settings" then
            PM.isSettingsOpen = false
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
                if PM.isSettingsOpen then
                    PM.isSettingsOpen = false
                    PM.closeSettingsPanel()
                else
                    PM.isSettingsOpen = true
                    if PM.isTerminalOpen then
                        PM.isTerminalOpen = false
                        PM.hideTerminalPanel()
                    end
                    if PM.isCommandsOpen then
                        PM.isCommandsOpen = false
                        PM.hideCommandsPanel()
                    end
                    if PM.isServersOpen then
                        PM.isServersOpen = false
                        PM.hideServersPanel()
                    end
                    if PM.isJoinOpen then
                        PM.isJoinOpen = false
                        PM.hideJoinPanel()
                    end
                    if PM.UI.NameTagsPanel and PM.UI.NameTagsPanel.Visible then
                        PM.UI.NameTagsPanel.Visible = false
                    end
                    PM.openSettingsPanel()
                end
            end)
        else
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
            end)
        end
        
        PM.UI.Buttons[btn.name] = button
    end
    
    PM.createTerminalPanel = function()
        if PM.UI.TerminalPanel then return end
        
        PM.UI.TerminalPanel = PM.mk("Frame", PM.UI.Gui, {
            Name = "TerminalPanel",
            Size = UDim2.new(0, 340, 0, 38),
            Position = UDim2.new(0.5, 0, 0, 35),
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 0.18,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
            ClipsDescendants = true,
        })
        PM.corner(PM.UI.TerminalPanel, 10)
        PM.stroke(PM.UI.TerminalPanel, C.border, 1, 0.5)
        
        -- Flag to prevent FocusLost from closing immediately after panel opens
        PM.panelJustOpened = false
        PM.keybindJustChanged = false
        
        PM.mk("TextLabel", PM.UI.TerminalPanel, {
            Size = UDim2.new(0, 24, 0, 38),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = ">",
            TextColor3 = C.textDim,
            TextSize = 18,
            Font = Enum.Font.Gotham,
            ZIndex = 101,
        })
        
        PM.UI.TerminalAutofill = PM.mk("TextLabel", PM.UI.TerminalPanel, {
            Size = UDim2.new(1, -40, 0, 38),
            Position = UDim2.new(0, 32, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = Color3.fromRGB(60, 60, 60), -- Darker than input text
            TextSize = 13,
            Font = Enum.Font.RobotoMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 102,
        })
        
        PM.UI.TerminalInput = PM.mk("TextBox", PM.UI.TerminalPanel, {
            Size = UDim2.new(1, -90, 0, 38),
            Position = UDim2.new(0, 32, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            PlaceholderText = "Enter a command...",
            PlaceholderColor3 = C.textDim,
            TextColor3 = C.textDim,
            TextSize = 13,
            Font = Enum.Font.RobotoMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            TextEditable = true,
            TextStrokeTransparency = 1,
            ZIndex = 105,
        })
        
        -- Keybind button (like Mono's F6 button in terminal)
        local keybindBtn = PM.mk("TextButton", PM.UI.TerminalPanel, {
            Name = "KeybindBtn",
            Size = UDim2.new(0, 46, 0, 22),
            Position = UDim2.new(1, -52, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Text = PM.terminalKeybind or "F6",
            TextColor3 = C.textDim,
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            ZIndex = 106,
        })
        PM.corner(keybindBtn, 4)
        
        -- Hover detection to prevent terminal close when rebinding
        PM.isHoveringKeybindBtn = false
        keybindBtn.MouseEnter:Connect(function()
            PM.isHoveringKeybindBtn = true
        end)
        keybindBtn.MouseLeave:Connect(function()
            PM.isHoveringKeybindBtn = false
        end)
        
        keybindBtn.MouseButton1Click:Connect(function()
            if PM.keybindJustChanged then
                PM.keybindJustChanged = false
                keybindBtn.Text = PM.terminalKeybind or "F6"
                keybindBtn.TextColor3 = C.textDim
            else
                PM.keybindJustChanged = true
                keybindBtn.Text = "..."
                keybindBtn.TextColor3 = C.textDim
            end
        end)
        
        -- Capture keybind from terminal panel
        game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if PM.keybindJustChanged and input.UserInputType == Enum.UserInputType.Keyboard then
                PM.keybindJustChanged = false
                PM.terminalKeybind = input.KeyCode.Name
                keybindBtn.Text = PM.terminalKeybind
                keybindBtn.TextColor3 = C.textDim
                -- Regain focus on input after rebinding
                task.delay(0.05, function()
                    if PM.UI.TerminalInput then
                        PM.UI.TerminalInput:CaptureFocus()
                    end
                end)
                -- Save to settings
                if writefile then
                    pcall(function()
                        local settings = {
                            autoExecutePrism = PM.autoExecutePrism or false,
                            autoExecuteCommands = PM.autoExecuteCommands ~= false,
                            terminalKeybind = PM.terminalKeybind,
                        }
                        writefile("prism/prism_settings.json", game:GetService("HttpService"):JSONEncode(settings))
                    end)
                end
            end
        end)
        
        -- Autofill functionality
        local function updateAutofill()
            local input = PM.UI.TerminalInput.Text:lower()
            if input == "" then
                PM.UI.TerminalAutofill.Text = ""
                return
            end
            
            -- Find first matching command
            for cmdName, cmd in pairs(PM.Commands or {}) do
                if cmdName:sub(1, #input) == input then
                    PM.UI.TerminalAutofill.Text = cmd.name
                    return
                end
                -- Check aliases too
                for _, alias in ipairs(cmd.aliases or {}) do
                    if alias:lower():sub(1, #input) == input then
                        PM.UI.TerminalAutofill.Text = cmd.name
                        return
                    end
                end
            end
            
            PM.UI.TerminalAutofill.Text = ""
        end
        
        PM.UI.TerminalInput:GetPropertyChangedSignal("Text"):Connect(updateAutofill)
        
        -- Handle Enter to execute and close
        PM.UI.TerminalInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local cmd = PM.UI.TerminalInput.Text
                local suggestion = PM.UI.TerminalAutofill.Text
                -- If there's an autofill suggestion, use it (like Mono)
                if suggestion and suggestion ~= "" and suggestion ~= " " then
                    cmd = suggestion
                end
                if cmd and cmd ~= "" then
                    PM.UI.TerminalInput.Text = ""
                    PM.UI.TerminalAutofill.Text = ""
                    if PM.executeCommand then
                        PM.executeCommand(cmd)
                    end
                end
                -- Close after executing command
                PM.isTerminalOpen = false
                PM.closeTerminalPanel()
            else
                -- Close on focus loss (clicking outside) - check blocking flags here
                if PM.panelJustOpened or PM.keybindJustChanged or PM.isHoveringKeybindBtn or PM.isHoveringAnyButton then
                    return
                end
                PM.isTerminalOpen = false
                PM.closeTerminalPanel()
            end
        end)
        
        -- Handle Tab for autofill and Escape to close
        game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if not PM.UI.TerminalPanel or not PM.UI.TerminalPanel.Visible then return end
            
            -- Skip keybind handling if panel just opened (prevents F6 from immediately closing)
            if PM.panelJustOpened then return end
            
            if input.KeyCode == Enum.KeyCode.Tab then
                local suggestion = PM.UI.TerminalAutofill.Text
                if suggestion and suggestion ~= "" then
                    PM.UI.TerminalInput.Text = suggestion
                    PM.UI.TerminalInput.CursorPosition = #suggestion + 1
                    PM.UI.TerminalAutofill.Text = ""
                end
            elseif input.KeyCode == Enum.KeyCode.Escape then
                PM.isTerminalOpen = false
                PM.closeTerminalPanel()
            end
        end)
        
    end
    
    PM.openTerminalPanel = function()
        if not PM.UI.TerminalPanel then
            PM.createTerminalPanel()
        end
        -- Keybind only opens, never closes (like Mono's bar)
        if PM.UI.TerminalPanel.Visible then return end
        
        -- Set flag to prevent immediate close
        PM.panelJustOpened = true
        task.delay(0.1, function()
            PM.panelJustOpened = false
        end)
        
        PM.isTerminalOpen = true
        PM.UI.TerminalPanel.Visible = true
        PM.UI.TerminalPanel.Size = UDim2.new(0, 0, 0, 38)
        PM.tween(PM.UI.TerminalPanel, 0.25, {Size = UDim2.new(0, 340, 0, 38)})
        PM.UI.TerminalInput:CaptureFocus()
    end
    
    -- For button toggle (opens and closes)
    PM.toggleTerminalPanel = function()
        if not PM.UI.TerminalPanel then
            PM.createTerminalPanel()
        end
        if PM.UI.TerminalPanel.Visible then
            PM.isTerminalOpen = false
            PM.closeTerminalPanel()
        else
            -- Set flag to prevent immediate close
            PM.panelJustOpened = true
            task.delay(0.1, function()
                PM.panelJustOpened = false
            end)
            
            PM.isTerminalOpen = true
            PM.UI.TerminalPanel.Visible = true
            PM.UI.TerminalPanel.Size = UDim2.new(0, 0, 0, 38)
            PM.tween(PM.UI.TerminalPanel, 0.25, {Size = UDim2.new(0, 340, 0, 38)})
            PM.UI.TerminalInput:CaptureFocus()
        end
    end
    
    PM.closeTerminalPanel = function()
        if not PM.UI.TerminalPanel or not PM.UI.TerminalPanel.Visible then return end
        
        PM.UI.TerminalInput:ReleaseFocus()
        PM.UI.TerminalInput.Text = ""
        PM.UI.TerminalAutofill.Text = ""
        PM.tween(PM.UI.TerminalPanel, 0.25, {Size = UDim2.new(0, 0, 0, 38)})
        task.delay(0.25, function()
            PM.UI.TerminalPanel.Visible = false
            PM.UI.TerminalPanel.Size = UDim2.new(0, 340, 0, 38)
        end)
    end
    
    PM.hideTerminalPanel = function()
        if not PM.UI.TerminalPanel then return end
        PM.UI.TerminalInput:ReleaseFocus()
        PM.UI.TerminalPanel.Visible = false
        PM.UI.TerminalPanel.Size = UDim2.new(0, 340, 0, 38)
    end

    PM.createCommandsPanel = function()
        if PM.UI.CommandsPanel then return end
        
        PM.UI.CommandsPanel = PM.mk("Frame", PM.UI.Gui, {
            Name = "CommandsPanel",
            Size = UDim2.new(0, 280, 0, 320),
            Position = UDim2.new(0.5, -140, 0, 35),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
            ClipsDescendants = true,
        })
        PM.corner(PM.UI.CommandsPanel, 12)
        PM.stroke(PM.UI.CommandsPanel, C.border, 1, 0.4)
        
        PM.UI.CommandsTitle = PM.mk("TextLabel", PM.UI.CommandsPanel, {
            Size = UDim2.new(1, 0, 0, 36),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "Commands",
            TextColor3 = C.text,
            TextSize = 14,
            Font = Enum.Font.GothamBlack,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 101,
        })
        
        PM.UI.CommandsClose = PM.mk("TextButton", PM.UI.CommandsPanel, {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, -30, 0, 6),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "X",
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            ZIndex = 101,
        })
        PM.corner(PM.UI.CommandsClose, 6)
        
        PM.UI.CommandsClose.MouseEnter:Connect(function()
            PM.UI.CommandsClose.TextColor3 = Color3.fromRGB(255, 80, 80)
        end)
        PM.UI.CommandsClose.MouseLeave:Connect(function()
            PM.UI.CommandsClose.TextColor3 = C.text
        end)
        
        PM.UI.CommandsClose.MouseButton1Click:Connect(function()
            PM.playClickSound()
            PM.isCommandsOpen = false
            PM.UI.CommandsSearch.Text = ""
            PM.closeCommandsPanel()
        end)
        
        PM.UI.CommandsSearch = PM.mk("TextBox", PM.UI.CommandsPanel, {
            Name = "CommandsSearch",
            Size = UDim2.new(1, -16, 0, 28),
            Position = UDim2.new(0, 8, 0, 38),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Text = "",
            PlaceholderText = "Search commands...",
            PlaceholderColor3 = C.textDim,
            TextColor3 = C.text,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            ClearTextOnFocus = true,
            ZIndex = 101,
        })
        PM.corner(PM.UI.CommandsSearch, 6)
        
        PM.UI.CommandsScroll = PM.mk("ScrollingFrame", PM.UI.CommandsPanel, {
            Size = UDim2.new(1, -10, 1, -80),
            Position = UDim2.new(0, 9, 0, 70),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 101,
        })
        
        PM.UI.CommandsList = PM.mk("UIListLayout", PM.UI.CommandsScroll, {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.Name,
        })
        
        PM.UI.CommandsList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            PM.UI.CommandsScroll.CanvasSize = UDim2.new(0, 0, 0, PM.UI.CommandsList.AbsoluteContentSize.Y)
        end)
        
        PM.UI.CommandButtons = {}
        
        PM.UI.CommandsSearch:GetPropertyChangedSignal("Text"):Connect(function()
            local search = PM.UI.CommandsSearch.Text:lower()
            local visibleCount = 0
            for _, data in ipairs(PM.UI.CommandButtons) do
                local match = data.name:lower():find(search, 1, true) or data.desc:lower():find(search, 1, true)
                data.btn.Visible = match or search == ""
                if data.btn.Visible then visibleCount = visibleCount + 1 end
            end
            PM.UI.CommandsScroll.CanvasSize = UDim2.new(0, 0, 0, visibleCount * 38)
        end)
    end
    
    PM.openCommandsPanel = function()
        if not PM.UI.CommandsPanel then
            PM.createCommandsPanel()
        end
        if PM.UI.CommandsPanel.Visible then return end
        
        PM.UI.CommandsPanel.Visible = true
        PM.UI.CommandsPanel.Size = UDim2.new(0, 280, 0, 0)
        PM.tween(PM.UI.CommandsPanel, 0.3, {Size = UDim2.new(0, 280, 0, 320)})
    end
    
    PM.closeCommandsPanel = function()
        if not PM.UI.CommandsPanel or not PM.UI.CommandsPanel.Visible then return end
        
        PM.UI.CommandsSearch.Text = ""
        PM.tween(PM.UI.CommandsPanel, 0.3, {Size = UDim2.new(0, 280, 0, 0)})
        task.delay(0.3, function()
            PM.UI.CommandsPanel.Visible = false
            PM.UI.CommandsPanel.Size = UDim2.new(0, 280, 0, 320)
        end)
    end
    
    PM.hideCommandsPanel = function()
        if not PM.UI.CommandsPanel then return end
        PM.UI.CommandsSearch.Text = ""
        PM.UI.CommandsPanel.Visible = false
        PM.UI.CommandsPanel.Size = UDim2.new(0, 280, 0, 320)
    end

    PM.createNameTagsPanel = function()
        if PM.UI.NameTagsPanel then return end
        
        PM.UI.NameTagsPanel = PM.mk("Frame", PM.UI.Gui, {
            Name = "NameTagsPanel",
            Size = UDim2.new(0, 120, 0, 26),
            Position = UDim2.new(0.5, -60, 0, 35),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
        })
        PM.corner(PM.UI.NameTagsPanel, 6)
        PM.stroke(PM.UI.NameTagsPanel, C.border, 1, 1)
        
        PM.UI.NameTagsLabel = PM.mk("TextLabel", PM.UI.NameTagsPanel, {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "Nametags On",
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.GothamBlack,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTransparency = 1,
            ZIndex = 101,
        })
    end
    
    PM.toggleNameTagsPanel = function()
        if not PM.UI.NameTagsPanel then
            PM.createNameTagsPanel()
        end
        
        if PM.isNameTagsEnabled then
            PM.UI.NameTagsLabel.Text = "Nametags On"
        else
            PM.UI.NameTagsLabel.Text = "Nametags Off"
        end
        
        if PM.fadeOutTask then
            task.cancel(PM.fadeOutTask)
        end
        
        if not PM.UI.NameTagsPanel.Visible then
            PM.UI.NameTagsPanel.Visible = true
            PM.UI.NameTagsPanel.BackgroundTransparency = 1
            PM.UI.NameTagsLabel.TextTransparency = 1
            PM.UI.NameTagsPanel.UIStroke.Transparency = 1
            
            PM.tween(PM.UI.NameTagsPanel, 0.2, {BackgroundTransparency = 0.15})
            PM.tween(PM.UI.NameTagsPanel.UIStroke, 0.2, {Transparency = 0.4})
            PM.tween(PM.UI.NameTagsLabel, 0.2, {TextTransparency = 0})
        end
        
        PM.fadeOutTask = task.delay(1.5, function()
            PM.tween(PM.UI.NameTagsLabel, 0.3, {TextTransparency = 1})
            PM.tween(PM.UI.NameTagsPanel, 0.3, {BackgroundTransparency = 1})
            PM.tween(PM.UI.NameTagsPanel.UIStroke, 0.3, {Transparency = 1})
            task.delay(0.3, function()
                PM.UI.NameTagsPanel.Visible = false
            end)
        end)
    end

    PM.createServersPanel = function()
        if PM.UI.ServersPanel then return end
        
        PM.UI.ServersPanel = PM.mk("Frame", PM.UI.Gui, {
            Name = "ServersPanel",
            Size = UDim2.new(0, 280, 0, 0),
            Position = UDim2.new(0.5, -140, 0, 35),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
            ClipsDescendants = true,
        })
        PM.corner(PM.UI.ServersPanel, 12)
        PM.stroke(PM.UI.ServersPanel, C.border, 1, 0.4)
        
        PM.UI.ServersTitle = PM.mk("TextLabel", PM.UI.ServersPanel, {
            Size = UDim2.new(1, 0, 0, 36),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "Servers",
            TextColor3 = C.text,
            TextSize = 14,
            Font = Enum.Font.GothamBlack,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 101,
        })
        
        PM.UI.ServersClose = PM.mk("TextButton", PM.UI.ServersPanel, {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, -30, 0, 6),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "X",
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            ZIndex = 101,
        })
        PM.corner(PM.UI.ServersClose, 6)
        
        PM.UI.ServersClose.MouseEnter:Connect(function()
            PM.UI.ServersClose.TextColor3 = Color3.fromRGB(255, 80, 80)
        end)
        PM.UI.ServersClose.MouseLeave:Connect(function()
            PM.UI.ServersClose.TextColor3 = C.text
        end)
        
        PM.UI.ServersClose.MouseButton1Click:Connect(function()
            PM.playClickSound()
            PM.isServersOpen = false
            PM.closeServersPanel()
        end)
        
        PM.UI.ServersFilterFrame = PM.mk("Frame", PM.UI.ServersPanel, {
            Size = UDim2.new(1, -16, 0, 28),
            Position = UDim2.new(0, 8, 0, 38),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ZIndex = 101,
        })
        PM.corner(PM.UI.ServersFilterFrame, 6)
        
        PM.UI.ServersFilterList = PM.mk("UIListLayout", PM.UI.ServersFilterFrame, {
            Padding = UDim.new(0, 4),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        
        -- Exclude Full Servers Background
        PM.UI.ExcludeFullBg = PM.mk("Frame", PM.UI.ServersPanel, {
            Size = UDim2.new(1, -16, 0, 26),
            Position = UDim2.new(0, 8, 0, 70),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ZIndex = 100,
        })
        PM.corner(PM.UI.ExcludeFullBg, 6)
        
        -- Exclude Full Servers Label
        PM.UI.ExcludeFullLabel = PM.mk("TextLabel", PM.UI.ServersPanel, {
            Size = UDim2.new(1, -56, 0, 20),
            Position = UDim2.new(0, 13, 0, 72),
            BackgroundTransparency = 1,
            Text = "Exclude full servers",
            TextColor3 = C.text,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 101,
        })
        
        -- Toggle Switch (Mono.lua style)
        PM.UI.ExcludeFullSwitch = PM.mk("Frame", PM.UI.ServersPanel, {
            Size = UDim2.new(0, 26, 0, 13),
            Position = UDim2.new(1, -39, 0, 81),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Color3.fromRGB(50, 50, 50),
            BorderSizePixel = 0,
            ZIndex = 101,
        })
        PM.corner(PM.UI.ExcludeFullSwitch, 10)
        
        -- Toggle Circle
        PM.UI.ExcludeFullCircle = PM.mk("Frame", PM.UI.ExcludeFullSwitch, {
            Size = UDim2.new(0, 9, 0, 9),
            Position = UDim2.new(0, 2, 0.5, -4),
            BackgroundColor3 = Color3.fromRGB(235, 235, 235),
            BorderSizePixel = 0,
            ZIndex = 102,
        })
        PM.corner(PM.UI.ExcludeFullCircle, 10)
        
        -- Toggle Hit Button
        PM.UI.ExcludeFullToggle = PM.mk("TextButton", PM.UI.ExcludeFullSwitch, {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 103,
        })
        
        -- Set initial visual state (ON by default with medium gray)
        PM.UI.ExcludeFullSwitch.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        PM.UI.ExcludeFullCircle.Position = UDim2.new(1, -11, 0.5, -4)
        
        PM.UI.ExcludeFullToggle.MouseButton1Click:Connect(function()
            PM.playClickSound()
            PM.excludeFullServers = not PM.excludeFullServers
            if PM.excludeFullServers then
                PM.tween(PM.UI.ExcludeFullSwitch, 0.2, {BackgroundColor3 = Color3.fromRGB(80, 80, 80)})
                PM.tween(PM.UI.ExcludeFullCircle, 0.2, {Position = UDim2.new(1, -11, 0.5, -4)})
            else
                PM.tween(PM.UI.ExcludeFullSwitch, 0.2, {BackgroundColor3 = Color3.fromRGB(50, 50, 50)})
                PM.tween(PM.UI.ExcludeFullCircle, 0.2, {Position = UDim2.new(0, 2, 0.5, -4)})
            end
            PM.serversFetched = false
            PM.fetchServers()
        end)
        
        PM.serversFilter = "most"
        PM.excludeFullServers = true
        PM.serverListData = {}
        PM.serversFetched = false
        
        local filters = {
            {name = "Most", id = "most", order = 1},
            {name = "Low Ping", id = "lowping", order = 2},
            {name = "Fewest", id = "fewest", order = 3},
        }
        
        PM.UI.ServersFilterButtons = {}
        for _, filter in ipairs(filters) do
            local btn = PM.mk("TextButton", PM.UI.ServersFilterFrame, {
                Size = UDim2.new(0, 80, 0, 24),
                BackgroundColor3 = C.bg,
                BackgroundTransparency = filter.id == "most" and 0.3 or 0.7,
                BorderSizePixel = 0,
                Text = filter.name,
                TextColor3 = C.text,
                TextSize = 9,
                Font = Enum.Font.Gotham,
                Name = filter.id,
                LayoutOrder = filter.order,
                ZIndex = 102,
            })
            PM.corner(btn, 4)
            
            btn.MouseButton1Click:Connect(function()
                PM.playClickSound()
                PM.serversFilter = filter.id
                for _, b in ipairs(PM.UI.ServersFilterButtons) do
                    PM.tween(b, 0.15, {BackgroundTransparency = b.Name == filter.id and 0.3 or 0.7})
                end
                PM.renderServerList()
            end)
            
            table.insert(PM.UI.ServersFilterButtons, btn)
        end
        
        PM.UI.ServersScroll = PM.mk("ScrollingFrame", PM.UI.ServersPanel, {
            Size = UDim2.new(1, -10, 1, -110),
            Position = UDim2.new(0, 9, 0, 100),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 101,
        })
        
        PM.UI.ServersList = PM.mk("UIListLayout", PM.UI.ServersScroll, {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.Name,
        })
        
        PM.UI.ServersList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            PM.UI.ServersScroll.CanvasSize = UDim2.new(0, 0, 0, PM.UI.ServersList.AbsoluteContentSize.Y)
        end)
        
    end
    
    PM.fetchServers = function()
        local HttpService = game:GetService("HttpService")
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        
        if success and result and result.data then
            PM.serverListData = {}
            for _, server in ipairs(result.data) do
                if not PM.excludeFullServers or server.playing < server.maxPlayers then
                    table.insert(PM.serverListData, server)
                end
            end
            PM.serversFetched = true
            PM.renderServerList()
            return true
        else
            return false
        end
    end
    
    PM.renderServerList = function()
        if not PM.UI.ServersScroll then return end
        
        for _, child in ipairs(PM.UI.ServersScroll:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        local servers = {}
        for _, server in ipairs(PM.serverListData) do
            table.insert(servers, server)
        end
        
        if PM.serversFilter == "lowping" then
            table.sort(servers, function(a, b)
                return (a.ping or math.huge) < (b.ping or math.huge)
            end)
        elseif PM.serversFilter == "most" then
            table.sort(servers, function(a, b)
                return (a.playing or 0) > (b.playing or 0)
            end)
        elseif PM.serversFilter == "fewest" then
            table.sort(servers, function(a, b)
                return (a.playing or 0) < (b.playing or 0)
            end)
        end
        
        local displayCount = math.min(#servers, 25)
        for i = 1, displayCount do
            local server = servers[i]
            if not server then break end
            
            local ping = server.ping or 0
            local playing = server.playing or 0
            local maxPlayers = server.maxPlayers or 0
            local pingColor = ping < 50 and Color3.fromRGB(80, 220, 120) or ping < 100 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(255, 80, 80)
            
            local btn = PM.mk("TextButton", PM.UI.ServersScroll, {
                Size = UDim2.new(1, -6, 0, 32),
                BackgroundColor3 = C.card,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                Text = "",
                Name = "Server_" .. i,
                ZIndex = 102,
            })
            PM.corner(btn, 6)
            
            PM.mk("TextLabel", btn, {
                Size = UDim2.new(0.4, 0, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = "Ping: " .. ping .. "ms",
                TextColor3 = pingColor,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 103,
            })
            
            PM.mk("TextLabel", btn, {
                Size = UDim2.new(0.5, 0, 1, 0),
                Position = UDim2.new(0.5, -8, 0, 0),
                BackgroundTransparency = 1,
                Text = playing .. "/" .. maxPlayers .. " players",
                TextColor3 = C.text,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 103,
            })
            
            btn.MouseEnter:Connect(function()
                PM.tween(btn, 0.15, {BackgroundTransparency = 0.2})
            end)
            btn.MouseLeave:Connect(function()
                PM.tween(btn, 0.15, {BackgroundTransparency = 0.5})
            end)
            btn.MouseButton1Click:Connect(function()
                PM.playClickSound()
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, server.id, PM.Svc.Players.LocalPlayer)
            end)
        end
        
    end
    
    PM.openServersPanel = function()
        if not PM.UI.ServersPanel then
            PM.createServersPanel()
        end
        
        PM.isServersOpen = true
        PM.UI.ServersPanel.Visible = true
        PM.UI.ServersPanel.Size = UDim2.new(0, 280, 0, 0)
        PM.tween(PM.UI.ServersPanel, 0.3, {Size = UDim2.new(0, 280, 0, 320)})
        
        if not PM.serversFetched then
            task.spawn(function()
                PM.fetchServers()
            end)
        end
    end
    
    PM.closeServersPanel = function()
        if not PM.UI.ServersPanel or not PM.UI.ServersPanel.Visible then return end
        
        PM.isServersOpen = false
        PM.tween(PM.UI.ServersPanel, 0.3, {Size = UDim2.new(0, 280, 0, 0)})
        task.delay(0.3, function()
            PM.UI.ServersPanel.Visible = false
            PM.UI.ServersPanel.Size = UDim2.new(0, 280, 0, 320)
        end)
    end
    
    PM.hideServersPanel = function()
        if not PM.UI.ServersPanel then return end
        PM.isServersOpen = false
        PM.UI.ServersPanel.Visible = false
        PM.UI.ServersPanel.Size = UDim2.new(0, 280, 0, 320)
    end
    
    -- ========== JOIN PRISM USERS PANEL ==========
    PM.createJoinPanel = function()
        if PM.UI.JoinPanel then return end
        
        PM.UI.JoinPanel = PM.mk("Frame", PM.UI.Gui, {
            Name = "JoinPanel",
            Size = UDim2.new(0, 280, 0, 0),
            Position = UDim2.new(0.5, -140, 0, 35),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
            ClipsDescendants = true,
        })
        PM.corner(PM.UI.JoinPanel, 12)
        PM.stroke(PM.UI.JoinPanel, C.border, 1, 0.4)
        
        -- Title
        PM.UI.JoinTitle = PM.mk("TextLabel", PM.UI.JoinPanel, {
            Size = UDim2.new(1, 0, 0, 36),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "Join Prism Users",
            TextColor3 = C.text,
            TextSize = 14,
            Font = Enum.Font.GothamBlack,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 101,
        })
        
        -- Close button
        PM.UI.JoinClose = PM.mk("TextButton", PM.UI.JoinPanel, {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, -30, 0, 6),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "X",
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            ZIndex = 101,
        })
        PM.corner(PM.UI.JoinClose, 6)
        
        PM.UI.JoinClose.MouseEnter:Connect(function()
            PM.UI.JoinClose.TextColor3 = Color3.fromRGB(255, 80, 80)
        end)
        PM.UI.JoinClose.MouseLeave:Connect(function()
            PM.UI.JoinClose.TextColor3 = C.text
        end)
        
        PM.UI.JoinClose.MouseButton1Click:Connect(function()
            PM.playClickSound()
            PM.isJoinOpen = false
            PM.closeJoinPanel()
        end)
        
        -- Filter buttons frame
        PM.UI.JoinFilterFrame = PM.mk("Frame", PM.UI.JoinPanel, {
            Size = UDim2.new(1, -16, 0, 28),
            Position = UDim2.new(0, 8, 0, 38),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ZIndex = 101,
        })
        PM.corner(PM.UI.JoinFilterFrame, 6)
        
        local filterList = PM.mk("UIListLayout", PM.UI.JoinFilterFrame, {
            Padding = UDim.new(0, 4),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
        })
        
        -- Filter buttons
        PM.UI.JoinFilterButtons = {}
        local filters = {
            {name = "This Game", id = "This Game"},
            {name = "All Games", id = "All Games"},
            {name = "Friends", id = "Friends"},
        }
        for _, filter in ipairs(filters) do
            local btn = PM.mk("TextButton", PM.UI.JoinFilterFrame, {
                Name = filter.id,
                Size = UDim2.new(0, 76, 0, 24),
                BackgroundColor3 = C.bg,
                BackgroundTransparency = filter.id == "All Games" and 0.3 or 0.7,
                BorderSizePixel = 0,
                Text = filter.name,
                TextColor3 = C.text,
                TextSize = 9,
                Font = Enum.Font.Gotham,
                ZIndex = 102,
            })
            PM.corner(btn, 4)
            table.insert(PM.UI.JoinFilterButtons, btn)
        end
        
        -- Search box
        PM.UI.JoinSearch = PM.mk("TextBox", PM.UI.JoinPanel, {
            Name = "JoinSearch",
            Size = UDim2.new(1, -16, 0, 28),
            Position = UDim2.new(0, 8, 0, 70),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            Text = "",
            PlaceholderText = "Search users...",
            TextColor3 = C.text,
            PlaceholderColor3 = Color3.fromRGB(120, 120, 120),
            TextSize = 10,
            Font = Enum.Font.Gotham,
            ClearTextOnFocus = false,
            ZIndex = 101,
        })
        PM.corner(PM.UI.JoinSearch, 6)
        
        -- User scroll frame (no refresh button, so larger)
        PM.UI.JoinScroll = PM.mk("ScrollingFrame", PM.UI.JoinPanel, {
            Name = "JoinScroll",
            Size = UDim2.new(1, -10, 1, -106),
            Position = UDim2.new(0, 9, 0, 102),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 101,
        })
        
        PM.UI.JoinList = PM.mk("UIListLayout", PM.UI.JoinScroll, {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        
        PM.UI.JoinList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            PM.UI.JoinScroll.CanvasSize = UDim2.new(0, 0, 0, PM.UI.JoinList.AbsoluteContentSize.Y)
        end)
        
        -- Join panel logic
        local HttpService = game:GetService("HttpService")
        local TeleportService = game:GetService("TeleportService")
        local currentJoinFilter = "All Games"
        local cachedServers = {}
        local renderServerList
        
        local function fetchPrismServers()
            local servers = PM.PrismAPI.getServers(true)
            return servers or {}
        end
        
        renderServerList = function()
            -- Clear existing
            for _, child in ipairs(PM.UI.JoinScroll:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end
            
            local servers = cachedServers
            local searchQuery = PM.UI.JoinSearch.Text:lower()
            
            for _, server in ipairs(servers) do
                -- Filter by search
                if searchQuery ~= "" then
                    local usernames = server.usernames or {}
                    local match = false
                    for _, username in ipairs(usernames) do
                        if username:lower():find(searchQuery, 1, true) then
                            match = true
                            break
                        end
                    end
                    if not match then continue end
                end
                
                local userCount = server.user_count or 0
                local usernames = server.usernames or {}
                local usernameList = table.concat(usernames, ", ")
                
                local btn = PM.mk("TextButton", PM.UI.JoinScroll, {
                    Size = UDim2.new(1, -6, 0, 44),
                    BackgroundColor3 = C.card,
                    BackgroundTransparency = 0.5,
                    BorderSizePixel = 0,
                    Text = "",
                    Name = "Server_" .. tostring(server.server_id),
                    ZIndex = 102,
                })
                PM.corner(btn, 6)
                
                PM.mk("TextLabel", btn, {
                    Size = UDim2.new(1, -16, 0, 16),
                    Position = UDim2.new(0, 8, 0, 4),
                    BackgroundTransparency = 1,
                    Text = userCount .. " Prism User(s)",
                    TextColor3 = Color3.fromRGB(0, 200, 70),
                    TextSize = 11,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 103,
                })
                
                PM.mk("TextLabel", btn, {
                    Size = UDim2.new(1, -16, 0, 24),
                    Position = UDim2.new(0, 8, 0, 20),
                    BackgroundTransparency = 1,
                    Text = usernameList,
                    TextColor3 = C.textDim,
                    TextSize = 9,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 103,
                })
                
                btn.MouseEnter:Connect(function()
                    PM.tween(btn, 0.15, {BackgroundTransparency = 0.2})
                end)
                btn.MouseLeave:Connect(function()
                    PM.tween(btn, 0.15, {BackgroundTransparency = 0.5})
                end)
                btn.MouseButton1Click:Connect(function()
                    PM.playClickSound()
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.server_id, PM.Svc.Players.LocalPlayer)
                    end)
                end)
            end
        end
        
        -- Initial fetch
        cachedServers = fetchPrismServers()
        renderServerList()
        
        -- Refresh every 30 seconds
        spawn(function()
            while PM.UI.JoinPanel do
                task.wait(30)
                cachedServers = fetchPrismServers()
                renderServerList()
            end
        end)
        
        -- Search filter
        PM.UI.JoinSearch:GetPropertyChangedSignal("Text"):Connect(function()
            renderServerList()
        end)
        
        -- Filter buttons
        for _, btn in ipairs(PM.UI.JoinFilterButtons) do
            btn.MouseButton1Click:Connect(function()
                PM.playClickSound()
                currentJoinFilter = btn.Name
                for _, b in ipairs(PM.UI.JoinFilterButtons) do
                    PM.tween(b, 0.15, {BackgroundTransparency = b.Name == currentJoinFilter and 0.3 or 0.7})
                end
            end)
        end
    end
    
    PM.openJoinPanel = function()
        if not PM.UI.JoinPanel then
            PM.createJoinPanel()
        end
        
        PM.isJoinOpen = true
        PM.UI.JoinPanel.Visible = true
        PM.UI.JoinPanel.Size = UDim2.new(0, 280, 0, 0)
        PM.tween(PM.UI.JoinPanel, 0.3, {Size = UDim2.new(0, 280, 0, 320)})
    end
    
    PM.closeJoinPanel = function()
        if not PM.UI.JoinPanel or not PM.UI.JoinPanel.Visible then return end
        
        PM.isJoinOpen = false
        PM.tween(PM.UI.JoinPanel, 0.3, {Size = UDim2.new(0, 280, 0, 0)})
        task.delay(0.3, function()
            PM.UI.JoinPanel.Visible = false
            PM.UI.JoinPanel.Size = UDim2.new(0, 280, 0, 320)
        end)
    end
    
    PM.hideJoinPanel = function()
        if not PM.UI.JoinPanel then return end
        PM.isJoinOpen = false
        PM.UI.JoinPanel.Visible = false
        PM.UI.JoinPanel.Size = UDim2.new(0, 280, 0, 320)
    end

    PM.createSettingsPanel = function()
        if PM.UI.SettingsPanel then return end

        PM.UI.SettingsPanel = PM.mk("Frame", PM.UI.Gui, {
            Name = "SettingsPanel",
            Size = UDim2.new(0, 280, 0, 320),
            Position = UDim2.new(0.5, -140, 0, 35),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
            ClipsDescendants = true,
        })
        PM.corner(PM.UI.SettingsPanel, 12)
        PM.stroke(PM.UI.SettingsPanel, C.border, 1, 0.4)

        PM.UI.SettingsTitle = PM.mk("TextLabel", PM.UI.SettingsPanel, {
            Size = UDim2.new(1, 0, 0, 36),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "Settings",
            TextColor3 = C.text,
            TextSize = 14,
            Font = Enum.Font.GothamBlack,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 101,
        })

        PM.UI.SettingsClose = PM.mk("TextButton", PM.UI.SettingsPanel, {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, -30, 0, 6),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "X",
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            ZIndex = 101,
        })
        PM.corner(PM.UI.SettingsClose, 6)

        PM.UI.SettingsClose.MouseEnter:Connect(function()
            PM.UI.SettingsClose.TextColor3 = Color3.fromRGB(255, 80, 80)
        end)
        PM.UI.SettingsClose.MouseLeave:Connect(function()
            PM.UI.SettingsClose.TextColor3 = C.text
        end)

        PM.UI.SettingsClose.MouseButton1Click:Connect(function()
            PM.playClickSound()
            PM.isSettingsOpen = false
            PM.closeSettingsPanel()
        end)

        PM.UI.SettingsButtonContainer = PM.mk("Frame", PM.UI.SettingsPanel, {
            Name = "ButtonContainer",
            Size = UDim2.new(1, -16, 0, 28),
            Position = UDim2.new(0, 8, 0, 38),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ZIndex = 101,
        })
        PM.corner(PM.UI.SettingsButtonContainer, 6)

        PM.mk("UIListLayout", PM.UI.SettingsButtonContainer, {
            Padding = UDim.new(0, 4),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        local function makeTabBtn(name, text, layout, isActive)
            local btn = PM.mk("TextButton", PM.UI.SettingsButtonContainer, {
                Name = name,
                Size = UDim2.new(0.5, -6, 1, -6),
                BackgroundColor3 = C.bg,
                BackgroundTransparency = isActive and 0.3 or 0.7,
                BorderSizePixel = 0,
                Text = text,
                TextColor3 = C.text,
                TextSize = 9,
                Font = Enum.Font.Gotham,
                AutoButtonColor = false,
                LayoutOrder = layout,
                ZIndex = 102,
            })
            PM.corner(btn, 4)

            btn.MouseEnter:Connect(function()
                if PM.activeSettingsTab ~= btn then
                    PM.tween(btn, 0.15, {BackgroundTransparency = 0.5})
                end
            end)
            btn.MouseLeave:Connect(function()
                if PM.activeSettingsTab ~= btn then
                    PM.tween(btn, 0.15, {BackgroundTransparency = 0.7})
                end
            end)

            return btn
        end

        PM.UI.SettingsTabAutoExec = makeTabBtn("AutoExecBtn", "Auto Execute", 1, true)
        PM.UI.SettingsTabSound = makeTabBtn("SoundBtn", "Sound", 2, false)
        PM.activeSettingsTab = PM.UI.SettingsTabAutoExec

        local function setActiveTab(activeBtn)
            PM.activeSettingsTab = activeBtn
            for _, btn in ipairs({PM.UI.SettingsTabAutoExec, PM.UI.SettingsTabSound}) do
                PM.tween(btn, 0.15, {BackgroundTransparency = 0.7})
            end
            PM.tween(activeBtn, 0.15, {BackgroundTransparency = 0.3})
            if PM.UI.AutoExecContent then
                PM.UI.AutoExecContent.Visible = (activeBtn == PM.UI.SettingsTabAutoExec)
            end
            if PM.UI.SoundContent then
                PM.UI.SoundContent.Visible = (activeBtn == PM.UI.SettingsTabSound)
            end
        end

        PM.UI.SettingsTabAutoExec.MouseButton1Click:Connect(function()
            PM.playClickSound()
            setActiveTab(PM.UI.SettingsTabAutoExec)
        end)
        PM.UI.SettingsTabSound.MouseButton1Click:Connect(function()
            PM.playClickSound()
            setActiveTab(PM.UI.SettingsTabSound)
        end)

        PM.UI.AutoExecContent = PM.mk("Frame", PM.UI.SettingsPanel, {
            Name = "AutoExecContent",
            Size = UDim2.new(1, 0, 0, 240),
            Position = UDim2.new(0, 0, 0, 70),
            BackgroundTransparency = 1,
            ZIndex = 101,
        })

        local function createToggleRow(parent, name, labelText, yPos, defaultState, onToggle)
            local bg = PM.mk("Frame", parent, {
                Name = name .. "Bg",
                Size = UDim2.new(1, -16, 0, 26),
                Position = UDim2.new(0, 8, 0, yPos),
                BackgroundColor3 = C.card,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                ZIndex = 102,
            })
            PM.corner(bg, 6)

            PM.mk("TextLabel", bg, {
                Size = UDim2.new(1, -56, 0, 20),
                Position = UDim2.new(0, 8, 0, 3),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = C.text,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 103,
            })

            local switch = PM.mk("Frame", bg, {
                Name = name .. "Switch",
                Size = UDim2.new(0, 26, 0, 13),
                Position = UDim2.new(1, -36, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = defaultState and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(50, 50, 50),
                BorderSizePixel = 0,
                ZIndex = 103,
            })
            PM.corner(switch, 10)

            local circle = PM.mk("Frame", switch, {
                Name = name .. "Circle",
                Size = UDim2.new(0, 9, 0, 9),
                Position = defaultState and UDim2.new(1, -11, 0.5, -4) or UDim2.new(0, 2, 0.5, -4),
                BackgroundColor3 = Color3.fromRGB(235, 235, 235),
                BorderSizePixel = 0,
                ZIndex = 104,
            })
            PM.corner(circle, 10)

            local hitBtn = PM.mk("TextButton", switch, {
                Name = name .. "Hit",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 105,
            })

            local state = defaultState
            hitBtn.MouseButton1Click:Connect(function()
                PM.playClickSound()
                state = not state
                if state then
                    PM.tween(switch, 0.2, {BackgroundColor3 = Color3.fromRGB(80, 80, 80)})
                    PM.tween(circle, 0.2, {Position = UDim2.new(1, -11, 0.5, -4)})
                else
                    PM.tween(switch, 0.2, {BackgroundColor3 = Color3.fromRGB(50, 50, 50)})
                    PM.tween(circle, 0.2, {Position = UDim2.new(0, 2, 0.5, -4)})
                end
                if onToggle then onToggle(state) end
            end)

            return bg
        end

        -- Save settings to file (settings already loaded at top of script)
        local function saveSettings()
            if not writefile then return end
            pcall(function()
                if not isfolder("prism") then
                    makefolder("prism")
                end
                local settings = {
                    autoExecutePrism = PM.autoExecutePrism,
                    autoExecuteCommands = PM.autoExecuteCommands,
                    terminalKeybind = PM.terminalKeybind,
                }
                writefile("prism/prism_settings.json", game:GetService("HttpService"):JSONEncode(settings))
            end)
        end
        
        -- Initialize with loaded or default values (loaded at top of script)
        local autoExecPrismDefault = PM.autoExecutePrism or false
        local autoExecCommandsDefault = PM.autoExecuteCommands ~= false
        PM.terminalKeybind = PM.terminalKeybind or "F6"
        
        PM.autoExecutePrism = autoExecPrismDefault
        PM.autoExecuteCommands = autoExecCommandsDefault

        -- Setup teleport check for auto execute prism (matching Infinite Yield pattern)
        pcall(function()
            local TeleportCheck = false
            local queueteleport = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or (krnl and krnl.queue_on_teleport) or (is_sirius and is_sirius.queue_on_teleport)
            
            if queueteleport and Players.LocalPlayer then
                Players.LocalPlayer.OnTeleport:Connect(function(State)
                    if PM.autoExecutePrism and (not TeleportCheck) and queueteleport then
                        TeleportCheck = true
                        pcall(function()
                            queueteleport([[loadstring(game:HttpGet("https://prismscript.vercel.app/Prism.lua"))()]])
                        end)
                    end
                end)
            end
        end)

        createToggleRow(PM.UI.AutoExecContent, "AutoExecPrism", "Auto execute prism", 0, autoExecPrismDefault, function(state)
            PM.autoExecutePrism = state
            saveSettings()
        end)

        createToggleRow(PM.UI.AutoExecContent, "AutoExecuteCommands", "Auto execute commands", 28, autoExecCommandsDefault, function(state)
            PM.autoExecuteCommands = state
            saveSettings()
        end)

        PM.UI.AutoExecSearch = PM.mk("TextBox", PM.UI.AutoExecContent, {
            Name = "AutoExecSearch",
            Size = UDim2.new(1, -16, 0, 28),
            Position = UDim2.new(0, 8, 0, 56),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Text = "",
            PlaceholderText = "Search commands...",
            PlaceholderColor3 = C.textDim,
            TextColor3 = C.text,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            ClearTextOnFocus = true,
            ZIndex = 102,
        })
        PM.corner(PM.UI.AutoExecSearch, 6)

        PM.UI.AutoExecScroll = PM.mk("ScrollingFrame", PM.UI.AutoExecContent, {
            Name = "AutoExecScroll",
            Size = UDim2.new(1, -10, 1, -88),
            Position = UDim2.new(0, 9, 0, 88),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 102,
        })

        PM.UI.AutoExecList = PM.mk("UIListLayout", PM.UI.AutoExecScroll, {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        PM.UI.AutoExecList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            PM.UI.AutoExecScroll.CanvasSize = UDim2.new(0, 0, 0, PM.UI.AutoExecList.AbsoluteContentSize.Y)
        end)

        -- ========== SOUND CONTENT ==========
        PM.UI.SoundContent = PM.mk("Frame", PM.UI.SettingsPanel, {
            Name = "SoundContent",
            Size = UDim2.new(1, 0, 0, 240),
            Position = UDim2.new(0, 0, 0, 70),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 101,
        })

        PM.UI.SoundScroll = PM.mk("ScrollingFrame", PM.UI.SoundContent, {
            Name = "SoundScroll",
            Size = UDim2.new(1, -10, 1, 0),
            Position = UDim2.new(0, 9, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.border,
            CanvasSize = UDim2.new(0, 0, 0, 266),
            ZIndex = 102,
        })

        local function makeSectionLabel(parent, text, yPos)
            PM.mk("TextLabel", parent, {
                Size = UDim2.new(1, -16, 0, 14),
                Position = UDim2.new(0, 8, 0, yPos),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = C.textDim,
                TextSize = 9,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 103,
            })
        end

        local function makeSliderRow(parent, name, labelText, yPos, defaultValue, onChange)
            local bg = PM.mk("Frame", parent, {
                Name = name .. "Bg",
                Size = UDim2.new(1, -16, 0, 38),
                Position = UDim2.new(0, 8, 0, yPos),
                BackgroundColor3 = C.card,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                ZIndex = 103,
            })
            PM.corner(bg, 6)

            PM.mk("TextLabel", bg, {
                Size = UDim2.new(1, -80, 0, 16),
                Position = UDim2.new(0, 8, 0, 4),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = C.text,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 104,
            })

            local valueLabel = PM.mk("TextLabel", bg, {
                Name = "ValueLabel",
                Size = UDim2.new(0, 40, 0, 16),
                Position = UDim2.new(1, -48, 0, 4),
                BackgroundTransparency = 1,
                Text = string.format("%.2f", defaultValue),
                TextColor3 = C.textDim,
                TextSize = 9,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 104,
            })

            local track = PM.mk("TextButton", bg, {
                Name = name .. "Track",
                Size = UDim2.new(1, -20, 0, 4),
                Position = UDim2.new(0, 10, 0, 26),
                BackgroundColor3 = Color3.fromRGB(30, 30, 38),
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 104,
            })
            PM.corner(track, 4)

            local fill = PM.mk("Frame", track, {
                Name = name .. "Fill",
                Size = UDim2.new(defaultValue, 0, 1, 0),
                BackgroundColor3 = C.text,
                BorderSizePixel = 0,
                ZIndex = 105,
            })
            PM.corner(fill, 4)

            local knob = PM.mk("Frame", track, {
                Name = name .. "Knob",
                Size = UDim2.new(0, 10, 0, 10),
                Position = UDim2.new(defaultValue, -5, 0.5, -5),
                BackgroundColor3 = C.text,
                BorderSizePixel = 0,
                ZIndex = 106,
            })
            PM.corner(knob, 6)

            local currentValue = defaultValue
            local isDragging = false

            local function updateSlider(input)
                local sliderWidth = track.AbsoluteSize.X
                local relativeX = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, sliderWidth)
                local newValue = relativeX / sliderWidth
                currentValue = newValue
                fill.Size = UDim2.new(newValue, 0, 1, 0)
                knob.Position = UDim2.new(newValue, -5, 0.5, -5)
                valueLabel.Text = string.format("%.2f", newValue)
                if onChange then onChange(newValue) end
            end

            knob.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    isDragging = true
                end
            end)

            track.MouseButton1Down:Connect(function(input)
                isDragging = true
                updateSlider(input)
            end)

            game:GetService("UserInputService").InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 and isDragging then
                    isDragging = false
                end
            end)

            game:GetService("UserInputService").InputChanged:Connect(function(input)
                if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    updateSlider(input)
                end
            end)

            return bg
        end

        local function makeSoundIDRow(parent, name, labelText, yPos, defaultID, onChange)
            local bg = PM.mk("Frame", parent, {
                Name = name .. "Bg",
                Size = UDim2.new(1, -16, 0, 48),
                Position = UDim2.new(0, 8, 0, yPos),
                BackgroundColor3 = C.card,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                ZIndex = 103,
            })
            PM.corner(bg, 6)

            PM.mk("TextLabel", bg, {
                Size = UDim2.new(1, -16, 0, 16),
                Position = UDim2.new(0, 8, 0, 4),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = C.text,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 104,
            })

            local box = PM.mk("TextBox", bg, {
                Size = UDim2.new(1, -20, 0, 20),
                Position = UDim2.new(0, 10, 0, 22),
                BackgroundColor3 = C.bg,
                BackgroundTransparency = 0.3,
                BorderSizePixel = 0,
                ClearTextOnFocus = false,
                PlaceholderText = "Sound Asset ID...",
                PlaceholderColor3 = C.textDim,
                Text = defaultID,
                TextColor3 = C.text,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                ZIndex = 104,
            })
            PM.corner(box, 3)

            box.FocusLost:Connect(function()
                if box.Text ~= "" and onChange then
                    onChange(box.Text)
                end
            end)

            return bg
        end

        -- CLICK SOUND section
        makeSectionLabel(PM.UI.SoundScroll, "CLICK SOUND", 0)
        createToggleRow(PM.UI.SoundScroll, "ClickSoundToggle", "Enable Click Sound", 16, PM.clickSoundEnabled, function(state)
            PM.clickSoundEnabled = state
        end)
        makeSliderRow(PM.UI.SoundScroll, "ClickVolume", "Click Volume", 44, PM.clickVolume, function(val)
            PM.clickVolume = val
            if PM.UI.ClickSound then PM.UI.ClickSound.Volume = val end
        end)
        makeSoundIDRow(PM.UI.SoundScroll, "ClickSoundID", "Click Sound ID", 84, PM.clickSoundID, function(id)
            PM.clickSoundID = id
            if PM.UI.ClickSound then PM.UI.ClickSound.SoundId = "rbxassetid://" .. id end
        end)

        -- HOVER SOUND section
        makeSectionLabel(PM.UI.SoundScroll, "HOVER SOUND", 134)
        createToggleRow(PM.UI.SoundScroll, "HoverSoundToggle", "Enable Hover Sound", 150, PM.hoverSoundEnabled, function(state)
            PM.hoverSoundEnabled = state
        end)
        makeSliderRow(PM.UI.SoundScroll, "HoverVolume", "Hover Volume", 178, PM.hoverVolume, function(val)
            PM.hoverVolume = val
            if PM.UI.HoverSound then PM.UI.HoverSound.Volume = val end
        end)
        makeSoundIDRow(PM.UI.SoundScroll, "HoverSoundID", "Hover Sound ID", 218, PM.hoverSoundID, function(id)
            PM.hoverSoundID = id
            if PM.UI.HoverSound then PM.UI.HoverSound.SoundId = "rbxassetid://" .. id end
        end)

        setActiveTab(PM.UI.SettingsTabAutoExec)
    end

    PM.openSettingsPanel = function()
        if not PM.UI.SettingsPanel then
            PM.createSettingsPanel()
        end
        PM.isSettingsOpen = true
        PM.UI.SettingsPanel.Visible = true
        PM.UI.SettingsPanel.Size = UDim2.new(0, 280, 0, 0)
        PM.tween(PM.UI.SettingsPanel, 0.3, {Size = UDim2.new(0, 280, 0, 320)})
    end

    PM.closeSettingsPanel = function()
        if not PM.UI.SettingsPanel or not PM.UI.SettingsPanel.Visible then return end
        PM.isSettingsOpen = false
        PM.tween(PM.UI.SettingsPanel, 0.3, {Size = UDim2.new(0, 280, 0, 0)})
        task.delay(0.3, function()
            PM.UI.SettingsPanel.Visible = false
            PM.UI.SettingsPanel.Size = UDim2.new(0, 280, 0, 320)
        end)
    end

    PM.hideSettingsPanel = function()
        if not PM.UI.SettingsPanel then return end
        PM.isSettingsOpen = false
        PM.UI.SettingsPanel.Visible = false
        PM.UI.SettingsPanel.Size = UDim2.new(0, 280, 0, 320)
    end

    PM.UI.LeftDivider = PM.mk("Frame", PM.UI.Main, {
        Name = "LeftDivider",
        Size = UDim2.new(0, 1, 0, 44),
        Position = UDim2.new(0, 70, 0.5, -22),
        BackgroundColor3 = C.border,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 10,
    })

    PM.UI.RightDivider = PM.mk("Frame", PM.UI.Main, {
        Name = "RightDivider",
        Size = UDim2.new(0, 1, 0, 44),
        Position = UDim2.new(1, -70, 0.5, -22),
        BackgroundColor3 = C.border,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 10,
    })
    
    PM.UI.RightFrame = PM.mk("Frame", PM.UI.Main, {
        Name = "RightFrame",
        Size = UDim2.new(0, 130, 0, 44),
        Position = UDim2.new(1, -136, 0.5, -22),
        BackgroundTransparency = 1,
        ZIndex = 10,
    })
    
    PM.UI.PrismLabel = PM.mk("TextLabel", PM.UI.RightFrame, {
        Name = "PrismLabel",
        Size = UDim2.new(1, -32, 0, 14),
        Position = UDim2.new(0, 25, 0, 2),
        BackgroundTransparency = 1,
        Text = "PRISM",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.GothamBlack,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    PM.UI.PlayerCountLabel = PM.mk("TextLabel", PM.UI.RightFrame, {
        Name = "PlayerCountLabel",
        Size = UDim2.new(1, -32, 0, 14),
        Position = UDim2.new(0, 25, 0, 23),
        BackgroundTransparency = 1,
        Text = "0/0",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    
    PM.UI.LogoFrame = PM.mk("Frame", PM.UI.RightFrame, {
        Name = "LogoFrame",
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -26, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Rotation = 315,
    })
    
    PM.UI.LogoBg = PM.mk("ImageLabel", PM.UI.LogoFrame, {
        Name = "LogoBg",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6734565426",
        ImageColor3 = C.accent,
    })
    
    local currentRotation = 315
    PM.Svc.RunService.Heartbeat:Connect(function(deltaTime)
        if PM.UI.Gui and PM.UI.Gui.Parent and PM.UI.LogoFrame then
            currentRotation = currentRotation + (120 * deltaTime)
            PM.UI.LogoFrame.Rotation = currentRotation
        end
    end)
    
    task.spawn(function()
        PM.UI.Main.Position = UDim2.new(0.5, -230, 0, -120)
        task.wait(0.2)
        PM.tween(PM.UI.Main, 0.6, {Position = UDim2.new(0.5, -230, 0, -30)})
    end)
    
    local frames = 0
    local lastT = tick()
    PM.Svc.RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local now = tick()
        if now - lastT >= 1 then
            local fps = frames
            frames = 0
            lastT = now
            if PM.UI.FPSLabel then
                PM.UI.FPSLabel.Text = fps
                if fps < 30 then
                    PM.UI.FPSLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                elseif fps < 60 then
                    PM.UI.FPSLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
                else
                    PM.UI.FPSLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
                end
            end
        end
    end)
    
    task.spawn(function()
        while PM.UI.Gui and PM.UI.Gui.Parent do
            local ping = math.round(LP:GetNetworkPing() * 1000)
            if PM.UI.PingLabel then
                PM.UI.PingLabel.Text = ping
                if ping < 50 then
                    PM.UI.PingLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
                elseif ping < 150 then
                    PM.UI.PingLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
                else
                    PM.UI.PingLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                end
            end
            task.wait(2)
        end
    end)
    
    local function updatePlayerCount()
        local currentPlayers = #PM.Svc.Players:GetPlayers()
        local maxPlayers = PM.Svc.Players.MaxPlayers
        if PM.UI.PlayerCountLabel then
            PM.UI.PlayerCountLabel.Text = currentPlayers .. "/" .. maxPlayers
        end
    end
    
    PM.Svc.Players.PlayerAdded:Connect(updatePlayerCount)
    PM.Svc.Players.PlayerRemoving:Connect(updatePlayerCount)
    updatePlayerCount()
    
    -- Fetch servers on execute and auto-refresh every 5 minutes
    task.spawn(function()
        PM.fetchServers()
        while true do
            task.wait(300) -- 5 minutes
            PM.fetchServers()
        end
    end)
end

repeat task.wait() until LP

pcall(PM.createMainGUI)

-- Initialize nametag system
clearAllNametags()
local player = PM.Svc.Players.LocalPlayer
if player.Character then
    createNametag()
end

player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if nametagEnabled then
        createNametag()
    end
    -- Recreate other players' nametags since PlayerGui was reset
    updateOtherNametags()
end)

-- Remove nametag when player leaves
PM.Svc.Players.PlayerRemoving:Connect(function(leavingPlayer)
    removeOtherNametag(leavingPlayer.UserId)
    -- Also remove from API instantly
    task.spawn(function()
        deleteFromAPI(leavingPlayer.UserId)
    end)
end)

-- Check for other Prism users on load
task.wait(1)
updateOtherNametags()

-- Poll loop failsafe: remove nametags for players no longer in server
task.spawn(function()
    while autoSyncEnabled do
        task.wait(2) -- Check every 2 seconds (like env.lua)
        pcall(function()
            local currentPlayers = {}
            for _, plrObj in ipairs(PM.Svc.Players:GetPlayers()) do
                currentPlayers[plrObj.UserId] = true
            end
            
            for userId, tagData in pairs(otherNametags) do
                if not currentPlayers[userId] then
                    removeOtherNametag(userId)
                end
            end
        end)
    end
end)

-- Send initial data IMMEDIATELY on execute
sendNametagData()

-- Start auto-sync in background
task.spawn(startAutoSync)

-- Panel population is handled by Prism Commands.lua after it loads

-- Global terminal keybind handler (only opens, never closes like Mono's bar)
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local keybind = PM.terminalKeybind or "F6"
    if input.KeyCode.Name == keybind then
        -- Skip if panel just opened (prevents immediate close after opening)
        if PM.panelJustOpened then return end
        -- Create panel if it doesn't exist
        if not PM.UI.TerminalPanel and PM.createTerminalPanel then
            PM.createTerminalPanel()
        end
        -- Only open if not already visible (never close with keybind)
        if PM.UI.TerminalPanel and not PM.UI.TerminalPanel.Visible and PM.openTerminalPanel then
            -- Hide other panels before opening terminal (like button click does)
            if PM.isCommandsOpen then
                PM.isCommandsOpen = false
                PM.hideCommandsPanel()
            end
            if PM.isServersOpen then
                PM.isServersOpen = false
                PM.hideServersPanel()
            end
            if PM.UI.NameTagsPanel and PM.UI.NameTagsPanel.Visible then
                PM.UI.NameTagsPanel.Visible = false
            end
            if PM.isJoinOpen then
                PM.isJoinOpen = false
                PM.hideJoinPanel()
            end
            if PM.isSettingsOpen then
                PM.isSettingsOpen = false
                PM.hideSettingsPanel()
            end
            PM.openTerminalPanel()
        end
    end
end)

-- Auto execute prism on teleport (like Mono's auto load)
local queueTeleport = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or (krnl and krnl.queue_on_teleport) or (is_sirius and is_sirius.queue_on_teleport)

if queueTeleport and PM.autoExecutePrism then
    pcall(function()
        queueTeleport([[loadstring(game:HttpGet("https://prismscript.vercel.app/Prism.lua"))()]])
    end)
end

return PM
