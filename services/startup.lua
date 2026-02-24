-- startup.lua

local piebank = require("lib.piebank")
local basalt = require("lib.basalt")
local app = basalt.getMainFrame()

local drive = peripheral.find("drive")
local dispenser = peripheral.find("minecraft:dispenser")
local trappedChests = { peripheral.find("minecraft:trapped_chest") }
local printer = peripheral.find("printer")
local speaker = peripheral.find("speaker")
local chests = peripheral.find("minecraft:chest")
local barrel = peripheral.find("minecraft:barrel")

local conn = piebank.connect(--[[ Specify the side your modem is on, e.g. "left" ]])
if not conn.success then
    error(conn.error)
end

local gatewayID = conn.gatewayID

local toast = app:addToast()
    :setSize(100, 1)
    :setBackground(colors.black)

local ctx = {
    gatewayID = gatewayID,
    app = app,
    drive = drive,
    dispenser = dispenser,
    cards = trappedChests,
    printer = printer,
    speaker = speaker,
    vault = chests,
    output = barrel
}

local screens = {
    main = require("ui.main")(ctx),
    create = require("ui.create")(ctx),
    delete = require("ui.delete")(ctx),
    recover = require("ui.recover")(ctx),
}

local function gotoScreen(name)
    for k, frame in pairs(screens) do
        frame:updateLayout()
        frame:setVisible(k == name)
    end
end

local function showToast(text, color)
    toast:setForeground(color)
    toast:show(text)
end

for _, frame in pairs(screens) do
    frame.gotoScreen = gotoScreen
    frame.showToast = showToast
end

gotoScreen("main")

basalt:run()