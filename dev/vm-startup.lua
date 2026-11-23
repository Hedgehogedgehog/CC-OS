-- CC-OS local VM startup (CraftOS-PC only).
-- run-local.ps1 copies this file to each VM computer's startup.lua and puts a
-- few lines in front of it:
--   _G.CCOS_EXTRA = { 2, 3 }        on the first computer: ids of extra PCs to open
--   _G.CCOS_SECONDARY = true        on the extra PCs
--   _G.CCOS_PERIPHERALS = [[...]]   the peripheral list file(s) (see .vm/peripherals/default.txt)
-- followed by dev/mock-peripherals.lua (fake mod devices such as Mekanism).
-- It marks the VM as a dev machine (so the GitHub updater never runs), attaches
-- the emulated peripherals from that list so the device scanner / dashboard has
-- something to find, then boots the OS like a real computer would.

-- run-local.ps1 -Installer turns dev mode off so the installer runs like on a real PC
settings.set("ccos.dev", rawget(_G, "CCOS_RUN_INSTALLER") ~= true)
settings.set("motd.enable", false)
settings.save()

-- Parse the peripheral list, keeping only the lines meant for this computer.
local function parsePeripherals(text, id, secondary)
    local list, active = {}, true -- lines before any [section] apply to every PC
    for raw in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        local line = raw:gsub("#.*$", ""):match("^%s*(.-)%s*$")
        local section = line:match("^%[(.-)%]$")
        if section then
            active = false
            for s in section:lower():gmatch("[^,%s]+") do
                if s == "all" or (s == "main" and not secondary) or (s == "secondary" and secondary)
                    or tonumber(s) == id then
                    active = true
                end
            end
        elseif line ~= "" and active then
            local entry = { args = {}, items = {}, opts = {} }
            for tok in line:gmatch("%S+") do
                if not entry.name then
                    entry.name = tok:gsub("{id}", tostring(id))
                elseif not entry.kind then
                    entry.kind = tok
                else
                    local key, value = tok:match("^([^=]+)=(.+)$")
                    if key == "disk" then
                        entry.disk = tonumber(value)
                    elseif key and tonumber(key) then
                        local item, count = value:match("^(.-)%*(%d+)$")
                        entry.items[#entry.items + 1] = {
                            slot = tonumber(key), name = item or value, count = tonumber(count) or 1,
                        }
                    elseif key then
                        entry.opts[key:lower()] = value -- options for mock peripherals
                    else
                        entry.args[#entry.args + 1] = tonumber(tok) or tok
                    end
                end
            end
            if entry.kind then
                list[#list + 1] = entry
            else
                print("peripherals: ignoring line without a type: " .. raw)
            end
        end
    end
    return list
end

local periphemu = _G.periphemu
if periphemu and not rawget(_G, "CCOS_NO_PERIPHERALS") then
    local secondary = rawget(_G, "CCOS_SECONDARY") == true
    local list = parsePeripherals(rawget(_G, "CCOS_PERIPHERALS") or "", os.getComputerID(), secondary)

    -- Mod devices (e.g. Mekanism) are faked in Lua, see dev/mock-peripherals.lua
    local mocks = rawget(_G, "CCOS_MOCKS") or { types = {} }
    local real = {}
    for _, p in ipairs(list) do
        if mocks.types[p.kind] == nil then real[#real + 1] = p end
    end
    if mocks.install then mocks.install(list) end

    for _, p in ipairs(real) do
        if not peripheral.isPresent(p.name) then
            local ok, err = pcall(periphemu.create, p.name, p.kind, table.unpack(p.args))
            if not ok then print("Could not attach " .. p.kind .. " '" .. p.name .. "': " .. tostring(err)) end
        end
        local dev = peripheral.isPresent(p.name) and peripheral.wrap(p.name)
        if dev then
            if p.disk and dev.isDiskPresent and not dev.isDiskPresent() then pcall(dev.insertDisk, p.disk) end
            if dev.setItem then
                for _, item in ipairs(p.items) do
                    pcall(dev.setItem, item.slot, { name = item.name, count = item.count })
                end
            end
        end
    end

    if not secondary then
        -- Extra CC-OS PCs (each opens its own window and boots CC-OS too).
        -- CraftOS-PC wants the computer id as the "side"; the new PC boots by itself.
        for _, id in ipairs(rawget(_G, "CCOS_EXTRA") or {}) do
            local ok, err = pcall(periphemu.create, id, "computer")
            if not ok then print("Could not open extra PC #" .. id .. ": " .. tostring(err)) end
        end
    end
end

shell.run("/root/sys/kernal/kernal.lua")
