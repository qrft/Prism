-- VC Icons - Standalone VCBypasser Player Overlays
-- Creates mute buttons and talking indicators on other players

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- SpeakerLight icons for talking detection
local SPEAKER_MUTED = "rbxasset://textures/ui/VoiceChat/SpeakerLight/Muted.png"
local SPEAKER_UNMUTED_LEVELS = {
    "rbxasset://textures/ui/VoiceChat/SpeakerLight/Unmuted0.png",
    "rbxasset://textures/ui/VoiceChat/SpeakerLight/Unmuted20.png",
    "rbxasset://textures/ui/VoiceChat/SpeakerLight/Unmuted40.png",
    "rbxasset://textures/ui/VoiceChat/SpeakerLight/Unmuted60.png",
    "rbxasset://textures/ui/VoiceChat/SpeakerLight/Unmuted80.png",
    "rbxasset://textures/ui/VoiceChat/SpeakerLight/Unmuted100.png"
}

-- State management
local VCIcons = {
    active = false,
    talkingDetectors = {}, -- [userId] = {analyzer, wire}
    talkingStates = {}, -- [userId] = bool
    playerOverlays = {}, -- [userId] = BillboardGui
    playerAddedConn = nil,
    playerRemovingConn = nil
}

-- Helper function to find AudioDeviceInput
local function getPlayerAudioInput(plr)
    local adi = nil
    pcall(function()
        adi = plr:FindFirstChildOfClass("AudioDeviceInput")
    end)
    if not adi then
        pcall(function()
            for _,v in ipairs(plr:GetDescendants()) do
                if v.ClassName == "AudioDeviceInput" then
                    adi = v
                    break
                end
            end
        end)
    end
    return adi
end

-- Helper function to wait for character to be ready
local function waitForCharacterReady(plr)
    if plr.Character then
        local char = plr.Character
        if char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") then
            return
        end
    end
    if not plr.Character then
        plr.CharacterAdded:Wait()
    end
    repeat task.wait() until plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Head")
end

-- Setup talking detection for a player
local function setupTalkingDetection(plr)
    if VCIcons.talkingDetectors[plr.UserId] then return end

    local adi = getPlayerAudioInput(plr)
    if not adi then return end

    local char = plr.Character
    if not char then return end

    -- Create AudioAnalyzer and Wire
    local analyzer = Instance.new("AudioAnalyzer")
    analyzer.Name = plr.Name .. "_TalkingAnalyzer"
    analyzer.Parent = char

    local wire = Instance.new("Wire")
    wire.Name = plr.Name .. "_TalkingWire"
    wire.SourceInstance = adi
    wire.TargetInstance = analyzer
    wire.Parent = char

    VCIcons.talkingDetectors[plr.UserId] = { analyzer = analyzer, wire = wire }
    VCIcons.talkingStates[plr.UserId] = false

    -- Monitor talking state
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not analyzer.Parent then
            if conn then conn:Disconnect() end
            return
        end
        local isTalking = analyzer.RmsLevel > 0.005
        VCIcons.talkingStates[plr.UserId] = isTalking
    end)
end

-- Cleanup talking detection for a player
local function cleanupTalkingDetection(plr)
    if VCIcons.talkingDetectors[plr.UserId] then
        pcall(function() VCIcons.talkingDetectors[plr.UserId].analyzer:Destroy() end)
        pcall(function() VCIcons.talkingDetectors[plr.UserId].wire:Destroy() end)
        VCIcons.talkingDetectors[plr.UserId] = nil
    end
    VCIcons.talkingStates[plr.UserId] = nil
end

-- Create player overlay with mute button and talking indicator
local function createPlayerOverlay(plr)
    if VCIcons.playerOverlays[plr.UserId] then return end

    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local bill = Instance.new("BillboardGui")
    bill.Name = plr.Name .. "_VCIconOverlay"
    bill.Active = true
    bill.AlwaysOnTop = true
    bill.Size = UDim2.fromOffset(40, 40)
    bill.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    bill.Adornee = head
    bill.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    bill.MaxDistance = 100

    -- Parent to CoreGui if possible, otherwise PlayerGui
    local CoreGui = game:GetService("CoreGui")
    if gethui then
        bill.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(bill)
        bill.Parent = CoreGui
    else
        bill.Parent = CoreGui
    end

    VCIcons.playerOverlays[plr.UserId] = bill

    -- Background frame
    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.3
    bg.Parent = bill
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = bg

    -- Mute button (main icon, shows talking animation + mute state)
    local muteBtn = Instance.new("ImageButton")
    muteBtn.Name = "MuteButton"
    muteBtn.Size = UDim2.fromScale(0.8, 0.8)
    muteBtn.Position = UDim2.fromScale(0.1, 0.1)
    muteBtn.BackgroundTransparency = 1
    muteBtn.Image = SPEAKER_UNMUTED_LEVELS[1]
    muteBtn.Parent = bill

    -- Mute button click
    muteBtn.MouseButton1Click:Connect(function()
        local adi = getPlayerAudioInput(plr)
        if adi then
            local isMuted = not adi.Muted
            pcall(function()
                adi.Muted = isMuted
            end)
        end
    end)

    -- Heartbeat for talking animation and updates
    local lastUpdate = 0
    local levelIndex = 1

    -- Handle character respawn - recreate overlay and talking detection
    local charAddedConn
    charAddedConn = plr.CharacterAdded:Connect(function(newChar)
        -- Cleanup old overlay and talking detection
        removePlayerOverlay(plr)
        -- Wait for character to be ready
        waitForCharacterReady(plr)
        -- Recreate after character loads
        if VCIcons.active then
            task.spawn(function()
                setupTalkingDetection(plr)
                createPlayerOverlay(plr)
            end)
        end
    end)

    RunService.Heartbeat:Connect(function()
        if not bill.Parent then
            if charAddedConn then charAddedConn:Disconnect() end
            return
        end

        -- Update adornee
        if plr.Character and plr.Character:FindFirstChild("Head") then
            bill.Adornee = plr.Character.Head
        end

        -- Distance check - only show within 50 studs
        local visible = false
        if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (LP.Character.HumanoidRootPart.Position - plr.Character.HumanoidRootPart.Position).Magnitude
            visible = dist <= 50
        end
        bill.Enabled = visible

        -- Update mute state
        local adi = getPlayerAudioInput(plr)
        local myMuted = false
        local selfMuted = false
        if adi then
            myMuted = adi.Muted
            selfMuted = not adi.Active
        end

        -- Update talking animation
        local isTalking = VCIcons.talkingStates[plr.UserId] or false
        if isTalking and not myMuted and not selfMuted then
            -- Cycle through volume levels randomly
            local now = tick()
            if now - lastUpdate > 0.1 then
                levelIndex = math.random(1, #SPEAKER_UNMUTED_LEVELS)
                muteBtn.Image = SPEAKER_UNMUTED_LEVELS[levelIndex]
                muteBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
                lastUpdate = now
            end
        else
            -- Show different colors based on mute state
            if myMuted then
                -- Muted by you - light gray
                muteBtn.Image = SPEAKER_MUTED
                muteBtn.ImageColor3 = Color3.fromRGB(180, 180, 180)
            elseif selfMuted then
                -- Self-muted - white
                muteBtn.Image = SPEAKER_MUTED
                muteBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
            else
                -- Not muted - normal
                muteBtn.Image = SPEAKER_UNMUTED_LEVELS[1]
                muteBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
    end)
end

-- Remove player overlay
local function removePlayerOverlay(plr)
    if VCIcons.playerOverlays[plr.UserId] then
        pcall(function() VCIcons.playerOverlays[plr.UserId]:Destroy() end)
        VCIcons.playerOverlays[plr.UserId] = nil
    end
    cleanupTalkingDetection(plr)
end

-- Toggle VC Icons
local function toggleVCIcons()
    VCIcons.active = not VCIcons.active

    if VCIcons.active then
        -- Setup for all current players
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                task.spawn(function()
                    waitForCharacterReady(p)
                    setupTalkingDetection(p)
                    createPlayerOverlay(p)
                end)
            end
        end

        -- Setup for new players
        VCIcons.playerAddedConn = Players.PlayerAdded:Connect(function(p)
            if p ~= LP then
                task.spawn(function()
                    waitForCharacterReady(p)
                    setupTalkingDetection(p)
                    createPlayerOverlay(p)
                end)
            end
        end)

        -- Cleanup on leave
        VCIcons.playerRemovingConn = Players.PlayerRemoving:Connect(function(p)
            removePlayerOverlay(p)
        end)

        print("VC Icons: Enabled")
    else
        -- Cleanup
        if VCIcons.playerAddedConn then
            VCIcons.playerAddedConn:Disconnect()
            VCIcons.playerAddedConn = nil
        end
        if VCIcons.playerRemovingConn then
            VCIcons.playerRemovingConn:Disconnect()
            VCIcons.playerRemovingConn = nil
        end

        -- Remove all overlays
        for _, p in ipairs(Players:GetPlayers()) do
            removePlayerOverlay(p)
        end

        print("VC Icons: Disabled")
    end

    return VCIcons.active
end

-- Auto-enable on load
task.wait(1)
toggleVCIcons()

-- Expose toggle function globally for manual control
_G.toggleVCIcons = toggleVCIcons

print("VC Icons loaded and auto-enabled")
print("To manually toggle, call: _G.toggleVCIcons()")
