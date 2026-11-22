CCOS_EXTRA = {  }
CCOS_RUN_INSTALLER = true
-- CC-OS local VM startup (CraftOS-PC only).
-- run-local.ps1 copies this file to each VM computer's startup.lua and puts a
-- line in front of it:
--   CCOS_EXTRA = { 2, 3 }   on the first computer: ids of extra PCs to open
--   CCOS_SECONDARY = true   on the extra PCs
-- It marks the VM as a dev machine (so the GitHub updater never runs), attaches
-- emulated peripherals so the device scanner / dashboard has something to find,
-- then boots the OS like a real computer would.

-- run-local.ps1 -Installer turns dev mode off so the installer runs like on a real PC
settings.set("ccos.dev", rawget(_G, "CCOS_RUN_INSTALLER") ~= true)
settings.set("motd.enable", false)
settings.save()

local periphemu = _G.periphemu
if periphemu and not rawget(_G, "CCOS_NO_PERIPHERALS") then
    local function add(name, kind, ...)
        if peripheral.isPresent(name) then return peripheral.wrap(name) end
        local ok = pcall(periphemu.create, name, kind, ...)
        if ok and peripheral.isPresent(name) then return peripheral.wrap(name) end
    end

    -- Every PC gets a modem on network 0 so the CC-OS PCs can see each other.
    add("back", "modem")

    if rawget(_G, "CCOS_SECONDARY") == true then
        -- Backup PCs: a couple of devices of their own to share over the network.
        add("left", "speaker")
        local chest = add("chest_" .. os.getComputerID(), "chest")
        if chest and chest.setItem then pcall(chest.setItem, 1, { name = "minecraft:redstone", count = 32 }) end
    else
        add("top", "monitor")    -- opens a second window: the dashboard shows up here
        add("left", "speaker")
        add("right", "drive")
        add("bottom", "printer")
        local chest = add("chest_0", "chest")
        if chest and chest.setItem then
            pcall(chest.setItem, 1, { name = "minecraft:cobblestone", count = 64 })
            pcall(chest.setItem, 2, { name = "minecraft:iron_ingot", count = 23 })
            pcall(chest.setItem, 5, { name = "minecraft:diamond", count = 4 })
        end
        add("energy_0", "energy")
        add("tank_0", "tank")
        -- Four floppy drives with blank disks to try data / backup / personal disks.
        for i = 1, 4 do
            local drive = add("drive_" .. i, "drive")
            if drive and not drive.isDiskPresent() then pcall(drive.insertDisk, 100 + i) end
        end
        -- Extra CC-OS PCs (each opens its own window and boots CC-OS too).
        -- CraftOS-PC wants the computer id as the "side"; the new PC boots by itself.
        for _, id in ipairs(rawget(_G, "CCOS_EXTRA") or {}) do
            local ok, err = pcall(periphemu.create, id, "computer")
            if not ok then print("Could not open extra PC #" .. id .. ": " .. tostring(err)) end
        end
    end
end

shell.run("/root/sys/kernal/kernal.lua")
