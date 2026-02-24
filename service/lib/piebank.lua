-- lib/piebank.lua

local piebank = {}

-- Internal helper for consistent timeout error response
local function timeoutFail()
    return { success = false, error = "The bank is currently offline" }
end

-- Internal helper to send + receive
local function sendAndReceive(gatewayID, payload)
    rednet.send(gatewayID, payload, "piebank")

    local _, response = rednet.receive("piebank", 10)
    if not response then
        return timeoutFail()
    end

    return response
end

-- Authorized methods

-- Authenticates a card and returns the account information
function piebank.auth(gatewayID, cardID)
    return sendAndReceive(gatewayID, {
        type = "auth",
        card_id = cardID
    })
end

-- Creates a new account
function piebank.create(gatewayID, username, pin)
    return sendAndReceive(gatewayID, {
        type = "create",
        owner = username,
        pin = pin
    })
end

-- Deletes an account
function piebank.delete(gatewayID, username, pin)
    return sendAndReceive(gatewayID, {
        type = "delete",
        owner = username,
        pin = pin
    })
end

-- Creates a new card ID for an existing account
function piebank.recover(gatewayID, username, pin)
    return sendAndReceive(gatewayID, {
        type = "recover",
        owner = username,
        pin = pin
    })
end

-- Deposits funds into an account
function piebank.deposit(gatewayID, cardID, amount)
    return sendAndReceive(gatewayID, {
        type = "deposit",
        card_id = cardID,
        amount = amount
    })
end

-- Withdraws funds from an account
function piebank.withdraw(gatewayID, cardID, amount)
    return sendAndReceive(gatewayID, {
        type = "withdraw",
        card_id = cardID,
        amount = amount
    })
end

-- Public methods

-- Connects to the PieBank gateway
function piebank.connect(side)
    if not side then
        return { success = false, error = "Please specify the side of the modem" }
    end

    rednet.open(side)

    if not rednet.isOpen(side) then
        return { success = false, error = "Failed to open modem for rednet communication" }
    end

    local gatewayID = rednet.lookup("piebank_gateway")
    if not gatewayID then
        return { success = false, error = "No PieBank gateway found" }
    end

    return { success = true, gatewayID = gatewayID }
end

-- Disconnects from the PieBank gateway
function piebank.disconnect(side)
    if not side or not rednet.isOpen(side) then
        return { success = false, error = "Modem is not open" }
    end

    rednet.close(side)

    return { success = true }
end

-- Checks if the computer is whitelisted
function piebank.isWhitelisted(gatewayID)
    return sendAndReceive(gatewayID, {
        type = "whitelisted"
    })
end

-- Reads the card ID from the PieBank card
function piebank.readCard(drive)
    if not drive then
        return { success = false, error = "Please connect a disk drive" }
    end

    local mount = drive.getMountPath and drive.getMountPath()
    if not mount then
        return { success = false, error = "No disk inserted in drive" }
    end

    local file = fs.open(mount .. "/info.json", "r")
    if not file then
        return { success = false, error = "No PieBank card found in disk drive" }
    end

    local raw = file.readAll()
    file.close()

    local ok, data = pcall(textutils.unserializeJSON, raw)
    if not ok or type(data) ~= "table" then
        return { success = false, error = "Card data is corrupted (invalid JSON)" }
    end

    if type(data.card_id) ~= "string" or data.card_id == "" then
        return { success = false, error = "Card data is missing card_id" }
    end

    return { success = true, card_id = data.card_id }
end

-- Lookup an account name by transfer ID
function piebank.lookup(gatewayID, txID)
    return sendAndReceive(gatewayID, {
        type = "lookup",
        tx_id = txID
    })
end

-- Sends funds from card ID to transfer ID
function piebank.transfer(gatewayID, cardID, txID, amount)
    return sendAndReceive(gatewayID, {
        type = "transfer",
        card_id = cardID,
        tx_id = txID,
        amount = amount
    })
end

-- Sends funds from card ID to transfer ID (alias for transfer)
function piebank.send(gatewayID, cardID, txID, amount)
    return piebank.transfer(gatewayID, cardID, txID, amount)
end

-- Gets the current processing rate of PieBank
function piebank.getProccessingRate(gatewayID)
    return sendAndReceive(gatewayID, {
        type = "rate"
    })
end

return piebank