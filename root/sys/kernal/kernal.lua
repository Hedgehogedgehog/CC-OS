package.path = "/root/sys/libs/?.lua;/root/sys/libs/?/init.lua;" .. package.path

Logger = require("logs/logger")
KernalLogger = Logger:new("kernal/kernal.log")

KernalLogger:log("OS initializing...")
KernalLogger:log("Loaded logger...")

if not settings.get("ccos.dev") then
    shell.run("/root/installer/installer.lua", "--boot")
    KernalLogger:log("running installer...")
end

KernalLogger:log("Updater finished...")

_G.ccos = {
    require = require,
}

KernalLogger:log("Loaded package manager...")

local id = multishell.launch({}, ("/root/sys/libs/peripherals/scripts/main.lua"))
multishell.setTitle(id, "peripherals")

KernalLogger:log("Loaded peripheral scanner...")