-- ui/balance.lua

local monitorLib = require("lib.monitor")
local bigfont = require("lib.bigfont")
local button = require("lib.button")

local buttons = nil

return {
    draw = function(ctx)
        local m = ctx.monitor
        buttons = nil
        monitorLib.reset(m)

        if not buttons then
            buttons = {
                button.createNewButton(4, 25, "Deposit", colors.green, colors.gray, false,
                    function() ctx:goto("deposit") end),
                button.createNewButton(14, 25, "Withdraw", colors.green, colors.gray, false,
                    function() ctx:goto("withdraw") end),
                button.createNewButton(25, 25, "Transfer", colors.orange, colors.gray, false,
                    function() ctx:goto("transfer") end),
                button.createNewButton(15, 30, "Logout", colors.red, colors.gray, false,
                    function() ctx.running = false end)
            }
            button.drawButtons(m, buttons)
        end

        if ctx.successMessage then
            m.setBackgroundColor(colors.gray)
            m.setTextColor(colors.lime)
            m.setCursorPos(2, 2)
            m.write(ctx.successMessage)
            ctx.successMessage = nil
        end

        m.setBackgroundColor(colors.black)
        m.setTextColor(colors.white)
        bigfont.writeOn(m, 1, ctx.owner, nil, 5)
        bigfont.writeOn(m, 1, ctx.currencyIcon .. ctx.balance, nil, 15)
    end,

    update = function(ctx)
        if buttons then
            button.checkButtonsPressed(ctx.monitor, buttons, 0)
        end
    end
}