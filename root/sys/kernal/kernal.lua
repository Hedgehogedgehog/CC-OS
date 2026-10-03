shell.run("clear")
print("OS initializing...")

shell.run("/root/sys/peripherals/scripts/main.lua")

local id = multishell.launch({}, ("/root/sys/peripherals/scripts/main.lua"))
multishell.setTitle(id, "peripherals!")

while true do
    
end