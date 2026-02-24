-- ui/create.lua

local piebank = require("lib.piebank")
local basalt = require("lib.basalt")

local DEFAULT_USERNAME = ""
local DEFAULT_USERNAME_LENGTH = 16
local DEFAULT_PIN = ""
local DEFAULT_PIN_LENGTH = 6
local DEFAULT_CURRENCY = "minecraft:diamond"
local DEFAULT_COST = 16

-- Pulls the printed receipt and card from the printer and drive into the output barrel.
local function outputResults(drive, printer, output)
    if not output then
        return { success = false, error = "Output is not found" }
    end

    if not printer then
        return { success = false, error = "Printer is not connected" }
    end

    if not drive then
        return { success = false, error = "Disk drive is not connected" }
    end

    local moved = 0

    -- Printer pages typically end up in slot 8
    moved = moved + (output.pullItems(peripheral.getName(printer), 8) or 0)

    -- Disk drives usually expose the disk as slot 1
    moved = moved + (output.pullItems(peripheral.getName(drive), 1) or 0)

    if moved > 0 then
        return { success = true }
    end

    return { success = false, error = "Failed to move items to output" }
end

-- Prints a receipt with the account information using a connected printer peripheral.
local function printAccountReceipt(account, id, pin)
    local printer = peripheral.find("printer")
    if not printer then
        return { success = false, error = "No printer connected" }
    end

    if not printer.newPage() then
        return { success = false, error = "Printer is out of paper or ink" }
    end

    if printer.setPageTitle then
        printer.setPageTitle(account.owner.. "'s Account Info")
    end

    -- Helper function to format SQL datetime strings into a more readable format.
    local function formatSqlDate(sqlDate)
        local y, m, d, h, mi, s = sqlDate:match(
            "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"
        )

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
    
    line(5, "     Account Receipt")
    line(7, "Owner: " .. tostring(account.owner))
    line(8, "Account ID: " .. tostring(account.account_id))
    line(9, "Transfer ID: " .. tostring(account.tx_id))
    line(10, "Card ID: " .. tostring(string.sub(account.card_id, 1, 4) .. "XXXXXXX-XXXX"))
    line(11, "PIN: " .. tostring(string.sub(pin, 1, 3)) .. "XXX")
    line(12, "Balance: " .. tostring(string.char(4) .. account.balance))

    line(14,  "\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140\140")

    line(16, "       IMPORTANT")
    line(18, "PLEASE KEEP YOUR PIEBANK")
    line(19, " CARD IN A SECURE PLACE")

    printer.endPage()
    return { success = true }
end

-- Copies the piebank library to the inserted PieBank card
local function copyPiebankLibToDisk(drive)
    if not drive then return false end

    local mount = drive.getMountPath and drive.getMountPath()
    if not mount then return false end

    if not fs.exists(mount .. "/lib") then
        fs.makeDir(mount .. "/lib")
    end

    local dst = mount .. "/lib/piebank.lua"
    if fs.exists(dst) then
        fs.delete(dst)
    end

    if not fs.exists("lib/piebank.lua") then
        return false
    end

    fs.copy("lib/piebank.lua", dst)
    return true
end

-- Writes the card information to the disk's info.json file.
local function writeCardInfo(drive, cardID, txID)
    if not drive then return false end

    if not copyPiebankLibToDisk(drive) then
        return false
    end

    local info = {
        card_id = cardID,
        tx_id = txID
    }

    local filePath = drive.getMountPath() .. "/info.json"
    local file = fs.open(filePath, "w+")
    if not file then return false end

    file.write(textutils.serializeJSON(info))
    file.close()

    return true
end

-- Counts the number of diamonds in the dispenser.
local function countDiamonds(dispenser)
    if not dispenser then return 0 end

    local total = 0
    for _, item in pairs(dispenser.list()) do
        if item.name == DEFAULT_CURRENCY then
            total = total + item.count
        end
    end
    return total
end

-- Attempts to take the specified amount of diamonds from the dispenser.
local function takeDiamonds(dispenser, vault, amount)
    if not dispenser or not vault then return false end

    local remaining = amount
    for slot, item in pairs(dispenser.list()) do
        if item.name == DEFAULT_CURRENCY then
            local toTake = math.min(item.count, remaining)
            local moved = dispenser.pushItems(peripheral.getName(vault), slot, toTake)
            remaining = remaining - moved
            if remaining <= 0 then
                return true
            end
        end
    end

    return false
end

-- Attempts to take a bank card from the available barrels.
local function takeCard(drive, cards)
    for _, barrel in ipairs(cards) do
        local list = barrel.list()
        if next(list) then
            local slot = next(list)
            local moved = barrel.pushItems(peripheral.getName(drive), slot, 1)
            if moved > 0 then
                return true
            end
        end
    end
    return false
end

return function(ctx)
    local width, height = term.getSize()
    local frame = ctx.app:addFrame()
        :setSize(width, height)
        :setBackground(colors.black)
        :setVisible(false)
    
    frame:addLabel()
        :setText("Bank Card Application")
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
        :onClick(function(self, button, x, y)
            usernameInput:setText("")
            pinInput:setText("")
            ctx.speaker.playSound("block.wooden_button.click_on")
        end )
        :setBackground(colors.yellow)
        :setForeground(colors.black)
    
    frame:addButton()
        :setText("Confirm")
        :centerHorizontal("parent", 12)
        :toTop(12)
        :setSize(11, 3)
        :onClick(function(self, button, x, y)
            ctx.speaker.playSound("block.wooden_button.click_on")

            local username = usernameInput.text
            local pin = pinInput.text

            if username == "" or #username > DEFAULT_USERNAME_LENGTH or not username:match("^[%w_]+$") then
                return frame.showToast("Please enter a valid username", colors.red) 
            end
            
            if #pin ~= DEFAULT_PIN_LENGTH or string.find(pin, "%D") then 
                return frame.showToast("PIN must be ".. DEFAULT_PIN_LENGTH .. " digits", colors.red)
            end
            
            local diamonds = countDiamonds(ctx.dispenser)
            if diamonds < DEFAULT_COST then
                return frame.showToast("Please insert ".. DEFAULT_COST .. " diamonds into the dispenser", colors.red)
            end

            if not ctx.cards or #ctx.cards == 0 then
                return frame.showToast("No card storage found! Please contact PieTwelve", colors.red)
            end

            local computer = piebank.isWhitelisted(ctx.gatewayID)
            if not computer.whitelisted then
                return frame.showToast("This computer is not have authorized access", colors.red)
            end

            if not takeCard(ctx.drive, ctx.cards) then
                return frame.showToast("Out of bank cards! Please contact PieTwelve", colors.red)
            end

            if not takeDiamonds(ctx.dispenser, ctx.vault, DEFAULT_COST) then
                return frame.showToast("Failed to take diamonds from dispenser!", colors.red)
            end

            frame.showToast("Processing your application...", colors.yellow)
            usernameInput:setText("")
            pinInput:setText("")

            local account = piebank.create(ctx.gatewayID, username, pin)
            if not account.success then
                return frame.showToast(account.error or "Failed to create account", colors.red)
            end

            ctx.drive.setDiskLabel(account.owner .. "'s PieBank Card")
            
            if not writeCardInfo(ctx.drive, account.card_id, account.tx_id) then
                return frame.showToast("Failed to write card information to disk", colors.red)
            end

            local printed = printAccountReceipt(account, ctx.drive.getDiskID(), pin)
            if not printed.success then
                frame.showToast(printed.error, colors.yellow)
            end

            local out = outputResults(ctx.drive, ctx.printer, ctx.output)
            if not out.success then
                frame.showToast(out.error, colors.yellow)
            end

            frame.gotoScreen("main")
            frame.showToast("Thank you for choosing PieBank!", colors.green)
            ctx.speaker.playSound("entity.experience_orb.pickup")
        end)
        :setBackground(colors.green)
        :setForeground(colors.black)

    return frame
end