-- ui/withdrawConfirm.lua

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
        local pType = peripheral.getType(name)
        local p = peripheral.wrap(name)

        if pType == "minecraft:dispenser" then
            dispenser = p
        elseif p and p.list and pType ~= "minecraft:dispenser" then
            table.insert(storages, p)
        end
    end

    return dispenser, storages
end

-- Count total currency in storages
local function countCurrency(storages, currency)
    local total = 0

    for _, inv in ipairs(storages) do
        for _, item in pairs(inv.list()) do
            if item.name == currency then
                total = total + item.count
            end
        end
    end

    return total
end

-- Calculate free space for currency in dispenser
local function getDispenserFreeSpace(dispenser, currency)
    local capacity = 0

    for slot = 1, 9 do
        local item = dispenser.getItemDetail(slot)

        if not item then
            capacity = capacity + 64
        elseif item.name == currency then
            capacity = capacity + (64 - item.count)
        end
    end

    return capacity
end

-- Withdraw physical currency
local function withdrawCurrency(ctx, amount)
    local dispenser, storages = findInventories()

    if not dispenser then
        return { success = false, error = "Dispenser is not connected" }
    end

    if #storages == 0 then
        return { success = false, error = "Bank vault is unavailable" }
    end

    local available = countCurrency(storages, "minecraft:" .. ctx.currency)
    if available < amount then
        return { success = false, error = "The bank is out of diamonds" }
    end

    local freeSpace = getDispenserFreeSpace(dispenser, "minecraft:" .. ctx.currency)
    if freeSpace < amount then
        return { success = false, error = "Not enough space in dispenser" }
    end

    local remaining = amount

    for _, inv in ipairs(storages) do
        for slot, item in pairs(inv.list()) do
            if item.name == "minecraft:" .. ctx.currency and remaining > 0 then
                local moved = inv.pushItems(
                    peripheral.getName(dispenser),
                    slot,
                    remaining
                )
                remaining = remaining - moved
            end
        end
        if remaining <= 0 then break end
    end

    return { success = true }
end

return {
    draw = function(ctx)
        local m = ctx.monitor
        buttons = nil
        monitorLib.reset(m)
        
        buttons = {
            -- Confirm / Back
            button.createNewButton(6, 28, "Confirm", colors.green, colors.gray, false,
                function()
                    local localResult = withdrawCurrency(ctx, ctx.withdrawAmount)

                    if not localResult.success then
                        ctx.errorMessage = localResult.error or "A critical error occurred during withdrawal"
                        return ctx:goto("withdraw")
                    end

                    local withdraw = piebank.withdraw(ctx.gatewayID, ctx.cardID, ctx.withdrawAmount)
                    if not withdraw.success then
                        ctx.errorMessage = withdraw.error or "Your withdrawal could not be processed"
                        return ctx:goto("withdraw")
                    end

                    ctx.balance = withdraw.balance
                    ctx.successMessage = "Successfully withdraw " .. ctx.currencyIcon .. ctx.withdrawAmount
                    ctx.withdrawAmount = 0
                    ctx:goto("balance")
                end
            ),
            button.createNewButton(22, 28, " Back ", colors.gray, colors.black, false,
                function() ctx:goto("withdraw") end )
        }

        button.drawButtons(m, buttons)

        m.setBackgroundColor(colors.black)
        m.setTextColor(colors.white)
        bigfont.writeOn(m, 1, "Withdraw", nil, 5)
        bigfont.writeOn(m, 1, ctx.currencyIcon .. ctx.withdrawAmount, nil, 15)
    end,

    update = function(ctx)
        if buttons then
            button.checkButtonsPressed(ctx.monitor, buttons, 0)
        end
    end
}