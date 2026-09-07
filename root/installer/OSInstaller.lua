local user = "Hedgehogedgehog"
local repo = "CC-OS"
local branch = "main"
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
    local file = fs.open(path, "w+")
    file.write(contents)
    file.close()
end

local function fetchFile(path, baseURL)
    local link = baseURL .. path

    local request = http.get(link)
    return request.readAll()

end

local function fetchFolder(folder)


    local APIURL = ("https://api.github.com/repos/%s/%s/contents/%s?ref=%s"):format(user, repo, folder, branch)

    local APIResponse = http.get(APIURL)

    if not APIResponse then 
        log("Failed to fetch folder if you have a older version of CC-OS installed it will continue to work else try to install agien later")
        return
    end
    
    ---@type table
    local contents = textutils.unserialiseJSON(APIResponse.readAll())
    --log(textutils.serialize(contents))

    APIResponse.close()

    for _, file in pairs(contents) do
	    if file.type == "file" then
            log("Fetching file: " .. file.path)
            local fileContents = fetchFile(file.path, baseURL)
            createFile(fileContents, file.path)
        elseif file.type == "dir" then
            log("Fetching folder: " .. file.path)
            createFolder(file.path)
            fetchFolder(file.path)
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
    fetchFolder(rootPath)
    --shell.run("clear")
end

local function readyInstall()
    clearLog()
    configComputerSettings()
    installOS()
end

readyInstall()
log("install complete")