-- Prism Nametag API Integration
-- Sends user data to the nametag website API with debugging

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuration - UPDATE THIS TO YOUR VERCEL DEPLOYMENT URL
local API_BASE_URL = "https://your-vercel-app.vercel.app" -- Replace with actual Vercel URL
local API_ENDPOINT = API_BASE_URL .. "/api/nametags"

-- Debugging flag
local DEBUG_MODE = true

-- Debug print function
local function debugPrint(message, level)
    if not DEBUG_MODE then return end
    
    local prefix = "[Prism Nametag API]"
    local timestamp = os.date("%H:%M:%S")
    
    if level == "SUCCESS" then
        warn(prefix .. " [" .. timestamp .. "] ✓ " .. message)
    elseif level == "ERROR" then
        warn(prefix .. " [" .. timestamp .. "] ✗ " .. message)
    elseif level == "WARN" then
        warn(prefix .. " [" .. timestamp .. "] ⚠ " .. message)
    else
        print(prefix .. " [" .. timestamp .. "] " .. message)
    end
end

-- Get user information
local function getUserInfo()
    local player = Players.LocalPlayer
    if not player then
        debugPrint("LocalPlayer not found", "ERROR")
        return nil
    end
    
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
    
    debugPrint("Collected user info:", "INFO")
    debugPrint("  Username: " .. userInfo.username, "INFO")
    debugPrint("  Display Name: " .. userInfo.displayName, "INFO")
    debugPrint("  User ID: " .. userInfo.userId, "INFO")
    debugPrint("  Job ID: " .. userInfo.jobId, "INFO")
    debugPrint("  Server ID: " .. userInfo.serverId, "INFO")
    
    return userInfo
end

-- Send data to API
local function sendToAPI(userInfo)
    debugPrint("Preparing to send data to API...", "INFO")
    debugPrint("API Endpoint: " .. API_ENDPOINT, "INFO")
    
    -- Prepare request body
    local requestBody = HttpService:JSONEncode(userInfo)
    
    debugPrint("Request body JSON: " .. requestBody, "INFO")
    
    -- Check if request function is available
    local requestFunction = request or (http and http.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        debugPrint("No HTTP request function available (request, http.request, http_request, fluxus.request)", "ERROR")
        return false, "No HTTP function available"
    end
    
    debugPrint("Using request function: " .. tostring(requestFunction), "INFO")
    
    -- Make the request
    local success, result = pcall(function()
        return requestFunction({
            Url = API_ENDPOINT,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = requestBody
        })
    end)
    
    if not success then
        debugPrint("Request failed: " .. tostring(result), "ERROR")
        return false, result
    end
    
    debugPrint("Request completed successfully", "INFO")
    
    -- Parse response
    if result and result.Body then
        debugPrint("Response body: " .. result.Body, "INFO")
        
        local responseSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(result.Body)
        end)
        
        if responseSuccess then
            if responseData.success then
                debugPrint("API confirmed data received: " .. (responseData.message or "OK"), "SUCCESS")
                return true, responseData
            else
                debugPrint("API returned error: " .. (responseData.error or "Unknown error"), "ERROR")
                return false, responseData.error
            end
        else
            debugPrint("Failed to parse API response: " .. tostring(responseData), "ERROR")
            return false, "Parse error"
        end
    else
        debugPrint("No response body received", "ERROR")
        return false, "No response"
    end
end

-- Main function to send nametag data
local function sendNametagData()
    debugPrint("=" .. string.rep("=", 50), "INFO")
    debugPrint("Starting nametag data sync", "INFO")
    
    local userInfo = getUserInfo()
    if not userInfo then
        debugPrint("Failed to get user info", "ERROR")
        return
    end
    
    local success, result = sendToAPI(userInfo)
    
    if success then
        debugPrint("Nametag data sync completed successfully!", "SUCCESS")
    else
        debugPrint("Nametag data sync failed: " .. tostring(result), "ERROR")
    end
    
    debugPrint("=" .. string.rep("=", 50), "INFO")
end

-- Auto-sync on a timer (every 30 seconds)
local autoSyncEnabled = true
local autoSyncInterval = 30 -- seconds

local function startAutoSync()
    debugPrint("Auto-sync enabled (every " .. autoSyncInterval .. " seconds)", "INFO")
    
    while autoSyncEnabled and RunService.Heartbeat:Wait() do
        task.wait(autoSyncInterval)
        if autoSyncEnabled then
            debugPrint("Auto-sync triggered", "INFO")
            sendNametagData()
        end
    end
end

-- Initialize
debugPrint("Prism Nametag API Integration Loaded", "SUCCESS")
debugPrint("API Base URL: " .. API_BASE_URL, "INFO")

-- Send initial data
task.delay(2, function()
    sendNametagData()
end)

-- Start auto-sync in background
task.spawn(startAutoSync)

-- Export functions for external use
getgenv().PrismNametagAPI = {
    sendNametagData = sendNametagData,
    getUserInfo = getUserInfo,
    setAPIUrl = function(url)
        API_BASE_URL = url
        API_ENDPOINT = url .. "/api/nametags"
        debugPrint("API URL updated to: " .. API_BASE_URL, "INFO")
    end,
    setDebugMode = function(enabled)
        DEBUG_MODE = enabled
        debugPrint("Debug mode set to: " .. tostring(enabled), "INFO")
    end,
    setAutoSync = function(enabled, interval)
        autoSyncEnabled = enabled
        if interval then
            autoSyncInterval = interval
        end
        debugPrint("Auto-sync " .. (enabled and "enabled" or "disabled"), "INFO")
    end
}

debugPrint("Functions exported to getgenv().PrismNametagAPI", "INFO")
debugPrint("Available functions: sendNametagData(), getUserInfo(), setAPIUrl(), setDebugMode(), setAutoSync()", "INFO")
