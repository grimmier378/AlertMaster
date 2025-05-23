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
	* /alertmaster show will toggle the search window.
	* /alertmaster popup will toggle the alert popup window.
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
local ZoneNames = require("defaults.ZoneNames")

Module = {}
Module.Name = 'AlertMaster'
Module.Path = string.format("%s/%s/", mq.luaDir, Module.Name)
if mq.TLO.EverQuest.GameState() ~= "INGAME" then
	printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", Module.Name)
	mq.exit()
end
---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false
if not loadedExeternally then
	Module.Utils       = require('lib.common')
	Module.CharLoaded  = mq.TLO.Me.DisplayName()
	Module.Colors      = require('lib.colors')
	Module.Guild       = mq.TLO.Me.Guild() or 'NoGuild'
	Module.Icons       = require('mq.ICONS')
	Module.ThemeLoader = require('lib.theme_loader')
	Module.ThemeFile   = Module.ThemeFile == nil and string.format('%s/MyUI/ThemeZ.lua', mq.configDir) or Module.ThemeFile
	Module.Theme       = require('defaults.themes')
	Module.Path        = string.format("%s/%s/", mq.luaDir, Module.Name)
	Module.Server      = mq.TLO.EverQuest.Server()
	Module.Build       = mq.TLO.MacroQuest.BuildName()
else
	Module.Utils = MyUI_Utils
	Module.CharLoaded = MyUI_CharLoaded
	Module.Colors = MyUI_Colors
	Module.Guild = MyUI_Guild
	Module.Icons = MyUI_Icons
	Module.ThemeLoader = MyUI_ThemeLoader
	Module.ThemeFile = MyUI_ThemeFile
	Module.Theme = MyUI_Theme
	Module.Path = MyUI_Path
	Module.Server = MyUI_Server
	Module.Build = MyUI_Build
end
Module.SoundPath                                                                                                                       = string.format("%s/sounds/default/",
	Module.Path)
local Utils                                                                                                                            = Module.Utils
local ToggleFlags                                                                                                                      = bit32.bor(
	Utils.ImGuiToggleFlags.PulseOnHover,
	Utils.ImGuiToggleFlags.RightLabel)

-- Variables
local arg                                                                                                                              = { ..., }
local amVer                                                                                                                            = '2.07'
local SpawnCount                                                                                                                       = mq.TLO.SpawnCount
local NearestSpawn                                                                                                                     = mq.TLO.NearestSpawn
local smSettings                                                                                                                       = mq.configDir .. '/MQ2SpawnMaster.ini'
local config_dir                                                                                                                       = mq.TLO.MacroQuest.Path():gsub('\\', '/')
local settings_file                                                                                                                    = '/config/AlertMaster.ini'
local settings_path                                                                                                                    = config_dir .. settings_file
local smImportList                                                                                                                     = mq.configDir .. '/am_imports.lua'
local Group                                                                                                                            = mq.TLO.Group
local Raid                                                                                                                             = mq.TLO.Raid
local Zone                                                                                                                             = mq.TLO.Zone
local groupCmd                                                                                                                         = '/dgae ' -- assumes DanNet, if EQBC found we switch to '/bcca /'
local angle                                                                                                                            = 0
local CharConfig                                                                                                                       = 'Char_' ..
	mq.TLO.Me.DisplayName() .. '_Config'
local CharCommands                                                                                                                     = 'Char_' ..
	mq.TLO.Me.DisplayName() .. '_Commands'
local newConfigFile                                                                                                                    = string.format(
	"%s/MyUI/AlertMaster/%s/%s.lua", mq.configDir, Module.Server, Module.CharLoaded)
local defaultConfig                                                                                                                    = {
	delay = 1,
	remindNPC = 5,
	remind = 30,
	aggro = false,
	pcs = true,
	spawns = true,
	gms = true,
	announce = false,
	ignoreguild = true,
	beep = false,
	popup = false,
	distmid = 600,
	distfar = 1200,
	locked = false,
}
local tSafeZones, spawnAlerts, spawnsSpawnMaster, settings                                                                             = {}, {}, {}, {}
local npcs, tAnnounce, tPlayers, tSpawns, tGMs                                                                                         = {}, {}, {}, {}, {}
local alertTime, numAlerts                                                                                                             = 0, 0
local volNPC, volGM, volPC, volPCEntered, volPCLeft                                                                                    = 100, 100, 100, 100, 100
local zone_id                                                                                                                          = Zone.ID() or 0
local soundGM                                                                                                                          = 'GM.wav'
local soundNPC                                                                                                                         = 'NPC.wav'
local soundPC                                                                                                                          = 'PC.wav'
local soundPCEntered                                                                                                                   = 'PCEntered.wav'
local soundPCLeft                                                                                                                      = 'PCLeft.wav'
local doBeep, doAlert, DoDrawArrow, haveSM, importZone, doSoundNPC, doSoundGM, doSoundPC, forceImport, doSoundPCEntered, doSoundPCLeft = false, false, false, false, false, false,
	false, false, false, false, false
local delay, remind, pcs, spawns, gms, announce, ignoreguild, radius, zradius, remindNPC, showAggro                                    = 1, 30, true, true, true, false, true, 100,
	100, 5, true
-- [[ UI ]] --
local AlertWindow_Show, AlertWindowOpen, SearchWindowOpen, SearchWindow_Show, showTooltips, active                                     = false, false, false, false, true, false
local currentTab                                                                                                                       = "zone"
local newSpawnName                                                                                                                     = ''
local zSettings                                                                                                                        = false
local useThemeName                                                                                                                     = 'Default'
local openConfigGUI                                                                                                                    = false
local ZoomLvl                                                                                                                          = 1.0
local doOnce                                                                                                                           = true
local importedZones                                                                                                                    = {}
local originalVolume                                                                                                                   = 50
local playTime                                                                                                                         = 0
local playing                                                                                                                          = false
local currZone, lastZone
local newSMFile                                                                                                                        = mq.configDir .. '/MyUI/MQ2SpawnMaster.ini'
local execCommands                                                                                                                     = false

local DistColorRanges                                                                                                                  = {
	orange = 600, -- distance the color changes from green to orange
	red = 1200, -- distance the color changes from orange to red
}

local Table_Cache                                                                                                                      = {
	Rules = {},
	Unhandled = {},
	Mobs = {},
	Alerts = {},
}

local xTarTable                                                                                                                        = {}
local spawnListFlags                                                                                                                   = bit32.bor(
	ImGuiTableFlags.Resizable,
	ImGuiTableFlags.Sortable,
	-- ImGuiTableFlags.SizingFixedFit,
	ImGuiTableFlags.BordersV,
	ImGuiTableFlags.BordersOuter,
	ImGuiTableFlags.Reorderable,
	ImGuiTableFlags.ScrollY,
	ImGuiTableFlags.Hideable
)
Module.IsRunning                                                                                                                       = false
Module.GUI_Main                                                                                                                        = {
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

Module.GUI_Alert                                                                                                                       = {
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
Module.Settings                                                                                                                        = {}
Module.Settings[CharConfig]                                                                                                            = {}
Module.Settings[CharCommands]                                                                                                          = {}
------- Sounds ----------
local ffi                                                                                                                              = require("ffi")
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
local function MsgPrefix()
	return string.format('\aw[\a-tAlert Master\aw] ::\ax ')
end

local function GetCharZone()
	return '\aw[\ao' .. Module.CharLoaded .. '\aw] [\at' .. Zone.ShortName() .. '\aw] '
end

local function print_status()
	Module.Utils.PrintOutput('AlertMaster', nil, '\ayAlert Status: ' .. tostring(active and 'on' or 'off'))
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tPCs: \a-y' ..
		tostring(pcs) ..
		'\ax radius: \a-y' .. tostring(radius) .. '\ax zradius: \a-y' .. tostring(zradius) .. '\ax delay: \a-y' .. tostring(delay) ..
		's\ax remind: \a-y' .. tostring(remind) .. ' seconds\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tremindNPC: \a-y' .. tostring(remindNPC) .. '\at minutes\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\agClose Range\a-t Below: \a-g' .. tostring(DistColorRanges.orange) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\aoMid Range\a-t Between: \a-g' .. tostring(DistColorRanges.orange) .. '\a-t and \a-r' .. tostring(DistColorRanges.red) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\arLong Rage\a-t Greater than: \a-r' .. tostring(DistColorRanges.red) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tAnnounce PCs: \a-y' .. tostring(announce) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tSpawns (zone wide): \a-y' .. tostring(spawns) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tGMs (zone wide): \a-y' .. tostring(gms) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tPopup Alerts: \a-y' .. tostring(doAlert) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tBeep: \a-y' .. tostring(doBeep) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tSound PC Alerts: \a-y' .. tostring(doSoundPC) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tSound NPC Alerts: \a-y' .. tostring(doSoundNPC) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tSound GM Alerts: \a-y' .. tostring(doSoundGM) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tVolume PC Alerts: \a-y' .. tostring(volPC) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tVolume NPC Alerts: \a-y' .. tostring(volNPC) .. '\ax')
	Module.Utils.PrintOutput('AlertMaster', nil, '\a-tVolume GM Alerts: \a-y' .. tostring(volGM) .. '\ax')
end

local function save_settings()
	LIP.save(settings_path, settings)
	mq.pickle(newConfigFile, Module.Settings)
end

local function check_safe_zone()
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

local function set_settings()
	useThemeName = Module.Settings[CharConfig]['theme'] or 'Default'
	Module.Settings[CharConfig]['theme'] = useThemeName
	ZoomLvl = Module.Settings[CharConfig]['ZoomLvl'] or 1.0
	Module.Settings[CharConfig]['ZoomLvl'] = ZoomLvl
	delay = Module.Settings[CharConfig]['delay']
	remind = Module.Settings[CharConfig]['remind']
	pcs = Module.Settings[CharConfig]['pcs']
	spawns = Module.Settings[CharConfig]['spawns']
	gms = Module.Settings[CharConfig]['gms']
	announce = Module.Settings[CharConfig]['announce']
	ignoreguild = Module.Settings[CharConfig]['ignoreguild']
	radius = Module.Settings[CharConfig]['radius'] or radius
	Module.Settings[CharConfig]['radius'] = radius
	zradius = Module.Settings[CharConfig]['zradius'] or zradius
	Module.Settings[CharConfig]['zradius'] = zradius
	remindNPC = Module.Settings[CharConfig]['remindNPC'] or 5
	Module.Settings[CharConfig]['remindNPC'] = remindNPC
	doBeep = Module.Settings[CharConfig]['beep'] or false
	Module.Settings[CharConfig]['beep'] = doBeep
	DoDrawArrow = Module.Settings[CharConfig]['arrows'] or false
	Module.Settings[CharConfig]['arrows'] = DoDrawArrow
	Module.GUI_Main.Locked = Module.Settings[CharConfig]['locked'] or false
	Module.Settings[CharConfig]['locked'] = Module.GUI_Main.Locked
	doAlert = Module.Settings[CharConfig]['popup'] or false
	Module.Settings[CharConfig]['popup'] = doAlert
	showAggro = Module.Settings[CharConfig]['aggro'] or false
	Module.Settings[CharConfig]['aggro'] = showAggro
	DistColorRanges.orange = Module.Settings[CharConfig]['distmid'] or 600
	Module.Settings[CharConfig]['distmid'] = DistColorRanges.orange
	DistColorRanges.red = Module.Settings[CharConfig]['distfar'] or 1200
	Module.Settings[CharConfig]['distfar'] = DistColorRanges.red
	doSoundGM = Module.Settings[CharConfig]['doSoundGM'] or false
	Module.Settings[CharConfig]['doSoundGM'] = doSoundGM
	doSoundNPC = Module.Settings[CharConfig]['doSoundNPC'] or false
	Module.Settings[CharConfig]['doSoundNPC'] = doSoundNPC
	doSoundPC = Module.Settings[CharConfig]['doSoundPC'] or false
	Module.Settings[CharConfig]['doSoundPC'] = doSoundPC
	volGM = Module.Settings[CharConfig]['volGM'] or volGM
	Module.Settings[CharConfig]['volGM'] = volGM
	volNPC = Module.Settings[CharConfig]['volNPC'] or volNPC
	Module.Settings[CharConfig]['volNPC'] = volNPC
	volPC = Module.Settings[CharConfig]['volPC'] or volPC
	Module.Settings[CharConfig]['volPC'] = volPC
	soundGM = Module.Settings[CharConfig]['soundGM'] or soundGM
	Module.Settings[CharConfig]['soundGM'] = soundGM
	soundNPC = Module.Settings[CharConfig]['soundNPC'] or soundNPC
	Module.Settings[CharConfig]['soundNPC'] = soundNPC
	soundPC = Module.Settings[CharConfig]['soundPC'] or soundPC
	Module.Settings[CharConfig]['soundPC'] = soundPC
	soundPCEntered = Module.Settings[CharConfig]['soundPCEntered'] or soundPCEntered
	Module.Settings[CharConfig]['soundPCEntered'] = soundPCEntered
	soundPCLeft = Module.Settings[CharConfig]['soundPCLeft'] or soundPCLeft
	Module.Settings[CharConfig]['soundPCLeft'] = soundPCLeft
	volPCEntered = Module.Settings[CharConfig]['volPCEntered'] or volPCEntered
	Module.Settings[CharConfig]['volPCEntered'] = volPCEntered
	volPCLeft = Module.Settings[CharConfig]['volPCLeft'] or volPCLeft
	Module.Settings[CharConfig]['volPCLeft'] = volPCLeft
end

local function load_settings()
	local check = false
	if Module.Utils.File.Exists(newConfigFile) then
		local config = dofile(newConfigFile)
		Module.Settings[CharCommands] = config[CharCommands] or {}
		Module.Settings[CharConfig] = config[CharConfig] or {}
		check = true
	else
		Module.Settings[CharCommands] = {}
		Module.Settings[CharConfig] = defaultConfig
	end

	if Module.Utils.File.Exists(settings_path) then
		settings = LIP.load(settings_path)
		if not check then
			Module.Settings[CharConfig] = settings[CharConfig] or defaultConfig
			Module.Settings[CharCommands] = settings[CharCommands] or {}
			settings[CharConfig] = nil
			settings[CharCommands] = nil
			save_settings()
		end
	else
		settings = {
			Ignore = {},
		}
		save_settings()
	end

	if not loadedExeternally then
		if Module.Utils.File.Exists(Module.ThemeFile) then
			Module.Theme = dofile(Module.ThemeFile)
		end
	end

	if Module.Utils.File.Exists(newSMFile) then
		spawnsSpawnMaster = LIP.loadSM(newSMFile)
		haveSM = true
		importZone = true
	elseif Module.Utils.File.Exists(smSettings) then
		spawnsSpawnMaster = LIP.loadSM(smSettings)
		haveSM = true
		importZone = true
		for section, data in pairs(spawnsSpawnMaster) do
			local lwrSection = section:lower()
			if ZoneNames[lwrSection] then
				spawnsSpawnMaster[ZoneNames[lwrSection]] = data
				spawnsSpawnMaster[section] = nil
			end
		end
		LIP.save(newSMFile, spawnsSpawnMaster)
	end
	local exportFile = string.format("%s/MyUI/ExportSM.lua", mq.configDir)
	mq.pickle(exportFile, spawnsSpawnMaster)

	if Module.Utils.File.Exists(smImportList) then
		importedZones = dofile(smImportList)
	end

	useThemeName = Module.Theme.LoadTheme
	-- if this character doesn't have the sections in the ini, create them
	if Module.Settings[CharConfig] == nil then Module.Settings[CharConfig] = defaultConfig end
	if Module.Settings[CharCommands] == nil then Module.Settings[CharCommands] = {} end
	if settings['SafeZones'] == nil then settings['SafeZones'] = {} end
	set_settings()
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
		return Module.Colors.color('green')
	elseif distance >= DistColorRanges.orange and distance <= DistColorRanges.red then
		-- Orange color for Mid Range
		return Module.Colors.color('orange')
	else
		-- Red color for Far Distance
		return Module.Colors.color('red')
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
		local spawnA = mq.TLO.Spawn(a.MobID)
		local spawnB = mq.TLO.Spawn(b.MobID)
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
				if math.floor(spawnA.Distance()) < math.floor(spawnB.Distance()) then
					delta = -1
				elseif math.floor(spawnA.Distance()) > math.floor(spawnB.Distance()) then
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
local function should_include_player(spawn)
	local name = spawn.DisplayName()
	local guild = spawn.Guild() or 'None'
	-- if pc exists on the ignore list, skip
	if settings['Ignore'] ~= nil then
		for k, v in pairs(settings['Ignore']) do
			if v == name then return false end
		end
	end
	-- if pc is in group, raid or (optionally) guild, skip
	local in_group = Group.Members() ~= nil and Group.Member(name).Index() ~= nil
	local in_raid = Raid.Members() > 0 and Raid.Member(name)() ~= nil
	local in_guild = (ignoreguild and Module.Guild == guild)
	if in_group or in_raid or in_guild then return false end
	return true
end

local function run_char_commands()
	if Module.Settings[CharCommands] ~= nil then
		for k, cmd in pairs(Module.Settings[CharCommands]) do
			mq.cmdf(cmd)
			Module.Utils.PrintOutput('AlertMaster', nil, string.format('Ran command: "%s"', cmd))
		end
	end
end

local function spawn_search_players(search)
	local tmp = {}
	-- if check_safe_zone() then return tmp end
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

local function spawn_search_npcs()
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

local function check_for_gms()
	if active and gms then
		local tmp = spawn_search_players('gm')
		if tmp ~= nil then
			for name, v in pairs(tmp) do
				if tGMs[name] == nil then
					tGMs[name] = v
					Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' ' .. v.guild .. ' entered the zone. ' .. v.distance .. ' units away.')
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
					Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' loitering ' .. v.distance .. ' units away.')
				end
			end
			if tGMs ~= nil then
				for name, v in pairs(tGMs) do
					if tmp[name] == nil then
						tGMs[name] = nil
						Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' left the zone.')
					end
				end
			end
		end
	end
end

local function check_for_pcs()
	if active and pcs then
		local tmp = spawn_search_players('pc radius ' .. radius .. ' zradius ' .. zradius .. ' notid ' .. mq.TLO.Me.ID())
		local charZone = '\aw[\a-o' .. Module.CharLoaded .. '\aw|\at' .. Zone.ShortName() .. '\aw] '
		if tmp ~= nil then
			for name, v in pairs(tmp) do
				if tPlayers[name] == nil then
					tPlayers[name] = v
					Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' ' .. v.guild .. ' entered the alert radius. ' .. v.distance .. ' units away.')
					if doSoundPC then
						setVolume(volPC)
						playSound(soundPC)
					end
					-- run commands here
					run_char_commands()
				elseif (remind ~= nil and remind > 0) and tPlayers[name] ~= nil and os.difftime(os.time(), tPlayers[name].time) > remind then
					tPlayers[name].time = v.time
					if doSoundPC then
						setVolume(volPC)
						playSound(soundPC)
					end
					Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' loitering ' .. v.distance .. ' units away.')
					run_char_commands()
				end
			end
			if tPlayers ~= nil then
				for name, v in pairs(tPlayers) do
					if tmp[name] == nil then
						tPlayers[name] = nil
						Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' left the alert radius.')
					end
				end
			end
		end
	end
end

local function check_for_spawns()
	if active and spawns then
		local spawnAlertsUpdated, tableUpdate = false, false
		local charZone = '\aw[\a-o' .. Module.CharLoaded .. '\aw|\at' .. Zone.ShortName() .. '\aw] '
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
				Module.Utils.PrintOutput('AlertMaster', nil, string.format('\aw[\atAlert Master\aw] \agImported \aw[\ay%d\aw]\ag Spawn Master Spawns...', counter))
			end
		end
		local tmp = spawn_search_npcs()
		if tmp ~= nil then
			for id, v in pairs(tmp) do
				if tSpawns[id] == nil then
					if check_safe_zone() ~= true then
						Module.Utils.PrintOutput('AlertMaster', nil,
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
								Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. '\ag' .. tostring(v.DisplayName) .. '\ax was killed or despawned.')
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

local function check_for_announce()
	if active and announce then
		local tmp = spawn_search_players('pc notid ' .. mq.TLO.Me.ID())
		local charZone = '\aw[\a-o' .. Module.CharLoaded .. '\aw|\at' .. Zone.ShortName() .. '\aw] '
		if tmp ~= nil then
			for name, v in pairs(tmp) do
				if tAnnounce[name] == nil then
					tAnnounce[name] = v
					Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' ' .. v.guild .. ' entered the zone.')
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
						Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' left the zone.')
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

local function check_for_zone_change()
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

local function DrawToggles()
	local lockedIcon = Module.GUI_Main.Locked and Module.Icons.FA_LOCK .. '##lockTabButton' or
		Module.Icons.FA_UNLOCK .. '##lockTablButton'
	if ImGui.SmallButton(lockedIcon) then
		--ImGuiWindowFlags.NoMove
		Module.GUI_Main.Locked = not Module.GUI_Main.Locked
		Module.Settings[CharConfig]['locked'] = Module.GUI_Main.Locked
		save_settings()
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Lock Window")
		ImGui.EndTooltip()
	end

	local gIcon = Module.Icons.MD_SETTINGS
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


	-- Alert Popup Toggle Button
	if doAlert then
		ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_green')) -- Green for enabled
		if ImGui.SmallButton(Module.Icons.MD_ALARM) then mq.cmdf('/alertmaster doalert') end
		ImGui.PopStyleColor(1)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_red')) -- Red for disabled
		if ImGui.Button(Module.Icons.MD_ALARM_OFF) then mq.cmdf('/alertmaster doalert') end
		ImGui.PopStyleColor(1)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Toggle Popup Alerts On\\Off")
		ImGui.EndTooltip()
	end


	-- Beep Alert Toggle Button
	if doBeep then
		ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_green')) -- Green for enabled
		if ImGui.SmallButton(Module.Icons.FA_BELL_O) then mq.cmdf('/alertmaster beep') end
		ImGui.PopStyleColor(1)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_red')) -- Red for disabled
		if ImGui.Button(Module.Icons.FA_BELL_SLASH_O) then mq.cmdf('/alertmaster beep') end
		ImGui.PopStyleColor(1)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Toggle Beep Alerts On\\Off")
		ImGui.EndTooltip()
	end


	-- Alert Window Toggle Button
	if AlertWindowOpen then
		ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_green')) -- Green for enabled
		if ImGui.SmallButton(Module.Icons.MD_VISIBILITY) then mq.cmdf('/alertmaster popup') end
		ImGui.PopStyleColor(1)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_red')) -- Red for inactive state
		if ImGui.SmallButton(Module.Icons.MD_VISIBILITY_OFF) then mq.cmdf('/alertmaster popup') end
		ImGui.PopStyleColor(1)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Show\\Hide Alert Window")
		ImGui.EndTooltip()
	end


	-- Button to add the new spawn
	if ImGui.SmallButton(Module.Icons.FA_HASHTAG) then
		mq.cmdf('/alertmaster spawnadd ${Target}')
		npcs = settings[Zone.ShortName()] or {}
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Add Target #Dirty_Name0 to SpawnList")
		ImGui.EndTooltip()
	end


	-- Button to add the new spawn
	if ImGui.SmallButton(Module.Icons.FA_BULLSEYE) then
		mq.cmdf('/alertmaster spawnadd "${Target.DisplayName}"')
		npcs = settings[Zone.ShortName()] or {}
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Add Target Clean Name to SpawnList\nThis is handy if you are hunting a specific type of Mob,\ntarget a moss snake and add, you will get all \"a moss snake\"")
		ImGui.EndTooltip()
	end

	-- Arrow Status Toggle Button
	if DoDrawArrow then
		ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_green')) -- Green for enabled
		if ImGui.SmallButton(Module.Icons.FA_ARROW_UP) then
			DoDrawArrow, Module.Settings[CharConfig]['arrows'] = false, false
			save_settings()
		end
		ImGui.PopStyleColor(1)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_red')) -- Red for disabled
		if ImGui.SmallButton(Module.Icons.FA_ARROW_DOWN) then
			DoDrawArrow, Module.Settings[CharConfig]['arrows'] = true, true
			save_settings()
		end
		ImGui.PopStyleColor(1)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Toggle Drawing Arrows On\\Off")
		ImGui.EndTooltip()
	end

	-- Aggro Status Toggle Button
	if showAggro then
		ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_green')) -- Green for enabled
		if ImGui.SmallButton(Module.Icons.MD_PRIORITY_HIGH) then mq.cmdf('/alertmaster aggro') end
		ImGui.PopStyleColor(1)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_red')) -- Red for disabled
		if ImGui.SmallButton(Module.Icons.MD_PRIORITY_HIGH) then mq.cmdf('/alertmaster aggro') end
		ImGui.PopStyleColor(1)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Toggle Aggro Status On\\Off")
		ImGui.EndTooltip()
	end

	-- Alert Master Scanning Toggle Button
	if active then
		ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_green')) -- Green for enabled
		if ImGui.SmallButton(Module.Icons.FA_HEARTBEAT) then mq.cmdf('/alertmaster off') end
		ImGui.PopStyleColor(1)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_red')) -- Red for disabled
		if ImGui.SmallButton(Module.Icons.MD_DO_NOT_DISTURB) then mq.cmdf('/alertmaster on') end
		ImGui.PopStyleColor(1)
	end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Toggle ALL Scanning and Alerts On\\Off")
		ImGui.EndTooltip()
	end


	-- Place a help icon
	if showTooltips then
		ImGui.Text(Module.Icons.MD_HELP)
	else
		ImGui.Text(Module.Icons.MD_HELP_OUTLINE)
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
			Module.Utils.PrintOutput('AlertMaster', nil, "\aySpawn alert \"" .. name .. "\" already exists.")
			return
		end
		sCount = sCount + 1
	end
	-- if we made it this far, the spawn isn't tracked -- add it to the table and store to ini
	settings[zone]['Spawn' .. sCount + 1] = name
	save_settings()
	Module.Utils.PrintOutput('AlertMaster', nil, '\ayAdded spawn alert for ' .. name .. ' in ' .. zone)
end

local function DrawRuleRow(entry)
	ImGui.TableNextColumn()
	-- Add to Spawn List Button
	if ImGui.SmallButton(Module.Icons.FA_USER_PLUS) then addSpawnToList(entry.MobName) end
	if ImGui.IsItemHovered() and showTooltips then
		ImGui.BeginTooltip()
		ImGui.Text("Add to Spawn List")
		ImGui.EndTooltip()
	end
	ImGui.TableNextColumn()
	-- Mob Name
	ImGui.Text('%s', entry.MobName)
	-- Right-click interaction uses the original spawnName
	if ImGui.IsItemHovered() then
		if showTooltips then
			ImGui.BeginTooltip()
			ImGui.Text("%s\n\nRight-Click to Navigate\nCtrl+Right-Click Group Nav", entry.MobName)
			if Module.Build:lower() == 'emu' then
				ImGui.Text("Shift+Left-Click to Target")
			end
			ImGui.EndTooltip()
		end
		if ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsMouseReleased(1) then
			mq.cmdf("/noparse %s/docommand /timed ${Math.Rand[5,25]} /nav id %s", groupCmd, entry.MobID)
		elseif ImGui.IsKeyDown(ImGuiMod.Shift) and ImGui.IsMouseReleased(0) and Module.Build:lower() == 'emu' then
			mq.cmdf("/target id %s", entry.MobID)
		elseif ImGui.IsMouseReleased(1) then
			mq.cmdf('/nav id %s', entry.MobID)
		end
	end
	ImGui.SameLine()
	ImGui.TableNextColumn()
	--Consider Color for Level Text
	ImGui.PushStyleColor(ImGuiCol.Text, Module.Colors.color(entry.MobConColor))
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
		ImGui.PushStyleColor(ImGuiCol.PlotHistogram, Module.Colors.color('red'))
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
	local spawn = mq.TLO.Spawn(entry.MobID)
	ImGui.TableSetColumnIndex(0)
	ImGui.PushStyleColor(ImGuiCol.Text, Module.Colors.color('green'))
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
	ImGui.PushStyleColor(ImGuiCol.Text, Module.Colors.color(entry.MobConColor))
	ImGui.Text(entry.MobLvl)
	ImGui.PopStyleColor()

	ImGui.TableSetColumnIndex(2)
	local distance = math.floor(spawn.Distance() or 0)
	ImGui.PushStyleColor(ImGuiCol.Text, ColorDistance(distance))
	ImGui.Text('\t' .. tostring(distance))
	ImGui.PopStyleColor()
	ImGui.TableSetColumnIndex(3)
	--if DoDrawArrow then
	angle = getRelativeDirection(sHeadingTo) or 0
	local cursorScreenPos = ImGui.GetCursorScreenPosVec()
	DrawArrow(ImVec2(cursorScreenPos.x + 10, cursorScreenPos.y), 5, 15, ColorDistance(distance))
	--end
end
local btnIconDel = Module.Icons.MD_DELETE
local function DrawSearchWindow()
	if currZone ~= lastZone then return end
	if Module.GUI_Main.Locked then
		Module.GUI_Main.Flags = bit32.bor(Module.GUI_Main.Flags, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize)
	else
		Module.GUI_Main.Flags = bit32.band(Module.GUI_Main.Flags, bit32.bnot(ImGuiWindowFlags.NoMove), bit32.bnot(ImGuiWindowFlags.NoResize))
	end
	if SearchWindowOpen then
		-- ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 5)
		local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(useThemeName, Module.Theme)
		local open, show = ImGui.Begin("Alert Master##" .. Module.CharLoaded, true, Module.GUI_Main.Flags)
		if not open then
			SearchWindowOpen = false
			show = false
		end
		if show then
			ImGui.BeginMenuBar()
			ImGui.SetWindowFontScale(ZoomLvl)
			DrawToggles()
			ImGui.EndMenuBar()
			-- if ZoomLvl > 1.25 then ImGui.PopStyleVar(1) end
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
				tabLabel = Module.Icons.FA_BULLHORN .. " NPC List " .. Module.Icons.FA_BULLHORN
				ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_red'))
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
					ImGui.TableSetupColumn(Module.Icons.FA_USER_PLUS, bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.NoSort), 15, Module.GUI_Main.Table.Column_ID
						.Remove)
					ImGui.TableSetupColumn("Name", bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.DefaultSort), 120, Module.GUI_Main.Table.Column_ID.MobName)
					ImGui.TableSetupColumn("Lvl", bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.DefaultSort), 30, Module.GUI_Main.Table.Column_ID.MobLvl)
					ImGui.TableSetupColumn("Dist", bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.DefaultSort), 40, Module.GUI_Main.Table.Column_ID.MobDist)
					ImGui.TableSetupColumn("Aggro", bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.DefaultSort), 30, Module.GUI_Main.Table.Column_ID.MobAggro)
					ImGui.TableSetupColumn("ID", bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.DefaultSort), 30, Module.GUI_Main.Table.Column_ID.MobID)
					ImGui.TableSetupColumn("Loc", bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.NoSort), 90, Module.GUI_Main.Table.Column_ID.MobLoc)
					ImGui.TableSetupColumn(Module.Icons.FA_COMPASS, bit32.bor(ImGuiTableColumnFlags.NoResize, ImGuiTableColumnFlags.NoSort, ImGuiTableColumnFlags.WidthFixed), 15,
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
				if ImGui.Button(Module.Icons.FA_USER_PLUS) and newSpawnName ~= "" then
					-- CMD('/alertmaster spawnadd "'..newSpawnName..'"')
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
						ImGui.TableSetupColumn("NPC Name##AMList")
						ImGui.TableSetupColumn("Zone##AMList")
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
								mq.cmdf('/alertmaster spawndel "' .. spawnName .. '"')
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
		end
		Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
		ImGui.SetWindowFontScale(1)
		ImGui.End()
	end
end

local function Config_GUI()
	if not openConfigGUI then return end
	-- local themeName = theme.LoadTheme or 'notheme'
	local ColorCountConf, StyleCountConf = Module.ThemeLoader.StartTheme(useThemeName, Module.Theme)

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
				for k, data in pairs(Module.Theme.Theme) do
					local isSelected = data.Name == useThemeName
					if ImGui.Selectable(data.Name, isSelected) then
						Module.Theme.LoadTheme = data.Name
						useThemeName = Module.Theme.LoadTheme
						Module.Settings[CharConfig]['theme'] = useThemeName
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
				Module.Settings[CharConfig]['ZoomLvl'] = ZoomLvl
			end

			if ImGui.Button('Reload Theme File') then
				load_settings()
			end

			ImGui.SameLine()
			if loadedExeternally then
				if ImGui.Button('Edit ThemeZ') then
					if not loadedExeternally then
						mq.cmd("/lua run themez")
					else
						if MyUI_Modules.ThemeZ ~= nil then
							if MyUI_Modules.ThemeZ.IsRunning then
								MyUI_Modules.ThemeZ.ShowGui = true
							else
								MyUI_TempSettings.ModuleChanged = true
								MyUI_TempSettings.ModuleName = 'ThemeZ'
								MyUI_TempSettings.ModuleEnabled = true
							end
						else
							MyUI_TempSettings.ModuleChanged = true
							MyUI_TempSettings.ModuleName = 'ThemeZ'
							MyUI_TempSettings.ModuleEnabled = true
						end
					end
				end
			end
		end

		if ImGui.CollapsingHeader('Toggles##AlertMaster') then
			if ImGui.BeginTable('##ToggleTable', 2, ImGuiTableFlags.Resizable) then
				ImGui.TableSetupColumn('##ToggleCol1')
				ImGui.TableSetupColumn('##ToggleCol2')
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				for k, v in pairs(Module.Settings[CharConfig]) do
					ImGui.PushID(k)
					if type(v) == 'boolean' then
						local pressed = false
						Module.Settings[CharConfig][k], pressed = Module.Utils.DrawToggle(k, Module.Settings[CharConfig][k], ToggleFlags, ImVec2(40, 16))
						if pressed then
							set_settings()
							save_settings()
						end
						ImGui.TableNextColumn()
					end
					ImGui.PopID()
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

			tmpDoGM = Module.Utils.DrawToggle('GM Alert##AlertMaster', tmpDoGM, ToggleFlags, ImVec2(40, 16))
			if tmpDoGM ~= doSoundGM then
				doSoundGM = tmpDoGM
				Module.Settings[CharConfig]['doSoundGM'] = doSoundGM
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
				Module.Settings[CharConfig]['volGM'] = volGM
				Module.Settings[CharConfig]['soundGM'] = soundGM
				save_settings()
			end
			--- PC Alerts ---
			ImGui.SeparatorText("PC Alerts##AlertMaster")
			--- tmp vars to change ---
			local tmpSndPC = soundPC or 'PC.wav'
			local tmpVolPC = volPC or 100
			local tmpDoPC = doSoundPC

			tmpDoPC = Module.Utils.DrawToggle('PC Alert##AlertMaster', tmpDoPC, ToggleFlags, ImVec2(40, 16))
			if tmpDoPC ~= doSoundPC then
				doSoundPC = tmpDoPC
				Module.Settings[CharConfig]['doSoundPC'] = doSoundPC
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
				Module.Settings[CharConfig]['volPC'] = volPC
				Module.Settings[CharConfig]['soundPC'] = soundPC
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

			tmpDoPCEntered = Module.Utils.DrawToggle('PC Entered##AlertMaster', tmpDoPCEntered, ToggleFlags, ImVec2(40, 16))
			if doSoundPCEntered ~= tmpDoPCEntered then
				doSoundPCEntered = tmpDoPCEntered
				Module.Settings[CharConfig]['doSoundPCEntered'] = doSoundPCEntered
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
				Module.Settings[CharConfig]['volPCEntered'] = volPCEntered
				Module.Settings[CharConfig]['soundPCEntered'] = soundPCEntered
				save_settings()
			end
			tmpDoPCLeft = Module.Utils.DrawToggle('PC Left##AlertMaster', tmpDoPCLeft, ToggleFlags, ImVec2(40, 16))
			if doSoundPCLeft ~= tmpDoPCLeft then
				doSoundPCLeft = tmpDoPCLeft
				Module.Settings[CharConfig]['doSoundPCLeft'] = doSoundPCLeft
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
				Module.Settings[CharConfig]['volPCLeft'] = volPCLeft
				Module.Settings[CharConfig]['soundPCLeft'] = soundPCLeft
				save_settings()
			end


			--- NPC Alerts ---
			ImGui.SeparatorText("NPC Alerts##AlertMaster")
			--- tmp vars to change ---
			local tmpSndNPC = soundNPC or 'NPC.wav'
			local tmpVolNPC = volNPC or 100
			local tmpDoNPC = doSoundNPC

			tmpDoNPC = Module.Utils.DrawToggle('NPC Alert##AlertMaster', tmpDoNPC, ToggleFlags, ImVec2(40, 16))
			if doSoundNPC ~= tmpDoNPC then
				doSoundNPC = tmpDoNPC
				Module.Settings[CharConfig]['doSoundNPC'] = doSoundNPC
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
				Module.Settings[CharConfig]['volNPC'] = volNPC
				Module.Settings[CharConfig]['soundNPC'] = soundNPC
				save_settings()
			end
		end

		if ImGui.CollapsingHeader("Commands") then
			if ImGui.BeginTable("CommandTable", 2, ImGuiTableFlags.Resizable) then
				ImGui.TableSetupColumn("Command")
				ImGui.TableSetupColumn("Text")
				for key, command in pairs(Module.Settings[CharCommands]) do
					local tmpCmd = command
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					ImGui.Text(key)
					ImGui.TableNextColumn()
					tmpCmd = ImGui.InputText("##" .. key, tmpCmd)
					if tmpCmd ~= command then
						if tmpCmd == '' or tmpCmd == nil then
							Module.Settings[CharCommands][key] = nil
						else
							Module.Settings[CharCommands][key] = tmpCmd
						end
						save_settings()
					end
				end
				ImGui.EndTable()
			end
		end

		if ImGui.Button('Save & Close') then
			openConfigGUI = false
			Module.Settings[CharConfig]['theme'] = useThemeName
			Module.Settings[CharConfig]['ZoomLvl'] = ZoomLvl
			save_settings()
		end
	end
	Module.ThemeLoader.EndTheme(ColorCountConf, StyleCountConf)
	ImGui.SetWindowFontScale(1)
	ImGui.End()
end

local function BuildAlertRows() -- Build the Button Rows for the GUI Window
	if zone_id == Zone.ID() then
		-- Start a new table for alerts
		local sizeX = ImGui.GetContentRegionAvail() - 4
		if ImGui.BeginTable("AlertTable", 4, Module.GUI_Alert.Table.Flags) then
			ImGui.TableSetupScrollFreeze(0, 1)
			ImGui.TableSetupColumn("Name", bit32.bor(ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.WidthFixed), 90, Module.GUI_Alert.Table.Column_ID.MobName)
			ImGui.TableSetupColumn("Lvl", bit32.bor(ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.WidthFixed), 30, Module.GUI_Alert.Table.Column_ID.MobLvl)
			ImGui.TableSetupColumn("Dist", bit32.bor(ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.WidthFixed), 50, Module.GUI_Alert.Table.Column_ID.MobDist)
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
		if currZone ~= lastZone then return end
		-- ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 5)
		local ColorCountAlert, StyleCountAlert = Module.ThemeLoader.StartTheme(useThemeName, Module.Theme)
		local open, show = ImGui.Begin("Alert Window##" .. Module.CharLoaded, true, Module.GUI_Alert.Flags)
		if not open then
			show = false
			AlertWindowOpen = false
		end
		if show then
			ImGui.SetWindowFontScale(ZoomLvl)
			BuildAlertRows()
		end
		Module.ThemeLoader.EndTheme(ColorCountAlert, StyleCountAlert)
		ImGui.SetWindowFontScale(1)
		ImGui.End()
	end
end

function Module.RenderGUI()
	DrawSearchWindow()
	DrawAlertGUI()
	Config_GUI()
end

local function load_binds()
	local function bind_alertmaster(cmd, val)
		local zone = Zone.ShortName()
		local val_num = tonumber(val, 10)
		local val_str = tostring(val):gsub("\"", "")
		-- enable/disable
		if cmd == 'on' then
			active = true
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayAlert Master enabled.')
		elseif cmd == 'off' then
			active = false
			tGMs, tAnnounce, tPlayers, tSpawns = {}, {}, {}, {}
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayAlert Master disabled.')
		end

		if cmd == 'quit' or cmd == 'exit' then
			Module.IsRunning = false
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayAlert Master\ao Shutting Down.')
		end
		-- Alert Show / Hide
		if cmd == 'popup' then
			if AlertWindowOpen then
				AlertWindowOpen = false
				AlertWindow_Show = false
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayClosing Alert Window.')
			else
				AlertWindowOpen = true
				AlertWindow_Show = true
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayShowing Alert Window.')
			end
		end
		-- Search Gui Show / Hide
		if cmd == 'show' then
			if SearchWindowOpen then
				SearchWindow_Show = false
				SearchWindowOpen = false
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayClosing Search UI.')
			else
				RefreshZone()
				SearchWindow_Show = true
				SearchWindowOpen = true
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayShowing Search UI.')
			end
		end
		-- Alert Popup On/Off Toggle
		if cmd == 'doalert' then
			if doAlert then
				doAlert = false
				Module.Settings[CharConfig]['popup'] = doAlert
				save_settings()
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayAlert PopUp Disabled.')
			else
				doAlert = true
				Module.Settings[CharConfig]['popup'] = doAlert
				save_settings()
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayAlert PopUp Enabled.')
			end
		end
		-- Aggro Display On/Off Toggle
		if cmd == 'aggro' then
			if showAggro then
				showAggro = false
				Module.Settings[CharConfig]['aggro'] = showAggro
				save_settings()
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayShow Aggro Disabled.')
			else
				showAggro = true
				Module.Settings[CharConfig]['aggro'] = showAggro
				save_settings()
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayShow Aggro Enabled.')
			end
		end
		-- Beep On/Off Toggle
		if cmd == 'beep' then
			if doBeep then
				doBeep = false
				Module.Settings[CharConfig]['beep'] = doBeep
				save_settings()
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayBeep Alerts Disabled.')
			else
				doBeep = true
				Module.Settings[CharConfig]['beep'] = doBeep
				save_settings()
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayBeep Alerts Enabled.')
			end
		end
		-- radius
		if cmd == 'radius' and val_num > 0 then
			Module.Settings[CharConfig]['radius'] = val_num
			radius = val_num
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayUpdated radius = ' .. radius)
		end
		-- zradius
		if cmd == 'zradius' and val_num > 0 then
			Module.Settings[CharConfig]['zradius'] = val_num
			zradius = val_num
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayUpdated zradius = ' .. zradius)
		end
		-- delay
		if cmd == 'delay' and val_num > 0 then
			Module.Settings[CharConfig]['delay'] = val_num
			delay = val_num
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayDelay interval = ' .. delay)
		end
		---- Volumes ----
		if cmd == 'volnpc' and val_num > 0 then
			Module.Settings[CharConfig]['volNPC'] = val_num
			volNPC = val_num
			save_settings()
			setVolume(volNPC)
			playSound(soundNPC)
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayNPC Volume = ' .. volNPC)
		end
		if cmd == 'volpc' and val_num > 0 then
			Module.Settings[CharConfig]['volPC'] = val_num
			volPC = val_num
			save_settings()
			setVolume(volPC)
			playSound(soundPC)
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayPC Volume = ' .. volPC)
		end
		if cmd == 'volgm' and val_num > 0 then
			Module.Settings[CharConfig]['volGM'] = val_num
			volGM = val_num
			save_settings()
			setVolume(volGM)
			playSound(soundGM)
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayGM Volume = ' .. volGM)
		end
		----- Sounds -----
		if cmd == 'dosound' and val_str ~= nil then
			if val_str == 'npc' then
				doSoundNPC = not doSoundNPC
				Module.Settings[CharConfig]['doSoundNPC'] = doSoundNPC
				Module.Utils.PrintOutput('AlertMaster', nil, '\aySetting doSoundNPC = ' .. tostring(doSoundNPC))
			elseif val_str == 'pc' then
				doSoundPC = not doSoundPC
				Module.Settings[CharConfig]['doSoundPC'] = doSoundPC
				Module.Utils.PrintOutput('AlertMaster', nil, '\aySetting doSoundPC = ' .. tostring(doSoundPC))
			elseif val_str == 'gm' then
				doSoundGM = not doSoundGM
				Module.Settings[CharConfig]['doSoundGM'] = doSoundGM
				Module.Utils.PrintOutput('AlertMaster', nil, '\aySetting doSoundGM = ' .. tostring(doSoundGM))
			end
			save_settings()
		end
		-- distfar Color Distance
		if cmd == 'distfar' and val_num > 0 then
			Module.Settings[CharConfig]['distfar'] = val_num
			DistColorRanges.red = val_num
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\arFar Range\a-t Greater than:\a-r' .. DistColorRanges.red .. '\ax')
		end
		-- distmid Color Distance
		if cmd == 'distmid' and val_num > 0 then
			Module.Settings[CharConfig]['distmid'] = val_num
			DistColorRanges.orange = val_num
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\aoMid Range\a-t Between: \a-g' .. DistColorRanges.orange .. ' \a-tand \a-r' .. DistColorRanges.red .. '\ax')
		end
		-- remind
		if cmd == 'remind' and val_num >= 0 then
			Module.Settings[CharConfig]['remind'] = val_num
			remind = val_num
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayRemind interval = ' .. remind)
		end
		if cmd == 'reload' then
			load_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, "\ayReloading Settings from File!")
		end
		if cmd == 'remindnpc' and val_num >= 0 then
			Module.Settings[CharConfig]['remindNPC'] = val_num
			remindNPC = val_num
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayRemind NPC interval = ' .. remindNPC .. 'minutes')
		end
		-- enabling/disabling spawn alerts
		if cmd == 'spawns' and val_str == 'on' then
			Module.Settings[CharConfig]['spawns'] = true
			save_settings()
			spawns = true
			Module.Utils.PrintOutput('AlertMaster', nil, '\aySpawn alerting enabled.')
		elseif cmd == 'spawns' and val_str == 'off' then
			Module.Settings[CharConfig]['spawns'] = false
			save_settings()
			spawns = false
			Module.Utils.PrintOutput('AlertMaster', nil, '\aySpawn alerting disabled.')
		end
		-- enabling/disabling pcs alerts
		if cmd == 'pcs' and val_str == 'on' then
			Module.Settings[CharConfig]['pcs'] = true
			save_settings()
			pcs = true
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayPC alerting enabled.')
		elseif cmd == 'pcs' and val_str == 'off' then
			Module.Settings[CharConfig]['pcs'] = false
			save_settings()
			pcs = false
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayPC alerting disabled.')
		end

		local sCount = #tSpawns or 0
		-- adding/removing/listing spawn alerts for current zone
		if cmd == 'spawnadd' then
			if val_str ~= nil and val_str ~= 'nil' then
				val_str = mq.TLO.Target.DisplayName()
			elseif mq.TLO.Target() ~= nil and mq.TLO.Target.Type() == 'NPC' then
				val_str = mq.TLO.Target.DisplayName()
			else
				Module.Utils.PrintOutput('AlertMaster', true, "\arNO \aoSpawn supplied\aw or \agTarget")
				return
			end
			addSpawnToList(val_str)
			-- -- if the zone doesn't exist in ini yet, create a new table
			-- if settings[zone] == nil then settings[zone] = {} end

			-- -- if the zone does exist in the ini, spin over entries and make sure we aren't duplicating
			-- for k, v in pairs(settings[zone]) do
			-- 	if settings[zone][k] == val_str then
			-- 		Module.Utils.PrintOutput('AlertMaster',nil,"\aySpawn alert \""..val_str.."\" already exists.")
			-- 		return
			-- 	end
			-- 	sCount = sCount + 1
			-- end
			-- -- if we made it this far, the spawn isn't tracked -- add it to the table and store to ini
			-- settings[zone]['Spawn'..sCount+1] = val_str
			-- save_settings()
			-- Module.Utils.PrintOutput('AlertMaster',nil,'\ayAdded spawn alert for '..val_str..' in '..zone)
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
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayRemoved spawn alert for ' .. val_str .. ' in ' .. zone)
			else
				Module.Utils.PrintOutput('AlertMaster', nil, '\aySpawn alert for ' .. val_str .. ' not found in ' .. zone)
			end
		elseif cmd == 'spawnlist' then
			-- if sCount > 0 then
			Module.Utils.PrintOutput('AlertMaster', nil, '\aySpawn Alerts (\a-t' .. zone .. '\ax): ')
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
					Module.Utils.PrintOutput('AlertMaster', nil, string.format('\ag[Live] %s ("%s")\ax', name, v))
				else
					Module.Utils.PrintOutput('AlertMaster', nil, string.format('\a-t[Dead] %s\ax', v))
				end
			end
			-- else
			-- 	Module.Utils.PrintOutput('AlertMaster',nil,'\aySpawn Alerts (\a-t' .. zone .. '\ax): No alerts found')
			-- end
		end

		-- adding/removing/listing commands
		local cmdCount = 0
		for k, v in pairs(Module.Settings[CharCommands]) do
			cmdCount = cmdCount + 1
		end
		if cmd == 'cmdadd' and val_str:len() > 0 then
			-- if the section doesn't exist in ini yet, create a new table
			if Module.Settings[CharCommands] == nil then Module.Settings[CharCommands] = {} end
			-- if the section does exist in the ini, spin over entries and make sure we aren't duplicating
			for k, v in pairs(Module.Settings[CharCommands]) do
				if Module.Settings[CharCommands][k] == val_str then
					Module.Utils.PrintOutput('AlertMaster', nil, "\ayCommand \"" .. val_str .. "\" already exists.")
					return
				end
				cmdCount = cmdCount + 1
			end
			-- if we made it this far, the command is new -- add it to the table and store to ini
			Module.Settings[CharCommands]['Cmd' .. cmdCount + 1] = val_str
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayAdded Command \"' .. val_str .. '\"')
		elseif cmd == 'cmddel' and val_str:len() > 0 then
			-- remove from the ini
			for k, v in pairs(Module.Settings[CharCommands]) do
				if k:lower() == val_str:lower() then
					Module.Settings[CharCommands][k] = nil
					break
				end
				if Module.Settings[CharCommands][k] == val_str then
					Module.Settings[CharCommands][k] = nil
					break
				end
			end
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayRemoved Command \"' .. val_str .. '\"')
		elseif cmd == 'cmdlist' then
			if cmdCount > 0 then
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayCommands (\a-t' .. Module.CharLoaded .. '\ax): ')
				for k, v in pairs(Module.Settings[CharCommands]) do
					Module.Utils.PrintOutput('AlertMaster', nil, '\t\a-t' .. k .. ' - ' .. v)
				end
			else
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayCommands (\a-t' .. Module.CharLoaded .. '\ax): No commands configured.')
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
					Module.Utils.PrintOutput('AlertMaster', nil, '\ayAlready ignoring \"' .. val_str .. '\".')
					return
				end
				ignoreCount = ignoreCount + 1
			end
			-- if we made it this far, the command is new -- add it to the table and store to ini
			settings['Ignore']['Ignore' .. ignoreCount + 1] = val_str
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayNow ignoring \"' .. val_str .. '\"')
		elseif cmd == 'ignoredel' and val_str:len() > 0 then
			-- remove from the ini
			for k, v in pairs(settings['Ignore']) do
				if settings['Ignore'][k] == val_str then settings['Ignore'][k] = nil end
			end
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayNo longer ignoring \"' .. val_str .. '\"')
		elseif cmd == 'ignorelist' then
			if ignoreCount > 0 then
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayIgnore List (\a-t' .. Module.CharLoaded .. '\ax): ')
				for k, v in pairs(settings['Ignore']) do
					Module.Utils.PrintOutput('AlertMaster', nil, '\t\a-t' .. k .. ' - ' .. v)
				end
			else
				Module.Utils.PrintOutput('AlertMaster', nil, '\ayIgnore List (\a-t' .. Module.CharLoaded .. '\ax): No ignore list configured.')
			end
		end
		-- Announce Alerts
		if cmd == 'announce' and val_str == 'on' then
			announce = true
			Module.Settings[CharConfig]['announce'] = announce
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayNow announcing players entering/exiting the zone.')
		elseif cmd == 'announce' and val_str == 'off' then
			announce = false
			Module.Settings[CharConfig]['announce'] = announce
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayNo longer announcing players entering/exiting the zone.')
		end
		-- GM Checks
		if cmd == 'gm' and val_str == 'on' then
			gms = true
			Module.Settings[CharConfig]['gms'] = gms
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayGM Alerts enabled.')
		elseif cmd == 'gm' and val_str == 'off' then
			gms = false
			Module.Settings[CharConfig]['gms'] = gms
			save_settings()
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayGM Alerts disabled.')
		end
		-- Status
		if cmd == 'status' then print_status() end
		if cmd == nil or cmd == 'help' then
			Module.Utils.PrintOutput('AlertMaster', nil, '\ayAlert Master Usage:')
			Module.Utils.PrintOutput('AlertMaster', nil, '\a-y- General -')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster status\a-t -- print current alerting status/settings')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster help\a-t -- print help/usage')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster on|off\a-t -- toggle alerts')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster gm on|off\a-t -- toggle GM alerts')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster pcs on|off\a-t -- toggle PC alerts')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster spawns on|off\a-t -- toggle spawn alerts')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster beep on|off\a-t -- toggle Audible Beep alerts')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster doalert \a-t -- toggle Popup alerts')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster announce on|off\a-t -- toggle announcing PCs entering/exiting the zone')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster radius #\a-t -- configure alert radius (integer)')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster reload #\a-t -- reload the Config File')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster zradius #\a-t -- configure alert z-radius (integer)')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster delay #\a-t -- configure alert check delay (seconds)')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster remind #\a-t -- configure Player and GM alert reminder interval (seconds)')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster remindnpc #\a-t -- configure NPC alert reminder interval (Minutes)')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster popup\a-t -- Toggles Display of Alert Window')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster reload\a-t -- Reload the ini file')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster distmid\a-t -- Sets distance the color changes from \a-gGreen \a-tto \a-oOrange')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster distfar\a-t -- Sets the distnace the color changes from \a-oOrange \a-tto \a-rRed')
			Module.Utils.PrintOutput('AlertMaster', nil, '\a-y- Sounds -')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster dosound pc\a-t -- toggle PC custom sound alerts')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster dosound npc\a-t -- toggle NPC custom sound alerts')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster dosound gm\a-t -- toggle GM custom sound alerts')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster volpc 1-100\a-t -- Set PC custom sound Volume 1-100')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster volnpc 1-100\a-t -- Set NPC custom sound Volume 1-100')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster volgm 1-100\a-t -- Set GM custom sound Volume 1-100')
			Module.Utils.PrintOutput('AlertMaster', nil, '\a-y- Ignore List -')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster ignoreadd pcname\a-t -- add pc to the ignore list')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster ignoredel pcname\a-t -- delete pc from the ignore list')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster ignorelist\a-t -- display ignore list')
			Module.Utils.PrintOutput('AlertMaster', nil, '\a-y- Spawns -')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster spawnadd npc\a-t -- add monster to the list of tracked spawns')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster spawndel npc\a-t -- delete monster from the list of tracked spawns')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster spawnlist\a-t -- display monsters being tracked for the current zone')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster show\a-t -- Toggles display of Search Window and Spawns for the current zone')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster aggro\a-t -- Toggles display of Aggro status bars in the search window.')
			Module.Utils.PrintOutput('AlertMaster', nil, '\a-y- Commands - executed when players remain in the alert radius for the reminder interval')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster cmdadd command\a-t -- add command to run when someone enters your alert radius')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster cmddel command\a-t -- delete command to run when someone enters your alert radius')
			Module.Utils.PrintOutput('AlertMaster', nil, '\t\ay/alertmaster cmdlist\a-t -- display command(s) to run when someone enters your alert radius')
		end
	end
	mq.bind('/alertmaster', bind_alertmaster)
	-- mq.bind('/am', bind_alertmaster)
end

function Module.Unload()
	mq.unbind('/alertmaster')
	-- mq.unbind('/am')
end

local function setup()
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
	Module.Utils.PrintOutput('AlertMaster', false, '\ayAlert Master version:\a-g' ..
		amVer .. '\n' .. MsgPrefix() .. '\ayOriginal by (\a-to_O\ay) Special.Ed (\a-tO_o\ay)\n' .. MsgPrefix() .. '\ayUpdated by (\a-tO_o\ay) Grimmier (\a-to_O\ay)')
	Module.Utils.PrintOutput('AlertMaster', false, '\atLoaded ' .. settings_file)
	Module.Utils.PrintOutput('AlertMaster', false, '\ay/alertmaster help for usage')
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
function Module.MainLoop()
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
		Module.Guild = mq.TLO.Me.Guild() or 'NoGuild'

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
						Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. '\ag' .. cleanName .. '\ax spawn alert! ' .. distance .. ' units away.')
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
