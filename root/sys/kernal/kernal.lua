if not settings.get("ccos.dev") then
    shell.run("/root/installer/installer.lua", "--boot")
end
shell.run("clear")

package.path = "/root/sys/libs/?.lua;/root/sys/libs/?/init.lua;" .. package.path

_G.ccos = {
    require = require,
}

Logger = require("logs/logger")

KernalLogger = Logger:new("kernal/kernal.log")
KernalLogger:log("OS initializing...")

local id = multishell.launch({}, ("/root/sys/libs/peripherals/scripts/main.lua"))
multishell.setTitle(id, "peripherals!")