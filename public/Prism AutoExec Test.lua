-- Prism AutoExec Test
-- Standalone test file for queue_on_teleport functionality

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Get queue_on_teleport function (matching Infinite Yield pattern)
local queueteleport = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or (krnl and krnl.queue_on_teleport) or (is_sirius and is_sirius.queue_on_teleport)

print("[Prism AutoExec Test] Starting...")
print("[Prism AutoExec Test] queueteleport available:", queueteleport ~= nil)

if not queueteleport then
    warn("[Prism AutoExec Test] ERROR: queue_on_teleport not available in this executor")
    return
end

-- Setup teleport check (matching Infinite Yield pattern exactly)
local TeleportCheck = false
local KeepPrism = true -- Set to true to enable auto-exec on teleport

print("[Prism AutoExec Test] Setting up OnTeleport connection...")

if Players.LocalPlayer then
    Players.LocalPlayer.OnTeleport:Connect(function(State)
        print("[Prism AutoExec Test] OnTeleport fired! State:", State)
        print("[Prism AutoExec Test] KeepPrism:", KeepPrism, "TeleportCheck:", TeleportCheck)
        
        if KeepPrism and (not TeleportCheck) and queueteleport then
            TeleportCheck = true
            print("[Prism AutoExec Test] Queueing test load...")
            
            pcall(function()
                queueteleport([[loadstring(game:HttpGet("https://raw.githubusercontent.com/qrft/test/refs/heads/main/test"))()]])
                print("[Prism AutoExec Test] Test load queued successfully!")
            end)
        else
            print("[Prism AutoExec Test] Skipped queueing - KeepPrism:", KeepPrism, "TeleportCheck:", TeleportCheck)
        end
    end)
    print("[Prism AutoExec Test] OnTeleport connection established!")
else
    warn("[Prism AutoExec Test] ERROR: Players.LocalPlayer not found")
end

print("[Prism AutoExec Test] Ready! Rejoining server in 2 seconds to test auto-exec...")
task.wait(2)
game:GetService("TeleportService"):Teleport(game.PlaceId, Players.LocalPlayer)
