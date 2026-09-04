-- Prism Nametag API Integration
-- Sends user data to the nametag website API with debugging

print("=== PRISM NAMETAG API LOADING ===")

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

print("Services loaded successfully")

-- Configuration - UPDATE THIS TO YOUR VERCEL DEPLOYMENT URL
local API_BASE_URL = "https://prismscript.vercel.app" -- Replace with actual Vercel URL
local API_ENDPOINT = API_BASE_URL .. "/api/nametags"

print("API URL configured: " .. API_ENDPOINT)

-- Debugging flag
local DEBUG_MODE = true

-- Debug print function
local function debugPrint(message, level)
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
    print("=== GETTING USER INFO ===")
    local player = Players.LocalPlayer
    if not player then
        debugPrint("LocalPlayer not found", "ERROR")
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
    
    -- Try different request formats for different executors
    local requestTable = {
        Url = API_ENDPOINT,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = requestBody
    }
    
    -- Some executors use lowercase headers
    if not requestFunction then
        requestTable.headers = {
            ["content-type"] = "application/json"
        }
        requestTable.body = requestBody
        requestTable.url = API_ENDPOINT
        requestTable.method = "POST"
    end
    
    debugPrint("Request table: " .. HttpService:JSONEncode(requestTable), "INFO")
    
    -- Make the request
    local success, result = pcall(function()
        return requestFunction(requestTable)
    end)
    
    if not success then
        debugPrint("Request failed: " .. tostring(result), "ERROR")
        debugPrint("Make sure HTTP requests are enabled in your executor settings", "WARN")
        return false, result
    end
    
    debugPrint("Request completed successfully", "INFO")
    debugPrint("Result type: " .. type(result), "INFO")
    
    -- Handle different response formats
    local responseBody = result.Body or result.body or result
    debugPrint("Response body: " .. tostring(responseBody), "INFO")
    
    -- Parse response
    if responseBody then
        local responseSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        
        if responseSuccess then
            if responseData.success then
                debugPrint("API confirmed data received: " .. (responseData.message or "OK"), "SUCCESS")
                if responseData.blobId then
                    debugPrint("JSONBlob ID: " .. responseData.blobId, "INFO")
                end
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
    print("=== SEND NAME TAG DATA CALLED ===")
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
print("=== INITIALIZING PRISM NAMETAG API ===")
debugPrint("Prism Nametag API Integration Loaded", "SUCCESS")
debugPrint("API Base URL: " .. API_BASE_URL, "INFO")
debugPrint("Debug Mode: " .. tostring(DEBUG_MODE), "INFO")

-- Send initial data IMMEDIATELY on execute
print("=== SENDING INITIAL DATA ===")
debugPrint("Sending initial data on execute...", "INFO")
sendNametagData()

-- Start auto-sync in background
print("=== STARTING AUTO-SYNC ===")
task.spawn(startAutoSync)

-- Export functions for external use
print("=== EXPORTING FUNCTIONS ===")
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
print("=== PRISM NAMETAG API INITIALIZATION COMPLETE ===")
