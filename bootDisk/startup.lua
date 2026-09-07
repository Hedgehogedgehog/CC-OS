
print("Installing CC-OS please wait")
local request = http.get(link)
if request == nil then
    print("There was an error installing the OS if you have a older version of CC-OS installed it will continue to work else try to install agien later")
else
    local file = fs.open("/root/installer/OSInstaller.lua", "w+")
    file.write(request.readAll())
    file.close()
    shell.run("/root/installer/OSInstaller.lua")
end


