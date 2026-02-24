-- install.lua (Service)

local BASE = "https://raw.githubusercontent.com/PieTw3lve/PieBank/main/services"

local FILES = {
    { path = "startup.lua",      url = BASE .. "/startup.lua" },

    { path = "lib/basalt.lua",   url = BASE .. "/lib/basalt.lua" },
    { path = "lib/piebank.lua",  url = BASE .. "/lib/piebank.lua" },

    { path = "ui/main.lua",      url = BASE .. "/ui/main.lua" },
    { path = "ui/create.lua",    url = BASE .. "/ui/create.lua" },
    { path = "ui/delete.lua",    url = BASE .. "/ui/delete.lua" },
    { path = "ui/recover.lua",   url = BASE .. "/ui/recover.lua" },
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
print("PieBank Services Installer")
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