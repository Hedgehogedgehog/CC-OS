local mainLog = "root/sys/logs/main.log"
local progLogPath = "root/sys/logs/programLogs/"

-- Define a global function in the _G table
_G.log = function(message, programName, printToConsole )
    
    if printToConsole == nil then 
        printToConsole = true 
    end

    if programName then
        local fileLogPath = progLogPath .. programName .. ".log"

        local file = fs.open(mainLog, "a")
        if file then
            file.writeLine("[" .. textutils.formatTime(os.time(), true) .. "] " .. message)
            file.close()
        end
    end
    
    local file = fs.open(fileLogPath, "a")
    if file then
        file.writeLine("[" .. textutils.formatTime(os.time(), true) .. "] " .. message)
        file.close()
    end
    
    if printToConsole then
        print("[" .. textutils.formatTime(os.time(), true) .. "] " .. message)
    end

end