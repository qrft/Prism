-- Prism Nametag API Integration
-- Sends user data to the nametag website API with debugging

print("PRISM NAMETAG API LOADING")

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

print("Services loaded successfully")

-- Configuration - UPDATE THIS TO YOUR VERCEL DEPLOYMENT URL
local API_BASE_URL = "https://prismscript.vercel.app" -- Replace with actual Vercel URL
local API_ENDPOINT = API_BASE_URL .. "/api/nametags"

print("API URL configured: " .. API_ENDPOINT)

-- Prism Color Scheme
local C = {
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

-- Nametag System
local nametagEnabled = true
local nametagGui = nil
local nametagConnection = nil
local otherNametags = {} -- Stores nametags for other players

local function createNametag()
    local player = Players.LocalPlayer
    if not player.Character then return end
    
    local head = player.Character:FindFirstChild("Head")
    if not head then return end
    
    -- Remove existing nametag
    if nametagGui then
        pcall(function() nametagGui:Destroy() end)
        nametagGui = nil
    end
    
    -- Check for and destroy any existing Prism nametags on head (from previous script runs)
    for _, child in ipairs(head:GetChildren()) do
        if child.Name == "PrismNametag" then
            pcall(function() child:Destroy() end)
            print("Destroyed duplicate nametag from previous run")
        end
    end
    
    -- Create BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PrismNametag"
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 50
    
    -- Main frame
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
    
    -- Rotating gradient border
    local stroke = Instance.new("UIStroke")
    stroke.Color = C.sep
    stroke.Thickness = 2
    stroke.Parent = frame
    
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.25, C.sep),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 20)),
        ColorSequenceKeypoint.new(0.75, C.sep),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    gradient.Parent = stroke
    
    -- Display name label
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
    
    -- Username label
    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Name = "Username"
    usernameLabel.Size = UDim2.new(1, -10, 0, 16)
    usernameLabel.Position = UDim2.new(0, 5, 0, 25)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = "@" .. player.Name
    usernameLabel.TextColor3 = C.textDim
    usernameLabel.TextSize = 11
    usernameLabel.Font = Enum.Font.Gotham
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Center
    usernameLabel.Parent = frame
    
    -- Rotating animation
    nametagConnection = RunService.Heartbeat:Connect(function(dt)
        if stroke and stroke.Parent then
            gradient.Rotation = (gradient.Rotation + 120 * dt) % 360
        end
    end)
    
    nametagGui = billboard
    pcall(function() billboard.Parent = player.Character.Head end)
    
    print("Nametag created for: " .. player.Name)
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
    print("Nametag removed")
end

local function toggleNametag()
    nametagEnabled = not nametagEnabled
    if nametagEnabled then
        createNametag()
    else
        removeNametag()
    end
    return nametagEnabled
end

-- Create nametag for another player
local function createOtherNametag(plrObj)
    if not plrObj.Character then return end
    
    local head = plrObj.Character:FindFirstChild("Head")
    if not head then return end
    
    -- Remove existing nametag for this player
    if otherNametags[plrObj.UserId] then
        if otherNametags[plrObj.UserId].connection then
            otherNametags[plrObj.UserId].connection:Disconnect()
        end
        pcall(function() otherNametags[plrObj.UserId].gui:Destroy() end)
        otherNametags[plrObj.UserId] = nil
    end
    
    -- Check for and destroy any existing Prism nametags on head (from previous script runs)
    for _, child in ipairs(head:GetChildren()) do
        if child.Name == "PrismNametag_" .. plrObj.UserId then
            pcall(function() child:Destroy() end)
            print("Destroyed duplicate nametag for " .. plrObj.Name .. " from previous run")
        end
    end
    
    -- Create BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PrismNametag_" .. plrObj.UserId
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 50
    
    -- Main frame
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
    
    -- Rotating gradient border
    local stroke = Instance.new("UIStroke")
    stroke.Color = C.sep
    stroke.Thickness = 2
    stroke.Parent = frame
    
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.25, C.sep),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 20)),
        ColorSequenceKeypoint.new(0.75, C.sep),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    gradient.Parent = stroke
    
    -- Display name label
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
    
    -- Username label
    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Name = "Username"
    usernameLabel.Size = UDim2.new(1, -10, 0, 16)
    usernameLabel.Position = UDim2.new(0, 5, 0, 25)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = "@" .. plrObj.Name
    usernameLabel.TextColor3 = C.textDim
    usernameLabel.TextSize = 11
    usernameLabel.Font = Enum.Font.Gotham
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Center
    usernameLabel.Parent = frame
    
    -- Rotating animation
    local connection = RunService.Heartbeat:Connect(function(dt)
        if stroke and stroke.Parent then
            gradient.Rotation = (gradient.Rotation + 120 * dt) % 360
        end
    end)
    
    nametagGui = billboard
    pcall(function() billboard.Parent = head end)
    
    otherNametags[plrObj.UserId] = {
        gui = billboard,
        connection = connection
    }
    
    print("Created nametag for: " .. plrObj.Name)
end

-- Remove nametag for another player
local function removeOtherNametag(userId)
    if otherNametags[userId] then
        if otherNametags[userId].connection then
            otherNametags[userId].connection:Disconnect()
        end
        pcall(function() otherNametags[userId].gui:Destroy() end)
        otherNametags[userId] = nil
    end
end

-- Read data from API
local function readFromAPI()
    print("Reading nametag data from API...")
    
    local http = game:GetService("HttpService")
    local requestFunction = request or (http and http.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        print("ERROR: No HTTP request function available")
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
        print("ERROR: API read failed - " .. tostring(result))
        return nil
    end
    
    local responseBody = result.Body or result.body or result
    
    if responseBody then
        local responseSuccess, responseData = pcall(function()
            return http:JSONDecode(responseBody)
        end)
        
        if responseSuccess and responseData.success then
            print("Successfully read API data")
            return responseData.data
        else
            print("ERROR: Failed to parse API response")
            return nil
        end
    end
    
    return nil
end

-- Update nametags for other Prism users
local function updateOtherNametags()
    local data = readFromAPI()
    if not data or not data.users then return end
    
    local myJobId = game.JobId
    local myUserId = Players.LocalPlayer.UserId
    
    -- Get current Prism users in same server
    local prismUsers = {}
    for _, user in ipairs(data.users) do
        if user.jobId == myJobId and tostring(user.userId) ~= tostring(myUserId) then
            prismUsers[user.userId] = user
        end
    end
    
    -- Create nametags for Prism users in the game
    for userId, userData in pairs(prismUsers) do
        local plrObj = Players:GetPlayerByUserId(tonumber(userId))
        if plrObj and not otherNametags[tonumber(userId)] then
            if plrObj.Character then
                createOtherNametag(plrObj)
            else
                -- Wait for character to load
                plrObj.CharacterAdded:Connect(function(char)
                    task.wait(0.5)
                    if prismUsers[userId] and not otherNametags[tonumber(userId)] then
                        createOtherNametag(plrObj)
                    end
                end)
            end
        end
    end
    
    -- Remove nametags for users no longer in Prism
    for userId, tagData in pairs(otherNametags) do
        if not prismUsers[tostring(userId)] then
            removeOtherNametag(userId)
        end
    end
end

-- Get user information
local function getUserInfo()
    print("GETTING USER INFO")
    local player = Players.LocalPlayer
    if not player then
        print("ERROR: LocalPlayer not found")
        return nil
    end
    print("LocalPlayer found: " .. player.Name)
    
    -- Try to get Job ID from game
    local jobId = game.JobId
    
    -- Try to get server ID (may be same as JobId in some games)
    local serverId = jobId
    
    -- Get user ID
    local userId = player.UserId
    local username = player.Name
    local displayName = player.DisplayName or username
    
    local userInfo = {
        username = username,
        displayName = displayName,
        userId = tostring(userId),
        jobId = jobId ~= "" and jobId or "unknown",
        serverId = serverId ~= "" and serverId or "unknown"
    }
    
    print("Collected user info:")
    print("  Username: " .. userInfo.username)
    print("  Display Name: " .. userInfo.displayName)
    print("  User ID: " .. userInfo.userId)
    print("  Job ID: " .. userInfo.jobId)
    print("  Server ID: " .. userInfo.serverId)
    
    return userInfo
end

-- Send data to API
local function sendToAPI(userInfo)
    print("Preparing to send data to API...")
    print("API Endpoint: " .. API_ENDPOINT)
    
    -- Prepare request body
    local requestBody = HttpService:JSONEncode(userInfo)
    
    print("Request body JSON: " .. requestBody)
    
    -- Check if request function is available
    local requestFunction = request or (http and http.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        print("ERROR: No HTTP request function available")
        return false, "No HTTP function available"
    end
    
    print("Using request function")
    
    -- Try different request formats for different executors
    local requestTable = {
        Url = API_ENDPOINT,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = requestBody
    }
    
    print("Request table: " .. HttpService:JSONEncode(requestTable))
    
    -- Make the request
    local success, result = pcall(function()
        return requestFunction(requestTable)
    end)
    
    if not success then
        print("ERROR: Request failed - " .. tostring(result))
        print("Make sure HTTP requests are enabled in your executor settings")
        return false, result
    end
    
    print("Request completed successfully")
    print("Result type: " .. type(result))
    
    -- Handle different response formats
    local responseBody = result.Body or result.body or result
    print("Response body: " .. tostring(responseBody))
    
    -- Parse response
    if responseBody then
        local responseSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        
        if responseSuccess then
            if responseData.success then
                print("SUCCESS: API confirmed data received - " .. (responseData.message or "OK"))
                if responseData.blobId then
                    print("JSONBlob ID: " .. responseData.blobId)
                end
                return true, responseData
            else
                print("ERROR: API returned error - " .. (responseData.error or "Unknown error"))
                return false, responseData.error
            end
        else
            print("ERROR: Failed to parse API response - " .. tostring(responseData))
            return false, "Parse error"
        end
    else
        print("ERROR: No response body received")
        return false, "No response"
    end
end

-- Delete user from API
local function deleteFromAPI()
    print("Deleting user from API...")
    print("API Endpoint: " .. API_ENDPOINT)
    
    local player = Players.LocalPlayer
    local userId = tostring(player.UserId)
    
    local requestBody = HttpService:JSONEncode({ userId = userId })
    
    local requestFunction = request or (http and http.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        print("ERROR: No HTTP request function available")
        return false
    end
    
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
    
    if success then
        local responseBody = result.Body or result.body or result
        if responseBody then
            local responseSuccess, responseData = pcall(function()
                return HttpService:JSONDecode(responseBody)
            end)
            if responseSuccess and responseData.success then
                print("SUCCESS: User removed from API")
                return true
            end
        end
    end
    
    print("ERROR: Failed to remove user from API")
    return false
end

-- Main function to send nametag data
local function sendNametagData()
    print("SEND NAME TAG DATA CALLED")
    print("Starting nametag data sync")
    
    local userInfo = getUserInfo()
    if not userInfo then
        print("ERROR: Failed to get user info")
        return
    end
    
    local success, result = sendToAPI(userInfo)
    
    if success then
        print("SUCCESS: Nametag data sync completed!")
        -- Update nametags for other Prism users after sending data
        updateOtherNametags()
    else
        print("ERROR: Nametag data sync failed - " .. tostring(result))
    end
end

-- Auto-sync on a timer (every 30 seconds)
local autoSyncEnabled = true
local autoSyncInterval = 30 -- seconds

local function startAutoSync()
    print("Auto-sync enabled (every " .. autoSyncInterval .. " seconds)")
    
    while autoSyncEnabled and RunService.Heartbeat:Wait() do
        task.wait(autoSyncInterval)
        if autoSyncEnabled then
            print("Auto-sync triggered")
            sendNametagData()
        end
    end
end

-- Initialize
print("INITIALIZING PRISM NAMETAG API")
print("Prism Nametag API Integration Loaded")
print("API Base URL: " .. API_BASE_URL)

-- Create nametag on load
print("CREATING NAMETAG")
local player = Players.LocalPlayer
if player.Character then
    createNametag()
end

-- Handle character respawn
player.CharacterAdded:Connect(function(char)
    print("Character added, recreating nametag")
    task.wait(0.5)
    if nametagEnabled then
        createNametag()
    end
end)

-- Check for other Prism users on load
print("CHECKING FOR OTHER PRISM USERS")
task.wait(1)
updateOtherNametags()

-- Send initial data IMMEDIATELY on execute
print("SENDING INITIAL DATA")
sendNametagData()

-- Start auto-sync in background
print("STARTING AUTO-SYNC")
task.spawn(startAutoSync)

-- Handle script unload (when user runs unload command)
local scriptUnloading = false
task.spawn(function()
    while not scriptUnloading do
        task.wait(1)
        -- Check if script is being unloaded (common executor pattern)
        if not script or not script.Parent then
            scriptUnloading = true
            print("Script unload detected, removing from API...")
            deleteFromAPI()
            break
        end
    end
end)

print("PRISM NAMETAG API INITIALIZATION COMPLETE")
