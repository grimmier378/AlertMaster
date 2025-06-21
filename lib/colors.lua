local ColorList = {}

--- Color table for GUI returns ImVec4
---Valud colors are:
---(red, pink, orange, yellow, yellow2, white, blue, softblue, light blue2, light blue,teal, green, green2, grey, purple, btn_red, btn_green)
---@param color_name string  the name of the color you want to return
---@return ImVec4  returns color as an ImVec4 vector
function ColorList.color(color_name)
    color_name = color_name:lower()
    local ColorList = {
        red = ImVec4(0.9, 0.1, 0.1, 1),
        red2 = ImVec4(0.928, 0.352, 0.035, 1.000),
        pink2 = ImVec4(0.976, 0.518, 0.844, 1.000),
        pink = ImVec4(0.9, 0.4, 0.4, 0.8),
        orange = ImVec4(0.78, 0.20, 0.05, 0.8),
        tangarine = ImVec4(1.000, 0.557, 0.000, 1.000),
        yellow = ImVec4(1, 1, 0, 1),
        yellow2 = ImVec4(0.7, 0.6, 0.1, 0.7),
        white = ImVec4(1, 1, 1, 1),
        blue = ImVec4(0, 0, 1, 1),
        softblue = ImVec4(0.370, 0.704, 1.000, 1.000),
        ['light blue2'] = ImVec4(0.2, 0.9, 0.9, 0.5),
        ['light blue'] = ImVec4(0, 1, 1, 1),
        teal = ImVec4(0, 1, 1, 1),
        green = ImVec4(0, 1, 0, 1),
        green2 = ImVec4(0.01, 0.56, 0.001, 1),
        grey = ImVec4(0.6, 0.6, 0.6, 1),
        purple = ImVec4(0.8, 0.0, 1.0, 1.0),
        purple2 = ImVec4(0.460, 0.204, 1.000, 1.000),
        btn_red = ImVec4(1.0, 0.4, 0.4, 0.4),
        btn_green = ImVec4(0.4, 1.0, 0.4, 0.4),
        black = ImVec4(0, 0, 0, 1),
    }
    if (ColorList[color_name]) then
        return ColorList[color_name]
    end
    -- If the color is not found, return white as default
    return ImVec4(1, 1, 1, 1)
end

return ColorList
