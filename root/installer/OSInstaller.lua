local user = "Hedgehogedgehog"
local repo = "CC-OS"
local branch = "main"
local baseURL = "https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/refs/heads/" .. branch .. "/"

local rootPath = "root"

local installerLogPath = "installerLog.txt"

local function clearLog()
    fs.delete(installerLogPath)
end

local function log(message)
    print(message)
    local file = fs.open(installerLogPath, "a")
    file.writeLine(message)
    file.close()
end

local function fetchFolder(folder, baseURL)
    --local link = baseURL .. folder

    --print("Fetching folder: " , folder, " From: " , link)

    --local request = http.get("https://raw.githubusercontent.com/Hedgehogedgehog/CC-OS/refs/heads/main/root/sys/startup.lua")
    --local request = http.get("https://example.tweaked.cc")
    --local request = http.get(link)
    --print(request.readAll())

    local folderPath = folder

    local APIURL = ("https://api.github.com/repos/%s/%s/contents/%s?ref=%s"):format(user, repo, folder, branch)

    local APIResponse = http.get(APIURL)

    if not APIResponse then 
        log("Failed to fetch folder if you have a older version of CC-OS installed it will continue to work else try to install agien later")
        return
    end
    
    ---@type table
    local contents = textutils.unserialiseJSON(APIResponse.readAll())
    log(textutils.serialize(contents))
end

local function configComputerSettings()
    log("Configuring Computer Settings")

    shell.run("Set motd.enable false")

    shell.run("clear")
end


local function installOS()
    log("Installing OS")
    fetchFolder("root", baseURL)

    --shell.run("clear")
end

local function readyInstall()
    clearLog()
    configComputerSettings()
    installOS()
end

readyInstall()
log("install complete")