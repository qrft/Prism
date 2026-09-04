local BASE = "https://prismscript.vercel.app"

local function loadScript(url, name)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    return ok, result
end

-- Set auth flag to true immediately (key system removed)
getgenv().PrismLoaded = true

-- 1. Main UI
loadScript(BASE .. "/Prism%20Main.lua", "Main")

-- 2. Commands
loadScript(BASE .. "/Prism%20Commands.lua", "Commands")
