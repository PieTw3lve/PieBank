-- ui/delete.lua

local piebank = require("lib.piebank")
local basalt = require("lib.basalt")

local DEFAULT_USERNAME = ""
local DEFAULT_USERNAME_LENGTH = 16
local DEFAULT_PIN = ""
local DEFAULT_PIN_LENGTH = 6

-- Pulls the printed receipt from the printer into the output barrel.
local function outputResults(printer, output)
    if not output then
        return { success = false, error = "Output is not found" }
    end

    if not printer then
        return { success = false, error = "Printer is not connected" }
    end

    local moved = 0

    -- Printer pages typically end up in slot 8
    moved = moved + (output.pullItems(peripheral.getName(printer), 8) or 0)

    if moved > 0 then
        return { success = true }
    end

    return { success = false, error = "Failed to move items to output" }
end

-- Prints a receipt with the account information using a connected printer peripheral.
local function printAccountReceipt(printer, account, id, pin)
    if not printer then
        return { success = false, error = "No printer connected" }
    end

    if not printer.newPage() then
        return { success = false, error = "Printer is out of paper or ink" }
    end

    if printer.setPageTitle then
        printer.setPageTitle(account.owner .. "'s Account Info")
    end

    local function formatSqlDate(sqlDate)
        local y, m, d, h, mi, s = sqlDate:match("(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
        if not y then return "invalid date" end

        local timestamp = os.time({
            year = tonumber(y),
            month = tonumber(m),
            day = tonumber(d),
            hour = tonumber(h),
            min = tonumber(mi),
            sec = tonumber(s),
            isdst = false
        })

        return os.date("%d-%m-%Y", timestamp)
    end

    local function line(y, text)
        printer.setCursorPos(1, y)
        printer.write(text)
    end

    line(1, "PieBank" .. "        " .. tostring(formatSqlDate(account.created_at)))
    line(2, "ID " .. tostring(id))
    line(3, "\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140")

    line(5, " Account Deletion Receipt")
    line(7, "Owner: " .. tostring(account.owner))
    line(8, "Account ID: " .. tostring(account.account_id))
    line(9, "Transfer ID: " .. tostring(account.tx_id))
    line(10, "Card ID: " .. tostring(string.sub(account.card_id, 1, 4) .. "XXXXXXX-XXXX"))
    line(11, "PIN: " .. tostring(string.sub(pin, 1, 3)) .. "XXX")
    line(12, "Balance: " .. tostring(string.char(4) .. account.balance))

    line(14, "\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140")

    line(16, "       IMPORTANT")
    line(18, "DO NOT SHARE THIS PAPER.")
    line(19, "ACCOUNT DELETION IS FINAL.")

    printer.endPage()
    return { success = true }
end

return function(ctx)
    local width, height = term.getSize()
    local frame = ctx.app:addFrame()
        :setSize(width, height)
        :setBackground(colors.black)
        :setVisible(false)

    frame:addLabel()
        :setText("Delete Account")
        :centerHorizontal("parent", 0)
        :toTop(2)
        :setForeground(colors.white)

    local usernameInput = frame:addInput()
        :setSize(16, 1)
        :toLeft(4)
        :toTop(7)
        :setBackground(colors.cyan)
        :setForeground(colors.white)
    usernameInput.text = DEFAULT_USERNAME

    frame:addLabel()
        :setText("Username")
        :centerHorizontal(usernameInput)
        :toTop(6)
        :setForeground(colors.white)

    local pinInput = frame:addInput()
        :setSize(16, 1)
        :toRight(4)
        :toTop(7)
        :setBackground(colors.cyan)
        :setForeground(colors.white)
    pinInput.text = DEFAULT_PIN
    pinInput.replaceChar = "*"

    frame:addLabel()
        :setText("Security PIN")
        :centerHorizontal(pinInput)
        :toTop(6)
        :setForeground(colors.white)

    frame:addButton()
        :setText("<--")
        :centerHorizontal("parent", -12)
        :toTop(12)
        :setSize(11, 3)
        :onClick(function()
            os.sleep(0.1)
            frame.gotoScreen("main")
            ctx.speaker.playSound("block.wooden_button.click_off")
        end)
        :setBackground(colors.red)
        :setForeground(colors.black)

    frame:addButton()
        :setText("Clear")
        :centerHorizontal("parent", 0)
        :toTop(12)
        :setSize(11, 3)
        :onClick(function()
            usernameInput:setText("")
            pinInput:setText("")
            ctx.speaker.playSound("block.wooden_button.click_on")
        end)
        :setBackground(colors.yellow)
        :setForeground(colors.black)

    frame:addButton()
        :setText("Confirm")
        :centerHorizontal("parent", 12)
        :toTop(12)
        :setSize(11, 3)
        :onClick(function()
            ctx.speaker.playSound("block.wooden_button.click_on")

            local username = usernameInput.text
            local pin = pinInput.text

            if username == "" or #username > DEFAULT_USERNAME_LENGTH or not username:match("^[A-Za-z0-9_]+$") then
                return frame.showToast("Please enter a valid username", colors.red)
            end

            if #pin ~= DEFAULT_PIN_LENGTH or string.find(pin, "%D") then
                return frame.showToast("PIN must be " .. DEFAULT_PIN_LENGTH .. " digits", colors.red)
            end

            local computer = piebank.isWhitelisted(ctx.gatewayID)
            if not computer.whitelisted then
                return frame.showToast("This computer is not have authorized access", colors.red)
            end

            frame.showToast("Deleting your account...", colors.yellow)
            usernameInput:setText("")
            pinInput:setText("")

            local deleted = piebank.delete(ctx.gatewayID, username, pin)
            if not deleted.success then
                return frame.showToast(deleted.error or "Failed to delete account", colors.red)
            end

            local receiptId = tostring(os.epoch("utc"))

            local printed = printAccountReceipt(ctx.printer, deleted, receiptId, pin)
            if not printed.success then
                frame.showToast(printed.error, colors.yellow)
            end

            local out = outputResults(ctx.printer, ctx.output)
            if not out.success then
                frame.showToast(out.error, colors.yellow)
            end

            frame.gotoScreen("main")
            frame.showToast("Account deleted successfully!", colors.green)
            ctx.speaker.playSound("entity.experience_orb.pickup")
        end)
        :setBackground(colors.green)
        :setForeground(colors.black)

    return frame
end