-- Prism Nametag API Integration
-- Sends user data to the nametag website API with debugging

print("PRISM NAMETAG API LOADING")

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

print("Services loaded successfully")

-- Configuration - UPDATE THIS TO YOUR VERCEL DEPLOYMENT URL
local API_BASE_URL = "https://prismscript.vercel.app" -- Replace with actual Vercel URL
local API_ENDPOINT = API_BASE_URL .. "/api/nametags"

print("API URL configured: " .. API_ENDPOINT)

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

-- Send initial data IMMEDIATELY on execute
print("SENDING INITIAL DATA")
sendNametagData()

-- Start auto-sync in background
print("STARTING AUTO-SYNC")
task.spawn(startAutoSync)

-- Export functions for external use
print("EXPORTING FUNCTIONS")
getgenv().PrismNametagAPI = {
    sendNametagData = sendNametagData,
    getUserInfo = getUserInfo,
    setAPIUrl = function(url)
        API_BASE_URL = url
        API_ENDPOINT = url .. "/api/nametags"
        print("API URL updated to: " .. API_BASE_URL)
    end,
    setDebugMode = function(enabled)
        DEBUG_MODE = enabled
        print("Debug mode set to: " .. tostring(enabled))
    end,
    setAutoSync = function(enabled, interval)
        autoSyncEnabled = enabled
        if interval then
            autoSyncInterval = interval
        end
        print("Auto-sync " .. (enabled and "enabled" or "disabled"))
    end
}

print("Functions exported to getgenv().PrismNametagAPI")
print("Available functions: sendNametagData(), getUserInfo(), setAPIUrl(), setDebugMode(), setAutoSync()")
print("PRISM NAMETAG API INITIALIZATION COMPLETE")
