local function isAdmin()
    local h = io.popen("net session 2>&1")
    local out = h:read("*a")
    h:close()
    return not out:match("Access is denied")
end

if not isAdmin() then
    local exe = '"' .. arg[0] .. '"'
    local cmd = 'powershell -Command "Start-Process ' .. exe .. ' -Verb runAs"'
    os.execute(cmd)
    os.exit()
end

local installPath = "C:\\lime"
os.execute('mkdir "' .. installPath .. '" >nul 2>nul')

local function dirname(path)
    return path:match("^(.*)[/\\][^/\\]+$")
end

local self = arg[0]
local base = dirname(self)

local source = base .. "\\lime.exe"
local dest = "C:\\lime\\lime.exe"

local copy = 'copy "' .. source .. '" "' .. dest .. '" /Y >nul'
os.execute(copy)

local function getPath()
    local h = io.popen('reg query "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment" /v Path')
    if not h then return nil end
    local o = h:read("*a")
    h:close()
    return o
end

local env = getPath()
local has = false

if env and env:lower():find("c:\\lime") then
    has = true
end

if not has then
    local d = "%Path%;C:\\\\lime"
    local cmd = 'reg add "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment" /v Path /t REG_EXPAND_SZ /d "' .. d .. '" /f'
    os.execute(cmd)
end

print("Lime installed. Restart your terminal.")
os.execute("pause")
