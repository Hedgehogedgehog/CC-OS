local user = "Hedgehogedgehog"
local repo = "CC-OS"
local branch = "rewrite-installer"
local baseURL = "https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/refs/heads/" .. branch .. "/"

local rootPath = "root"

local installerLogPath = "installerLog.log"

local function clearLog()
    fs.delete(installerLogPath)
end

local function log(message)
    print(message)
    local file = fs.open(installerLogPath, "a")
    file.writeLine(message)
    file.close()
end

local function createFolder (folderPath)
    if fs.exists(folderPath) then
        return
    end
    fs.makeDir(folderPath)
    log("Created folder: " .. folderPath)
end

local function createFile(contents, path)

    local dir = fs.getDir(path)
    if dir and dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local file = fs.open(path, "w+")
    if file then
        file.write(contents)
        file.close()
        return true
    end
    return false
end

local function fetchFile(path, baseURL)
    local link = baseURL .. path

    local request = http.get(link)

    if not request then 
        return "ERROR"
        end
    return request.readAll()

end

local function fetchFolder(folder)


    local APIURL = ("https://api.github.com/repos/%s/%s/contents/%s?ref=%s"):format(user, repo, folder, branch)
    --local APIURL = ("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1"):format(user, repo, branch)
    

    local APIResponse = http.get(APIURL)

    if not APIResponse then 
        log("Failed to fetch folder if you have a older version of CC-OS installed it will continue to work else try to install agien later")
        return "ERROR"
    end
    
    ---@type table
    local contents = textutils.unserialiseJSON(APIResponse.readAll())
    --log(textutils.serialize(contents))

    APIResponse.close()

    for _, file in pairs(contents) do
	    if file.type == "file" then

            log("Fetching file: " .. file.path)
            local fileContents = fetchFile(file.path, baseURL)
            if fileContents == "ERROR" then
                return "ERROR"
            end

            createFile(fileContents, file.path)

        elseif file.type == "dir" then

            log("Fetching folder: " .. file.path)
            createFolder(file.path)
            local errors = fetchFolder(file.path)
            if errors == "ERROR" then
                return "ERROR"
            end

        end
    end
end

local function installRoot()

    local APIURL = ("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1"):format(user, repo, branch)
    local APIResponse = http.get(APIURL, { ["User-Agent"] = "CC-OS-Installer" })

    --local APIResponse = http.get(APIURL)

    if not APIResponse then 
        log("Failed to fetch folder if you have a older version of CC-OS installed it will continue to work else try to install agien later")
        return "ERROR"
    end
    
    ---@type table
    local contents = textutils.unserialiseJSON(APIResponse.readAll())
    --log(textutils.serialize(contents))

    APIResponse.close()

    if not contents or not contents.tree then
        log("ERROR: Invalid tree data received from GitHub.")
        return "ERROR"
    end

    local rootPrefix = "root/"

    for _, item in pairs(contents.tree) do
	    if item.type == "blob" and item.path:sub(1, #rootPrefix) == rootPrefix then

            log("Fetching item: " .. item.path)
            local fileContents = fetchFile(item.path, baseURL)
            if fileContents == "ERROR" then
                return "ERROR"
            end

            createFile(fileContents, item.path)

        elseif item.type == "dir" then

            log("Fetching folder: " .. item.path)
            createFolder(item.path)
            local errors = fetchFolder(item.path)
            if errors == "ERROR" then
                return "ERROR"
            end

        end
    end
end

local function configComputerSettings()
    log("Configuring Computer Settings")

    shell.run("Set motd.enable false")

    shell.run("clear")
end


local function installOS()
    log("Installing OS")
    --fetchFolder(rootPath)
    --shell.run("clear")
    installRoot()
end


local function setupStartup()
    local startupScriptPath = "startup.lua"
    createFile('shell.run("/root/sys/kernal/kernal.lua")', startupScriptPath)
    
end


local function readyInstall()
    setupStartup()
    clearLog()
    configComputerSettings()
    local errors = installOS()
    if errors == "ERROR" then
        log("There was an error installing the OS if you have a older version of CC-OS installed it will continue to work else try to install agien later")
    else 
        log("OS installed successfully")
    end
end

readyInstall()
log("install process complete")
log("Booting into OS if the OS does not exist the computer will boot into Crafty-OS")
--shell.run("/root/sys/kernal/kernal.lua")