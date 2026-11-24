---Writes timestamped log lines to the main OS log and optional per-program logs.
---@class Logger
---@field mainLog string Path of the main log file every message is written to.
---@field progLogPath string Folder that per-program log files are written into.
local Logger = {}
Logger.__index = Logger

Logger.mainLog = "root/sys/libs/logs/main.log"
Logger.progLogPath = "root/sys/libs/logs/programLogs/"

---Returns the current time as a string, using the real date if available.
---@return string
local function timestamp()
    if os.date then
        return tostring(os.date("%Y-%m-%d %H:%M:%S"))
    end
    return textutils.formatTime(os.time(), true)
end

---Appends one line to a file, creating the file if needed.
---@param path string File to append to.
---@param line string Text to write.
---@return boolean ok True if the line was written.
local function appendLine(path, line)
    local file, err = fs.open(path, "a")
    if not file then
        printError("Logger: could not open " .. path .. ": " .. tostring(err))
        return false
    end
    file.writeLine(line)
    file.close()
    return true
end

---Logs a message to the main log, and to the program's own log if a name is given.
---@param message any The message to log (converted with tostring).
---@param echo? boolean Print the line to the screen too. Defaults to true.
function Logger:log(message, echo)
    if echo == nil then
        echo = true
    end

    local line = "[" .. timestamp() .. "] " .. tostring(message)

    appendLine(self.mainLog, line)

    appendLine(self.progLogPath, line)

    if echo then
        print(line)
    end
end

---Creates a new logger instance.
---@param progLogPath? string Subfolder appended to the default program log folder (e.g. "myapp/").
---@return Logger
function Logger:new(progLogPath)
    if not progLogPath then
        progLogPath = "noLogAssigned.log"
    
    end
    local self = setmetatable({}, Logger)
    if progLogPath then
        self.progLogPath = Logger.progLogPath .. progLogPath
    end
    return self
end

return Logger
