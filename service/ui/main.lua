-- ui/main.lua

local basalt = require("basalt")

return function(ctx)
    local width, height = term.getSize()
    local frame = ctx.app:addFrame()
        :setSize(width, height)
        :setBackground(colors.black)
        :setVisible(false)
    
    local toast = frame:addToast()
        :setSize(100, 1)
        :setBackground(colors.black)

    frame:addLabel()
        :setText("PieBank Services")
        :centerHorizontal("parent", 0)
        :toTop(2)
        :setForeground(colors.white)

    frame:addButton()
        :setText("Create Account")
        :setSize(20, 3)
        :centerHorizontal("parent", 0)
        :toTop(6)
        :onClick(function()
            os.sleep(0.1)
            frame.gotoScreen("create")
            ctx.speaker.playSound("block.wooden_button.click_on")
        end)
        :setBackground(colors.green)
    
    frame:addButton()
        :setText("Delete Account")
        :setSize(20, 3)
        :centerHorizontal("parent", 0)
        :toTop(10)
        :onClick(function()
            os.sleep(0.1)
            frame.gotoScreen("delete")
            ctx.speaker.playSound("block.wooden_button.click_on")
        end)
        :setBackground(colors.red)
    
    frame:addButton()
        :setText("Account Recovery")
        :setSize(20, 3)
        :centerHorizontal("parent", 0)
        :toTop(14)
        :onClick(function()
            os.sleep(0.1)
            frame.gotoScreen("recover")
            ctx.speaker.playSound("block.wooden_button.click_on")
        end)
        :setBackground(colors.yellow)

    return frame
end