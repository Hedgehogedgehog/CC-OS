
print("Installing CC-OS please wait")
local request = http.get("https://raw.githubusercontent.com/Hedgehogedgehog/CC-OS/refs/heads/main/root/installer/OSInstaller.lua")
if request == nil then
    print("There was an error installing the OS if you have a older version of CC-OS installed it will continue to work else try to install agien later")
else
    local file = fs.open("/root/installer/OSInstaller.lua", "w+")
    file.write(request.readAll())
    file.close()
    print("Installation complete, please remove the disk and reboot the computer to start using CC-OS")
end


