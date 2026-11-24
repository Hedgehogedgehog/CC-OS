package.path = "/root/sys/libs/?.lua;/root/sys/libs/?/init.lua;" .. package.path

_G.fs = require("fileManager")

Logger = require("logs")
KernalLogger = Logger:new("kernal/kernal.log")

KernalLogger:log("OS initializing...")
KernalLogger:log("Loaded logger...")

if not settings.get("CCOS.dev") then
    shell.run("/root/installer/installer.lua", "--boot")
    KernalLogger:log("running installer...")
end

KernalLogger:log("Updater finished...")

_G.CCOS = {
    require = require,
}

KernalLogger:log("Loaded package manager...")

local id = multishell.launch({}, ("root/sys/progs/progList/init.lua"))
multishell.setTitle(id, "apps")

KernalLogger:log("Loaded peripheral scanner...")