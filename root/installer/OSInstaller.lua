local user = "Hedgehogedgehog"
local repo = "CC-OS"
local branch = "main"
local baseURL = "https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/refs/heads/" .. branch .. "/"

local sysFolders = {
    --"root/installer/OSInstaller.lua",
    "root/sys/startup.lua",
}

local function fetchFolder(folder, baseURL)
    local link = baseURL .. folder

    print("Fetching folder: " , folder, " From: " , link)

    --local request = http.get("https://raw.githubusercontent.com/Hedgehogedgehog/CC-OS/refs/heads/main/root/sys/startup.lua")
    --local request = http.get("https://example.tweaked.cc")
    local request = http.get(link)
    print(request.readAll())

end

local function configComputerSettings()
    print("Configuring Computer Settings")

    shell.run("Set motd.enable false")

    shell.run("clear")
end


local function installOS()
    print("Installing OS")
    for _,folder in pairs(sysFolders) do
        fetchFolder(folder, baseURL)
    end

    --shell.run("clear")
end

local function readyInstall()
    configComputerSettings()
    installOS()
end

readyInstall()
print("install complete")