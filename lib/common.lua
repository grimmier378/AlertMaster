local mq = require('mq')
local ImGui = require('ImGui')
local CommonUtils = require('mq.Utils')

CommonUtils.Animation_Item = mq.FindTextureAnimation('A_DragItem')
CommonUtils.Animation_Spell = mq.FindTextureAnimation('A_SpellIcons')

---Calcluate the color between two colors based on a value between 0 and 100.
---
--- If a midColor is provided, the color will transition from minColor (0 value ) to midColor (midVal) to maxColor (100 value) or vice versa depending on the value
---@param minColor table  Color in the format {r, g, b, a}
---@param maxColor table  Color in the format {r, g, b, a}
---@param value number Value between 0 and 100
---@param midColor table|nil  Optional mid range color
---@param midValue number|nil  Optional mid range value, where we switch from minColor to midColor and midColor to maxColor
---@return ImVec4  Returns the color as an ImVec4
function CommonUtils.CalculateColor(minColor, maxColor, value, midColor, midValue)
	-- Ensure value is within the range of 0 to 100
	value = math.max(0, math.min(100, value))
	midValue = midValue or 50

	local r, g, b, a

	if midColor then
		-- If midColor is provided, calculate in two segments
		if value > midValue then
			local proportion = (value - midValue) / (100 - midValue)
			r = midColor[1] + proportion * (maxColor[1] - midColor[1])
			g = midColor[2] + proportion * (maxColor[2] - midColor[2])
			b = midColor[3] + proportion * (maxColor[3] - midColor[3])
			a = midColor[4] + proportion * (maxColor[4] - midColor[4])
		else
			local proportion = value / midValue
			r = minColor[1] + proportion * (midColor[1] - minColor[1])
			g = minColor[2] + proportion * (midColor[2] - minColor[2])
			b = minColor[3] + proportion * (midColor[3] - minColor[3])
			a = minColor[4] + proportion * (midColor[4] - minColor[4])
		end
	else
		-- If midColor is not provided, calculate between minColor and maxColor
		local proportion = value / 100
		r = minColor[1] + proportion * (maxColor[1] - minColor[1])
		g = minColor[2] + proportion * (maxColor[2] - minColor[2])
		b = minColor[3] + proportion * (maxColor[3] - minColor[3])
		a = minColor[4] + proportion * (maxColor[4] - minColor[4])
	end
	-- changed to return as an ImVec4. keeping input as is since the color picker returns the table not an ImVec4
	return ImVec4(r, g, b, a)
end

---@param type string  'item' or 'pwcs' or 'spell' type of icon to draw
---@param txt string  the tooltip text
---@param iconID integer|string  the icon id to draw
---@param iconSize integer|nil  the size of the icon to draw
function CommonUtils.DrawStatusIcon(iconID, type, txt, iconSize)
	iconSize = iconSize or 26
	CommonUtils.Animation_Spell:SetTextureCell(iconID or 0)
	CommonUtils.Animation_Item:SetTextureCell(iconID or 3996)
	if type == 'item' then
		ImGui.DrawTextureAnimation(CommonUtils.Animation_Item, iconSize, iconSize)
	elseif type == 'pwcs' then
		local animPWCS = mq.FindTextureAnimation(iconID)
		animPWCS:SetTextureCell(iconID)
		ImGui.DrawTextureAnimation(animPWCS, iconSize, iconSize)
	else
		ImGui.DrawTextureAnimation(CommonUtils.Animation_Spell, iconSize, iconSize)
	end
	if ImGui.IsItemHovered() then
		ImGui.SetTooltip(txt)
	end
end

---@param spawn MQSpawn
function CommonUtils.GetConColor(spawn)
	local conColor = string.lower(spawn.ConColor()) or 'WHITE'
	return conColor
end

function CommonUtils.SetImage(file_path)
	return mq.CreateTexture(file_path)
end

--- Handles Printing output.
---
---If MyChat is not loaded it will just print to the main console or the mychat_tab is nil
---
---Options mainconsole only, mychat only, or both
---
---Note: MyChatHandler is a global function that is set by the MyChat mod if it is not loaded we will default to printing to the main console
---
---@param mychat_tab string|nil the MyChat tab name if nil we will just print to main console
---@param main_console boolean|nil  the main console if true we will print to the main console as well as the MyChat tab if it is loaded
---@param msg string  the message to output
---@param ... unknown  any additional arguments to format the message
function CommonUtils.PrintOutput(mychat_tab, main_console, msg, ...)
	if main_console == nil then main_console = false end

	msg = string.format(msg, ...)

	if mychat_tab == nil then
		print(msg)
	elseif MyUI_MyChatHandler ~= nil and main_console then
		MyUI_MyChatHandler(mychat_tab, msg)
		print(msg)
	elseif MyUI_MyChatHandler ~= nil then
		MyUI_MyChatHandler(mychat_tab, msg)
	else
		print(msg)
	end
end

--- Takes in a table or sorted index,key pairs and returns a sorted table of keys based on the number of columns to sorty by.
---
---This will keep your table sorted by columns instead of rows.
---@param input_table table|nil  the table to sort (optional) You can send a set of sorted keys if you have already custom sorted it.
---@param sorted_keys table|nil  the sorted keys table (optional) if you have already sorted the keys
---@param num_columns integer  the number of column groups to sort the keys into
---@return table
function CommonUtils.SortTableColums(input_table, sorted_keys, num_columns)
	if input_table == nil and sorted_keys == nil then return {} end

	-- If sorted_keys is provided, use it, otherwise extract the keys from the input_table
	local keys = sorted_keys or {}
	if #keys == 0 then
		for k, _ in pairs(input_table) do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return a < b
		end)
	end

	local total_items = #keys
	local num_rows = math.ceil(total_items / num_columns)
	local column_sorted = {}

	-- Reorganize the keys to fill vertically by columns
	for row = 1, num_rows do
		for col = 1, num_columns do
			local index = (col - 1) * num_rows + row
			if index <= total_items then
				table.insert(column_sorted, keys[index])
			end
		end
	end

	return column_sorted
end

---
--- Takes in a table of default settings and a table of loaded settings and checks for depreciated settings
---
--- If a depreciated setting is found it will remove it from the loaded settings table
---
--- Returns true if a new setting was found so you know to save the settings file
---@param default_settings table  the default settings table
---@param loaded_settings table  the loaded settings table
---@return boolean  returns true if a new setting was found
function CommonUtils.CheckRemovedSettings(default_settings, loaded_settings)
	local newSetting = false
	for setting, value in pairs(loaded_settings or {}) do
		if default_settings[setting] == nil then
			CommonUtils.PrintOutput('MyUI', nil, "\ayFound Depreciated Setting: \ao%s \ayRemoving it from the Settings File.", setting)
			loaded_settings[setting] = nil
			newSetting = true
		end
	end
	return newSetting
end

--- Takes in a table of default settings and a table of loaded settings and checks for any New default settings
---
--- If a new setting is found it will add it to the loaded settings table
---
--- Returns true if a new setting was found so you know to save the settings file
---@param default_settings table  the default settings table
---@param loaded_settings table  the loaded settings table
---@return boolean  returns true if a new setting was found
function CommonUtils.CheckDefaultSettings(default_settings, loaded_settings)
	local newSetting = false
	for setting, value in pairs(default_settings or {}) do
		if loaded_settings[setting] == nil then
			CommonUtils.PrintOutput('MyUI', nil, "\ayNew Default Setting: \ao%s \ayAdding it to the Settings File.", setting)
			loaded_settings[setting] = value
			newSetting = true
		end
	end
	return newSetting
end

-- Function to append colored text segments
---@param console any  the console we are writing to
---@param timestamp string  the timestamp for the line
---@param text string  the text we are writing
---@param textColor table|nil  the color we are writing the text in
---@param timeStamps boolean|nil  are we writing timestamps?
function CommonUtils.AppendColoredTimestamp(console, timestamp, text, textColor, timeStamps)
	if timeStamps == nil then timeStamps = true end
	text = text:gsub("%[%d%d:%d%d:%d%d%] ", "")
	if timeStamps then
		-- Define TimeStamp colors
		local yellowColor = ImVec4(1, 1, 0, 1)
		local whiteColor = ImVec4(1, 1, 1, 1)
		console:AppendTextUnformatted(yellowColor, "[")
		console:AppendTextUnformatted(whiteColor, timestamp)
		console:AppendTextUnformatted(yellowColor, "] ")
	end
	if textColor ~= nil then
		console:AppendTextUnformatted(textColor, text)
		console:AppendText("") -- Move to the next line after the entry
	else
		console:AppendText(text)
	end
end

function CommonUtils.GiveItem(target_id)
	if ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
		mq.cmdf("/target id %s", target_id)
		if mq.TLO.Cursor() then
			mq.cmdf('/multiline ; /tar id %s; /face; /if (${Cursor.ID}) /click left target', target_id)
		end
	end
end

return CommonUtils
