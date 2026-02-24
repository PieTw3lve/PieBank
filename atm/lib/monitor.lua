local M = {}

function M.reset(m)
    m.clear()
    m.setCursorPos(1, 1)
    m.setTextScale(0.5)
    m.setBackgroundColor(colors.black)
    m.setTextColor(colors.white)
end

return M