local BASE = "https://prismscript.vercel.app/"

local function loadScript(url, name)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    return ok, result
end

getgenv().PrismLoaded = true

loadScript(BASE .. "/Prism%20Main.lua", "Main")

loadScript(BASE .. "/Prism%20Commands.lua", "Commands")