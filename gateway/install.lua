-- install.lua (Gateway)

local BASE = "https://raw.githubusercontent.com/PieTw3lve/PieBank/main/gateway"

local FILES = {
    { path = "startup.lua", url = BASE .. "/startup.lua" },
}

term.clear()
term.setCursorPos(1,1)
print("PieBank Gateway Installer")
print("--------------------------")

for i, file in ipairs(FILES) do
    write(("Downloading %s ... "):format(file.path))

    if fs.exists(file.path) then
        fs.delete(file.path)
    end

    local ok = shell.run("wget", file.url, file.path)

    if ok and fs.exists(file.path) then
        print("ok")
    else
        print("failed")
        print("URL:", file.url)
        print("Stopping install.")
        return
    end
end

print("\nInstall complete.")
sleep(1)
os.reboot()