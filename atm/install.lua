-- install.lua (ATM)

local BASE = "https://raw.githubusercontent.com/PieTw3lve/PieBank/main/atm"

local FILES = {
    { path = "startup.lua",      url = BASE .. "/startup.lua" },
    { path = "main.lua",      url = BASE .. "/main.lua" },

    { path = "lib/bigfont.lua",  url = BASE .. "/lib/bigfont.lua" },
    { path = "lib/button.lua",   url = BASE .. "/lib/button.lua" },
    { path = "lib/monitor.lua",   url = BASE .. "/lib/monitor.lua" },

    { path = "ui/balance.lua",      url = BASE .. "/ui/balance.lua" },
    { path = "ui/deposit.lua",      url = BASE .. "/ui/deposit.lua" },
    { path = "ui/withdraw.lua",     url = BASE .. "/ui/withdraw.lua" },
    { path = "ui/withdrawConfirm.lua",     url = BASE .. "/ui/withdrawConfirm.lua" },
    { path = "ui/transfer.lua",     url = BASE .. "/ui/transfer.lua" },
    { path = "ui/transferAmount.lua",     url = BASE .. "/ui/transferAmount.lua" },
    { path = "ui/transferConfirm.lua",     url = BASE .. "/ui/transferConfirm.lua" },
}

local function ensureDir(path)
    if path ~= "" and not fs.exists(path) then
        fs.makeDir(path)
    end
end

local function prepare(path)
    local dir = fs.getDir(path)
    ensureDir(dir)
    if fs.exists(path) then
        fs.delete(path)
    end
end

term.clear()
term.setCursorPos(1,1)
print("PieBank ATM Installer")
print("----------------------")

for i, file in ipairs(FILES) do
    write(("Downloading %s ... "):format(file.path))

    prepare(file.path)
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
sleep(5)
os.reboot()