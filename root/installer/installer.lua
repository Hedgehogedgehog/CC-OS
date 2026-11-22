local user = "Hedgehogedgehog"
local repo = "CC-OS"
local branch = "feature/cheapInstaller"

local rootPath = "root"

local installerSavePath = "/root/installer/saves/installerSave.json"

-- ------------------------------------------------------------------

local Logger = {}
Logger.__index = Logger

Logger.installerLogPath = "installerLog.log"

function Logger:setLogFilePath(path)
    self.installerLogPath = path
end

function Logger:clearLog()
    fs.delete(self.installerLogPath)
end

function Logger:log(message)
    print(message)
    local file = fs.open(self.installerLogPath, "a")
    file.writeLine(message)
    file.close()
end

function Logger:new(logPath)
    local self = setmetatable({}, Logger)
    self.installerLogPath = logPath
    return self
end

-- ----------------------------------------------------------------

local InstallerSaves = {}
InstallerSaves.__index = InstallerSaves

InstallerSaves.installerSavePath = "/root/installer/saves/installerSave.json"

function InstallerSaves:new(
    savePath
)
    local self = setmetatable({}, InstallerSaves)
    self.savePath = savePath or InstallerSaves.installerSavePath

    if fs.exists(fs.getDir(self.savePath)) then
        return self
    end

    fs.makeDir(fs.getDir(self.savePath))

    return self
    
end

function InstallerSaves:getValue(key)
    if not fs.exists(self.savePath) then
        return nil
    end

    local file = fs.open(self.savePath, "r")
    local data = textutils.unserialize(file.readAll()) or {}
    file.close()

    return data[key]
    
end

function InstallerSaves:setValue(key, value)
    local data = {}
    if fs.exists(self.savePath) then
        local file = fs.open(self.savePath, "r")
        data = textutils.unserialize(file.readAll()) or {}
        file.close()
    end

    data[key] = value

    local file = fs.open(self.savePath, "w")
    file.write(textutils.serialize(data))
    file.close()
end

-- ------------------------------------------------------------------

local GitHubSource = {}
GitHubSource.__index = GitHubSource

GitHubSource.user = "Hedgehogedgehog"
GitHubSource.repo = "CC-OS"
GitHubSource.branch = "main"

function GitHubSource:new(
    user,
    repo,
    branch,
    rootPath
)

    local self = setmetatable({}, GitHubSource)
    self.user = user
    self.repo = repo
    self.branch = branch
    self.rootPath = rootPath
    self.headers = { ["User-Agent"] = "CC-OS-Installer" }

    return self
end

function GitHubSource:get(url, headers, binary)
    local res, err = http.get(url, headers or self.headers, binary)
    if not res then return nil, err end
    local body = res.readAll()
    res.close()
    return body
end

function GitHubSource:getLatestCommit()
    local url = ("https://api.github.com/repos/%s/%s/commits/%s"):format(self.user, self.repo, self.branch)
    local body, err = self:get(url, { ["User-Agent"] = self.headers["User-Agent"], ["Accept"] = "application/vnd.github.sha" })
    if not body then return nil, err end
    body = body:gsub("%s+", "")
    if not body:match("^%x+$") then return nil, "unexpected response" end
    return body
end

function GitHubSource:getTreeHash(commit, prefix)
    local url = ("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1"):format(self.user, self.repo, commit)
    local body, err = self:get(url, { ["User-Agent"] = self.headers["User-Agent"], ["Accept"] = "application/vnd.github.v3+json" })
    
    if not body then return nil, err end
    local data = textutils.unserializeJSON(body)
    
    for _, item in ipairs(data.tree) do
        if item.type == "tree" and item.path == prefix then
            return item.sha
        end
    end
    return nil, "path not found: " .. prefix
end

-- Returns { [path] = sha } for every file under rootPath at the given commit
function GitHubSource:getFileTree(commit)
    local url = ("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1"):format(self.user, self.repo, commit)
    local body, err = self:get(url, { ["User-Agent"] = self.headers["User-Agent"], ["Accept"] = "application/vnd.github.v3+json" })

    if not body then return nil, err end
    local data = textutils.unserializeJSON(body)
    if not data or not data.tree then return nil, "unexpected response" end

    local prefix = self.rootPath .. "/"
    local files = {}
    for _, item in ipairs(data.tree) do
        if item.type == "blob" and item.path:sub(1, #prefix) == prefix then
            files[item.path] = item.sha
        end
    end
    return files
end

function GitHubSource:getFile(commit, path)
    local url = ("https://raw.githubusercontent.com/%s/%s/%s/%s"):format(self.user, self.repo, commit, path)
    return self:get(url, self.headers)
end

-- ----------------------------------------------------------------
local Installer = {}
Installer.__index = Installer

Installer.user = "Hedgehogedgehog"
Installer.repo = "CC-OS"
Installer.branch = "main"
Installer.rootPath = "root"


Installer.BOOT_TIMEOUT = 10


function Installer:new(
    source,
    saves,
    opts
)

    local self = setmetatable({}, Installer)
    self.source = source
    self.saves = saves
    self.opts = opts or {}

    return self

end

-- Files the installer has installed before, saved as { [path] = sha }
function Installer:getInstalledFiles()
    return self.saves:getValue("installedFiles") or {}
end

-- Files the installer should never overwrite or delete (log files, not logger.lua)
function Installer:isPreserved(path)
    return path:find("%.log$") ~= nil
end

function Installer:ask(question, default, timeout)
    write(question .. (default and " [Y/n] " or " [y/N] "))

    local answer
    if timeout then
        parallel.waitForAny(
            function() answer = read() end,
            function() sleep(timeout) end
        )
        if answer == nil then print() end
    else
        answer = read()
    end

    answer = (answer or ""):lower()
    if answer == "" then
        return default
    end
    return answer == "y" or answer == "yes"
end

function Installer:plan(remote)
    local plan = { add = {}, change = {}, remove = {} }
    local known = self:getInstalledFiles()
    for path, sha in pairs(remote) do
        local exists = fs.exists(path)
        if exists and self:isPreserved(path) then
        elseif not exists or known[path] == nil then
            table.insert(plan.add, path)
        elseif self.opts.force or known[path] ~= sha then
            table.insert(plan.change, path)
        end
    end
    for path in pairs(known) do
        if remote[path] == nil and not self:isPreserved(path) then table.insert(plan.remove, path) end
    end
    table.sort(plan.add); table.sort(plan.change); table.sort(plan.remove)
    return plan
end

-- Downloads everything first so a failed download leaves the old install untouched
function Installer:downloadFiles(commit, paths)
    local downloaded = {}
    for i, path in ipairs(paths) do
        MainLogger:log(("[%d/%d] %s"):format(i, #paths, path))
        local contents, err = self.source:getFile(commit, path)
        if not contents then
            MainLogger:log("Failed to download " .. path .. ": " .. tostring(err))
            return nil
        end
        downloaded[path] = contents
    end
    return downloaded
end

function Installer:writeFiles(downloaded)
    for path, contents in pairs(downloaded) do
        local dir = fs.getDir(path)
        if dir ~= "" and not fs.exists(dir) then
            fs.makeDir(dir)
        end

        local file = fs.open(path, "w")
        file.write(contents)
        file.close()
    end
end

function Installer:removeFiles(paths)
    for _, path in ipairs(paths) do
        MainLogger:log("Removing " .. path)
        fs.delete(path)
    end
end

function Installer:install()
    if settings.get("ccos.dev") then
        MainLogger:log("OS is in dev mode, skipping installation")
        return true
    end
    if not http then
        MainLogger:log("HTTP API is not enabled. Please enable it in the ComputerCraft settings. Installer cannot continue.")
        return false
    end

    local commit = self:checkForUpdates()
    if not commit then
        return false
    end
    if commit == true then
        return true
    end

    local remote, err = self.source:getFileTree(commit)
    if not remote then
        MainLogger:log("Failed to get file list from GitHub: " .. tostring(err))
        return false
    end

    local plan = self:plan(remote)
    local fetch = {}
    for _, p in ipairs(plan.add) do fetch[#fetch + 1] = p end
    for _, p in ipairs(plan.change) do fetch[#fetch + 1] = p end

    if #fetch == 0 and #plan.remove == 0 then
        self.saves:setValue("latestCommit", commit)
        MainLogger:log("Already up to date (" .. commit:sub(1, 7) .. ")")
        return true
    end

    local firstInstall = next(self:getInstalledFiles()) == nil
    MainLogger:log(("%s %s: %d new, %d changed, %d removed"):format(firstInstall and "Install" or "Update",
        commit:sub(1, 7), #plan.add, #plan.change, #plan.remove))
    if not self.opts.yes then
        local question = firstInstall and "Install CC-OS?" or "Install update?"
        if not self:ask(question, true, self.opts.boot and Installer.BOOT_TIMEOUT or nil) then
            MainLogger:log("Update declined.")
            return true
        end
    end

    local downloaded = self:downloadFiles(commit, fetch)
    if not downloaded then
        return false
    end

    self:writeFiles(downloaded)
    self:removeFiles(plan.remove)

    -- Only save once everything is on disk, so a failed update gets retried next time
    self.saves:setValue("installedFiles", remote)
    self.saves:setValue("latestCommit", commit)

    MainLogger:log("Installed " .. commit:sub(1, 7))
    return true
end

function Installer:checkForUpdates()
    MainLogger:log("Checking for updates...")
    local latestCommit, err = self.source:getLatestCommit()

    if not latestCommit then
        MainLogger:log("Failed to get latest commit from GitHub: " .. tostring(err))
        return false
    end

    local savedCommit = self.saves:getValue("latestCommit")

    if savedCommit == nil then
        MainLogger:log("No previous commit found. This is a fresh install.")
        return latestCommit
    end

    if latestCommit == savedCommit and not self.opts.force then
        MainLogger:log("No updates available.")
        return true
    end

    return latestCommit

end
-- ----------------------------------------------------------------

local function configComputerSettings()
    MainLogger:log("Configuring Computer Settings")

    shell.run("set motd.enable false")

    shell.run("clear")
end


local function installOS()
    MainLogger:log("Installing OS")
    --fetchFolder(rootPath)
    --shell.run("clear")
    local installer = Installer:new(
        GitHubSource:new(user, repo, branch, rootPath),
        InstallerSaves:new(installerSavePath),
        { yes = false, force = false, boot = false }
    )

    if not installer:install() then
        return "ERROR"
    end
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

local function setupStartup()
    local startupScriptPath = "startup.lua"
    createFile('shell.run("/root/sys/kernal/kernal.lua")', startupScriptPath)
end



local function readyInstall()
    setupStartup()
    MainLogger:clearLog()
    configComputerSettings()
    local errors = installOS()
    if errors == "ERROR" then
        MainLogger:log("There was an error installing the OS if you have a older version of CC-OS installed it will continue to work else try to install agien later")
    else 
        MainLogger:log("OS installed successfully")
    end
end

local installerLogPath = "installerLog.log"
MainLogger = Logger:new(installerLogPath)

readyInstall()
MainLogger:log("install process complete")
MainLogger:log("Booting into OS if the OS does not exist the computer will boot into Crafty-OS")
--shell.run("/root/sys/kernal/kernal.lua")