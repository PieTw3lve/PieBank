-- main.lua

local piebank = require("disk.lib.piebank")

local drive = peripheral.find("drive")
local monitor = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

local connect = piebank.connect(--[[ Specify the side your modem is on, e.g. "left" ]])
if not connect.success then error(connect.error) end

print("Connected to PieBank gateway ID:", connect.gatewayID)

local ctx = {
    monitor = monitor,
    gatewayID = connect.gatewayID,
    cardID = nil,
    owner = "",
    balance = 0,
    withdrawAmount = 0,
    transferOwner = nil,
    transferID = "_",
    transferAmount = 0,
    screen = "balance",
    currency = "diamond",
    currencyIcon = string.char(4),
    successMessage = nil,
    errorMessage = nil,
    running = true,
    goto = function(self, name) self.screen = name end
}

-- Fetch initial account data
local card = piebank.readCard(drive)
local account = piebank.auth(ctx.gatewayID, card.card_id)

if account.success then
    ctx.cardID = card.card_id
    ctx.owner = account.owner
    ctx.balance = account.balance
else
    term.setTextColor(colors.red)
    print(account.error)
    return term.setTextColor(colors.white)
end

local screens = {
    balance = require("ui.balance"),
    deposit = require("ui.deposit"),
    withdraw = require("ui.withdraw"),
    withdrawConfirm = require("ui.withdrawConfirm"),
    transfer = require("ui.transfer"),
    transferAmount = require("ui.transferAmount"),
    transferConfirm = require("ui.transferConfirm")
}

while ctx.running do
    speaker.playSound("block.wooden_button.click_on")
    screens[ctx.screen].draw(ctx)
    screens[ctx.screen].update(ctx)
    sleep(0)
end