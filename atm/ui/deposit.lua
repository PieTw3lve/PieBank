-- ui/deposit.lua

local piebank = require("disk.lib.piebank")

local monitorLib = require("lib.monitor")
local bigfont = require("lib.bigfont")
local button = require("lib.button")

local buttons = nil

-- Find dispenser and storage inventories
local function findInventories()
    local dispenser = nil
    local storages = {}

    for _, name in ipairs(peripheral.getNames()) do
        local p = peripheral.wrap(name)
        local pType = peripheral.getType(name)

        if pType == "minecraft:dispenser" then
            dispenser = p
        elseif p and p.list and pType ~= "minecraft:dispenser" then
            table.insert(storages, p)
        end
    end

    return dispenser, storages
end

-- Count total currency in dispenser
local function countCurrency(dispenser, currency)
    local total = 0
    for slot, item in pairs(dispenser.list()) do
        if item.name == currency then
            total = total + item.count
        end
    end
    return total
end

-- Move currency from dispenser to vault
local function depositCurrency(ctx)
    local dispenser, storages = findInventories()

    if not dispenser then
        return { success = false, error = "ATM input is not connected" }
    end

    if #storages == 0 then
        return { success = false, error = "Bank vault is unavailable" }
    end

    local amount = countCurrency(dispenser, "minecraft:" .. ctx.currency)
    if amount <= 0 then
        return { success = false, error = "No " .. ctx.currency .. " to deposit" }
    end

    local remaining = amount
    for _, inv in ipairs(storages) do
        for slot, item in pairs(dispenser.list()) do
            if item.name == "minecraft:" .. ctx.currency and remaining > 0 then
                local moved = dispenser.pushItems(
                    peripheral.getName(inv),
                    slot,
                    remaining
                )
                remaining = remaining - moved
            end
        end
        if remaining <= 0 then break end
    end

    if remaining > 0 then
        return { success = false, error = "Not enough space in vault" }
    end

    return { success = true, amount = amount }
end

return {
    draw = function(ctx)
        local m = ctx.monitor
        buttons = nil
        monitorLib.reset(m)

        local dispenser, _ = findInventories()
        local depositAmount = 0
        if dispenser then
            depositAmount = countCurrency(dispenser, "minecraft:" .. ctx.currency)
        end

        buttons = {
            -- Confirm / Refresh / Back
            button.createNewButton(5, 28, "Confirm", colors.green, colors.gray, false,
                function()
                    local localResult = depositCurrency(ctx)
                    if not localResult.success then
                        ctx.errorMessage = localResult.error
                        return
                    end

                    local deposit = piebank.deposit(ctx.gatewayID, ctx.cardID, localResult.amount)
                    if not deposit.success then
                        ctx.errorMessage = deposit.error or "Your deposit could not be processed"
                        return
                    end

                    ctx.balance = deposit.balance
                    ctx.successMessage = "Successfully deposited ".. ctx.currencyIcon .. localResult.amount
                    ctx:goto("balance")
                end
            ),
            button.createNewButton(15, 28, "Refresh", colors.orange, colors.gray, false,
                function() ctx:goto("deposit") end ),

            button.createNewButton(25, 28, " Back ", colors.gray, colors.black, false,
                function() ctx:goto("balance") end )
        }

        button.drawButtons(m, buttons)

        if ctx.errorMessage then
            m.setBackgroundColor(colors.gray)
            m.setTextColor(colors.red)
            m.setCursorPos(2, 2)
            m.write(ctx.errorMessage)
            ctx.errorMessage = nil
        end

        m.setBackgroundColor(colors.black)
        m.setTextColor(colors.white)
        bigfont.writeOn(m, 1, "Deposit", nil, 5)
        bigfont.writeOn(m, 1, ctx.currencyIcon .. depositAmount, nil, 15)
    end,

    update = function(ctx)
        if buttons then
            button.checkButtonsPressed(ctx.monitor, buttons, 0)
        end
    end
}