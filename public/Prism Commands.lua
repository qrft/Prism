--[[ missing

    rewind
    invisibility
    headsit player
    backpack player
    face bang player
    doggy player
    drag player
    bang player
    stand player
    view player friends
    view player inventory
    animation packs
    animation replacer
    animation cloning
    shaders (with presets / time of day control / all axons shader controls)
    reanim (maybe)
    anti admin
    anti headsit / facebang / etc
    nametags
    join other prism users
    better vcbypasser

]]
-- Wait for PrismMain to be initialized by Main.lua
repeat task.wait() until getgenv().PrismMain
local PM = getgenv().PrismMain

PM.Commands = PM.Commands or {}

local function registerCommand(name, desc, aliases, execute, excludeFromAutoExec)
    PM.Commands[name:lower()] = {
        name = name,
        desc = desc,
        aliases = aliases or {},
        execute = execute,
        excludeFromAutoExec = excludeFromAutoExec or false,
    }
end

-- Helper function to find AudioDeviceInput (from env.lua)
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

-- Helper function to wait for character to be ready
local function waitForCharacterReady(plr)
    if plr.Character then
        local char = plr.Character
        -- Check if character is already ready
        if char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") then
            return
        end
    end
    -- Wait for character to load and become ready
    if not plr.Character then
        plr.CharacterAdded:Wait()
    end
    repeat task.wait() until plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Head")
end

-- Setup talking detection for a player
local function setupTalkingDetection(plr)
    if PM.VCBypasser.talkingDetectors[plr.UserId] then return end

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

    PM.VCBypasser.talkingDetectors[plr.UserId] = { analyzer = analyzer, wire = wire }
    PM.VCBypasser.talkingStates[plr.UserId] = false

    -- Monitor talking state
    local conn
    conn = game:GetService("RunService").Heartbeat:Connect(function()
        if not analyzer.Parent then
            if conn then conn:Disconnect() end
            return
        end
        local isTalking = analyzer.RmsLevel > 0.005
        PM.VCBypasser.talkingStates[plr.UserId] = isTalking
    end)
end

-- Cleanup talking detection for a player
local function cleanupTalkingDetection(plr)
    if PM.VCBypasser.talkingDetectors[plr.UserId] then
        pcall(function() PM.VCBypasser.talkingDetectors[plr.UserId].analyzer:Destroy() end)
        pcall(function() PM.VCBypasser.talkingDetectors[plr.UserId].wire:Destroy() end)
        PM.VCBypasser.talkingDetectors[plr.UserId] = nil
    end
    PM.VCBypasser.talkingStates[plr.UserId] = nil
end

-- Create player overlay with mute button and talking indicator
local function createPlayerOverlay(plr)
    if PM.VCBypasser.playerOverlays[plr.UserId] then return end

    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local bill = Instance.new("BillboardGui")
    bill.Name = plr.Name .. "_VCBOverlay"
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

    PM.VCBypasser.playerOverlays[plr.UserId] = bill

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
                -- Don't touch adi.Active - that's the player's self-mute state
            end)
            PM.MutedPlayers[plr.UserId] = adi
        end
    end)

    -- Heartbeat for talking animation and updates
    local RunService = game:GetService("RunService")
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
        setupTalkingDetection(plr)
        createPlayerOverlay(plr)
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

        -- Distance check - only show within 100 studs
        local LP = game:GetService("Players").LocalPlayer
        local visible = false
        if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (LP.Character.HumanoidRootPart.Position - plr.Character.HumanoidRootPart.Position).Magnitude
            visible = dist <= 100
        end
        bill.Enabled = visible

        -- Update mute state - check both Muted and Active properties
        local adi = getPlayerAudioInput(plr)
        local myMuted = false
        local selfMuted = false
        if adi then
            myMuted = adi.Muted
            selfMuted = not adi.Active
        end

        -- Update talking animation
        local isTalking = PM.VCBypasser.talkingStates[plr.UserId] or false
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
                -- Self-muted - old color (white)
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
    if PM.VCBypasser.playerOverlays[plr.UserId] then
        pcall(function() PM.VCBypasser.playerOverlays[plr.UserId]:Destroy() end)
        PM.VCBypasser.playerOverlays[plr.UserId] = nil
    end
    cleanupTalkingDetection(plr)
end

-- ========== CHAT COMMAND HANDLING ==========

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local ChatPrefix = "'"

-- Hook into chat
local function onChat(msg)
    if not msg:sub(1, 1) == ChatPrefix then return end
    
    -- Remove prefix and parse command
    local input = msg:sub(2):gsub("^%s+", "")
    if input == "" then return end
    
    local parts = {}
    for part in input:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    local cmdName = parts[1]:lower()
    table.remove(parts, 1)
    
    -- Find and execute command
    local cmd = PM.Commands[cmdName]
    if not cmd then
        -- Check aliases
        for _, c in pairs(PM.Commands) do
            for _, alias in ipairs(c.aliases) do
                if alias:lower() == cmdName then
                    cmd = c
                    break
                end
            end
            if cmd then break end
        end
    end
    
    if cmd then
        pcall(function() cmd.execute(parts) end)
    end
end

-- Connect to chat
if LP then
    LP.Chatted:Connect(onChat)
end

-- ========== BUILT-IN COMMANDS ==========

local function cleanupPrism()
    -- Clean up Main GUI (from Prism Main.lua)
    if PM.UI and PM.UI.Gui then
        pcall(function() PM.UI.Gui:Destroy() end)
        PM.UI.Gui = nil
    end
    
    -- Disconnect all PM-level connections
    local topLevelConns = {
        "HideAllPlayerAddedConn",
        "MuteAllPlayerAddedConn",
        "JerkRespawnConn",
        "HitlerSaluteRespawnConn"
    }
    for _, connName in ipairs(topLevelConns) do
        if PM[connName] then
            pcall(function() PM[connName]:Disconnect() end)
            PM[connName] = nil
        end
    end
    
    -- Unhide all hidden players
    for uid, data in pairs(PM.HiddenPlayers or {}) do
        if data.connection then pcall(function() data.connection:Disconnect() end) end
        if data.audioDevice then pcall(function() data.audioDevice.Muted = false end) end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        local adi = getPlayerAudioInput(p)
        if adi then
            pcall(function() adi.Muted = false end)
        end
    end
    PM.HiddenPlayers = {}
    
    -- Unmute all muted players
    for uid, data in pairs(PM.MutedPlayers or {}) do
        if data.connection then pcall(function() data.connection:Disconnect() end) end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        local adi = getPlayerAudioInput(p)
        if adi then
            pcall(function() adi.Muted = false end)
        end
    end
    PM.MutedPlayers = {}
    
    -- Clear state flags
    PM.JerkActive = false
    PM.HitlerSaluteActive = false
    
    -- Cleanup Teleport Tool
    if PM.TpToolConn then pcall(function() PM.TpToolConn:Disconnect() end); PM.TpToolConn = nil end
    if PM.TpWatchConn1 then pcall(function() PM.TpWatchConn1:Disconnect() end); PM.TpWatchConn1 = nil end
    if PM.TpWatchConn2 then pcall(function() PM.TpWatchConn2:Disconnect() end); PM.TpWatchConn2 = nil end
    PM.TpToolActive = false
    
    -- Cleanup Jerk Tool
    local jerk = LP.Backpack:FindFirstChild("Jerk")
    if jerk then pcall(function() jerk:Destroy() end) end
    local charJerk = LP.Character and LP.Character:FindFirstChild("Jerk")
    if charJerk then pcall(function() charJerk:Destroy() end) end

    -- Cleanup Hitler Salute Tool
    if PM.HitlerSaluteRespawnConn then pcall(function() PM.HitlerSaluteRespawnConn:Disconnect() end); PM.HitlerSaluteRespawnConn = nil end
    local salute = LP.Backpack:FindFirstChild("Hitler Salute")
    if salute then pcall(function() salute:Destroy() end) end
    local charSalute = LP.Character and LP.Character:FindFirstChild("Hitler Salute")
    if charSalute then pcall(function() charSalute:Destroy() end) end
    
    -- Cleanup Walk On Air
    if PM.WOA then
        if PM.WOA.renderConn then pcall(function() PM.WOA.renderConn:Disconnect() end) end
        if PM.WOA.platform then pcall(function() PM.WOA.platform:Destroy() end) end
        if PM.WOA.Gui then pcall(function() PM.WOA.Gui:Destroy() end) end
        PM.WOA = nil
    end

    -- Cleanup Respawn hooks
    if respawnCharAddedConn then pcall(function() respawnCharAddedConn:Disconnect() end) end
    if respawnDiedConn then pcall(function() respawnDiedConn:Disconnect() end) end
    _respawnEnabled = false
    _respawnLastCFrame = nil
    PM.Respawn.enabled = false
    PM.Respawn.lastCFrame = nil
    
    -- Cleanup Anti All
    if PM.Anti then
        for _, conn in pairs(PM.Anti.connections or {}) do
            pcall(function() conn:Disconnect() end)
        end
        PM.Anti.connections = {}
        PM.Anti.afk = false
        PM.Anti.sit = false
        PM.Anti.ragdoll = false
        PM.Anti.void = false
        PM.Anti.paused = false
        if PM.Anti.origVoidY ~= nil then
            pcall(function() workspace.FallenPartsDestroyHeight = PM.Anti.origVoidY end)
            PM.Anti.origVoidY = nil
        end
    end
    
    -- Cleanup Infinite Baseplate
    if PM.BP then
        PM.BP.active = false
        if PM.BP.connection then pcall(function() PM.BP.connection:Disconnect() end) end
    end
    
    -- Cleanup Hamster Ball
    if PM.HB then
        PM.HB.active = false
        if PM.HB.renderConn then pcall(function() PM.HB.renderConn:Disconnect() end) end
        if PM.HB.jumpConn then pcall(function() PM.HB.jumpConn:Disconnect() end) end
    end
    
    -- Cleanup AutoClicker
    if PM.AC then
        PM.AC.active = false
        if PM.AC.keyConnection then pcall(function() PM.AC.keyConnection:Disconnect() end) end
    end
    
    -- Cleanup Noclip
    if PM.Noclip then
        PM.Noclip.active = false
        if PM.Noclip.connection then pcall(function() PM.Noclip.connection:Disconnect() end) end
        if PM.Noclip.keyConnection then pcall(function() PM.Noclip.keyConnection:Disconnect() end) end
        local snapshot = PM.Noclip.snapshot or {}
        local char = LP.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        if snapshot[part] ~= nil then
                            part.CanCollide = snapshot[part]
                        end
                    end)
                end
            end
        end
        PM.Noclip.snapshot = {}
    end
    
    -- Cleanup Move While Emoting
    if PM.Emotes then
        if PM.Emotes.mwePriConn then PM.Emotes.mwePriConn:Disconnect(); PM.Emotes.mwePriConn = nil end
        if PM.Emotes.mweWalkConn then PM.Emotes.mweWalkConn:Disconnect(); PM.Emotes.mweWalkConn = nil end
        if PM.Emotes.currentEmoteTrack then pcall(function() PM.Emotes.currentEmoteTrack:Stop() end); PM.Emotes.currentEmoteTrack = nil end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then
            local char = plr.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    for _, track in pairs(hum:GetPlayingAnimationTracks()) do
                        if track.Priority == Enum.AnimationPriority.Action then
                            pcall(function() track:Stop() end)
                        end
                    end
                end
            end
        end
    end
    
    -- Cleanup View
    if PM.View then
        if PM.View.connection then PM.View.connection:Disconnect(); PM.View.connection = nil end
        if PM.View.leavingConnection then PM.View.leavingConnection:Disconnect(); PM.View.leavingConnection = nil end
        PM.View.viewing = false
        PM.View.target = nil
        local camera = workspace.CurrentCamera
        local char = LP.Character
        if char and char:FindFirstChild("Humanoid") then
            camera.CameraSubject = char.Humanoid
        end
    end
    
    -- Clear state objects
    PM.Fly = nil
    PM.Jump = nil
    
    -- Reset walkspeed to game default
    local char = game:GetService("Players").LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local defaultWS = humanoid:GetAttribute("OriginalWalkSpeed") or 16
            humanoid.WalkSpeed = defaultWS
        end
    end
    
    -- Cleanup CoreGui GUIs
    local CoreGui = game:GetService("CoreGui")
    for _, obj in ipairs(CoreGui:GetChildren()) do
        if obj.Name:find("Prism") and obj:IsA("ScreenGui") then
            pcall(function() obj:Destroy() end)
        end
    end
    
    -- Cleanup PlayerGui GUIs
    for _, obj in ipairs(LP.PlayerGui:GetChildren()) do
        if obj.Name:find("Prism") and obj:IsA("ScreenGui") then
            pcall(function() obj:Destroy() end)
        end
    end
    
    -- Cleanup hidden GUIs (gethui)
    if gethui then
        local hiddenGui = gethui()
        if hiddenGui then
            for _, obj in ipairs(hiddenGui:GetChildren()) do
                if obj.Name:find("Prism") and obj:IsA("ScreenGui") then
                    pcall(function() obj:Destroy() end)
                end
            end
        end
    end
    
    -- Cleanup workspace objects
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name:find("Prism") then
            pcall(function() obj:Destroy() end)
        end
    end
    
    -- Cleanup Backpack tools
    for _, obj in ipairs(LP.Backpack:GetChildren()) do
        if obj.Name:find("Prism") or obj.Name == "Teleport Tool" or obj.Name == "Jerk" or obj.Name == "Hitler Salute" then
            pcall(function() obj:Destroy() end)
        end
    end

    -- Cleanup Character tools
    if LP.Character then
        for _, obj in ipairs(LP.Character:GetChildren()) do
            if obj.Name:find("Prism") or obj.Name == "Teleport Tool" or obj.Name == "Jerk" or obj.Name == "Hitler Salute" then
                pcall(function() obj:Destroy() end)
            end
        end
    end
end

local function FindPrismGUI(name)
    local cg = game:GetService("CoreGui")
    local g = cg:FindFirstChild(name)
    if g then return g end
    local lp = game:GetService("Players").LocalPlayer
    if lp and lp:FindFirstChild("PlayerGui") then
        g = lp.PlayerGui:FindFirstChild(name)
        if g then return g end
    end
    if get_hidden_gui or gethui then
        g = (get_hidden_gui or gethui)():FindFirstChild(name)
        if g then return g end
    end
    return nil
end

registerCommand("destroy", "Destroy Prism", {}, function(args)
    cleanupPrism()
    getgenv().PrismMain = nil
end, true)

registerCommand("reload", "Reload Prism script", {}, function(args)
    cleanupPrism()
    getgenv().PrismMain = nil
    task.wait(0.5)
    loadstring(game:HttpGet("https://prismscript.vercel.app/Prism.lua"))()
end, true)

registerCommand("rejoin", "Rejoin current server", {}, function(args)
    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
end, true)

registerCommand("serverhopmost", "Join server with most players", {}, function(args)
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"))
    end)
    if ok and result and result.data then
        local best = nil
        for _, server in ipairs(result.data) do
            local playing = server.playing or 0
            local maxP = server.maxPlayers or 0
            if server.id ~= game.JobId and maxP > 0 and playing < maxP then
                if not best or playing > (best.playing or 0) then
                    best = server
                end
            end
        end
        if best then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, best.id, LP)
        end
    end
end, true)

registerCommand("serverhopping", "Join server with lowest ping", {}, function(args)
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if ok and result and result.data then
        local best = nil
        for _, server in ipairs(result.data) do
            local playing = server.playing or 0
            local maxP = server.maxPlayers or 0
            if server.id ~= game.JobId and maxP > 0 and playing < maxP then
                if not best or (server.ping or math.huge) < (best.ping or math.huge) then
                    best = server
                end
            end
        end
        if best then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, best.id, LP)
        end
    end
end, true)

registerCommand("serverhopfew", "Join server with fewest players", {}, function(args)
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if ok and result and result.data then
        local best = nil
        for _, server in ipairs(result.data) do
            local playing = server.playing or 0
            local maxP = server.maxPlayers or 0
            if server.id ~= game.JobId and maxP > 0 and playing < maxP then
                if not best or playing < (best.playing or math.huge) then
                    best = server
                end
            end
        end
        if best then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, best.id, LP)
        end
    end
end, true)

registerCommand("serverhopany", "Join any random server", {}, function(args)
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if ok and result and result.data then
        local servers = {}
        for _, server in ipairs(result.data) do
            if server.id ~= game.JobId then
                table.insert(servers, server)
            end
        end
        if #servers > 0 then
            local randomServer = servers[math.random(1, #servers)]
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, randomServer.id, LP)
        end
    end
end, true)

-- VCBypasser state management
PM.VCBypasser = {
    active = false,
    selfMuted = false,
    buttonConn = nil,
    mouseEnterConn = nil,
    mouseLeaveConn = nil,
    sizeMonitorConn = nil,
    propertySignalConn = nil,
    -- Muting others
    playerOverlays = {}, -- [userId] = BillboardGui
    talkingDetectors = {}, -- [userId] = {AudioAnalyzer, Wire}
    talkingStates = {}, -- [userId] = bool
    playerAddedConn = nil,
    playerRemovingConn = nil
}

local function getMicPath()
    local CoreGui = game:GetService("CoreGui")
    local TopBarApp = CoreGui:FindFirstChild("TopBarApp")
    if not TopBarApp then return nil end
    
    local TopBarApp2 = TopBarApp:FindFirstChild("TopBarApp")
    if not TopBarApp2 then return nil end
    
    local UnibarLeftFrame = TopBarApp2:FindFirstChild("UnibarLeftFrame")
    if not UnibarLeftFrame then return nil end
    
    local UnibarMenu = UnibarLeftFrame:FindFirstChild("UnibarMenu")
    if not UnibarMenu then return nil end
    
    local frame2 = UnibarMenu:FindFirstChild("2")
    if not frame2 then return nil end
    
    local frame3 = frame2:FindFirstChild("3")
    if not frame3 then return nil end
    
    return frame2, frame3
end

local function createMuteButton()
    local frame2, frame3 = getMicPath()
    if not frame2 or not frame3 then return false end
    
    -- Resize UnibarMenu - 2
    frame2.Size = UDim2.new(0, 140, 0, 44)
    
    -- Remove existing button if present
    local existing = frame3:FindFirstChild("toggle_mic_mute")
    if existing then
        existing:Destroy()
    end
    
    -- Create toggle_mic_mute
    local toggleMute = Instance.new("Frame")
    toggleMute.Name = "toggle_mic_mute"
    toggleMute.Size = UDim2.new(0, 44, 0, 44)
    toggleMute.Position = UDim2.new(0, 92, 0, 0)
    toggleMute.BackgroundColor3 = Color3.fromRGB(163, 162, 165)
    toggleMute.BackgroundTransparency = 1
    toggleMute.Parent = frame3
    
    -- Highlighter
    local highlighter = Instance.new("Frame")
    highlighter.Name = "Highlighter"
    highlighter.Size = UDim2.new(0, 36, 0, 36)
    highlighter.Position = UDim2.new(0.5, 0, 0.5, 0)
    highlighter.AnchorPoint = Vector2.new(0.5, 0.5)
    highlighter.BackgroundColor3 = Color3.fromRGB(208, 217, 251)
    highlighter.BackgroundTransparency = 0.92
    highlighter.Visible = false
    highlighter.Parent = toggleMute
    
    local corner1 = Instance.new("UICorner")
    corner1.CornerRadius = UDim.new(1, 0)
    corner1.Parent = highlighter
    
    -- IntegrationIconFrame
    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "IntegrationIconFrame"
    iconFrame.Size = UDim2.new(1, 0, 1, 0)
    iconFrame.BackgroundTransparency = 1
    iconFrame.Parent = toggleMute
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Horizontal
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    listLayout.SortOrder = Enum.SortOrder.Name
    listLayout.Parent = iconFrame
    
    -- IntegrationIcon
    local icon = Instance.new("Frame")
    icon.Name = "IntegrationIcon"
    icon.Size = UDim2.new(0, 36, 0, 36)
    icon.BackgroundColor3 = Color3.fromRGB(163, 162, 165)
    icon.BackgroundTransparency = 1
    icon.Parent = iconFrame
    
    -- Mic image
    local micImage = Instance.new("ImageLabel")
    micImage.Name = "MicImage"
    micImage.Size = UDim2.new(1, 0, 1, 0)
    micImage.BackgroundTransparency = 1
    micImage.Image = "rbxasset://textures/ui/VoiceChat/MicLight/Unmuted0.png"
    micImage.Parent = icon
    
    -- RedVoiceDot
    local redDot = Instance.new("Frame")
    redDot.Name = "RedVoiceDot"
    redDot.Size = UDim2.new(0, 4, 0, 4)
    redDot.Position = UDim2.new(1, -7, 1, -7)
    redDot.BackgroundColor3 = Color3.fromRGB(234, 51, 35)
    redDot.Visible = true
    redDot.Parent = icon
    
    local corner2 = Instance.new("UICorner")
    corner2.CornerRadius = UDim.new(1, 0)
    corner2.Parent = redDot
    
    -- Click handler
    local btn = Instance.new("TextButton")
    btn.Name = "ClickButton"
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.TextTransparency = 1
    btn.Parent = toggleMute
    
    return true
end

local function applyMuteUI()
    local _, frame3 = getMicPath()
    if not frame3 then return end
    
    local toggleMute = frame3:FindFirstChild("toggle_mic_mute")
    if not toggleMute then return end
    
    local iconFrame = toggleMute:FindFirstChild("IntegrationIconFrame")
    if not iconFrame then return end
    
    local icon = iconFrame:FindFirstChild("IntegrationIcon")
    if not icon then return end
    
    local micImage = icon:FindFirstChild("MicImage")
    if micImage then
        micImage.Image = "rbxasset://textures/ui/VoiceChat/MicLight/Muted.png"
    end
    
    -- Find and hide RedVoiceDot
    for _, child in ipairs(toggleMute:GetDescendants()) do
        if child.Name == "RedVoiceDot" then
            child.Visible = false
            break
        end
    end
end

local function applyUnmuteUI()
    local _, frame3 = getMicPath()
    if not frame3 then return end
    
    local toggleMute = frame3:FindFirstChild("toggle_mic_mute")
    if not toggleMute then return end
    
    local iconFrame = toggleMute:FindFirstChild("IntegrationIconFrame")
    if not iconFrame then return end
    
    local icon = iconFrame:FindFirstChild("IntegrationIcon")
    if not icon then return end
    
    local micImage = icon:FindFirstChild("MicImage")
    if micImage then
        micImage.Image = "rbxasset://textures/ui/VoiceChat/MicLight/Unmuted0.png"
    end
    
    -- Find and show RedVoiceDot
    for _, child in ipairs(toggleMute:GetDescendants()) do
        if child.Name == "RedVoiceDot" then
            child.Visible = true
            break
        end
    end
end

local function setupSizeMonitor()
    local frame2, _ = getMicPath()
    if not frame2 then return end

    local targetSize = UDim2.new(0, 140, 0, 44)
    local RunService = game:GetService("RunService")

    PM.VCBypasser.sizeMonitorConn = RunService.RenderStepped:Connect(function()
        if not PM.VCBypasser.active then return end
        if not frame2 or not frame2.Parent then return end

        if frame2.Size.X.Offset < 140 or frame2.Size.Y.Offset < 44 then
            pcall(function()
                frame2.Size = targetSize
            end)
        end
    end)
end

local function setupButtonClick()
    local _, frame3 = getMicPath()
    if not frame3 then return end

    local toggleMute = frame3:FindFirstChild("toggle_mic_mute")
    if not toggleMute then return end

    local btn = toggleMute:FindFirstChild("ClickButton")
    if not btn then return end

    local highlighter = toggleMute:FindFirstChild("Highlighter")

    -- Read initial mic state (from env.lua)
    task.spawn(function()
        task.wait(0.5)
        PM.VCBypasser.selfMuted = false
        applyUnmuteUI()

        local adi = getPlayerAudioInput(LP)
        if adi then
            -- Listen for external changes (from env.lua)
            PM.VCBypasser.propertySignalConn = adi:GetPropertyChangedSignal("Active"):Connect(function()
                PM.VCBypasser.selfMuted = not adi.Active
                if PM.VCBypasser.selfMuted then
                    applyMuteUI()
                else
                    applyUnmuteUI()
                end
            end)
        end
    end)

    PM.VCBypasser.buttonConn = btn.MouseButton1Click:Connect(function()
        PM.VCBypasser.selfMuted = not PM.VCBypasser.selfMuted
        local isMuted = PM.VCBypasser.selfMuted

        -- Use VoiceChatInternal:PublishPause for real muting control
        pcall(function()
            local VoiceChatInternal = game:GetService("VoiceChatInternal")
            VoiceChatInternal:PublishPause(isMuted)
        end)

        if isMuted then
            applyMuteUI()
        else
            applyUnmuteUI()
        end
    end)

    if highlighter then
        PM.VCBypasser.mouseEnterConn = btn.MouseEnter:Connect(function()
            highlighter.Visible = true
        end)

        PM.VCBypasser.mouseLeaveConn = btn.MouseLeave:Connect(function()
            highlighter.Visible = false
        end)
    end
end

registerCommand("vcbypasser", "Bypass voice chat restrictions", {}, function(args)
    local VoiceChatService = game:GetService("VoiceChatService")
    local VoiceChatInternal = game:GetService("VoiceChatInternal")

    pcall(function()
        VoiceChatService:rejoinVoice()
    end)

    task.wait(0.02)

    pcall(function()
        for _, connection in pairs(getconnections(VoiceChatInternal.StateChanged)) do
            connection:Disable()
        end
    end)

    PM.VCBypasser.active = true

    -- Wait for UI to recreate
    task.wait(1)

    -- Create the button
    createMuteButton()
    setupButtonClick()
    setupSizeMonitor()

    -- Setup player overlays and talking detection for all current players
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
    PM.VCBypasser.playerAddedConn = Players.PlayerAdded:Connect(function(p)
        if p ~= LP then
            task.spawn(function()
                waitForCharacterReady(p)
                setupTalkingDetection(p)
                createPlayerOverlay(p)
            end)
        end
    end)

    -- Cleanup on leave
    PM.VCBypasser.playerRemovingConn = Players.PlayerRemoving:Connect(function(p)
        removePlayerOverlay(p)
    end)
end, true)



-- View state management
PM.View = {
    viewing = false,
    target = nil,
    connection = nil,
    leavingConnection = nil
}

registerCommand("view", "View a player", {}, function(args)
    local targetName = args[1] or ""
    if targetName == "" then return end
    
    local q = targetName:lower()
    local target = nil
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            if p.Name:lower() == q or p.DisplayName:lower() == q then
                target = p
                break
            end
        end
    end
    
    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():sub(1, #q) == q or p.DisplayName:lower():sub(1, #q) == q then
                    target = p
                    break
                end
            end
        end
    end
    
    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
                    target = p
                    break
                end
            end
        end
    end
    
    if not target then return end
    
    -- Disconnect existing view
    if PM.View.connection then
        PM.View.connection:Disconnect()
        PM.View.connection = nil
    end
    if PM.View.leavingConnection then
        PM.View.leavingConnection:Disconnect()
        PM.View.leavingConnection = nil
    end
    
    PM.View.viewing = true
    PM.View.target = target
    
    local camera = workspace.CurrentCamera
    local RunService = game:GetService("RunService")
    
    PM.View.connection = RunService.Heartbeat:Connect(function()
        if PM.View.viewing and PM.View.target then
            local char = PM.View.target.Character
            if char and char:FindFirstChild("Humanoid") then
                camera.CameraSubject = char.Humanoid
            end
        end
    end)
    
    -- Auto-unview if target leaves
    PM.View.leavingConnection = target.CharacterRemoving:Connect(function()
        PM.View.viewing = false
        PM.View.target = nil
        
        if PM.View.connection then
            PM.View.connection:Disconnect()
            PM.View.connection = nil
        end
        if PM.View.leavingConnection then
            PM.View.leavingConnection:Disconnect()
            PM.View.leavingConnection = nil
        end
        
        local camera = workspace.CurrentCamera
        local char = LP.Character
        if char and char:FindFirstChild("Humanoid") then
            camera.CameraSubject = char.Humanoid
        end
    end)
end, true)

registerCommand("unview", "Stop viewing a player", {}, function(args)
    PM.View.viewing = false
    PM.View.target = nil
    
    if PM.View.connection then
        PM.View.connection:Disconnect()
        PM.View.connection = nil
    end
    if PM.View.leavingConnection then
        PM.View.leavingConnection:Disconnect()
        PM.View.leavingConnection = nil
    end
    
    local camera = workspace.CurrentCamera
    local char = LP.Character
    if char and char:FindFirstChild("Humanoid") then
        camera.CameraSubject = char.Humanoid
    end
end, true)

registerCommand("inspect", "Inspect a player", {}, function(args)
    local targetName = args[1] or ""
    if targetName == "" then return end

    local q = targetName:lower()
    local target = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            if p.Name:lower() == q or p.DisplayName:lower() == q then
                target = p
                break
            end
        end
    end

    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():sub(1, #q) == q or p.DisplayName:lower():sub(1, #q) == q then
                    target = p
                    break
                end
            end
        end
    end

    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
                    target = p
                    break
                end
            end
        end
    end

    if not target then return end

    local tChar = target.Character
    if not tChar then return end

    local th = tChar:FindFirstChildOfClass("Humanoid")
    if not th then return end

    pcall(function()
        local desc = th:GetAppliedDescription()
        game:GetService("GuiService"):InspectPlayerFromHumanoidDescription(desc, target.Name)
    end)
end, true)

registerCommand("add", "Send friend request to player", {}, function(args)
    local targetName = args[1] or ""
    if targetName == "" then return end

    local q = targetName:lower()
    local target = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            if p.Name:lower() == q or p.DisplayName:lower() == q then
                target = p
                break
            end
        end
    end

    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():sub(1, #q) == q or p.DisplayName:lower():sub(1, #q) == q then
                    target = p
                    break
                end
            end
        end
    end

    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
                    target = p
                    break
                end
            end
        end
    end

    if not target then return end

    pcall(function()
        LP:RequestFriendship(target)
    end)
end, true)

registerCommand("unadd", "Cancel friend request or unfriend", {}, function(args)
    local targetName = args[1] or ""
    if targetName == "" then return end

    local q = targetName:lower()
    local target = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            if p.Name:lower() == q or p.DisplayName:lower() == q then
                target = p
                break
            end
        end
    end

    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():sub(1, #q) == q or p.DisplayName:lower():sub(1, #q) == q then
                    target = p
                    break
                end
            end
        end
    end

    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
                    target = p
                    break
                end
            end
        end
    end

    if not target then return end

    pcall(function()
        LP:RevokeFriendship(target)
    end)
end, true)



-- Hidden players state
PM.HiddenPlayers = {}

local function applyHide(char, savedState)
    if not char then return savedState end
    savedState = savedState or { parts = {}, guis = {}, particles = {}, beams = {}, sounds = {}, lights = {}, hum = {} }
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            savedState.hum.displayDistType = hum.DisplayDistanceType
            savedState.hum.healthDist = hum.HealthDisplayDistance
            savedState.hum.nameDist = hum.NameDisplayDistance
            hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            hum.HealthDisplayDistance = 0
            hum.NameDisplayDistance = 0
        end)
    end
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BillboardGui") then
            pcall(function()
                savedState.guis[desc] = desc.Enabled
                desc.Enabled = false
            end)
        end
    end
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("ParticleEmitter") or desc:IsA("Fire") or desc:IsA("Sparkles") or desc:IsA("Smoke") then
            pcall(function()
                savedState.particles[desc] = desc.Enabled
                desc.Enabled = false
            end)
        end
    end
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("Beam") or desc:IsA("Trail") then
            pcall(function()
                savedState.beams[desc] = desc.Enabled
                desc.Enabled = false
            end)
        end
    end
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("Sound") then
            pcall(function()
                savedState.sounds[desc] = desc.Volume
                desc.Volume = 0
            end)
        end
    end
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("PointLight") or desc:IsA("SpotLight") or desc:IsA("SurfaceLight") then
            pcall(function()
                savedState.lights[desc] = desc.Brightness
                desc.Brightness = 0
            end)
        end
    end
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
            pcall(function()
                savedState.parts[desc] = desc.Transparency
                desc.Transparency = 1
            end)
        end
    end
    return savedState
end

registerCommand("hide", "Hide a player", {}, function(args)
    local targetName = args[1] or ""
    if targetName == "" then return end
    local q = targetName:lower()
    local target = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            if p.Name:lower() == q or p.DisplayName:lower() == q then
                target = p
                break
            end
        end
    end
    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():sub(1, #q) == q or p.DisplayName:lower():sub(1, #q) == q then
                    target = p
                    break
                end
            end
        end
    end
    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
                    target = p
                    break
                end
            end
        end
    end
    if not target then return end
    if PM.HiddenPlayers[target.UserId] then return end
    local adi = getPlayerAudioInput(target)
    if adi then pcall(function()
        adi.Muted = true
        -- Don't touch adi.Active - that's the player's self-mute state
    end) end
    local savedState = nil
    if target.Character then savedState = applyHide(target.Character, nil) end
    local conn = target.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        local newAdi = getPlayerAudioInput(target)
        if newAdi then pcall(function()
            newAdi.Muted = true
            -- Don't touch adi.Active - that's the player's self-mute state
        end) end
        savedState = applyHide(char, savedState)
        -- Remove VCBypasser icon on respawn
        removePlayerOverlay(target)
    end)
    PM.HiddenPlayers[target.UserId] = { connection = conn, audioDevice = adi, savedState = savedState }
    -- Hide the VCBypasser icon too
    removePlayerOverlay(target)
end, true)

registerCommand("unhide", "Unhide a player", {}, function(args)
    local targetName = args[1] or ""
    if targetName == "" then return end
    local q = targetName:lower()
    local target = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
                target = p
                break
            end
        end
    end
    if not target then return end
    if not PM.HiddenPlayers[target.UserId] then return end
    local data = PM.HiddenPlayers[target.UserId]
    if data.connection then pcall(function() data.connection:Disconnect() end) end
    if data.audioDevice then pcall(function()
        data.audioDevice.Muted = false
        data.audioDevice.Active = true
    end) end
    if target.Character and data.savedState then
        local state = data.savedState
        pcall(function()
            local hum = target.Character:FindFirstChildOfClass("Humanoid")
            if hum and state.hum then
                hum.DisplayDistanceType = state.hum.displayDistType or Enum.HumanoidDisplayDistanceType.Viewer
                hum.HealthDisplayDistance = state.hum.healthDist or 100
                hum.NameDisplayDistance = state.hum.nameDist or 100
            end
        end)
        for desc, orig in pairs(state.parts or {}) do pcall(function() desc.Transparency = orig end) end
        for desc, orig in pairs(state.guis or {}) do pcall(function() desc.Enabled = orig end) end
        for desc, orig in pairs(state.particles or {}) do pcall(function() desc.Enabled = orig end) end
        for desc, orig in pairs(state.beams or {}) do pcall(function() desc.Enabled = orig end) end
        for desc, orig in pairs(state.sounds or {}) do pcall(function() desc.Volume = orig end) end
        for desc, orig in pairs(state.lights or {}) do pcall(function() desc.Brightness = orig end) end
    end
    -- Mark as manually unhidden so hideall won't re-hide
    if PM.HiddenPlayers[target.UserId] then
        PM.HiddenPlayers[target.UserId].manuallyUnhidden = true
    end
    -- Restore the VCBypasser icon
    if PM.VCBypasser.active then
        task.spawn(function()
            if not target.Character then target.CharacterAdded:Wait() end
            task.wait(0.5)
            setupTalkingDetection(target)
            createPlayerOverlay(target)
        end)
    end
end, true)

registerCommand("hideall", "Hide all other players", {}, function(args)
    -- Hide all currently existing players (unless manually unhidden)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and not PM.HiddenPlayers[p.UserId] then
            local adi = getPlayerAudioInput(p)
            if adi then pcall(function()
                adi.Muted = true
                -- Don't touch adi.Active - that's the player's self-mute state
            end) end
            local savedState = nil
            if p.Character then savedState = applyHide(p.Character, nil) end
            local conn = p.CharacterAdded:Connect(function(char)
                task.wait(0.1)
                -- Skip if player was manually unhidden
                if PM.HiddenPlayers[p.UserId] and PM.HiddenPlayers[p.UserId].manuallyUnhidden then return end
                local newAdi = getPlayerAudioInput(p)
                if newAdi then pcall(function()
                    newAdi.Muted = true
                    -- Don't touch adi.Active - that's the player's self-mute state
                end) end
                savedState = applyHide(char, savedState)
                -- Remove VCBypasser icon on respawn
                removePlayerOverlay(p)
            end)
            PM.HiddenPlayers[p.UserId] = { connection = conn, audioDevice = adi, savedState = savedState }
        end
    end
    -- Auto-hide new players who join
    if not PM.HideAllPlayerAddedConn then
        PM.HideAllPlayerAddedConn = Players.PlayerAdded:Connect(function(p)
            if p ~= LP and not PM.HiddenPlayers[p.UserId] then
                local adi = getPlayerAudioInput(p)
                if adi then pcall(function()
                    adi.Muted = true
                    -- Don't touch adi.Active - that's the player's self-mute state
                end) end
                local savedState = nil
                if p.Character then savedState = applyHide(p.Character, nil) end
                local conn = p.CharacterAdded:Connect(function(char)
                    task.wait(0.1)
                    -- Skip if player was manually unhidden
                    if PM.HiddenPlayers[p.UserId] and PM.HiddenPlayers[p.UserId].manuallyUnhidden then return end
                    local newAdi = getPlayerAudioInput(p)
                    if newAdi then pcall(function()
                        newAdi.Muted = true
                        -- Don't touch adi.Active - that's the player's self-mute state
                    end) end
                    savedState = applyHide(char, savedState)
                    -- Remove VCBypasser icon on respawn
                    removePlayerOverlay(p)
                end)
                PM.HiddenPlayers[p.UserId] = { connection = conn, audioDevice = adi, savedState = savedState }
            end
        end)
    end
end, true)

registerCommand("unhideall", "Unhide all players", {}, function(args)
    -- Disconnect the auto-hide connection
    if PM.HideAllPlayerAddedConn then
        pcall(function() PM.HideAllPlayerAddedConn:Disconnect() end)
        PM.HideAllPlayerAddedConn = nil
    end
    for uid, data in pairs(PM.HiddenPlayers) do
        if data.connection then pcall(function() data.connection:Disconnect() end) end
        if data.audioDevice then pcall(function()
            data.audioDevice.Muted = false
            data.audioDevice.Active = true
        end) end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.UserId == uid and p.Character and data.savedState then
                local state = data.savedState
                pcall(function()
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if hum and state.hum then
                        hum.DisplayDistanceType = state.hum.displayDistType or Enum.HumanoidDisplayDistanceType.Viewer
                        hum.HealthDisplayDistance = state.hum.healthDist or 100
                        hum.NameDisplayDistance = state.hum.nameDist or 100
                    end
                end)
                for desc, orig in pairs(state.parts or {}) do pcall(function() desc.Transparency = orig end) end
                for desc, orig in pairs(state.guis or {}) do pcall(function() desc.Enabled = orig end) end
                for desc, orig in pairs(state.particles or {}) do pcall(function() desc.Enabled = orig end) end
                for desc, orig in pairs(state.beams or {}) do pcall(function() desc.Enabled = orig end) end
                for desc, orig in pairs(state.sounds or {}) do pcall(function() desc.Volume = orig end) end
                for desc, orig in pairs(state.lights or {}) do pcall(function() desc.Brightness = orig end) end
                break
            end
        end
    end
    PM.HiddenPlayers = {}
    -- Restore VCBypasser icons for all players if vcbypasser is active
    if PM.VCBypasser.active then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                task.spawn(function()
                    if not p.Character then p.CharacterAdded:Wait() end
                    task.wait(0.5)
                    setupTalkingDetection(p)
                    createPlayerOverlay(p)
                end)
            end
        end
    end
end, true)

-- Muted players tracking table
PM.MutedPlayers = {}

registerCommand("mute", "Mute a player's microphone", {}, function(args)
    local targetName = args[1] or ""
    if targetName == "" then return end
    local q = targetName:lower()
    local target = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            if p.Name:lower() == q or p.DisplayName:lower() == q then
                target = p
                break
            end
        end
    end
    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
                    target = p
                    break
                end
            end
        end
    end
    if target then
        -- Use env.lua's approach to find AudioDeviceInput
        local adi = getPlayerAudioInput(target)
        if adi then
            pcall(function()
                adi.Muted = true
                -- Don't touch adi.Active - that's the player's self-mute state
            end)
            PM.MutedPlayers[target.UserId] = adi
        end
    end
end, true)

registerCommand("unmute", "Unmute a player's microphone", {}, function(args)
    local targetName = args[1] or ""
    if targetName == "" then return end
    local q = targetName:lower()
    local target = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            if p.Name:lower() == q or p.DisplayName:lower() == q then
                target = p
                break
            end
        end
    end
    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
                    target = p
                    break
                end
            end
        end
    end
    if target then
        -- Use env.lua's approach to find AudioDeviceInput
        local adi = getPlayerAudioInput(target)
        if adi then
            -- Check if they self-muted (Active = false)
            local selfMuted = not adi.Active
            pcall(function()
                adi.Muted = false
                -- Only set Active = true if they weren't self-muted
                if not selfMuted then
                    adi.Active = true
                end
            end)
        end
        -- Mark as manually unmuted so muteall won't re-mute
        if PM.MutedPlayers[target.UserId] then
            PM.MutedPlayers[target.UserId].manuallyUnmuted = true
        end
    end
end, true)

registerCommand("muteall", "Mute all other players", {}, function(args)
    -- Mute all currently existing players (unless manually unmuted)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and not PM.MutedPlayers[p.UserId] then
            local adi = getPlayerAudioInput(p)
            if adi then
                pcall(function()
                    adi.Muted = true
                    -- Don't touch adi.Active - that's the player's self-mute state
                end)
            end
            -- Hook CharacterAdded for respawns
            local conn = p.CharacterAdded:Connect(function(char)
                task.wait(0.1)
                -- Skip if player was manually unmuted
                if PM.MutedPlayers[p.UserId] and PM.MutedPlayers[p.UserId].manuallyUnmuted then return end
                local newAdi = getPlayerAudioInput(p)
                if newAdi then
                    pcall(function()
                        newAdi.Muted = true
                        -- Don't touch adi.Active - that's the player's self-mute state
                    end)
                end
            end)
            PM.MutedPlayers[p.UserId] = { connection = conn }
        end
    end
    -- Auto-mute new players who join (unless manually unmuted)
    if not PM.MuteAllPlayerAddedConn then
        PM.MuteAllPlayerAddedConn = Players.PlayerAdded:Connect(function(p)
            if p ~= LP and not PM.MutedPlayers[p.UserId] then
                local adi = getPlayerAudioInput(p)
                if adi then
                    pcall(function()
                        adi.Muted = true
                        -- Don't touch adi.Active - that's the player's self-mute state
                    end)
                end
                local conn = p.CharacterAdded:Connect(function(char)
                    task.wait(0.1)
                    -- Skip if player was manually unmuted
                    if PM.MutedPlayers[p.UserId] and PM.MutedPlayers[p.UserId].manuallyUnmuted then return end
                    local newAdi = getPlayerAudioInput(p)
                    if newAdi then
                        pcall(function()
                            newAdi.Muted = true
                            -- Don't touch adi.Active - that's the player's self-mute state
                        end)
                    end
                end)
                PM.MutedPlayers[p.UserId] = { connection = conn }
            end
        end)
    end
end, true)

registerCommand("unmuteall", "Unmute all players", {}, function(args)
    -- Disconnect the auto-mute connection
    if PM.MuteAllPlayerAddedConn then
        pcall(function() PM.MuteAllPlayerAddedConn:Disconnect() end)
        PM.MuteAllPlayerAddedConn = nil
    end
    for uid, data in pairs(PM.MutedPlayers) do
        if data.connection then pcall(function() data.connection:Disconnect() end) end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.UserId == uid then
                local adi = getPlayerAudioInput(p)
                if adi then
                    pcall(function()
                        adi.Muted = false
                        adi.Active = true
                    end)
                end
            end
        end
    end
    PM.MutedPlayers = {}
end, true)

registerCommand("to", "Teleport to player", {}, function(args)
    local targetName = table.concat(args, " ")
    if targetName == "" then return end
    local q = targetName:lower()
    local target = nil
    -- Exact match
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            if p.Name:lower() == q or p.DisplayName:lower() == q then
                target = p
                break
            end
        end
    end
    -- Prefix match
    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():sub(1, #q) == q or p.DisplayName:lower():sub(1, #q) == q then
                    target = p
                    break
                end
            end
        end
    end
    -- Substring match
    if not target then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
                    target = p
                    break
                end
            end
        end
    end
    if not target then return end
    if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local myChar = LP.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if myHRP then
            myHRP.CFrame = target.Character.HumanoidRootPart.CFrame
        end
    end
end, true)

registerCommand("tptospawn", "Teleport to spawn", {}, function(args)
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local assigned = LP.RespawnLocation
    if assigned and assigned:IsA("SpawnLocation") then
        root.CFrame = assigned.CFrame + Vector3.new(0, 5, 0)
        return
    end
    
    local allSpawns = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            table.insert(allSpawns, obj)
        end
    end
    
    if #allSpawns > 0 then
        local nearest, nearestDist = allSpawns[1], math.huge
        for _, sp in ipairs(allSpawns) do
            local d = (sp.Position - root.Position).Magnitude
            if d < nearestDist then
                nearest = sp
                nearestDist = d
            end
        end
        root.CFrame = nearest.CFrame + Vector3.new(0, 5, 0)
        return
    end
    
    root.CFrame = CFrame.new(0, 10, 0)
end, true)

registerCommand("tptool", "Click to teleport tool", {}, function(args)
    if PM.TpToolActive then
        PM.TpToolActive = false
        if PM.TpToolConn then pcall(function() PM.TpToolConn:Disconnect() end); PM.TpToolConn = nil end
        if PM.TpWatchConn1 then pcall(function() PM.TpWatchConn1:Disconnect() end); PM.TpWatchConn1 = nil end
        if PM.TpWatchConn2 then pcall(function() PM.TpWatchConn2:Disconnect() end); PM.TpWatchConn2 = nil end
        local tpTool = LP.Backpack:FindFirstChild("Teleport Tool")
        if tpTool then pcall(function() tpTool:Destroy() end) end
        local charTp = LP.Character and LP.Character:FindFirstChild("Teleport Tool")
        if charTp then pcall(function() charTp:Destroy() end) end
        return
    end
    PM.TpToolActive = true
    
    local function giveTool()
        local bp = LP.Backpack
        local char = LP.Character
        if (bp and bp:FindFirstChild("Teleport Tool")) or (char and char:FindFirstChild("Teleport Tool")) then return end
        
        local tool = Instance.new("Tool")
        tool.Name = "Teleport Tool"
        tool.RequiresHandle = false
        tool.ToolTip = "Click to teleport"
        
        tool.Activated:Connect(function()
            local c = LP.Character
            if not c then return end
            local h = c:FindFirstChildOfClass("Humanoid")
            local root = c:FindFirstChild("HumanoidRootPart")
            if not root then return end

            local mouse = LP:GetMouse()
            local hipH = h and h.HipHeight or 2.3
            local hrpHalfHeight = root.Size.Y * 0.5
            local sinkBuffer = math.max(0.5, hipH * 0.15) + hrpHalfHeight * 0.25
            local hit = mouse.Hit.Position

            local targetPos
            if mouse.Target and PM.WOA and PM.WOA.enabled then
                -- WOA active: confirm real ground below the hit point
                local rcParams = RaycastParams.new()
                local excludes = { c }
                if PM.WOA.platform then table.insert(excludes, PM.WOA.platform) end
                rcParams.FilterDescendantsInstances = excludes
                rcParams.FilterType = Enum.RaycastFilterType.Exclude
                local groundCheck = workspace:Raycast(Vector3.new(hit.X, hit.Y + 0.5, hit.Z), Vector3.new(0, -15000, 0), rcParams)
                if groundCheck then
                    targetPos = Vector3.new(hit.X, hit.Y + hipH + sinkBuffer, hit.Z)
                else
                    targetPos = Vector3.new(hit.X, PM.WOA.baseY + hipH + 0.5, hit.Z)
                end
            elseif PM.WOA and PM.WOA.enabled then
                -- Aimed at void with WOA: project camera ray onto WOA plane
                local cam = workspace.CurrentCamera
                local UIS = game:GetService("UserInputService")
                local mousePos = UIS:GetMouseLocation()
                local unitRay = cam:ScreenPointToRay(mousePos.X, mousePos.Y)
                local planeY = PM.WOA.baseY
                local dirY = unitRay.Direction.Y
                local projX, projZ
                if math.abs(dirY) > 0.0001 then
                    local t = (planeY - unitRay.Origin.Y) / dirY
                    local p = unitRay.Origin + unitRay.Direction * math.max(t, 0)
                    projX, projZ = p.X, p.Z
                else
                    projX, projZ = hit.X, hit.Z
                end
                targetPos = Vector3.new(projX, PM.WOA.baseY + hipH + 0.5, projZ)
            else
                targetPos = Vector3.new(hit.X, hit.Y + hipH + sinkBuffer, hit.Z)
            end

            local lookDir = (Vector3.new(targetPos.X, root.Position.Y, targetPos.Z) - root.Position)
            lookDir = lookDir.Magnitude > 0.01 and lookDir.Unit or root.CFrame.LookVector
            root.CFrame = CFrame.new(targetPos, targetPos + lookDir)
            if h then h.Sit = false; h.AutoRotate = true end
        end)
        
        tool.Parent = bp
        
        -- Detect removal
        local function checkGone()
            local bp2 = LP.Backpack
            local char2 = LP.Character
            local inBp = bp2 and bp2:FindFirstChild("Teleport Tool")
            local inChar = char2 and char2:FindFirstChild("Teleport Tool")
            if not inBp and not inChar then
                PM.TpToolActive = false
                if PM.TpToolConn then pcall(function() PM.TpToolConn:Disconnect() end); PM.TpToolConn = nil end
                if PM.TpWatchConn1 then pcall(function() PM.TpWatchConn1:Disconnect() end); PM.TpWatchConn1 = nil end
                if PM.TpWatchConn2 then pcall(function() PM.TpWatchConn2:Disconnect() end); PM.TpWatchConn2 = nil end
            end
        end
        
        local function onRemoved(child)
            if child == tool then task.defer(checkGone) end
        end
        
        if bp then PM.TpWatchConn1 = bp.ChildRemoved:Connect(onRemoved) end
        if char then PM.TpWatchConn2 = char.ChildRemoved:Connect(onRemoved) end
    end
    
    giveTool()
    
    -- Re-give after respawn
    if PM.TpToolConn then pcall(function() PM.TpToolConn:Disconnect() end) end
    PM.TpToolConn = LP.CharacterAdded:Connect(function()
        task.wait(0.5)
        giveTool()
    end)
end)

registerCommand("jerk", "Jerk tool", {}, function(args)
    if PM.JerkActive then
        PM.JerkActive = false
        if PM.JerkRespawnConn then
            pcall(function() PM.JerkRespawnConn:Disconnect() end)
            PM.JerkRespawnConn = nil
        end
        local jerk = LP.Backpack:FindFirstChild("Jerk")
        if jerk then pcall(function() jerk:Destroy() end) end
        local charJerk = LP.Character and LP.Character:FindFirstChild("Jerk")
        if charJerk then pcall(function() charJerk:Destroy() end) end
        return
    end
    PM.JerkActive = true
    local function giveJerk()
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local bp = LP:FindFirstChild("Backpack")
        if not hum or not bp then return end
        if bp:FindFirstChild("Jerk") or char:FindFirstChild("Jerk") then return end
        local tool = Instance.new("Tool")
        tool.Name = "Jerk"
        tool.ToolTip = ";)"
        tool.RequiresHandle = false
        tool.Parent = bp
        local jorkin = false
        local track
        local function stopJerk()
            jorkin = false
            if track then track:Stop() track = nil end
        end
        tool.Equipped:Connect(function() jorkin = true end)
        tool.Unequipped:Connect(stopJerk)
        hum.Died:Connect(stopJerk)
        task.spawn(function()
            while task.wait() do
                if not (tool and tool.Parent) then break end
                if jorkin then
                    local isR15 = hum.RigType == Enum.HumanoidRigType.R15
                    if not track then
                        local anim = Instance.new("Animation")
                        anim.AnimationId = isR15 and "rbxassetid://698251653" or "rbxassetid://72042024"
                        track = hum:LoadAnimation(anim)
                    end
                    track:Play()
                    track:AdjustSpeed(isR15 and 0.7 or 0.65)
                    track.TimePosition = 0.6
                    task.wait(0.1)
                    while track and track.TimePosition < (isR15 and 0.7 or 0.65) do task.wait(0.1) end
                    if track then track:Stop() track = nil end
                end
            end
        end)
    end
    giveJerk()
    if PM.JerkRespawnConn then PM.JerkRespawnConn:Disconnect() end
    PM.JerkRespawnConn = LP.CharacterAdded:Connect(function()
        task.wait(0.5)
        giveJerk()
    end)
end)

registerCommand("hitlersalute", "Hitler salute tool", {}, function(args)
    if PM.HitlerSaluteActive then
        PM.HitlerSaluteActive = false
        if PM.HitlerSaluteRespawnConn then
            pcall(function() PM.HitlerSaluteRespawnConn:Disconnect() end)
            PM.HitlerSaluteRespawnConn = nil
        end
        local salute = LP.Backpack:FindFirstChild("Hitler Salute")
        if salute then pcall(function() salute:Destroy() end) end
        local charSalute = LP.Character and LP.Character:FindFirstChild("Hitler Salute")
        if charSalute then pcall(function() charSalute:Destroy() end) end
        return
    end
    PM.HitlerSaluteActive = true
    local function giveSalute()
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local bp = LP:FindFirstChild("Backpack")
        if not hum or not bp then return end
        if bp:FindFirstChild("Hitler Salute") or char:FindFirstChild("Hitler Salute") then return end
        local tool = Instance.new("Tool")
        tool.Name = "Hitler Salute"
        tool.ToolTip = "Salute"
        tool.RequiresHandle = false
        tool.Parent = bp
        local saluting = false
        local track
        local function stopSalute()
            saluting = false
            if track then track:Stop() track = nil end
        end
        tool.Equipped:Connect(function() saluting = true end)
        tool.Unequipped:Connect(stopSalute)
        hum.Died:Connect(stopSalute)
        task.spawn(function()
            while task.wait() do
                if not (tool and tool.Parent) then break end
                if saluting then
                    local isR15 = hum.RigType == Enum.HumanoidRigType.R15
                    if not track then
                        local anim = Instance.new("Animation")
                        anim.AnimationId = isR15 and "rbxassetid://698251653" or "rbxassetid://72042024"
                        track = hum:LoadAnimation(anim)
                    end
                    track:Play()
                    track.TimePosition = 0.6
                    track:AdjustSpeed(0)
                    while saluting and track do
                        track.TimePosition = 0.3
                        task.wait(0.05)
                    end
                    if track then track:Stop() track = nil end
                end
            end
        end)
    end
    giveSalute()
    if PM.HitlerSaluteRespawnConn then PM.HitlerSaluteRespawnConn:Disconnect() end
    PM.HitlerSaluteRespawnConn = LP.CharacterAdded:Connect(function()
        task.wait(0.5)
        giveSalute()
    end)
end)

-- Walk On Air state
PM.WOA = { enabled = false, platform = nil, baseY = 0, startY = nil, up = false, down = false, renderConn = nil, Gui = nil }

local function WOA_GetHR()
    local char = LP.Character
    if not char then return nil, nil end
    local h = char:FindFirstChildOfClass("Humanoid")
    local r = char:FindFirstChild("HumanoidRootPart")
    return h, r
end

local function WOA_GetFootY(h, root)
    local char = LP.Character
    local rcParams = RaycastParams.new()
    rcParams.FilterDescendantsInstances = char and {char} or {}
    rcParams.FilterType = Enum.RaycastFilterType.Exclude
    local hit = workspace:Raycast(root.Position, Vector3.new(0, -50, 0), rcParams)
    if hit then return hit.Position.Y end
    local hipH = h and h.HipHeight or 2.3
    local hrpHalf = root.Size.Y * 0.5
    return root.Position.Y - hrpHalf - hipH
end

local function WOA_Destroy()
    if not PM.WOA then return end
    if PM.WOA.renderConn then PM.WOA.renderConn:Disconnect(); PM.WOA.renderConn = nil end
    if PM.WOA.platform then PM.WOA.platform:Destroy(); PM.WOA.platform = nil end
    PM.WOA.enabled = false; PM.WOA.up = false; PM.WOA.down = false
end

local function WOA_Create()
    local h, root = WOA_GetHR(); if not root then return end
    WOA_Destroy(); PM.WOA.enabled = true; PM.WOA.startY = WOA_GetFootY(h, root); PM.WOA.baseY = PM.WOA.startY
    local part = Instance.new("Part")
    part.Name = "PrismWalkAirPlatform"
    part.Size = Vector3.new(20, 5, 20)
    part.Anchored = true; part.CanCollide = true; part.Material = Enum.Material.SmoothPlastic
    part.Transparency = 1; part.CastShadow = false
    part.CFrame = CFrame.new(root.Position.X, PM.WOA.baseY - 2.5, root.Position.Z)
    part.Parent = workspace
    PM.WOA.platform = part
    local RunService = game:GetService("RunService")
    PM.WOA.renderConn = RunService.RenderStepped:Connect(function()
        if not PM.WOA.enabled then return end
        local _, r = WOA_GetHR(); if not r or not PM.WOA.platform then return end
        if PM.WOA.up   then PM.WOA.baseY = PM.WOA.baseY + 0.2 end
        if PM.WOA.down then PM.WOA.baseY = PM.WOA.baseY - 0.2 end
        PM.WOA.platform.CFrame = CFrame.new(r.Position.X, PM.WOA.baseY - 2.5, r.Position.Z)
    end)
end

-- Load saved WOA enabled state
local WOA_STATE_FILE = "prism/prism_woa_state.json"
local savedWOAState = {}
pcall(function()
    if readfile and isfile(WOA_STATE_FILE) then
        savedWOAState = game:GetService("HttpService"):JSONDecode(readfile(WOA_STATE_FILE))
    end
end)
PM.WOA.enabled = savedWOAState.enabled or false

local function SaveWOAState()
    pcall(function()
        if writefile then
            if makefolder and not isfolder("prism") then makefolder("prism") end
            writefile(WOA_STATE_FILE, game:GetService("HttpService"):JSONEncode({enabled = PM.WOA.enabled}))
        end
    end)
end

-- Jump state
PM.Jump = { jumpPower = 50, infinite = false }

local JUMP_STATE_FILE = "prism/prism_jump_state.json"
local savedJumpState = {}
pcall(function()
    if readfile and isfile(JUMP_STATE_FILE) then
        savedJumpState = game:GetService("HttpService"):JSONDecode(readfile(JUMP_STATE_FILE))
    end
end)
PM.Jump.jumpPower = savedJumpState.jumpPower or 50
PM.Jump.infinite = savedJumpState.infinite or false

local function SaveJumpState()
    pcall(function()
        if writefile then
            if makefolder and not isfolder("prism") then makefolder("prism") end
            writefile(JUMP_STATE_FILE, game:GetService("HttpService"):JSONEncode({
                jumpPower = PM.Jump.jumpPower,
                infinite = PM.Jump.infinite
            }))
        end
    end)
end

-- Fly state
PM.Fly = { enabled = false, speed = 50, keybind = nil }

local FLY_STATE_FILE = "prism/prism_fly_state.json"
local savedFlyState = {}
pcall(function()
    if readfile and isfile(FLY_STATE_FILE) then
        savedFlyState = game:GetService("HttpService"):JSONDecode(readfile(FLY_STATE_FILE))
    end
end)
PM.Fly.enabled = savedFlyState.enabled or false
PM.Fly.speed = savedFlyState.speed or 50
PM.Fly.qeEnabled = savedFlyState.qeEnabled or false
if savedFlyState.keybind then
    local code = Enum.KeyCode[savedFlyState.keybind]
    if code then PM.Fly.keybind = code end
end

local function SaveFlyState()
    pcall(function()
        if writefile then
            if makefolder and not isfolder("prism") then makefolder("prism") end
            local state = {
                enabled = PM.Fly.enabled,
                speed = PM.Fly.speed,
                keybind = PM.Fly.keybind and PM.Fly.keybind.Name or nil,
                qeEnabled = PM.Fly.qeEnabled or false
            }
            writefile(FLY_STATE_FILE, game:GetService("HttpService"):JSONEncode(state))
        end
    end)
end

registerCommand("walkonair", "Walk on invisible platform with height control", {}, function(args)
    local CoreGui = game:GetService("CoreGui")
    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_WOAGUI") then return end

    local success, err = pcall(function()
        local UserInputService = game:GetService("UserInputService")
        local RunService = game:GetService("RunService")
        local TweenService = game:GetService("TweenService")
        local HttpService = game:GetService("HttpService")

        -- Load saved GUI settings
        local WOA_GUI_FILE = "prism/prism_woa_gui_settings.json"
        local savedWOAGUI = {}
        pcall(function()
            if readfile and isfile(WOA_GUI_FILE) then
                savedWOAGUI = HttpService:JSONDecode(readfile(WOA_GUI_FILE))
            end
        end)
        local savedPos = savedWOAGUI.position or {X = {Scale = 0, Offset = 1142}, Y = {Scale = 0, Offset = 320}}
        local savedMinimized = savedWOAGUI.minimized or false

        local currentWOASettings = {
            position = savedPos,
            minimized = savedMinimized
        }

        local function SaveWOAGUISettings()
            pcall(function()
                if writefile then
                    if makefolder and not isfolder("prism") then makefolder("prism") end
                    writefile(WOA_GUI_FILE, HttpService:JSONEncode(currentWOASettings))
                end
            end)
        end

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "Prism_WOAGUI"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.DisplayOrder = 1000
        PM.WOA.Gui = ScreenGui

        if syn and syn.protect_gui then
            syn.protect_gui(ScreenGui)
            ScreenGui.Parent = CoreGui
        elseif gethui then
            ScreenGui.Parent = gethui()
        else
            ScreenGui.Parent = CoreGui
        end

        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, 239, 0, 130)
        MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
        MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        MainFrame.BackgroundTransparency = 0.3
        MainFrame.BorderSizePixel = 0
        MainFrame.ClipsDescendants = true
        MainFrame.Parent = ScreenGui

        local MainCorner = Instance.new("UICorner")
        MainCorner.CornerRadius = UDim.new(0, 14)
        MainCorner.Parent = MainFrame

        local MainStroke = Instance.new("UIStroke")
        MainStroke.Color = Color3.fromRGB(60, 60, 60)
        MainStroke.Thickness = 1
        MainStroke.Parent = MainFrame

        local TitleBar = Instance.new("Frame")
        TitleBar.Name = "TitleBar"
        TitleBar.Size = UDim2.new(1, 0, 0, 36)
        TitleBar.BackgroundTransparency = 1
        TitleBar.Parent = MainFrame

        local dragging = false
        local dragStart = nil
        local startPos = nil

        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
            end
        end)

        TitleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                -- Save position when drag ends
                currentWOASettings.position = {
                    X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                    Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
                }
                SaveWOAGUISettings()
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Name = "Title"
        TitleLabel.Size = UDim2.new(1, -80, 1, 0)
        TitleLabel.Position = UDim2.new(0, 14, 0, 0)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = "Prism  •  Walk On Air"
        TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TitleLabel.TextSize = 13
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = TitleBar

        local MinBtn = Instance.new("TextButton")
        MinBtn.Name = "Minimize"
        MinBtn.Size = UDim2.new(0, 24, 0, 24)
        MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
        MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        MinBtn.BackgroundTransparency = 0.4
        MinBtn.BorderSizePixel = 0
        MinBtn.Text = "—"
        MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        MinBtn.TextSize = 11
        MinBtn.Font = Enum.Font.GothamBold
        MinBtn.Parent = TitleBar

        local MinCorner = Instance.new("UICorner")
        MinCorner.CornerRadius = UDim.new(0, 6)
        MinCorner.Parent = MinBtn

        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Name = "Close"
        CloseBtn.Size = UDim2.new(0, 24, 0, 24)
        CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        CloseBtn.BackgroundTransparency = 0.4
        CloseBtn.BorderSizePixel = 0
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        CloseBtn.TextSize = 11
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.Parent = TitleBar

        local CloseCorner = Instance.new("UICorner")
        CloseCorner.CornerRadius = UDim.new(0, 6)
        CloseCorner.Parent = CloseBtn

        CloseBtn.MouseButton1Click:Connect(function()
            ScreenGui:Destroy()
            WOA_Destroy()
            PM.WOA.Gui = nil
        end)

        local ContentFrame = Instance.new("Frame")
        ContentFrame.Name = "Content"
        ContentFrame.Size = UDim2.new(1, 0, 1, -40)
        ContentFrame.Position = UDim2.new(0, 0, 0, 40)
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.ClipsDescendants = true
        ContentFrame.Parent = MainFrame

        local isMinimized = savedMinimized
        local originalSize = UDim2.new(0, 239, 0, 130)
        local minimizedSize = UDim2.new(0, 239, 0, 36)
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        -- Apply saved minimized state
        if isMinimized then
            MinBtn.Text = "+"
            MainFrame.Size = minimizedSize
            ContentFrame.Visible = false
        end

        MinBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            currentWOASettings.minimized = isMinimized
            SaveWOAGUISettings()
            if isMinimized then
                MinBtn.Text = "+"
                local tween = TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize})
                tween:Play()
                tween.Completed:Connect(function() ContentFrame.Visible = false end)
            else
                MinBtn.Text = "—"
                ContentFrame.Visible = true
                TweenService:Create(MainFrame, tweenInfo, {Size = originalSize}):Play()
            end
        end)

        local ContentLayout = Instance.new("UIListLayout")
        ContentLayout.Padding = UDim.new(0, 6)
        ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ContentLayout.Parent = ContentFrame

        local ContentPadding = Instance.new("UIPadding")
        ContentPadding.PaddingTop = UDim.new(0, 4)
        ContentPadding.PaddingBottom = UDim.new(0, 4)
        ContentPadding.PaddingLeft = UDim.new(0, 8)
        ContentPadding.PaddingRight = UDim.new(0, 8)
        ContentPadding.Parent = ContentFrame

        local ToggleSection = Instance.new("Frame")
        ToggleSection.Name = "ToggleSection"
        ToggleSection.Size = UDim2.new(1, 0, 0, 36)
        ToggleSection.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        ToggleSection.BackgroundTransparency = 0.4
        ToggleSection.BorderSizePixel = 0
        ToggleSection.LayoutOrder = 1
        ToggleSection.Parent = ContentFrame

        local ToggleSectionCorner = Instance.new("UICorner")
        ToggleSectionCorner.CornerRadius = UDim.new(0, 10)
        ToggleSectionCorner.Parent = ToggleSection

        local ToggleLabel = Instance.new("TextLabel")
        ToggleLabel.Name = "Label"
        ToggleLabel.Size = UDim2.new(1, -100, 1, 0)
        ToggleLabel.Position = UDim2.new(0, 12, 0, 0)
        ToggleLabel.BackgroundTransparency = 1
        ToggleLabel.Text = "Walk On Air"
        ToggleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        ToggleLabel.TextSize = 12
        ToggleLabel.Font = Enum.Font.Gotham
        ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
        ToggleLabel.Parent = ToggleSection

        local Pill = Instance.new("Frame")
        Pill.Name = "Pill"
        Pill.Size = UDim2.new(0, 40, 0, 22)
        Pill.Position = UDim2.new(1, -52, 0.5, -11)
        Pill.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        Pill.BorderSizePixel = 0
        Pill.Parent = ToggleSection

        local PillCorner = Instance.new("UICorner")
        PillCorner.CornerRadius = UDim.new(0, 11)
        PillCorner.Parent = Pill

        local Knob = Instance.new("Frame")
        Knob.Name = "Knob"
        Knob.Size = UDim2.new(0, 16, 0, 16)
        Knob.Position = UDim2.new(0, 3, 0.5, -8)
        Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Knob.BorderSizePixel = 0
        Knob.Parent = Pill

        local KnobCorner = Instance.new("UICorner")
        KnobCorner.CornerRadius = UDim.new(0, 8)
        KnobCorner.Parent = Knob

        local PillHit = Instance.new("TextButton")
        PillHit.Size = UDim2.new(0, 52, 1, 0)
        PillHit.Position = UDim2.new(1, -56, 0, 0)
        PillHit.BackgroundTransparency = 1
        PillHit.Text = ""
        PillHit.Parent = ToggleSection

        local function SetWOA(val, save)
            PM.WOA.enabled = val
            ToggleLabel.Text = "Walk On Air"
            if val then
                TweenService:Create(Pill, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
                TweenService:Create(Knob, TweenInfo.new(0.15), {Position = UDim2.new(1, -19, 0.5, -8)}):Play()
            else
                TweenService:Create(Pill, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
                TweenService:Create(Knob, TweenInfo.new(0.15), {Position = UDim2.new(0, 3, 0.5, -8)}):Play()
            end
            if val then WOA_Create() else WOA_Destroy() end
            -- Save toggle state
            if save ~= false then
                SaveWOAState()
            end
        end

        PillHit.MouseButton1Click:Connect(function() SetWOA(not PM.WOA.enabled) end)

        -- Apply saved toggle state (visual only, don't auto-enable)
        if PM.WOA.enabled then
            SetWOA(true, false)
        end

        local BtnSection = Instance.new("Frame")
        BtnSection.Name = "BtnSection"
        BtnSection.Size = UDim2.new(1, 0, 0, 36)
        BtnSection.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        BtnSection.BackgroundTransparency = 0.4
        BtnSection.BorderSizePixel = 0
        BtnSection.LayoutOrder = 2
        BtnSection.Parent = ContentFrame

        local BtnSectionCorner = Instance.new("UICorner")
        BtnSectionCorner.CornerRadius = UDim.new(0, 10)
        BtnSectionCorner.Parent = BtnSection

        local BtnLayout = Instance.new("UIListLayout")
        BtnLayout.FillDirection = Enum.FillDirection.Horizontal
        BtnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        BtnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        BtnLayout.Padding = UDim.new(0, 6)
        BtnLayout.SortOrder = Enum.SortOrder.LayoutOrder
        BtnLayout.Parent = BtnSection

        local UpBtn = Instance.new("TextButton")
        UpBtn.Name = "UpBtn"
        UpBtn.Size = UDim2.new(0, 62, 0, 24)
        UpBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        UpBtn.BackgroundTransparency = 0.4
        UpBtn.BorderSizePixel = 0
        UpBtn.Text = "▲  Up"
        UpBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        UpBtn.TextSize = 11
        UpBtn.Font = Enum.Font.GothamBold
        UpBtn.LayoutOrder = 1
        UpBtn.Parent = BtnSection

        local UpBtnCorner = Instance.new("UICorner")
        UpBtnCorner.CornerRadius = UDim.new(0, 6)
        UpBtnCorner.Parent = UpBtn

        local ResetBtn = Instance.new("TextButton")
        ResetBtn.Name = "ResetBtn"
        ResetBtn.Size = UDim2.new(0, 62, 0, 24)
        ResetBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        ResetBtn.BackgroundTransparency = 0.4
        ResetBtn.BorderSizePixel = 0
        ResetBtn.Text = "Reset"
        ResetBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        ResetBtn.TextSize = 11
        ResetBtn.Font = Enum.Font.GothamBold
        ResetBtn.LayoutOrder = 2
        ResetBtn.Parent = BtnSection

        local ResetBtnCorner = Instance.new("UICorner")
        ResetBtnCorner.CornerRadius = UDim.new(0, 6)
        ResetBtnCorner.Parent = ResetBtn

        local DownBtn = Instance.new("TextButton")
        DownBtn.Name = "DownBtn"
        DownBtn.Size = UDim2.new(0, 62, 0, 24)
        DownBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        DownBtn.BackgroundTransparency = 0.4
        DownBtn.BorderSizePixel = 0
        DownBtn.Text = "▼  Down"
        DownBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        DownBtn.TextSize = 11
        DownBtn.Font = Enum.Font.GothamBold
        DownBtn.LayoutOrder = 3
        DownBtn.Parent = BtnSection

        local DownBtnCorner = Instance.new("UICorner")
        DownBtnCorner.CornerRadius = UDim.new(0, 6)
        DownBtnCorner.Parent = DownBtn

        UpBtn.MouseButton1Down:Connect(function() PM.WOA.up = true end)
        UpBtn.MouseButton1Up:Connect(function() PM.WOA.up = false end)
        UpBtn.MouseLeave:Connect(function() PM.WOA.up = false end)

        DownBtn.MouseButton1Down:Connect(function() PM.WOA.down = true end)
        DownBtn.MouseButton1Up:Connect(function() PM.WOA.down = false end)
        DownBtn.MouseLeave:Connect(function() PM.WOA.down = false end)

        ResetBtn.MouseButton1Click:Connect(function()
            if PM.WOA.enabled and PM.WOA.startY ~= nil then
                PM.WOA.baseY = PM.WOA.startY
            end
        end)

        ScreenGui.Destroying:Connect(function()
            WOA_Destroy()
            local plat = workspace:FindFirstChild("PrismWalkAirPlatform")
            if plat then pcall(function() plat:Destroy() end) end
        end)
    end)

end)

registerCommand("jump", "Jump power control with infinite jump", {}, function(args)
    local CoreGui = game:GetService("CoreGui")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local HttpService = game:GetService("HttpService")

    if FindPrismGUI("Prism_JumpGUI") then return end

    -- Load saved GUI settings
    local JUMP_GUI_FILE = "prism/prism_jump_gui_settings.json"
    local savedJumpGUI = {}
    pcall(function()
        if readfile and isfile(JUMP_GUI_FILE) then
            savedJumpGUI = HttpService:JSONDecode(readfile(JUMP_GUI_FILE))
        end
    end)
    local savedPos = savedJumpGUI.position or {X = {Scale = 0, Offset = 860}, Y = {Scale = 0, Offset = 320}}
    local savedMinimized = savedJumpGUI.minimized or false

    local currentJumpSettings = {
        position = savedPos,
        minimized = savedMinimized
    }

    local function SaveJumpGUISettings()
        pcall(function()
            if writefile then
                if makefolder and not isfolder("prism") then makefolder("prism") end
                writefile(JUMP_GUI_FILE, HttpService:JSONEncode(currentJumpSettings))
            end
        end)
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Prism_JumpGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 1000
    PM.Jump.Gui = ScreenGui

    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
    elseif gethui then
        ScreenGui.Parent = gethui()
    else
        ScreenGui.Parent = CoreGui
    end

    local MW, MH = 239, 148

    local defaultJP = PM.Jump.jumpPower or 50
    local currentJP = defaultJP
    local char0 = LP.Character
    local hum0 = char0 and char0:FindFirstChildOfClass("Humanoid")
    if hum0 then hum0.UseJumpPower = true; hum0.JumpPower = currentJP end

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, MW, 0, MH)
    MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
    MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    MainFrame.BackgroundTransparency = 0.3
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 14)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(60, 60, 60)
    MainStroke.Thickness = 1
    MainStroke.Parent = MainFrame

    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundTransparency = 1
    TitleBar.Parent = MainFrame

    local dragging = false
    local dragStart = nil
    local startPos = nil

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)

    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            currentJumpSettings.position = {
                X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
            }
            SaveJumpGUISettings()
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "Title"
    TitleLabel.Size = UDim2.new(1, -80, 1, 0)
    TitleLabel.Position = UDim2.new(0, 14, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "Prism  •  Jump"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 13
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Name = "Minimize"
    MinBtn.Size = UDim2.new(0, 24, 0, 24)
    MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
    MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MinBtn.BackgroundTransparency = 0.4
    MinBtn.BorderSizePixel = 0
    MinBtn.Text = "—"
    MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    MinBtn.TextSize = 11
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.Parent = TitleBar

    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 6)
    MinCorner.Parent = MinBtn

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "Close"
    CloseBtn.Size = UDim2.new(0, 24, 0, 24)
    CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    CloseBtn.BackgroundTransparency = 0.4
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    CloseBtn.TextSize = 11
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = TitleBar

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        PM.Jump.Gui = nil
    end)

    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "Content"
    ContentFrame.Size = UDim2.new(1, 0, 1, -44)
    ContentFrame.Position = UDim2.new(0, 0, 0, 44)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ClipsDescendants = true
    ContentFrame.Parent = MainFrame

    local isMinimized = savedMinimized
    local originalSize = UDim2.new(0, MW, 0, MH)
    local minimizedSize = UDim2.new(0, MW, 0, 36)
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    MinBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        currentJumpSettings.minimized = isMinimized
        SaveJumpGUISettings()
        if isMinimized then
            MinBtn.Text = "+"
            local tween = TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize})
            tween:Play()
            tween.Completed:Connect(function() ContentFrame.Visible = false end)
        else
            MinBtn.Text = "—"
            ContentFrame.Visible = true
            TweenService:Create(MainFrame, tweenInfo, {Size = originalSize}):Play()
        end
    end)

    if isMinimized then
        MinBtn.Text = "+"
        MainFrame.Size = minimizedSize
        ContentFrame.Visible = false
    end

    local ContentLayout = Instance.new("UIListLayout")
    ContentLayout.Padding = UDim.new(0, 6)
    ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ContentLayout.Parent = ContentFrame

    local ContentPadding = Instance.new("UIPadding")
    ContentPadding.PaddingTop = UDim.new(0, 4)
    ContentPadding.PaddingBottom = UDim.new(0, 4)
    ContentPadding.PaddingLeft = UDim.new(0, 8)
    ContentPadding.PaddingRight = UDim.new(0, 8)
    ContentPadding.Parent = ContentFrame

    -- Jump Power loop
    local jpLoopConn = nil
    local function startJPLoop(value)
        if jpLoopConn then jpLoopConn:Disconnect(); jpLoopConn = nil end
        if value <= 0 then return end
        jpLoopConn = RunService.Heartbeat:Connect(function()
            local c = LP.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if h then h.UseJumpPower = true; if h.JumpPower ~= value then h.JumpPower = value end end
        end)
    end

    -- Jump Power slider
    local Section = Instance.new("Frame")
    Section.Name = "Section"
    Section.Size = UDim2.new(1, 0, 0, 52)
    Section.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Section.BackgroundTransparency = 0.4
    Section.BorderSizePixel = 0
    Section.LayoutOrder = 1
    Section.Parent = ContentFrame

    local SectionCorner = Instance.new("UICorner")
    SectionCorner.CornerRadius = UDim.new(0, 10)
    SectionCorner.Parent = Section

    local SectionPadding = Instance.new("UIPadding")
    SectionPadding.PaddingTop = UDim.new(0, 5)
    SectionPadding.PaddingBottom = UDim.new(0, 5)
    SectionPadding.Parent = Section

    local SectionLayout = Instance.new("UIListLayout")
    SectionLayout.Padding = UDim.new(0, 2)
    SectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SectionLayout.Parent = Section

    local LabelRow = Instance.new("Frame")
    LabelRow.Size = UDim2.new(1, 0, 0, 20)
    LabelRow.BackgroundTransparency = 1
    LabelRow.LayoutOrder = 1
    LabelRow.Parent = Section

    local LabelPadding = Instance.new("UIPadding")
    LabelPadding.PaddingLeft = UDim.new(0, 12)
    LabelPadding.PaddingRight = UDim.new(0, 12)
    LabelPadding.Parent = LabelRow

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, -60, 1, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = "Jump Power"
    NameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    NameLabel.TextSize = 12
    NameLabel.Font = Enum.Font.Gotham
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.Parent = LabelRow

    local ValLabel = Instance.new("TextLabel")
    ValLabel.Size = UDim2.new(0, 55, 1, 0)
    ValLabel.Position = UDim2.new(1, -55, 0, 0)
    ValLabel.BackgroundTransparency = 1
    ValLabel.Text = tostring(math.floor(currentJP))
    ValLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
    ValLabel.TextSize = 11
    ValLabel.Font = Enum.Font.Gotham
    ValLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValLabel.Parent = LabelRow

    local SliderRow = Instance.new("Frame")
    SliderRow.Size = UDim2.new(1, 0, 0, 18)
    SliderRow.BackgroundTransparency = 1
    SliderRow.LayoutOrder = 2
    SliderRow.Parent = Section

    local SliderRowPadding = Instance.new("UIPadding")
    SliderRowPadding.PaddingLeft = UDim.new(0, 12)
    SliderRowPadding.PaddingRight = UDim.new(0, 12)
    SliderRowPadding.Parent = SliderRow

    local SliderBg = Instance.new("Frame")
    SliderBg.Size = UDim2.new(1, 0, 0, 6)
    SliderBg.Position = UDim2.new(0, 0, 0.5, -3)
    SliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    SliderBg.BorderSizePixel = 0
    SliderBg.Active = true
    SliderBg.Parent = SliderRow

    local SliderBgCorner = Instance.new("UICorner")
    SliderBgCorner.CornerRadius = UDim.new(0, 3)
    SliderBgCorner.Parent = SliderBg

    local initScale = currentJP / 500
    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new(initScale, 0, 1, 0)
    SliderFill.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    SliderFill.BorderSizePixel = 0
    SliderFill.Parent = SliderBg

    local SliderFillCorner = Instance.new("UICorner")
    SliderFillCorner.CornerRadius = UDim.new(0, 3)
    SliderFillCorner.Parent = SliderFill

    local SliderKnob = Instance.new("Frame")
    SliderKnob.Size = UDim2.new(0, 14, 0, 14)
    SliderKnob.Position = UDim2.new(initScale, 0, 0.5, 0)
    SliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SliderKnob.BorderSizePixel = 0
    SliderKnob.ZIndex = 3
    SliderKnob.Parent = SliderBg

    local SliderKnobCorner = Instance.new("UICorner")
    SliderKnobCorner.CornerRadius = UDim.new(0, 7)
    SliderKnobCorner.Parent = SliderKnob

    local sliderDragging = false
    local function updateJP(value)
        currentJP = math.clamp(math.floor(value + 0.5), 0, 500)
        local scale = currentJP / 500
        SliderFill.Size = UDim2.new(scale, 0, 1, 0)
        SliderKnob.Position = UDim2.new(scale, 0, 0.5, 0)
        ValLabel.Text = tostring(currentJP)
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then h.UseJumpPower = true; h.JumpPower = currentJP end
        startJPLoop(currentJP)
        PM.Jump.jumpPower = currentJP
        SaveJumpState()
    end

    SliderKnob.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if sliderDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
            updateJP(rel * 500)
        end
    end)
    local lastClickJP = 0
    SliderBg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            local now = tick()
            if now - lastClickJP < 0.3 then
                updateJP(50)
                sliderDragging = false
            else
                local rel = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                updateJP(rel * 500)
                sliderDragging = true
            end
            lastClickJP = now
        end
    end)

    startJPLoop(currentJP)

    -- Infinite Jump toggle
    local ijOn = PM.Jump.infinite or false
    local ijConn = nil

    local IJRow = Instance.new("Frame")
    IJRow.Size = UDim2.new(1, 0, 0, 32)
    IJRow.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    IJRow.BackgroundTransparency = 0.4
    IJRow.BorderSizePixel = 0
    IJRow.LayoutOrder = 2
    IJRow.Parent = ContentFrame

    local IJRowCorner = Instance.new("UICorner")
    IJRowCorner.CornerRadius = UDim.new(0, 10)
    IJRowCorner.Parent = IJRow

    local IJRowPadding = Instance.new("UIPadding")
    IJRowPadding.PaddingLeft = UDim.new(0, 12)
    IJRowPadding.PaddingRight = UDim.new(0, 12)
    IJRowPadding.Parent = IJRow

    local IJLabel = Instance.new("TextLabel")
    IJLabel.Size = UDim2.new(1, -48, 1, 0)
    IJLabel.BackgroundTransparency = 1
    IJLabel.Text = "Infinite Jump"
    IJLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    IJLabel.TextSize = 12
    IJLabel.Font = Enum.Font.Gotham
    IJLabel.TextXAlignment = Enum.TextXAlignment.Left
    IJLabel.Parent = IJRow

    local IJPill = Instance.new("Frame")
    IJPill.Size = UDim2.new(0, 36, 0, 18)
    IJPill.Position = UDim2.new(1, -36, 0.5, -9)
    IJPill.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    IJPill.BorderSizePixel = 0
    IJPill.Parent = IJRow

    local IJPillCorner = Instance.new("UICorner")
    IJPillCorner.CornerRadius = UDim.new(0, 9)
    IJPillCorner.Parent = IJPill

    local IJKnob = Instance.new("Frame")
    IJKnob.Size = UDim2.new(0, 14, 0, 14)
    IJKnob.Position = UDim2.new(0, 2, 0.5, -7)
    IJKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    IJKnob.BorderSizePixel = 0
    IJKnob.Parent = IJPill

    local IJKnobCorner = Instance.new("UICorner")
    IJKnobCorner.CornerRadius = UDim.new(0, 7)
    IJKnobCorner.Parent = IJKnob

    local IJBtn = Instance.new("TextButton")
    IJBtn.Size = UDim2.new(1, 0, 1, 0)
    IJBtn.BackgroundTransparency = 1
    IJBtn.Text = ""
    IJBtn.Parent = IJPill

    local function setIJ(on)
        ijOn = on
        TweenService:Create(IJPill, tweenInfo, {BackgroundColor3 = on and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(50, 50, 50)}):Play()
        TweenService:Create(IJKnob, tweenInfo, {Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        PM.Jump.infinite = ijOn
        SaveJumpState()
        if on then
            if ijConn then ijConn:Disconnect() end
            ijConn = UserInputService.JumpRequest:Connect(function()
                local c = LP.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        else
            if ijConn then ijConn:Disconnect(); ijConn = nil end
        end
    end
    IJBtn.MouseButton1Click:Connect(function() setIJ(not ijOn) end)

    -- Apply saved toggle state
    if PM.Jump.infinite then setIJ(true) end

    -- Respawn: reapply JP and IJ
    LP.CharacterAdded:Connect(function()
        task.wait(0.5)
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then h.UseJumpPower = true; h.JumpPower = currentJP end
        startJPLoop(currentJP)
        if ijOn then
            if ijConn then ijConn:Disconnect() end
            ijConn = UserInputService.JumpRequest:Connect(function()
                local c2 = LP.Character
                local h2 = c2 and c2:FindFirstChildOfClass("Humanoid")
                if h2 then h2:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        end
    end)

    ScreenGui.Destroying:Connect(function()
        if jpLoopConn then jpLoopConn:Disconnect(); jpLoopConn = nil end
        if ijConn then ijConn:Disconnect(); ijConn = nil end
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then h.UseJumpPower = true; h.JumpPower = defaultJP end
    end)
end)

-- Anti state management
PM.Anti = {
    afk = false,
    sit = false,
    ragdoll = false,
    void = false,
    paused = false,
    connections = {},
    origVoidY = nil
}

-- Load saved anti toggle states
local ANTI_TOGGLE_FILE = "prism/prism_anti_toggles.json"
pcall(function()
    if readfile and isfile(ANTI_TOGGLE_FILE) then
        local data = game:GetService("HttpService"):JSONDecode(readfile(ANTI_TOGGLE_FILE))
        if data then
            PM.Anti.afk = data.afk or false
            PM.Anti.sit = data.sit or false
            PM.Anti.ragdoll = data.ragdoll or false
            PM.Anti.void = data.void or false
            PM.Anti.paused = data.paused or false
        end
    end
end)

local function SaveAntiToggles()
    pcall(function()
        if writefile then
            if makefolder and not isfolder("prism") then makefolder("prism") end
            writefile(ANTI_TOGGLE_FILE, game:GetService("HttpService"):JSONEncode({
                afk = PM.Anti.afk,
                sit = PM.Anti.sit,
                ragdoll = PM.Anti.ragdoll,
                void = PM.Anti.void,
                paused = PM.Anti.paused
            }))
        end
    end)
end

registerCommand("antiall", "Anti Everything", {}, function(args)
    local CoreGui = game:GetService("CoreGui")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_AntiGUI") then return end

    local success, err = pcall(function()
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "Prism_AntiGUI"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.DisplayOrder = 1000
        ScreenGui.DisplayOrder = 999

        if syn and syn.protect_gui then
            syn.protect_gui(ScreenGui)
            ScreenGui.Parent = CoreGui
        elseif gethui then
            ScreenGui.Parent = gethui()
        else
            ScreenGui.Parent = CoreGui
        end

        -- Load saved settings
        local ANTI_SAVE_FILE = "prism/prism_anti_settings.json"
        local savedAntiSettings = {}
        pcall(function()
            if readfile and isfile(ANTI_SAVE_FILE) then
                savedAntiSettings = game:GetService("HttpService"):JSONDecode(readfile(ANTI_SAVE_FILE))
            end
        end)
        local savedPos = savedAntiSettings.position or {X = {Scale = 0, Offset = 1142}, Y = {Scale = 0, Offset = 160}}
        local savedMinimized = savedAntiSettings.minimized or false

        local currentAntiSettings = {
            position = savedPos,
            minimized = savedMinimized
        }

        local function SaveAntiSettings()
            pcall(function()
                if writefile then
                    if makefolder and not isfolder("prism") then makefolder("prism") end
                    writefile(ANTI_SAVE_FILE, game:GetService("HttpService"):JSONEncode(currentAntiSettings))
                end
            end)
        end

        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, 260, 0, 250)
        MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
        MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        MainFrame.BackgroundTransparency = 0.3
        MainFrame.BorderSizePixel = 0
        MainFrame.ClipsDescendants = true
        MainFrame.Parent = ScreenGui

        local MainCorner = Instance.new("UICorner")
        MainCorner.CornerRadius = UDim.new(0, 14)
        MainCorner.Parent = MainFrame

        local MainStroke = Instance.new("UIStroke")
        MainStroke.Color = Color3.fromRGB(60, 60, 60)
        MainStroke.Thickness = 1
        MainStroke.Parent = MainFrame

        local TitleBar = Instance.new("Frame")
        TitleBar.Name = "TitleBar"
        TitleBar.Size = UDim2.new(1, 0, 0, 36)
        TitleBar.BackgroundTransparency = 1
        TitleBar.Parent = MainFrame

        local dragging = false
        local dragStart = nil
        local startPos = nil

        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
            end
        end)

        TitleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                -- Save position
                currentAntiSettings.position = {
                    X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                    Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
                }
                SaveAntiSettings()
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Name = "Title"
        TitleLabel.Size = UDim2.new(1, -80, 1, 0)
        TitleLabel.Position = UDim2.new(0, 14, 0, 0)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = "Prism  •  Anti All"
        TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TitleLabel.TextSize = 13
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = TitleBar

        local MinBtn = Instance.new("TextButton")
        MinBtn.Name = "Minimize"
        MinBtn.Size = UDim2.new(0, 24, 0, 24)
        MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
        MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        MinBtn.BackgroundTransparency = 0.4
        MinBtn.BorderSizePixel = 0
        MinBtn.Text = "—"
        MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        MinBtn.TextSize = 11
        MinBtn.Font = Enum.Font.GothamBold
        MinBtn.Parent = TitleBar

        local MinCorner = Instance.new("UICorner")
        MinCorner.CornerRadius = UDim.new(0, 6)
        MinCorner.Parent = MinBtn

        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Name = "Close"
        CloseBtn.Size = UDim2.new(0, 24, 0, 24)
        CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        CloseBtn.BackgroundTransparency = 0.4
        CloseBtn.BorderSizePixel = 0
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        CloseBtn.TextSize = 11
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.Parent = TitleBar

        local CloseCorner = Instance.new("UICorner")
        CloseCorner.CornerRadius = UDim.new(0, 6)
        CloseCorner.Parent = CloseBtn

        CloseBtn.MouseButton1Click:Connect(function()
            ScreenGui:Destroy()
        end)

        local ContentFrame = Instance.new("Frame")
        ContentFrame.Name = "Content"
        ContentFrame.Size = UDim2.new(1, 0, 1, -40)
        ContentFrame.Position = UDim2.new(0, 0, 0, 40)
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.ClipsDescendants = true
        ContentFrame.Parent = MainFrame

        local isMinimized = savedMinimized
        local originalSize = UDim2.new(0, 260, 0, 260)
        local minimizedSize = UDim2.new(0, 260, 0, 36)
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        -- Apply saved minimized state
        if isMinimized then
            MinBtn.Text = "+"
            MainFrame.Size = minimizedSize
            ContentFrame.Visible = false
        end

        MinBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            currentAntiSettings.minimized = isMinimized
            SaveAntiSettings()
            if isMinimized then
                MinBtn.Text = "+"
                local tween = TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize})
                tween:Play()
                tween.Completed:Connect(function() ContentFrame.Visible = false end)
            else
                MinBtn.Text = "—"
                ContentFrame.Visible = true
                TweenService:Create(MainFrame, tweenInfo, {Size = originalSize}):Play()
            end
        end)

        local ContentLayout = Instance.new("UIListLayout")
        ContentLayout.Padding = UDim.new(0, 6)
        ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ContentLayout.Parent = ContentFrame

        local ContentPadding = Instance.new("UIPadding")
        ContentPadding.PaddingTop = UDim.new(0, 6)
        ContentPadding.PaddingBottom = UDim.new(0, 6)
        ContentPadding.PaddingLeft = UDim.new(0, 8)
        ContentPadding.PaddingRight = UDim.new(0, 8)
        ContentPadding.Parent = ContentFrame

        -- Function to create toggle row matching WOA style
        local function CreateToggle(name, label, layoutOrder, initialState, onToggle)
            local ToggleRow = Instance.new("Frame")
            ToggleRow.Name = name .. "Row"
            ToggleRow.Size = UDim2.new(1, 0, 0, 32)
            ToggleRow.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            ToggleRow.BackgroundTransparency = 0.4
            ToggleRow.BorderSizePixel = 0
            ToggleRow.LayoutOrder = layoutOrder
            ToggleRow.Parent = ContentFrame

            local RowCorner = Instance.new("UICorner")
            RowCorner.CornerRadius = UDim.new(0, 10)
            RowCorner.Parent = ToggleRow

            local ToggleLabel = Instance.new("TextLabel")
            ToggleLabel.Name = "Label"
            ToggleLabel.Size = UDim2.new(1, -100, 1, 0)
            ToggleLabel.Position = UDim2.new(0, 12, 0, 0)
            ToggleLabel.BackgroundTransparency = 1
            ToggleLabel.Text = label
            ToggleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
            ToggleLabel.TextSize = 12
            ToggleLabel.Font = Enum.Font.Gotham
            ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
            ToggleLabel.Parent = ToggleRow

            local Pill = Instance.new("Frame")
            Pill.Name = "Pill"
            Pill.Size = UDim2.new(0, 40, 0, 22)
            Pill.Position = UDim2.new(1, -52, 0.5, -11)
            Pill.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            Pill.BorderSizePixel = 0
            Pill.Parent = ToggleRow

            local PillCorner = Instance.new("UICorner")
            PillCorner.CornerRadius = UDim.new(0, 11)
            PillCorner.Parent = Pill

            local Knob = Instance.new("Frame")
            Knob.Name = "Knob"
            Knob.Size = UDim2.new(0, 16, 0, 16)
            Knob.Position = UDim2.new(0, 3, 0.5, -8)
            Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Knob.BorderSizePixel = 0
            Knob.Parent = Pill

            local KnobCorner = Instance.new("UICorner")
            KnobCorner.CornerRadius = UDim.new(0, 8)
            KnobCorner.Parent = Knob

            local PillHit = Instance.new("TextButton")
            PillHit.Size = UDim2.new(0, 52, 1, 0)
            PillHit.Position = UDim2.new(1, -56, 0, 0)
            PillHit.BackgroundTransparency = 1
            PillHit.Text = ""
            PillHit.Parent = ToggleRow

            local state = initialState
            local function SetToggle(val)
                state = val
                if val then
                    TweenService:Create(Pill, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
                    TweenService:Create(Knob, TweenInfo.new(0.15), {Position = UDim2.new(1, -19, 0.5, -8)}):Play()
                else
                    TweenService:Create(Pill, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
                    TweenService:Create(Knob, TweenInfo.new(0.15), {Position = UDim2.new(0, 3, 0.5, -8)}):Play()
                end
                if onToggle then onToggle(val) end
            end

            PillHit.MouseButton1Click:Connect(function() SetToggle(not state) end)

            if initialState then SetToggle(true) end

            return ToggleRow, SetToggle
        end

        -- Disconnect all anti connections
        local function DisconnectAnti(name)
            if PM.Anti.connections[name] then
                PM.Anti.connections[name]:Disconnect()
                PM.Anti.connections[name] = nil
            end
            if PM.Anti.connections[name .. "Char"] then
                PM.Anti.connections[name .. "Char"]:Disconnect()
                PM.Anti.connections[name .. "Char"] = nil
            end
        end

        -- Anti AFK: prevents Roblox from kicking you for idling
        CreateToggle("afk", "Anti AFK", 1, PM.Anti.afk, function(on)
            PM.Anti.afk = on
            SaveAntiToggles()
            DisconnectAnti("afk")
            if on then
                local VU = game:GetService("VirtualUser")
                PM.Anti.connections.afk = LocalPlayer.Idled:Connect(function()
                    VU:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                    task.wait(1)
                    VU:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                end)
            end
        end)

        -- Anti Sit: disables Seated humanoid state
        CreateToggle("sit", "Anti Sit", 2, PM.Anti.sit, function(on)
            PM.Anti.sit = on
            SaveAntiToggles()
            DisconnectAnti("sit")
            local function applyAntiSit(char)
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, not on) end)
                end
            end
            if on then
                if LocalPlayer.Character then applyAntiSit(LocalPlayer.Character) end
                PM.Anti.connections.sitChar = LocalPlayer.CharacterAdded:Connect(function(newChar)
                    repeat task.wait() until newChar:FindFirstChildWhichIsA("Humanoid")
                    local newHum = newChar:FindFirstChildWhichIsA("Humanoid")
                    if newHum then pcall(function() newHum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
                end)
            end
        end)

        -- Anti Ragdoll: disables Ragdoll and FallingDown states
        CreateToggle("ragdoll", "Anti Ragdoll", 3, PM.Anti.ragdoll, function(on)
            PM.Anti.ragdoll = on
            SaveAntiToggles()
            DisconnectAnti("ragdoll")
            local function applyAntiRagdoll(character)
                local h = character:FindFirstChildWhichIsA("Humanoid")
                if h then
                    pcall(function()
                        h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                        h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    end)
                end
            end
            if on then
                local c = LocalPlayer.Character
                if c then applyAntiRagdoll(c) end
                PM.Anti.connections.ragdollChar = LocalPlayer.CharacterAdded:Connect(function(newChar)
                    if not PM.Anti.ragdoll then return end
                    applyAntiRagdoll(newChar)
                end)
            end
        end)

        -- Anti Void: saves you from falling in void AND lowers void so you can never die to it
        CreateToggle("void", "Anti Void", 4, PM.Anti.void, function(on)
            PM.Anti.void = on
            SaveAntiToggles()
            DisconnectAnti("void")
            if on then
                PM.Anti.origVoidY = PM.Anti.origVoidY or workspace.FallenPartsDestroyHeight
                PM.Anti.connections.void = RunService.Heartbeat:Connect(function()
                    -- Lower void so you can never die to it
                    workspace.FallenPartsDestroyHeight = -99999
                    
                    -- Save you from falling in void
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root and root:IsA("BasePart") then
                        local refY = PM.Anti.origVoidY or workspace.FallenPartsDestroyHeight
                        if root.Position.Y < refY + 50 then
                            root.AssemblyLinearVelocity = Vector3.new(0, 500, 0)
                        end
                    end
                end)
            else
                if PM.Anti.origVoidY ~= nil then
                    pcall(function() workspace.FallenPartsDestroyHeight = PM.Anti.origVoidY end)
                end
            end
        end)

        -- Anti Gameplay Paused: destroy NetworkPause screen
        CreateToggle("paused", "Anti Gameplay Paused", 5, PM.Anti.paused, function(on)
            PM.Anti.paused = on
            SaveAntiToggles()
            DisconnectAnti("paused")
            if on then
                local coreGui = game:GetService("CoreGui")
                local robloxGui = coreGui:FindFirstChild("RobloxGui")
                if robloxGui then
                    local existing = robloxGui:FindFirstChild("CoreScripts/NetworkPause")
                    if existing then existing:Destroy() end
                    PM.Anti.connections.paused = robloxGui.ChildAdded:Connect(function(obj)
                        if obj.Name == "CoreScripts/NetworkPause" then obj:Destroy() end
                    end)
                end
            end
        end)



        -- Cleanup on close
        ScreenGui.Destroying:Connect(function()
            for name, conn in pairs(PM.Anti.connections) do
                if conn then pcall(function() conn:Disconnect() end) end
            end
            PM.Anti.connections = {}
            if PM.Anti.origVoidY ~= nil then
                pcall(function() workspace.FallenPartsDestroyHeight = PM.Anti.origVoidY end)
            end
        end)
    end)

end)

-- Emotes state management
PM.Emotes = {
    speed = 1.0,
    favorites = {},
    mwePriConn = nil,
    mweWalkConn = nil,
    currentEmoteTrack = nil
}

-- Load emotes favorites
local EMOTES_FAVORITES_FILE = "prism/prism_emotes_favorites.json"
local function LoadEmotesFavorites()
    if not readfile then return end
    pcall(function()
        if isfile(EMOTES_FAVORITES_FILE) then
            local content = readfile(EMOTES_FAVORITES_FILE)
            if content and content ~= "" then
                local data = game:GetService("HttpService"):JSONDecode(content)
                if data and type(data) == "table" then
                    PM.Emotes.favorites = data
                end
            end
        end
    end)
end
LoadEmotesFavorites()

local function SaveEmotesFavorites()
    if not writefile then return end
    pcall(function()
        if makefolder and not isfolder("prism") then makefolder("prism") end
        writefile(EMOTES_FAVORITES_FILE, game:GetService("HttpService"):JSONEncode(PM.Emotes.favorites))
    end)
end

registerCommand("emotes", "All Emotes On Roblox", {}, function(args)
    local CoreGui = game:GetService("CoreGui")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_EmotesGUI") then return end

    local success, err = pcall(function()
        -- Load emote data
        local emotesData = {}
        local jsonUrl = "https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json"
        local httpSuccess, jsonContent = pcall(function()
            return game:HttpGet(jsonUrl)
        end)
        if httpSuccess and jsonContent and jsonContent ~= "" then
            local decoded = HttpService:JSONDecode(jsonContent)
            if decoded and decoded.data then
                emotesData = decoded.data
            end
        end

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "Prism_EmotesGUI"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.DisplayOrder = 1000
        ScreenGui.DisplayOrder = 999

        if syn and syn.protect_gui then
            syn.protect_gui(ScreenGui)
            ScreenGui.Parent = CoreGui
        elseif gethui then
            ScreenGui.Parent = gethui()
        else
            ScreenGui.Parent = CoreGui
        end

        -- Load saved settings
        local EMOTES_SAVE_FILE = "prism/prism_emotes_gui_settings.json"
        local savedEmotesGUI = {}
        pcall(function()
            if readfile and isfile(EMOTES_SAVE_FILE) then
                savedEmotesGUI = game:GetService("HttpService"):JSONDecode(readfile(EMOTES_SAVE_FILE))
            end
        end)
        local savedPos = savedEmotesGUI.position or {X = {Scale = 0, Offset = 1142}, Y = {Scale = 0, Offset = 500}}
        local savedMinimized = savedEmotesGUI.minimized or false
        local savedMWE = savedEmotesGUI.moveWhileEmoting or false

        local currentEmotesSettings = {
            position = savedPos,
            minimized = savedMinimized,
            moveWhileEmoting = savedMWE
        }

        local function SaveEmotesGUISettings()
            currentEmotesSettings.moveWhileEmoting = moveWhileEmotingEnabled
            pcall(function()
                if writefile then
                    if makefolder and not isfolder("prism") then makefolder("prism") end
                    writefile(EMOTES_SAVE_FILE, game:GetService("HttpService"):JSONEncode(currentEmotesSettings))
                end
            end)
        end

        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, 260, 0, 360)
        MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
        MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        MainFrame.BackgroundTransparency = 0.3
        MainFrame.BorderSizePixel = 0
        MainFrame.ClipsDescendants = true
        MainFrame.Parent = ScreenGui

        local MainCorner = Instance.new("UICorner")
        MainCorner.CornerRadius = UDim.new(0, 14)
        MainCorner.Parent = MainFrame

        local MainStroke = Instance.new("UIStroke")
        MainStroke.Color = Color3.fromRGB(60, 60, 60)
        MainStroke.Thickness = 1
        MainStroke.Parent = MainFrame

        local TitleBar = Instance.new("Frame")
        TitleBar.Name = "TitleBar"
        TitleBar.Size = UDim2.new(1, 0, 0, 36)
        TitleBar.BackgroundTransparency = 1
        TitleBar.Parent = MainFrame

        local dragging = false
        local dragStart = nil
        local startPos = nil

        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
            end
        end)

        TitleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                -- Save position
                currentEmotesSettings.position = {
                    X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                    Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
                }
                SaveEmotesGUISettings()
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Name = "Title"
        TitleLabel.Size = UDim2.new(1, -80, 1, 0)
        TitleLabel.Position = UDim2.new(0, 14, 0, 0)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = "Prism  •  Emotes"
        TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TitleLabel.TextSize = 13
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = TitleBar

        local MinBtn = Instance.new("TextButton")
        MinBtn.Name = "Minimize"
        MinBtn.Size = UDim2.new(0, 24, 0, 24)
        MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
        MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        MinBtn.BackgroundTransparency = 0.4
        MinBtn.BorderSizePixel = 0
        MinBtn.Text = "—"
        MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        MinBtn.TextSize = 11
        MinBtn.Font = Enum.Font.GothamBold
        MinBtn.Parent = TitleBar

        local MinCorner = Instance.new("UICorner")
        MinCorner.CornerRadius = UDim.new(0, 6)
        MinCorner.Parent = MinBtn

        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Name = "Close"
        CloseBtn.Size = UDim2.new(0, 24, 0, 24)
        CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        CloseBtn.BackgroundTransparency = 0.4
        CloseBtn.BorderSizePixel = 0
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        CloseBtn.TextSize = 11
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.Parent = TitleBar

        local CloseCorner = Instance.new("UICorner")
        CloseCorner.CornerRadius = UDim.new(0, 6)
        CloseCorner.Parent = CloseBtn

        CloseBtn.MouseButton1Click:Connect(function()
            ScreenGui:Destroy()
        end)

        local ContentFrame = Instance.new("Frame")
        ContentFrame.Name = "Content"
        ContentFrame.Size = UDim2.new(1, 0, 1, -40)
        ContentFrame.Position = UDim2.new(0, 0, 0, 40)
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.ClipsDescendants = true
        ContentFrame.Parent = MainFrame

        local isMinimized = savedMinimized
        local originalSize = UDim2.new(0, 260, 0, 360)
        local minimizedSize = UDim2.new(0, 260, 0, 36)
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        -- Apply saved minimized state
        if isMinimized then
            MinBtn.Text = "+"
            MainFrame.Size = minimizedSize
            ContentFrame.Visible = false
        end

        MinBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            currentEmotesSettings.minimized = isMinimized
            SaveEmotesGUISettings()
            if isMinimized then
                MinBtn.Text = "+"
                local tween = TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize})
                tween:Play()
                tween.Completed:Connect(function() ContentFrame.Visible = false end)
            else
                MinBtn.Text = "—"
                ContentFrame.Visible = true
                TweenService:Create(MainFrame, tweenInfo, {Size = originalSize}):Play()
            end
        end)

        -- Status Bar
        local StatusBar = Instance.new("Frame")
        StatusBar.Name = "StatusBar"
        StatusBar.Size = UDim2.new(1, -16, 0, 20)
        StatusBar.Position = UDim2.new(0, 8, 0, 0)
        StatusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        StatusBar.BackgroundTransparency = 0.4
        StatusBar.BorderSizePixel = 0
        StatusBar.Parent = ContentFrame

        local StatusCorner = Instance.new("UICorner")
        StatusCorner.CornerRadius = UDim.new(0, 10)
        StatusCorner.Parent = StatusBar

        local StatusLabel = Instance.new("TextLabel")
        StatusLabel.Name = "Status"
        StatusLabel.Size = UDim2.new(1, -20, 1, 0)
        StatusLabel.Position = UDim2.new(0, 10, 0, 0)
        StatusLabel.BackgroundTransparency = 1
        StatusLabel.Text = "Loaded " .. #emotesData .. " emotes"
        StatusLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
        StatusLabel.TextSize = 11
        StatusLabel.Font = Enum.Font.Gotham
        StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        StatusLabel.Parent = StatusBar

        -- Tab Bar
        local TabContainer = Instance.new("Frame")
        TabContainer.Name = "TabContainer"
        TabContainer.Size = UDim2.new(1, -16, 0, 26)
        TabContainer.Position = UDim2.new(0, 8, 0, 26)
        TabContainer.BackgroundTransparency = 1
        TabContainer.Parent = ContentFrame

        local TabList = Instance.new("UIListLayout")
        TabList.Padding = UDim.new(0, 3)
        TabList.FillDirection = Enum.FillDirection.Horizontal
        TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
        TabList.SortOrder = Enum.SortOrder.LayoutOrder
        TabList.Parent = TabContainer

        local Tabs = {"All", "Favorites", "Settings"}
        local TabButtons = {}
        local currentTab = "All"

        for i, tabName in ipairs(Tabs) do
            local tabBtn = Instance.new("TextButton")
            tabBtn.Name = tabName .. "Tab"
            tabBtn.Size = UDim2.new(0, 0, 1, 0)
            tabBtn.AutomaticSize = Enum.AutomaticSize.X
            tabBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            tabBtn.BackgroundTransparency = (tabName == "All") and 0.1 or 0.7
            tabBtn.BorderSizePixel = 0
            tabBtn.Text = "  " .. tabName .. "  "
            tabBtn.TextColor3 = (tabName == "All") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
            tabBtn.TextSize = 10
            tabBtn.Font = Enum.Font.GothamMedium
            tabBtn.LayoutOrder = i
            tabBtn.ZIndex = 10
            tabBtn.Parent = TabContainer

            local tabCorner = Instance.new("UICorner")
            tabCorner.CornerRadius = UDim.new(0, 10)
            tabCorner.Parent = tabBtn

            TabButtons[tabName] = tabBtn
        end

        -- Search Box
        local SearchBox = Instance.new("TextBox")
        SearchBox.Name = "Search"
        SearchBox.Size = UDim2.new(1, -16, 0, 24)
        SearchBox.Position = UDim2.new(0, 8, 0, 58)
        SearchBox.Visible = true
        SearchBox.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        SearchBox.BackgroundTransparency = 0.3
        SearchBox.BorderSizePixel = 0
        SearchBox.Text = ""
        SearchBox.PlaceholderText = "Search emotes..."
        SearchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
        SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        SearchBox.TextSize = 11
        SearchBox.Font = Enum.Font.Gotham
        SearchBox.ClearTextOnFocus = false
        SearchBox.Parent = ContentFrame

        local SearchCorner = Instance.new("UICorner")
        SearchCorner.CornerRadius = UDim.new(0, 6)
        SearchCorner.Parent = SearchBox

        -- List Container
        local ListContainer = Instance.new("Frame")
        ListContainer.Name = "ListContainer"
        ListContainer.Size = UDim2.new(1, -16, 1, -138)
        ListContainer.Position = UDim2.new(0, 8, 0, 88)
        ListContainer.BackgroundTransparency = 1
        ListContainer.ClipsDescendants = true
        ListContainer.Parent = ContentFrame

        local ScrollFrame = Instance.new("ScrollingFrame")
        ScrollFrame.Name = "ScrollFrame"
        ScrollFrame.Size = UDim2.new(1, 0, 1, 0)
        ScrollFrame.BackgroundTransparency = 1
        ScrollFrame.BorderSizePixel = 0
        ScrollFrame.ScrollBarThickness = 4
        ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        ScrollFrame.Parent = ListContainer

        local ListLayout = Instance.new("UIListLayout")
        ListLayout.Padding = UDim.new(0, 4)
        ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ListLayout.Parent = ScrollFrame

        -- Bottom Bar with Animation Speed
        local BottomBar = Instance.new("Frame")
        BottomBar.Name = "BottomBar"
        BottomBar.Size = UDim2.new(1, 0, 0, 52)
        BottomBar.Position = UDim2.new(0, 0, 1, -52)
        BottomBar.BackgroundTransparency = 1
        BottomBar.ZIndex = 25
        BottomBar.Visible = true
        BottomBar.Parent = ContentFrame

        -- Animation Speed Control
        local function ApplyAnimSpeed(speed)
            local char = LocalPlayer.Character
            if not char then return end
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if not animator then return end

            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                pcall(function()
                    track:AdjustSpeed(speed)
                end)
            end
        end

        local function HookAnimationSpeed()
            local char = LocalPlayer.Character
            if not char then return nil end
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not humanoid then return nil end
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if not animator then return nil end

            return animator.AnimationPlayed:Connect(function(track)
                if PM.Emotes.speed and PM.Emotes.speed ~= 1 then
                    pcall(function()
                        track:AdjustSpeed(PM.Emotes.speed)
                    end)
                end
            end)
        end

        local animSpeedConn = nil
        local function SetupAnimSpeed()
            if animSpeedConn then animSpeedConn:Disconnect() end
            animSpeedConn = HookAnimationSpeed()
            ApplyAnimSpeed(PM.Emotes.speed)
        end

        SetupAnimSpeed()
        LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.3)
            SetupAnimSpeed()
        end)

        -- Speed Label
        local SpeedLabel = Instance.new("TextLabel")
        SpeedLabel.Size = UDim2.new(1, -20, 0, 16)
        SpeedLabel.Position = UDim2.new(0, 10, 0, 0)
        SpeedLabel.BackgroundTransparency = 1
        SpeedLabel.Text = "Animation Speed: " .. string.format("%.1f", PM.Emotes.speed) .. "x"
        SpeedLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        SpeedLabel.TextSize = 11
        SpeedLabel.Font = Enum.Font.Gotham
        SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
        SpeedLabel.Parent = BottomBar

        -- Speed Slider Background
        local SliderBg = Instance.new("Frame")
        SliderBg.Size = UDim2.new(1, -20, 0, 6)
        SliderBg.Position = UDim2.new(0, 10, 0, 22)
        SliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        SliderBg.BorderSizePixel = 0
        SliderBg.Parent = BottomBar

        local SliderBgCorner = Instance.new("UICorner")
        SliderBgCorner.CornerRadius = UDim.new(0, 3)
        SliderBgCorner.Parent = SliderBg

        -- Speed Slider Fill
        local initScale = (PM.Emotes.speed - 0.1) / 4.9
        local SliderFill = Instance.new("Frame")
        SliderFill.Size = UDim2.new(initScale, 0, 1, 0)
        SliderFill.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        SliderFill.BorderSizePixel = 0
        SliderFill.Parent = SliderBg

        local SliderFillCorner = Instance.new("UICorner")
        SliderFillCorner.CornerRadius = UDim.new(0, 3)
        SliderFillCorner.Parent = SliderFill

        -- Speed Slider Knob
        local SliderKnob = Instance.new("Frame")
        SliderKnob.Size = UDim2.new(0, 12, 0, 12)
        SliderKnob.Position = UDim2.new(initScale, -6, 0.5, -6)
        SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        SliderKnob.BorderSizePixel = 0
        SliderKnob.ZIndex = 3
        SliderKnob.Parent = SliderBg

        local SliderKnobCorner = Instance.new("UICorner")
        SliderKnobCorner.CornerRadius = UDim.new(0, 6)
        SliderKnobCorner.Parent = SliderKnob

        -- Slider interaction
        local sliderDragging = false
        local lastClickAnimSpeed = 0
        local function updateSlider(value)
            local speed = math.clamp(math.floor(value * 10) / 10, 0.1, 5.0)
            PM.Emotes.speed = speed
            local scale = (speed - 0.1) / 4.9
            SliderFill.Size = UDim2.new(scale, 0, 1, 0)
            SliderKnob.Position = UDim2.new(scale, -6, 0.5, -6)
            SpeedLabel.Text = "Animation Speed: " .. string.format("%.1f", speed) .. "x"
            ApplyAnimSpeed(speed)
        end

        SliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local now = tick()
                if now - lastClickAnimSpeed < 0.3 then
                    updateSlider(1.0)
                    sliderDragging = false
                else
                    local pos = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                    updateSlider(0.1 + pos * 4.9)
                    sliderDragging = true
                end
                lastClickAnimSpeed = now
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local pos = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                updateSlider(0.1 + pos * 4.9)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = false
            end
        end)

        -- Settings Panel (hidden by default)
        local SettingsPanel = Instance.new("Frame")
        SettingsPanel.Name = "SettingsPanel"
        SettingsPanel.Size = UDim2.new(1, -16, 1, -58)
        SettingsPanel.Position = UDim2.new(0, 8, 0, 86)
        SettingsPanel.BackgroundTransparency = 1
        SettingsPanel.Visible = false
        SettingsPanel.Parent = ContentFrame

        -- Move While Emoting Toggle
        local MWESection = Instance.new("Frame")
        MWESection.Size = UDim2.new(1, 0, 0, 32)
        MWESection.Position = UDim2.new(0, 0, 0, -20)
        MWESection.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        MWESection.BackgroundTransparency = 0.4
        MWESection.BorderSizePixel = 0
        MWESection.Parent = SettingsPanel

        local MWECorner = Instance.new("UICorner")
        MWECorner.CornerRadius = UDim.new(0, 10)
        MWECorner.Parent = MWESection

        local MWELabel = Instance.new("TextLabel")
        MWELabel.Size = UDim2.new(1, -100, 1, 0)
        MWELabel.Position = UDim2.new(0, 12, 0, 0)
        MWELabel.BackgroundTransparency = 1
        MWELabel.Text = "Move While Emoting"
        MWELabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        MWELabel.TextSize = 12
        MWELabel.Font = Enum.Font.Gotham
        MWELabel.TextXAlignment = Enum.TextXAlignment.Left
        MWELabel.Parent = MWESection

        local MWEPill = Instance.new("Frame")
        MWEPill.Name = "Pill"
        MWEPill.Size = UDim2.new(0, 40, 0, 22)
        MWEPill.Position = UDim2.new(1, -52, 0.5, -11)
        MWEPill.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        MWEPill.BorderSizePixel = 0
        MWEPill.Parent = MWESection

        local MWEPillCorner = Instance.new("UICorner")
        MWEPillCorner.CornerRadius = UDim.new(0, 11)
        MWEPillCorner.Parent = MWEPill

        local MWEKnob = Instance.new("Frame")
        MWEKnob.Name = "Knob"
        MWEKnob.Size = UDim2.new(0, 16, 0, 16)
        MWEKnob.Position = UDim2.new(0, 3, 0.5, -8)
        MWEKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        MWEKnob.BorderSizePixel = 0
        MWEKnob.Parent = MWEPill

        local MWEKnobCorner = Instance.new("UICorner")
        MWEKnobCorner.CornerRadius = UDim.new(0, 8)
        MWEKnobCorner.Parent = MWEKnob

        local MWEHit = Instance.new("TextButton")
        MWEHit.Size = UDim2.new(0, 52, 1, 0)
        MWEHit.Position = UDim2.new(1, -56, 0, 0)
        MWEHit.BackgroundTransparency = 1
        MWEHit.Text = ""
        MWEHit.Parent = MWESection

        -- Move While Emoting State
        local moveWhileEmotingEnabled = savedMWE or false
        PM.Emotes.mwePriConn = nil
        PM.Emotes.mweWalkConn = nil
        PM.Emotes.currentEmoteTrack = nil

        local function urlToId(id)
            id = id:gsub("http://www%.roblox%.com/asset/%?id=", "")
            id = id:gsub("rbxassetid://", "")
            return id
        end

        local function isDancing(char, animTrack)
            local animate = char:FindFirstChild("Animate")
            if not animate then return false end
            local animId = urlToId(animTrack.Animation.AnimationId)
            for _, holder in ipairs(animate:GetChildren()) do
                if holder:IsA("StringValue") then
                    for _, animObj in ipairs(holder:GetChildren()) do
                        if animObj:IsA("Animation") and urlToId(animObj.AnimationId) == animId then
                            return false
                        end
                    end
                end
            end
            return true
        end

        local function StopCurrentEmote()
            if PM.Emotes.currentEmoteTrack then
                pcall(function() PM.Emotes.currentEmoteTrack:Stop() end)
                PM.Emotes.currentEmoteTrack = nil
            end
        end

        local function PlayEmoteWalk(hum, emoteId)
            StopCurrentEmote()
            local anim = Instance.new("Animation")
            anim.AnimationId = "rbxassetid://" .. emoteId
            PM.Emotes.currentEmoteTrack = hum:LoadAnimation(anim)
            if PM.Emotes.currentEmoteTrack then
                PM.Emotes.currentEmoteTrack.Priority = Enum.AnimationPriority.Action
                PM.Emotes.currentEmoteTrack.Looped = true
                task.wait(0.1)
                PM.Emotes.currentEmoteTrack:Play()
            end
        end

        local function HookEmoteWalk(char)
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local animator = hum:FindFirstChildOfClass("Animator")
            if not animator then return end

            if PM.Emotes.mwePriConn then PM.Emotes.mwePriConn:Disconnect(); PM.Emotes.mwePriConn = nil end

            PM.Emotes.mwePriConn = animator.AnimationPlayed:Connect(function(animTrack)
                if not moveWhileEmotingEnabled then return end
                if not isDancing(char, animTrack) then return end

                local playedId = urlToId(animTrack.Animation.AnimationId)
                if PM.Emotes.currentEmoteTrack then
                    local curId = urlToId(PM.Emotes.currentEmoteTrack.Animation.AnimationId)
                    if curId == playedId then return end
                    StopCurrentEmote()
                end
                PlayEmoteWalk(hum, playedId)
            end)

            hum.Died:Connect(function()
                moveWhileEmotingEnabled = false
                StopCurrentEmote()
            end)
        end

        local function SetMoveWhileEmoting(enabled)
            moveWhileEmotingEnabled = enabled

            if not enabled then
                StopCurrentEmote()
                if PM.Emotes.mwePriConn then PM.Emotes.mwePriConn:Disconnect(); PM.Emotes.mwePriConn = nil end
                if PM.Emotes.mweWalkConn then PM.Emotes.mweWalkConn:Disconnect(); PM.Emotes.mweWalkConn = nil end
                return
            end

            local char = LocalPlayer.Character
            if char then
                task.spawn(function()
                    task.wait(0.1)
                    if moveWhileEmotingEnabled then HookEmoteWalk(char) end
                end)
            end

            if PM.Emotes.mweWalkConn then PM.Emotes.mweWalkConn:Disconnect(); PM.Emotes.mweWalkConn = nil end
            PM.Emotes.mweWalkConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
                task.wait(0.5)
                if moveWhileEmotingEnabled then HookEmoteWalk(newChar) end
            end)
        end

        local function SetMWE(val)
            moveWhileEmotingEnabled = val
            SetMoveWhileEmoting(moveWhileEmotingEnabled)
            currentEmotesSettings.moveWhileEmoting = moveWhileEmotingEnabled
            SaveEmotesGUISettings()

            if val then
                TweenService:Create(MWEPill, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
                TweenService:Create(MWEKnob, TweenInfo.new(0.15), {Position = UDim2.new(1, -19, 0.5, -8)}):Play()
            else
                TweenService:Create(MWEPill, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
                TweenService:Create(MWEKnob, TweenInfo.new(0.15), {Position = UDim2.new(0, 3, 0.5, -8)}):Play()
            end
        end

        MWEHit.MouseButton1Click:Connect(function() SetMWE(not moveWhileEmotingEnabled) end)

        -- Initialize toggle state from saved settings
        if savedMWE then
            SetMWE(true)
        end

        -- Animation Logger Toggle
        local ALSection = Instance.new("Frame")
        ALSection.Size = UDim2.new(1, 0, 0, 32)
        ALSection.Position = UDim2.new(0, 0, 0, 16)
        ALSection.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        ALSection.BackgroundTransparency = 0.4
        ALSection.BorderSizePixel = 0
        ALSection.Parent = SettingsPanel

        local ALCorner = Instance.new("UICorner")
        ALCorner.CornerRadius = UDim.new(0, 10)
        ALCorner.Parent = ALSection

        local ALLabel = Instance.new("TextLabel")
        ALLabel.Size = UDim2.new(1, -100, 1, 0)
        ALLabel.Position = UDim2.new(0, 12, 0, 0)
        ALLabel.BackgroundTransparency = 1
        ALLabel.Text = "Animation Logger"
        ALLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        ALLabel.TextSize = 12
        ALLabel.Font = Enum.Font.Gotham
        ALLabel.TextXAlignment = Enum.TextXAlignment.Left
        ALLabel.Parent = ALSection

        local ALPill = Instance.new("Frame")
        ALPill.Name = "Pill"
        ALPill.Size = UDim2.new(0, 40, 0, 22)
        ALPill.Position = UDim2.new(1, -52, 0.5, -11)
        ALPill.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        ALPill.BorderSizePixel = 0
        ALPill.Parent = ALSection

        local ALPillCorner = Instance.new("UICorner")
        ALPillCorner.CornerRadius = UDim.new(0, 11)
        ALPillCorner.Parent = ALPill

        local ALKnob = Instance.new("Frame")
        ALKnob.Name = "Knob"
        ALKnob.Size = UDim2.new(0, 16, 0, 16)
        ALKnob.Position = UDim2.new(0, 3, 0.5, -8)
        ALKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ALKnob.BorderSizePixel = 0
        ALKnob.Parent = ALPill

        local ALKnobCorner = Instance.new("UICorner")
        ALKnobCorner.CornerRadius = UDim.new(0, 8)
        ALKnobCorner.Parent = ALKnob

        local ALHit = Instance.new("TextButton")
        ALHit.Size = UDim2.new(0, 52, 1, 0)
        ALHit.Position = UDim2.new(1, -56, 0, 0)
        ALHit.BackgroundTransparency = 1
        ALHit.Text = ""
        ALHit.Parent = ALSection

        -- Animation Logger Frame (scrolling log) - positioned below toggle
        local ALLogFrame = Instance.new("Frame")
        ALLogFrame.Name = "AnimLogFrame"
        ALLogFrame.Size = UDim2.new(1, 0, 0, 0)
        ALLogFrame.Position = UDim2.new(0, 0, 0, 52)
        ALLogFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        ALLogFrame.BackgroundTransparency = 0.3
        ALLogFrame.BorderSizePixel = 0
        ALLogFrame.Visible = false
        ALLogFrame.Parent = SettingsPanel

        local ALLogCorner = Instance.new("UICorner")
        ALLogCorner.CornerRadius = UDim.new(0, 8)
        ALLogCorner.Parent = ALLogFrame

        local ALLogScroll = Instance.new("ScrollingFrame")
        ALLogScroll.Size = UDim2.new(1, -8, 1, -8)
        ALLogScroll.Position = UDim2.new(0, 4, 0, 4)
        ALLogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        ALLogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        ALLogScroll.BackgroundTransparency = 1
        ALLogScroll.BorderSizePixel = 0
        ALLogScroll.ScrollBarThickness = 3
        ALLogScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
        ALLogScroll.Parent = ALLogFrame

        local ALLogHolder = Instance.new("Frame")
        ALLogHolder.Size = UDim2.new(1, 0, 0, 0)
        ALLogHolder.AutomaticSize = Enum.AutomaticSize.Y
        ALLogHolder.BackgroundTransparency = 1
        ALLogHolder.Parent = ALLogScroll

        local ALLogLayout = Instance.new("UIListLayout")
        ALLogLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ALLogLayout.Padding = UDim.new(0, 4)
        ALLogLayout.Parent = ALLogHolder

        local ALLogPadding = Instance.new("UIPadding")
        ALLogPadding.PaddingTop = UDim.new(0, 4)
        ALLogPadding.PaddingBottom = UDim.new(0, 4)
        ALLogPadding.PaddingLeft = UDim.new(0, 4)
        ALLogPadding.PaddingRight = UDim.new(0, 4)
        ALLogPadding.Parent = ALLogHolder

        -- Animation Logger State
        local animLoggerEnabled = false
        local animLogEntries = {}
        local animLogSeenIds = {}
        local animLogCount = 0
        local MAX_ANIM_LOG = 50
        local ANIM_ENTRY_H = 36
        local animLogConn = nil

        local function UpdateALLogFrameHeight()
            local h = math.min(#animLogEntries, 4) * (ANIM_ENTRY_H + 4) + 12
            ALLogFrame.Size = UDim2.new(1, 0, 0, math.max(h, 24))
        end

        local function AddAnimLogEntry(idNum)
            if not idNum or idNum == "" then return end
            if animLogSeenIds[idNum] then return end
            animLogSeenIds[idNum] = true

            animLogCount = animLogCount + 1

            local entry = Instance.new("Frame")
            entry.Size = UDim2.new(1, 0, 0, ANIM_ENTRY_H)
            entry.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            entry.BorderSizePixel = 0
            entry.LayoutOrder = animLogCount
            entry.Parent = ALLogHolder

            local entryCorner = Instance.new("UICorner")
            entryCorner.CornerRadius = UDim.new(0, 6)
            entryCorner.Parent = entry

            local entryStroke = Instance.new("UIStroke")
            entryStroke.Color = Color3.fromRGB(50, 50, 50)
            entryStroke.Thickness = 1
            entryStroke.Parent = entry

            table.insert(animLogEntries, entry)

            if #animLogEntries > MAX_ANIM_LOG then
                local oldest = table.remove(animLogEntries, 1)
                if oldest and oldest.Parent then oldest:Destroy() end
            end

            local timestamp = Instance.new("TextLabel")
            timestamp.Size = UDim2.new(0, 52, 0, 12)
            timestamp.Position = UDim2.new(1, -50, 0, 6)
            timestamp.BackgroundTransparency = 1
            timestamp.Text = os.date("%H:%M:%S")
            timestamp.TextColor3 = Color3.fromRGB(150, 150, 150)
            timestamp.Font = Enum.Font.Gotham
            timestamp.TextSize = 9
            timestamp.TextXAlignment = Enum.TextXAlignment.Center
            timestamp.ZIndex = 3
            timestamp.Parent = entry

            local idLabel = Instance.new("TextLabel")
            idLabel.Size = UDim2.new(1, -100, 1, 0)
            idLabel.Position = UDim2.new(0, 8, 0, 0)
            idLabel.BackgroundTransparency = 1
            idLabel.Text = "ID: " .. idNum
            idLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            idLabel.Font = Enum.Font.Gotham
            idLabel.TextSize = 11
            idLabel.TextXAlignment = Enum.TextXAlignment.Left
            idLabel.Parent = entry

            local copyLinkBtn = Instance.new("TextButton")
            copyLinkBtn.Size = UDim2.new(0, 82, 0, 24)
            copyLinkBtn.Position = UDim2.new(1, -86, 0.5, -12)
            copyLinkBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            copyLinkBtn.Text = "Copy ID"
            copyLinkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            copyLinkBtn.Font = Enum.Font.GothamSemibold
            copyLinkBtn.TextSize = 10
            copyLinkBtn.BorderSizePixel = 0
            copyLinkBtn.AutoButtonColor = false
            copyLinkBtn.ZIndex = 4
            copyLinkBtn.Parent = entry

            local copyLinkCorner = Instance.new("UICorner")
            copyLinkCorner.CornerRadius = UDim.new(0, 5)
            copyLinkCorner.Parent = copyLinkBtn

            copyLinkBtn.MouseEnter:Connect(function()
                TweenService:Create(copyLinkBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
            end)
            copyLinkBtn.MouseLeave:Connect(function()
                TweenService:Create(copyLinkBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
            end)
            copyLinkBtn.MouseButton1Click:Connect(function()
                pcall(function() setclipboard(idNum) end)
                copyLinkBtn.Text = "Copied"
                task.delay(1.5, function()
                    if copyLinkBtn and copyLinkBtn.Parent then copyLinkBtn.Text = "Copy ID" end
                end)
            end)

            UpdateALLogFrameHeight()
        end

        local function HookAnimLogger(char)
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local animator = hum:FindFirstChildOfClass("Animator")
            if not animator then return end

            if animLogConn then animLogConn:Disconnect(); animLogConn = nil end

            animLogConn = animator.AnimationPlayed:Connect(function(animTrack)
                if not animLoggerEnabled then return end
                local animId = animTrack.Animation.AnimationId
                local cleanId = animId:gsub("rbxassetid://", "")
                cleanId = cleanId:gsub("http://www%.roblox%.com/asset/%?id=", "")
                cleanId = cleanId:gsub("https://www%.roblox%.com/asset/%?id=", "")
                cleanId = cleanId:gsub("www%.roblox%.com/.*", "")
                AddAnimLogEntry(cleanId)
            end)
        end

        local function SetAnimLogger(enabled)
            animLoggerEnabled = enabled
            ALLogFrame.Visible = enabled

            if not enabled then
                if animLogConn then animLogConn:Disconnect(); animLogConn = nil end
                return
            end

            local char = LocalPlayer.Character
            if char then
                task.spawn(function()
                    task.wait(0.1)
                    if animLoggerEnabled then HookAnimLogger(char) end
                end)
            end

            if animLogConn then animLogConn:Disconnect(); animLogConn = nil end
            animLogConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
                task.wait(0.5)
                if animLoggerEnabled then HookAnimLogger(newChar) end
            end)
        end

        local function SetAL(val)
            animLoggerEnabled = val
            SetAnimLogger(animLoggerEnabled)

            if val then
                TweenService:Create(ALPill, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
                TweenService:Create(ALKnob, TweenInfo.new(0.15), {Position = UDim2.new(1, -19, 0.5, -8)}):Play()
            else
                TweenService:Create(ALPill, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
                TweenService:Create(ALKnob, TweenInfo.new(0.15), {Position = UDim2.new(0, 3, 0.5, -8)}):Play()
            end
        end

        ALHit.MouseButton1Click:Connect(function() SetAL(not animLoggerEnabled) end)

        -- Favorites functions
        local function isFavorite(emoteId)
            return PM.Emotes.favorites[tostring(emoteId)] == true
        end

        local function toggleFavorite(emoteId)
            local id = tostring(emoteId)
            if PM.Emotes.favorites[id] then
                PM.Emotes.favorites[id] = nil
                SaveEmotesFavorites()
                return false
            else
                PM.Emotes.favorites[id] = true
                SaveEmotesFavorites()
                return true
            end
        end

        -- Create emote row
        local function createEmoteRow(emote, index)
            local row = Instance.new("Frame")
            row.Name = tostring(emote.id)
            row.Size = UDim2.new(1, 0, 0, 32)
            row.BackgroundTransparency = 1
            row.LayoutOrder = index

            local nameBtn = Instance.new("TextButton")
            nameBtn.Name = "NameBtn"
            nameBtn.Size = UDim2.new(1, -40, 1, 0)
            nameBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            nameBtn.BackgroundTransparency = 0.5
            nameBtn.BorderSizePixel = 0
            nameBtn.Text = emote.name
            nameBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameBtn.TextSize = 11
            nameBtn.Font = Enum.Font.Gotham
            nameBtn.TextXAlignment = Enum.TextXAlignment.Left
            nameBtn.Parent = row

            local nameCorner = Instance.new("UICorner")
            nameCorner.CornerRadius = UDim.new(0, 6)
            nameCorner.Parent = nameBtn

            local favBtn = Instance.new("TextButton")
            favBtn.Name = "Fav"
            favBtn.Size = UDim2.new(0, 32, 1, 0)
            favBtn.Position = UDim2.new(1, -32, 0, 0)
            favBtn.BackgroundTransparency = 1
            local emoteIsFav = isFavorite(emote.id)
            favBtn.Text = emoteIsFav and "★" or "☆"
            favBtn.TextColor3 = emoteIsFav and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(120, 120, 120)
            favBtn.TextSize = 16
            favBtn.Font = Enum.Font.GothamBold
            favBtn.Parent = row

            nameBtn.MouseEnter:Connect(function()
                nameBtn.BackgroundTransparency = 0.3
            end)
            nameBtn.MouseLeave:Connect(function()
                nameBtn.BackgroundTransparency = 0.5
            end)

            nameBtn.MouseButton1Click:Connect(function()
                local char = LocalPlayer.Character
                if not char then return end
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if not humanoid then return end

                pcall(function()
                    local desc = humanoid:FindFirstChildOfClass("HumanoidDescription") or Instance.new("HumanoidDescription")
                    desc.Parent = humanoid
                    desc:AddEmote(emote.name, emote.id)
                    humanoid:PlayEmoteAndGetAnimTrackById(emote.id)
                end)
            end)

            favBtn.MouseButton1Click:Connect(function()
                local nowFav = toggleFavorite(emote.id)
                favBtn.Text = nowFav and "★" or "☆"
                favBtn.TextColor3 = nowFav and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(120, 120, 120)
            end)

            return row
        end

        -- Lazy Loading
        local visibleEmotes = {}
        local loadedRows = {}
        local BATCH_SIZE = 20
        local ROW_HEIGHT = 36
        local isLoading = false

        local function updateVisibleEmotes(searchTerm)
            visibleEmotes = {}
            searchTerm = searchTerm:lower()

            for i, emote in ipairs(emotesData) do
                local matchesSearch = searchTerm == "" or emote.name:lower():find(searchTerm, 1, true)

                if currentTab == "Favorites" then
                    if isFavorite(emote.id) and matchesSearch then
                        table.insert(visibleEmotes, {emote = emote, index = i})
                    end
                else
                    if matchesSearch then
                        table.insert(visibleEmotes, {emote = emote, index = i})
                    end
                end
            end

            for _, row in ipairs(loadedRows) do
                row:Destroy()
            end
            loadedRows = {}

            ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
            StatusLabel.Text = #visibleEmotes .. " emotes found"
        end

        local function loadBatch(startIdx, count)
            if isLoading then return end
            isLoading = true

            local endIdx = math.min(startIdx + count - 1, #visibleEmotes)
            for i = startIdx, endIdx do
                local item = visibleEmotes[i]
                if item then
                    local row = createEmoteRow(item.emote, item.index)
                    row.Parent = ScrollFrame
                    table.insert(loadedRows, row)
                end
            end

            local loadedHeight = #loadedRows * ROW_HEIGHT
            ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, loadedHeight)

            isLoading = false
        end

        local function checkLoadMore()
            if isLoading or #loadedRows >= #visibleEmotes then return end

            local scrollPos = ScrollFrame.CanvasPosition.Y
            local viewHeight = ScrollFrame.AbsoluteWindowSize.Y
            local canvasHeight = ScrollFrame.CanvasSize.Y.Offset

            local buffer = ROW_HEIGHT * BATCH_SIZE * 2
            if scrollPos + viewHeight + buffer > canvasHeight then
                loadBatch(#loadedRows + 1, BATCH_SIZE)
            end
        end

        -- Initial load
        updateVisibleEmotes("")
        loadBatch(1, BATCH_SIZE)
        SettingsPanel.Visible = false

        -- Tab handlers
        for tabName, tabBtn in pairs(TabButtons) do
            tabBtn.MouseButton1Click:Connect(function()
                currentTab = tabName
                for name, btn in pairs(TabButtons) do
                    btn.BackgroundTransparency = (name == tabName) and 0.1 or 0.7
                    btn.TextColor3 = (name == tabName) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
                end

                if tabName == "Settings" then
                    ScrollFrame.Visible = false
                    SettingsPanel.Visible = true
                    SearchBox.Visible = false
                    BottomBar.Visible = false
                else
                    ScrollFrame.Visible = true
                    SettingsPanel.Visible = false
                    SearchBox.Visible = true
                    BottomBar.Visible = true
                    updateVisibleEmotes(SearchBox.Text)
                    loadBatch(1, BATCH_SIZE)
                    ScrollFrame.CanvasPosition = Vector2.new(0, 0)
                end
            end)
        end

        -- Search debounce
        local searchPending = false
        local searchThread = nil
        SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
            if not SearchBox.Visible then return end
            searchPending = true
            if searchThread then
                pcall(function() task.cancel(searchThread) end)
            end
            searchThread = task.delay(0.3, function()
                if searchPending then
                    searchPending = false
                    updateVisibleEmotes(SearchBox.Text)
                    loadBatch(1, BATCH_SIZE)
                    ScrollFrame.CanvasPosition = Vector2.new(0, 0)
                end
            end)
        end)

        -- Scroll check
        RunService.Heartbeat:Connect(function()
            if ScrollFrame.Visible then
                checkLoadMore()
            end
        end)
    end)

    if not success then
        -- Silent fail
    end
end)

-- Infinite baseplate state management
PM.BP = {
    active = false,
    connection = nil,
    chunks = {},
    folders = {}
}

registerCommand("infinitebaseplate", "Procedural infinite baseplate", {}, function(args)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer

    -- Toggle off if already running
    if PM.BP.active then
        PM.BP.active = false
        if PM.BP.connection then PM.BP.connection:Disconnect(); PM.BP.connection = nil end
        local f = workspace:FindFirstChild("PrismBaseplateFolder")
        if f then pcall(function() f:Destroy() end) end
        PM.BP.chunks = {}
        PM.BP.folders = {}
        return
    end

    -- Settings
    local BP_COLOR = Color3.fromRGB(115, 231, 117)
    local BP_MATERIAL = Enum.Material.Grass
    local BP_TILE = 256
    local BP_CHUNK = 8
    local BP_RENDER = 2
    local BP_UNLOAD = 3

    PM.BP.chunks = {}
    PM.BP.folders = {}

    local function BPGetFolder()
        local f = workspace:FindFirstChild("PrismBaseplateFolder")
        if not f then f = Instance.new("Folder"); f.Name = "PrismBaseplateFolder"; f.Parent = workspace end
        return f
    end

    local baseY = -0.001

    local function BPGenChunk(cx, cz)
        local key = cx .. "," .. cz
        if PM.BP.chunks[key] then return end
        PM.BP.chunks[key] = true
        local folder = Instance.new("Folder")
        folder.Name = "PrismChunk_" .. key
        folder.Parent = BPGetFolder()
        PM.BP.folders[key] = folder
        for x = 0, BP_CHUNK - 1 do
            for z = 0, BP_CHUNK - 1 do
                local part = Instance.new("Part")
                part.Name = "PrismTile"
                part.Anchored = true
                part.Locked = true
                part.Size = Vector3.new(BP_TILE, 5, BP_TILE)
                part.Position = Vector3.new((cx * BP_CHUNK + x) * BP_TILE, baseY - 2.5, (cz * BP_CHUNK + z) * BP_TILE)
                part.Material = BP_MATERIAL
                part.Color = BP_COLOR
                part.Transparency = 0
                part.CanCollide = true
                part.TopSurface = Enum.SurfaceType.Smooth
                part.BottomSurface = Enum.SurfaceType.Smooth
                part.Parent = folder
            end
        end
    end

    local function BPUnloadFar(cx, cz)
        for key in pairs(PM.BP.chunks) do
            local x, z = key:match("([^,]+),([^,]+)")
            x, z = tonumber(x), tonumber(z)
            if math.abs(x - cx) > BP_UNLOAD or math.abs(z - cz) > BP_UNLOAD then
                if PM.BP.folders[key] then PM.BP.folders[key]:Destroy(); PM.BP.folders[key] = nil end
                PM.BP.chunks[key] = nil
            end
        end
    end

    local function BPUpdate()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local pos = root.Position
        local cx = math.floor(pos.X / (BP_TILE * BP_CHUNK))
        local cz = math.floor(pos.Z / (BP_TILE * BP_CHUNK))
        for x = -BP_RENDER, BP_RENDER do
            for z = -BP_RENDER, BP_RENDER do
                BPGenChunk(cx + x, cz + z)
            end
        end
        BPUnloadFar(cx, cz)
    end

    PM.BP.active = true
    PM.BP.connection = RunService.Heartbeat:Connect(function()
        if PM.BP.active then BPUpdate() end
    end)
end)

-- Cleanup infinite baseplate on destroy
local oldDestroy = PM.Commands["destroy"].execute
PM.Commands["destroy"].execute = function(args)
    if PM.BP.active then
        PM.BP.active = false
        if PM.BP.connection then PM.BP.connection:Disconnect(); PM.BP.connection = nil end
        local f = workspace:FindFirstChild("PrismBaseplateFolder")
        if f then pcall(function() f:Destroy() end) end
        PM.BP.chunks = {}
        PM.BP.folders = {}
    end
    if PM.HB and PM.HB.active then
        PM.HB.active = false
        if PM.HB.renderConn then PM.HB.renderConn:Disconnect(); PM.HB.renderConn = nil end
        if PM.HB.jumpConn then PM.HB.jumpConn:Disconnect(); PM.HB.jumpConn = nil end
    end
    return oldDestroy(args)
end

-- Hamster ball state management
PM.HB = {
    active = false,
    ballSize = 6,
    renderConn = nil,
    jumpConn = nil,
    origShape = nil,
    origSize = nil,
    origTransp = nil,
    origCollide = nil,
    origCamSubj = nil,
    soundVols = {},
    partCollide = {}
}

-- Load saved hamsterball settings
local HB_SAVE_FILE = "prism/prism_hb_settings.json"
local savedHBSettings = {}
pcall(function()
    if readfile and isfile(HB_SAVE_FILE) then
        savedHBSettings = game:GetService("HttpService"):JSONDecode(readfile(HB_SAVE_FILE))
    end
end)
PM.HB.ballSize = savedHBSettings.ballSize or 6

local function SaveHBSettings()
    pcall(function()
        if writefile then
            if makefolder and not isfolder("prism") then makefolder("prism") end
            writefile(HB_SAVE_FILE, game:GetService("HttpService"):JSONEncode({ballSize = PM.HB.ballSize}))
        end
    end)
end

registerCommand("hamsterball", "Roll around in a ball", {}, function(args)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")
    local LocalPlayer = Players.LocalPlayer

    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_HamsterBallGUI") then return end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Prism_HamsterBallGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 1000
    ScreenGui.DisplayOrder = 999

    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
    elseif gethui then
        ScreenGui.Parent = gethui()
    else
        ScreenGui.Parent = CoreGui
    end

    -- Load saved GUI settings
    local HB_GUI_FILE = "prism/prism_hb_gui_settings.json"
    local savedHBGUI = {}
    pcall(function()
        if readfile and isfile(HB_GUI_FILE) then
            savedHBGUI = game:GetService("HttpService"):JSONDecode(readfile(HB_GUI_FILE))
        end
    end)
    local savedPos = savedHBGUI.position or {X = {Scale = 0, Offset = 940}, Y = {Scale = 0, Offset = 320}}
    local savedMinimized = savedHBGUI.minimized or false

    local currentHBSettings = {
        position = savedPos,
        minimized = savedMinimized
    }

    local function SaveHBGUISettings()
        pcall(function()
            if writefile then
                if makefolder and not isfolder("prism") then makefolder("prism") end
                writefile(HB_GUI_FILE, game:GetService("HttpService"):JSONEncode(currentHBSettings))
            end
        end)
    end

    local MW, MH = 239, 148

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, MW, 0, MH)
    MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
    MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    MainFrame.BackgroundTransparency = 0.3
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 14)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(60, 60, 60)
    MainStroke.Thickness = 1
    MainStroke.Parent = MainFrame

    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundTransparency = 1
    TitleBar.Parent = MainFrame

    local dragging = false
    local dragStart = nil
    local startPos = nil

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)

    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            currentHBSettings.position = {
                X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
            }
            SaveHBGUISettings()
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -80, 1, 0)
    TitleLabel.Position = UDim2.new(0, 14, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "Prism  •  Hamster Ball"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 13
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 24, 0, 24)
    MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
    MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MinBtn.BackgroundTransparency = 0.4
    MinBtn.BorderSizePixel = 0
    MinBtn.Text = "—"
    MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    MinBtn.TextSize = 11
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.Parent = TitleBar

    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 6)
    MinCorner.Parent = MinBtn

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 24, 0, 24)
    CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    CloseBtn.BackgroundTransparency = 0.4
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    CloseBtn.TextSize = 11
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = TitleBar

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn

    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "Content"
    ContentFrame.Size = UDim2.new(1, 0, 1, -44)
    ContentFrame.Position = UDim2.new(0, 0, 0, 44)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ClipsDescendants = true
    ContentFrame.Parent = MainFrame

    local isMinimized = savedMinimized
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    if isMinimized then
        MinBtn.Text = "+"
        MainFrame.Size = UDim2.new(0, MW, 0, 40)
        ContentFrame.Visible = false
    end

    MinBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        currentHBSettings.minimized = isMinimized
        SaveHBGUISettings()
        if isMinimized then
            MinBtn.Text = "+"
            local tween = TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, MW, 0, 40)})
            tween:Play()
            tween.Completed:Connect(function() ContentFrame.Visible = false end)
        else
            MinBtn.Text = "—"
            ContentFrame.Visible = true
            TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, MW, 0, MH)}):Play()
        end
    end)

    local ListLayout = Instance.new("UIListLayout")
    ListLayout.Padding = UDim.new(0, 6)
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Parent = ContentFrame

    local Padding = Instance.new("UIPadding")
    Padding.PaddingTop = UDim.new(0, 4)
    Padding.PaddingBottom = UDim.new(0, 4)
    Padding.PaddingLeft = UDim.new(0, 8)
    Padding.PaddingRight = UDim.new(0, 8)
    Padding.Parent = ContentFrame

    -- HB functions
    local HB = PM.HB

    local function StopHamsterBall()
        HB.active = false
        if HB.renderConn then HB.renderConn:Disconnect(); HB.renderConn = nil end
        if HB.jumpConn then HB.jumpConn:Disconnect(); HB.jumpConn = nil end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local h = char and char:FindFirstChildOfClass("Humanoid")
        if root then
            pcall(function()
                root.Shape = HB.origShape or Enum.PartType.Block
                root.Size = HB.origSize or Vector3.new(2, 2, 1)
                root.Transparency = HB.origTransp or 1
                root.CanCollide = HB.origCollide or false
                root.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        for snd, vol in pairs(HB.soundVols) do pcall(function() snd.Volume = vol end) end
        HB.soundVols = {}
        for part, orig in pairs(HB.partCollide) do pcall(function() part.CanCollide = orig end) end
        HB.partCollide = {}
        if h then h.PlatformStand = false end
        local cam = workspace.CurrentCamera
        if HB.origCamSubj and cam then pcall(function() cam.CameraSubject = HB.origCamSubj end) end
    end

    local function StartHamsterBall()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local h = char and char:FindFirstChildOfClass("Humanoid")
        if not root then return end
        local cam = workspace.CurrentCamera
        HB.origShape = root.Shape
        HB.origSize = root.Size
        HB.origTransp = root.Transparency
        HB.origCollide = root.CanCollide
        HB.origCamSubj = cam and cam.CameraSubject
        HB.soundVols = {}
        pcall(function()
            for _, snd in ipairs(root:GetChildren()) do
                if snd:IsA("Sound") then HB.soundVols[snd] = snd.Volume; snd.Volume = 0 end
            end
        end)
        HB.partCollide = {}
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part ~= root then
                HB.partCollide[part] = part.CanCollide; part.CanCollide = false
            end
        end
        root.Shape = Enum.PartType.Ball
        root.Size = Vector3.new(HB.ballSize, HB.ballSize, HB.ballSize)
        root.Transparency = 1
        root.CanCollide = true
        if h then h.PlatformStand = true end
        if cam then cam.CameraSubject = root end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}
        HB.renderConn = RunService.RenderStepped:Connect(function(delta)
            local c2 = LocalPlayer.Character
            local r = c2 and c2:FindFirstChild("HumanoidRootPart")
            if not r then StopHamsterBall(); return end
            r.CanCollide = true
            if UserInputService:GetFocusedTextBox() then return end
            local spd = 30
            local camCF = workspace.CurrentCamera.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then r.AssemblyAngularVelocity = r.AssemblyAngularVelocity - camCF.RightVector * delta * spd end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then r.AssemblyAngularVelocity = r.AssemblyAngularVelocity + camCF.RightVector * delta * spd end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then r.AssemblyAngularVelocity = r.AssemblyAngularVelocity - camCF.LookVector * delta * spd end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then r.AssemblyAngularVelocity = r.AssemblyAngularVelocity + camCF.LookVector * delta * spd end
        end)
        HB.jumpConn = UserInputService.JumpRequest:Connect(function()
            local c2 = LocalPlayer.Character
            local r = c2 and c2:FindFirstChild("HumanoidRootPart")
            if not r then return end
            local groundCheck = workspace:Raycast(r.Position, Vector3.new(0, -((r.Size.Y * 0.5) + 0.4), 0), params)
            if groundCheck then
                r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, 50, r.AssemblyLinearVelocity.Z)
            end
        end)
        HB.active = true
    end

    -- Toggle row
    local ToggleRow = Instance.new("Frame")
    ToggleRow.Size = UDim2.new(1, 0, 0, 32)
    ToggleRow.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    ToggleRow.BackgroundTransparency = 0.4
    ToggleRow.BorderSizePixel = 0
    ToggleRow.LayoutOrder = 1
    ToggleRow.Parent = ContentFrame

    local TRC = Instance.new("UICorner")
    TRC.CornerRadius = UDim.new(0, 10)
    TRC.Parent = ToggleRow

    local TRP = Instance.new("UIPadding")
    TRP.PaddingLeft = UDim.new(0, 12)
    TRP.PaddingRight = UDim.new(0, 12)
    TRP.Parent = ToggleRow

    local ToggleLbl = Instance.new("TextLabel")
    ToggleLbl.Size = UDim2.new(1, -48, 1, 0)
    ToggleLbl.BackgroundTransparency = 1
    ToggleLbl.Text = "Enable"
    ToggleLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    ToggleLbl.TextSize = 12
    ToggleLbl.Font = Enum.Font.Gotham
    ToggleLbl.TextXAlignment = Enum.TextXAlignment.Left
    ToggleLbl.Parent = ToggleRow

    -- Grey toggle matching other Prism toggles
    local Pill = Instance.new("Frame")
    Pill.Size = UDim2.new(0, 40, 0, 22)
    Pill.Position = UDim2.new(1, -36, 0.5, -11)
    Pill.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    Pill.BorderSizePixel = 0
    Pill.Parent = ToggleRow

    local PillCorner = Instance.new("UICorner")
    PillCorner.CornerRadius = UDim.new(0, 11)
    PillCorner.Parent = Pill

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 16, 0, 16)
    Knob.Position = UDim2.new(0, 3, 0.5, -8)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    Knob.Parent = Pill

    local KnobC = Instance.new("UICorner")
    KnobC.CornerRadius = UDim.new(0, 8)
    KnobC.Parent = Knob

    local PillBtn = Instance.new("TextButton")
    PillBtn.Size = UDim2.new(1, 0, 1, 0)
    PillBtn.BackgroundTransparency = 1
    PillBtn.Text = ""
    PillBtn.Parent = Pill

    local function setHB(on)
        ToggleLbl.Text = on and "Disable" or "Enable"
        TweenService:Create(Pill, tweenInfo, {BackgroundColor3 = on and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(60, 60, 60)}):Play()
        TweenService:Create(Knob, tweenInfo, {Position = on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}):Play()
        if on then task.spawn(StartHamsterBall) else StopHamsterBall() end
    end
    PillBtn.MouseButton1Click:Connect(function() setHB(not HB.active) end)

    if HB.active then setHB(true) end

    -- Ball Size slider
    local Section = Instance.new("Frame")
    Section.Size = UDim2.new(1, 0, 0, 52)
    Section.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Section.BackgroundTransparency = 0.4
    Section.BorderSizePixel = 0
    Section.LayoutOrder = 2
    Section.Parent = ContentFrame

    local SC = Instance.new("UICorner")
    SC.CornerRadius = UDim.new(0, 10)
    SC.Parent = Section

    local SP2 = Instance.new("UIPadding")
    SP2.PaddingTop = UDim.new(0, 5)
    SP2.PaddingBottom = UDim.new(0, 5)
    SP2.Parent = Section

    local IL = Instance.new("UIListLayout")
    IL.Padding = UDim.new(0, 2)
    IL.SortOrder = Enum.SortOrder.LayoutOrder
    IL.Parent = Section

    local LabelRow = Instance.new("Frame")
    LabelRow.Size = UDim2.new(1, 0, 0, 20)
    LabelRow.BackgroundTransparency = 1
    LabelRow.LayoutOrder = 1
    LabelRow.Parent = Section

    local LP2 = Instance.new("UIPadding")
    LP2.PaddingLeft = UDim.new(0, 12)
    LP2.PaddingRight = UDim.new(0, 12)
    LP2.Parent = LabelRow

    local NameLbl = Instance.new("TextLabel")
    NameLbl.Size = UDim2.new(1, -60, 1, 0)
    NameLbl.BackgroundTransparency = 1
    NameLbl.Text = "Ball Size"
    NameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    NameLbl.TextSize = 12
    NameLbl.Font = Enum.Font.Gotham
    NameLbl.TextXAlignment = Enum.TextXAlignment.Left
    NameLbl.Parent = LabelRow

    local ValLbl = Instance.new("TextLabel")
    ValLbl.Size = UDim2.new(0, 55, 1, 0)
    ValLbl.Position = UDim2.new(1, -55, 0, 0)
    ValLbl.BackgroundTransparency = 1
    ValLbl.Text = tostring(HB.ballSize)
    ValLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
    ValLbl.TextSize = 11
    ValLbl.Font = Enum.Font.Gotham
    ValLbl.TextXAlignment = Enum.TextXAlignment.Right
    ValLbl.Parent = LabelRow

    local SliderRow = Instance.new("Frame")
    SliderRow.Size = UDim2.new(1, 0, 0, 18)
    SliderRow.BackgroundTransparency = 1
    SliderRow.LayoutOrder = 2
    SliderRow.Parent = Section

    local SRP = Instance.new("UIPadding")
    SRP.PaddingLeft = UDim.new(0, 12)
    SRP.PaddingRight = UDim.new(0, 12)
    SRP.Parent = SliderRow

    local SliderBg = Instance.new("Frame")
    SliderBg.Size = UDim2.new(1, 0, 0, 6)
    SliderBg.Position = UDim2.new(0, 0, 0.5, -3)
    SliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    SliderBg.BorderSizePixel = 0
    SliderBg.Active = true
    SliderBg.Parent = SliderRow

    local TkC = Instance.new("UICorner")
    TkC.CornerRadius = UDim.new(0, 3)
    TkC.Parent = SliderBg

    local initBallScale = (HB.ballSize - 2) / 28
    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new(initBallScale, 0, 1, 0)
    SliderFill.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    SliderFill.BorderSizePixel = 0
    SliderFill.Parent = SliderBg

    local FC = Instance.new("UICorner")
    FC.CornerRadius = UDim.new(0, 3)
    FC.Parent = SliderFill

    local SliderKnob = Instance.new("Frame")
    SliderKnob.Size = UDim2.new(0, 14, 0, 14)
    SliderKnob.Position = UDim2.new(initBallScale, 0, 0.5, 0)
    SliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SliderKnob.BorderSizePixel = 0
    SliderKnob.ZIndex = 3
    SliderKnob.Parent = SliderBg

    local KC = Instance.new("UICorner")
    KC.CornerRadius = UDim.new(0, 7)
    KC.Parent = SliderKnob

    local sliderDragging = false
    local function updateBallSize(value)
        HB.ballSize = math.clamp(math.floor(value + 0.5), 2, 30)
        local scale = (HB.ballSize - 2) / 28
        SliderFill.Size = UDim2.new(scale, 0, 1, 0)
        SliderKnob.Position = UDim2.new(scale, 0, 0.5, 0)
        ValLbl.Text = tostring(HB.ballSize)
        SaveHBSettings()
        if HB.active then
            local c2 = LocalPlayer.Character
            local r = c2 and c2:FindFirstChild("HumanoidRootPart")
            if r then r.Size = Vector3.new(HB.ballSize, HB.ballSize, HB.ballSize) end
        end
    end

    SliderKnob.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliderDragging = true end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliderDragging = false end end)
    UserInputService.InputChanged:Connect(function(i)
        if sliderDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
            updateBallSize(2 + rel * 28)
        end
    end)

    local lastClick2 = 0
    SliderBg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            local now = tick()
            if now - lastClick2 < 0.3 then updateBallSize(6); sliderDragging = false
            else
                local rel = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                updateBallSize(2 + rel * 28); sliderDragging = true
            end
            lastClick2 = now
        end
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        if HB.active then StopHamsterBall() end
        ScreenGui:Destroy()
    end)
end)

registerCommand("trip", "Trip your character", {}, function(args)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local CoreGui = game:GetService("CoreGui")
    local LocalPlayer = Players.LocalPlayer

    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_TripGUI") then return end

    local success, err = pcall(function()
        -- Load saved GUI settings
        local TRIP_GUI_FILE = "prism/prism_trip_gui_settings.json"
        local savedTripGUI = {}
        pcall(function()
            if readfile and isfile(TRIP_GUI_FILE) then
                savedTripGUI = HttpService:JSONDecode(readfile(TRIP_GUI_FILE))
            end
        end)
        local savedPos = savedTripGUI.position or {X = {Scale = 0, Offset = 900}, Y = {Scale = 0, Offset = 600}}
        local savedMinimized = savedTripGUI.minimized or false
        local savedKey = savedTripGUI.keybind

        local currentTripSettings = {
            position = savedPos,
            minimized = savedMinimized,
            keybind = savedKey
        }

        local function SaveTripGUISettings()
            pcall(function()
                if writefile then
                    if makefolder and not isfolder("prism") then makefolder("prism") end
                    writefile(TRIP_GUI_FILE, HttpService:JSONEncode(currentTripSettings))
                end
            end)
        end

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "Prism_TripGUI"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.DisplayOrder = 1000
        ScreenGui.DisplayOrder = 999

        local ok = pcall(function() ScreenGui.Parent = CoreGui end)
        if not ok then ScreenGui.Parent = LocalPlayer.PlayerGui end

        local MW, MH = 220, 88

        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, MW, 0, MH)
        MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
        MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        MainFrame.BackgroundTransparency = 0.3
        MainFrame.BorderSizePixel = 0
        MainFrame.ClipsDescendants = true
        MainFrame.Parent = ScreenGui

        local MainCorner = Instance.new("UICorner")
        MainCorner.CornerRadius = UDim.new(0, 14)
        MainCorner.Parent = MainFrame

        local MainStroke = Instance.new("UIStroke")
        MainStroke.Color = Color3.fromRGB(60, 60, 60)
        MainStroke.Thickness = 1
        MainStroke.Parent = MainFrame

        local TitleBar = Instance.new("Frame")
        TitleBar.Name = "TitleBar"
        TitleBar.Size = UDim2.new(1, 0, 0, 36)
        TitleBar.BackgroundTransparency = 1
        TitleBar.Parent = MainFrame

        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Name = "Title"
        TitleLabel.Size = UDim2.new(1, -80, 1, 0)
        TitleLabel.Position = UDim2.new(0, 14, 0, 0)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = "Prism  •  Trip"
        TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TitleLabel.TextSize = 13
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = TitleBar

        local MinBtn = Instance.new("TextButton")
        MinBtn.Name = "Minimize"
        MinBtn.Size = UDim2.new(0, 24, 0, 24)
        MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
        MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        MinBtn.BackgroundTransparency = 0.4
        MinBtn.BorderSizePixel = 0
        MinBtn.Text = "—"
        MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        MinBtn.TextSize = 11
        MinBtn.Font = Enum.Font.GothamBold
        MinBtn.Parent = TitleBar
        local MinCorner = Instance.new("UICorner")
        MinCorner.CornerRadius = UDim.new(0, 6)
        MinCorner.Parent = MinBtn

        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Name = "Close"
        CloseBtn.Size = UDim2.new(0, 24, 0, 24)
        CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        CloseBtn.BackgroundTransparency = 0.4
        CloseBtn.BorderSizePixel = 0
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        CloseBtn.TextSize = 11
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.Parent = TitleBar
        local CloseCorner = Instance.new("UICorner")
        CloseCorner.CornerRadius = UDim.new(0, 6)
        CloseCorner.Parent = CloseBtn

        -- Drag functionality
        local dragging = false
        local dragStart = nil
        local startPos = nil

        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
            end
        end)

        TitleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                currentTripSettings.position = {
                    X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                    Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
                }
                SaveTripGUISettings()
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        local ContentFrame = Instance.new("Frame")
        ContentFrame.Name = "Content"
        ContentFrame.Size = UDim2.new(1, 0, 1, -40)
        ContentFrame.Position = UDim2.new(0, 0, 0, 40)
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.ClipsDescendants = true
        ContentFrame.Parent = MainFrame

        local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local isMinimized = savedMinimized
        local originalSize = UDim2.new(0, MW, 0, MH)
        local minimizedSize = UDim2.new(0, MW, 0, 36)

        if isMinimized then
            MinBtn.Text = "+"
            MainFrame.Size = minimizedSize
            ContentFrame.Visible = false
        end

        MinBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            currentTripSettings.minimized = isMinimized
            SaveTripGUISettings()
            if isMinimized then
                MinBtn.Text = "+"
                TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize}):Play()
                ContentFrame.Visible = false
            else
                MinBtn.Text = "—"
                ContentFrame.Visible = true
                TweenService:Create(MainFrame, tweenInfo, {Size = originalSize}):Play()
            end
        end)

        local Padding = Instance.new("UIPadding")
        Padding.PaddingTop = UDim.new(0, 4)
        Padding.PaddingBottom = UDim.new(0, 4)
        Padding.PaddingLeft = UDim.new(0, 8)
        Padding.PaddingRight = UDim.new(0, 8)
        Padding.Parent = ContentFrame

        -- Trip logic
        local function DoTrip()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not hum or not root then return end
            hum:ChangeState(Enum.HumanoidStateType.FallingDown)
            root.AssemblyLinearVelocity = root.CFrame.LookVector * 30
        end

        local BtnSection = Instance.new("Frame")
        BtnSection.Name = "BtnSection"
        BtnSection.Size = UDim2.new(1, 0, 0, 36)
        BtnSection.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        BtnSection.BackgroundTransparency = 0.4
        BtnSection.BorderSizePixel = 0
        BtnSection.Parent = ContentFrame

        local BtnSectionCorner = Instance.new("UICorner")
        BtnSectionCorner.CornerRadius = UDim.new(0, 10)
        BtnSectionCorner.Parent = BtnSection

        local TripBtn = Instance.new("TextButton")
        TripBtn.Name = "TripBtn"
        TripBtn.Size = UDim2.new(0, 130, 0, 24)
        TripBtn.Position = UDim2.new(0, 6, 0.5, -12)
        TripBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        TripBtn.BackgroundTransparency = 0.4
        TripBtn.BorderSizePixel = 0
        TripBtn.Text = "Trip"
        TripBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        TripBtn.TextSize = 11
        TripBtn.Font = Enum.Font.GothamBold
        TripBtn.Parent = BtnSection

        local TripBtnCorner = Instance.new("UICorner")
        TripBtnCorner.CornerRadius = UDim.new(0, 6)
        TripBtnCorner.Parent = TripBtn

        local BindBtn = Instance.new("TextButton")
        BindBtn.Name = "BindBtn"
        BindBtn.Size = UDim2.new(0, 52, 0, 24)
        BindBtn.Position = UDim2.new(1, -58, 0.5, -12)
        BindBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        BindBtn.BackgroundTransparency = 0.4
        BindBtn.BorderSizePixel = 0
        BindBtn.Text = "Bind"
        BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        BindBtn.TextSize = 11
        BindBtn.Font = Enum.Font.GothamBold
        BindBtn.Parent = BtnSection

        local BindBtnCorner = Instance.new("UICorner")
        BindBtnCorner.CornerRadius = UDim.new(0, 6)
        BindBtnCorner.Parent = BindBtn

        -- Hover effects
        TripBtn.MouseEnter:Connect(function()
            TweenService:Create(TripBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(55, 55, 55)}):Play()
        end)
        TripBtn.MouseLeave:Connect(function()
            TweenService:Create(TripBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
        end)
        BindBtn.MouseEnter:Connect(function()
            TweenService:Create(BindBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(55, 55, 55)}):Play()
        end)
        BindBtn.MouseLeave:Connect(function()
            TweenService:Create(BindBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
        end)

        TripBtn.MouseButton1Click:Connect(function()
            DoTrip()
        end)

        -- Keybind button
        local tripKey = nil
        pcall(function()
            tripKey = Enum.KeyCode[savedKey]
        end)
        local tripCapturing = false
        local tripCaptureConn = nil
        local tripGlobalConn = nil

        local function UpdateBindDisplay()
            if tripKey then
                BindBtn.Text = tripKey.Name
            else
                BindBtn.Text = "Bind"
            end
        end
        UpdateBindDisplay()

        local function SaveTripKey()
            currentTripSettings.keybind = tripKey and tripKey.Name or "T"
            SaveTripGUISettings()
        end

        local function CancelCapture()
            tripCapturing = false
            tripKey = nil
            if tripCaptureConn then tripCaptureConn:Disconnect(); tripCaptureConn = nil end
            UpdateBindDisplay()
            SaveTripKey()
        end

        local function EnableGlobalTrip()
            if tripGlobalConn then return end
            tripGlobalConn = UserInputService.InputBegan:Connect(function(input, gpe)
                if gpe or tripCapturing then return end
                if UserInputService:GetFocusedTextBox() then return end
                if input.UserInputType == Enum.UserInputType.Keyboard and tripKey and input.KeyCode == tripKey then
                    DoTrip()
                end
            end)
        end

        BindBtn.MouseButton1Click:Connect(function()
            tripCapturing = true
            if tripGlobalConn then tripGlobalConn:Disconnect(); tripGlobalConn = nil end
            BindBtn.Text = "..."
            BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)

            if tripCaptureConn then tripCaptureConn:Disconnect() end
            tripCaptureConn = UserInputService.InputBegan:Connect(function(input, gpe)
                if gpe then return end
                if not tripCapturing then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    if input.KeyCode == Enum.KeyCode.Backspace then
                        tripKey = nil
                        tripCapturing = false
                        tripCaptureConn:Disconnect(); tripCaptureConn = nil
                        UpdateBindDisplay()
                        BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                        SaveTripKey()
                        EnableGlobalTrip()
                    else
                        tripKey = input.KeyCode
                        tripCapturing = false
                        tripCaptureConn:Disconnect(); tripCaptureConn = nil
                        UpdateBindDisplay()
                        BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                        SaveTripKey()
                        EnableGlobalTrip()
                    end
                elseif input.UserInputType == Enum.UserInputType.MouseButton1 or
                       input.UserInputType == Enum.UserInputType.MouseButton2 or
                       input.UserInputType == Enum.UserInputType.MouseButton3 then
                    CancelCapture()
                    BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                    EnableGlobalTrip()
                end
            end)
        end)

        EnableGlobalTrip()

        CloseBtn.MouseButton1Click:Connect(function()
            tripCapturing = false
            if tripCaptureConn then tripCaptureConn:Disconnect(); tripCaptureConn = nil end
            if tripGlobalConn then tripGlobalConn:Disconnect(); tripGlobalConn = nil end
            ScreenGui:Destroy()
        end)
    end)

    if not success then
        -- Failed to load trip GUI
    end
end)

registerCommand("gravity", "Control gravity", {}, function(args)
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")
    local LocalPlayer = LP

    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_GravityGUI") then return end

    local success, err = pcall(function()
        local GRAVITY_GUI_FILE = "prism/prism_gravity_gui_settings.json"
        local savedGrav = {}
        pcall(function()
            if readfile and isfile(GRAVITY_GUI_FILE) then
                savedGrav = HttpService:JSONDecode(readfile(GRAVITY_GUI_FILE))
            end
        end)
        local savedPos = savedGrav.position or {X = {Scale = 0, Offset = 900}, Y = {Scale = 0, Offset = 260}}
        local savedMinimized = savedGrav.minimized or false

        local currentGravSettings = {
            position = savedPos,
            minimized = savedMinimized
        }

        local function SaveGravGUISettings()
            pcall(function()
                if writefile then
                    if makefolder and not isfolder("prism") then makefolder("prism") end
                    writefile(GRAVITY_GUI_FILE, HttpService:JSONEncode(currentGravSettings))
                end
            end)
        end

        local defaultGravity = 196.2
        local currentGravity = savedGrav.value or workspace.Gravity
        if currentGravity == 0 then currentGravity = defaultGravity end
        workspace.Gravity = currentGravity

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "Prism_GravityGUI"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.DisplayOrder = 1000
        ScreenGui.DisplayOrder = 999

        local ok = pcall(function() ScreenGui.Parent = CoreGui end)
        if not ok then ScreenGui.Parent = LocalPlayer.PlayerGui end

        local MW, MH = 239, 120

        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, MW, 0, MH)
        MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
        MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        MainFrame.BackgroundTransparency = 0.3
        MainFrame.BorderSizePixel = 0
        MainFrame.ClipsDescendants = true
        MainFrame.Parent = ScreenGui

        local MainCorner = Instance.new("UICorner")
        MainCorner.CornerRadius = UDim.new(0, 14)
        MainCorner.Parent = MainFrame

        local MainStroke = Instance.new("UIStroke")
        MainStroke.Color = Color3.fromRGB(60, 60, 60)
        MainStroke.Thickness = 1
        MainStroke.Parent = MainFrame

        local TitleBar = Instance.new("Frame")
        TitleBar.Name = "TitleBar"
        TitleBar.Size = UDim2.new(1, 0, 0, 36)
        TitleBar.BackgroundTransparency = 1
        TitleBar.Parent = MainFrame

        local dragging = false
        local dragStart = nil
        local startPos = nil

        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
            end
        end)

        TitleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                currentGravSettings.position = {
                    X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                    Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
                }
                SaveGravGUISettings()
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Size = UDim2.new(1, -80, 1, 0)
        TitleLabel.Position = UDim2.new(0, 14, 0, 0)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = "Prism  •  Gravity"
        TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TitleLabel.TextSize = 13
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = TitleBar

        local MinBtn = Instance.new("TextButton")
        MinBtn.Size = UDim2.new(0, 24, 0, 24)
        MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
        MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        MinBtn.BackgroundTransparency = 0.4
        MinBtn.BorderSizePixel = 0
        MinBtn.Text = "—"
        MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        MinBtn.TextSize = 11
        MinBtn.Font = Enum.Font.GothamBold
        MinBtn.Parent = TitleBar
        local MinCorner = Instance.new("UICorner")
        MinCorner.CornerRadius = UDim.new(0, 6)
        MinCorner.Parent = MinBtn

        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Size = UDim2.new(0, 24, 0, 24)
        CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        CloseBtn.BackgroundTransparency = 0.4
        CloseBtn.BorderSizePixel = 0
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        CloseBtn.TextSize = 11
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.Parent = TitleBar
        local CloseCorner = Instance.new("UICorner")
        CloseCorner.CornerRadius = UDim.new(0, 6)
        CloseCorner.Parent = CloseBtn

        local ContentFrame = Instance.new("Frame")
        ContentFrame.Name = "Content"
        ContentFrame.Size = UDim2.new(1, 0, 1, -40)
        ContentFrame.Position = UDim2.new(0, 0, 0, 40)
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.ClipsDescendants = true
        ContentFrame.Parent = MainFrame

        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local isMinimized = savedMinimized
        local originalSize = UDim2.new(0, MW, 0, MH)
        local minimizedSize = UDim2.new(0, MW, 0, 36)

        if isMinimized then
            MinBtn.Text = "+"
            MainFrame.Size = minimizedSize
            ContentFrame.Visible = false
        end

        MinBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            currentGravSettings.minimized = isMinimized
            SaveGravGUISettings()
            if isMinimized then
                MinBtn.Text = "+"
                local tween = TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize})
                tween:Play()
                tween.Completed:Connect(function() ContentFrame.Visible = false end)
            else
                MinBtn.Text = "—"
                ContentFrame.Visible = true
                TweenService:Create(MainFrame, tweenInfo, {Size = originalSize}):Play()
            end
        end)

        -- Gravity loop (fights scripts overwriting)
        local gravLoopConn = nil
        local function startGravityLoop(value)
            if gravLoopConn then gravLoopConn:Disconnect(); gravLoopConn = nil end
            gravLoopConn = RunService.Heartbeat:Connect(function()
                if workspace.Gravity ~= value then
                    workspace.Gravity = value
                end
            end)
        end

        local ListLayout = Instance.new("UIListLayout")
        ListLayout.Padding = UDim.new(0, 6)
        ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ListLayout.Parent = ContentFrame

        local CPadding = Instance.new("UIPadding")
        CPadding.PaddingTop = UDim.new(0, 4)
        CPadding.PaddingBottom = UDim.new(0, 4)
        CPadding.PaddingLeft = UDim.new(0, 8)
        CPadding.PaddingRight = UDim.new(0, 8)
        CPadding.Parent = ContentFrame

        -- Gravity slider
        local Section = Instance.new("Frame")
        Section.Size = UDim2.new(1, 0, 0, 52)
        Section.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        Section.BackgroundTransparency = 0.4
        Section.BorderSizePixel = 0
        Section.LayoutOrder = 1
        Section.Parent = ContentFrame

        local SC = Instance.new("UICorner")
        SC.CornerRadius = UDim.new(0, 10)
        SC.Parent = Section

        local SP = Instance.new("UIPadding")
        SP.PaddingTop = UDim.new(0, 5)
        SP.PaddingBottom = UDim.new(0, 5)
        SP.Parent = Section

        local IL = Instance.new("UIListLayout")
        IL.Padding = UDim.new(0, 2)
        IL.SortOrder = Enum.SortOrder.LayoutOrder
        IL.Parent = Section

        local LabelRow = Instance.new("Frame")
        LabelRow.Size = UDim2.new(1, 0, 0, 20)
        LabelRow.BackgroundTransparency = 1
        LabelRow.LayoutOrder = 1
        LabelRow.Parent = Section

        local LP2 = Instance.new("UIPadding")
        LP2.PaddingLeft = UDim.new(0, 12)
        LP2.PaddingRight = UDim.new(0, 12)
        LP2.Parent = LabelRow

        local NameLbl = Instance.new("TextLabel")
        NameLbl.Size = UDim2.new(1, -60, 1, 0)
        NameLbl.BackgroundTransparency = 1
        NameLbl.Text = "Gravity"
        NameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        NameLbl.TextSize = 12
        NameLbl.Font = Enum.Font.Gotham
        NameLbl.TextXAlignment = Enum.TextXAlignment.Left
        NameLbl.Parent = LabelRow

        local ValLbl = Instance.new("TextLabel")
        ValLbl.Size = UDim2.new(0, 55, 1, 0)
        ValLbl.Position = UDim2.new(1, -55, 0, 0)
        ValLbl.BackgroundTransparency = 1
        ValLbl.Text = tostring(math.floor(currentGravity))
        ValLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
        ValLbl.TextSize = 11
        ValLbl.Font = Enum.Font.Gotham
        ValLbl.TextXAlignment = Enum.TextXAlignment.Right
        ValLbl.Parent = LabelRow

        local SliderRow = Instance.new("Frame")
        SliderRow.Size = UDim2.new(1, 0, 0, 18)
        SliderRow.BackgroundTransparency = 1
        SliderRow.LayoutOrder = 2
        SliderRow.Parent = Section

        local SRP = Instance.new("UIPadding")
        SRP.PaddingLeft = UDim.new(0, 12)
        SRP.PaddingRight = UDim.new(0, 12)
        SRP.Parent = SliderRow

        local SliderBg = Instance.new("Frame")
        SliderBg.Size = UDim2.new(1, 0, 0, 6)
        SliderBg.Position = UDim2.new(0, 0, 0.5, -3)
        SliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        SliderBg.BorderSizePixel = 0
        SliderBg.Active = true
        SliderBg.Parent = SliderRow

        local TkC = Instance.new("UICorner")
        TkC.CornerRadius = UDim.new(0, 3)
        TkC.Parent = SliderBg

        local initScale = math.clamp(currentGravity / 500, 0, 1)

        local SliderFill = Instance.new("Frame")
        SliderFill.Size = UDim2.new(initScale, 0, 1, 0)
        SliderFill.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        SliderFill.BorderSizePixel = 0
        SliderFill.Parent = SliderBg

        local FC = Instance.new("UICorner")
        FC.CornerRadius = UDim.new(0, 3)
        FC.Parent = SliderFill

        local SliderKnob = Instance.new("Frame")
        SliderKnob.Size = UDim2.new(0, 14, 0, 14)
        SliderKnob.Position = UDim2.new(initScale, 0, 0.5, 0)
        SliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
        SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        SliderKnob.BorderSizePixel = 0
        SliderKnob.ZIndex = 3
        SliderKnob.Parent = SliderBg

        local KC = Instance.new("UICorner")
        KC.CornerRadius = UDim.new(0, 7)
        KC.Parent = SliderKnob

        local sliderDragging = false
        local function updateGravity(value)
            currentGravity = math.clamp(math.floor(value + 0.5), 0, 500)
            local scale = currentGravity / 500
            SliderFill.Size = UDim2.new(scale, 0, 1, 0)
            SliderKnob.Position = UDim2.new(scale, 0, 0.5, 0)
            ValLbl.Text = tostring(currentGravity)
            workspace.Gravity = currentGravity
            startGravityLoop(currentGravity)
            currentGravSettings.value = currentGravity
            SaveGravGUISettings()
        end

        SliderKnob.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = true
            end
        end)

        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(i)
            if sliderDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local rel = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                updateGravity(rel * 500)
            end
        end)

        local lastClickGrav = 0
        SliderBg.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                local now = tick()
                if now - lastClickGrav < 0.3 then
                    updateGravity(defaultGravity)
                    sliderDragging = false
                else
                    local rel = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                    updateGravity(rel * 500)
                    sliderDragging = true
                end
                lastClickGrav = now
            end
        end)

        startGravityLoop(currentGravity)

        CloseBtn.MouseButton1Click:Connect(function()
            if gravLoopConn then gravLoopConn:Disconnect(); gravLoopConn = nil end
            workspace.Gravity = defaultGravity
            ScreenGui:Destroy()
        end)
    end)

    if not success then
        -- Failed to load gravity GUI
    end
end)

-- Autoclicker state management
PM.AC = {
    active = false,
    key = nil,
    connection = nil,
    keyConnection = nil
}

-- Load saved autoclicker key
local AC_SAVE_FILE = "prism/prism_ac_settings.json"
local savedACSettings = {}
pcall(function()
    if readfile and isfile(AC_SAVE_FILE) then
        savedACSettings = game:GetService("HttpService"):JSONDecode(readfile(AC_SAVE_FILE))
    end
end)
if savedACSettings.key then
    pcall(function()
        PM.AC.key = Enum.KeyCode[savedACSettings.key]
    end)
end

local function SaveACSettings()
    pcall(function()
        if writefile then
            if makefolder and not isfolder("prism") then makefolder("prism") end
            writefile(AC_SAVE_FILE, game:GetService("HttpService"):JSONEncode({
                key = PM.AC.key and PM.AC.key.Name or nil
            }))
        end
    end)
end

registerCommand("autoclicker", "Auto clicker with keybind", {}, function(args)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")
    local LocalPlayer = Players.LocalPlayer

    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_AutoClickerGUI") then return end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Prism_AutoClickerGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 1000
    ScreenGui.DisplayOrder = 999

    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
    elseif gethui then
        ScreenGui.Parent = gethui()
    else
        ScreenGui.Parent = CoreGui
    end

    -- Load saved GUI settings
    local AC_GUI_FILE = "prism/prism_ac_gui_settings.json"
    local savedACGUI = {}
    pcall(function()
        if readfile and isfile(AC_GUI_FILE) then
            savedACGUI = game:GetService("HttpService"):JSONDecode(readfile(AC_GUI_FILE))
        end
    end)
    local savedPos = savedACGUI.position or {X = {Scale = 0, Offset = 500}, Y = {Scale = 0, Offset = 500}}
    local savedMinimized = savedACGUI.minimized or false

    local currentACSettings = {
        position = savedPos,
        minimized = savedMinimized
    }

    local function SaveACGUISettings()
        pcall(function()
            if writefile then
                if makefolder and not isfolder("prism") then makefolder("prism") end
                writefile(AC_GUI_FILE, game:GetService("HttpService"):JSONEncode(currentACSettings))
            end
        end)
    end

    local MW, MH = 220, 88

    local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, MW, 0, MH)
    MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
    MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    MainFrame.BackgroundTransparency = 0.3
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 14)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(60, 60, 60)
    MainStroke.Thickness = 1
    MainStroke.Parent = MainFrame

    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 36)
    TitleBar.BackgroundTransparency = 1
    TitleBar.Parent = MainFrame

    local dragging = false
    local dragStart = nil
    local startPos = nil

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)

    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            currentACSettings.position = {
                X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
            }
            SaveACGUISettings()
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -80, 1, 0)
    TitleLabel.Position = UDim2.new(0, 14, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "Prism  •  Auto Clicker"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 13
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 24, 0, 24)
    MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
    MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MinBtn.BackgroundTransparency = 0.4
    MinBtn.BorderSizePixel = 0
    MinBtn.Text = "—"
    MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    MinBtn.TextSize = 11
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.Parent = TitleBar

    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 6)
    MinCorner.Parent = MinBtn

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 24, 0, 24)
    CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    CloseBtn.BackgroundTransparency = 0.4
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    CloseBtn.TextSize = 11
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = TitleBar

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn

    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "Content"
    ContentFrame.Size = UDim2.new(1, 0, 1, -40)
    ContentFrame.Position = UDim2.new(0, 0, 0, 40)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ClipsDescendants = true
    ContentFrame.Parent = MainFrame

    local Padding = Instance.new("UIPadding")
    Padding.PaddingTop = UDim.new(0, 4)
    Padding.PaddingBottom = UDim.new(0, 4)
    Padding.PaddingLeft = UDim.new(0, 8)
    Padding.PaddingRight = UDim.new(0, 8)
    Padding.Parent = ContentFrame

    local isMinimized = savedMinimized
    local minimizedSize = UDim2.new(0, MW, 0, 36)
    MinBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        currentACSettings.minimized = isMinimized
        SaveACGUISettings()
        if isMinimized then
            MinBtn.Text = "+"
            TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize}):Play()
            ContentFrame.Visible = false
        else
            MinBtn.Text = "—"
            ContentFrame.Visible = true
            TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, MW, 0, MH)}):Play()
        end
    end)

    if isMinimized then
        MinBtn.Text = "+"
        MainFrame.Size = minimizedSize
        ContentFrame.Visible = false
    end

    -- Autoclicker logic
    local acOn = false
    local acConn = nil
    local acKey = PM.AC.key
    local acCapturing = false
    local acCaptureConn = nil
    local acKeyConn = nil
    local acCountdownTask = nil

    -- Action Buttons
    local BtnSection = Instance.new("Frame")
    BtnSection.Name = "BtnSection"
    BtnSection.Size = UDim2.new(1, 0, 0, 36)
    BtnSection.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    BtnSection.BackgroundTransparency = 0.4
    BtnSection.BorderSizePixel = 0
    BtnSection.Parent = ContentFrame

    local BtnSectionCorner = Instance.new("UICorner")
    BtnSectionCorner.CornerRadius = UDim.new(0, 10)
    BtnSectionCorner.Parent = BtnSection

    local ACBtn = Instance.new("TextButton")
    ACBtn.Name = "ACBtn"
    ACBtn.Size = UDim2.new(0, 130, 0, 24)
    ACBtn.Position = UDim2.new(0, 6, 0.5, -12)
    ACBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    ACBtn.BackgroundTransparency = 0.4
    ACBtn.BorderSizePixel = 0
    ACBtn.Text = "Start"
    ACBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    ACBtn.TextSize = 11
    ACBtn.Font = Enum.Font.GothamBold
    ACBtn.Parent = BtnSection

    local ACBtnCorner = Instance.new("UICorner")
    ACBtnCorner.CornerRadius = UDim.new(0, 6)
    ACBtnCorner.Parent = ACBtn

    local BindBtn = Instance.new("TextButton")
    BindBtn.Name = "BindBtn"
    BindBtn.Size = UDim2.new(0, 52, 0, 24)
    BindBtn.Position = UDim2.new(1, -58, 0.5, -12)
    BindBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    BindBtn.BackgroundTransparency = 0.4
    BindBtn.BorderSizePixel = 0
    BindBtn.Text = "Bind"
    BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    BindBtn.TextSize = 11
    BindBtn.Font = Enum.Font.GothamBold
    BindBtn.Parent = BtnSection

    local BindBtnCorner = Instance.new("UICorner")
    BindBtnCorner.CornerRadius = UDim.new(0, 6)
    BindBtnCorner.Parent = BindBtn

    -- Hover effects
    ACBtn.MouseEnter:Connect(function()
        TweenService:Create(ACBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(55, 55, 55)}):Play()
    end)
    ACBtn.MouseLeave:Connect(function()
        TweenService:Create(ACBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
    end)

    BindBtn.MouseEnter:Connect(function()
        TweenService:Create(BindBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(55, 55, 55)}):Play()
    end)
    BindBtn.MouseLeave:Connect(function()
        TweenService:Create(BindBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
    end)

    -- Load saved key
    local function UpdateBindDisplay()
        if acKey then
            BindBtn.Text = acKey.Name
        else
            BindBtn.Text = "Bind"
        end
    end
    UpdateBindDisplay()

    local function SaveACKey()
        PM.AC.key = acKey
        SaveACSettings()
    end

    local function CancelCapture()
        acCapturing = false
        acKey = nil
        if acCaptureConn then acCaptureConn:Disconnect(); acCaptureConn = nil end
        UpdateBindDisplay()
        SaveACKey()
        EnableGlobalAC()
    end

    BindBtn.MouseButton1Click:Connect(function()
        acCapturing = true
        if acKeyConn then acKeyConn:Disconnect(); acKeyConn = nil end
        BindBtn.Text = "..."
        BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)

        if acCaptureConn then acCaptureConn:Disconnect() end
        acCaptureConn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if not acCapturing then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Backspace then
                    acKey = nil
                    acCapturing = false
                    acCaptureConn:Disconnect(); acCaptureConn = nil
                    UpdateBindDisplay()
                    BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                    SaveACKey()
                    EnableGlobalAC()
                else
                    acKey = input.KeyCode
                    acCapturing = false
                    acCaptureConn:Disconnect(); acCaptureConn = nil
                    UpdateBindDisplay()
                    BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                    SaveACKey()
                    EnableGlobalAC()
                end
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 or
                   input.UserInputType == Enum.UserInputType.MouseButton2 or
                   input.UserInputType == Enum.UserInputType.MouseButton3 then
                CancelCapture()
                BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                EnableGlobalAC()
            end
        end)
    end)

    -- Autoclicker functions
    local function StartAC()
        if acConn then return end
        acConn = task.spawn(function()
            while acOn do
                pcall(function()
                    if mouse1click then mouse1click() end
                end)
                task.wait()
            end
        end)
    end

    local function StopAC()
        acOn = false
        if acCountdownTask then
            pcall(function() task.cancel(acCountdownTask) end)
            acCountdownTask = nil
        end
        if acConn then task.cancel(acConn); acConn = nil end
    end

    local acCountingDown = false

    local function SetAC(val, fromKeybind)
        if val == acOn then return end
        acOn = val
        if val then
            if fromKeybind then
                ACBtn.Text = "End"
                StartAC()
            else
                acCountingDown = true
                acCountdownTask = task.spawn(function()
                    for i = 3, 1, -1 do
                        if not acOn then
                            acCountingDown = false
                            return
                        end
                        ACBtn.Text = tostring(i)
                        task.wait(1)
                    end
                    acCountingDown = false
                    if acOn then
                        ACBtn.Text = "End"
                        StartAC()
                    end
                end)
            end
        else
            ACBtn.Text = "Start"
            TweenService:Create(ACBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
            StopAC()
        end
    end

    ACBtn.MouseButton1Click:Connect(function()
        SetAC(not acOn, false)
    end)

    local function EnableGlobalAC()
        if acKeyConn then return end
        acKeyConn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe or acCapturing then return end
            if UserInputService:GetFocusedTextBox() then return end
            if input.UserInputType == Enum.UserInputType.Keyboard and acKey and input.KeyCode == acKey then
                SetAC(not acOn, true)
            end
        end)
    end

    EnableGlobalAC()

    CloseBtn.MouseButton1Click:Connect(function()
        acCapturing = false
        StopAC()
        if acCaptureConn then acCaptureConn:Disconnect(); acCaptureConn = nil end
        if acKeyConn then acKeyConn:Disconnect(); acKeyConn = nil end
        ScreenGui:Destroy()
    end)
end)

-- Noclip state management
PM.Noclip = {
    active = false,
    key = nil,
    connection = nil,
    keyConnection = nil,
    snapshot = {},
    noclipKey = nil
}

-- Load saved noclip key
local NC_SAVE_FILE = "prism/prism_nc_settings.json"
local savedNCSettings = {}
pcall(function()
    if readfile and isfile(NC_SAVE_FILE) then
        savedNCSettings = game:GetService("HttpService"):JSONDecode(readfile(NC_SAVE_FILE))
    end
end)
if savedNCSettings.key then
    pcall(function()
        PM.Noclip.key = Enum.KeyCode[savedNCSettings.key]
    end)
end

local function SaveNCSettings()
    pcall(function()
        if writefile then
            if makefolder and not isfolder("prism") then makefolder("prism") end
            writefile(NC_SAVE_FILE, game:GetService("HttpService"):JSONEncode({
                key = PM.Noclip.key and PM.Noclip.key.Name or nil
            }))
        end
    end)
end

registerCommand("noclip", "Noclip with keybind", {}, function(args)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")
    local LocalPlayer = Players.LocalPlayer

    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_NoclipGUI") then return end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Prism_NoclipGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 1000
    ScreenGui.DisplayOrder = 999

    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
    elseif gethui then
        ScreenGui.Parent = gethui()
    else
        ScreenGui.Parent = CoreGui
    end

    -- Load saved GUI settings
    local NC_GUI_FILE = "prism/prism_nc_gui_settings.json"
    local savedNCGUI = {}
    pcall(function()
        if readfile and isfile(NC_GUI_FILE) then
            savedNCGUI = game:GetService("HttpService"):JSONDecode(readfile(NC_GUI_FILE))
        end
    end)
    local savedPos = savedNCGUI.position or {X = {Scale = 0, Offset = 500}, Y = {Scale = 0, Offset = 400}}
    local savedMinimized = savedNCGUI.minimized or false

    local currentNCSettings = {
        position = savedPos,
        minimized = savedMinimized
    }

    local function SaveNCGUISettings()
        pcall(function()
            if writefile then
                if makefolder and not isfolder("prism") then makefolder("prism") end
                writefile(NC_GUI_FILE, game:GetService("HttpService"):JSONEncode(currentNCSettings))
            end
        end)
    end

    local MW, MH = 220, 88

    local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, MW, 0, MH)
    MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
    MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    MainFrame.BackgroundTransparency = 0.3
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 14)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(60, 60, 60)
    MainStroke.Thickness = 1
    MainStroke.Parent = MainFrame

    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 36)
    TitleBar.BackgroundTransparency = 1
    TitleBar.Parent = MainFrame

    local dragging = false
    local dragStart = nil
    local startPos = nil

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)

    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            currentNCSettings.position = {
                X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
            }
            SaveNCGUISettings()
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -80, 1, 0)
    TitleLabel.Position = UDim2.new(0, 14, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "Prism  •  Noclip"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 13
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 24, 0, 24)
    MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
    MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MinBtn.BackgroundTransparency = 0.4
    MinBtn.BorderSizePixel = 0
    MinBtn.Text = "—"
    MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    MinBtn.TextSize = 11
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.Parent = TitleBar

    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 6)
    MinCorner.Parent = MinBtn

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 24, 0, 24)
    CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    CloseBtn.BackgroundTransparency = 0.4
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    CloseBtn.TextSize = 11
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = TitleBar

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn

    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "Content"
    ContentFrame.Size = UDim2.new(1, 0, 1, -40)
    ContentFrame.Position = UDim2.new(0, 0, 0, 40)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ClipsDescendants = true
    ContentFrame.Parent = MainFrame

    local Padding = Instance.new("UIPadding")
    Padding.PaddingTop = UDim.new(0, 4)
    Padding.PaddingBottom = UDim.new(0, 4)
    Padding.PaddingLeft = UDim.new(0, 8)
    Padding.PaddingRight = UDim.new(0, 8)
    Padding.Parent = ContentFrame

    local isMinimized = savedMinimized
    local minimizedSize = UDim2.new(0, MW, 0, 36)
    MinBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        currentNCSettings.minimized = isMinimized
        SaveNCGUISettings()
        if isMinimized then
            MinBtn.Text = "+"
            TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize}):Play()
            ContentFrame.Visible = false
        else
            MinBtn.Text = "—"
            ContentFrame.Visible = true
            TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, MW, 0, MH)}):Play()
        end
    end)

    if isMinimized then
        MinBtn.Text = "+"
        MainFrame.Size = minimizedSize
        ContentFrame.Visible = false
    end

    -- Noclip logic
    local ncOn = false
    local ncKey = PM.Noclip.key
    local ncCapturing = false
    local ncCaptureConn = nil
    local ncKeyConn = nil

    -- Action Buttons
    local BtnSection = Instance.new("Frame")
    BtnSection.Name = "BtnSection"
    BtnSection.Size = UDim2.new(1, 0, 0, 36)
    BtnSection.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    BtnSection.BackgroundTransparency = 0.4
    BtnSection.BorderSizePixel = 0
    BtnSection.Parent = ContentFrame

    local BtnSectionCorner = Instance.new("UICorner")
    BtnSectionCorner.CornerRadius = UDim.new(0, 10)
    BtnSectionCorner.Parent = BtnSection

    local NCBtn = Instance.new("TextButton")
    NCBtn.Name = "NCBtn"
    NCBtn.Size = UDim2.new(0, 130, 0, 24)
    NCBtn.Position = UDim2.new(0, 6, 0.5, -12)
    NCBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    NCBtn.BackgroundTransparency = 0.4
    NCBtn.BorderSizePixel = 0
    NCBtn.Text = "Noclip"
    NCBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    NCBtn.TextSize = 11
    NCBtn.Font = Enum.Font.GothamBold
    NCBtn.Parent = BtnSection

    local NCBtnCorner = Instance.new("UICorner")
    NCBtnCorner.CornerRadius = UDim.new(0, 6)
    NCBtnCorner.Parent = NCBtn

    local BindBtn = Instance.new("TextButton")
    BindBtn.Name = "BindBtn"
    BindBtn.Size = UDim2.new(0, 52, 0, 24)
    BindBtn.Position = UDim2.new(1, -58, 0.5, -12)
    BindBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    BindBtn.BackgroundTransparency = 0.4
    BindBtn.BorderSizePixel = 0
    BindBtn.Text = "Bind"
    BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    BindBtn.TextSize = 11
    BindBtn.Font = Enum.Font.GothamBold
    BindBtn.Parent = BtnSection

    local BindBtnCorner = Instance.new("UICorner")
    BindBtnCorner.CornerRadius = UDim.new(0, 6)
    BindBtnCorner.Parent = BindBtn

    -- Hover effects
    NCBtn.MouseEnter:Connect(function()
        TweenService:Create(NCBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(55, 55, 55)}):Play()
    end)
    NCBtn.MouseLeave:Connect(function()
        TweenService:Create(NCBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
    end)

    BindBtn.MouseEnter:Connect(function()
        TweenService:Create(BindBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(55, 55, 55)}):Play()
    end)
    BindBtn.MouseLeave:Connect(function()
        TweenService:Create(BindBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
    end)

    -- Load saved key
    local function UpdateBindDisplay()
        if ncKey then
            BindBtn.Text = ncKey.Name
        else
            BindBtn.Text = "Bind"
        end
    end
    UpdateBindDisplay()

    local function SaveNCKey()
        PM.Noclip.key = ncKey
        SaveNCSettings()
    end

    local function CancelCapture()
        ncCapturing = false
        ncKey = nil
        if ncCaptureConn then ncCaptureConn:Disconnect(); ncCaptureConn = nil end
        UpdateBindDisplay()
        SaveNCKey()
        EnableGlobalNC()
    end

    BindBtn.MouseButton1Click:Connect(function()
        ncCapturing = true
        if PM.Noclip.keyConnection then PM.Noclip.keyConnection:Disconnect(); PM.Noclip.keyConnection = nil end
        BindBtn.Text = "..."
        BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)

        if ncCaptureConn then ncCaptureConn:Disconnect() end
        ncCaptureConn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if not ncCapturing then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Backspace then
                    ncKey = nil
                    ncCapturing = false
                    ncCaptureConn:Disconnect(); ncCaptureConn = nil
                    UpdateBindDisplay()
                    BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                    SaveNCKey()
                    EnableGlobalNC()
                else
                    ncKey = input.KeyCode
                    ncCapturing = false
                    ncCaptureConn:Disconnect(); ncCaptureConn = nil
                    UpdateBindDisplay()
                    BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                    SaveNCKey()
                    EnableGlobalNC()
                end
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 or
                   input.UserInputType == Enum.UserInputType.MouseButton2 or
                   input.UserInputType == Enum.UserInputType.MouseButton3 then
                CancelCapture()
                BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                EnableGlobalNC()
            end
        end)
    end)

    -- Noclip functions
    local function StartNC()
        if PM.Noclip.connection then return end
        PM.Noclip.snapshot = {}
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    PM.Noclip.snapshot[part] = part.CanCollide
                end
            end
        end
        PM.Noclip.connection = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if not c then return end
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end)
    end

    local function StopNC()
        if PM.Noclip.connection then PM.Noclip.connection:Disconnect(); PM.Noclip.connection = nil end
        local snapshot = PM.Noclip.snapshot or {}
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        if snapshot[part] ~= nil then
                            part.CanCollide = snapshot[part]
                        end
                    end)
                end
            end
        end
        PM.Noclip.snapshot = {}
    end

    local function SetNC(val)
        if val == ncOn then return end
        ncOn = val
        if val then
            NCBtn.Text = "Stop"
            StartNC()
        else
            NCBtn.Text = "Noclip"
            StopNC()
        end
        PM.Noclip.active = ncOn
    end

    NCBtn.MouseButton1Click:Connect(function()
        SetNC(not ncOn)
    end)

    local function EnableGlobalNC()
        if PM.Noclip.keyConnection then return end
        PM.Noclip.keyConnection = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe or ncCapturing then return end
            if UserInputService:GetFocusedTextBox() then return end
            if input.UserInputType == Enum.UserInputType.Keyboard and ncKey and input.KeyCode == ncKey then
                SetNC(not ncOn)
            end
        end)
    end

    EnableGlobalNC()

    CloseBtn.MouseButton1Click:Connect(function()
        ncCapturing = false
        StopNC()
        if ncCaptureConn then ncCaptureConn:Disconnect(); ncCaptureConn = nil end
        if PM.Noclip.keyConnection then PM.Noclip.keyConnection:Disconnect(); PM.Noclip.keyConnection = nil end
        ScreenGui:Destroy()
    end)
end)

-- Speed state management
PM.Speed = {
    walkSpeed = 16,
    cframeSpeed = 0
}

-- Load saved speed settings
local SPEED_STATE_FILE = "prism/prism_speed_state.json"
local savedSpeedState = {}
pcall(function()
    if readfile and isfile(SPEED_STATE_FILE) then
        savedSpeedState = game:GetService("HttpService"):JSONDecode(readfile(SPEED_STATE_FILE))
    end
end)
PM.Speed.walkSpeed = savedSpeedState.walkSpeed or 16
PM.Speed.cframeSpeed = savedSpeedState.cframeSpeed or 0

local function SaveSpeedState()
    pcall(function()
        if writefile then
            if makefolder and not isfolder("prism") then makefolder("prism") end
            writefile(SPEED_STATE_FILE, game:GetService("HttpService"):JSONEncode({walkSpeed = PM.Speed.walkSpeed, cframeSpeed = PM.Speed.cframeSpeed}))
        end
    end)
end

registerCommand("speed", "WalkSpeed and CFrame speed control", {}, function(args)
    local CoreGui = game:GetService("CoreGui")
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer

    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_SpeedGUI") then return end

    local success, err = pcall(function()
        -- Load saved GUI settings
        local SPEED_GUI_FILE = "prism/prism_speed_gui_settings.json"
        local savedSpeedGUI = {}
        pcall(function()
            if readfile and isfile(SPEED_GUI_FILE) then
                savedSpeedGUI = HttpService:JSONDecode(readfile(SPEED_GUI_FILE))
            end
        end)
        local savedPos = savedSpeedGUI.position or {X = {Scale = 0, Offset = 1142}, Y = {Scale = 0, Offset = 477}}
        local savedMinimized = savedSpeedGUI.minimized or false

        local currentSpeedSettings = {
            position = savedPos,
            minimized = savedMinimized
        }

        local function SaveSpeedGUISettings()
            pcall(function()
                if writefile then
                    if makefolder and not isfolder("prism") then makefolder("prism") end
                    writefile(SPEED_GUI_FILE, HttpService:JSONEncode(currentSpeedSettings))
                end
            end)
        end

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "Prism_SpeedGUI"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.DisplayOrder = 1000
        ScreenGui.DisplayOrder = 999

        if syn and syn.protect_gui then
            syn.protect_gui(ScreenGui)
            ScreenGui.Parent = CoreGui
        elseif gethui then
            ScreenGui.Parent = gethui()
        else
            ScreenGui.Parent = CoreGui
        end

        local MW, MH = 239, 171

        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, MW, 0, MH)
        MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
        MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        MainFrame.BackgroundTransparency = 0.3
        MainFrame.BorderSizePixel = 0
        MainFrame.ClipsDescendants = true
        MainFrame.Parent = ScreenGui

        local MainCorner = Instance.new("UICorner")
        MainCorner.CornerRadius = UDim.new(0, 14)
        MainCorner.Parent = MainFrame

        local MainStroke = Instance.new("UIStroke")
        MainStroke.Color = Color3.fromRGB(60, 60, 60)
        MainStroke.Thickness = 1
        MainStroke.Parent = MainFrame

        local TitleBar = Instance.new("Frame")
        TitleBar.Name = "TitleBar"
        TitleBar.Size = UDim2.new(1, 0, 0, 36)
        TitleBar.BackgroundTransparency = 1
        TitleBar.Parent = MainFrame

        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Name = "Title"
        TitleLabel.Size = UDim2.new(1, -80, 1, 0)
        TitleLabel.Position = UDim2.new(0, 14, 0, 0)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = "Prism  •  Speed"
        TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TitleLabel.TextSize = 13
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = TitleBar

        local MinBtn = Instance.new("TextButton")
        MinBtn.Name = "Minimize"
        MinBtn.Size = UDim2.new(0, 24, 0, 24)
        MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
        MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        MinBtn.BackgroundTransparency = 0.4
        MinBtn.BorderSizePixel = 0
        MinBtn.Text = "—"
        MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        MinBtn.TextSize = 11
        MinBtn.Font = Enum.Font.GothamBold
        MinBtn.Parent = TitleBar
        local MinCorner = Instance.new("UICorner")
        MinCorner.CornerRadius = UDim.new(0, 6)
        MinCorner.Parent = MinBtn

        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Name = "Close"
        CloseBtn.Size = UDim2.new(0, 24, 0, 24)
        CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        CloseBtn.BackgroundTransparency = 0.4
        CloseBtn.BorderSizePixel = 0
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        CloseBtn.TextSize = 11
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.Parent = TitleBar
        local CloseCorner = Instance.new("UICorner")
        CloseCorner.CornerRadius = UDim.new(0, 6)
        CloseCorner.Parent = CloseBtn

        -- Drag functionality
        local dragging = false
        local dragStart = nil
        local startPos = nil

        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
            end
        end)

        TitleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                currentSpeedSettings.position = {
                    X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                    Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
                }
                SaveSpeedGUISettings()
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        local ContentFrame = Instance.new("Frame")
        ContentFrame.Name = "Content"
        ContentFrame.Size = UDim2.new(1, 0, 1, -40)
        ContentFrame.Position = UDim2.new(0, 0, 0, 40)
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.ClipsDescendants = true
        ContentFrame.Parent = MainFrame

        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local isMinimized = savedMinimized
        local originalSize = UDim2.new(0, MW, 0, MH)
        local minimizedSize = UDim2.new(0, MW, 0, 36)

        if isMinimized then
            MinBtn.Text = "+"
            MainFrame.Size = minimizedSize
            ContentFrame.Visible = false
        end

        MinBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            currentSpeedSettings.minimized = isMinimized
            SaveSpeedGUISettings()
            if isMinimized then
                MinBtn.Text = "+"
                local tween = TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize})
                tween:Play()
                tween.Completed:Connect(function() ContentFrame.Visible = false end)
            else
                MinBtn.Text = "—"
                ContentFrame.Visible = true
                TweenService:Create(MainFrame, tweenInfo, {Size = originalSize}):Play()
            end
        end)

        local ListLayout = Instance.new("UIListLayout")
        ListLayout.Padding = UDim.new(0, 6)
        ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ListLayout.Parent = ContentFrame

        local Padding = Instance.new("UIPadding")
        Padding.PaddingTop = UDim.new(0, 4)
        Padding.PaddingBottom = UDim.new(0, 4)
        Padding.PaddingLeft = UDim.new(0, 8)
        Padding.PaddingRight = UDim.new(0, 8)
        Padding.Parent = ContentFrame

        -- Helper function to create slider section
        local function CreateSliderSection(name, defaultValue, minVal, maxVal, layoutOrder, callback, resetValue)
            local Section = Instance.new("Frame")
            Section.Name = name .. "Section"
            Section.Size = UDim2.new(1, 0, 0, 52)
            Section.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            Section.BackgroundTransparency = 0.4
            Section.BorderSizePixel = 0
            Section.LayoutOrder = layoutOrder
            Section.Parent = ContentFrame

            local SC = Instance.new("UICorner")
            SC.CornerRadius = UDim.new(0, 10)
            SC.Parent = Section

            local SP = Instance.new("UIPadding")
            SP.PaddingTop = UDim.new(0, 5)
            SP.PaddingBottom = UDim.new(0, 5)
            SP.Parent = Section

            local InnerList = Instance.new("UIListLayout")
            InnerList.Padding = UDim.new(0, 2)
            InnerList.SortOrder = Enum.SortOrder.LayoutOrder
            InnerList.Parent = Section

            local LabelRow = Instance.new("Frame")
            LabelRow.Size = UDim2.new(1, 0, 0, 20)
            LabelRow.BackgroundTransparency = 1
            LabelRow.LayoutOrder = 1
            LabelRow.Parent = Section

            local LP = Instance.new("UIPadding")
            LP.PaddingLeft = UDim.new(0, 12)
            LP.PaddingRight = UDim.new(0, 12)
            LP.Parent = LabelRow

            local NameLbl = Instance.new("TextLabel")
            NameLbl.Size = UDim2.new(1, -60, 1, 0)
            NameLbl.BackgroundTransparency = 1
            NameLbl.Text = name
            NameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
            NameLbl.TextSize = 12
            NameLbl.Font = Enum.Font.Gotham
            NameLbl.TextXAlignment = Enum.TextXAlignment.Left
            NameLbl.Parent = LabelRow

            local ValLbl = Instance.new("TextLabel")
            ValLbl.Size = UDim2.new(0, 55, 1, 0)
            ValLbl.Position = UDim2.new(1, -55, 0, 0)
            ValLbl.BackgroundTransparency = 1
            ValLbl.Text = tostring(math.floor(defaultValue))
            ValLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
            ValLbl.TextSize = 11
            ValLbl.Font = Enum.Font.Gotham
            ValLbl.TextXAlignment = Enum.TextXAlignment.Right
            ValLbl.Parent = LabelRow

            local SliderRow = Instance.new("Frame")
            SliderRow.Size = UDim2.new(1, 0, 0, 18)
            SliderRow.BackgroundTransparency = 1
            SliderRow.LayoutOrder = 2
            SliderRow.Parent = Section

            local SRP = Instance.new("UIPadding")
            SRP.PaddingLeft = UDim.new(0, 12)
            SRP.PaddingRight = UDim.new(0, 12)
            SRP.Parent = SliderRow

            local SliderBg = Instance.new("Frame")
            SliderBg.Size = UDim2.new(1, 0, 0, 6)
            SliderBg.Position = UDim2.new(0, 0, 0.5, -3)
            SliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            SliderBg.BorderSizePixel = 0
            SliderBg.Active = true
            SliderBg.Parent = SliderRow

            local TkC = Instance.new("UICorner")
            TkC.CornerRadius = UDim.new(0, 3)
            TkC.Parent = SliderBg

            local range = maxVal - minVal
            local initScale = range > 0 and (defaultValue - minVal) / range or 0

            local SliderFill = Instance.new("Frame")
            SliderFill.Size = UDim2.new(initScale, 0, 1, 0)
            SliderFill.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            SliderFill.BorderSizePixel = 0
            SliderFill.Parent = SliderBg

            local FC = Instance.new("UICorner")
            FC.CornerRadius = UDim.new(0, 3)
            FC.Parent = SliderFill

            local SliderKnob = Instance.new("Frame")
            SliderKnob.Size = UDim2.new(0, 14, 0, 14)
            SliderKnob.Position = UDim2.new(initScale, 0, 0.5, 0)
            SliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
            SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SliderKnob.BorderSizePixel = 0
            SliderKnob.ZIndex = 3
            SliderKnob.Parent = SliderBg

            local KC = Instance.new("UICorner")
            KC.CornerRadius = UDim.new(0, 7)
            KC.Parent = SliderKnob

            local sliderDragging = false
            local currentValue = defaultValue

            local function updateSlider(value)
                currentValue = math.clamp(math.floor(value + 0.5), minVal, maxVal)
                local scale = range > 0 and (currentValue - minVal) / range or 0
                SliderFill.Size = UDim2.new(scale, 0, 1, 0)
                SliderKnob.Position = UDim2.new(scale, 0, 0.5, 0)
                ValLbl.Text = tostring(currentValue)
                callback(currentValue)
            end

            SliderKnob.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    sliderDragging = true
                end
            end)

            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    sliderDragging = false
                end
            end)

            UserInputService.InputChanged:Connect(function(i)
                if sliderDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                    local rel = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                    updateSlider(minVal + rel * range)
                end
            end)

            local lastClick = 0
            SliderBg.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    local now = tick()
                    if now - lastClick < 0.3 then
                        updateSlider(resetValue or minVal + (maxVal - minVal) * 0.32)
                        sliderDragging = false
                    else
                        local rel = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                        updateSlider(minVal + rel * range)
                        sliderDragging = true
                    end
                    lastClick = now
                end
            end)

            return {
                GetValue = function() return currentValue end,
                SetValue = updateSlider
            }
        end

        -- Get default walkspeed from current humanoid
        local function getDefaultWalkSpeed()
            local char = LocalPlayer.Character
            local h = char and char:FindFirstChildOfClass("Humanoid")
            return h and h.WalkSpeed or 16
        end

        local gameDefaultWalkSpeed = getDefaultWalkSpeed()

        -- WalkSpeed Slider (0-500)
        local wsLoopConn = nil
        local function startWSLoop(value)
            if wsLoopConn then wsLoopConn:Disconnect(); wsLoopConn = nil end
            if value <= 0 then return end
            wsLoopConn = RunService.Heartbeat:Connect(function()
                local c = LocalPlayer.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                if h and h.WalkSpeed ~= value then h.WalkSpeed = value end
            end)
        end

        local defaultWalkSpeed = PM.Speed.walkSpeed or gameDefaultWalkSpeed
        local walkSpeedSlider = CreateSliderSection("Walkspeed", defaultWalkSpeed, 0, 500, 1, function(value)
            local char = LocalPlayer.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid.WalkSpeed = value end
            end
            startWSLoop(value)
            PM.Speed.walkSpeed = math.floor(value + 0.5)
            SaveSpeedState()
        end, gameDefaultWalkSpeed)
        startWSLoop(defaultWalkSpeed)

        -- CFrame Speed Slider (0-100)
        local cframeSpeed = PM.Speed.cframeSpeed or 0
        local cframeConnection = nil

        local cframeSlider = CreateSliderSection("CFrame Speed", cframeSpeed, 0, 100, 2, function(value)
            cframeSpeed = value
            PM.Speed.cframeSpeed = math.floor(value + 0.5)
            SaveSpeedState()
        end, 0)

        local function StartCFrameMovement()
            if cframeConnection then cframeConnection:Disconnect() end
            cframeConnection = RunService.Heartbeat:Connect(function()
                if cframeSpeed > 0 then
                    local char = LocalPlayer.Character
                    if char then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local moveDirection = Vector3.new(0, 0, 0)
                            local humanoid = char:FindFirstChildOfClass("Humanoid")
                            if humanoid then
                                moveDirection = humanoid.MoveDirection
                            end
                            if moveDirection.Magnitude > 0 then
                                hrp.CFrame = hrp.CFrame + (moveDirection * cframeSpeed * 0.01)
                            end
                        end
                    end
                end
            end)
        end

        StartCFrameMovement()

        -- Reconnect on character added
        LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            local char = LocalPlayer.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid.WalkSpeed = walkSpeedSlider.GetValue() end
            end
            startWSLoop(walkSpeedSlider.GetValue())
            StartCFrameMovement()
        end)

        -- Close button
        CloseBtn.MouseButton1Click:Connect(function()
            ScreenGui:Destroy()
        end)

        -- Cleanup on destroy
        ScreenGui.Destroying:Connect(function()
            if wsLoopConn then wsLoopConn:Disconnect(); wsLoopConn = nil end
            if cframeConnection then cframeConnection:Disconnect(); cframeConnection = nil end
            -- Reset walkspeed to game default
            local char = LocalPlayer.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = gameDefaultWalkSpeed
                end
            end
        end)
    end)

    if not success then
        -- Failed to load speed GUI
    end
end)

-- Spin state management
PM.Spin = {
    enabled = false,
    speed = 5,
    connection = nil
}

-- Load saved spin state
local SPIN_STATE_FILE = "prism/prism_spin_state.json"
local savedSpinState = {}
pcall(function()
    if readfile and isfile(SPIN_STATE_FILE) then
        savedSpinState = game:GetService("HttpService"):JSONDecode(readfile(SPIN_STATE_FILE))
    end
end)
PM.Spin.enabled = savedSpinState.enabled or false
PM.Spin.speed = savedSpinState.speed or 5

local function SaveSpinState()
    pcall(function()
        if writefile then
            if makefolder and not isfolder("prism") then makefolder("prism") end
            writefile(SPIN_STATE_FILE, game:GetService("HttpService"):JSONEncode({enabled = PM.Spin.enabled, speed = PM.Spin.speed}))
        end
    end)
end

registerCommand("spin", "Spin your character", {}, function(args)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")
    local LocalPlayer = Players.LocalPlayer
    local HttpService = game:GetService("HttpService")

    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_SpinGUI") then return end

    local success, err = pcall(function()
        -- Load saved GUI settings
        local SPIN_GUI_FILE = "prism/prism_spin_gui_settings.json"
        local savedSpinGUI = {}
        pcall(function()
            if readfile and isfile(SPIN_GUI_FILE) then
                savedSpinGUI = HttpService:JSONDecode(readfile(SPIN_GUI_FILE))
            end
        end)
        local savedPos = savedSpinGUI.position or {X = {Scale = 0, Offset = 900}, Y = {Scale = 0, Offset = 320}}
        local savedMinimized = savedSpinGUI.minimized or false

        local currentSpinSettings = {
            position = savedPos,
            minimized = savedMinimized
        }

        local function SaveSpinGUISettings()
            pcall(function()
                if writefile then
                    if makefolder and not isfolder("prism") then makefolder("prism") end
                    writefile(SPIN_GUI_FILE, HttpService:JSONEncode(currentSpinSettings))
                end
            end)
        end

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "Prism_SpinGUI"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.DisplayOrder = 1000
        ScreenGui.DisplayOrder = 999

        local ok = pcall(function() ScreenGui.Parent = CoreGui end)
        if not ok then ScreenGui.Parent = LocalPlayer.PlayerGui end

        local MW, MH = 239, 148

        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, MW, 0, MH)
        MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
        MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        MainFrame.BackgroundTransparency = 0.3
        MainFrame.BorderSizePixel = 0
        MainFrame.ClipsDescendants = true
        MainFrame.Parent = ScreenGui

        local MainCorner = Instance.new("UICorner")
        MainCorner.CornerRadius = UDim.new(0, 14)
        MainCorner.Parent = MainFrame

        local MainStroke = Instance.new("UIStroke")
        MainStroke.Color = Color3.fromRGB(60, 60, 60)
        MainStroke.Thickness = 1
        MainStroke.Parent = MainFrame

        local TitleBar = Instance.new("Frame")
        TitleBar.Name = "TitleBar"
        TitleBar.Size = UDim2.new(1, 0, 0, 36)
        TitleBar.BackgroundTransparency = 1
        TitleBar.Parent = MainFrame

        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Name = "Title"
        TitleLabel.Size = UDim2.new(1, -80, 1, 0)
        TitleLabel.Position = UDim2.new(0, 14, 0, 0)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = "Prism  •  Spin"
        TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TitleLabel.TextSize = 13
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = TitleBar

        local MinBtn = Instance.new("TextButton")
        MinBtn.Name = "Minimize"
        MinBtn.Size = UDim2.new(0, 24, 0, 24)
        MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
        MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        MinBtn.BackgroundTransparency = 0.4
        MinBtn.BorderSizePixel = 0
        MinBtn.Text = "—"
        MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        MinBtn.TextSize = 11
        MinBtn.Font = Enum.Font.GothamBold
        MinBtn.Parent = TitleBar
        local MinCorner = Instance.new("UICorner")
        MinCorner.CornerRadius = UDim.new(0, 6)
        MinCorner.Parent = MinBtn

        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Name = "Close"
        CloseBtn.Size = UDim2.new(0, 24, 0, 24)
        CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        CloseBtn.BackgroundTransparency = 0.4
        CloseBtn.BorderSizePixel = 0
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        CloseBtn.TextSize = 11
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.Parent = TitleBar
        local CloseCorner = Instance.new("UICorner")
        CloseCorner.CornerRadius = UDim.new(0, 6)
        CloseCorner.Parent = CloseBtn

        -- Drag functionality
        local dragging = false
        local dragStart = nil
        local startPos = nil

        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
            end
        end)

        TitleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                currentSpinSettings.position = {
                    X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                    Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
                }
                SaveSpinGUISettings()
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        local ContentFrame = Instance.new("Frame")
        ContentFrame.Name = "Content"
        ContentFrame.Size = UDim2.new(1, 0, 1, -40)
        ContentFrame.Position = UDim2.new(0, 0, 0, 40)
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.ClipsDescendants = true
        ContentFrame.Parent = MainFrame

        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local isMinimized = savedMinimized
        local originalSize = UDim2.new(0, MW, 0, MH)
        local minimizedSize = UDim2.new(0, MW, 0, 36)

        if isMinimized then
            MinBtn.Text = "+"
            MainFrame.Size = minimizedSize
            ContentFrame.Visible = false
        end

        MinBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            currentSpinSettings.minimized = isMinimized
            SaveSpinGUISettings()
            if isMinimized then
                MinBtn.Text = "+"
                local tween = TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize})
                tween:Play()
                tween.Completed:Connect(function() ContentFrame.Visible = false end)
            else
                MinBtn.Text = "—"
                ContentFrame.Visible = true
                TweenService:Create(MainFrame, tweenInfo, {Size = originalSize}):Play()
            end
        end)

        local ListLayout = Instance.new("UIListLayout")
        ListLayout.Padding = UDim.new(0, 6)
        ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ListLayout.Parent = ContentFrame

        local Padding = Instance.new("UIPadding")
        Padding.PaddingTop = UDim.new(0, 4)
        Padding.PaddingBottom = UDim.new(0, 4)
        Padding.PaddingLeft = UDim.new(0, 8)
        Padding.PaddingRight = UDim.new(0, 8)
        Padding.Parent = ContentFrame

        -- Spin state
        local spinSpeed = PM.Spin.speed or 5
        local spinConn = nil
        local spinOn = false

        -- Toggle row
        local ToggleRow = Instance.new("Frame")
        ToggleRow.Name = "ToggleRow"
        ToggleRow.Size = UDim2.new(1, 0, 0, 32)
        ToggleRow.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        ToggleRow.BackgroundTransparency = 0.4
        ToggleRow.BorderSizePixel = 0
        ToggleRow.LayoutOrder = 1
        ToggleRow.Parent = ContentFrame
        local TRC = Instance.new("UICorner")
        TRC.CornerRadius = UDim.new(0, 10)
        TRC.Parent = ToggleRow
        local TRP = Instance.new("UIPadding")
        TRP.PaddingLeft = UDim.new(0, 12)
        TRP.PaddingRight = UDim.new(0, 12)
        TRP.Parent = ToggleRow

        local ToggleLbl = Instance.new("TextLabel")
        ToggleLbl.Size = UDim2.new(1, -48, 1, 0)
        ToggleLbl.BackgroundTransparency = 1
        ToggleLbl.Text = "Enable"
        ToggleLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        ToggleLbl.TextSize = 12
        ToggleLbl.Font = Enum.Font.Gotham
        ToggleLbl.TextXAlignment = Enum.TextXAlignment.Left
        ToggleLbl.Parent = ToggleRow

        local Pill = Instance.new("Frame")
        Pill.Size = UDim2.new(0, 36, 0, 18)
        Pill.Position = UDim2.new(1, -36, 0.5, -9)
        Pill.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        Pill.BorderSizePixel = 0
        Pill.Parent = ToggleRow
        local PillCorner = Instance.new("UICorner")
        PillCorner.CornerRadius = UDim.new(0, 9)
        PillCorner.Parent = Pill
        local Knob = Instance.new("Frame")
        Knob.Size = UDim2.new(0, 14, 0, 14)
        Knob.Position = UDim2.new(0, 3, 0.5, -7)
        Knob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
        Knob.BorderSizePixel = 0
        Knob.Parent = Pill
        local KnobC = Instance.new("UICorner")
        KnobC.CornerRadius = UDim.new(0, 7)
        KnobC.Parent = Knob
        local PillBtn = Instance.new("TextButton")
        PillBtn.Size = UDim2.new(1, 0, 1, 0)
        PillBtn.BackgroundTransparency = 1
        PillBtn.Text = ""
        PillBtn.Parent = Pill

        local function setSpin(on)
            spinOn = on
            PM.Spin.enabled = on
            ToggleLbl.Text = on and "Disable" or "Enable"
            TweenService:Create(Pill, tweenInfo, {BackgroundColor3 = on and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(60, 60, 60)}):Play()
            TweenService:Create(Knob, tweenInfo, {Position = on and UDim2.new(1, -19, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)}):Play()
            if spinConn then spinConn:Disconnect(); spinConn = nil end
            if on then
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local lv = root.CFrame.LookVector
                    local flat = Vector3.new(lv.X, 0, lv.Z)
                    if flat.Magnitude > 0.01 then root.CFrame = CFrame.new(root.Position, root.Position + flat) end
                end
                spinConn = RunService.RenderStepped:Connect(function()
                    local c = LocalPlayer.Character
                    local r = c and c:FindFirstChild("HumanoidRootPart")
                    if r then r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(spinSpeed), 0) end
                end)
            end
            SaveSpinState()
        end

        PillBtn.MouseButton1Click:Connect(function() setSpin(not spinOn) end)
        ToggleRow.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then setSpin(not spinOn) end end)

        -- Slider section
        local Section = Instance.new("Frame")
        Section.Name = "SpinSection"
        Section.Size = UDim2.new(1, 0, 0, 52)
        Section.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        Section.BackgroundTransparency = 0.4
        Section.BorderSizePixel = 0
        Section.LayoutOrder = 2
        Section.Parent = ContentFrame
        local SectionCorner = Instance.new("UICorner")
        SectionCorner.CornerRadius = UDim.new(0, 10)
        SectionCorner.Parent = Section
        local SectionPad = Instance.new("UIPadding")
        SectionPad.PaddingTop = UDim.new(0, 5)
        SectionPad.PaddingBottom = UDim.new(0, 5)
        SectionPad.Parent = Section
        local InnerList = Instance.new("UIListLayout")
        InnerList.Padding = UDim.new(0, 2)
        InnerList.SortOrder = Enum.SortOrder.LayoutOrder
        InnerList.Parent = Section

        local LabelRow = Instance.new("Frame")
        LabelRow.Size = UDim2.new(1, 0, 0, 20)
        LabelRow.BackgroundTransparency = 1
        LabelRow.LayoutOrder = 1
        LabelRow.Parent = Section
        local LP = Instance.new("UIPadding")
        LP.PaddingLeft = UDim.new(0, 12)
        LP.PaddingRight = UDim.new(0, 12)
        LP.Parent = LabelRow

        local NameLbl = Instance.new("TextLabel")
        NameLbl.Size = UDim2.new(1, -60, 1, 0)
        NameLbl.BackgroundTransparency = 1
        NameLbl.Text = "Spin Speed"
        NameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        NameLbl.TextSize = 12
        NameLbl.Font = Enum.Font.Gotham
        NameLbl.TextXAlignment = Enum.TextXAlignment.Left
        NameLbl.Parent = LabelRow

        local ValLbl = Instance.new("TextLabel")
        ValLbl.Size = UDim2.new(0, 55, 1, 0)
        ValLbl.Position = UDim2.new(1, -55, 0, 0)
        ValLbl.BackgroundTransparency = 1
        ValLbl.Text = tostring(spinSpeed)
        ValLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
        ValLbl.TextSize = 11
        ValLbl.Font = Enum.Font.Gotham
        ValLbl.TextXAlignment = Enum.TextXAlignment.Right
        ValLbl.Parent = LabelRow

        local SliderRow = Instance.new("Frame")
        SliderRow.Size = UDim2.new(1, 0, 0, 18)
        SliderRow.BackgroundTransparency = 1
        SliderRow.LayoutOrder = 2
        SliderRow.Parent = Section
        local SP = Instance.new("UIPadding")
        SP.PaddingLeft = UDim.new(0, 12)
        SP.PaddingRight = UDim.new(0, 12)
        SP.Parent = SliderRow

        local SliderBg = Instance.new("Frame")
        SliderBg.Size = UDim2.new(1, 0, 0, 6)
        SliderBg.Position = UDim2.new(0, 0, 0.5, -3)
        SliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        SliderBg.BorderSizePixel = 0
        SliderBg.Active = true
        SliderBg.Parent = SliderRow
        local TrackCorner = Instance.new("UICorner")
        TrackCorner.CornerRadius = UDim.new(0, 3)
        TrackCorner.Parent = SliderBg

        local initSpinScale = (spinSpeed - 1) / 499
        local SliderFill = Instance.new("Frame")
        SliderFill.Size = UDim2.new(initSpinScale, 0, 1, 0)
        SliderFill.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        SliderFill.BorderSizePixel = 0
        SliderFill.Parent = SliderBg
        local FillCorner = Instance.new("UICorner")
        FillCorner.CornerRadius = UDim.new(0, 3)
        FillCorner.Parent = SliderFill

        local SliderKnob = Instance.new("Frame")
        SliderKnob.Size = UDim2.new(0, 14, 0, 14)
        SliderKnob.Position = UDim2.new(initSpinScale, 0, 0.5, 0)
        SliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
        SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        SliderKnob.BorderSizePixel = 0
        SliderKnob.ZIndex = 3
        SliderKnob.Parent = SliderBg
        local KnobCorner = Instance.new("UICorner")
        KnobCorner.CornerRadius = UDim.new(0, 7)
        KnobCorner.Parent = SliderKnob

        local sliderDragging = false
        local function updateSlider(value)
            spinSpeed = math.clamp(math.floor(value + 0.5), 1, 500)
            local scale = (spinSpeed - 1) / 499
            SliderFill.Size = UDim2.new(scale, 0, 1, 0)
            SliderKnob.Position = UDim2.new(scale, 0, 0.5, 0)
            ValLbl.Text = tostring(spinSpeed)
            PM.Spin.speed = spinSpeed
            SaveSpinState()
        end

        SliderKnob.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = true
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if sliderDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local rel = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                updateSlider(1 + rel * 499)
            end
        end)

        local lastClick = 0
        SliderBg.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                local now = tick()
                if now - lastClick < 0.3 then
                    updateSlider(5)
                    sliderDragging = false
                else
                    local rel = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                    updateSlider(1 + rel * 499)
                    sliderDragging = true
                end
                lastClick = now
            end
        end)

        -- Apply saved toggle state
        if PM.Spin.enabled then setSpin(true) end

        CloseBtn.MouseButton1Click:Connect(function()
            if spinConn then spinConn:Disconnect() end
            PM.Spin.enabled = false
            SaveSpinState()
            ScreenGui:Destroy()
        end)
    end)

    if not success then
        -- Failed to load spin GUI
    end
end)

-- Camera state management
PM.Camera = {
    fov = 70,
    maxZoom = false
}

local CAMERA_STATE_FILE = "prism/prism_camera_state.json"
local savedCameraState = {}
pcall(function()
    if readfile and isfile(CAMERA_STATE_FILE) then
        savedCameraState = game:GetService("HttpService"):JSONDecode(readfile(CAMERA_STATE_FILE))
    end
end)
PM.Camera.fov = savedCameraState.fov or 70
PM.Camera.maxZoom = savedCameraState.maxZoom or false

local function SaveCameraState()
    pcall(function()
        if writefile then
            if makefolder and not isfolder("prism") then makefolder("prism") end
            writefile(CAMERA_STATE_FILE, game:GetService("HttpService"):JSONEncode(PM.Camera))
        end
    end)
end

registerCommand("camera", "Camera controls", {}, function(args)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")
    local LocalPlayer = Players.LocalPlayer
    local HttpService = game:GetService("HttpService")

    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_CameraGUI") then return end

    local success, err = pcall(function()
        local CAMERA_GUI_FILE = "prism/prism_camera_gui_settings.json"
        local savedCameraGUI = {}
        pcall(function()
            if readfile and isfile(CAMERA_GUI_FILE) then
                savedCameraGUI = HttpService:JSONDecode(readfile(CAMERA_GUI_FILE))
            end
        end)
        local savedPos = savedCameraGUI.position or {X = {Scale = 0, Offset = 980}, Y = {Scale = 0, Offset = 320}}
        local savedMinimized = savedCameraGUI.minimized or false

        local currentCameraSettings = {
            position = savedPos,
            minimized = savedMinimized
        }

        local function SaveCameraGUISettings()
            pcall(function()
                if writefile then
                    if makefolder and not isfolder("prism") then makefolder("prism") end
                    writefile(CAMERA_GUI_FILE, HttpService:JSONEncode(currentCameraSettings))
                end
            end)
        end

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "Prism_CameraGUI"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.DisplayOrder = 1000
        ScreenGui.DisplayOrder = 999

        local ok = pcall(function() ScreenGui.Parent = CoreGui end)
        if not ok then ScreenGui.Parent = LocalPlayer.PlayerGui end

        local MW, MH = 239, 152

        local cam = workspace.CurrentCamera
        local gameDefaultFOV = cam and cam.FieldOfView or 70
        local gameDefaultMaxZoom = LocalPlayer.CameraMaxZoomDistance or 128
        local defaultFOV = PM.Camera.fov or gameDefaultFOV
        local currentFOV = defaultFOV

        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, MW, 0, MH)
        MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
        MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        MainFrame.BackgroundTransparency = 0.3
        MainFrame.BorderSizePixel = 0
        MainFrame.ClipsDescendants = true
        MainFrame.Parent = ScreenGui

        local MainCorner = Instance.new("UICorner")
        MainCorner.CornerRadius = UDim.new(0, 14)
        MainCorner.Parent = MainFrame

        local MainStroke = Instance.new("UIStroke")
        MainStroke.Color = Color3.fromRGB(60, 60, 60)
        MainStroke.Thickness = 1
        MainStroke.Parent = MainFrame

        local TitleBar = Instance.new("Frame")
        TitleBar.Name = "TitleBar"
        TitleBar.Size = UDim2.new(1, 0, 0, 36)
        TitleBar.BackgroundTransparency = 1
        TitleBar.Parent = MainFrame

        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Size = UDim2.new(1, -80, 1, 0)
        TitleLabel.Position = UDim2.new(0, 14, 0, 0)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = "Prism  •  Camera"
        TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TitleLabel.TextSize = 13
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = TitleBar

        local MinBtn = Instance.new("TextButton")
        MinBtn.Size = UDim2.new(0, 24, 0, 24)
        MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
        MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        MinBtn.BackgroundTransparency = 0.4
        MinBtn.BorderSizePixel = 0
        MinBtn.Text = "—"
        MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        MinBtn.TextSize = 11
        MinBtn.Font = Enum.Font.GothamBold
        MinBtn.Parent = TitleBar
        local MinCorner = Instance.new("UICorner")
        MinCorner.CornerRadius = UDim.new(0, 6)
        MinCorner.Parent = MinBtn

        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Size = UDim2.new(0, 24, 0, 24)
        CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        CloseBtn.BackgroundTransparency = 0.4
        CloseBtn.BorderSizePixel = 0
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        CloseBtn.TextSize = 11
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.Parent = TitleBar
        local CloseCorner = Instance.new("UICorner")
        CloseCorner.CornerRadius = UDim.new(0, 6)
        CloseCorner.Parent = CloseBtn

        -- Drag functionality
        local dragging = false
        local dragStart = nil
        local startPos = nil

        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
            end
        end)

        TitleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                currentCameraSettings.position = {
                    X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                    Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
                }
                SaveCameraGUISettings()
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        local ContentFrame = Instance.new("Frame")
        ContentFrame.Name = "Content"
        ContentFrame.Size = UDim2.new(1, 0, 1, -40)
        ContentFrame.Position = UDim2.new(0, 0, 0, 40)
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.ClipsDescendants = true
        ContentFrame.Parent = MainFrame

        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local isMinimized = savedMinimized
        local originalSize = UDim2.new(0, MW, 0, MH)
        local minimizedSize = UDim2.new(0, MW, 0, 36)

        if isMinimized then
            MinBtn.Text = "+"
            MainFrame.Size = minimizedSize
            ContentFrame.Visible = false
        end

        MinBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            currentCameraSettings.minimized = isMinimized
            SaveCameraGUISettings()
            if isMinimized then
                MinBtn.Text = "+"
                local tween = TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize})
                tween:Play()
                tween.Completed:Connect(function() ContentFrame.Visible = false end)
            else
                MinBtn.Text = "—"
                ContentFrame.Visible = true
                TweenService:Create(MainFrame, tweenInfo, {Size = originalSize}):Play()
            end
        end)

        local ListLayout = Instance.new("UIListLayout")
        ListLayout.Padding = UDim.new(0, 6)
        ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ListLayout.Parent = ContentFrame

        local Padding = Instance.new("UIPadding")
        Padding.PaddingTop = UDim.new(0, 4)
        Padding.PaddingBottom = UDim.new(0, 4)
        Padding.PaddingLeft = UDim.new(0, 8)
        Padding.PaddingRight = UDim.new(0, 8)
        Padding.Parent = ContentFrame

        -- FOV loop
        local fovLoopConn = nil
        local function startFOVLoop(value)
            if fovLoopConn then fovLoopConn:Disconnect(); fovLoopConn = nil end
            fovLoopConn = RunService.Heartbeat:Connect(function()
                local c = workspace.CurrentCamera
                if c and c.FieldOfView ~= value then c.FieldOfView = value end
            end)
        end

        -- FOV slider section
        local Section = Instance.new("Frame")
        Section.Size = UDim2.new(1, 0, 0, 52)
        Section.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        Section.BackgroundTransparency = 0.4
        Section.BorderSizePixel = 0
        Section.LayoutOrder = 1
        Section.Parent = ContentFrame
        local SC = Instance.new("UICorner")
        SC.CornerRadius = UDim.new(0, 10)
        SC.Parent = Section
        local SP = Instance.new("UIPadding")
        SP.PaddingTop = UDim.new(0, 5)
        SP.PaddingBottom = UDim.new(0, 5)
        SP.Parent = Section
        local IL = Instance.new("UIListLayout")
        IL.Padding = UDim.new(0, 2)
        IL.SortOrder = Enum.SortOrder.LayoutOrder
        IL.Parent = Section

        local LabelRow = Instance.new("Frame")
        LabelRow.Size = UDim2.new(1, 0, 0, 20)
        LabelRow.BackgroundTransparency = 1
        LabelRow.LayoutOrder = 1
        LabelRow.Parent = Section
        local LP = Instance.new("UIPadding")
        LP.PaddingLeft = UDim.new(0, 12)
        LP.PaddingRight = UDim.new(0, 12)
        LP.Parent = LabelRow

        local NameLbl = Instance.new("TextLabel")
        NameLbl.Size = UDim2.new(1, -60, 1, 0)
        NameLbl.BackgroundTransparency = 1
        NameLbl.Text = "Field of View"
        NameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        NameLbl.TextSize = 12
        NameLbl.Font = Enum.Font.Gotham
        NameLbl.TextXAlignment = Enum.TextXAlignment.Left
        NameLbl.Parent = LabelRow

        local ValLbl = Instance.new("TextLabel")
        ValLbl.Size = UDim2.new(0, 55, 1, 0)
        ValLbl.Position = UDim2.new(1, -55, 0, 0)
        ValLbl.BackgroundTransparency = 1
        ValLbl.Text = tostring(math.floor(currentFOV))
        ValLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
        ValLbl.TextSize = 11
        ValLbl.Font = Enum.Font.Gotham
        ValLbl.TextXAlignment = Enum.TextXAlignment.Right
        ValLbl.Parent = LabelRow

        local SliderRow = Instance.new("Frame")
        SliderRow.Size = UDim2.new(1, 0, 0, 18)
        SliderRow.BackgroundTransparency = 1
        SliderRow.LayoutOrder = 2
        SliderRow.Parent = Section
        local SRP = Instance.new("UIPadding")
        SRP.PaddingLeft = UDim.new(0, 12)
        SRP.PaddingRight = UDim.new(0, 12)
        SRP.Parent = SliderRow

        local SliderBg = Instance.new("Frame")
        SliderBg.Size = UDim2.new(1, 0, 0, 6)
        SliderBg.Position = UDim2.new(0, 0, 0.5, -3)
        SliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        SliderBg.BorderSizePixel = 0
        SliderBg.Active = true
        SliderBg.Parent = SliderRow
        local TkC = Instance.new("UICorner")
        TkC.CornerRadius = UDim.new(0, 3)
        TkC.Parent = SliderBg

        local initScale = (currentFOV - 1) / 119
        local SliderFill = Instance.new("Frame")
        SliderFill.Size = UDim2.new(initScale, 0, 1, 0)
        SliderFill.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        SliderFill.BorderSizePixel = 0
        SliderFill.Parent = SliderBg
        local FC = Instance.new("UICorner")
        FC.CornerRadius = UDim.new(0, 3)
        FC.Parent = SliderFill

        local SliderKnob = Instance.new("Frame")
        SliderKnob.Size = UDim2.new(0, 14, 0, 14)
        SliderKnob.Position = UDim2.new(initScale, 0, 0.5, 0)
        SliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
        SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        SliderKnob.BorderSizePixel = 0
        SliderKnob.ZIndex = 3
        SliderKnob.Parent = SliderBg
        local KC = Instance.new("UICorner")
        KC.CornerRadius = UDim.new(0, 7)
        KC.Parent = SliderKnob

        local sliderDragging = false
        local function updateFOV(value)
            currentFOV = math.clamp(math.floor(value + 0.5), 1, 120)
            local scale = (currentFOV - 1) / 119
            SliderFill.Size = UDim2.new(scale, 0, 1, 0)
            SliderKnob.Position = UDim2.new(scale, 0, 0.5, 0)
            ValLbl.Text = tostring(currentFOV)
            local c = workspace.CurrentCamera
            if c then c.FieldOfView = currentFOV end
            startFOVLoop(currentFOV)
            PM.Camera.fov = currentFOV
            SaveCameraState()
        end

        SliderKnob.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = true
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if sliderDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local rel = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                updateFOV(1 + rel * 119)
            end
        end)
        local lastClickFOV = 0
        SliderBg.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                local now = tick()
                if now - lastClickFOV < 0.3 then
                    updateFOV(70)
                    sliderDragging = false
                else
                    local rel = math.clamp((i.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                    updateFOV(1 + rel * 119)
                    sliderDragging = true
                end
                lastClickFOV = now
            end
        end)

        startFOVLoop(currentFOV)

        -- Infinite Zoom toggle
        local izOn = PM.Camera.maxZoom or false
        local izConn = nil
        local defaultMaxZoom = nil

        local IZRow = Instance.new("Frame")
        IZRow.Size = UDim2.new(1, 0, 0, 32)
        IZRow.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        IZRow.BackgroundTransparency = 0.4
        IZRow.BorderSizePixel = 0
        IZRow.LayoutOrder = 2
        IZRow.Parent = ContentFrame
        local IZRC = Instance.new("UICorner")
        IZRC.CornerRadius = UDim.new(0, 10)
        IZRC.Parent = IZRow

        local IZLbl = Instance.new("TextLabel")
        IZLbl.Size = UDim2.new(1, -100, 1, 0)
        IZLbl.Position = UDim2.new(0, 12, 0, 0)
        IZLbl.BackgroundTransparency = 1
        IZLbl.Text = "Max Zoom"
        IZLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        IZLbl.TextSize = 12
        IZLbl.Font = Enum.Font.Gotham
        IZLbl.TextXAlignment = Enum.TextXAlignment.Left
        IZLbl.Parent = IZRow

        local IZPill = Instance.new("Frame")
        IZPill.Name = "Pill"
        IZPill.Size = UDim2.new(0, 40, 0, 22)
        IZPill.Position = UDim2.new(1, -52, 0.5, -11)
        IZPill.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        IZPill.BorderSizePixel = 0
        IZPill.Parent = IZRow
        local IZPillC = Instance.new("UICorner")
        IZPillC.CornerRadius = UDim.new(0, 11)
        IZPillC.Parent = IZPill
        local IZKnob = Instance.new("Frame")
        IZKnob.Name = "Knob"
        IZKnob.Size = UDim2.new(0, 16, 0, 16)
        IZKnob.Position = UDim2.new(0, 3, 0.5, -8)
        IZKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        IZKnob.BorderSizePixel = 0
        IZKnob.Parent = IZPill
        local IZKnobC = Instance.new("UICorner")
        IZKnobC.CornerRadius = UDim.new(0, 8)
        IZKnobC.Parent = IZKnob
        local IZHit = Instance.new("TextButton")
        IZHit.Size = UDim2.new(0, 52, 1, 0)
        IZHit.Position = UDim2.new(1, -56, 0, 0)
        IZHit.BackgroundTransparency = 1
        IZHit.Text = ""
        IZHit.Parent = IZRow

        local function setInfZoom(on)
            izOn = on
            PM.Camera.maxZoom = on
            TweenService:Create(IZPill, tweenInfo, {BackgroundColor3 = on and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(60, 60, 60)}):Play()
            TweenService:Create(IZKnob, tweenInfo, {Position = on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}):Play()
            if on then
                if not defaultMaxZoom then defaultMaxZoom = gameDefaultMaxZoom end
                LocalPlayer.CameraMaxZoomDistance = 400
                if izConn then izConn:Disconnect() end
                izConn = RunService.Heartbeat:Connect(function()
                    if LocalPlayer.CameraMaxZoomDistance ~= 400 then
                        LocalPlayer.CameraMaxZoomDistance = 400
                    end
                end)
            else
                if izConn then izConn:Disconnect(); izConn = nil end
                LocalPlayer.CameraMaxZoomDistance = defaultMaxZoom or gameDefaultMaxZoom
            end
            SaveCameraState()
        end
        IZHit.MouseButton1Click:Connect(function() setInfZoom(not izOn) end)

        if izOn then setInfZoom(true) end

        CloseBtn.MouseButton1Click:Connect(function()
            if fovLoopConn then fovLoopConn:Disconnect(); fovLoopConn = nil end
            if izConn then izConn:Disconnect(); izConn = nil end
            ScreenGui:Destroy()
        end)

        ScreenGui.Destroying:Connect(function()
            if fovLoopConn then fovLoopConn:Disconnect(); fovLoopConn = nil end
            if izConn then izConn:Disconnect(); izConn = nil end
            local c = workspace.CurrentCamera
            if c then c.FieldOfView = gameDefaultFOV end
            LocalPlayer.CameraMaxZoomDistance = defaultMaxZoom or gameDefaultMaxZoom
        end)
    end)

    if not success then
        -- Failed to load camera GUI
    end
end)

-- Respawn state management (use global variables like Axon)
local _respawnEnabled = false
local _respawnLastCFrame = nil

PM.Respawn = {
    enabled = false,
    lastCFrame = nil
}

local RESPAWN_STATE_FILE = "prism/prism_respawn_state.json"
local savedRespawnState = {}
pcall(function()
    if readfile and isfile(RESPAWN_STATE_FILE) then
        savedRespawnState = game:GetService("HttpService"):JSONDecode(readfile(RESPAWN_STATE_FILE))
    end
end)
_respawnEnabled = savedRespawnState.enabled or false
PM.Respawn.enabled = _respawnEnabled

local function SaveRespawnState()
    pcall(function()
        if writefile then
            if makefolder and not isfolder("prism") then makefolder("prism") end
            writefile(RESPAWN_STATE_FILE, game:GetService("HttpService"):JSONEncode({enabled = _respawnEnabled}))
        end
    end)
end

-- CharacterAdded and Died connections for respawn (set up globally like Axon)
local respawnCharAddedConn = nil
local respawnDiedConn = nil

local function OnCharacterAdded(char)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    local hum = char:WaitForChild("Humanoid", 5)
    if not root or not hum then return end
    
    if _respawnEnabled and _respawnLastCFrame then
        task.wait(0.1)
        root.CFrame = _respawnLastCFrame
    end

    if respawnDiedConn then respawnDiedConn:Disconnect(); respawnDiedConn = nil end
    respawnDiedConn = hum.Died:Connect(function()
        if root and root.Position.Y > (workspace.FallenPartsDestroyHeight + 10) then
            _respawnLastCFrame = root.CFrame
        else
            _respawnLastCFrame = nil
        end
    end)
end

-- Set up hooks globally (always monitoring like Axon)
if LP.Character then
    task.spawn(OnCharacterAdded, LP.Character)
end
respawnCharAddedConn = LP.CharacterAdded:Connect(OnCharacterAdded)

registerCommand("respawnlastlocation", "Respawn to last location with toggle", {}, function(args)
    local CoreGui = game:GetService("CoreGui")
    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_RespawnGUI") then return end

    local success, err = pcall(function()
        local UserInputService = game:GetService("UserInputService")
        local TweenService = game:GetService("TweenService")
        local HttpService = game:GetService("HttpService")

        -- Load saved GUI settings
        local RESPAWN_GUI_FILE = "prism/prism_respawn_gui_settings.json"
        local savedRespawnGUI = {}
        pcall(function()
            if readfile and isfile(RESPAWN_GUI_FILE) then
                savedRespawnGUI = HttpService:JSONDecode(readfile(RESPAWN_GUI_FILE))
            end
        end)
        local savedPos = savedRespawnGUI.position or {X = {Scale = 0, Offset = 1142}, Y = {Scale = 0, Offset = 500}}
        local savedMinimized = savedRespawnGUI.minimized or false

        local currentRespawnGUISettings = {
            position = savedPos,
            minimized = savedMinimized
        }

        local function SaveRespawnGUISettings()
            pcall(function()
                if writefile then
                    if makefolder and not isfolder("prism") then makefolder("prism") end
                    writefile(RESPAWN_GUI_FILE, HttpService:JSONEncode(currentRespawnGUISettings))
                end
            end)
        end

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "Prism_RespawnGUI"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.DisplayOrder = 1000
        PM.Respawn.Gui = ScreenGui

        if syn and syn.protect_gui then
            syn.protect_gui(ScreenGui)
            ScreenGui.Parent = CoreGui
        elseif gethui then
            ScreenGui.Parent = gethui()
        else
            ScreenGui.Parent = CoreGui
        end

        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, 239, 0, 90)
        MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
        MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        MainFrame.BackgroundTransparency = 0.3
        MainFrame.BorderSizePixel = 0
        MainFrame.ClipsDescendants = true
        MainFrame.Parent = ScreenGui

        local MainCorner = Instance.new("UICorner")
        MainCorner.CornerRadius = UDim.new(0, 14)
        MainCorner.Parent = MainFrame

        local MainStroke = Instance.new("UIStroke")
        MainStroke.Color = Color3.fromRGB(60, 60, 60)
        MainStroke.Thickness = 1
        MainStroke.Parent = MainFrame

        local TitleBar = Instance.new("Frame")
        TitleBar.Name = "TitleBar"
        TitleBar.Size = UDim2.new(1, 0, 0, 36)
        TitleBar.BackgroundTransparency = 1
        TitleBar.Parent = MainFrame

        local dragging = false
        local dragStart = nil
        local startPos = nil

        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
            end
        end)

        TitleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                currentRespawnGUISettings.position = {
                    X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                    Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
                }
                SaveRespawnGUISettings()
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Name = "Title"
        TitleLabel.Size = UDim2.new(1, -80, 1, 0)
        TitleLabel.Position = UDim2.new(0, 14, 0, 0)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = "Prism  •  Respawn"
        TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TitleLabel.TextSize = 13
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = TitleBar

        local MinBtn = Instance.new("TextButton")
        MinBtn.Name = "Minimize"
        MinBtn.Size = UDim2.new(0, 24, 0, 24)
        MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
        MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        MinBtn.BackgroundTransparency = 0.4
        MinBtn.BorderSizePixel = 0
        MinBtn.Text = "—"
        MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        MinBtn.TextSize = 11
        MinBtn.Font = Enum.Font.GothamBold
        MinBtn.Parent = TitleBar

        local MinCorner = Instance.new("UICorner")
        MinCorner.CornerRadius = UDim.new(0, 6)
        MinCorner.Parent = MinBtn

        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Name = "Close"
        CloseBtn.Size = UDim2.new(0, 24, 0, 24)
        CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        CloseBtn.BackgroundTransparency = 0.4
        CloseBtn.BorderSizePixel = 0
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        CloseBtn.TextSize = 11
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.Parent = TitleBar

        local CloseCorner = Instance.new("UICorner")
        CloseCorner.CornerRadius = UDim.new(0, 6)
        CloseCorner.Parent = CloseBtn

        CloseBtn.MouseButton1Click:Connect(function()
            ScreenGui:Destroy()
            PM.Respawn.Gui = nil
        end)

        local ContentFrame = Instance.new("Frame")
        ContentFrame.Name = "Content"
        ContentFrame.Size = UDim2.new(1, 0, 1, -40)
        ContentFrame.Position = UDim2.new(0, 0, 0, 40)
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.ClipsDescendants = true
        ContentFrame.Parent = MainFrame

        local isMinimized = savedMinimized
        local originalSize = UDim2.new(0, 239, 0, 90)
        local minimizedSize = UDim2.new(0, 239, 0, 36)
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        if isMinimized then
            MinBtn.Text = "+"
            MainFrame.Size = minimizedSize
            ContentFrame.Visible = false
        end

        MinBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            currentRespawnGUISettings.minimized = isMinimized
            SaveRespawnGUISettings()
            if isMinimized then
                MinBtn.Text = "+"
                local tween = TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize})
                tween:Play()
                tween.Completed:Connect(function() ContentFrame.Visible = false end)
            else
                MinBtn.Text = "—"
                ContentFrame.Visible = true
                TweenService:Create(MainFrame, tweenInfo, {Size = originalSize}):Play()
            end
        end)

        local ContentLayout = Instance.new("UIListLayout")
        ContentLayout.Padding = UDim.new(0, 6)
        ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ContentLayout.Parent = ContentFrame

        local ContentPadding = Instance.new("UIPadding")
        ContentPadding.PaddingTop = UDim.new(0, 4)
        ContentPadding.PaddingBottom = UDim.new(0, 4)
        ContentPadding.PaddingLeft = UDim.new(0, 8)
        ContentPadding.PaddingRight = UDim.new(0, 8)
        ContentPadding.Parent = ContentFrame

        local ToggleSection = Instance.new("Frame")
        ToggleSection.Name = "ToggleSection"
        ToggleSection.Size = UDim2.new(1, 0, 0, 36)
        ToggleSection.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        ToggleSection.BackgroundTransparency = 0.4
        ToggleSection.BorderSizePixel = 0
        ToggleSection.LayoutOrder = 1
        ToggleSection.Parent = ContentFrame

        local ToggleSectionCorner = Instance.new("UICorner")
        ToggleSectionCorner.CornerRadius = UDim.new(0, 10)
        ToggleSectionCorner.Parent = ToggleSection

        local ToggleLabel = Instance.new("TextLabel")
        ToggleLabel.Name = "Label"
        ToggleLabel.Size = UDim2.new(1, -100, 1, 0)
        ToggleLabel.Position = UDim2.new(0, 12, 0, 0)
        ToggleLabel.BackgroundTransparency = 1
        ToggleLabel.Text = "Respawn Last Location"
        ToggleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        ToggleLabel.TextSize = 12
        ToggleLabel.Font = Enum.Font.Gotham
        ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
        ToggleLabel.Parent = ToggleSection

        local Pill = Instance.new("Frame")
        Pill.Name = "Pill"
        Pill.Size = UDim2.new(0, 40, 0, 22)
        Pill.Position = UDim2.new(1, -52, 0.5, -11)
        Pill.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        Pill.BorderSizePixel = 0
        Pill.Parent = ToggleSection

        local PillCorner = Instance.new("UICorner")
        PillCorner.CornerRadius = UDim.new(0, 11)
        PillCorner.Parent = Pill

        local Knob = Instance.new("Frame")
        Knob.Name = "Knob"
        Knob.Size = UDim2.new(0, 16, 0, 16)
        Knob.Position = UDim2.new(0, 3, 0.5, -8)
        Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Knob.BorderSizePixel = 0
        Knob.Parent = Pill

        local KnobCorner = Instance.new("UICorner")
        KnobCorner.CornerRadius = UDim.new(0, 8)
        KnobCorner.Parent = Knob

        local PillHit = Instance.new("TextButton")
        PillHit.Size = UDim2.new(0, 52, 1, 0)
        PillHit.Position = UDim2.new(1, -56, 0, 0)
        PillHit.BackgroundTransparency = 1
        PillHit.Text = ""
        PillHit.Parent = ToggleSection

        local function SetRespawn(val, save)
            _respawnEnabled = val
            PM.Respawn.enabled = val
            if val then
                TweenService:Create(Pill, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
                TweenService:Create(Knob, TweenInfo.new(0.15), {Position = UDim2.new(1, -19, 0.5, -8)}):Play()
            else
                TweenService:Create(Pill, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
                TweenService:Create(Knob, TweenInfo.new(0.15), {Position = UDim2.new(0, 3, 0.5, -8)}):Play()
            end
            if save ~= false then
                SaveRespawnState()
            end
        end

        PillHit.MouseButton1Click:Connect(function() SetRespawn(not _respawnEnabled) end)

        if _respawnEnabled then
            SetRespawn(true, false)
        end
    end)

    if not success then
        -- Failed to load respawn GUI
    end
end)

registerCommand("fly", "Fly around", {}, function(args)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")
    local LocalPlayer = Players.LocalPlayer
    local HttpService = game:GetService("HttpService")

    local function guiExists(guiName)
        if CoreGui:FindFirstChild(guiName) then return true end
        if LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild(guiName) then return true end
        if get_hidden_gui or gethui then
            if (get_hidden_gui or gethui)():FindFirstChild(guiName) then return true end
        end
        return false
    end
    if guiExists("Prism_FlyGUI") then return end

    local success, err = pcall(function()
        local FLY_GUI_FILE = "prism/prism_fly_gui_settings.json"
        local savedFlyGUI = {}
        pcall(function()
            if readfile and isfile(FLY_GUI_FILE) then
                savedFlyGUI = HttpService:JSONDecode(readfile(FLY_GUI_FILE))
            end
        end)
        local savedPos = savedFlyGUI.position or {X = {Scale = 0, Offset = 900}, Y = {Scale = 0, Offset = 516}}
        local savedMinimized = savedFlyGUI.minimized or false

        local currentFlySettings = {
            position = savedPos,
            minimized = savedMinimized
        }
        
        -- Adjust saved height if it's the old size
        if savedPos and savedPos.Y and savedPos.Y.Offset == 460 then
            savedPos.Y.Offset = 516  -- 460 + 56 for increased height
        elseif savedPos and savedPos.Y and savedPos.Y.Offset == 496 then
            savedPos.Y.Offset = 516  -- 496 + 20 for further increase
        elseif savedPos and savedPos.Y and savedPos.Y.Offset == 532 then
            savedPos.Y.Offset = 516  -- 532 - 16 for new smaller height
        end

        local function SaveFlyGUISettings()
            pcall(function()
                if writefile then
                    if makefolder and not isfolder("prism") then makefolder("prism") end
                    writefile(FLY_GUI_FILE, HttpService:JSONEncode(currentFlySettings))
                end
            end)
        end

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "Prism_FlyGUI"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.DisplayOrder = 1000
        ScreenGui.DisplayOrder = 999

        local ok = pcall(function() ScreenGui.Parent = CoreGui end)
        if not ok then ScreenGui.Parent = LocalPlayer.PlayerGui end

        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, 220, 0, 204)
        MainFrame.Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
        MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        MainFrame.BackgroundTransparency = 0.3
        MainFrame.BorderSizePixel = 0
        MainFrame.ClipsDescendants = true
        MainFrame.Parent = ScreenGui

        local MainCorner = Instance.new("UICorner")
        MainCorner.CornerRadius = UDim.new(0, 14)
        MainCorner.Parent = MainFrame

        local MainStroke = Instance.new("UIStroke")
        MainStroke.Color = Color3.fromRGB(60, 60, 60)
        MainStroke.Thickness = 1
        MainStroke.Parent = MainFrame

        local TitleBar = Instance.new("Frame")
        TitleBar.Name = "TitleBar"
        TitleBar.Size = UDim2.new(1, 0, 0, 36)
        TitleBar.BackgroundTransparency = 1
        TitleBar.Parent = MainFrame

        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Name = "Title"
        TitleLabel.Size = UDim2.new(1, -80, 1, 0)
        TitleLabel.Position = UDim2.new(0, 14, 0, 0)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = "Prism  •  Fly"
        TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TitleLabel.TextSize = 13
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = TitleBar

        local MinBtn = Instance.new("TextButton")
        MinBtn.Name = "Minimize"
        MinBtn.Size = UDim2.new(0, 24, 0, 24)
        MinBtn.Position = UDim2.new(1, -52, 0.5, -12)
        MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        MinBtn.BackgroundTransparency = 0.4
        MinBtn.BorderSizePixel = 0
        MinBtn.Text = "—"
        MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        MinBtn.TextSize = 11
        MinBtn.Font = Enum.Font.GothamBold
        MinBtn.Parent = TitleBar
        local MinCorner = Instance.new("UICorner")
        MinCorner.CornerRadius = UDim.new(0, 6)
        MinCorner.Parent = MinBtn

        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Name = "Close"
        CloseBtn.Size = UDim2.new(0, 24, 0, 24)
        CloseBtn.Position = UDim2.new(1, -26, 0.5, -12)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        CloseBtn.BackgroundTransparency = 0.4
        CloseBtn.BorderSizePixel = 0
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        CloseBtn.TextSize = 11
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.Parent = TitleBar
        local CloseCorner = Instance.new("UICorner")
        CloseCorner.CornerRadius = UDim.new(0, 6)
        CloseCorner.Parent = CloseBtn

        -- Drag functionality
        local dragging = false
        local dragStart = nil
        local startPos = nil

        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
            end
        end)

        TitleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                currentFlySettings.position = {
                    X = {Scale = MainFrame.Position.X.Scale, Offset = MainFrame.Position.X.Offset},
                    Y = {Scale = MainFrame.Position.Y.Scale, Offset = MainFrame.Position.Y.Offset}
                }
                SaveFlyGUISettings()
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        local ContentFrame = Instance.new("Frame")
        ContentFrame.Name = "Content"
        ContentFrame.Size = UDim2.new(1, 0, 1, -40)
        ContentFrame.Position = UDim2.new(0, 0, 0, 40)
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.ClipsDescendants = true
        ContentFrame.Parent = MainFrame

        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local isMinimized = savedMinimized
        local originalSize = UDim2.new(0, 220, 0, 204)
        local minimizedSize = UDim2.new(0, 220, 0, 36)

        if isMinimized then
            MinBtn.Text = "+"
            MainFrame.Size = minimizedSize
            ContentFrame.Visible = false
        end

        MinBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            currentFlySettings.minimized = isMinimized
            SaveFlyGUISettings()
            if isMinimized then
                MinBtn.Text = "+"
                local tween = TweenService:Create(MainFrame, tweenInfo, {Size = minimizedSize})
                tween:Play()
                tween.Completed:Connect(function() ContentFrame.Visible = false end)
            else
                MinBtn.Text = "—"
                ContentFrame.Visible = true
                TweenService:Create(MainFrame, tweenInfo, {Size = originalSize}):Play()
            end
        end)

        -- Fly state
        local flyOn = false
        local flyConn = nil
        local flyLoopConn = nil
        local flySpeed = PM.Fly and PM.Fly.speed or 50
        local bv = nil
        local bg = nil
        local flyAnimTrack = nil
        local flyKey = PM.Fly and PM.Fly.keybind or nil
        local flyCapturing = false
        local flyCaptureConn = nil
        local flyKeyConn = nil
        local charConn = nil
        local charDescendantConn = nil
        local footstepSounds = {}
        local flyQE = PM.Fly and PM.Fly.qeEnabled or false

        local function startFlyLoop()
            if flyLoopConn then flyLoopConn:Disconnect(); flyLoopConn = nil end
            flyLoopConn = RunService.Heartbeat:Connect(function()
                if not flyOn then return end
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not hum or not root then return end
                if hum.PlatformStand ~= true then
                    hum.PlatformStand = true
                end
                if not bv or not bv.Parent then
                    bv = Instance.new("BodyVelocity")
                    bv.MaxForce = Vector3.new(400000, 400000, 400000)
                    bv.Velocity = Vector3.new(0, 0, 0)
                    bv.Parent = root
                else
                    bv.MaxForce = Vector3.new(400000, 400000, 400000)
                end
                if not bg or not bg.Parent then
                    bg = Instance.new("BodyGyro")
                    bg.MaxTorque = Vector3.new(400000, 400000, 400000)
                    bg.P = 90000
                    bg.CFrame = root.CFrame
                    bg.Parent = root
                else
                    bg.MaxTorque = Vector3.new(400000, 400000, 400000)
                end
            end)
        end

        local function MuteFootsteps(char)
            if not char then return end
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("Sound") then
                    local name = obj.Name:lower()
                    if name:find("footstep") or name:find("running") or name:find("walk") then
                        if footstepSounds[obj] == nil then
                            footstepSounds[obj] = obj.Volume
                        end
                        obj.Volume = 0
                    end
                end
            end
            if charDescendantConn then charDescendantConn:Disconnect() end
            charDescendantConn = char.DescendantAdded:Connect(function(obj)
                if obj:IsA("Sound") and flyOn then
                    local name = obj.Name:lower()
                    if name:find("footstep") or name:find("running") or name:find("walk") then
                        if footstepSounds[obj] == nil then
                            footstepSounds[obj] = obj.Volume
                        end
                        obj.Volume = 0
                    end
                end
            end)
        end

        local function UnmuteFootsteps()
            if charDescendantConn then charDescendantConn:Disconnect(); charDescendantConn = nil end
            for sound, oldVol in pairs(footstepSounds) do
                pcall(function()
                    if sound then sound.Volume = oldVol end
                end)
            end
            footstepSounds = {}
        end

        -- Action Buttons
        local BtnSection = Instance.new("Frame")
        BtnSection.Name = "BtnSection"
        BtnSection.Size = UDim2.new(1, 0, 0, 36)
        BtnSection.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        BtnSection.BackgroundTransparency = 0.4
        BtnSection.BorderSizePixel = 0
        BtnSection.LayoutOrder = 1
        BtnSection.Parent = ContentFrame

        local BtnSectionCorner = Instance.new("UICorner")
        BtnSectionCorner.CornerRadius = UDim.new(0, 10)
        BtnSectionCorner.Parent = BtnSection

        local FlyBtn = Instance.new("TextButton")
        FlyBtn.Name = "FlyBtn"
        FlyBtn.Size = UDim2.new(0, 130, 0, 24)
        FlyBtn.Position = UDim2.new(0, 6, 0.5, -12)
        FlyBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        FlyBtn.BackgroundTransparency = 0.4
        FlyBtn.BorderSizePixel = 0
        FlyBtn.Text = "Fly"
        FlyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        FlyBtn.TextSize = 11
        FlyBtn.Font = Enum.Font.GothamBold
        FlyBtn.Parent = BtnSection

        local FlyBtnCorner = Instance.new("UICorner")
        FlyBtnCorner.CornerRadius = UDim.new(0, 6)
        FlyBtnCorner.Parent = FlyBtn

        local BindBtn = Instance.new("TextButton")
        BindBtn.Name = "BindBtn"
        BindBtn.Size = UDim2.new(0, 52, 0, 24)
        BindBtn.Position = UDim2.new(1, -58, 0.5, -12)
        BindBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        BindBtn.BackgroundTransparency = 0.4
        BindBtn.BorderSizePixel = 0
        BindBtn.Text = flyKey and flyKey.Name or "Bind"
        BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        BindBtn.TextSize = 11
        BindBtn.Font = Enum.Font.GothamBold
        BindBtn.Parent = BtnSection

        local BindBtnCorner = Instance.new("UICorner")
        BindBtnCorner.CornerRadius = UDim.new(0, 6)
        BindBtnCorner.Parent = BindBtn

        -- Hover effects
        FlyBtn.MouseEnter:Connect(function()
            TweenService:Create(FlyBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(55, 55, 55)}):Play()
        end)
        FlyBtn.MouseLeave:Connect(function()
            TweenService:Create(FlyBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
        end)
        BindBtn.MouseEnter:Connect(function()
            TweenService:Create(BindBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(55, 55, 55)}):Play()
        end)
        BindBtn.MouseLeave:Connect(function()
            TweenService:Create(BindBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
        end)

        local ListLayout = Instance.new("UIListLayout")
        ListLayout.Padding = UDim.new(0, 6)
        ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ListLayout.Parent = ContentFrame

        local Padding = Instance.new("UIPadding")
        Padding.PaddingTop = UDim.new(0, 4)
        Padding.PaddingBottom = UDim.new(0, 4)
        Padding.PaddingLeft = UDim.new(0, 8)
        Padding.PaddingRight = UDim.new(0, 8)
        Padding.Parent = ContentFrame

        -- Speed slider section
        local SpeedSection = Instance.new("Frame")
        SpeedSection.Size = UDim2.new(1, 0, 0, 52)
        SpeedSection.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        SpeedSection.BackgroundTransparency = 0.4
        SpeedSection.BorderSizePixel = 0
        SpeedSection.LayoutOrder = 3
        SpeedSection.Parent = ContentFrame

        local SSC = Instance.new("UICorner")
        SSC.CornerRadius = UDim.new(0, 10)
        SSC.Parent = SpeedSection

        local SSP = Instance.new("UIPadding")
        SSP.PaddingTop = UDim.new(0, 5)
        SSP.PaddingBottom = UDim.new(0, 5)
        SSP.Parent = SpeedSection

        local SIL = Instance.new("UIListLayout")
        SIL.Padding = UDim.new(0, 2)
        SIL.SortOrder = Enum.SortOrder.LayoutOrder
        SIL.Parent = SpeedSection

        local SLabelRow = Instance.new("Frame")
        SLabelRow.Size = UDim2.new(1, 0, 0, 20)
        SLabelRow.BackgroundTransparency = 1
        SLabelRow.LayoutOrder = 1
        SLabelRow.Parent = SpeedSection

        local SLP = Instance.new("UIPadding")
        SLP.PaddingLeft = UDim.new(0, 12)
        SLP.PaddingRight = UDim.new(0, 12)
        SLP.Parent = SLabelRow

        local SNameLbl = Instance.new("TextLabel")
        SNameLbl.Size = UDim2.new(1, -60, 1, 0)
        SNameLbl.BackgroundTransparency = 1
        SNameLbl.Text = "Speed"
        SNameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        SNameLbl.TextSize = 12
        SNameLbl.Font = Enum.Font.Gotham
        SNameLbl.TextXAlignment = Enum.TextXAlignment.Left
        SNameLbl.Parent = SLabelRow

        local SValLbl = Instance.new("TextLabel")
        SValLbl.Size = UDim2.new(0, 55, 1, 0)
        SValLbl.Position = UDim2.new(1, -55, 0, 0)
        SValLbl.BackgroundTransparency = 1
        SValLbl.Text = tostring(math.floor(flySpeed))
        SValLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
        SValLbl.TextSize = 11
        SValLbl.Font = Enum.Font.Gotham
        SValLbl.TextXAlignment = Enum.TextXAlignment.Right
        SValLbl.Parent = SLabelRow

        local SSliderRow = Instance.new("Frame")
        SSliderRow.Size = UDim2.new(1, 0, 0, 18)
        SSliderRow.BackgroundTransparency = 1
        SSliderRow.LayoutOrder = 2
        SSliderRow.Parent = SpeedSection

        local SSRP = Instance.new("UIPadding")
        SSRP.PaddingLeft = UDim.new(0, 12)
        SSRP.PaddingRight = UDim.new(0, 12)
        SSRP.Parent = SSliderRow

        local SSliderBg = Instance.new("Frame")
        SSliderBg.Size = UDim2.new(1, 0, 0, 6)
        SSliderBg.Position = UDim2.new(0, 0, 0.5, -3)
        SSliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        SSliderBg.BorderSizePixel = 0
        SSliderBg.Active = true
        SSliderBg.Parent = SSliderRow

        local STkC = Instance.new("UICorner")
        STkC.CornerRadius = UDim.new(0, 3)
        STkC.Parent = SSliderBg

        local initFlyScale = math.clamp(flySpeed / 500, 0, 1)
        local SSliderFill = Instance.new("Frame")
        SSliderFill.Size = UDim2.new(initFlyScale, 0, 1, 0)
        SSliderFill.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        SSliderFill.BorderSizePixel = 0
        SSliderFill.Parent = SSliderBg

        local SFC = Instance.new("UICorner")
        SFC.CornerRadius = UDim.new(0, 3)
        SFC.Parent = SSliderFill

        local SSliderKnob = Instance.new("Frame")
        SSliderKnob.Size = UDim2.new(0, 14, 0, 14)
        SSliderKnob.Position = UDim2.new(initFlyScale, 0, 0.5, 0)
        SSliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
        SSliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        SSliderKnob.BorderSizePixel = 0
        SSliderKnob.ZIndex = 3
        SSliderKnob.Parent = SSliderBg

        local SKC = Instance.new("UICorner")
        SKC.CornerRadius = UDim.new(0, 7)
        SKC.Parent = SSliderKnob

        local sliderDragging = false
        local function updateFlySpeed(value)
            flySpeed = math.clamp(math.floor(value + 0.5), 0, 500)
            local scale = flySpeed / 500
            SSliderFill.Size = UDim2.new(scale, 0, 1, 0)
            SSliderKnob.Position = UDim2.new(scale, 0, 0.5, 0)
            SValLbl.Text = tostring(flySpeed)
            PM.Fly = PM.Fly or {}
            PM.Fly.speed = flySpeed
            SaveFlyState()
            SaveFlyGUISettings()
        end

        SSliderKnob.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = true
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if sliderDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local rel = math.clamp((i.Position.X - SSliderBg.AbsolutePosition.X) / SSliderBg.AbsoluteSize.X, 0, 1)
                updateFlySpeed(rel * 500)
            end
        end)
        local lastClickSpeed = 0
        SSliderBg.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                local now = tick()
                if now - lastClickSpeed < 0.3 then
                    updateFlySpeed(50)
                    sliderDragging = false
                else
                    local rel = math.clamp((i.Position.X - SSliderBg.AbsolutePosition.X) / SSliderBg.AbsoluteSize.X, 0, 1)
                    updateFlySpeed(rel * 500)
                    sliderDragging = true
                end
                lastClickSpeed = now
            end
        end)

        -- QE Toggle section
        local QESection = Instance.new("Frame")
        QESection.Size = UDim2.new(1, 0, 0, 32)
        QESection.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        QESection.BackgroundTransparency = 0.4
        QESection.BorderSizePixel = 0
        QESection.LayoutOrder = 2
        QESection.Parent = ContentFrame

        local QECorner = Instance.new("UICorner")
        QECorner.CornerRadius = UDim.new(0, 10)
        QECorner.Parent = QESection

        local QELabel = Instance.new("TextLabel")
        QELabel.Size = UDim2.new(1, -100, 1, 0)
        QELabel.Position = UDim2.new(0, 12, 0, 0)
        QELabel.BackgroundTransparency = 1
        QELabel.Text = "E Up / Q Down"
        QELabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        QELabel.TextSize = 12
        QELabel.Font = Enum.Font.Gotham
        QELabel.TextXAlignment = Enum.TextXAlignment.Left
        QELabel.Parent = QESection

        local QEPill = Instance.new("Frame")
        QEPill.Name = "Pill"
        QEPill.Size = UDim2.new(0, 40, 0, 22)
        QEPill.Position = UDim2.new(1, -52, 0.5, -11)
        QEPill.BackgroundColor3 = flyQE and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(60, 60, 60)
        QEPill.BorderSizePixel = 0
        QEPill.Parent = QESection

        local QEPillCorner = Instance.new("UICorner")
        QEPillCorner.CornerRadius = UDim.new(0, 11)
        QEPillCorner.Parent = QEPill

        local QEKnob = Instance.new("Frame")
        QEKnob.Name = "Knob"
        QEKnob.Size = UDim2.new(0, 16, 0, 16)
        QEKnob.Position = flyQE and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        QEKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        QEKnob.BorderSizePixel = 0
        QEKnob.Parent = QEPill

        local QEKnobCorner = Instance.new("UICorner")
        QEKnobCorner.CornerRadius = UDim.new(0, 8)
        QEKnobCorner.Parent = QEKnob

        local QEHit = Instance.new("TextButton")
        QEHit.Size = UDim2.new(0, 52, 1, 0)
        QEHit.Position = UDim2.new(1, -56, 0, 0)
        QEHit.BackgroundTransparency = 1
        QEHit.Text = ""
        QEHit.Parent = QESection

        local function SetQE(val)
            flyQE = val
            PM.Fly = PM.Fly or {}
            PM.Fly.qeEnabled = flyQE
            SaveFlyState()
            SaveFlyGUISettings()

            if val then
                TweenService:Create(QEPill, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
                TweenService:Create(QEKnob, TweenInfo.new(0.15), {Position = UDim2.new(1, -19, 0.5, -8)}):Play()
            else
                TweenService:Create(QEPill, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
                TweenService:Create(QEKnob, TweenInfo.new(0.15), {Position = UDim2.new(0, 3, 0.5, -8)}):Play()
            end
        end

        QEHit.MouseButton1Click:Connect(function() SetQE(not flyQE) end)

        if flyQE then SetQE(true) end

        -- Fly logic
        local function StopFly()
            flyOn = false
            UnmuteFootsteps()
            if flyConn then flyConn:Disconnect(); flyConn = nil end
            if flyLoopConn then flyLoopConn:Disconnect(); flyLoopConn = nil end
            if bv then bv:Destroy(); bv = nil end
            if bg then bg:Destroy(); bg = nil end
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            if flyAnimTrack then
                pcall(function() flyAnimTrack:Stop() end)
                flyAnimTrack = nil
            end
        end

        local function StartFly()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not hum or not root then
                flyOn = false
                return
            end
            MuteFootsteps(char)

            pcall(function()
                local anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://132783162476851"
                local animator = hum:FindFirstChildOfClass("Animator")
                if animator then
                    flyAnimTrack = animator:LoadAnimation(anim)
                else
                    flyAnimTrack = hum:LoadAnimation(anim)
                end
                if flyAnimTrack then
                    flyAnimTrack.Priority = Enum.AnimationPriority.Action
                    flyAnimTrack:Play()
                end
            end)

            hum.PlatformStand = true

            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(400000, 400000, 400000)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = root

            bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(400000, 400000, 400000)
            bg.P = 90000
            bg.CFrame = root.CFrame
            bg.Parent = root

            flyConn = RunService.RenderStepped:Connect(function()
                if not flyOn then return end
                local cam = workspace.CurrentCamera
                local newChar = LocalPlayer.Character
                local newRoot = newChar and newChar:FindFirstChild("HumanoidRootPart")
                local newHum = newChar and newChar:FindFirstChildOfClass("Humanoid")
                if not newRoot or not newHum or not cam then
                    StopFly()
                    return
                end
                local dir = Vector3.new(0, 0, 0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if flyQE then
                    if UserInputService:IsKeyDown(Enum.KeyCode.E) then dir = dir + Vector3.new(0, 1, 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then dir = dir - Vector3.new(0, 1, 0) end
                end
                if dir.Magnitude > 0 then dir = dir.Unit * flySpeed end
                bv.Velocity = dir
                bg.CFrame = cam.CFrame
            end)
            startFlyLoop()
        end

        local flyCountingDown = false
        local flyCountdownTask = nil

        local function SetFly(val)
            if val == flyOn then return end
            if val then
                flyOn = true
                FlyBtn.Text = "Stop"
                StartFly()
            else
                flyOn = false
                FlyBtn.Text = "Fly"
                StopFly()
            end
            PM.Fly = PM.Fly or {}
            PM.Fly.enabled = flyOn
            SaveFlyState()
        end

        FlyBtn.MouseButton1Click:Connect(function()
            SetFly(not flyOn)
        end)

        -- Auto-start if previously enabled
        if PM.Fly.enabled then
            FlyBtn.Text = "Stop"
            SetFly(true)
        end

        charConn = LocalPlayer.CharacterAdded:Connect(function()
            StopFly()
            FlyBtn.Text = "Fly"
        end)

        ScreenGui.Destroying:Connect(function()
            if flyOn then
                StopFly()
                FlyBtn.Text = "Fly"
            end
        end)

        local function UpdateBindDisplay()
            if flyKey then
                BindBtn.Text = flyKey.Name
            else
                BindBtn.Text = "Bind"
            end
        end
        UpdateBindDisplay()

        local function SaveFlyKey()
            PM.Fly = PM.Fly or {}
            PM.Fly.keybind = flyKey
            SaveFlyState()
        end

        local function CancelCapture()
            flyCapturing = false
            flyKey = nil
            if flyCaptureConn then flyCaptureConn:Disconnect(); flyCaptureConn = nil end
            UpdateBindDisplay()
            SaveFlyKey()
        end

        local function EnableGlobalFly()
            if flyKeyConn then return end
            flyKeyConn = UserInputService.InputBegan:Connect(function(input, gpe)
                if gpe or flyCapturing then return end
                if UserInputService:GetFocusedTextBox() then return end
                if input.UserInputType == Enum.UserInputType.Keyboard and flyKey and input.KeyCode == flyKey then
                    SetFly(not flyOn)
                end
            end)
        end

        BindBtn.MouseButton1Click:Connect(function()
            flyCapturing = true
            if flyKeyConn then flyKeyConn:Disconnect(); flyKeyConn = nil end
            BindBtn.Text = "..."
            BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)

            if flyCaptureConn then flyCaptureConn:Disconnect() end
            flyCaptureConn = UserInputService.InputBegan:Connect(function(input, gpe)
                if gpe then return end
                if not flyCapturing then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    if input.KeyCode == Enum.KeyCode.Backspace then
                        flyKey = nil
                        flyCapturing = false
                        flyCaptureConn:Disconnect(); flyCaptureConn = nil
                        UpdateBindDisplay()
                        BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                        SaveFlyKey()
                        EnableGlobalFly()
                    else
                        flyKey = input.KeyCode
                        flyCapturing = false
                        flyCaptureConn:Disconnect(); flyCaptureConn = nil
                        UpdateBindDisplay()
                        BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                        SaveFlyKey()
                        EnableGlobalFly()
                    end
                elseif input.UserInputType == Enum.UserInputType.MouseButton1 or
                       input.UserInputType == Enum.UserInputType.MouseButton2 or
                       input.UserInputType == Enum.UserInputType.MouseButton3 then
                    CancelCapture()
                    BindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                    EnableGlobalFly()
                end
            end)
        end)

        EnableGlobalFly()

        CloseBtn.MouseButton1Click:Connect(function()
            flyCapturing = false
            if flyOn then
                StopFly()
                PM.Fly = PM.Fly or {}
                PM.Fly.enabled = false
                SaveFlyState()
            end
            if flyCaptureConn then flyCaptureConn:Disconnect(); flyCaptureConn = nil end
            if flyKeyConn then flyKeyConn:Disconnect(); flyKeyConn = nil end
            if charConn then charConn:Disconnect(); charConn = nil end
            if flyLoopConn then flyLoopConn:Disconnect(); flyLoopConn = nil end
            ScreenGui:Destroy()
        end)
    end)

    if not success then
        -- Failed to load fly GUI
    end
end)

-- ========== COMMANDS PANEL POPULATION ==========

PM.populateCommandsPanel = function()
    if not PM.UI.CommandsScroll then return end

    local childCount = 0
    for _, child in ipairs(PM.UI.CommandsScroll:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    PM.UI.CommandButtons = {}

    local sorted = {}
    for _, cmd in pairs(PM.Commands) do
        table.insert(sorted, cmd)
    end
    table.sort(sorted, function(a, b) return a.name:lower() < b.name:lower() end)

    for _, cmd in ipairs(sorted) do
        local btn = PM.mk("TextButton", PM.UI.CommandsScroll, {
            Name = cmd.name,
            Size = UDim2.new(1, -6, 0, 36),
            BackgroundColor3 = PM.C and PM.C.card or Color3.fromRGB(28, 28, 28),
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 102,
        })
        PM.corner(btn, 6)

        PM.mk("TextLabel", btn, {
            Size = UDim2.new(1, -16, 0, 16),
            Position = UDim2.new(0, 8, 0, 2),
            BackgroundTransparency = 1,
            Text = cmd.name,
            TextColor3 = PM.C and PM.C.text or Color3.fromRGB(230, 230, 230),
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 103,
        })

        PM.mk("TextLabel", btn, {
            Size = UDim2.new(1, -16, 0, 14),
            Position = UDim2.new(0, 8, 0, 18),
            BackgroundTransparency = 1,
            Text = cmd.desc,
            TextColor3 = PM.C and PM.C.textDim or Color3.fromRGB(90, 90, 90),
            TextSize = 9,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
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
            cmd.execute({})
        end)

        table.insert(PM.UI.CommandButtons, {name = cmd.name, desc = cmd.desc, btn = btn})
    end

    local count = #PM.UI.CommandButtons
    PM.UI.CommandsScroll.CanvasSize = UDim2.new(0, 0, 0, count * 38)
end

-- ========== AUTO EXEC PANEL POPULATION ==========

PM.autoExecStates = {}

PM.populateAutoExecPanel = function()
    if not PM.UI.AutoExecScroll then return end

    local childCount = 0
    for _, child in ipairs(PM.UI.AutoExecScroll:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" then
            child:Destroy()
        end
    end

    PM.UI.AutoExecRows = {}

    local function makeToggleRow(parent, name, labelText, layoutOrder, defaultState, onToggle)
        local bg = PM.mk("Frame", parent, {
            Name = name .. "Bg",
            Size = UDim2.new(1, -6, 0, 26),
            BackgroundColor3 = PM.C and PM.C.card or Color3.fromRGB(28, 28, 28),
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            LayoutOrder = layoutOrder,
            ZIndex = 102,
        })
        PM.corner(bg, 6)

        PM.mk("TextLabel", bg, {
            Size = UDim2.new(1, -56, 0, 20),
            Position = UDim2.new(0, 8, 0, 3),
            BackgroundTransparency = 1,
            Text = labelText,
            TextColor3 = PM.C and PM.C.text or Color3.fromRGB(230, 230, 230),
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

        return bg, switch, circle, hitBtn
    end

    local sorted = {}
    for _, cmd in pairs(PM.Commands) do
        table.insert(sorted, cmd)
    end
    table.sort(sorted, function(a, b) return a.name:lower() < b.name:lower() end)

    for i, cmd in ipairs(sorted) do
        -- Skip commands that should not be auto-executed
        if cmd.excludeFromAutoExec then continue end
        
        local isEnabled = PM.autoExecStates[cmd.name] or false
        local row, switch, circle, hitBtn = makeToggleRow(
            PM.UI.AutoExecScroll,
            "AutoExec_" .. cmd.name,
            cmd.name,
            i,
            isEnabled,
            function(state)
                PM.autoExecStates[cmd.name] = state
                PM.saveAutoExecStates()
            end
        )
        table.insert(PM.UI.AutoExecRows, {name = cmd.name, row = row})
    end
end

PM.filterAutoExecPanel = function(query)
    query = (query or ""):lower()
    for _, data in ipairs(PM.UI.AutoExecRows or {}) do
        local match = data.name:lower():find(query, 1, true) or query == ""
        data.row.Visible = match
    end
end

-- ========== TERMINAL EXECUTION ==========

PM.printTerminal = function(text)
    if not PM.UI.TerminalOutput then return end
    PM.UI.TerminalOutput.Text = PM.UI.TerminalOutput.Text .. "\n" .. text
end

PM.executeCommand = function(input)
    input = input:gsub("^%s+", ""):gsub("%s+$", "")
    if input == "" then return end

    local parts = {}
    for part in input:gmatch("%S+") do
        table.insert(parts, part)
    end

    local cmdName = parts[1]:lower()
    table.remove(parts, 1)

    local cmd = PM.Commands[cmdName]
    if not cmd then
        -- check aliases
        for _, c in pairs(PM.Commands) do
            for _, alias in ipairs(c.aliases) do
                if alias:lower() == cmdName then
                    cmd = c
                    break
                end
            end
            if cmd then break end
        end
    end

    if cmd then
        pcall(function()
            cmd.execute(parts)
        end)
    end
end

-- ========== TERMINAL OUTPUT LABEL ==========

PM.createTerminalOutput = function()
    if PM.UI.TerminalOutput then return end
    if not PM.UI.TerminalPanel then return end

    PM.UI.TerminalOutput = PM.mk("TextLabel", PM.UI.TerminalPanel, {
        Name = "TerminalOutput",
        Size = UDim2.new(1, -20, 0, 200),
        Position = UDim2.new(0, 10, 0, 38),
        BackgroundTransparency = 1,
        Text = "Type 'help' for available commands.",
        TextColor3 = PM.C and PM.C.text or Color3.fromRGB(230, 230, 230),
        TextSize = 11,
        Font = Enum.Font.RobotoMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 101,
    })
end

-- ========== AUTO EXECUTE FUNCTIONALITY ==========

PM.AUTOEXEC_SAVE_FILE = "prism/prism_autoexec.json"

-- Save auto exec states to file
PM.saveAutoExecStates = function()
    if not writefile then return end
    
    local states = {}
    for name, cmd in pairs(PM.Commands) do
        if not cmd.excludeFromAutoExec then
            states[name] = PM.autoExecStates[name] or false
        end
    end
    
    pcall(function()
        if not isfolder("prism") then
            makefolder("prism")
        end
        writefile(PM.AUTOEXEC_SAVE_FILE, game:GetService("HttpService"):JSONEncode(states))
    end)
end

-- Load auto exec states from file
PM.loadAutoExecStates = function()
    if not readfile then return end
    
    pcall(function()
        local data = readfile(PM.AUTOEXEC_SAVE_FILE)
        if data then
            local states = game:GetService("HttpService"):JSONDecode(data)
            for name, state in pairs(states) do
                PM.autoExecStates[name] = state
            end
        end
    end)
end

-- Execute auto exec commands on startup
PM.executeAutoExecCommands = function()
    -- Check if auto execute is enabled globally
    if PM.autoExecuteCommands == false then return end
    
    for name, cmd in pairs(PM.Commands) do
        -- Skip excluded commands
        if not cmd.excludeFromAutoExec then
            local isEnabled = PM.autoExecStates[name] or false
            if isEnabled then
                pcall(function()
                    cmd.execute({})
                end)
            end
        end
    end
end

-- Populate panels after this file loads
-- Wait for Main.lua to create the UI functions if needed
local retries = 0
while (not PM.createCommandsPanel or not PM.createSettingsPanel) and retries < 20 do
    task.wait(0.1)
    retries = retries + 1
end

-- Load saved auto exec states first
if PM.loadAutoExecStates then PM.loadAutoExecStates() end

registerCommand("discord", "Discord invite", {"support", "help"}, function(args, speaker)
	local everyClipboard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
	local httprequest = http_request or (syn and syn.request) or request
	
	if everyClipboard then
		everyClipboard('https://discord.com/invite/S3UFq2VXtv')
		PM.notify('Discord Invite', 'Copied to clipboard!\ndiscord.gg/S3UFq2VXtv')
	else
		PM.notify('Discord Invite', 'discord.gg/S3UFq2VXtv')
	end
	
	if httprequest then
		httprequest({
			Url = 'http://127.0.0.1:6463/rpc?v=1',
			Method = 'POST',
			Headers = {
				['Content-Type'] = 'application/json',
				Origin = 'https://discord.com'
			},
			Body = HttpService:JSONEncode({
				cmd = 'INVITE_BROWSER',
				nonce = HttpService:GenerateGUID(false),
				args = {code = 'S3UFq2VXtv'}
			})
		})
	end
end, true)

-- Create panels if they don't exist
if not PM.UI.CommandsPanel and PM.createCommandsPanel then
    PM.createCommandsPanel()
end
if not PM.UI.SettingsPanel and PM.createSettingsPanel then
    PM.createSettingsPanel()
end

-- Populate the panels
PM.populateCommandsPanel()
PM.populateAutoExecPanel()
if PM.createTerminalOutput then PM.createTerminalOutput() end

if PM.UI.AutoExecSearch then
    PM.UI.AutoExecSearch:GetPropertyChangedSignal("Text"):Connect(function()
        PM.filterAutoExecPanel(PM.UI.AutoExecSearch.Text)
    end)
end

-- Execute auto exec commands after everything is loaded
PM.executeAutoExecCommands()

return PM.Commands
