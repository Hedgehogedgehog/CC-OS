local chars = ""
for i = 0, 255 do chars = chars .. string.char(i) end
print(chars)

fs.open("root/sys/libs/imgDraw/dev/getCharsOut/chars.txt", "w").write(chars)