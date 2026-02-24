-- ui/transfer.lua

local piebank = require("disk.lib.piebank")

local monitorLib = require("lib.monitor")
local bigfont = require("lib.bigfont")
local button = require("lib.button")

local buttons = nil
local MAX_LEN = 8

-- Add a digit to the input if it doesn't exceed max length
local function addDigit(ctx, d)
    if #ctx.transferID < MAX_LEN then
        if ctx.transferID == "_" then
            ctx.transferID = ""
        end
        ctx.transferID = ctx.transferID .. d
    end
end

-- Remove the last character from the input
local function backspace(ctx)
    ctx.transferID = ctx.transferID:sub(1, -2)
end

-- Clear the entire input
local function clear(ctx)
    ctx.transferID = "_"
end

return {
    draw = function(ctx)
        local m = ctx.monitor
        buttons = nil
        monitorLib.reset(m)

        ctx.transferID = ctx.transferID or ""

        buttons = {
            -- Numberpad
            button.createNewButton(11, 15, "1", colors.gray, colors.lightGray, false,
            function() addDigit(ctx, "1") end),
            button.createNewButton(17, 15, "2", colors.gray, colors.lightGray, false,
                function() addDigit(ctx, "2") end),
            button.createNewButton(23, 15, "3", colors.gray, colors.lightGray, false,
                function() addDigit(ctx, "3") end),

            button.createNewButton(11, 19, "4", colors.gray, colors.lightGray, false,
                function() addDigit(ctx, "4") end),
            button.createNewButton(17, 19, "5", colors.gray, colors.lightGray, false,
                function() addDigit(ctx, "5") end),
            button.createNewButton(23, 19, "6", colors.gray, colors.lightGray, false,
                function() addDigit(ctx, "6") end),

            button.createNewButton(11, 23, "7", colors.gray, colors.lightGray, false,
                function() addDigit(ctx, "7") end),
            button.createNewButton(17, 23, "8", colors.gray, colors.lightGray, false,
                function() addDigit(ctx, "8") end),
            button.createNewButton(23, 23, "9", colors.gray, colors.lightGray, false,
                function() addDigit(ctx, "9") end),

            button.createNewButton(11, 27, "C", colors.red, colors.gray, false,
                function() clear(ctx) end),
            button.createNewButton(17, 27, "0", colors.gray, colors.lightGray, false,
                function() addDigit(ctx, "0") end),
            button.createNewButton(23, 27, "<", colors.orange, colors.gray, false,
                function() backspace(ctx) end),

            -- Confirm / Back
            button.createNewButton(7, 32, "Confirm", colors.green, colors.gray, false, function()
                if ctx.transferID == "" or ctx.transferID == "_" then
                    ctx.errorMessage = "Enter an transaction ID"
                    return ctx:goto("transfer")
                end

                local lookup = piebank.lookup(ctx.gatewayID, ctx.transferID)
                if not lookup.success then
                    ctx.errorMessage = lookup.error or "Your transfer could not be processed"
                    return ctx:goto("transfer")
                end

                ctx.transferOwner = lookup.owner

                ctx:goto("transferAmount")
            end),
            button.createNewButton(21, 32, " Back ", colors.gray, colors.black, false,
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
        bigfont.writeOn(m, 1, "Enter TXID", nil, 5)
        bigfont.writeOn(m, 1, ctx.transferID, nil, 10)
    end,

    update = function(ctx)
        if buttons then
            button.checkButtonsPressed(ctx.monitor, buttons, 0)
        end
    end
}