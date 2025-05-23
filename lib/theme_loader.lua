local mq = require('mq')
local ImGui = require('ImGui')

local LoadTheme = {}

function LoadTheme.shallowcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in pairs(orig) do
			copy[orig_key] = orig_value
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function LoadTheme.PCallString(str)
	local func, err = load(str)
	if not func then
		print(err)
		return false, err
	end

	return pcall(func)
end

function LoadTheme.EvaluateLua(str)
	local runEnv = [[mq = require('mq')
			%s
			]]
	return LoadTheme.PCallString(string.format(runEnv, str))
end

---Loads a Theme from a Table and returns the number of Styles and Colors pushed so you can Pop them later
---@param tName string Theme Name
---@param tTable table Theme Table
---@param mouseOver boolean|nil Mouse Over option for changing alpha
---@param mouseHovered boolean|nil Pass Mouse Hovered state to change alpha
---@param mouseOvaerAlpha number|nil Alpha to set when Mouse Over is true
---@return integer StyleCounter Count of Styles Pushed
---@return integer ColorCounter Count of Colors Pushed
---@return integer themeID Theme ID Loaded
function LoadTheme.StartTheme(tName, tTable, mouseOver, mouseHovered, mouseOvaerAlpha)
	if mouseOver == nil then mouseOver = false end
	if mouseHovered == nil then mouseHovered = false end
	if mouseOvaerAlpha == nil then mouseOvaerAlpha = 1 end
	local StyleCounter = 0
	local ColorCounter = 0
	local themeID = 0
	if tTable.Theme == nil then
		return StyleCounter, ColorCounter, themeID
	end
	for tID, tData in pairs(tTable.Theme or {}) do
		if tData.Name == tName then
			themeID = tID
			for pID, cData in pairs(tTable.Theme[tID].Color) do
				if cData.PropertyName == 'WindowBg' and mouseOver then
					if mouseHovered then
						ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], 1.0))
						ColorCounter = ColorCounter + 1
					else
						ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], mouseOvaerAlpha))
						ColorCounter = ColorCounter + 1
					end
				else
					ImGui.PushStyleColor(ImGuiCol[cData.PropertyName], ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
					ColorCounter = ColorCounter + 1
				end
			end
			if tData['Style'] ~= nil then
				if next(tData['Style']) ~= nil then
					for sID, sData in pairs(tTable.Theme[tID].Style) do
						if sData.Size ~= nil then
							ImGui.PushStyleVar(sID, sData.Size)
							StyleCounter = StyleCounter + 1
						elseif sData.X ~= nil then
							ImGui.PushStyleVar(sID, sData.X, sData.Y)
							StyleCounter = StyleCounter + 1
						end
					end
				end
			end
		end
	end
	return ColorCounter, StyleCounter, themeID
end

---@param themeColorPop integer
---@param themeStylePop integer
function LoadTheme.EndTheme(themeColorPop, themeStylePop)
	if themeColorPop > 0 then
		ImGui.PopStyleColor(themeColorPop)
	end
	if themeStylePop > 0 then
		ImGui.PopStyleVar(themeStylePop)
	end
end

return LoadTheme
