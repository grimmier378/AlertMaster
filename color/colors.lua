-- colors.lua
local COLOR = {}
 function COLOR.txtColor(c)
    if (c=='red') then return ImGui.PushStyleColor(ImGuiCol.Text,0.9, 0.1, 0.1, 1) end
    if (c=='yellow') then return ImGui.PushStyleColor(ImGuiCol.Text,1, 1, 0, 1) end
    if (c=='white') then return ImGui.PushStyleColor(ImGuiCol.Text,1, 1, 1, 1) end
    if (c=='blue') then return ImGui.PushStyleColor(ImGuiCol.Text,0, 0, 1, 1) end
    if (c=='light blue') then return ImGui.PushStyleColor(ImGuiCol.Text,0, 1, 1, 1) end
    if (c=='green') then return ImGui.PushStyleColor(ImGuiCol.Text,0, 1, 0, 1) end
    if (c=='grey') then return ImGui.PushStyleColor(ImGuiCol.Text,0.6, 0.6, 0.6, 1) end
    if (c=='purple') then return ImGui.PushStyleColor(ImGuiCol.Text,0.8, 0.0, 1.0, 1.0) end
end
 function COLOR.barColor(c)
    if (c == 'red') then return ImGui.PushStyleColor(ImGuiCol.PlotHistogram,0.7, 0, 0, 0.7) end
    if (c == 'pink') then return ImGui.PushStyleColor(ImGuiCol.PlotHistogram,0.9, 0.4, 0.4, 0.8) end
    if (c == 'blue') then return ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 0.2, 0.6, 1, 0.4) end
    if (c == 'yellow') then return ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 0.7, .6, .1, .7) end
    if (c == 'purple') then return ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 0.6, 0.0, 0.6, 0.7) end
    if (c == 'grey') then return ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 1, 1, 1, 0.2) end
end

return COLOR