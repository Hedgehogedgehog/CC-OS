local user = "Hedghogedgehog"
local repo = "CC-OS"
local branch = "main"
local baseURL = "https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/refs/heads/" .. branch .. "/"

local sysFolders = {
    "root/installer",
    "root/sys"
}

local function fetchFolder(folder, baseURL)
    local link = baseURL .. folder

    print("Fetching folder: " , folder, " From: " , link)

    --local request = http.get("https://example.tweaked.cc")
    local request = http.get(link)
    print(request.readAll())

end

local function installOS()
    print("Installing OS")
    for _,folder in pairs(sysFolders) do
        fetchFolder(folder, baseURL)
    end
end




installOS()