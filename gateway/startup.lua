-- startup.lua

local API_URL = ""
local API_KEY = ""

local whitelist = {
    -- Add authorized computer IDs here
}

rednet.open("top")
rednet.host("piebank_gateway", "PieBank Gateway")

term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.green)
print("PieBank gateway online, waiting for rednet requests...")
term.setTextColor(colors.gray)

-- Helper function to check if a computer ID is whitelisted
local function isWhitelisted(id)
    for _, cid in ipairs(whitelist) do
        if cid == id then return true end
    end
    return false
end

-- Helper function to POST JSON data to the API
local function postJSON(endpoint, tableData)
    local payload = textutils.serializeJSON(tableData)

    local res, err = http.post(
        API_URL .. endpoint,
        payload,
        { ["Content-Type"] = "application/json" }
    )

    if not res then
        return { success = false, error = "HTTP failed: " .. tostring(err) }
    end

    local body = res.readAll()
    res.close()

    local ok, decoded = pcall(textutils.unserializeJSON, body)
    if not ok or type(decoded) ~= "table" then
        return { success = false, error = "Invalid response from API", raw = body }
    end

    return decoded
end

while true do
    local sender, msg = rednet.receive()

    if not msg.type then goto continue end

    print(("[%s] Request from computer %d (%s)"):format(
        os.date("%Y-%m-%d %H:%M:%S"),
        sender,
        msg.type
    ))

    if type(msg) ~= "table" or not msg.type then
        rednet.send(sender, { success = false, error = "Invalid request format" }, "piebank")
        goto continue
    end

    local restrictedTypes = { create = true, delete = true, recover = true, auth = true, withdraw = true, deposit = true }
    if restrictedTypes[msg.type] and not isWhitelisted(sender) then
        rednet.send(sender, { success = false, error = "Computer access not authorized" }, "piebank")
        goto continue
    end

    -- AUTH REQUEST (whitelist only)
    if msg.type == "auth" then
        local response = postJSON("/auth", {
            card_id = msg.card_id,
            key = API_KEY
        })

        rednet.send(sender, response, "piebank")
        goto continue
    end

    -- CREATE ACCOUNT REQUEST (whitelist only)
    if msg.type == "create" then
        local response = postJSON("/create", {
            owner = msg.owner,
            pin = msg.pin,
            key = API_KEY
        })

        rednet.send(sender, response, "piebank")
        goto continue
    end

    -- DELETE ACCOUNT REQUEST (whitelist only)
    if msg.type == "delete" then
        local response = postJSON("/delete", {
            owner = msg.owner,
            pin = msg.pin,
            key = API_KEY
        })

        rednet.send(sender, response, "piebank")
        goto continue
    end

    -- RECOVER ACCOUNT REQUEST (whitelist only)
    if msg.type == "recover" then
        local response = postJSON("/recover", {
            owner = msg.owner,
            pin = msg.pin,
            key = API_KEY
        })

        rednet.send(sender, response, "piebank")
        goto continue
    end

    -- WITHDRAW REQUEST (whitelist only)
    if msg.type == "withdraw" then
        local response = postJSON("/withdraw", {
            card_id = msg.card_id,
            amount = msg.amount,
            key = API_KEY
        })

        rednet.send(sender, response, "piebank")
        goto continue
    end

    -- DEPOSIT REQUEST (whitelist only)
    if msg.type == "deposit" then
        local response = postJSON("/deposit", {
            card_id = msg.card_id,
            amount = msg.amount,
            key = API_KEY
        })

        rednet.send(sender, response, "piebank")
        goto continue
    end

    -- IS WHITELISTED REQUEST
    if msg.type == "whitelisted" then
        local isWhitelisted = isWhitelisted(sender)
        rednet.send(sender, { success = true, whitelisted = isWhitelisted }, "piebank")
        goto continue
    end

    -- LOOKUP REQUEST
    if msg.type == "lookup" then
        local response = postJSON("/lookup", {
            tx_id = msg.tx_id,
            key = API_KEY
        })

        rednet.send(sender, response, "piebank")
        goto continue
    end

    -- TRANSFER REQUEST
    if msg.type == "transfer" then
        local response = postJSON("/transfer", {
            card_id = msg.card_id,
            tx_id = msg.tx_id,
            amount = msg.amount,
            key = API_KEY
        })

        rednet.send(sender, response, "piebank")
        goto continue
    end

    -- RATE REQUEST
    if msg.type == "rate" then
        local response = postJSON("/rate", {
            key = API_KEY
        })

        rednet.send(sender, response, "piebank")
        goto continue
    end

    -- UNKNOWN REQUEST
    rednet.send(sender, {
        success = false,
        error = "Unknown request type: " .. tostring(msg.type),
        "piebank"
    })

    ::continue::
end