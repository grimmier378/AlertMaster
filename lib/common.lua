local mq = require('mq')
local ImGui = require('ImGui')
local CommonUtils = require('mq.Utils')
CommonUtils.Colors = require('lib.colors')
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
		ImGui.BeginTooltip()
		if string.find(txt, "\\n") then
			local lines = {}
			for line in string.gmatch(txt, "[^\n]+") do
				table.insert(lines, line)
			end
			for _, line in ipairs(lines) do
				ImGui.Text(line)
			end
		else
			ImGui.Text(txt)
		end
		ImGui.EndTooltip()
	end
end

CommonUtils.ImGuiToggleFlags = {
	None           = 0,
	StarKnob       = bit32.lshift(1, 0),
	RightLabel     = bit32.lshift(1, 1),
	AnimateKnob    = bit32.lshift(1, 2),
	SmilyKnob      = bit32.lshift(1, 3),
	GlowOnHover    = bit32.lshift(1, 4),
	AnimateOnHover = bit32.lshift(1, 5),
	PulseOnHover   = bit32.lshift(1, 6),
	KnobBorder     = bit32.lshift(1, 7),
}

---@param draw_list ImDrawList Draw list to draw from
---@param pos ImVec2 Posion to start from (top-left corner of the star)
---@param size number Diameter of the star's outter points as a circle
---@param star_color ImU32 Color as ImU32
---@param rotation number Rotation in radians (optional)
---@param num_points integer Number of points to draw (default 5)
---@param border boolean Optional border flag (default false)
function CommonUtils.RenderStar(draw_list, pos, size, star_color, rotation, num_points, border)
	num_points = num_points or 5
	rotation = rotation or 0
	-- less than 4 points and we can't draw a star, 3 points should be a triangle, 2 is a line etc.
	if num_points < 4 then
		num_points = 4
	end
	local outer_radius = size * 0.5
	local center = ImVec2(pos.x + outer_radius, pos.y + outer_radius)

	-- Build the base triangle (tip up, unrotated)
	local triangleBase = outer_radius * math.tan(math.pi / num_points)
	local base_half = triangleBase * 0.5

	local base_triangle = {
		ImVec2(center.x, center.y - outer_radius),
		ImVec2(center.x + base_half, center.y),
		ImVec2(center.x - base_half, center.y),
	}

	for i = 0, num_points - 1 do
		local angle = rotation + (2 * math.pi / num_points) * i

		-- Rotate each point individually so we can get a better looking star.
		-- trying to draw out the lines was making a fat point at the top this is cleaner and scales easier
		-- thank you to the java code i found on https://stackoverflow.com/questions/14580033/algorithm-for-drawing-a-5-point-star

		local rotated_triangle = {}
		for _, p in ipairs(base_triangle) do
			table.insert(rotated_triangle, CommonUtils.RotatePoint(p, center, angle))
		end
		if border then
			draw_list:AddCircle(center, outer_radius, ImGui.GetColorU32(0.1, 0.1, 0.1, 0.4), 32, 2)
		end
		draw_list:AddConvexPolyFilled(rotated_triangle, star_color)
	end
end

-- ---@param draw_list ImDrawList Draw list to draw from
-- ---@param pos ImVec2 Position to start from (top-left corner of the star)
-- ---@param size number Diameter of the star's outer points as a circle
-- ---@param star_color ImU32 Color as ImU32
-- ---@param rotation number Rotation in radians (optional)
-- ---@param num_points integer Number of points to draw (default 5)
-- ---@param border boolean Optional border flag (default false)
-- function CommonUtils.RenderStar(draw_list, pos, size, star_color, rotation, num_points, border)
-- 	num_points = num_points or 5
-- 	rotation = rotation or 0
-- 	if num_points < 2 then num_points = 2 end

-- 	local outer_radius = size * 0.5
-- 	local inner_radius = outer_radius * 0.5
-- 	local center = ImVec2(pos.x + outer_radius, pos.y + outer_radius)
-- 	local angle_step = math.pi / num_points -- half the points are inner
-- 	local points = {}

-- 	local function polarToVec2(angleRad, distance)
-- 		return ImVec2(
-- 			center.x + math.cos(angleRad) * distance,
-- 			center.y + math.sin(angleRad) * distance
-- 		)
-- 	end

-- 	for i = 0, num_points * 2 - 1 do
-- 		local angle = rotation + (i * angle_step)
-- 		local radius = (i % 2 == 0) and outer_radius or inner_radius
-- 		table.insert(points, polarToVec2(angle, radius))
-- 	end

-- 	if border then
-- 		draw_list:AddCircle(center, outer_radius, ImGui.GetColorU32(0.1, 0.1, 0.1, 0.4), 32, 2)
-- 	end

-- 	draw_list:AddConvexPolyFilled(points, star_color)
-- end

---@param draw_list ImDrawList to draw to
---@param pos ImVec2 Top-left position (of moon)
---@param size number Size of the moon (diameter)
---@param col ImU32 Color
---@param bg_color ImVec4 Background color (shadow color)
---@param rotation number Optional rotation in radians
---@param border boolean Optional border flag (default false)
function CommonUtils.RenderMoon(draw_list, pos, size, col, bg_color, rotation, border)
	local outer_radius = size * 0.5
	local center = ImVec2(pos.x + outer_radius, pos.y + outer_radius)


	-- Draw big circle (moon body)
	draw_list:AddCircleFilled(center, outer_radius, col, 32)

	-- Cutout crescent: black first
	local offset = outer_radius * 0.6
	local cutout_center = ImVec2(center.x + offset, center.y)

	-- Apply rotation if specified
	if rotation and rotation ~= 0 then
		cutout_center = CommonUtils.RotatePoint(cutout_center, center, rotation)
	end

	draw_list:AddCircleFilled(
		cutout_center,
		outer_radius,
		ImGui.GetColorU32(0, 0, 0, 1),
		32
	)

	-- Overlay semi-transparent bg color
	draw_list:AddCircleFilled(
		cutout_center,
		outer_radius,
		ImGui.GetColorU32(bg_color),
		32
	)
	if border then
		draw_list:AddCircle(center, outer_radius, ImGui.GetColorU32(0.1, 0.1, 0.1, 0.5), 32, 2)
	end
end

--[[
	* DrawToggle
	* A toggle button that can be used to switch between two states (on/off) (true\false).
	* It can also display a star or moon shape as the knob.
	* The function takes various parameters to customize its appearance and behavior.
	* The function returns the updated value of the toggle and whether it was clicked.
	* some Flags you can pass in are ImGuiToggleFlags.StarKnob, ImGuiToggleFlags.RightLabel, ImGuiToggleFlags.AnimateKnob
	* The function also supports custom colors for the toggle button and knob.
	* The function can also animate the knob (roatating stars or a rocking moon).
	* The function can also display a label on the right side of the toggle button.
	* The function can also set the size of the toggle button (width, height) or just height and width will be defaulted to height * 2.0
	* The function can also set the number of points for the star knob (default 5).
	]]
---@param id string Label and Id for the toggle button) clicking the label or the toggle will toggle the value
---@param value boolean Current value of the toggle button
---@param flags integer|nil combined bit flags (ImGuiToggleFlags.None, ImGuiToggleFlags.StarKnob, ImGuiToggleFlags.RightLabel, ImGuiToggleFlags.AnimateKnob)
---@param size ImVec2|number|nil -- ImVec2 Size of the toggle button (width, height) or height value if single number and width will default to height * 2.0
---@param on_color ImVec4|integer|nil Color for ON state, or number of points if passing star points
---@param off_color ImVec4|integer|nil ImVec4 Color for the Toggle when Off , or number of points if passing star points
---@param knob_color ImVec4|integer|nil ImVec4 Color for the Knob , or its the number of points if passing star points
---@param num_points integer|nil the number of points for the star knob (default 5)
---@return boolean value
---@return boolean clicked
function CommonUtils.DrawToggle(id, value, flags, size, on_color, off_color, knob_color, num_points)
	if not id or value == nil then return false, false end
	-- setup any defaults for mising params
	size = type(size) == 'number' and ImVec2(size * 2, size) or size or ImVec2(32, 16)
	local height = size.y or 16
	local width = size.x or height * 2
	-- if you omit a color you can still pass the number as the number of points
	if type(on_color) == 'number' then
		num_points = on_color
		on_color = nil
	elseif type(off_color) == 'number' then
		num_points = off_color
		off_color = nil
	elseif type(knob_color) == 'number' then
		num_points = knob_color
		knob_color = nil
	end

	on_color = on_color or ImGui.GetStyleColorVec4(ImGuiCol.FrameBgActive)
	off_color = off_color or ImGui.GetStyleColorVec4(ImGuiCol.FrameBg)
	knob_color = knob_color or ImVec4(1, 1, 1, 1) -- default white

	local star_knob = flags and bit32.band(flags, CommonUtils.ImGuiToggleFlags.StarKnob) ~= 0
	local right_label = flags and bit32.band(flags, CommonUtils.ImGuiToggleFlags.RightLabel) ~= 0
	local animate_knob = flags and bit32.band(flags, CommonUtils.ImGuiToggleFlags.AnimateKnob) ~= 0
	local smily_knob = flags and bit32.band(flags, CommonUtils.ImGuiToggleFlags.SmilyKnob) ~= 0
	local glow_on_hover = flags and bit32.band(flags, CommonUtils.ImGuiToggleFlags.GlowOnHover) ~= 0
	local animate_on_hover = flags and bit32.band(flags, CommonUtils.ImGuiToggleFlags.AnimateOnHover) ~= 0
	local pulse_on_hover = flags and bit32.band(flags, CommonUtils.ImGuiToggleFlags.PulseOnHover) ~= 0
	local knob_border = flags and bit32.band(flags, CommonUtils.ImGuiToggleFlags.KnobBorder) ~= 0

	if smily_knob then
		star_knob = false
	end

	num_points = num_points or 5

	-- pull the label from the ID if there is one
	local label = id:match("^(.-)##") -- Capture text before ##

	-- if there was no "##" then to separate the ID from the lable then use the ID as the label
	if not id:find("##") then -- no ID tag so the id is the label
		label = id
	end
	local clicked = false

	if not right_label and label and label ~= "" then
		ImGui.Text(string.format("%s:", label))
		if ImGui.IsItemClicked() then
			value = not value
			clicked = true
		end
		ImGui.SameLine()
	end

	local draw_list = ImGui.GetWindowDrawList()
	local pos = { x = 0, y = 0, }
	pos.x, pos.y = ImGui.GetCursorScreenPos()
	local radius = height * 0.5

	-- clickable area
	ImGui.InvisibleButton(id, width, height)
	if ImGui.IsItemClicked() then
		value = not value
		clicked = true
	end

	-- detect hovering for applying hover effects
	local is_hovered = ImGui.IsItemHovered()
	local should_animate = animate_knob or (animate_on_hover and is_hovered)
	local final_knob_col = ImGui.GetColorU32(knob_color)

	if pulse_on_hover and is_hovered then
		local pulse_strength = 0.5 + 0.5 * math.sin(os.clock() * 4)
		if knob_color.x == 1 and knob_color.y == 1 and knob_color.z == 1 then
			-- Special case: white glows warm yellow
			local new_color = ImVec4(
				1,
				math.min(1, 1 - 0.2 * pulse_strength),
				math.min(1, 1 - 0.4 * pulse_strength),
				knob_color.w
			)
			final_knob_col = ImGui.GetColorU32(new_color)
		else
			local new_color = ImVec4(
				math.min(1, knob_color.x + pulse_strength * 0.4),
				math.min(1, knob_color.y + pulse_strength * 0.4),
				math.min(1, knob_color.z + pulse_strength * 0.4),
				knob_color.w
			)
			final_knob_col = ImGui.GetColorU32(new_color)
		end
	end

	local t = value and 1.0 or 0.0
	local knob_x = pos.x + radius + t * (width - height)
	local center = ImVec2(knob_x, pos.y + radius)
	local fill_radius = radius * 0.8
	-- Background
	draw_list:AddRectFilled(
		ImVec2(pos.x, pos.y),
		ImVec2(pos.x + width, pos.y + height),
		ImGui.GetColorU32(value and on_color or off_color),
		height * 0.5
	)

	if star_knob then
		if value then
			local star_rotation = os.clock() * 1.5 -- spinning speed
			if not should_animate then
				star_rotation = 0
			end
			CommonUtils.RenderStar(
				draw_list,
				ImVec2(knob_x - fill_radius, pos.y + radius - fill_radius),
				radius * 1.6,
				final_knob_col,
				star_rotation,
				num_points,
				knob_border)
		else
			local moon_rotation = math.sin(os.clock() * 2) * (math.pi / 18)
			if not should_animate then
				moon_rotation = 0
			end
			CommonUtils.RenderMoon(draw_list, ImVec2(knob_x - fill_radius, pos.y + radius - fill_radius), radius * 1.6,
				final_knob_col, off_color, moon_rotation, knob_border)
		end
	elseif smily_knob then
		-- smily or froown based on value
		CommonUtils.RenderSmiley(draw_list, ImVec2(knob_x - fill_radius, pos.y + radius - fill_radius), radius * 1.6,
			final_knob_col, value)
	else
		-- Knob (circle) -- default circle toggle
		local radiusOutline = radius * 0.85

		draw_list:AddCircleFilled(
			center,
			fill_radius,
			final_knob_col,
			0
		)
		-- Draw outline
		if knob_border then
			draw_list:AddCircle(center, fill_radius, ImGui.GetColorU32(0, 0, 0, 1), 32, 2)
		end
	end

	-- apply any glow over the knob on hover
	if glow_on_hover and is_hovered then
		CommonUtils.DrawGlowAura(draw_list, center, fill_radius, knob_color)
	end

	-- Label on the right side of the toggle
	if right_label and label and label ~= "" then
		ImGui.SameLine()
		ImGui.Text(string.format("%s", label))
		if ImGui.IsItemClicked() then
			value = not value
			clicked = true
		end
	end

	return value, clicked
end

---@param draw_list ImDrawList
---@param pos ImVec2 Top-left position (for face center calculation)
---@param size number Diameter of face
---@param col ImU32 Color for face fill
---@param value boolean Value of the toggle (true for smiley, false for frown)
function CommonUtils.RenderSmiley(draw_list, pos, size, col, value)
	local center = ImVec2(pos.x + size * 0.5, pos.y + size * 0.5)
	local radius = size * 0.5

	-- Draw face color inside
	draw_list:AddCircleFilled(center, radius * 0.9, col, 32)

	-- Eyes
	local eye_offset_x = radius * 0.4
	local eye_offset_y = radius * 0.3
	local eye_radius = radius * 0.1

	draw_list:AddCircleFilled(ImVec2(center.x - eye_offset_x, center.y - eye_offset_y), eye_radius, ImGui.GetColorU32(0, 0, 0, 1), 12)
	draw_list:AddCircleFilled(ImVec2(center.x + eye_offset_x, center.y - eye_offset_y), eye_radius, ImGui.GetColorU32(0, 0, 0, 1), 12)

	-- Mouth (smile)
	local mouth_radius = radius * 0.6
	local mouth_center = ImVec2(center.x, center.y + radius * 0.2)

	if not value then
		-- Mouth (frown)
		mouth_center = ImVec2(center.x, center.y + radius * 0.8) -- Move center *lower* for frown
		draw_list:PathArcTo(mouth_center, mouth_radius * 0.5, math.pi * 1.25, math.pi * 1.75, 16)
	else
		-- Smiling arc (bottom half circle) kinda
		draw_list:PathArcTo(mouth_center, mouth_radius * 0.5, math.pi * 0.25, math.pi * 0.75, 16)
	end

	draw_list:PathStroke(ImGui.GetColorU32(0, 0, 0, 1), ImDrawFlags.RoundCornersAll, radius * 0.08)
	-- Draw black outline
	draw_list:AddCircle(center, radius * 0.9, ImGui.GetColorU32(0, 0, 0, 1), 32, 2)
end

---

---@param draw_list ImDrawList
---@param pos ImVec2 Top-left position
---@param size number
---@param col ImU32
function CommonUtils.RenderFrown(draw_list, pos, size, col)
	local center = ImVec2(pos.x + size * 0.5, pos.y + size * 0.5)
	local radius = size * 0.5

	-- Outline might apply this to the default circle toggle as well not sure though.
	-- draw_list:AddCircleFilled(center, radius, ImGui.GetColorU32(0, 0, 0, 1), 32)
	draw_list:AddCircleFilled(center, radius * 0.9, col, 32)

	-- Eyes
	local eye_offset_x = radius * 0.4
	local eye_offset_y = radius * 0.3
	local eye_radius = radius * 0.1

	draw_list:AddCircleFilled(ImVec2(center.x - eye_offset_x, center.y - eye_offset_y), eye_radius, ImGui.GetColorU32(0, 0, 0, 1), 12)
	draw_list:AddCircleFilled(ImVec2(center.x + eye_offset_x, center.y - eye_offset_y), eye_radius, ImGui.GetColorU32(0, 0, 0, 1), 12)

	-- Mouth (frown)
	local mouth_radius = radius * 0.6
	local mouth_center = ImVec2(center.x, center.y + radius * 0.8) -- Move center *lower* for frown

	-- Frown arc (top of a circle pointing down) hard to see if small but scales nicely
	draw_list:PathArcTo(mouth_center, mouth_radius * 0.5, math.pi * 1.25, math.pi * 1.75, 16)
	draw_list:PathStroke(ImGui.GetColorU32(0, 0, 0, 1), ImDrawFlags.RoundCornersAll, radius * 0.08)
	draw_list:AddCircle(center, radius, ImGui.GetColorU32(0, 0, 0, 1), 32, 2)
end

-- Glow Aura
---@param draw_list ImDrawList
---@param center ImVec2 Center position (knob center)
---@param base_radius number Base radius of the knob
---@param base_color ImVec4 Base color of the knob
---@param time_offset number|nil Optional clock offset for breathing
function CommonUtils.DrawGlowAura(draw_list, center, base_radius, base_color, time_offset)
	time_offset = time_offset or 0
	local t = (os.clock() + time_offset) * 2
	local breathe = 0.5 + 0.5 * math.sin(t)

	-- Adjust alpha separately for inner/outer glow
	local aura_color_inner = ImVec4(
		base_color.x,
		base_color.y,
		base_color.z,
		0.3 * breathe

	)
	local aura_color_outer = ImVec4(
		base_color.x,
		base_color.y,
		base_color.z,
		0.2 * breathe * breathe * (3 - 2 * breathe)
	)

	-- Glow expands outward
	local glow_radius_inner = base_radius * 1.2
	local glow_radius_outer = base_radius * 1.6

	-- Draw the outer softer aura first
	draw_list:AddCircleFilled(
		center,
		glow_radius_outer,
		ImGui.GetColorU32(aura_color_outer),
		32
	)

	-- Then a stronger inner glow
	draw_list:AddCircleFilled(
		center,
		glow_radius_inner,
		ImGui.GetColorU32(aura_color_inner),
		32
	)
end

function CommonUtils.GetBreathingColor(base_color, do_breathe)
	if not do_breathe then
		return base_color
	end
	-- If the incoming color is white or black, return it unchanged
	if (base_color.x == 1 and base_color.y == 1 and base_color.z == 1) or
		(base_color.x == 0 and base_color.y == 0 and base_color.z == 0) then
		return base_color
	end

	local t = os.clock() * 2
	local breathe = 0.5 + 0.5 * math.sin(t)
	local highest = math.max(base_color.x, base_color.y, base_color.z)

	-- small amplitude of breathing (how much it shifts)
	local breatheAmount = 0.4

	local function breatheChannel(base, isDominant)
		if isDominant then
			-- is base is 0.9 or higher then we lower the base value
			-- if base is 0.1 or lower then we raise the base value
			if base >= 0.9 then
				base = base - 0.1
			elseif base <= 0.1 then
				base = base + 0.1
			end
			-- breathe slightly above and below the base value
			return math.min(1.0, math.max(0.0, base + (breathe - 0.5) * 2.0 * breatheAmount))
		else
			return base
		end
	end

	local r = breatheChannel(base_color.x, highest == base_color.x)
	local g = breatheChannel(base_color.y, highest == base_color.y)
	local b = breatheChannel(base_color.z, highest == base_color.z)
	local a = base_color.w

	return ImVec4(r, g, b, a)
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

function CommonUtils.GetNextID(table)
	local maxID = 0
	for k, _ in pairs(table) do
		local numericId = tonumber(k)
		if numericId and numericId > maxID then
			maxID = numericId
		end
	end
	return maxID + 1
end

---@param input_table table|nil  the table to sort (optional) You can send a set of sorted keys if you have already custom sorted it.
---@param sorted_keys table|nil  the sorted keys table (optional) if you have already sorted the keys
---@param num_columns integer  the number of column groups to sort the keys into
---@return table
function CommonUtils.SortTableColumns(input_table, sorted_keys, num_columns)
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
	local base_rows = math.floor(total_items / num_columns) -- Base number of rows per column
	local extra_rows = total_items % num_columns         -- Number of columns that need an extra row

	local column_sorted = {}
	local column_entries = {}

	-- Precompute how many rows each column gets
	local start_index = 1
	for col = 1, num_columns do
		local rows_in_col = base_rows + (col <= extra_rows and 1 or 0)
		column_entries[col] = {}

		-- Assign keys to their respective columns
		for row = 1, rows_in_col do
			if start_index <= total_items then
				table.insert(column_entries[col], keys[start_index])
				start_index = start_index + 1
			end
		end
	end

	-- Rearrange into the final sorted order, maintaining column-first layout
	local max_rows = base_rows + (extra_rows > 0 and 1 or 0)
	for row = 1, max_rows do
		for col = 1, num_columns do
			if column_entries[col][row] then
				table.insert(column_sorted, column_entries[col][row])
			end
		end
	end

	return column_sorted
end

function CommonUtils.SortKeys(input_table)
	local keys = {}
	for k, _ in pairs(input_table) do
		table.insert(keys, k)
	end

	table.sort(keys) -- Sort the keys
	return keys
end

function CommonUtils.Deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[CommonUtils.Deepcopy(orig_key)] = CommonUtils.Deepcopy(orig_value)
		end
		setmetatable(copy, CommonUtils.Deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
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
	if target_id == nil then return end
	mq.cmdf("/target id %s", target_id)
	if mq.TLO.Cursor() or mq.TLO.Me.CursorPlatinum() > 0 or mq.TLO.Me.CursorGold() > 0 or mq.TLO.Me.CursorSilver() > 0 or mq.TLO.Me.CursorCopper() > 0 then
		mq.cmdf('/multiline ; /tar id %s; /timed 5, /click left target', target_id)
	end
end

function CommonUtils.MaskName(name)
	local maskedName = name
	if maskedName ~= nil then
		maskedName = maskedName:gsub("([A-Za-z])", "X")
	end
	return maskedName
end

-- Animation

---comment
---@param textureMap MQTexture the texture map to draw from
---@param rowNum integer the row number to draw from (0-7)
---@param colNum integer the column number to draw from (0-3) there are 8 columns but we offset to get to the last 4. Any animation uses 4 cells at most.
---@param colPerAnimation integer the number of columns per animation
---@param spriteSheetSize integer the size of the sprite sheet
---@param frameWidth integer the width of the frame
---@param frameHeight integer the height of the frame
---@param imgSize integer the size of the image to draw
---@param isOffset boolean if true we will offset the column number by rightOffset
---@param rightOffset integer the offset to apply to the column number
---@param cursorX integer the x position to draw the image at
---@param cursorY integer the y position to draw the image at
function CommonUtils.DrawAnimatedFrame(textureMap, rowNum, colNum, colPerAnimation, spriteSheetSize, frameWidth, frameHeight, imgSize, isOffset, rightOffset, cursorX, cursorY)
	local genderOffset = isOffset and rightOffset or 0

	local col = (colNum % colPerAnimation) + genderOffset

	-- Normalize UVs
	local u1 = (col * frameWidth) / spriteSheetSize
	local v1 = (rowNum * frameHeight) / spriteSheetSize
	local u2 = ((col + 1) * frameWidth) / spriteSheetSize
	local v2 = ((rowNum + 1) * frameHeight) / spriteSheetSize

	if textureMap then
		ImGui.Image(textureMap:GetTextureID(), ImVec2(imgSize, imgSize), ImVec2(u1, v1), ImVec2(u2, v2))
	end
	ImGui.SetCursorPos(cursorX, cursorY)
end

function CommonUtils.directions(heading)
	-- convert headings from letter values to degrees
	local dirToDeg = {
		N = 0,
		NEN = 22.5,
		NE = 45,
		ENE = 67.5,
		E = 90,
		ESE = 112.5,
		SE = 135,
		SES = 157.5,
		S = 180,
		SWS = 202.5,
		SW = 225,
		WSW = 247.5,
		W = 270,
		WNW = 292.5,
		NW = 315,
		NWN = 337.5,
	}
	return dirToDeg[heading] or 0 -- Returns the degree value for the given direction, defaulting to 0 if not found
end

-- Tighter relative direction code for when I make better arrows.
function CommonUtils.getRelativeDirection(spawnDir)
	local meHeading = CommonUtils.directions(mq.TLO.Me.Heading())
	local spawnHeadingTo = CommonUtils.directions(spawnDir)
	local difference = spawnHeadingTo - meHeading
	difference = (difference + 360) % 360
	return difference
end

-- function CommonUtils.RotatePoint(p, cx, cy, degAngle)
-- 	local radians = math.rad(degAngle)
-- 	local cosA = math.cos(radians)
-- 	local sinA = math.sin(radians)
-- 	local newX = cosA * (p.x - cx) - sinA * (p.y - cy) + cx
-- 	local newY = sinA * (p.x - cx) + cosA * (p.y - cy) + cy
-- 	return ImVec2(newX, newY)
-- end

--- Function to rotate aa point around a center point by a given angle
---@param point ImVec2 Point Coordinates
---@param center ImVec2 Center Coordinates to rotate around
---@param angle number Angle in radians to roatate the point
---@return ImVec2 -- New point cooridnates after rotating
function CommonUtils.RotatePoint(point, center, angle)
	local s = math.sin(angle)
	local c = math.cos(angle)
	local dx = point.x - center.x
	local dy = point.y - center.y
	return ImVec2(
		center.x + (dx * c - dy * s),
		center.y + (dx * s + dy * c)
	)
end

function CommonUtils.DrawArrow(topPoint, width, height, color, angle)
	local draw_list = ImGui.GetWindowDrawList()
	local p1 = ImVec2(topPoint.x, topPoint.y)
	local p2 = ImVec2(topPoint.x + width, topPoint.y + height)
	local p3 = ImVec2(topPoint.x - width, topPoint.y + height)
	-- center
	local center_x = (p1.x + p2.x + p3.x) / 3
	local center_y = (p1.y + p2.y + p3.y) / 3
	-- rotate
	angle = angle + .01
	p1 = CommonUtils.RotatePoint(p1, ImVec2(center_x, center_y), angle)
	p2 = CommonUtils.RotatePoint(p2, ImVec2(center_x, center_y), angle)
	p3 = CommonUtils.RotatePoint(p3, ImVec2(center_x, center_y), angle)
	draw_list:AddTriangleFilled(p1, p2, p3, ImGui.GetColorU32(color))
end

---comment
---@param distance integer  the distance to check the color for
---@param range_orange integer|nil  the distance the color changes from green to orange default (600)
---@param range_red integer|nil  the distance the color changes from orange to red default (1200)
---@return ImVec4 color returns the color as an ImVec4
function CommonUtils.ColorDistance(distance, range_orange, range_red)
	local DistColorRanges = {
		orange = range_orange or 600, -- distance the color changes from green to orange
		red = range_red or 1200, -- distance the color changes from orange to red
	}
	if distance < DistColorRanges.orange then
		-- Green color for Close Range
		return CommonUtils.Colors.color('green')
	elseif distance >= DistColorRanges.orange and distance <= DistColorRanges.red then
		-- Orange color for Mid Range
		return CommonUtils.Colors.color('orange')
	else
		-- Red color for Far Distance
		return CommonUtils.Colors.color('red')
	end
end

return CommonUtils
