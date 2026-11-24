local FileManager = {}
FileManager.__index = FileManager

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

return FileManager