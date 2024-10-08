--[[
	Created by Special.Ed
	Shout out to the homies:
	Lads
	Dannuic (my on again off again thing)
	Knightly (no, i won't take that bet)
--]]
--[[
	Modified by Grimmier
	Added a GUI and commands.
	** Commands **
	* /am show will toggle the search window.
	* /am popup will toggle the alert popup window.
	** Search Window **
	* You can search with the search box
	* Clicking the check box for track, and the spawn will be added to spawnlist
	* Clicking ignore will remove the spawn from the list if it exists.
	* you can navTo any spawn in the search window by clicking the button, rightclicking the name will target the spawn.
	** Alert Window **
	* The Alert Popup Window lists the spawns that you are tracking and are alive. Shown as "Name : Distance"
	* Clicking the button on the Alert Window will NavTo the spawn.
	* Closing the Alert Popup will keep it closed until something changes or your remind timer is up.
	* remind setting is in minutes.
]]
local LIP = require('lib.lip')
local mq = require('mq')
local ImGui = require('ImGui')
Module = {}
Module.Name = 'AlertMaster'
Module.Path = MyUI_Path ~= nil and MyUI_Path or string.format("%s/%s/", mq.luaDir, Module.Name)
Module.SoundPath = string.format("%s/sounds/default/", Module.Path)

---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false
if not loadedExeternally then
	MyUI_Utils      = require('lib.common')
	MyUI_CharLoaded = mq.TLO.Me.DisplayName()
	MyUI_Colors     = require('lib.colors')
	MyUI_Guild      = mq.TLO.Me.Guild()
	MyUI_Icons      = require('mq.ICONS')
end

-- Variables
local arg = { ..., }
local amVer = '2.07'
local SpawnCount = mq.TLO.SpawnCount
local NearestSpawn = mq.TLO.NearestSpawn
local smSettings = mq.configDir .. '/MQ2SpawnMaster.ini'
local config_dir = mq.TLO.MacroQuest.Path():gsub('\\', '/')
local settings_file = '/config/AlertMaster.ini'
local settings_path = config_dir .. settings_file
local smImportList = mq.configDir .. '/am_imports.lua'
local Group = mq.TLO.Group
local Raid = mq.TLO.Raid
local Zone = mq.TLO.Zone
local groupCmd = '/dgae ' -- assumes DanNet, if EQBC found we switch to '/bcca /'
local angle = 0
local CharConfig = 'Char_' .. mq.TLO.Me.DisplayName() .. '_Config'
local CharCommands = 'Char_' .. mq.TLO.Me.DisplayName() .. '_Commands'
local defaultConfig = { delay = 1, remindNPC = 5, remind = 30, aggro = false, pcs = true, spawns = true, gms = true, announce = false, ignoreguild = true, beep = false, popup = false, distmid = 600, distfar = 1200, locked = false, }
local tSafeZones, spawnAlerts, spawnsSpawnMaster, settings = {}, {}, {}, {}
local npcs, tAnnounce, tPlayers, tSpawns, tGMs = {}, {}, {}, {}, {}
local alertTime, numAlerts = 0, 0
local volNPC, volGM, volPC, volPCEntered, volPCLeft = 100, 100, 100, 100, 100
local zone_id = Zone.ID() or 0
local soundGM = 'GM.wav'
local soundNPC = 'NPC.wav'
local soundPC = 'PC.wav'
local soundPCEntered = 'PCEntered.wav'
local soundPCLeft = 'PCLeft.wav'
local doBeep, doAlert, DoDrawArrow, haveSM, importZone, doSoundNPC, doSoundGM, doSoundPC, forceImport, doSoundPCEntered, doSoundPCLeft = false, false, false, false, false, false,
	false, false, false, false, false
local delay, remind, pcs, spawns, gms, announce, ignoreguild, radius, zradius, remindNPC, showAggro = 1, 30, true, true, true, false, true, 100, 100, 5, true
-- [[ UI ]] --
local AlertWindow_Show, AlertWindowOpen, SearchWindowOpen, SearchWindow_Show, showTooltips, active = false, false, false, false, true, false
local currentTab = "zone"
local newSpawnName = ''
local zSettings = false
local theme = require('defaults.themes')
local useThemeName = 'Default'
local openConfigGUI = false
local themeFile = mq.configDir .. '/MyThemeZ.lua'
local ZoomLvl = 1.0
local doOnce = true
local ColorCountAlert, ColorCountConf, StyleCountConf, StyleCountAlert = 0, 0, 0, 0
local importedZones = {}
local originalVolume = 50
local playTime = 0
local playing = false
local currZone, lastZone

local DistColorRanges = {
	orange = 600, -- distance the color changes from green to orange
	red = 1200, -- distance the color changes from orange to red
}

local Table_Cache = {
	Rules = {},
	Unhandled = {},
	Mobs = {},
	Alerts = {},
}

local xTarTable = {}
local spawnListFlags = bit32.bor(
	ImGuiTableFlags.Resizable,
	ImGuiTableFlags.Sortable,
	-- ImGuiTableFlags.SizingFixedFit,
	ImGuiTableFlags.BordersV,
	ImGuiTableFlags.BordersOuter,
	ImGuiTableFlags.Reorderable,
	ImGuiTableFlags.ScrollY,
	ImGuiTableFlags.ScrollX,
	ImGuiTableFlags.Hideable
)
Module.IsRunning = false
Module.GUI_Main = {
	Open    = false,
	Show    = false,
	Locked  = false,
	Flags   = bit32.bor(
		ImGuiWindowFlags.None,
		ImGuiWindowFlags.MenuBar
	--ImGuiWindowFlags.NoSavedSettings
	),
	Refresh = {
		Sort = {
			Rules     = true,
			Filtered  = true,
			Unhandled = true,
			Mobs      = false,
		},
		Table = {
			Rules     = true,
			Filtered  = true,
			Unhandled = true,
			Mobs      = false,
		},
	},
	Search  = '',
	Table   = {
		Column_ID = {
			ID           = 1,
			MobName      = 2,
			MobDirtyName = 3,
			MobLoc       = 4,
			MobZoneName  = 5,
			MobDist      = 6,
			MobID        = 7,
			Action       = 8,
			Remove       = 9,
			MobLvl       = 10,
			MobConColor  = 11,
			MobAggro     = 12,
			MobDirection = 13,
			Enum_Action  = 14,
		},
		Flags = bit32.bor(
			ImGuiTableFlags.Resizable,
			ImGuiTableFlags.Sortable,
			--ImGuiTableFlags.RowBg,
			--ImGuiTableFlags.NoKeepColumnsVisible,
			--ImGuiTableFlags.SizingFixedFit,
			-- ImGuiTableFlags.MultiSortable, -- MultiSort seems to not work at all.
			ImGuiTableFlags.NoBordersInBodyUntilResize,
			--ImGuiTableFlags.BordersOuter,
			ImGuiTableFlags.Reorderable,
			ImGuiTableFlags.ScrollY,
			ImGuiTableFlags.ScrollX,
			ImGuiTableFlags.Hideable
		),
		SortSpecs = {
			Rules     = nil,
			Unhandled = nil,
			Filtered  = nil,
			Mobs      = nil,
		},
	},
}

Module.GUI_Alert = {
	Open    = false,
	Show    = false,
	Locked  = false,
	Flags   = bit32.bor(ImGuiWindowFlags.NoCollapse),
	Refresh = {
		Sort = {
			Rules     = true,
			Filtered  = true,
			Unhandled = true,
			Mobs      = false,
			Alerts    = true,
		},
		Table = {
			Rules     = true,
			Filtered  = true,
			Unhandled = true,
			Mobs      = false,
			Alerts    = true,
		},
	},
	Table   = {
		Column_ID = {
			ID           = 1,
			MobName      = 2,
			MobDist      = 3,
			MobID        = 4,
			MobDirection = 5,
		},
		Flags = bit32.bor(
			ImGuiTableFlags.Resizable,
			ImGuiTableFlags.Sortable,
			ImGuiTableFlags.SizingFixedFit,
			ImGuiTableFlags.BordersV,
			ImGuiTableFlags.BordersOuter,
			ImGuiTableFlags.Reorderable,
			ImGuiTableFlags.ScrollY,
			ImGuiTableFlags.ScrollX,
			ImGuiTableFlags.Hideable
		),
		SortSpecs = {
			Rules     = nil,
			Unhandled = nil,
			Filtered  = nil,
			Mobs      = nil,
			Alerts    = nil,
		},
	},
}
------- Sounds ----------
local ffi = require("ffi")
-- C code definitions
ffi.cdef [[
int sndPlaySoundA(const char *pszSound, unsigned int fdwSound);
uint32_t waveOutSetVolume(void* hwo, uint32_t dwVolume);
uint32_t waveOutGetVolume(void* hwo, uint32_t* pdwVolume);
]]

local winmm = ffi.load("winmm")

local SND_ASYNC = 0x0001
local SND_LOOP = 0x0008
local SND_FILENAME = 0x00020000
local flags = SND_FILENAME + SND_ASYNC

local function getVolume()
	local pdwVolume = ffi.new("uint32_t[1]")
	winmm.waveOutGetVolume(nil, pdwVolume)
	return pdwVolume[0]
end

local function resetVolume()
	winmm.waveOutSetVolume(nil, originalVolume)
	playTime = 0
	playing = false
end

-- Function to play sound allowing for simultaneous plays
local function playSound(name)
	local filename = Module.SoundPath .. name
	playTime = os.time()
	playing = true
	winmm.sndPlaySoundA(filename, flags)
end

-- Function to set volume (affects all sounds globally)
local function setVolume(volume)
	if volume < 0 or volume > 100 then
		error("Volume must be between 0 and 100")
	end
	local vol = math.floor(volume / 100 * 0xFFFF)
	local leftRightVolume = bit32.bor(bit32.lshift(vol, 16), vol) -- Set both left and right volume
	winmm.waveOutSetVolume(nil, leftRightVolume)
end
-- helpers
local MsgPrefix = function() return string.format('\aw[\a-tAlert Master\aw] ::\ax ') end

local GetCharZone = function()
	return '\aw[\ao' .. MyUI_CharLoaded .. '\aw] [\at' .. Zone.ShortName() .. '\aw] '
end

local function print_status()
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayAlert Status: ' .. tostring(active and 'on' or 'off'))
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tPCs: \a-y' ..
		tostring(pcs) ..
		'\ax radius: \a-y' .. tostring(radius) .. '\ax zradius: \a-y' .. tostring(zradius) .. '\ax delay: \a-y' .. tostring(delay) ..
		's\ax remind: \a-y' .. tostring(remind) .. ' seconds\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tremindNPC: \a-y' .. tostring(remindNPC) .. '\at minutes\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\agClose Range\a-t Below: \a-g' .. tostring(DistColorRanges.orange) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\aoMid Range\a-t Between: \a-g' .. tostring(DistColorRanges.orange) .. '\a-t and \a-r' .. tostring(DistColorRanges.red) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\arLong Rage\a-t Greater than: \a-r' .. tostring(DistColorRanges.red) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tAnnounce PCs: \a-y' .. tostring(announce) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tSpawns (zone wide): \a-y' .. tostring(spawns) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tGMs (zone wide): \a-y' .. tostring(gms) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tPopup Alerts: \a-y' .. tostring(doAlert) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tBeep: \a-y' .. tostring(doBeep) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tSound PC Alerts: \a-y' .. tostring(doSoundPC) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tSound NPC Alerts: \a-y' .. tostring(doSoundNPC) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tSound GM Alerts: \a-y' .. tostring(doSoundGM) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tVolume PC Alerts: \a-y' .. tostring(volPC) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tVolume NPC Alerts: \a-y' .. tostring(volNPC) .. '\ax')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-tVolume GM Alerts: \a-y' .. tostring(volGM) .. '\ax')
end

local save_settings = function()
	LIP.save(settings_path, settings)
end

local check_safe_zone = function()
	return tSafeZones[Zone.ShortName()]
end

local function import_spawnmaster(val)
	local zoneShort = Zone.ShortName()
	local val_str = tostring(val):gsub("\"", "")
	if zoneShort ~= nil then
		local flag = true -- assume we are adding a new spawn
		local count = 0
		if settings[zoneShort] == nil then settings[zoneShort] = {} end
		-- if the zone does exist in the ini, spin over entries and make sure we aren't duplicating
		for k, v in pairs(settings[zoneShort]) do
			if string.find(v, val_str) then
				flag = false
			end
			if flag then
				count = count + 1
			end
		end

		importedZones[zoneShort] = true
		-- if we made it this far, the spawn isn't tracked -- add it to the table and store to ini
		if flag then
			settings[zoneShort]['Spawn' .. count + 1] = val_str
			save_settings()
		end
		return flag
	end
end

local function load_settings()
	if MyUI_Utils.File.Exists(settings_path) then
		settings = LIP.load(settings_path)
	else
		settings = {
			[CharConfig] = defaultConfig,
			[CharCommands] = {},
			Ignore = {},
		}
		save_settings()
	end
	if MyUI_Utils.File.Exists(themeFile) then
		theme = dofile(themeFile)
	end

	if MyUI_Utils.File.Exists(smSettings) then
		spawnsSpawnMaster = LIP.loadSM(smSettings)
		haveSM = true
		importZone = true
	end

	if MyUI_Utils.File.Exists(smImportList) then
		importedZones = dofile(smImportList)
	end

	useThemeName = theme.LoadTheme
	-- if this character doesn't have the sections in the ini, create them
	if settings[CharConfig] == nil then settings[CharConfig] = defaultConfig end
	if settings[CharCommands] == nil then settings[CharCommands] = {} end
	if settings['SafeZones'] == nil then settings['SafeZones'] = {} end
	useThemeName = settings[CharConfig]['theme'] or 'Default'
	settings[CharConfig]['theme'] = useThemeName
	ZoomLvl = settings[CharConfig]['ZoomLvl'] or 1.0
	settings[CharConfig]['ZoomLvl'] = ZoomLvl
	delay = settings[CharConfig]['delay']
	remind = settings[CharConfig]['remind']
	pcs = settings[CharConfig]['pcs']
	spawns = settings[CharConfig]['spawns']
	gms = settings[CharConfig]['gms']
	announce = settings[CharConfig]['announce']
	ignoreguild = settings[CharConfig]['ignoreguild']
	radius = settings[CharConfig]['radius'] or radius
	settings[CharConfig]['radius'] = radius
	zradius = settings[CharConfig]['zradius'] or zradius
	settings[CharConfig]['zradius'] = zradius
	remindNPC = settings[CharConfig]['remindNPC'] or 5
	settings[CharConfig]['remindNPC'] = remindNPC
	doBeep = settings[CharConfig]['beep'] or false
	settings[CharConfig]['beep'] = doBeep
	DoDrawArrow = settings[CharConfig]['arrows'] or false
	settings[CharConfig]['arrows'] = DoDrawArrow
	Module.GUI_Main.Locked = settings[CharConfig]['locked'] or false
	settings[CharConfig]['locked'] = Module.GUI_Main.Locked
	doAlert = settings[CharConfig]['popup'] or false
	settings[CharConfig]['popup'] = doAlert
	showAggro = settings[CharConfig]['aggro'] or false
	settings[CharConfig]['aggro'] = showAggro
	DistColorRanges.orange = settings[CharConfig]['distmid'] or 600
	settings[CharConfig]['distmid'] = DistColorRanges.orange
	DistColorRanges.red = settings[CharConfig]['distfar'] or 1200
	settings[CharConfig]['distfar'] = DistColorRanges.red
	doSoundGM = settings[CharConfig]['doSoundGM'] or false
	settings[CharConfig]['doSoundGM'] = doSoundGM
	doSoundNPC = settings[CharConfig]['doSoundNPC'] or false
	settings[CharConfig]['doSoundNPC'] = doSoundNPC
	doSoundPC = settings[CharConfig]['doSoundPC'] or false
	settings[CharConfig]['doSoundPC'] = doSoundPC
	volGM = settings[CharConfig]['volGM'] or volGM
	settings[CharConfig]['volGM'] = volGM
	volNPC = settings[CharConfig]['volNPC'] or volNPC
	settings[CharConfig]['volNPC'] = volNPC
	volPC = settings[CharConfig]['volPC'] or volPC
	settings[CharConfig]['volPC'] = volPC
	soundGM = settings[CharConfig]['soundGM'] or soundGM
	settings[CharConfig]['soundGM'] = soundGM
	soundNPC = settings[CharConfig]['soundNPC'] or soundNPC
	settings[CharConfig]['soundNPC'] = soundNPC
	soundPC = settings[CharConfig]['soundPC'] or soundPC
	settings[CharConfig]['soundPC'] = soundPC
	soundPCEntered = settings[CharConfig]['soundPCEntered'] or soundPCEntered
	settings[CharConfig]['soundPCEntered'] = soundPCEntered
	soundPCLeft = settings[CharConfig]['soundPCLeft'] or soundPCLeft
	settings[CharConfig]['soundPCLeft'] = soundPCLeft
	volPCEntered = settings[CharConfig]['volPCEntered'] or volPCEntered
	settings[CharConfig]['volPCEntered'] = volPCEntered
	volPCLeft = settings[CharConfig]['volPCLeft'] or volPCLeft
	settings[CharConfig]['volPCLeft'] = volPCLeft
	save_settings()
	if Module.GUI_Main.Locked then
		SearchWindow_Show = true
		SearchWindowOpen = true
	else
		SearchWindow_Show = false
		SearchWindowOpen = false
	end
	-- setup safe zone "set"
	for k, v in pairs(settings['SafeZones']) do tSafeZones[v] = true end
end

local function ColorDistance(distance)
	if distance < DistColorRanges.orange then
		-- Green color for Close Range
		return MyUI_Colors.color('green')
	elseif distance >= DistColorRanges.orange and distance <= DistColorRanges.red then
		-- Orange color for Mid Range
		return MyUI_Colors.color('orange')
	else
		-- Red color for Far Distance
		return MyUI_Colors.color('red')
	end
end

local function isSpawnInAlerts(spawnName, spawnAlertsTable)
	for _, spawnData in pairs(spawnAlertsTable) do
		if spawnData.DisplayName() == spawnName or spawnData.Name() == spawnName then
			return true
		end
	end
	return false
end

---@param spawn MQSpawn
local function SpawnToEntry(spawn, id, table)
	local pAggro = 0
	if table == xTarTable then
		pAggro = spawn.PctAggro() or 0
	end
	if spawn.ID() then
		local entry = {
			ID = id or 0,
			MobName = spawn.DisplayName() or ' ',
			MobDirtyName = spawn.Name() or ' ',
			MobZoneName = Zone.Name() or ' ',
			MobDist = math.floor(spawn.Distance() or 0),
			MobLoc = spawn.Loc() or ' ',
			MobID = spawn.ID() or 0,
			MobLvl = spawn.Level() or 0,
			MobConColor = string.lower(spawn.ConColor() or 'white'),
			MobAggro = pAggro or 0,
			MobDirection = spawn.HeadingTo() or '0',
			Enum_Action = 'unhandled',
		}
		return entry
	else
		return
	end
end

---@param spawn MQSpawn
local function InsertTableSpawn(dataTable, spawn, id, opts)
	if spawn then
		local entry = SpawnToEntry(spawn, id, dataTable)
		if opts then
			for k, v in pairs(opts) do
				entry[k] = v
			end
		end
		table.insert(dataTable, entry)
	end
end

local function TableSortSpecs(a, b)
	for i = 1, Module.GUI_Main.Table.SortSpecs.SpecsCount do
		local spec = Module.GUI_Main.Table.SortSpecs:Specs(i)
		local delta = 0
		if spec.ColumnUserID == Module.GUI_Main.Table.Column_ID.MobName then
			if a.MobName and b.MobName then
				if a.MobName < b.MobName then
					delta = -1
				elseif a.MobName > b.MobName then
					delta = 1
				end
			else
				return 0
			end
		elseif spec.ColumnUserID == Module.GUI_Main.Table.Column_ID.MobID then
			if a.MobID and b.MobID then
				if a.MobID < b.MobID then
					delta = -1
				elseif a.MobID > b.MobID then
					delta = 1
				end
			else
				return 0
			end
		elseif spec.ColumnUserID == Module.GUI_Main.Table.Column_ID.MobLvl then
			if a.MobLvl and b.MobLvl then
				if a.MobLvl < b.MobLvl then
					delta = -1
				elseif a.MobLvl > b.MobLvl then
					delta = 1
				end
			else
				return 0
			end
		elseif spec.ColumnUserID == Module.GUI_Main.Table.Column_ID.MobDist then
			if a.MobDist and b.MobDist then
				if a.MobDist < b.MobDist then
					delta = -1
				elseif a.MobDist > b.MobDist then
					delta = 1
				end
			else
				return 0
			end
		elseif spec.ColumnUserID == Module.GUI_Main.Table.Column_ID.MobAggro then
			if a.MobAggro and b.MobAggro then
				if a.MobAggro < b.MobAggro then
					delta = -1
				elseif a.MobAggro > b.MobAggro then
					delta = 1
				end
			else
				return 0
			end
		elseif spec.ColumnUserID == Module.GUI_Main.Table.Column_ID.Action then
			if a.Enum_Action < b.Enum_Action then
				delta = -1
			elseif a.Enum_Action > b.Enum_Action then
				delta = 1
			end
		end
		if delta ~= 0 then
			if spec.SortDirection == ImGuiSortDirection.Ascending then
				return delta < 0
			else
				return delta > 0
			end
		end
	end
	return a.MobName < b.MobName
end

local function AlertTableSortSpecs(a, b)
	for i = 1, Module.GUI_Alert.Table.SortSpecs.SpecsCount do
		local spec = Module.GUI_Alert.Table.SortSpecs:Specs(i)
		local delta = 0
		if spec.ColumnUserID == Module.GUI_Alert.Table.Column_ID.MobName then
			if a.MobName and b.MobName then
				if a.MobName < b.MobName then
					delta = -1
				elseif a.MobName > b.MobName then
					delta = 1
				end
			else
				return 0
			end
		elseif spec.ColumnUserID == Module.GUI_Alert.Table.Column_ID.MobDist then
			if a.MobDist and b.MobDist then
				if math.floor(mq.TLO.Spawn(a.MobID).Distance()) < math.floor(mq.TLO.Spawn(b.MobID).Distance()) then
					delta = -1
				elseif math.floor(mq.TLO.Spawn(a.MobID).Distance()) > math.floor(mq.TLO.Spawn(b.MobID).Distance()) then
					delta = 1
				end
			else
				return 0
			end
		end
		if delta ~= 0 then
			if spec.SortDirection == ImGuiSortDirection.Ascending then
				return delta < 0
			else
				return delta > 0
			end
		end
	end
	return a.MobName < b.MobName -- Default fallback to sorting by name
end

local function RefreshUnhandled()
	local splitSearch = {}
	for part in string.gmatch(Module.GUI_Main.Search, '[^%s]+') do
		table.insert(splitSearch, part)
	end
	local newTable = {}
	for k, v in ipairs(Table_Cache.Rules) do
		local found = 0
		for _, search in ipairs(splitSearch) do
			if string.find(string.lower(v.MobName), string.lower(search)) or string.find(v.MobDirtyName, search) then
				found = found + 1
			end
		end
		if #splitSearch == found then table.insert(newTable, v) end
	end
	Table_Cache.Unhandled = newTable
	Module.GUI_Main.Refresh.Sort.Rules = true
	Module.GUI_Main.Refresh.Table.Unhandled = true
end

local function RefreshAlerts()
	local tmp = {}
	local z = 1
	doOnce = false
	for k, v in pairs(spawnAlerts) do
		tmp[z] = v
		z = z + 1
	end
	local newTable = {}
	for i = 1, #tmp do
		local spawn = tmp[i]
		if #tmp > 0 then InsertTableSpawn(newTable, spawn, tonumber(spawn.ID())) end
	end
	Table_Cache.Alerts = newTable
	Module.GUI_Alert.Refresh.Sort.Alerts = true
	Module.GUI_Alert.Refresh.Table.Alerts = false
end

local function RefreshZone()
	local newTable = {}
	xTarTable = {}
	local npcs = mq.getFilteredSpawns(function(spawn) return spawn.Type() == 'NPC' end)
	for i = 1, #npcs do
		local spawn = npcs[i]
		if #npcs > 0 then InsertTableSpawn(newTable, spawn, tonumber(spawn.ID())) end
	end
	for i = 1, mq.TLO.Me.XTargetSlots() do
		if mq.TLO.Me.XTarget(i)() ~= nil and mq.TLO.Me.XTarget(i)() ~= 0 then
			local spawn = mq.TLO.Me.XTarget(i)
			if spawn.ID() > 0 then InsertTableSpawn(xTarTable, spawn, tonumber(spawn.ID())) end
		end
	end
	if showAggro then
		for _, xTarEntry in ipairs(xTarTable) do
			-- Check if xTarEntry already exists in newTable
			local found = false
			for j, newEntry in ipairs(newTable) do
				if newEntry.MobID == xTarEntry.MobID then
					-- Update newTable entry with xTarEntry data
					newTable[j]['MobAggro'] = xTarEntry['MobAggro']
					break
				end
			end
		end
	end
	Table_Cache.Rules = newTable
	Table_Cache.Mobs = newTable
	Module.GUI_Main.Refresh.Sort.Mobs = true
	Module.GUI_Main.Refresh.Table.Mobs = false
end

-----------------------

---@param spawn MQSpawn
local should_include_player = function(spawn)
	local name = spawn.DisplayName()
	local guild = spawn.Guild()
	-- if pc exists on the ignore list, skip
	if settings['Ignore'] ~= nil then
		for k, v in pairs(settings['Ignore']) do
			if v == name then return false end
		end
	end
	-- if pc is in group, raid or (optionally) guild, skip
	local in_group = Group.Members() ~= nil and Group.Member(name).Index() ~= nil
	local in_raid = Raid.Members() > 0 and Raid.Member(name)() ~= nil
	local in_guild = ignoreguild and MyUI_Guild ~= nil and MyUI_Guild == guild
	if in_group or in_raid or in_guild then return false end
	return true
end

local run_char_commands = function()
	if settings[CharCommands] ~= nil then
		for k, cmd in pairs(settings[CharCommands]) do
			mq.cmdf(cmd)
			MyUI_Utils.PrintOutput('AlertMaster', nil, string.format('Ran command: "%s"', cmd))
		end
	end
end

local spawn_search_players = function(search)
	local tmp = {}
	local cnt = SpawnCount(search)()
	if cnt ~= nil or cnt > 0 then
		for i = 1, cnt do
			local pc = NearestSpawn(i, search)
			if pc ~= nil and pc.DisplayName() ~= nil then
				local name = pc.DisplayName()
				local guild = pc.Guild() or 'No Guild'
				if should_include_player(pc) then
					tmp[name] = {
						name = (pc.GM() and '\ag*GM*\ax ' or '') .. '\ar' .. name .. '\ax',
						guild = '<\ay' .. guild .. '\ax>',
						distance = math.floor(pc.Distance() or 0),
						time = os.time(),
					}
				end
			end
		end
	end
	return tmp
end

local spawn_search_npcs = function()
	local tmp = {}
	local spawns = settings[Zone.ShortName()]
	if spawns ~= nil then
		for k, v in pairs(spawns) do
			local search = 'npc ' .. v
			local cnt = SpawnCount(search)()
			for i = 1, cnt do
				local spawn = NearestSpawn(i, search)
				local id = spawn.ID()
				if spawn ~= nil and id ~= nil then
					-- Case-sensitive comparison using CleanName for exact matching
					if spawn.DisplayName() == v or spawn.Name() == v then
						tmp[id] = spawn
					end
				end
			end
		end
	end
	return tmp
end

local check_for_gms = function()
	if active and gms then
		local tmp = spawn_search_players('gm')
		if tmp ~= nil then
			for name, v in pairs(tmp) do
				if tGMs[name] == nil then
					tGMs[name] = v
					MyUI_Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' ' .. v.guild .. ' entered the zone. ' .. v.distance .. ' units away.')
					if doSoundGM then
						setVolume(volGM)
						playSound(soundGM)
					end
				elseif (remind ~= nil and remind > 0) and tGMs[name] ~= nil and os.difftime(os.time(), tGMs[name].time) > remind then
					tGMs[name].time = v.time
					if doSoundGM then
						setVolume(volGM)
						playSound(soundGM)
					end
					MyUI_Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' loitering ' .. v.distance .. ' units away.')
				end
			end
			if tGMs ~= nil then
				for name, v in pairs(tGMs) do
					if tmp[name] == nil then
						tGMs[name] = nil
						MyUI_Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' left the zone.')
					end
				end
			end
		end
	end
end

local check_for_pcs = function()
	if active and pcs then
		local tmp = spawn_search_players('pc radius ' .. radius .. ' zradius ' .. zradius .. ' notid ' .. mq.TLO.Me.ID())
		local charZone = '\aw[\a-o' .. MyUI_CharLoaded .. '\aw|\at' .. Zone.ShortName() .. '\aw] '
		if tmp ~= nil then
			for name, v in pairs(tmp) do
				if tPlayers[name] == nil then
					tPlayers[name] = v
					MyUI_Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' ' .. v.guild .. ' entered the alert radius. ' .. v.distance .. ' units away.')
					if doSoundPC then
						setVolume(volPC)
						playSound(soundPC)
					end
					-- run commands here
				elseif (remind ~= nil and remind > 0) and tPlayers[name] ~= nil and os.difftime(os.time(), tPlayers[name].time) > remind then
					tPlayers[name].time = v.time
					if doSoundPC then
						setVolume(volPC)
						playSound(soundPC)
					end
					MyUI_Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' loitering ' .. v.distance .. ' units away.')
					run_char_commands()
				end
			end
			if tPlayers ~= nil then
				for name, v in pairs(tPlayers) do
					if tmp[name] == nil then
						tPlayers[name] = nil
						MyUI_Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' left the alert radius.')
					end
				end
			end
		end
	end
end

local check_for_spawns = function()
	if active and spawns then
		local spawnAlertsUpdated, tableUpdate = false, false
		local charZone = '\aw[\a-o' .. MyUI_CharLoaded .. '\aw|\at' .. Zone.ShortName() .. '\aw] '
		if haveSM and (importZone or forceImport) then
			local counter = 0
			local tmpSpawnMaster = {}

			if not importedZones[Zone.ShortName()] or forceImport then
				-- Check for Long Name
				local tmpFixName = Zone.Name():gsub("the ", ""):lower()
				if spawnsSpawnMaster[Zone.Name():lower()] ~= nil or spawnsSpawnMaster[tmpFixName] ~= nil then
					tmpSpawnMaster = spawnsSpawnMaster[Zone.Name():lower()] ~= nil and spawnsSpawnMaster[Zone.Name():lower()] or spawnsSpawnMaster[tmpFixName]
					for k, v in pairs(tmpSpawnMaster) do
						if import_spawnmaster(v) then
							counter = counter + 1
						end
					end
				end
				-- Check for Short Name
				if spawnsSpawnMaster[Zone.ShortName()] ~= nil then
					tmpSpawnMaster = spawnsSpawnMaster[Zone.ShortName()]
					for k, v in pairs(tmpSpawnMaster) do
						if import_spawnmaster(v) then
							counter = counter + 1
						end
					end
				end
				importZone = false
				forceImport = false
				mq.pickle(smImportList, importedZones)
				MyUI_Utils.PrintOutput('AlertMaster', nil, string.format('\aw[\atAlert Master\aw] \agImported \aw[\ay%d\aw]\ag Spawn Master Spawns...', counter))
			end
		end
		local tmp = spawn_search_npcs()
		if tmp ~= nil then
			for id, v in pairs(tmp) do
				if tSpawns[id] == nil then
					if check_safe_zone() ~= true then
						MyUI_Utils.PrintOutput('AlertMaster', nil,
							GetCharZone() .. '\ag' .. tostring(v.DisplayName()) .. '\ax spawn alert! ' .. tostring(math.floor(v.Distance() or 0)) .. ' units away.')
						spawnAlertsUpdated = true
					end
					tableUpdate = true
					tSpawns[id] = { DisplayName = v.DisplayName(), Spawn = v, }
					spawnAlerts[id] = v
					numAlerts = numAlerts + 1
				end
			end
			if tSpawns ~= nil then
				for id, v in pairs(tSpawns) do
					if tmp[id] == nil then
						if check_safe_zone() ~= true then
							if v.DisplayName ~= nil then
								MyUI_Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. '\ag' .. tostring(v.DisplayName) .. '\ax was killed or despawned.')
							end
							spawnAlertsUpdated = false
						end
						tableUpdate = true
						tSpawns[id] = nil
						spawnAlerts[id] = nil
						numAlerts = numAlerts - 1
					end
				end
			else
				AlertWindow_Show = false
				AlertWindowOpen = false
			end
			-- Check if there are any entries in the spawnAlerts table
			if next(spawnAlerts) ~= nil then
				if tableUpdate or doOnce then RefreshAlerts() end
				if spawnAlertsUpdated then
					if doAlert then
						AlertWindow_Show = true
						AlertWindowOpen = true
						if not AlertWindowOpen then DrawAlertGUI() end
					end
					alertTime = os.time()
					if doBeep or doSoundNPC then
						if doSoundNPC then
							setVolume(volNPC)
							playSound(soundNPC)
						else
							mq.cmdf('/beep')
						end
					end
				end
			else
				AlertWindow_Show = false
				AlertWindowOpen = false
			end
		end
	end
end

local check_for_announce = function()
	if active and announce then
		local tmp = spawn_search_players('pc notid ' .. mq.TLO.Me.ID())
		local charZone = '\aw[\a-o' .. MyUI_CharLoaded .. '\aw|\at' .. Zone.ShortName() .. '\aw] '
		if tmp ~= nil then
			for name, v in pairs(tmp) do
				if tAnnounce[name] == nil then
					tAnnounce[name] = v
					MyUI_Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' ' .. v.guild .. ' entered the zone.')
					if doSoundPCEntered then
						setVolume(volPCEntered)
						playSound(soundPCEntered)
					end
				end
			end
			if tAnnounce ~= nil then
				for name, v in pairs(tAnnounce) do
					if tmp[name] == nil then
						tAnnounce[name] = nil
						MyUI_Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' left the zone.')
						if doSoundPCLeft then
							setVolume(volPCLeft)
							playSound(soundPCLeft)
						end
					end
				end
			end
		end
	end
end

local check_for_zone_change = function()
	-- if we've changed zones, clear the tables and update current zone id
	if active and (zone_id == nil or zone_id ~= Zone.ID()) then
		AlertWindowOpen, AlertWindow_Show = false, false
		tGMs, tAnnounce, tPlayers, tSpawns, spawnAlerts, Table_Cache.Unhandled, Table_Cache.Alerts, Table_Cache.Mobs, Table_Cache.Rules = {}, {}, {}, {}, {}, {}, {}, {}, {}
		zone_id = Zone.ID()
		alertTime = os.time()
		doOnce = true
		if haveSM then importZone = true end
	end
end
-------- GUI STUFF ------------

local function directions(heading)
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
local function getRelativeDirection(spawnDir)
	local meHeading = directions(mq.TLO.Me.Heading())
	local spawnHeadingTo = directions(spawnDir)
	local difference = spawnHeadingTo - meHeading
	difference = (difference + 360) % 360
	return difference
end

function RotatePoint(p, cx, cy, degAngle)
	local radians = math.rad(degAngle)
	local cosA = math.cos(radians)
	local sinA = math.sin(radians)
	local newX = cosA * (p.x - cx) - sinA * (p.y - cy) + cx
	local newY = sinA * (p.x - cx) + cosA * (p.y - cy) + cy
	return ImVec2(newX, newY)
end

function DrawArrow(topPoint, width, height, color)
	local draw_list = ImGui.GetWindowDrawList()
	local p1 = ImVec2(topPoint.x, topPoint.y)
	local p2 = ImVec2(topPoint.x + width, topPoint.y + height)
	local p3 = ImVec2(topPoint.x - width, topPoint.y + height)
	-- center
	local center_x = (p1.x + p2.x + p3.x) / 3
	local center_y = (p1.y + p2.y + p3.y) / 3
	-- rotate
	angle = angle + .01
	p1 = RotatePoint(p1, center_x, center_y, angle)
	p2 = RotatePoint(p2, center_x, center_y, angle)
	p3 = RotatePoint(p3, center_x, center_y, angle)
	draw_list:AddTriangleFilled(p1, p2, p3, ImGui.GetColorU32(color))
end

----------------------------
---comment
---@param tName string -- name of the theme to load form table
---@return integer, integer -- returns the new counter values
local function DrawTheme(tName)
	local StyleCounter = 0
	local ColorCounter = 0
	for tID, tData in pairs(theme.Theme) do
		if tData.Name == tName then
			for pID, cData in pairs(theme.Theme[tID].Color) do
				ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
				ColorCounter = ColorCounter + 1
			end
			if tData['Style'] ~= nil then
				if next(tData['Style']) ~= nil then
					for sID, sData in pairs(theme.Theme[tID].Style) do
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
	return ColorCounter, StyleCounter
end

local function DrawToggles()
	local lockedIcon = Module.GUI_Main.Locked and MyUI_Icons.FA_LOCK .. '##lockTabButton' or
		MyUI_Icons.FA_UNLOCK .. '##lockTablButton'
	if ImGui.SmallButton(lockedIcon) then
		--ImGuiWindowFlags.NoMove
		Module.GUI_Main.Locked = not Module.GUI_Main.Locked
		settings[CharConfig]['locked'] = Module.GUI_Main.Locked
		save_settings()
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Lock Window")
		ImGui.EndTooltip()
	end
	ImGui.SameLine()
	local gIcon = MyUI_Icons.MD_SETTINGS
	if ImGui.SmallButton(gIcon) then
		openConfigGUI = not openConfigGUI
		save_settings()
		--mq.pickle(themeFile, theme)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Config")
		ImGui.EndTooltip()
	end
	ImGui.SameLine()
	-- Alert Popup Toggle Button
	if doAlert then
		ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_green')) -- Green for enabled
		if ImGui.SmallButton(MyUI_Icons.MD_ALARM) then mq.cmdf('/am doalert') end
		ImGui.PopStyleColor(1)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_red')) -- Red for disabled
		if ImGui.Button(MyUI_Icons.MD_ALARM_OFF) then mq.cmdf('/am doalert') end
		ImGui.PopStyleColor(1)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Toggle Popup Alerts On\\Off")
		ImGui.EndTooltip()
	end
	ImGui.SameLine()
	-- Beep Alert Toggle Button
	if doBeep then
		ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_green')) -- Green for enabled
		if ImGui.SmallButton(MyUI_Icons.FA_BELL_O) then mq.cmdf('/am beep') end
		ImGui.PopStyleColor(1)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_red')) -- Red for disabled
		if ImGui.Button(MyUI_Icons.FA_BELL_SLASH_O) then mq.cmdf('/am beep') end
		ImGui.PopStyleColor(1)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Toggle Beep Alerts On\\Off")
		ImGui.EndTooltip()
	end
	ImGui.SameLine()
	-- Alert Window Toggle Button
	if AlertWindowOpen then
		ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_green')) -- Green for enabled
		if ImGui.SmallButton(MyUI_Icons.MD_VISIBILITY) then mq.cmdf('/am popup') end
		ImGui.PopStyleColor(1)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_red')) -- Red for inactive state
		if ImGui.SmallButton(MyUI_Icons.MD_VISIBILITY_OFF) then mq.cmdf('/am popup') end
		ImGui.PopStyleColor(1)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Show\\Hide Alert Window")
		ImGui.EndTooltip()
	end
	ImGui.SameLine()
	-- Button to add the new spawn
	if ImGui.SmallButton(MyUI_Icons.FA_HASHTAG) then
		mq.cmdf('/am spawnadd ${Target}')
		npcs = settings[Zone.ShortName()] or {}
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Add Target #Dirty_Name0 to SpawnList")
		ImGui.EndTooltip()
	end
	ImGui.SameLine()
	-- Button to add the new spawn
	if ImGui.SmallButton(MyUI_Icons.FA_BULLSEYE) then
		mq.cmdf('/am spawnadd "${Target.DisplayName}"')
		npcs = settings[Zone.ShortName()] or {}
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Add Target Clean Name to SpawnList\nThis is handy if you are hunting a specific type of Mob,\ntarget a moss snake and add, you will get all \"a moss snake\"")
		ImGui.EndTooltip()
	end
	ImGui.SameLine(ImGui.GetWindowWidth() - 120)
	-- Arrow Status Toggle Button
	if DoDrawArrow then
		ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_green')) -- Green for enabled
		if ImGui.SmallButton(MyUI_Icons.FA_ARROW_UP) then
			DoDrawArrow, settings[CharConfig]['arrows'] = false, false
			save_settings()
		end
		ImGui.PopStyleColor(1)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_red')) -- Red for disabled
		if ImGui.SmallButton(MyUI_Icons.FA_ARROW_DOWN) then
			DoDrawArrow, settings[CharConfig]['arrows'] = true, true
			save_settings()
		end
		ImGui.PopStyleColor(1)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Toggle Drawing Arrows On\\Off")
		ImGui.EndTooltip()
	end
	ImGui.SameLine(ImGui.GetWindowWidth() - 90)
	-- Aggro Status Toggle Button
	if showAggro then
		ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_green')) -- Green for enabled
		if ImGui.SmallButton(MyUI_Icons.MD_PRIORITY_HIGH) then mq.cmdf('/am aggro') end
		ImGui.PopStyleColor(1)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_red')) -- Red for disabled
		if ImGui.SmallButton(MyUI_Icons.MD_PRIORITY_HIGH) then mq.cmdf('/am aggro') end
		ImGui.PopStyleColor(1)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Toggle Aggro Status On\\Off")
		ImGui.EndTooltip()
	end
	ImGui.SameLine(ImGui.GetWindowWidth() - 60)
	-- Alert Master Scanning Toggle Button
	if active then
		ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_green')) -- Green for enabled
		if ImGui.SmallButton(MyUI_Icons.FA_HEARTBEAT) then mq.cmdf('/am off') end
		ImGui.PopStyleColor(1)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_red')) -- Red for disabled
		if ImGui.SmallButton(MyUI_Icons.MD_DO_NOT_DISTURB) then mq.cmdf('/am on') end
		ImGui.PopStyleColor(1)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Toggle ALL Scanning and Alerts On\\Off")
		ImGui.EndTooltip()
	end
	ImGui.SameLine()
	-- Place a help icon
	ImGui.SameLine(ImGui.GetWindowWidth() - 30) -- Position at right end of line.
	if showTooltips then
		ImGui.Text(MyUI_Icons.MD_HELP)
	else
		ImGui.Text(MyUI_Icons.MD_HELP_OUTLINE)
	end
	if ImGui.IsItemHovered() then
		ImGui.SetTooltip("Right-Click.\nTo toggle Tooltips.")
		if ImGui.IsMouseReleased(0) or ImGui.IsMouseReleased(1) then showTooltips = not showTooltips end
	end
end

local function addSpawnToList(name)
	local sCount = 0
	local zone = Zone.ShortName()
	if settings[zone] == nil then settings[zone] = {} end

	-- if the zone does exist in the ini, spin over entries and make sure we aren't duplicating
	for k, v in pairs(settings[zone]) do
		if settings[zone][k] == name then
			MyUI_Utils.PrintOutput('AlertMaster', nil, "\aySpawn alert \"" .. name .. "\" already exists.")
			return
		end
		sCount = sCount + 1
	end
	-- if we made it this far, the spawn isn't tracked -- add it to the table and store to ini
	settings[zone]['Spawn' .. sCount + 1] = name
	save_settings()
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayAdded spawn alert for ' .. name .. ' in ' .. zone)
end

local function DrawRuleRow(entry)
	ImGui.TableNextColumn()
	-- Add to Spawn List Button
	if ImGui.SmallButton(MyUI_Icons.FA_USER_PLUS) then addSpawnToList(entry.MobName) end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Add to Spawn List")
		ImGui.EndTooltip()
	end
	ImGui.TableNextColumn()
	-- Mob Name
	ImGui.Text('%s', entry.MobName)
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("%s\n\nRight-Click to Navigate\nCtrl+Right-Click Group Nav", entry.MobName)
		ImGui.EndTooltip()
	end
	-- Right-click interaction uses the original spawnName
	if ImGui.IsItemHovered() then
		if ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsMouseReleased(1) then
			mq.cmdf("/noparse %s/docommand /timed ${Math.Rand[5,25]} /nav id %s", groupCmd, entry.MobID)
		elseif
			ImGui.IsMouseReleased(1) then
			mq.cmdf('/nav id %s', entry.MobID)
		end
	end
	ImGui.SameLine()
	ImGui.TableNextColumn()
	--Consider Color for Level Text
	ImGui.PushStyleColor(ImGuiCol.Text, MyUI_Colors.color(entry.MobConColor))
	ImGui.Text('%s', (entry.MobLvl))
	ImGui.PopStyleColor()
	ImGui.TableNextColumn()
	--Distance
	local distance = math.floor(entry.MobDist or 0)
	ImGui.PushStyleColor(ImGuiCol.Text, ColorDistance(distance))
	ImGui.Text(tostring(distance))
	ImGui.PopStyleColor()
	ImGui.TableNextColumn()
	--Mob Aggro
	if entry.MobAggro ~= 0 then
		local pctAggro = tonumber(entry.MobAggro) / 100
		ImGui.PushStyleColor(ImGuiCol.PlotHistogram, MyUI_Colors.color('red'))
		ImGui.ProgressBar(pctAggro, ImGui.GetColumnWidth(), 15)
		ImGui.PopStyleColor()
	else
	end
	ImGui.TableNextColumn()
	--Mob ID
	ImGui.Text('%s', (entry.MobID))
	ImGui.TableNextColumn()
	--Mob Loc
	ImGui.Text('%s', (entry.MobLoc))
	ImGui.TableNextColumn()
	--Mob Direction
	if DoDrawArrow then
		angle = getRelativeDirection(entry.MobDirection) or 0
		local cursorScreenPos = ImGui.GetCursorScreenPosVec()
		DrawArrow(ImVec2(cursorScreenPos.x + 10, cursorScreenPos.y), 5, 15, ColorDistance(distance))
	end
	ImGui.SetWindowFontScale(1)
	ImGui.TableNextColumn()
end

local function DrawAlertRuleRow(entry)
	local sHeadingTo = entry.MobDirection

	ImGui.TableSetColumnIndex(0)
	ImGui.PushStyleColor(ImGuiCol.Text, MyUI_Colors.color('green'))
	ImGui.Text(entry.MobName)
	ImGui.PopStyleColor(1)
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Right-Click to Navigate: " .. entry.MobName .. "\nCtrl+Right-Click to Group Navigate: " .. entry.MobName)
		ImGui.EndTooltip()
	end
	if ImGui.IsItemHovered() then
		if ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsMouseReleased(1) then
			mq.cmdf('/noparse %s/docommand /timed ${Math.Rand[10,60]} /nav id %s', groupCmd, entry.MobID)
		elseif
			ImGui.IsMouseReleased(1) then
			mq.cmdf('/nav id %s', entry.MobID)
		end
	end
	ImGui.TableSetColumnIndex(1)
	local distance = math.floor(mq.TLO.Spawn(entry.MobID).Distance() or 0)
	ImGui.PushStyleColor(ImGuiCol.Text, ColorDistance(distance))
	ImGui.Text('\t' .. tostring(distance))
	ImGui.PopStyleColor()
	ImGui.TableSetColumnIndex(2)
	--if DoDrawArrow then
	angle = getRelativeDirection(sHeadingTo) or 0
	local cursorScreenPos = ImGui.GetCursorScreenPosVec()
	DrawArrow(ImVec2(cursorScreenPos.x + 10, cursorScreenPos.y), 5, 15, ColorDistance(distance))
	--end
end
local btnIconDel = MyUI_Icons.MD_DELETE
local function DrawSearchWindow()
	if currZone ~= lastZone then return end
	if Module.GUI_Main.Locked then
		Module.GUI_Main.Flags = bit32.bor(Module.GUI_Main.Flags, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize)
	else
		Module.GUI_Main.Flags = bit32.band(Module.GUI_Main.Flags, bit32.bnot(ImGuiWindowFlags.NoMove), bit32.bnot(ImGuiWindowFlags.NoResize))
	end
	if SearchWindowOpen then
		-- ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 5)
		local ColorCount, StyleCount = DrawTheme(useThemeName)
		if ZoomLvl > 1.25 then ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4, 7) end
		SearchWindowOpen = ImGui.Begin("Alert Master##" .. MyUI_CharLoaded, SearchWindowOpen, Module.GUI_Main.Flags)
		ImGui.BeginMenuBar()
		ImGui.SetWindowFontScale(ZoomLvl)
		DrawToggles()
		ImGui.EndMenuBar()
		if ZoomLvl > 1.25 then ImGui.PopStyleVar(1) end
		-- ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4,3)
		--ImGui.SameLine()
		ImGui.SetWindowFontScale(ZoomLvl)
		ImGui.Separator()
		-- next row
		if ImGui.Button(Zone.Name(), 160, 0.0) then
			currentTab = "zone"
			RefreshZone()
		end
		if ImGui.IsItemHovered() and showTooltips then
			ImGui.BeginTooltip()
			ImGui.Text("Zone Short Name: %s\nSpawn Count: %s", Zone.ShortName(), tostring(#Table_Cache.Unhandled))
			ImGui.EndTooltip()
		end
		ImGui.SameLine()
		local tabLabel = "NPC List"
		if next(spawnAlerts) ~= nil then
			tabLabel = MyUI_Icons.FA_BULLHORN .. " NPC List " .. MyUI_Icons.FA_BULLHORN
			ImGui.PushStyleColor(ImGuiCol.Button, MyUI_Colors.color('btn_red'))
			if ImGui.Button(tabLabel) then
				currentTab = "npcList"
			end
			ImGui.PopStyleColor(1)
		else
			ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.4, 0.8, 0.4)
			if ImGui.Button(tabLabel) then
				currentTab = "npcList"
			end
			ImGui.PopStyleColor(1)
		end

		if currentTab == "zone" then
			local searchText, selected = ImGui.InputText("Search##RulesSearch", Module.GUI_Main.Search)
			-- ImGui.PopItemWidth()
			if selected and Module.GUI_Main.Search ~= searchText then
				Module.GUI_Main.Search = searchText
				Module.GUI_Main.Refresh.Sort.Rules = true
				Module.GUI_Main.Refresh.Table.Unhandled = true
			end
			ImGui.SameLine()
			if ImGui.Button("Clear##ClearRulesSearch") then
				Module.GUI_Main.Search = ''
				Module.GUI_Main.Refresh.Sort.Rules = false
				Module.GUI_Main.Refresh.Table.Unhandled = true
			end
			ImGui.Separator()
			local sizeX = ImGui.GetContentRegionAvail() - 4
			ImGui.SetWindowFontScale(ZoomLvl)
			if ImGui.BeginTable('##RulesTable', 8, Module.GUI_Main.Table.Flags) then
				ImGui.TableSetupScrollFreeze(0, 1)
				ImGui.TableSetupColumn(MyUI_Icons.FA_USER_PLUS, ImGuiTableColumnFlags.NoSort, 15, Module.GUI_Main.Table.Column_ID.Remove)
				ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.DefaultSort, 120, Module.GUI_Main.Table.Column_ID.MobName)
				ImGui.TableSetupColumn("Lvl", ImGuiTableColumnFlags.DefaultSort, 30, Module.GUI_Main.Table.Column_ID.MobLvl)
				ImGui.TableSetupColumn("Dist", ImGuiTableColumnFlags.DefaultSort, 40, Module.GUI_Main.Table.Column_ID.MobDist)
				ImGui.TableSetupColumn("Aggro", ImGuiTableColumnFlags.DefaultSort, 30, Module.GUI_Main.Table.Column_ID.MobAggro)
				ImGui.TableSetupColumn("ID", ImGuiTableColumnFlags.DefaultSort, 30, Module.GUI_Main.Table.Column_ID.MobID)
				ImGui.TableSetupColumn("Loc", ImGuiTableColumnFlags.NoSort, 90, Module.GUI_Main.Table.Column_ID.MobLoc)
				ImGui.TableSetupColumn(MyUI_Icons.FA_COMPASS, bit32.bor(ImGuiTableColumnFlags.NoResize, ImGuiTableColumnFlags.NoSort, ImGuiTableColumnFlags.WidthFixed), 15,
					Module.GUI_Main.Table.Column_ID.MobDirection)
				ImGui.TableHeadersRow()
				local sortSpecs = ImGui.TableGetSortSpecs()

				if sortSpecs and (sortSpecs.SpecsDirty or Module.GUI_Main.Refresh.Sort.Rules) then
					if #Table_Cache.Unhandled > 0 then
						Module.GUI_Main.Table.SortSpecs = sortSpecs
						table.sort(Table_Cache.Unhandled, TableSortSpecs)
						Module.GUI_Main.Table.SortSpecs = nil
					end
					sortSpecs.SpecsDirty = false
					Module.GUI_Main.Refresh.Sort.Rules = false
				end
				local clipper = ImGuiListClipper.new()
				clipper:Begin(#Table_Cache.Unhandled)
				while clipper:Step() do
					for i = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
						local entry = Table_Cache.Unhandled[i + 1]
						ImGui.PushID(entry.ID)
						ImGui.TableNextRow()
						DrawRuleRow(entry)
						ImGui.PopID()
					end
				end
				clipper:End()

				ImGui.EndTable()
			end
		elseif currentTab == "npcList" then
			-- Tab for NPC List
			local npcs = settings[Zone.ShortName()] or {}
			local changed
			ImGui.SetNextItemWidth(160)
			newSpawnName, changed = ImGui.InputText("##NewSpawnName", newSpawnName, 256)
			if ImGui.IsItemHovered() and showTooltips then
				ImGui.BeginTooltip()
				ImGui.Text("Enter Spawn Name this is CaseSensative,\n also accepts variables like: ${Target.DisplayName} and ${Target.Name}")
				ImGui.EndTooltip()
			end
			ImGui.SameLine()
			-- Button to add the new spawn
			if ImGui.Button(MyUI_Icons.FA_USER_PLUS) and newSpawnName ~= "" then
				-- CMD('/am spawnadd "'..newSpawnName..'"')
				addSpawnToList(newSpawnName)
				newSpawnName = "" -- Clear the input text after adding
				npcs = settings[Zone.ShortName()] or {}
			end
			if ImGui.IsItemHovered() and showTooltips then
				ImGui.BeginTooltip()
				ImGui.Text("Add to SpawnList")
				ImGui.EndTooltip()
			end
			ImGui.SameLine()
			if haveSM then
				if ImGui.Button('Import Zone##ImportSM') then
					forceImport = true
					importZone = true
					check_for_spawns()
				end
			end
			-- Populate and sort sortedNpcs right before using it
			local sortedNpcs = {}
			for id, spawnName in pairs(npcs) do
				table.insert(sortedNpcs, {
					name = spawnName,
					isInAlerts = isSpawnInAlerts(spawnName, spawnAlerts),
				})
			end
			-- Sort the table so NPCs in alerts come first
			table.sort(sortedNpcs, function(a, b)
				if a.isInAlerts and not b.isInAlerts then
					return true
				elseif not a.isInAlerts and b.isInAlerts then
					return false
				else
					return a.name < b.name
				end
			end)
			-- Now build the table with the sorted list
			ImGui.SetWindowFontScale(ZoomLvl)
			if next(sortedNpcs) ~= nil then
				local sizeX = ImGui.GetContentRegionAvail() - 4
				if ImGui.BeginTable("NPCListTable", 3, spawnListFlags) then
					-- Set up table headers
					ImGui.TableSetupScrollFreeze(0, 1)
					ImGui.TableSetupColumn("NPC Name##AMList", ImGuiTableColumnFlags.None)
					ImGui.TableSetupColumn("Zone##AMList", ImGuiTableColumnFlags.None)
					ImGui.TableSetupColumn(" " .. btnIconDel .. "##AMList", bit32.bor(ImGuiTableColumnFlags.WidthFixed,
						ImGuiTableColumnFlags.NoSort, ImGuiTableColumnFlags.NoResize), 20)
					ImGui.TableHeadersRow()
					for index, npc in ipairs(sortedNpcs) do
						local spawnName = npc.name
						-- local sHeading = npc.HeadingTo() or '??'
						ImGui.TableNextRow()
						ImGui.TableNextColumn()
						-- Modify the spawnName to create a display name
						local displayName = spawnName:gsub("_", " "):gsub("%d*$", "") -- Replace underscores with spaces and remove trailing digits
						-- Check if the spawn is in the alert list and change color
						if npc.isInAlerts then
							ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1) -- Green color for alert spawns
						end
						-- Display the name and handle interaction
						ImGui.Text(displayName)
						if npc.isInAlerts then
							ImGui.PopStyleColor()
							if ImGui.IsItemHovered() and showTooltips then
								ImGui.BeginTooltip()
								ImGui.Text("Green Names are up!\n Right-Click to Navigate to " .. displayName .. "\n Ctrl+Right-Click to Group Navigate to " .. displayName)
								ImGui.EndTooltip()
							end
							-- Right-click interaction uses the original spawnName
							if ImGui.IsItemHovered() then
								if ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsMouseReleased(1) then
									mq.cmdf('/noparse %s/docommand /timed ${Math.Rand[10,60]} /nav spawn "%s"', groupCmd, spawnName)
								elseif
									ImGui.IsMouseReleased(1) then
									mq.cmdf('/nav spawn "%s"', spawnName)
								end
							end
						end
						ImGui.TableNextColumn()
						ImGui.Text(Zone.ShortName())

						local buttonLabel = btnIconDel .. "##AM_Remove" .. tostring(index)
						ImGui.TableNextColumn()
						if ImGui.SmallButton(buttonLabel) then
							mq.cmdf('/am spawndel "' .. spawnName .. '"')
						end
						if ImGui.IsItemHovered() and showTooltips then
							ImGui.BeginTooltip()
							ImGui.Text("Delete Spawn From SpawnList")
							ImGui.EndTooltip()
						end
					end
					ImGui.EndTable()
				end
			else
				ImGui.Text('No spawns in list for this zone. Add some!')
			end
		end
		if StyleCount > 0 then ImGui.PopStyleVar(StyleCount) end
		if ColorCount > 0 then ImGui.PopStyleColor(ColorCount) end
		ImGui.SetWindowFontScale(1)
		ImGui.End()
	end
end

local function Config_GUI()
	if not openConfigGUI then return end
	ColorCountConf = 0
	StyleCountConf = 0
	-- local themeName = theme.LoadTheme or 'notheme'
	ColorCountConf, StyleCountConf = DrawTheme(useThemeName)

	local open, drawConfigGUI = ImGui.Begin("Alert master Config", true, bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.NoCollapse))
	ImGui.SetWindowFontScale(ZoomLvl)
	if not open then
		drawConfigGUI = false
		openConfigGUI = false
	end
	if drawConfigGUI then
		if ImGui.CollapsingHeader('Theme Settings##AlertMaster') then
			ImGui.Text("Cur Theme: %s", useThemeName)
			-- Combo Box Load Theme
			if ImGui.BeginCombo("Load Theme", useThemeName) then
				ImGui.SetWindowFontScale(ZoomLvl)
				for k, data in pairs(theme.Theme) do
					local isSelected = data.Name == useThemeName
					if ImGui.Selectable(data.Name, isSelected) then
						theme.LoadTheme = data.Name
						useThemeName = theme.LoadTheme
						settings[CharConfig]['theme'] = useThemeName
						save_settings()
					end
				end
				ImGui.EndCombo()
			end

			-- Slider for adjusting zoom level
			local tmpZoom = ZoomLvl
			if ZoomLvl then
				tmpZoom = ImGui.SliderFloat("Text Scaling", tmpZoom, 0.5, 2.0)
			end
			if ZoomLvl ~= tmpZoom then
				ZoomLvl = tmpZoom
				settings[CharConfig]['ZoomLvl'] = ZoomLvl
			end

			if ImGui.Button('Reload Theme File') then
				load_settings()
			end
		end

		if ImGui.CollapsingHeader('Toggles##AlertMaster') then
			local keys = {}
			if ImGui.BeginTable('##ToggleTable', 2, ImGuiTableFlags.Resizable) then
				ImGui.TableSetupColumn('##ToggleCol1', ImGuiTableColumnFlags.None)
				ImGui.TableSetupColumn('##ToggleCol2', ImGuiTableColumnFlags.None)
				ImGui.TableNextRow()
				for k, v in pairs(settings[CharConfig]) do
					if type(v) == 'boolean' then
						keys[k]                          = false
						settings[CharConfig][k], keys[k] = ImGui.Checkbox(k, v)
						if keys[k] then
							save_settings()
						end
						ImGui.TableNextColumn()
					end
				end
				ImGui.EndTable()
			end
		end

		if ImGui.CollapsingHeader('Sounds##AlertMaster') then
			--- GM Alerts ---
			ImGui.SeparatorText("GM Alerts##AlertMaster")
			--- tmp vars to change ---
			local tmpSndGM = soundGM or 'GM.wav'
			local tmpVolGM = volGM or 100
			local tmpDoGM = doSoundGM

			tmpDoGM = ImGui.Checkbox('GM Alert##AlertMaster', tmpDoGM)
			if tmpDoGM ~= doSoundGM then
				doSoundGM = tmpDoGM
				settings[CharConfig]['doSoundGM'] = doSoundGM
				save_settings()
			end
			ImGui.SameLine()
			ImGui.SetNextItemWidth(70)
			tmpSndGM = ImGui.InputText('Filename##GMSND', tmpSndGM)
			if tmpSndGM ~= soundGM then
				soundGM = tmpSndGM
			end
			ImGui.SameLine()
			ImGui.SetNextItemWidth(100)
			tmpVolGM = ImGui.InputFloat('Volume##GMVOL', tmpVolGM, 0.1)
			if tmpVolGM ~= volGM then
				volGM = tmpVolGM
			end
			ImGui.SameLine()
			if ImGui.Button("Test and Save##GMALERT") then
				setVolume(volGM)
				playSound(soundGM)
				settings[CharConfig]['volGM'] = volGM
				settings[CharConfig]['soundGM'] = soundGM
				save_settings()
			end
			--- PC Alerts ---
			ImGui.SeparatorText("PC Alerts##AlertMaster")
			--- tmp vars to change ---
			local tmpSndPC = soundPC or 'PC.wav'
			local tmpVolPC = volPC or 100
			local tmpDoPC = doSoundPC

			tmpDoPC = ImGui.Checkbox('PC Alert##AlertMaster', tmpDoPC)
			if tmpDoPC ~= doSoundPC then
				doSoundPC = tmpDoPC
				settings[CharConfig]['doSoundPC'] = doSoundPC
				save_settings()
			end
			ImGui.SameLine()
			ImGui.SetNextItemWidth(70)
			tmpSndPC = ImGui.InputText('Filename##PCSND', tmpSndPC)
			if tmpSndPC ~= soundPC then
				soundPC = tmpSndPC
			end
			ImGui.SameLine()
			ImGui.SetNextItemWidth(100)
			tmpVolPC = ImGui.InputFloat('Volume##PCVOL', tmpVolPC, 0.1)
			if tmpVolPC ~= volPC then
				volPC = tmpVolPC
			end
			ImGui.SameLine()
			if ImGui.Button("Test and Save##PCALERT") then
				setVolume(volPC)
				playSound(soundPC)
				settings[CharConfig]['volPC'] = volPC
				settings[CharConfig]['soundPC'] = soundPC
				save_settings()
			end
			--- PC Announce ---
			ImGui.SeparatorText("PC Announce##AlertMaster")
			--- tmp vars to change ---
			local tmpSndPCEntered = soundPCEntered or 'PC.wav'
			local tmpVolPCEntered = volPCEntered or 100
			local tmpDoPCEntered = doSoundPCEntered
			local tmpSndPCLeft = soundPCLeft or 'PC.wav'
			local tmpVolPCLeft = volPCLeft or 100
			local tmpDoPCLeft = doSoundPCLeft

			tmpDoPCEntered = ImGui.Checkbox('PC Entered##AlertMaster', tmpDoPCEntered)
			if doSoundPCEntered ~= tmpDoPCEntered then
				doSoundPCEntered = tmpDoPCEntered
				settings[CharConfig]['doSoundPCEntered'] = doSoundPCEntered
				save_settings()
			end
			ImGui.SameLine()
			ImGui.SetNextItemWidth(70)
			tmpSndPCEntered = ImGui.InputText('Filename##PCENTEREDSND', tmpSndPCEntered)
			if tmpSndPCEntered ~= soundPCEntered then
				soundPCEntered = tmpSndPCEntered
			end
			ImGui.SameLine()
			ImGui.SetNextItemWidth(100)
			tmpVolPCEntered = ImGui.InputFloat('Volume##PCENTEREDVOL', tmpVolPCEntered, 0.1)
			if tmpVolPCEntered ~= volPCEntered then
				volPCEntered = tmpVolPCEntered
			end
			ImGui.SameLine()
			if ImGui.Button("Test and Save##PCENTEREDALERT") then
				setVolume(volPCEntered)
				playSound(soundPCEntered)
				settings[CharConfig]['volPCEntered'] = volPCEntered
				settings[CharConfig]['soundPCEntered'] = soundPCEntered
				save_settings()
			end
			tmpDoPCLeft = ImGui.Checkbox('PC Left##AlertMaster', tmpDoPCLeft)
			if doSoundPCLeft ~= tmpDoPCLeft then
				doSoundPCLeft = tmpDoPCLeft
				settings[CharConfig]['doSoundPCLeft'] = doSoundPCLeft
				save_settings()
			end
			ImGui.SameLine()
			ImGui.SetNextItemWidth(70)
			tmpSndPCLeft = ImGui.InputText('Filename##PCLEFTSND', tmpSndPCLeft)
			if tmpSndPCLeft ~= soundPCLeft then
				soundPCLeft = tmpSndPCLeft
			end
			ImGui.SameLine()
			ImGui.SetNextItemWidth(100)
			tmpVolPCLeft = ImGui.InputFloat('Volume##PCLEFTVOL', tmpVolPCLeft, 0.1)
			if tmpVolPCLeft ~= volPCLeft then
				volPCLeft = tmpVolPCLeft
			end
			ImGui.SameLine()
			if ImGui.Button("Test and Save##PCLEFTALERT") then
				setVolume(volPCLeft)
				playSound(soundPCLeft)
				settings[CharConfig]['volPCLeft'] = volPCLeft
				settings[CharConfig]['soundPCLeft'] = soundPCLeft
				save_settings()
			end


			--- NPC Alerts ---
			ImGui.SeparatorText("NPC Alerts##AlertMaster")
			--- tmp vars to change ---
			local tmpSndNPC = soundNPC or 'NPC.wav'
			local tmpVolNPC = volNPC or 100
			local tmpDoNPC = doSoundNPC

			tmpDoNPC = ImGui.Checkbox('NPC Alert##AlertMaster', tmpDoNPC)
			if doSoundNPC ~= tmpDoNPC then
				doSoundNPC = tmpDoNPC
				settings[CharConfig]['doSoundNPC'] = doSoundNPC
				save_settings()
			end
			ImGui.SameLine()
			ImGui.SetNextItemWidth(70)
			tmpSndNPC = ImGui.InputText('Filename##NPCSND', tmpSndNPC)
			if tmpSndNPC ~= soundNPC then
				soundNPC = tmpSndNPC
			end
			ImGui.SameLine()
			ImGui.SetNextItemWidth(100)
			tmpVolNPC = ImGui.InputFloat('Volume##NPCVOL', tmpVolNPC, 0.1)
			if tmpVolNPC ~= volNPC then
				volNPC = tmpVolNPC
			end
			ImGui.SameLine()
			if ImGui.Button("Test and Save##NPCALERT") then
				setVolume(volNPC)
				playSound(soundNPC)
				settings[CharConfig]['volNPC'] = volNPC
				settings[CharConfig]['soundNPC'] = soundNPC
				save_settings()
			end
		end

		if ImGui.CollapsingHeader("Commands") then
			if ImGui.BeginTable("CommandTable", 2, ImGuiTableFlags.Resizable) then
				ImGui.TableSetupColumn("Command", ImGuiTableColumnFlags.None)
				ImGui.TableSetupColumn("Text", ImGuiTableColumnFlags.None)
				for key, command in pairs(settings[CharCommands]) do
					local tmpCmd = command
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					ImGui.Text(key)
					ImGui.TableNextColumn()
					tmpCmd = ImGui.InputText("##" .. key, tmpCmd)
					if tmpCmd ~= command then
						if tmpCmd == '' or tmpCmd == nil then
							settings[CharCommands][key] = nil
						else
							settings[CharCommands][key] = tmpCmd
						end
						save_settings()
					end
				end
				ImGui.EndTable()
			end
		end

		if ImGui.Button('Close') then
			openConfigGUI = false
			settings[CharConfig]['theme'] = useThemeName
			settings[CharConfig]['ZoomLvl'] = ZoomLvl
			save_settings()
		end
	end
	if StyleCountConf > 0 then ImGui.PopStyleVar(StyleCountConf) end
	if ColorCountConf > 0 then ImGui.PopStyleColor(ColorCountConf) end
	ImGui.SetWindowFontScale(1)
	ImGui.End()
end

local function BuildAlertRows() -- Build the Button Rows for the GUI Window
	if zone_id == Zone.ID() then
		-- Start a new table for alerts
		local sizeX = ImGui.GetContentRegionAvail() - 4
		if ImGui.BeginTable("AlertTable", 3, Module.GUI_Alert.Table.Flags) then
			ImGui.TableSetupScrollFreeze(0, 1)
			ImGui.TableSetupColumn("Name", bit32.bor(ImGuiTableColumnFlags.DefaultSort), 90, Module.GUI_Alert.Table.Column_ID.MobName)
			ImGui.TableSetupColumn("Dist", bit32.bor(ImGuiTableColumnFlags.DefaultSort), 50, Module.GUI_Alert.Table.Column_ID.MobDist)
			ImGui.TableSetupColumn("Dir", bit32.bor(ImGuiTableColumnFlags.NoResize, ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.NoSort), 30,
				Module.GUI_Alert.Table.Column_ID.MobDirection)
			ImGui.TableHeadersRow()
			local sortSpecsAlerts = ImGui.TableGetSortSpecs()

			if sortSpecsAlerts and (sortSpecsAlerts.SpecsDirty or Module.GUI_Alert.Refresh.Sort.Rules) then
				if #Table_Cache.Alerts > 0 then
					Module.GUI_Alert.Table.SortSpecs = sortSpecsAlerts
					table.sort(Table_Cache.Alerts, AlertTableSortSpecs)
					Module.GUI_Alert.Table.SortSpecs = nil
				end
				sortSpecsAlerts.SpecsDirty = false
				Module.GUI_Alert.Refresh.Sort.Rules = false
			end
			local clipper = ImGuiListClipper.new()
			clipper:Begin(#Table_Cache.Alerts)
			while clipper:Step() do
				for i = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
					local entry = Table_Cache.Alerts[i + 1]
					ImGui.PushID(entry.ID)
					ImGui.TableNextRow()
					DrawAlertRuleRow(entry)
					ImGui.PopID()
				end
			end
			clipper:End()

			ImGui.EndTable()
		end
	end
end

function DrawAlertGUI() -- Draw GUI Window
	if AlertWindowOpen then
		local opened = false
		ColorCountAlert = 0
		StyleCountAlert = 0
		if currZone ~= lastZone then return end
		-- ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 5)
		ColorCountAlert, StyleCountAlert = DrawTheme(useThemeName)
		AlertWindowOpen, opened = ImGui.Begin("Alert Window##" .. MyUI_CharLoaded, AlertWindowOpen, Module.GUI_Alert.Flags)
		if not opened then
			AlertWindowOpen = false
			AlertWindow_Show = false
			ImGui.PopStyleColor(ColorCountAlert)
			ImGui.PopStyleVar(StyleCountAlert)
			ImGui.SetWindowFontScale(1)
			ImGui.End()
			if remindNPC > 0 then
				alertTime = os.time()
			else
				spawnAlerts = {}
			end
		else
			ImGui.SetWindowFontScale(ZoomLvl)
			BuildAlertRows()
		end
		ImGui.PopStyleVar(StyleCountAlert)
		ImGui.PopStyleColor(ColorCountAlert)
		ImGui.SetWindowFontScale(1)
		ImGui.End()
	end
end

function Module.RenderGUI()
	DrawSearchWindow()
	DrawAlertGUI()
	Config_GUI()
end

local load_binds = function()
	local bind_alertmaster = function(cmd, val)
		local zone = Zone.ShortName()
		local val_num = tonumber(val, 10)
		local val_str = tostring(val):gsub("\"", "")
		-- enable/disable
		if cmd == 'on' then
			active = true
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayAlert Master enabled.')
		elseif cmd == 'off' then
			active = false
			tGMs, tAnnounce, tPlayers, tSpawns = {}, {}, {}, {}
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayAlert Master disabled.')
		end

		if cmd == 'quit' or cmd == 'exit' then
			Module.IsRunning = false
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayAlert Master\ao Shutting Down.')
		end
		-- Alert Show / Hide
		if cmd == 'popup' then
			if AlertWindowOpen then
				AlertWindowOpen = false
				AlertWindow_Show = false
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayClosing Alert Window.')
			else
				AlertWindowOpen = true
				AlertWindow_Show = true
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayShowing Alert Window.')
			end
		end
		-- Search Gui Show / Hide
		if cmd == 'show' then
			if SearchWindowOpen then
				SearchWindow_Show = false
				SearchWindowOpen = false
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayClosing Search UI.')
			else
				RefreshZone()
				SearchWindow_Show = true
				SearchWindowOpen = true
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayShowing Search UI.')
			end
		end
		-- Alert Popup On/Off Toggle
		if cmd == 'doalert' then
			if doAlert then
				doAlert = false
				settings[CharConfig]['popup'] = doAlert
				save_settings()
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayAlert PopUp Disabled.')
			else
				doAlert = true
				settings[CharConfig]['popup'] = doAlert
				save_settings()
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayAlert PopUp Enabled.')
			end
		end
		-- Aggro Display On/Off Toggle
		if cmd == 'aggro' then
			if showAggro then
				showAggro = false
				settings[CharConfig]['aggro'] = showAggro
				save_settings()
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayShow Aggro Disabled.')
			else
				showAggro = true
				settings[CharConfig]['aggro'] = showAggro
				save_settings()
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayShow Aggro Enabled.')
			end
		end
		-- Beep On/Off Toggle
		if cmd == 'beep' then
			if doBeep then
				doBeep = false
				settings[CharConfig]['beep'] = doBeep
				save_settings()
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayBeep Alerts Disabled.')
			else
				doBeep = true
				settings[CharConfig]['beep'] = doBeep
				save_settings()
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayBeep Alerts Enabled.')
			end
		end
		-- radius
		if cmd == 'radius' and val_num > 0 then
			settings[CharConfig]['radius'] = val_num
			radius = val_num
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayUpdated radius = ' .. radius)
		end
		-- zradius
		if cmd == 'zradius' and val_num > 0 then
			settings[CharConfig]['zradius'] = val_num
			zradius = val_num
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayUpdated zradius = ' .. zradius)
		end
		-- delay
		if cmd == 'delay' and val_num > 0 then
			settings[CharConfig]['delay'] = val_num
			delay = val_num
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayDelay interval = ' .. delay)
		end
		---- Volumes ----
		if cmd == 'volnpc' and val_num > 0 then
			settings[CharConfig]['volNPC'] = val_num
			volNPC = val_num
			save_settings()
			setVolume(volNPC)
			playSound(soundNPC)
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayNPC Volume = ' .. volNPC)
		end
		if cmd == 'volpc' and val_num > 0 then
			settings[CharConfig]['volPC'] = val_num
			volPC = val_num
			save_settings()
			setVolume(volPC)
			playSound(soundPC)
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayPC Volume = ' .. volPC)
		end
		if cmd == 'volgm' and val_num > 0 then
			settings[CharConfig]['volGM'] = val_num
			volGM = val_num
			save_settings()
			setVolume(volGM)
			playSound(soundGM)
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayGM Volume = ' .. volGM)
		end
		----- Sounds -----
		if cmd == 'dosound' and val_str ~= nil then
			if val_str == 'npc' then
				doSoundNPC = not doSoundNPC
				settings[CharConfig]['doSoundNPC'] = doSoundNPC
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\aySetting doSoundNPC = ' .. tostring(doSoundNPC))
			elseif val_str == 'pc' then
				doSoundPC = not doSoundPC
				settings[CharConfig]['doSoundPC'] = doSoundPC
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\aySetting doSoundPC = ' .. tostring(doSoundPC))
			elseif val_str == 'gm' then
				doSoundGM = not doSoundGM
				settings[CharConfig]['doSoundGM'] = doSoundGM
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\aySetting doSoundGM = ' .. tostring(doSoundGM))
			end
			save_settings()
		end
		-- distfar Color Distance
		if cmd == 'distfar' and val_num > 0 then
			settings[CharConfig]['distfar'] = val_num
			DistColorRanges.red = val_num
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\arFar Range\a-t Greater than:\a-r' .. DistColorRanges.red .. '\ax')
		end
		-- distmid Color Distance
		if cmd == 'distmid' and val_num > 0 then
			settings[CharConfig]['distmid'] = val_num
			DistColorRanges.orange = val_num
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\aoMid Range\a-t Between: \a-g' .. DistColorRanges.orange .. ' \a-tand \a-r' .. DistColorRanges.red .. '\ax')
		end
		-- remind
		if cmd == 'remind' and val_num >= 0 then
			settings[CharConfig]['remind'] = val_num
			remind = val_num
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayRemind interval = ' .. remind)
		end
		if cmd == 'reload' then
			load_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, "\ayReloading Settings from File!")
		end
		if cmd == 'remindnpc' and val_num >= 0 then
			settings[CharConfig]['remindNPC'] = val_num
			remindNPC = val_num
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayRemind NPC interval = ' .. remindNPC .. 'minutes')
		end
		-- enabling/disabling spawn alerts
		if cmd == 'spawns' and val_str == 'on' then
			settings[CharConfig]['spawns'] = true
			save_settings()
			spawns = true
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\aySpawn alerting enabled.')
		elseif cmd == 'spawns' and val_str == 'off' then
			settings[CharConfig]['spawns'] = false
			save_settings()
			spawns = false
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\aySpawn alerting disabled.')
		end
		-- enabling/disabling pcs alerts
		if cmd == 'pcs' and val_str == 'on' then
			settings[CharConfig]['pcs'] = true
			save_settings()
			pcs = true
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayPC alerting enabled.')
		elseif cmd == 'pcs' and val_str == 'off' then
			settings[CharConfig]['pcs'] = false
			save_settings()
			pcs = false
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayPC alerting disabled.')
		end
		-- enabling/disabling pcs alerts
		if cmd == 'reload' then
			load_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, "\ayReloading Settings from File!")
		end
		local sCount = #tSpawns or 0
		-- adding/removing/listing spawn alerts for current zone
		if cmd == 'spawnadd' then
			if val_str ~= nil and val_str ~= 'nil' then
				val_str = mq.TLO.Target.DisplayName()
			elseif mq.TLO.Target() ~= nil and mq.TLO.Target.Type() == 'NPC' then
				val_str = mq.TLO.Target.DisplayName()
			else
				MyUI_Utils.PrintOutput('AlertMaster', true, "\arNO \aoSpawn supplied\aw or \agTarget")
				return
			end
			addSpawnToList(val_str)
			-- -- if the zone doesn't exist in ini yet, create a new table
			-- if settings[zone] == nil then settings[zone] = {} end

			-- -- if the zone does exist in the ini, spin over entries and make sure we aren't duplicating
			-- for k, v in pairs(settings[zone]) do
			-- 	if settings[zone][k] == val_str then
			-- 		MyUI_Utils.PrintOutput('AlertMaster',nil,"\aySpawn alert \""..val_str.."\" already exists.")
			-- 		return
			-- 	end
			-- 	sCount = sCount + 1
			-- end
			-- -- if we made it this far, the spawn isn't tracked -- add it to the table and store to ini
			-- settings[zone]['Spawn'..sCount+1] = val_str
			-- save_settings()
			-- MyUI_Utils.PrintOutput('AlertMaster',nil,'\ayAdded spawn alert for '..val_str..' in '..zone)
		elseif cmd == 'spawndel' and val_str:len() > 0 then
			-- Identify and remove the spawn from the ini
			local found = false
			for k, v in pairs(settings[zone]) do
				if v == val_str then
					settings[zone][k] = nil
					found = true
					break
				end
			end
			if found then
				-- Rebuild the table to eliminate gaps
				local newTable = {}
				for _, v in pairs(settings[zone]) do
					table.insert(newTable, v)
				end
				-- Clear the existing table
				for k in pairs(settings[zone]) do
					settings[zone][k] = nil
				end
				-- Repopulate the table with renumbered spawns
				for i, v in ipairs(newTable) do
					settings[zone]['Spawn' .. i] = v
				end
				save_settings()
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayRemoved spawn alert for ' .. val_str .. ' in ' .. zone)
			else
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\aySpawn alert for ' .. val_str .. ' not found in ' .. zone)
			end
		elseif cmd == 'spawnlist' then
			-- if sCount > 0 then
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\aySpawn Alerts (\a-t' .. zone .. '\ax): ')
			local tmp = {}
			for k, v in pairs(settings[zone]) do table.insert(tmp, v) end
			for k, v in ipairs(tmp) do
				local up = false
				local name = ''
				for _, spawn in pairs(tSpawns) do
					if spawn ~= nil then
						if string.find(v, v) ~= nil then
							up = true
							name = v
							break
						end
					end
				end
				if up then
					MyUI_Utils.PrintOutput('AlertMaster', nil, string.format('\ag[Live] %s ("%s")\ax', name, v))
				else
					MyUI_Utils.PrintOutput('AlertMaster', nil, string.format('\a-t[Dead] %s\ax', v))
				end
			end
			-- else
			-- 	MyUI_Utils.PrintOutput('AlertMaster',nil,'\aySpawn Alerts (\a-t' .. zone .. '\ax): No alerts found')
			-- end
		end

		-- adding/removing/listing commands
		local cmdCount = 0
		for k, v in pairs(settings[CharCommands]) do
			cmdCount = cmdCount + 1
		end
		if cmd == 'cmdadd' and val_str:len() > 0 then
			-- if the section doesn't exist in ini yet, create a new table
			if settings[CharCommands] == nil then settings[CharCommands] = {} end
			-- if the section does exist in the ini, spin over entries and make sure we aren't duplicating
			for k, v in pairs(settings[CharCommands]) do
				if settings[CharCommands][k] == val_str then
					MyUI_Utils.PrintOutput('AlertMaster', nil, "\ayCommand \"" .. val_str .. "\" already exists.")
					return
				end
				cmdCount = cmdCount + 1
			end
			-- if we made it this far, the command is new -- add it to the table and store to ini
			settings[CharCommands]['Cmd' .. cmdCount + 1] = val_str
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayAdded Command \"' .. val_str .. '\"')
		elseif cmd == 'cmddel' and val_str:len() > 0 then
			-- remove from the ini
			for k, v in pairs(settings[CharCommands]) do
				if k:lower() == val_str:lower() then
					settings[CharCommands][k] = nil
					break
				end
				if settings[CharCommands][k] == val_str then
					settings[CharCommands][k] = nil
					break
				end
			end
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayRemoved Command \"' .. val_str .. '\"')
		elseif cmd == 'cmdlist' then
			if cmdCount > 0 then
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayCommands (\a-t' .. MyUI_CharLoaded .. '\ax): ')
				for k, v in pairs(settings[CharCommands]) do
					MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\a-t' .. k .. ' - ' .. v)
				end
			else
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayCommands (\a-t' .. MyUI_CharLoaded .. '\ax): No commands configured.')
			end
		end
		-- adding/removing/listing ignored pcs
		local ignoreCount = 0
		if cmd == 'ignoreadd' and val_str:len() > 0 then
			-- if the section doesn't exist in ini yet, create a new table
			if settings['Ignore'] == nil then settings['Ignore'] = {} end
			-- if the section does exist in the ini, spin over entries and make sure we aren't duplicating
			for k, v in pairs(settings['Ignore']) do
				if settings['Ignore'][k] == val_str then
					MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayAlready ignoring \"' .. val_str .. '\".')
					return
				end
				ignoreCount = ignoreCount + 1
			end
			-- if we made it this far, the command is new -- add it to the table and store to ini
			settings['Ignore']['Ignore' .. ignoreCount + 1] = val_str
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayNow ignoring \"' .. val_str .. '\"')
		elseif cmd == 'ignoredel' and val_str:len() > 0 then
			-- remove from the ini
			for k, v in pairs(settings['Ignore']) do
				if settings['Ignore'][k] == val_str then settings['Ignore'][k] = nil end
			end
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayNo longer ignoring \"' .. val_str .. '\"')
		elseif cmd == 'ignorelist' then
			if ignoreCount > 0 then
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayIgnore List (\a-t' .. MyUI_CharLoaded .. '\ax): ')
				for k, v in pairs(settings['Ignore']) do
					MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\a-t' .. k .. ' - ' .. v)
				end
			else
				MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayIgnore List (\a-t' .. MyUI_CharLoaded .. '\ax): No ignore list configured.')
			end
		end
		-- Announce Alerts
		if cmd == 'announce' and val_str == 'on' then
			announce = true
			settings[CharConfig]['announce'] = announce
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayNow announcing players entering/exiting the zone.')
		elseif cmd == 'announce' and val_str == 'off' then
			announce = false
			settings[CharConfig]['announce'] = announce
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayNo longer announcing players entering/exiting the zone.')
		end
		-- GM Checks
		if cmd == 'gm' and val_str == 'on' then
			gms = true
			settings[CharConfig]['gms'] = gms
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayGM Alerts enabled.')
		elseif cmd == 'gm' and val_str == 'off' then
			gms = false
			settings[CharConfig]['gms'] = gms
			save_settings()
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayGM Alerts disabled.')
		end
		-- Status
		if cmd == 'status' then print_status() end
		if cmd == nil or cmd == 'help' then
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayAlert Master Usage:')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-y- General -')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am status\a-t -- print current alerting status/settings')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am help\a-t -- print help/usage')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am on|off\a-t -- toggle alerts')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am gm on|off\a-t -- toggle GM alerts')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am pcs on|off\a-t -- toggle PC alerts')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am spawns on|off\a-t -- toggle spawn alerts')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am beep on|off\a-t -- toggle Audible Beep alerts')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am doalert \a-t -- toggle Popup alerts')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am announce on|off\a-t -- toggle announcing PCs entering/exiting the zone')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am radius #\a-t -- configure alert radius (integer)')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am reload #\a-t -- reload the Config File')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am zradius #\a-t -- configure alert z-radius (integer)')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am delay #\a-t -- configure alert check delay (seconds)')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am remind #\a-t -- configure Player and GM alert reminder interval (seconds)')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am remindnpc #\a-t -- configure NPC alert reminder interval (Minutes)')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am popup\a-t -- Toggles Display of Alert Window')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am reload\a-t -- Reload the ini file')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am distmid\a-t -- Sets distance the color changes from \a-gGreen \a-tto \a-oOrange')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am distfar\a-t -- Sets the distnace the color changes from \a-oOrange \a-tto \a-rRed')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-y- Sounds -')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am dosound pc\a-t -- toggle PC custom sound alerts')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am dosound npc\a-t -- toggle NPC custom sound alerts')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am dosound gm\a-t -- toggle GM custom sound alerts')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am volpc 1-100\a-t -- Set PC custom sound Volume 1-100')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am volnpc 1-100\a-t -- Set NPC custom sound Volume 1-100')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am volgm 1-100\a-t -- Set GM custom sound Volume 1-100')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-y- Ignore List -')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am ignoreadd pcname\a-t -- add pc to the ignore list')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am ignoredel pcname\a-t -- delete pc from the ignore list')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am ignorelist\a-t -- display ignore list')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-y- Spawns -')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am spawnadd npc\a-t -- add monster to the list of tracked spawns')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am spawndel npc\a-t -- delete monster from the list of tracked spawns')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am spawnlist\a-t -- display monsters being tracked for the current zone')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am show\a-t -- Toggles display of Search Window and Spawns for the current zone')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am aggro\a-t -- Toggles display of Aggro status bars in the search window.')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\a-y- Commands - executed when players remain in the alert radius for the reminder interval')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am cmdadd command\a-t -- add command to run when someone enters your alert radius')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am cmddel command\a-t -- delete command to run when someone enters your alert radius')
			MyUI_Utils.PrintOutput('AlertMaster', nil, '\t\ay/am cmdlist\a-t -- display command(s) to run when someone enters your alert radius')
		end
	end
	mq.bind('/alertmaster', bind_alertmaster)
	mq.bind('/am', bind_alertmaster)
end

function Module.Unload()
	mq.unbind('/alertmaster')
	mq.unbind('/am')
end

local setup = function()
	originalVolume = getVolume()
	active = true
	radius = arg[1] or 200
	zradius = arg[2] or 100
	currZone = mq.TLO.Zone.ID()
	lastZone = currZone
	if mq.TLO.Plugin('mq2eqbc').IsLoaded() then groupCmd = '/bcaa /' end
	load_settings()
	load_binds()
	-- Kickstart the data
	Module.GUI_Main.Refresh.Table.Rules = true
	Module.GUI_Main.Refresh.Table.Filtered = true
	Module.GUI_Main.Refresh.Table.Unhandled = true
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\ayAlert Master version:\a-g' ..
		amVer .. '\n' .. MsgPrefix() .. '\ayOriginal by (\a-to_O\ay) Special.Ed (\a-tO_o\ay)\n' .. MsgPrefix() .. '\ayUpdated by (\a-tO_o\ay) Grimmier (\a-to_O\ay)')
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\atLoaded ' .. settings_file)
	MyUI_Utils.PrintOutput('AlertMaster', nil, '\ay/am help for usage')
	print_status()
	RefreshZone()
	Module.IsRunning = true
	if not loadedExeternally then
		mq.imgui.init(Module.Name, Module.RenderGUI)
		Module.LocalLoop()
	end
end

local cTime = os.time()
local firstRun = true
Module.MainLoop = function()
	-- while true do
	if currZone ~= lastZone then
		numAlerts = 0
		RefreshZone()
		lastZone = currZone
	end
	if loadedExeternally then
		---@diagnostic disable-next-line: undefined-global
		if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
	end

	if not loadedExeternally or os.time() - cTime > delay or firstRun then
		if mq.TLO.Window('CharacterListWnd').Open() then return false end
		currZone = mq.TLO.Zone.ID()
		check_for_zone_change()
		check_for_spawns() -- always refresh spawn list and only alert if not a safe zone.(checked later in the function)
		if check_safe_zone() ~= true then
			check_for_gms()
			check_for_announce()
			check_for_pcs()

			if ((os.time() - alertTime) > (remindNPC * 60) and numAlerts > 0) then -- if we're past the alert remindnpc time and we have alerts to give
				-- do text alerts
				for _, v in pairs(tSpawns) do
					if v ~= nil then
						local cleanName = v.DisplayName ~= nil and v.DisplayName or 'Unknown'
						local distance = math.floor(v.Spawn.Distance() or 0)
						MyUI_Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. '\ag' .. cleanName .. '\ax spawn alert! ' .. distance .. ' units away.')
					end
				end
				--do beep alerts
				if doBeep or doSoundNPC then
					if doSoundNPC then
						setVolume(volNPC)
						playSound(soundNPC)
					else
						mq.cmdf('/beep')
					end
				end
				--do popup alerts
				if (AlertWindow_Show == false) then
					if doAlert then
						AlertWindow_Show = true
						AlertWindowOpen = true
						if not AlertWindowOpen then DrawAlertGUI() end
					end
				end
				--reset alertTime to current time
				alertTime = os.time()
			end
		end

		cTime = os.time()
		firstRun = false
	end

	if playing and playTime > 0 then
		local sTime = os.time()
		if sTime - playTime > 2 then
			resetVolume()
		end
	end

	if not playing and playTime == 0 then
		-- we aren't playing anything so we can double check the original voulme wasn't changed by the user.
		originalVolume = getVolume()
	end

	if Module.GUI_Main.Refresh.Table.Unhandled then RefreshUnhandled() end
	if SearchWindow_Show == true or #Table_Cache.Mobs < 1 then RefreshZone() end
end
if mq.TLO.EverQuest.GameState() ~= "INGAME" then
	printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", Module.Name)
	mq.exit()
end
function Module.LocalLoop()
	while Module.IsRunning do
		Module.MainLoop()
		mq.delay(delay .. 's')
	end
end

setup()

return Module
