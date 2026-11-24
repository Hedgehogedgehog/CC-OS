local nativeFS = fs

local FileManager = {}
setmetatable(FileManager, { __index = nativeFS })

function FileManager.createFile(contents, path)

    local dir = fs.getDir(path)
    if dir and dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local file = fs.open(path, "w")
    if file then
        file.write(contents)
        file.close()
        return true
    end
    return false
end

---Appends one line to a file, creating the file if needed.
---@param path string File to append to.
---@param data string Text to write.
---@return boolean ok True if the line was written.
function FileManager.append(path, data)
    local file, err = fs.open(path, "a")
    if not file then
        printError("FileManager: could not open " .. path .. ": " .. tostring(err))
        return false
    end
    file.writeLine(data)
    file.close()
    return true
end


return FileManager