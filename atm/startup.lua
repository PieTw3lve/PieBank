-- startup.lua

local monitor = peripheral.find("monitor")
local drive = peripheral.find("drive")

if not monitor then
    error("No monitor found")
end

if not drive then
    error("No disk drive found")
end

-- Reset the ATM screen
local function resetScreen()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    monitor.setTextScale(2.5)
    monitor.setCursorPos(1, 3)
    monitor.write("Insert")
    monitor.setCursorPos(1, 4)
    monitor.write("Card...")
end

-- for i = 0, 300 do
--     print(i, string.char(i))
--     os.sleep(0.2)
-- end

-- Handle disk insertion
local function onDiskInserted()
    if fs.exists("main.lua") then
        shell.run("main.lua")
        drive.ejectDisk()
    else
        error("main.lua not found")
        sleep(2)
    end
end

while true do
    resetScreen()
    os.pullEvent("disk")
    onDiskInserted()
end
