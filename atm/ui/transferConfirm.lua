-- ui/transferConfirm.lua

local piebank = require("disk.lib.piebank")

local monitorLib = require("lib.monitor")
local bigfont = require("lib.bigfont")
local button = require("lib.button")

local buttons = nil

-- Write centered text on monitor at given y position
local function writeCentered(monitor, y, text)
    local w, _ = monitor.getSize()
    local x = math.floor((w - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

return {
    draw = function(ctx)
        local m = ctx.monitor
        buttons = nil
        monitorLib.reset(m)

        buttons = {
            -- Confirm / Back
            button.createNewButton(9, 30, "Confirm", colors.green, colors.gray, false,
                function()
                    local transfer = piebank.send(ctx.gatewayID, ctx.cardID, ctx.transferID, ctx.transferAmount)
                    if not transfer.success then
                        ctx.errorMessage = transfer.error or "Your transfer could not be processed"
                        return ctx:goto("transfer")
                    end

                    ctx.balance = transfer.sender.balance
                    ctx.transferOwner = nil
                    ctx.transferID = "_"
                    ctx.transferAmount = 0
                    ctx:goto("balance")
                end
            ),
            button.createNewButton(21, 30, " Back ", colors.gray, colors.black, false,
                function() ctx:goto("transferAmount") end
            )
        }
        button.drawButtons(m, buttons)

        local transaction = piebank.getProccessingRate(ctx.gatewayID)
        local rate = 0
        if not transaction.success then
            ctx.errorMessage = transaction.error or "Could not retrieve processing fee"
        else
            rate = transaction.processing_rate * 100
        end

        if ctx.errorMessage then
            m.setCursorPos(2, 2)
            m.setTextColor(colors.red)
            m.write(ctx.errorMessage)
            ctx.errorMessage = nil
        end

        m.setBackgroundColor(colors.black)
        m.setTextColor(colors.white)
        bigfont.writeOn(m, 1, "Transfer", nil, 5)
        bigfont.writeOn(m, 1, tostring(ctx.transferOwner), nil, 15)
        bigfont.writeOn(m, 1, ctx.currencyIcon .. ctx.transferAmount, nil, 20)
        m.setTextColor(colors.gray)
        writeCentered(m, 38, " a " .. rate .. "% processing fee will be charged*")
    end,

    update = function(ctx)
        if buttons then
            button.checkButtonsPressed(ctx.monitor, buttons, 0)
        end
    end
}