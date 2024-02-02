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
    * Sort by columns (Shift-Clicking Columns will MultiSort based onthe order you click.)
    * Clicking the check box for track, and the spawn will be added to spawnlist
    * Clicking ignore will remove the spawn from the list if it exists.
    * you can navTo any spawn in the search window by clicking the button, rightclicking the name will target the spawn.
    ** Alert Window **
    * The Alert Popup Window lists the spawns that you are tracking and are alive. Shown as "Name : Distance"
    * Clicking the button on the Alert Window will NavTo the spawn.
    * Closing the Alert Popup will keep it closed until something changes or your remind timer is up.
    * remind setting is in minutes.
]]
local LIP = require('lib/LIP')
require('lib/ed/utils')
--- @type Mq
local mq = require('mq')
--- @type ImGui
require('ImGui')
-- Variables
local arg = {...}
local CMD = mq.cmd
local TLO = mq.TLO
local Me = TLO.Me
local SpawnCount = TLO.SpawnCount
local NearestSpawn = TLO.NearestSpawn
local Group = TLO.Group
local Raid = TLO.Raid
local Zone = TLO.Zone
local curZone = Zone.Name()
local CharConfig = 'Char_'..Me.CleanName()..'_Config'
local CharCommands = 'Char_'..Me.CleanName()..'_Commands'
local defaultConfig =  { delay = 1, remind = 30, pcs = true, spawns = true, gms = true, announce = false, ignoreguild = true , beep = false, popup = false}
local tSafeZones, spawnAlerts = {}, {}
local alertTime, numAlerts = 0,0
local doBeep, doAlert = false, false

-- [[ UI ]] --
local AlertWindow_Show = false
local AlertWindowOpen = false
local SearchWindow_Show = false
local SearchWindowOpen = false
local Table_Cache = {
    Rules = {},
    Unhandled = {},
    Mobs = {},
}
local alertFlags = bit32.bor(ImGuiWindowFlags.None)
local spawnListFlags = bit32.bor(
    ImGuiTableFlags.Resizable,
    ImGuiTableFlags.RowBg,
    ImGuiTableFlags.SizingFixedFit,
    ImGuiTableFlags.BordersV,
    ImGuiTableFlags.BordersOuter,
    ImGuiTableFlags.Reorderable,
    ImGuiTableFlags.ScrollY,
    ImGuiTableFlags.ScrollX,
    ImGuiTableFlags.Hideable
)
local GUI_Main = {
    Open  = false,
    Show  = false,
    Flags = bit32.bor(
        ImGuiWindowFlags.None
    ),
    Refresh = {
        Sort = {
            Rules     = true,
            Filtered  = true,
            Unhandled = true,
            Mobs = false,
        },
        Table = {
            Rules     = true,
            Filtered  = true,
            Unhandled = true,
            Mobs = false,
        },
    },
    Search = '',
    Table = {
        Column_ID = {
            ID          = 1,
            MobName     = 2,
            MobLoc      = 3,
            MobZoneName = 4,
            MobDist     = 5,
            MobID       = 6,
            Action      = 7,
            Remove      = 8,
            MobLvl      = 9,
        },
        Flags = bit32.bor(
            ImGuiTableFlags.Resizable,
            ImGuiTableFlags.Sortable,
            ImGuiTableFlags.RowBg,
            --ImGuiTableFlags.NoKeepColumnsVisible,
            ImGuiTableFlags.SizingFixedFit,
            ImGuiTableFlags.MultiSortable,
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
            Filtered = nil,
            Mobs = nil,
        },
    },
}
function isSpawnInAlerts(spawnName, spawnAlerts)
    for _, spawnData in pairs(spawnAlerts) do
        if spawnData.CleanName() == spawnName or spawnData.Name() == spawnName then
            return true
        end
    end
    return false
end
local function SpawnToEntry(spawn, row)
    if spawn.Distance() then
        local entry = {
            ID = row,
            MobName = spawn.CleanName(),
            MobZoneName = mq.TLO.Zone.Name,
            MobDist = math.floor(spawn.Distance() or 0),
            MobLoc = spawn.Loc(),
            MobID = spawn.ID(),
            MobLvl = spawn.Level(),
            Enum_Action = 'unhandled',
        }
        return entry
        else
        return
    end
end
local function InsertTableSpawn(dataTable, spawn, row, opts)
    if spawn then
        local entry = SpawnToEntry(spawn, row)
        if opts then
            for k,v in pairs(opts) do
                entry[k] = v
            end
        end
        table.insert(dataTable, entry)
    end
end
local function TableSortSpecs(a, b)
    for i = 1, GUI_Main.Table.SortSpecs.SpecsCount do
        local spec = GUI_Main.Table.SortSpecs:Specs(i)
        local delta = 0
        if spec.ColumnUserID == GUI_Main.Table.Column_ID.MobName then
            if a.MobName and b.MobName then
                if a.MobName < b.MobName then
                    delta = -1
                    elseif a.MobName> b.MobName then
                    delta = 1
                end
                else
                return  0
            end
            elseif spec.ColumnUserID == GUI_Main.Table.Column_ID.MobID then
            if a.MobID and b.MobID then
                if a.MobID < b.MobID then
                    delta = -1
                    elseif a.MobID > b.MobID then
                    delta = 1
                end
                else
                return  0
            end
            elseif spec.ColumnUserID == GUI_Main.Table.Column_ID.MobLvl then
            if a.MobLvl and b.MobLvl then
                if a.MobLvl < b.MobLvl then
                    delta = -1
                    elseif a.MobLvl > b.MobLvl then
                    delta = 1
                end
                else
                return  0
            end
            elseif spec.ColumnUserID == GUI_Main.Table.Column_ID.MobDist then
            if a.MobDist and b.MobDist then
                if a.MobDist < b.MobDist then
                    delta = -1
                    elseif a.MobDist > b.MobDist then
                    delta = 1
                end
                else
                return  0
            end
            elseif spec.ColumnUserID == GUI_Main.Table.Column_ID.Action then
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
local function RefreshUnhandled()
    local splitSearch = {}
    for part in string.gmatch(GUI_Main.Search, '[^%s]+') do
        table.insert(splitSearch, part)
    end
    local newTable = {}
    for k,v in ipairs(Table_Cache.Rules) do
        local found = 0
        for _,search in ipairs(splitSearch) do
            if string.find(string.lower(v.MobName), string.lower(search)) then found = found + 1 end
        end
        if #splitSearch == found then table.insert(newTable, v) end
    end
    Table_Cache.Unhandled = newTable
    GUI_Main.Refresh.Sort.Rules = true
    GUI_Main.Refresh.Table.Unhandled = true
end
local function RefreshZone()
    local newTable = {}
    local npcs = mq.getFilteredSpawns(function(spawn) return spawn.Type() == 'NPC' end)
    --CMD('/echo Refreshing Zone Mobs')
    for i = 1, #npcs do
        local spawn = npcs[i]
        if #npcs>0 then InsertTableSpawn(newTable, spawn, i) end
    end
    Table_Cache.Rules = newTable
    Table_Cache.Mobs = newTable
    GUI_Main.Refresh.Sort.Mobs = true
    GUI_Main.Refresh.Table.Mobs = false
end
local function DrawRuleRow(entry)
    ImGui.TableNextColumn()
    if ImGui.SmallButton("NavTo##" .. entry.ID) then
        CMD('/nav id '..entry.MobID)
        CMD('/target id '..entry.MobID)
        printf('\ayMoving to \ag%s',entry.MobName)
    end
    ImGui.TableNextColumn()
    ImGui.Text('%s', entry.MobName)

    ImGui.TableNextColumn()
    ImGui.Text('%s', (entry.MobLvl))

    ImGui.TableNextColumn()
    ImGui.Text('%s', (entry.MobDist))

    ImGui.TableNextColumn()
    ImGui.Text('%s', (entry.MobID))

    ImGui.TableNextColumn()
    ImGui.Text('%s', (entry.MobLoc))

    ImGui.TableNextColumn()
    ImGui.SameLine()
    if ImGui.SmallButton("Add##" .. entry.ID) then CMD('/am spawnadd "'..entry.MobName..'"') end
    ImGui.SameLine()
    if ImGui.SmallButton("Del##" .. entry.ID) then CMD('/am spawndel "'..entry.MobName..'"') end
end

local function DrawSearchWindow()
    if SearchWindowOpen then
        if mq.TLO.Me.Zoning() then return end
        SearchWindowOpen = ImGui.Begin("Alert Master Search Window", SearchWindowOpen, GUI_Main.Flags)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 2, 2)
        if #Table_Cache.Unhandled > 0 then
            ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(1, 0.3, 0.3, 1))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(1, 0.4, 0.4, 1))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImVec4(1, 0.5, 0.5, 1))
        end
        if #Table_Cache.Unhandled > 0 then ImGui.PopStyleColor(3) end
        ImGui.SameLine()
        if ImGui.SmallButton("Refresh Zone") then RefreshZone() end
        ImGui.SameLine()
        -- Alert Window Toggle Button
        if AlertWindowOpen then
            ImGui.PushStyleColor(ImGuiCol.Button, 0.4, 1.0, 0.4, 1.0) -- Green for active state
            ImGui.PushStyleColor(ImGuiCol.Text, 0,0,0,1)
            if ImGui.SmallButton("Toggle Alert Window") then CMD('/am popup') end
            ImGui.PopStyleColor(2)
            else
            ImGui.PushStyleColor(ImGuiCol.Button, 1.0, 0.4, 0.4, 1.0) -- Red for inactive state
            ImGui.PushStyleColor(ImGuiCol.Text, 0,0,0,1)
            if ImGui.SmallButton("Toggle Alert Window") then CMD('/am popup') end
            ImGui.PopStyleColor(2)
        end
        
        -- Alert Popup Toggle Button
        if doAlert then
            ImGui.PushStyleColor(ImGuiCol.Button, 0.4, 1.0, 0.4, 1.0) -- Green for enabled
            ImGui.PushStyleColor(ImGuiCol.Text, 0,0,0,1)
            if ImGui.SmallButton("DoPopup") then CMD('/am doalert') end
            ImGui.PopStyleColor(2)
            else
            ImGui.PushStyleColor(ImGuiCol.Button, 1.0, 0.4, 0.4, 1.0) -- Red for disabled
            ImGui.PushStyleColor(ImGuiCol.Text, 0,0,0,1)
            if ImGui.SmallButton("DoPopup") then CMD('/am doalert') end
            ImGui.PopStyleColor(2)
        end
        
        ImGui.SameLine()
        
        -- Beep Alert Toggle Button
        if doBeep then
            ImGui.PushStyleColor(ImGuiCol.Button, 0.4, 1.0, 0.4, 1.0) -- Green for enabled
            ImGui.PushStyleColor(ImGuiCol.Text, 0,0,0,1)
            if ImGui.SmallButton("DoBeep") then CMD('/am beep') end
            ImGui.PopStyleColor(2)
            else
            ImGui.PushStyleColor(ImGuiCol.Button, 1.0, 0.4, 0.4, 1.0) -- Red for disabled
            ImGui.PushStyleColor(ImGuiCol.Text, 0,0,0,1)
            if ImGui.SmallButton("DoBeep") then CMD('/am beep') end
            ImGui.PopStyleColor(2)
        end
        
        ImGui.PopStyleVar()
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 2, 2)
        if ImGui.BeginTabBar('##TabBar',ImGuiTabBarFlags.Reorderable) then
            if ImGui.BeginTabItem(string.format('%s', curZone)) then
                ImGui.PushItemWidth(-95)
                local searchText, selected = ImGui.InputText("Search##RulesSearch", GUI_Main.Search)
                ImGui.PopItemWidth()
                if selected and GUI_Main.Search ~= searchText then
                    GUI_Main.Search = searchText
                    GUI_Main.Refresh.Sort.Rules = true
                    GUI_Main.Refresh.Table.Unhandled = true
                end
                ImGui.SameLine()
                if ImGui.Button("Clear##ClearRulesSearch") then
                    GUI_Main.Search = ''
                    GUI_Main.Refresh.Sort.Rules = false
                    GUI_Main.Refresh.Table.Unhandled = true
                end
                ImGui.Separator()
                if ImGui.BeginTable('##RulesTable', 7, GUI_Main.Table.Flags) then
                    ImGui.TableSetupScrollFreeze(0, 1)
                    ImGui.TableSetupColumn("NavTO", ImGuiTableColumnFlags.NoSort, 2, GUI_Main.Table.Column_ID.Remove)
                    ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.DefaultSort, 8, GUI_Main.Table.Column_ID.MobName, 150)
                    ImGui.TableSetupColumn("Lvl", ImGuiTableColumnFlags.DefaultSort, 8, GUI_Main.Table.Column_ID.MobLvl)
                    ImGui.TableSetupColumn("Dist", ImGuiTableColumnFlags.DefaultSort, 8, GUI_Main.Table.Column_ID.MobDist)
                    ImGui.TableSetupColumn("ID", ImGuiTableColumnFlags.DefaultSort, 8, GUI_Main.Table.Column_ID.MobID)
                    ImGui.TableSetupColumn("Loc (x,y,z)", ImGuiTableColumnFlags.NoSort, 8, GUI_Main.Table.Column_ID.MobLoc)
                    ImGui.TableSetupColumn("Action", ImGuiTableColumnFlags.NoSort, 8, GUI_Main.Table.Column_ID.Action)
                    ImGui.TableHeadersRow()
                    local sortSpecs = ImGui.TableGetSortSpecs()
                    if sortSpecs and (sortSpecs.SpecsDirty or GUI_Main.Refresh.Sort.Rules) then
                        if #Table_Cache.Unhandled > 0 then
                            GUI_Main.Table.SortSpecs = sortSpecs
                            table.sort(Table_Cache.Unhandled, TableSortSpecs)
                            GUI_Main.Table.SortSpecs = nil
                        end
                        sortSpecs.SpecsDirty = false
                        GUI_Main.Refresh.Sort.Rules = false
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
                ImGui.EndTabItem()
            end
            if next(spawnAlerts) ~= nil then
                
                -- Change tab background color to something noticeable
                ImGui.PushStyleColor(ImGuiCol.Tab, 1.0, 0.3, 0.3, 1.0) -- Reddish background for alert
                ImGui.PushStyleColor(ImGuiCol.TabHovered, 1.0, 0.4, 0.4, 1.0) -- Lighter red when hovered
                ImGui.PushStyleColor(ImGuiCol.Text, 0,0,0,1)
                ImGui.PushStyleColor(ImGuiCol.TabActive, 1.0, 0.5, 0.5, 1.0) -- Even lighter red when active or selected
                ImGui.BeginTabItem("NPC List")
                ImGui.PopStyleColor(4)
                else
                ImGui.BeginTabItem("NPC List")
            end
            
            -- Tab for NPC List
            
            
            local npcs = settings[Zone.ShortName()] or {}
            newSpawnName, inputChanged = ImGui.InputText("##NewSpawnName", newSpawnName, 256)
            ImGui.SameLine()
            -- Button to add the new spawn
            if ImGui.Button("Add Spawn") then
                CMD('/am spawnadd "'..newSpawnName..'"')
                newSpawnName = ""
                -- Refresh npcs from settings in case it was updated
                npcs = settings[Zone.ShortName()] or {}
            end
            
            -- Populate and sort sortedNpcs right before using it
            local sortedNpcs = {}
            for id, spawnName in pairs(npcs) do
                table.insert(sortedNpcs, {
                    name = spawnName,
                    isInAlerts = isSpawnInAlerts(spawnName, spawnAlerts)
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
            if next(sortedNpcs) ~= nil then
                if ImGui.BeginTable("NPCListTable", 3, spawnListFlags) then
                    -- Set up table headers
                    ImGui.TableSetupColumn("NPC Name", ImGuiTableColumnFlags.WidthAlwaysAutoResize)
                    ImGui.TableSetupColumn("Zone", ImGuiTableColumnFlags.WidthAlwaysAutoResize)
                    ImGui.TableSetupColumn("Remove")
                    ImGui.TableHeadersRow()
                    
                    for index, npc in ipairs(sortedNpcs) do
                        local spawnName = npc.name
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
                        if ImGui.IsItemHovered() then
                            ImGui.BeginTooltip()
                            ImGui.Text("Green Names are up! Right-Click to Navigate to " .. displayName)
                            ImGui.EndTooltip()
                            
                            -- Right-click interaction uses the original spawnName
                            if ImGui.IsItemHovered() and ImGui.IsMouseReleased(1) then
                                CMD('/nav spawn "' .. spawnName .. '"')
                            end
                        end
                        
                        if npc.isInAlerts then
                            ImGui.PopStyleColor()
                        end
                        
                        ImGui.TableNextColumn()
                        ImGui.Text(Zone.ShortName())
                        
                        -- Correctly concatenate 'id' as a string for ImGui identifiers
                        ImGui.TableNextColumn()
                        if ImGui.SmallButton('Remove##' .. tostring(index)) then
                            CMD('/am spawndel "' .. spawnName .. '"')
                        end
                    end
                    
                    ImGui.EndTable()
                end
                else
                ImGui.Text('No spawns in list for this zone. Add some!')
            end
            ImGui.EndTabItem()
            
            ImGui.EndTabBar()
        end
        ImGui.End()
    end
end
local function BuildAlertRows() -- Build the Button Rows for the GUI Window
    if zone_id == Zone.ID() then
        -- Start a new table for alerts
        if ImGui.BeginTable("AlertTable", 2, ImGuiTableFlags_Borders or ImGuiTableFlags_RowBg) then
            ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.WidthAlwaysAutoResize)
            ImGui.TableSetupColumn("Distance", ImGuiTableColumnFlags.WidthAlwaysAutoResize)
            ImGui.TableHeadersRow()
            
            for id, spawnData in pairs(spawnAlerts) do
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0)
                -- Append the spawn's ID to the button label to ensure uniqueness
                if ImGui.Button(spawnData.CleanName() .. "##" .. spawnData.ID()) then
                    -- Actions tied to this specific spawn
                    CMD('/nav id ' .. spawnData.ID())
                end
                if ImGui.IsItemHovered() then
                    ImGui.BeginTooltip()
                    ImGui.Text("Click to Navigate to " .. spawnData.CleanName())
                    ImGui.EndTooltip()
                end
                
                ImGui.TableSetColumnIndex(1)
                ImGui.Text("Dist: " .. math.floor(spawnData.Distance() or 0))
            end
            ImGui.EndTable()
        end
    end
end

function DrawAlertGUI() -- Draw GUI Window
    if AlertWindowOpen then
        if mq.TLO.Me.Zoning() then return end
        AlertWindowOpen, opened = ImGui.Begin("Alert Window", AlertWindowOpen, alertFlags)
        if not opened then
            AlertWindowOpen = false
            AlertWindow_Show = false
            if remind > 0 then
                alertTime = os.time()
                else
                spawnAlerts = {}
            end
            else
            BuildAlertRows()
        end
        
        ImGui.End()
    end
end
local function DrawSearchGUI()
    RefreshZone()
    DrawSearchWindow()
end

-- helpers
local MsgPrefix = function() return string.format('\aw[%s] [\a-tAlert Master\aw] ::\ax ', mq.TLO.Time()) end
local GetCharZone = function()
    return '\aw[\ao'..Me.CleanName()..'\aw] [\at'..Zone.ShortName():lower()..'\aw] '
end
local print_ts = function(msg) print(MsgPrefix()..msg) end
local function print_status()
    print_ts('\ayAlert Status: '..tostring(active and 'on' or 'off'))
    print_ts('\a-tPCs: \a-y'..tostring(pcs)..'\ax radius: \a-y'..tostring(radius)..'\ax zradius: \a-y'..tostring(zradius)..'\ax delay: \a-y'..tostring(delay)..'s\ax remind: \a-y'..tostring(remind)..' min\ax')
    print_ts('\a-tAnnounce PCs: \a-y'..tostring(announce)..'\ax')
    print_ts('\a-tSpawns (zone wide): \a-y'..tostring(spawns)..'\ax')
    print_ts('\a-tGMs (zone wide): \a-y'..tostring(gms)..'\ax')
    print_ts('\a-tPopup Alerts: \a-y'..tostring(doAlert)..'\ax')
    print_ts('\a-tBeep: \a-y'..tostring(doBeep)..'\ax')
end
local save_settings = function()
    LIP.save(settings_path, settings)
end
local check_safe_zone = function()
    return tSafeZones[Zone.ShortName():lower()]
end
local load_binds = function()
    local bind_alertmaster = function(cmd, val)
        local zone = Zone.ShortName():lower()
        local val_num = tonumber(val)
        local val_str = tostring(val):gsub("\"","")
        -- enable/disable
        if cmd == 'on' then
            active = true
            print_ts('\ayAlert Master enabled.')
            elseif cmd == 'off' then
            active = false
            tGMs, tAnnounce, tPlayers, tSpawns = {}, {}, {}, {}
            print_ts('\ayAlert Master disabled.')
        end
        -- Alert Show / Hide
        if cmd == 'popup' then
            if AlertWindowOpen then
                AlertWindowOpen = false
                AlertWindow_Show = false
                print_ts('\ayClosing Alert Window.')
                else
                AlertWindowOpen = true
                AlertWindow_Show = true
                print_ts('\ayShowing Alert Window.')
            end
        end
        -- Search Gui Show / Hide
        if cmd == 'show' then
            if SearchWindowOpen then
                SearchWindow_Show = false
                SearchWindowOpen = false
                print_ts('\ayClosing Search UI.')
                else
                RefreshZone()
                SearchWindow_Show = true
                SearchWindowOpen = true
                print_ts('\ayShowing Search UI.')
            end
        end
        -- Alert Popup On/Off Toggle
        if cmd == 'doalert' then
            if doAlert then
                doAlert = false
                settings[CharConfig]['popup'] = doAlert
                save_settings()
                print_ts('\ayAlert PopUp Disabled.')
                else
                doAlert = true
                settings[CharConfig]['popup'] = doAlert
                save_settings()
                print_ts('\ayAlert PopUp Enabled.')
            end
        end
        -- Beep On/Off Toggle
        if cmd == 'beep' then
            if doBeep then
                doBeep = false
                settings[CharConfig]['beep'] = doBeep
                save_settings()
                print_ts('\ayBeep Alerts Disabled.')
                else
                doBeep = true
                settings[CharConfig]['beep'] = doBeep
                save_settings()
                print_ts('\ayBeep Alerts Enabled.')
            end
        end
        -- radius
        if cmd == 'radius' and val_num > 0 then
            settings[CharConfig]['radius'] = val_num
            radius = val_num
            save_settings()
            print_ts('\ayUpdated radius = '..radius)
        end
        -- zradius
        if cmd == 'zradius' and val_num > 0 then
            settings[CharConfig]['zradius'] = val_num
            zradius = val_num
            save_settings()
            print_ts('\ayUpdated zradius = '..zradius)
        end
        -- delay
        if cmd == 'delay' and val_num > 0 then
            settings[CharConfig]['delay'] = val_num
            delay = val_num
            save_settings()
            print_ts('\ayDelay interval = '..delay)
        end
        -- remind
        if cmd == 'remind' and  val_num >= 0 then
            settings[CharConfig]['remind'] =  val_num
            remind =  val_num
            save_settings()
            print_ts('\ayRemind interval = '..remind)
        end
        -- enabling/disabling spawn alerts
        if cmd == 'spawns' and val_str == 'on' then
            settings[CharConfig]['spawns'] = true
            save_settings()
            spawns = true
            print_ts('\aySpawn alerting enabled.')
            elseif cmd == 'spawns' and val_str == 'off' then
            settings[CharConfig]['spawns'] = false
            save_settings()
            spawns = false
            print_ts('\aySpawn alerting disabled.')
        end
        -- enabling/disabling pcs alerts
        if cmd == 'pcs' and val_str == 'on' then
            settings[CharConfig]['pcs'] = true
            save_settings()
            pcs = true
            print_ts('\ayPC alerting enabled.')
            elseif cmd == 'pcs' and val_str == 'off' then
            settings[CharConfig]['pcs'] = false
            save_settings()
            pcs = false
            print_ts('\ayPC alerting disabled.')
        end
        -- adding/removing/listing spawn alerts for current zone
        if cmd == 'spawnadd' and val_str:len() > 0 then
            -- if the zone doesn't exist in ini yet, create a new table
            if settings[zone] == nil then settings[zone] = {} end
            -- if the zone does exist in the ini, spin over entries and make sure we aren't duplicating
            for k, v in pairs(settings[zone]) do
                if settings[zone][k] == val_str then
                    print_ts("\aySpawn alert \""..val_str.."\" already exists.")
                    return
                end
            end
            -- if we made it this far, the spawn isn't tracked -- add it to the table and store to ini
            settings[zone]['Spawn'..getTableSize(settings[zone])+1] = val_str
            save_settings()
            print_ts('\ayAdded spawn alert for '..val_str..' in '..zone)
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
                    settings[zone]['Spawn'..i] = v
                end
                
                save_settings()
                print_ts('\ayRemoved spawn alert for '..val_str..' in '..zone)
                else
                print_ts('\aySpawn alert for '..val_str..' not found in '..zone)
            end
            elseif cmd == 'spawnlist' then
            if getTableSize(settings[zone]) > 0 then
                print_ts('\aySpawn Alerts (\a-t'..zone..'\ax): ')
                local tmp = {}
                for k, v in pairs(settings[zone]) do table.insert(tmp, v) end
                for k, v in ipairs(tmp) do
                    local up = false
                    local name
                    for _, spawn in pairs(tSpawns) do
                        if string.find(spawn.CleanName(), v) ~= nil then
                            up = true
                            name = spawn.CleanName()
                            break
                        end
                    end
                    if up then
                        print_ts(string.format('\ag[Live] %s ("%s")\ax', name, v))
                        else
                        print_ts(string.format('\a-t[Dead] %s\ax', v))
                    end
                end
                else
                print_ts('\aySpawn Alerts (\a-t'..zone..'\ax): No alerts found')
            end
        end
        -- adding/removing/listing commands
        if cmd == 'cmdadd' and val_str:len() > 0 then
            -- if the section doesn't exist in ini yet, create a new table
            if settings[CharCommands] == nil then settings[CharCommands] = {} end
            -- if the section does exist in the ini, spin over entries and make sure we aren't duplicating
            for k, v in pairs(settings[CharCommands]) do
                if settings[CharCommands][k] == val_str then
                    print_ts("\ayCommand \""..val_str.."\" already exists.")
                    return
                end
            end
            -- if we made it this far, the command is new -- add it to the table and store to ini
            settings[CharCommands]['Cmd'..getTableSize(settings[CharCommands])+1] = val_str
            save_settings()
            print_ts('\ayAdded Command \"'..val_str..'\"')
            elseif cmd == 'cmddel' and val_str:len() > 0 then
            -- remove from the ini
            for k, v in pairs(settings[CharCommands]) do
                if settings[CharCommands][k] == val_str then settings[CharCommands][k] = nil end
            end
            save_settings()
            print_ts('\ayRemoved Command \"'..val_str..'\"')
            elseif cmd == 'cmdlist' then
            if getTableSize(settings[CharCommands]) > 0 then
                print_ts('\ayCommands (\a-t'..Me.CleanName()..'\ax): ')
                for k, v in pairs(settings[CharCommands]) do
                    print_ts('\t\a-t'..k..' - '..v)
                end
                else
                print_ts('\ayCommands (\a-t'..Me.CleanName()..'\ax): No commands configured.')
            end
        end
        -- adding/removing/listing ignored pcs
        if cmd == 'ignoreadd' and val_str:len() > 0 then
            -- if the section doesn't exist in ini yet, create a new table
            if settings['Ignore'] == nil then settings['Ignore'] = {} end
            -- if the section does exist in the ini, spin over entries and make sure we aren't duplicating
            for k, v in pairs(settings['Ignore']) do
                if settings['Ignore'][k] == val_str then
                    print_ts('\ayAlready ignoring \"'..val_str..'\".')
                    return
                end
            end
            -- if we made it this far, the command is new -- add it to the table and store to ini
            settings['Ignore']['Ignore'..getTableSize(settings['Ignore'])+1] = val_str
            save_settings()
            print_ts('\ayNow ignoring \"'..val_str..'\"')
            elseif cmd == 'ignoredel' and val_str:len() > 0 then
            -- remove from the ini
            for k, v in pairs(settings['Ignore']) do
                if settings['Ignore'][k] == val_str then settings['Ignore'][k] = nil end
            end
            save_settings()
            print_ts('\ayNo longer ignoring \"'..val_str..'\"')
            elseif cmd == 'ignorelist' then
            if getTableSize(settings['Ignore']) > 0 then
                print_ts('\ayIgnore List (\a-t'..Me.CleanName()..'\ax): ')
                for k, v in pairs(settings['Ignore']) do
                    print_ts('\t\a-t'..k..' - '..v)
                end
                else
                print_ts('\ayIgnore List (\a-t'..Me.CleanName()..'\ax): No ignore list configured.')
            end
        end
        -- Announce Alerts
        if cmd == 'announce' and val_str == 'on' then
            announce = true
            settings[CharConfig]['announce'] = announce
            save_settings()
            print_ts('\ayNow announcing players entering/exiting the zone.')
            elseif cmd == 'announce' and val_str == 'off'  then
            announce = false
            settings[CharConfig]['announce'] = announce
            save_settings()
            print_ts('\ayNo longer announcing players entering/exiting the zone.')
        end
        -- GM Checks
        if cmd == 'gm' and val_str == 'on' then
            gms = true
            settings[CharConfig]['gms'] = gms
            save_settings()
            print_ts('\ayGM Alerts enabled.')
            elseif cmd == 'gm' and val_str == 'off'  then
            gms = false
            settings[CharConfig]['gms'] = gms
            save_settings()
            print_ts('\ayGM Alerts disabled.')
        end
        -- Status
        if cmd == 'status' then print_status() end
        if cmd == nil or cmd == 'help' then
            print_ts('\ayAlert Master Usage:')
            print_ts('\a-y- General -')
            print_ts('\t\ay/am status\a-t -- print current alerting status/settings')
            print_ts('\t\ay/am help\a-t -- print help/usage')
            print_ts('\t\ay/am on|off\a-t -- toggle alerts')
            print_ts('\t\ay/am gm on|off\a-t -- toggle GM alerts')
            print_ts('\t\ay/am pcs on|off\a-t -- toggle PC alerts')
            print_ts('\t\ay/am spawns on|off\a-t -- toggle spawn alerts')
            print_ts('\t\ay/am beep on|off\a-t -- toggle Audible Beep alerts')
            print_ts('\t\ay/am doalert \a-t -- toggle Popup alerts')
            
            print_ts('\t\ay/am announce on|off\a-t -- toggle announcing PCs entering/exiting the zone')
            print_ts('\t\ay/am radius #\a-t -- configure alert radius (integer)')
            print_ts('\t\ay/am zradius #\a-t -- configure alert z-radius (integer)')
            print_ts('\t\ay/am delay #\a-t -- configure alert check delay (seconds)')
            print_ts('\t\ay/am remind #\a-t -- configure alert reminder interval (seconds)')
            print_ts('\t\ay/am popup\a-t -- Toggles Display of Alert Window')
            
            print_ts('\a-y- Ignore List -')
            print_ts('\t\ay/am ignoreadd pc\a-t -- add pc to the ignore list')
            print_ts('\t\ay/am ignoredel pc\a-t -- delete pc from the ignore list')
            print_ts('\t\ay/am ignorelist\a-t -- display ignore list')
            print_ts('\a-y- Spawns -')
            print_ts('\t\ay/am spawnadd npc\a-t -- add monster to the list of tracked spawns')
            print_ts('\t\ay/am spawndel npc\a-t -- delete monster from the list of tracked spawns')
            print_ts('\t\ay/am spawnlist\a-t -- display monsters being tracked for the current zone')
            print_ts('\t\ay/am show\a-t -- Toggles display of Search Window and Spawns for the current zone')
            
            print_ts('\a-y- Commands - executed when players remain in the alert radius for the reminder interval')
            print_ts('\t\ay/am cmdadd command\a-t -- add command to run when someone enters your alert radius')
            print_ts('\t\ay/am cmddel command\a-t -- delete command to run when someone enters your alert radius')
            print_ts('\t\ay/am cmdlist\a-t -- display command(s) to run when someone enters your alert radius')
        end
    end
    mq.bind('/alertmaster', bind_alertmaster)
    mq.bind('/am', bind_alertmaster)
end
local load_settings = function()
    config_dir = TLO.MacroQuest.Path():gsub('\\', '/')
    settings_file = '/config/AlertMaster.ini'
    settings_path = config_dir..settings_file
    if file_exists(settings_path) then
        settings = LIP.load(settings_path)
        else
        settings = {
            [CharConfig] = defaultConfig,
            [CharCommands] = {},
            Ignore = {}
        }
        save_settings()
    end
    -- if this character doesn't have the sections in the ini, create them
    if settings[CharConfig] == nil then settings[CharConfig] = defaultConfig end
    if settings[CharCommands] == nil then settings[CharCommands] = {} end
    if settings['SafeZones'] == nil then settings['SafeZones'] = {} end
    delay = settings[CharConfig]['delay']
    remind = settings[CharConfig]['remind']
    pcs = settings[CharConfig]['pcs']
    spawns = settings[CharConfig]['spawns']
    gms = settings[CharConfig]['gms']
    announce = settings[CharConfig]['announce']
    ignoreguild = settings[CharConfig]['ignoreguild']
    if settings[CharConfig]['beep'] == nil then
        settings[CharConfig]['beep'] = false
        save_settings()
    end
    doBeep = settings[CharConfig]['beep']
    if settings[CharConfig]['popup'] == nil then
        settings[CharConfig]['popup'] = false
        save_settings()
    end
    doAlert = settings[CharConfig]['popup']
    -- setup safe zone "set"
    for k, v in pairs(settings['SafeZones']) do tSafeZones[v] = true end
end
local setup = function()
    active = true
    radius = arg[1] or 200
    zradius = arg[2] or 100
    load_settings()
    load_binds()
    mq.imgui.init("Alert_Master", DrawAlertGUI)
    -- Kickstart the data
    GUI_Main.Refresh.Table.Rules = true
    GUI_Main.Refresh.Table.Filtered = true
    GUI_Main.Refresh.Table.Unhandled = true
    mq.imgui.init('DrawSearchWindow', DrawSearchGUI)
    print_ts('\ayAlert Master (v2024-01-29)\nOriginal by (\a-to_O\ay) Special.Ed (\a-to_O\ay)\n\ayUpdated by (\a-to_O\ay) Grimmier (\a-to_O\ay)')
    print_ts('\atLoaded '..settings_file)
    print_ts('\ay/am help for usage')
    print_status()
    RefreshZone()
end
local should_include_player = function(spawn)
    local name = spawn.CleanName()
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
    local in_guild = ignoreguild and Me.Guild() ~= nil and Me.Guild() == guild
    if in_group or in_raid or in_guild then return false end
    return true
end
local run_char_commands = function()
    if settings[CharCommands] ~= nil then
        for k, cmd in pairs(settings[CharCommands]) do CMD.docommand(cmd) end
    end
end
local spawn_search_players = function(search)
    local tmp = {}
    local cnt = SpawnCount(search)()
    if cnt ~= nil or cnt > 0 then
        for i = 1, cnt do
            local pc = NearestSpawn(i,search)
            if pc ~= nil and pc.CleanName() ~= nil then
                local name = pc.CleanName()
                local guild = pc.Guild() or 'No Guild'
                if should_include_player(pc) then
                    tmp[name] = {
                        name = (pc.GM() and '\ag*GM*\ax ' or '')..'\ar'..name..'\ax',
                        guild = '<\ay'..guild..'\ax>',
                        distance = math.floor(pc.Distance() or 0),
                        time = os.time()
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
            local search = 'npc '..v
            local cnt = SpawnCount(search)()
            for i = 1, cnt do
                local spawn = NearestSpawn(i, search)
                local id = spawn.ID()
                if spawn ~= nil and id ~= nil then
                    -- Case-sensitive comparison using CleanName for exact matching
                    if spawn.CleanName() == v or spawn.Name() == v then
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
                    print_ts(GetCharZone()..v.name..' '..v.guild..' entered the zone. '..v.distance..' units away.')
                    elseif (remind ~= nil and remind > 0) and tGMs[name] ~= nil and os.difftime(os.time(), tGMs[name].time) > remind then
                    tGMs[name].time = v.time
                    print_ts(GetCharZone()..v.name..' loitering ' ..v.distance.. ' units away.')
                end
            end
            if tGMs ~= nil then
                for name, v in pairs(tGMs) do
                    if tmp[name] == nil then
                        tGMs[name] = nil
                        print_ts(GetCharZone()..v.name..' left the zone.')
                    end
                end
            end
        end
    end
end
local check_for_pcs = function()
    if active and pcs then
        local tmp = spawn_search_players('pc radius '..radius..' zradius '..zradius..' notid '..Me.ID())
        local charZone = '\aw[\a-o'..Me.CleanName()..'\aw|\at'..Zone.ShortName():lower()..'\aw] '
        if tmp ~= nil then
            for name, v in pairs(tmp) do
                if tPlayers[name] == nil then
                    tPlayers[name] = v
                    print_ts(GetCharZone()..v.name..' '..v.guild..' entered the alert radius. '..v.distance..' units away.')
                    -- run commands here
                    elseif (remind ~= nil and remind > 0) and tPlayers[name] ~= nil and os.difftime(os.time(), tPlayers[name].time) > remind then
                    tPlayers[name].time = v.time
                    print_ts(GetCharZone()..v.name..' loitering ' ..v.distance.. ' units away.')
                    run_char_commands()
                end
            end
            if tPlayers ~= nil then
                for name, v in pairs(tPlayers) do
                    if tmp[name] == nil then
                        tPlayers[name] = nil
                        print_ts(GetCharZone()..v.name..' left the alert radius.')
                    end
                end
            end
        end
    end
end
local check_for_spawns = function()
    if active and spawns then
        local tmp = spawn_search_npcs()
        local spawnAlertsUpdated = false
        local charZone = '\aw[\a-o'..Me.CleanName()..'\aw|\at'..Zone.ShortName():lower()..'\aw] '
        if tmp ~= nil then
            for id, v in pairs(tmp) do
                if tSpawns[id] == nil then
                    if check_safe_zone() ~= true then
                        print_ts(GetCharZone()..'\ag'..tostring(v.CleanName())..'\ax spawn alert! '..tostring(math.floor(v.Distance() or 0))..' units away.')
                        spawnAlertsUpdated = true
                    end
                    tSpawns[id] = v
                    spawnAlerts[id] = v
                    numAlerts =numAlerts + 1
                end
            end
            if tSpawns ~= nil then
                for id, v in pairs(tSpawns) do
                    if tmp[id] == nil then
                        if check_safe_zone() ~= true then
                            print_ts(GetCharZone()..'\ag'..tostring(v.CleanName())..'\ax was killed or despawned.')
                            AlertWindow_Show = false
                            AlertWindowOpen = false
                            spawnAlertsUpdated = true
                        end
                        tSpawns[id] = nil
                        spawnAlerts[id] = nil
                        numAlerts = numAlerts - 1
                    end
                end
            end
            -- Check if there are any entries in the spawnAlerts table
            if next(spawnAlerts) ~= nil and spawnAlertsUpdated then
                if doAlert then
                    AlertWindow_Show = true
                    AlertWindowOpen = true
                    DrawAlertGUI()
                end
                alertTime = os.time()
                if doBeep then CMD('/beep') end
            end
        end
    end
end
local check_for_announce = function()
    if active and announce then
        local tmp = spawn_search_players('pc notid '..Me.ID())
        local charZone = '\aw[\a-o'..Me.CleanName()..'\aw|\at'..Zone.ShortName():lower()..'\aw] '
        if tmp ~= nil then
            for name, v in pairs(tmp) do
                if tAnnounce[name] == nil then
                    tAnnounce[name] = v
                    print_ts(GetCharZone()..v.name..' '..v.guild..' entered the zone.')
                end
            end
            if tAnnounce ~= nil then
                for name, v in pairs(tAnnounce) do
                    if tmp[name] == nil then
                        tAnnounce[name] = nil
                        print_ts(GetCharZone()..v.name..' left the zone.')
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
        tGMs, tAnnounce, tPlayers, tSpawns, spawnAlerts, Table_Cache.Unhandled, Table_Cache.Mobs, Table_Cache.Rules = {}, {}, {}, {}, {}, {}, {}, {}
        zone_id = Zone.ID()
        alertTime = os.time()
    end
end
local loop = function()
    while true do
        check_for_zone_change()
        check_for_spawns() -- always refresh spawn list and only alert if not a safe zone.(checked later in the function)
        if check_safe_zone() ~= true then
            check_for_gms()
            check_for_announce()
            check_for_pcs()
        end
        if Me.Zoning() then numAlerts = 0 end
        --CMD('/echo '..numAlerts)
        if check_safe_zone() ~= true then
            if ((os.time() - alertTime) > (remind * 60) and AlertWindow_Show == false and numAlerts >0) then
                if doAlert then
                    AlertWindow_Show = true
                    AlertWindowOpen = true
                    DrawAlertGUI()
                end
                if doBeep then CMD('/beep') end
                alertTime = os.time()
            end
        end
        if SearchWindow_Show == true or #Table_Cache.Mobs < 1 then RefreshZone() end
        curZone = TLO.Zone.Name
        if GUI_Main.Refresh.Table.Unhandled then RefreshUnhandled() end
        mq.delay(delay..'s')
    end
end
setup()
loop()
