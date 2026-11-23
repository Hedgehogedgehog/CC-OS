if not settings.get("ccos.dev") then
    shell.run("/root/installer/installer.lua", "--boot")
end
shell.run("clear")

_G.Logger = dofile("/root/sys/logs/logger.lua")

KernalLogger = Logger:new("kernal/kernal.log")

KernalLogger:log("OS initializing...")

local id = multishell.launch({}, ("/root/sys/peripherals/scripts/main.lua"))
multishell.setTitle(id, "peripherals!")
