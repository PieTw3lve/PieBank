local button = {}

-- Creates a new button
-- xPos, yPos: top-left coordinates
-- label: string displayed on button
-- defaultColor: background when inactive (colors.*)
-- pressedColor: background when active
-- toggleable: boolean, true = toggles on/off
-- onPress: function to call when pressed
function button.createNewButton(xPos, yPos, label, defaultColor, pressedColor, toggleable, onPress)
    return {
        x = xPos,
        y = yPos,
        label = label,
        defaultColor = defaultColor,
        pressedColor = pressedColor,
        toggleable = toggleable,
        onPress = onPress, -- function to run on press
        toggled = false
    }
end

-- Draws a list of buttons onto a monitor
function button.drawButtons(monitor, buttonList)
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    for i = 1, #buttonList do
        local btn = buttonList[i]
        monitor.setBackgroundColor(btn.toggled and btn.pressedColor or btn.defaultColor)

        -- Top row of spaces
        monitor.setCursorPos(btn.x, btn.y)
        monitor.write(string.rep(" ", #btn.label + 2))

        -- Label row
        monitor.setCursorPos(btn.x, btn.y + 1)
        monitor.write(" " .. btn.label .. " ")

        -- Bottom row of spaces
        monitor.setCursorPos(btn.x, btn.y + 2)
        monitor.write(string.rep(" ", #btn.label + 2))
    end
end

-- Checks for button presses (monitor_touch events)
-- timeoutLength in seconds; 0 for no timeout
-- timeoutFunction runs if timeout triggers
function button.checkButtonsPressed(monitor, buttonList, timeoutLength, timeoutFunction)
    local pressedCheck = false
    local timeoutTimer
    if timeoutLength > 0 then
        timeoutTimer = os.startTimer(timeoutLength)
    end

    while true do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "timer" and p1 == timeoutTimer then
            if timeoutFunction then timeoutFunction() end
            break

        elseif event == "monitor_touch" then
            for i = 1, #buttonList do
                local btn = buttonList[i]
                if p2 >= btn.x and p2 <= btn.x + #btn.label + 2
                   and p3 >= btn.y and p3 <= btn.y + 2 then

                    if btn.toggleable then
                        btn.toggled = not btn.toggled
                        button.drawButtons(monitor, buttonList)
                        if btn.onPress then btn.onPress(not btn.toggled) end
                    else
                        btn.toggled = true
                        button.drawButtons(monitor, buttonList)
                        sleep(0.25)
                        if btn.onPress then btn.onPress() end
                        btn.toggled = false
                        button.drawButtons(monitor, buttonList)
                    end

                    pressedCheck = true
                    break
                end
            end

            if pressedCheck then break end
        end
    end
end

return button