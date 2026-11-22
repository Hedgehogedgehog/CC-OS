if not settings.get("ccos.dev") then
    shell.run("/root/installer/installer.lua", "--boot")
end
shell.run("clear")

shell.run("root/sys/logs/logger.lua")


log("OS initializing...", "kernal")

--shell.run("/root/sys/peripherals/scripts/main.lua")

local id = multishell.launch({}, ("/root/sys/peripherals/scripts/main.lua"))
multishell.setTitle(id, "peripherals!")

--while true do
-- 
--end