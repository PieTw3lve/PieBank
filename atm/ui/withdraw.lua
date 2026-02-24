-- ui/withdraw.lua

local monitorLib = require("lib.monitor")
local bigfont = require("lib.bigfont")
local button = require("lib.button")

local buttons = nil

return {
    draw = function(ctx)
        local m = ctx.monitor
        buttons = nil
        monitorLib.reset(m)

        buttons = {
            -- Increment
            button.createNewButton(6, 17, " +1 ", colors.green, colors.gray, false,
                function() ctx.withdrawAmount = math.min(ctx.balance, ctx.withdrawAmount + 1) end),
            button.createNewButton(16, 17, " +5 ", colors.green, colors.gray, false,
                function() ctx.withdrawAmount = math.min(ctx.balance, ctx.withdrawAmount + 5) end),
            button.createNewButton(26, 17, "+100", colors.green, colors.gray, false,
                function() ctx.withdrawAmount = math.min(ctx.balance, ctx.withdrawAmount + 100) end),

            -- Decrement
            button.createNewButton(6, 22, " -1 ", colors.red, colors.gray, false,
                function() ctx.withdrawAmount = math.max(0, ctx.withdrawAmount - 1) end),
            button.createNewButton(16, 22, " -5 ", colors.red, colors.gray, false,
                function() ctx.withdrawAmount = math.max(0, ctx.withdrawAmount - 5) end),
            button.createNewButton(26, 22, "-100", colors.red, colors.gray, false,
                function() ctx.withdrawAmount = math.max(0, ctx.withdrawAmount - 100) end),

            -- Confirm / Back
            button.createNewButton(9, 30, "Confirm", colors.orange, colors.gray, false,
                function() 
                    if ctx.withdrawAmount <= 0 then
                        ctx.errorMessage = "Enter an amount greater than 0"
                        return ctx:goto("withdraw")
                    end
                    ctx:goto("withdrawConfirm") 
                end
            ),
            button.createNewButton(21, 30, " Back ", colors.gray, colors.black, false,
                function() ctx:goto("balance") end)
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
        bigfont.writeOn(m, 1, " How Much?", nil, 5)
        bigfont.writeOn(m, 1, ctx.currencyIcon .. ctx.withdrawAmount, nil, 10)
    end,

    update = function(ctx)
        if buttons then
            button.checkButtonsPressed(ctx.monitor, buttons, 0)
        end
    end
}