local ColorList = {}

--- Color table for GUI returns ImVec4
---Valud colors are:
---(red, pink, orange, yellow, yellow2, white, blue, softblue, light blue2, light blue,teal, green, green2, grey, purple, btn_red, btn_green)
---@param color_name string  the name of the color you want to return
---@return ImVec4  returns color as an ImVec4 vector
function ColorList.color(color_name)
    color_name = color_name:lower()
    if (color_name == 'red') then return ImVec4(0.9, 0.1, 0.1, 1) end
    if (color_name == 'pink2') then return ImVec4(0.976, 0.518, 0.844, 1.000) end
    if (color_name == 'pink') then return ImVec4(0.9, 0.4, 0.4, 0.8) end
    if (color_name == 'orange') then return ImVec4(0.78, 0.20, 0.05, 0.8) end
    if (color_name == 'tangarine') then return ImVec4(1.000, 0.557, 0.000, 1.000) end
    if (color_name == 'yellow') then return ImVec4(1, 1, 0, 1) end
    if (color_name == 'yellow2') then return ImVec4(0.7, 0.6, 0.1, 0.7) end
    if (color_name == 'white') then return ImVec4(1, 1, 1, 1) end
    if (color_name == 'blue') then return ImVec4(0, 0, 1, 1) end
    if (color_name == 'softblue') then return ImVec4(0.370, 0.704, 1.000, 1.000) end
    if (color_name == 'light blue2') then return ImVec4(0.2, 0.9, 0.9, 0.5) end
    if (color_name == 'light blue') then return ImVec4(0, 1, 1, 1) end
    if (color_name == 'teal') then return ImVec4(0, 1, 1, 1) end
    if (color_name == 'green') then return ImVec4(0, 1, 0, 1) end
    if (color_name == 'green2') then return ImVec4(0.01, 0.56, 0.001, 1) end
    if (color_name == 'grey') then return ImVec4(0.6, 0.6, 0.6, 1) end
    if (color_name == 'purple') then return ImVec4(0.8, 0.0, 1.0, 1.0) end
    if (color_name == 'purple2') then return ImVec4(0.460, 0.204, 1.000, 1.000) end
    if (color_name == 'btn_red') then return ImVec4(1.0, 0.4, 0.4, 0.4) end
    if (color_name == 'btn_green') then return ImVec4(0.4, 1.0, 0.4, 0.4) end
    return ImVec4(1, 1, 1, 1)
end

return ColorList
