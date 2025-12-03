local KQversion = "KamberQuests v1.4.5"

-- Function to return settings to defaults
local function SetAllDefaults()
    
    KamberQuestsDB = {trackAll = false, daily = true, weekly = true, zone = true, completed = true, pvp = false, dungeon = false, professions = false, raid = false, important = false, version = KQversion}
   
end

if KamberQuestsDB == nil then
    SetAllDefaults()
end

--local variable definitions
local InitializeOptions     -- placeholder for UI Options screen function
local currentMapID = nil    -- cache variable for the player's current map/zone ID as given by the C_Map variable
local currentMapName = nil  -- cache variable for the player's current map/zone name
local questMapID = nil      -- cache variable for the player's current map/zone ID as given by the quest log
local KQ_Timer = nil        -- Timer variable to avoid flooded quest log updates
local C_Map = C_Map         -- localize global
local C_QuestLog = C_QuestLog -- localize global
local C_SuperTrack = C_SuperTrack -- localize global

local function resetMapCache()
    -- set the cache variables back to nil. call this when the map change events are triggered and BEFORE the UpdateQuestWatch function
    currentMapID = nil    
    currentMapName = nil  
    questMapID = nil      
end

local function IsQuestObjectivesComplete(questID)
    local objectives = C_QuestLog.GetQuestObjectives(questID)
        if not objectives or type(objectives) ~= 'table' then return false end

    for _, objective in ipairs(objectives) do
        if not objective.finished then
            return false
        end
    end
    return true
end

local function IsQuestInCurrentZone(questID)
    --get current zone for player along with the current zone from the blizzard quest API
    -- questHeader gets the zone for the quest header/group.  also check this against the name of the current map
    currentMapID = currentMapID or C_Map.GetBestMapForUnit("player")    -- grab cached currentMapID or retrieve from C_Map
    questMapID = questMapID or C_QuestLog.GetMapForQuestPOIs()          -- grab cached questMapID or retrieve from C_QuestLog
    
    local function checkMapName(mapID)
        -- attempt to get the name of the player's current zone
        if mapID and not currentMapName then    -- if currentMapName is cached this part is skipped
            local MapInfo = C_Map.GetMapInfo(mapID)
            if MapInfo then
                currentMapName = MapInfo.name
            end
        end
        -- if we have the player's zone name lets try to get the quest's header name
        if currentMapName then
            local questHeaderIndex = C_QuestLog.GetHeaderIndexForQuest(questID) -- grab the group header index that this quest belongs to in the quest log.
            if questHeaderIndex then
                local questHeaderZoneText  = C_QuestLog.GetTitleForLogIndex(questHeaderIndex)
                -- if the quest header matches the current zone name then return true that we are in the right zone for this quest group
                if questHeaderZoneText and questHeaderZoneText == currentMapName then
                    return true
                end
                -- if we are tracking important quests and the zone header is "SPECIAL" then consider this quest in the current zone.
                if questHeaderZoneText and questHeaderZoneText == "Special" and KamberQuestsDB.important then
                    return true
                end
            end
        end
    end

    -- execute the above function on both versions of the mapID and cancel further checks if the map name matches (returning true -- the quest is in the zone)
    if checkMapName(currentMapID) then return true end
    if checkMapName(questMapID) then return true end
    
    -- if the quest log header name did NOT match then we continue with a more detailed check:
    local function checkQuestList(mapID)
        local questsOnMap
        if mapID then
            questsOnMap = C_QuestLog.GetQuestsOnMap(mapID)
            for _, questInfo in ipairs(questsOnMap) do
                if questInfo.questID == questID then
                    return true
                end
            end
        end

    end

    -- return true if either checks worked otherwise return false
    return checkQuestList(currentMapID) or checkQuestList(questMapID)
    
end

local function UpdateQuestWatch(event, ...)
    local success, errormessage -- error handler variables for use in this function
    
    --Notify the user than there has been an update!
    if KamberQuestsDB.version ~= KQversion then
        print("You have updated to the new |cFF4169E1" .. KQversion .. "|r")
        KamberQuestsDB.version = KQversion
    end

    --if the event was a zone/map change reset the map cache variables
    if event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
        resetMapCache() -- reset cache variables
    elseif event == "QUEST_ACCEPTED" then   -- OR if this is a new quest accepted event we can do some quick assumptions
        local questID = ...         -- get questID from the event arguments
        success, errormessage = pcall(C_QuestLog.AddQuestWatch, questID, Enum.QuestWatchType.Automatic)
        if not success then
            -- Handle the error gracefully
            --print("KamberQuests: Error tracking quest:", errormessage)  -- Or log to a file if you prefer
        end    -- track this questID.  if it wasn't supposed to be it'll come off during the next event
        return true --abort the remainder of the checks and calculations
    end

    local numQuests = C_QuestLog.GetNumQuestLogEntries()
    

	--back out if the player has no quests in log
	if numQuests == 0 or numQuests == nil then
		return false
	end

	for i = 1, numQuests do
        local info = C_QuestLog.GetInfo(i)
        if not info.isHeader then
            local questID = info.questID
            local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
            local tagID = nil
            --debug quest print out
            --print(" Quest ID: " .. questID .. " named as " .. info.title)
            

            if tagInfo then  -- Checks that tagInfo is not nil
                tagID = tagInfo.tagID
                --debug quest print out
                --print("   tagged as " .. tagInfo.tagName .. "(" .. tagID .. ")")
            end
            
            -- if the player is "Super Tracking" the current questID then we want to ignore it altogether and not do any add/remove watch functions on it that might turn off the supertrack
            if C_SuperTrack.GetSuperTrackedQuestID() ~= questID then
                -- Check if the quest fits the criteria to be tracked. Checks both the player's preference for tracking and whether the criteria is met.
                local isEverything = KamberQuestsDB.trackAll
                local isDaily = KamberQuestsDB.daily and (info.frequency == Enum.QuestFrequency.Daily)
                local isWeekly = KamberQuestsDB.weekly and (info.frequency == Enum.QuestFrequency.Weekly or info.frequency == Enum.QuestFrequency.ResetByScheduler)
                local isComplete = KamberQuestsDB.completed and (C_QuestLog.IsComplete(questID) or IsQuestObjectivesComplete(questID) or C_QuestLog.IsQuestFlaggedCompleted(questID) or C_QuestLog.ReadyForTurnIn(questID))
                local isInZone = KamberQuestsDB.zone and (IsQuestInCurrentZone(questID) or C_QuestLog.IsOnMap(questID) or info.isOnMap or info.hasLocalPOI)
                local isPvP = tagID and KamberQuestsDB.pvp and (tagID == Enum.QuestTag.PvP)
                local isRaid = tagID and KamberQuestsDB.raid and (tagID == Enum.QuestTag.Raid or tagID == Enum.QuestTag.Raid10 or tagID == Enum.QuestTag.Raid25)
                local isDungeon = tagID and KamberQuestsDB.dungeon and (tagID == Enum.QuestTag.Dungeon or tagID == Enum.QuestTag.Delve or tagID == Enum.QuestTag.Scenario)
                local isProfessions = tagID and KamberQuestsDB.professions and (tagID == 267) --hard coding 267 for professions because the Enum doesnt seem to work
                local isImportant = KamberQuestsDB.important and (info.isStory or C_QuestLog.IsImportantQuest(questID) or C_QuestLog.IsLegendaryQuest(questID) or info.campaignID)
                            
                -- If any of the criteria and settings are met then track it, otherwise remove tracking
                if isEverything or isComplete or isDaily or isWeekly or isInZone or isPvP or isRaid or isProfessions or isDungeon or isImportant then
                    success, errormessage = pcall(C_QuestLog.AddQuestWatch, questID, Enum.QuestWatchType.Automatic)
                    if not success then
                        -- Handle the error gracefully
                        --print("KamberQuests: Error tracking quest:", errormessage)  -- Or log to a file if you prefer
                    end
                    --[[ --debug printout
                    local debugstring = "      "
                    if isComplete then debugstring = debugstring .. " isComplete" end
                    if isDaily then debugstring = debugstring .. " isDaily" end
                    if isWeekly then debugstring = debugstring .. " isWeekly" end
                    if isInZone then 
                        debugstring = debugstring .. " isInZone:"
                        if IsQuestInCurrentZone(questID) then debugstring = debugstring .. " ManualZoneCheck" end
                        if info.isOnMap then debugstring = debugstring .. " AutoZoneCheck" end
                    end
                    if isPvP then debugstring = debugstring .. " isPvP" end
                    if isRaid then debugstring = debugstring .. " isRaid" end
                    if isProfessions then debugstring = debugstring .. " isProfessions" end
                    if isDungeon then debugstring = debugstring .. " isDungeon" end
                    print(debugstring) --]]
                else
                    -- only remove the tracking if the quest was auto-tracked.  if the user manually tracked this quest then it needs to stay tracked forever.
                    -- THIS NO LONGER WORKS BECAUSE THE ADDQUESTWATCH function is setting everything to manual!
                    -- TODO: needs to be fixed at a later date when the manual vs auto is fixed by Blizzard
                    --if C_QuestLog.GetQuestWatchType(questID) == Enum.QuestWatchType.Automatic then
                        C_QuestLog.RemoveQuestWatch(questID)
                    --end
                end
            elseif C_SuperTrack.GetSuperTrackedQuestID() == questID then
                -- the quest is superTracked we need to force track it
                success, errormessage = pcall(C_QuestLog.AddQuestWatch, questID, Enum.QuestWatchType.Automatic)
                if not success then
                    -- Handle the error gracefully
                    --print("KamberQuests: Error tracking quest:", errormessage)  -- Or log to a file if you prefer
                end
            end
        end
    end
    C_QuestLog.SortQuestWatches() --re-sort watched quests by prox to player
end

-- Function to use the delay timer and ensure all rapid/flooded quest log updates are finished before we start doing our checks. particularly useful on zone changes to prevent lag
local function Timer_UpdateQuestWatch(event, ...)

    -- clear the timer if it exists
    if KQ_Timer then 
        KQ_Timer:Cancel()
    end

    -- start a new timer
    KQ_Timer = C_Timer.NewTimer(1, function()       -- 1 second delay
        UpdateQuestWatch(event, ...)
        KQ_Timer = nil  -- reset the timer after expiration/execution
    end)
end

-- Function to reset quest tracking
local function ResetQuestTracking()
    local numQuests = C_QuestLog.GetNumQuestLogEntries()

    for i = 1, numQuests do
        local info = C_QuestLog.GetInfo(i)
        if not info.isHeader and C_QuestLog.GetQuestWatchType(info.questID) then
            C_QuestLog.RemoveQuestWatch(info.questID)
        end
    end

    -- Reapply tracking based on addon criteria
    UpdateQuestWatch()
end

-- Slash command function
local function SlashCmdHandler(msg)
    local outputPrefix = "|cFF4169E1KQ|r "
	local command = string.lower(msg)
    if command == "status" then
        -- Output current settings to chat
        local settings = string.format(outputPrefix .. "Current Settings:\nTrack Everything: %s\nDaily Tracking: %s\nWeekly Tracking: %s\nZone Tracking: %s\nCompleted Tracking: %s\nRaid Tracking: %s\nDungeon Tracking: %s\nProfessions Tracking: %s\nImportant Tracking: %s\nPvP Tracking: %s",
            KamberQuestsDB.trackAll and "ON" or "OFF",
            KamberQuestsDB.daily and "ON" or "OFF",
            KamberQuestsDB.weekly and "ON" or "OFF",
            KamberQuestsDB.zone and "ON" or "OFF",
            KamberQuestsDB.completed and "ON" or "OFF",
            KamberQuestsDB.raid and "ON" or "OFF",
            KamberQuestsDB.dungeon and "ON" or "OFF",
            KamberQuestsDB.professions and "ON" or "OFF",
            KamberQuestsDB.important and "ON" or "OFF",
            KamberQuestsDB.pvp and "ON" or "OFF")
        print(settings)
    elseif command == "trackall" then
        KamberQuestsDB.trackAll = not KamberQuestsDB.trackAll
        print(outputPrefix .. "Track Everything: " .. (KamberQuestsDB.trackAll and "ON" or "OFF"))
    elseif command == "daily" then
        KamberQuestsDB.daily = not KamberQuestsDB.daily
        print(outputPrefix .. "Daily Tracking: " .. (KamberQuestsDB.daily and "ON" or "OFF"))
    elseif command == "weekly" then
        KamberQuestsDB.weekly = not KamberQuestsDB.weekly
        print(outputPrefix .. "Weekly Tracking: " .. (KamberQuestsDB.weekly and "ON" or "OFF"))
    elseif command == "zone" then
        KamberQuestsDB.zone = not KamberQuestsDB.zone
        print(outputPrefix .. "Zone Tracking: " .. (KamberQuestsDB.zone and "ON" or "OFF"))
    elseif command == "completed" then
        KamberQuestsDB.completed = not KamberQuestsDB.completed
        print(outputPrefix .. "Completed Tracking: " .. (KamberQuestsDB.completed and "ON" or "OFF"))
    elseif command == "pvp" then
        KamberQuestsDB.pvp = not KamberQuestsDB.pvp
        print(outputPrefix .. "PvP Tracking: " .. (KamberQuestsDB.pvp and "ON" or "OFF"))
    elseif command == "raid" then
        KamberQuestsDB.raid = not KamberQuestsDB.raid
        print(outputPrefix .. "Raid Tracking: " .. (KamberQuestsDB.raid and "ON" or "OFF"))
    elseif command == "dungeon" then
        KamberQuestsDB.dungeon = not KamberQuestsDB.dungeon
        print(outputPrefix .. "Dungeon Tracking: " .. (KamberQuestsDB.dungeon and "ON" or "OFF"))
    elseif command == "professions" then
        KamberQuestsDB.professions = not KamberQuestsDB.professions
        print(outputPrefix .. "Professions Tracking: " .. (KamberQuestsDB.professions and "ON" or "OFF"))
    elseif command == "important" then
        KamberQuestsDB.important = not KamberQuestsDB.important
        print(outputPrefix .. "Important Tracking: " .. (KamberQuestsDB.important and "ON" or "OFF"))
    elseif command == "reset" then
        print(outputPrefix .. "reseting all manually tracked quests.")
        ResetQuestTracking()
    else
		-- Open the Interface Options window to the KamberQuests panel
         Settings.OpenToCategory(KamberQuestsPanel.category:GetID())
    end
    UpdateQuestWatch() -- Update quests based on new settings
    InitializeOptions() -- Update the options panel if its open
end

-- Register slash command
SLASH_KAMBERQUESTS1 = "/kq"
SlashCmdList["KAMBERQUESTS"] = SlashCmdHandler

-- Register event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_POI_UPDATE")
frame:RegisterEvent("SUPER_TRACKING_CHANGED")
frame:SetScript("OnEvent", function(self, event, ...)
    Timer_UpdateQuestWatch(event, ...)  -- Pass event and additional arguments
end)

-- Create the main panel for the addon's options
local panel = CreateFrame("Frame", "KamberQuestsPanel")
panel.name = "KamberQuests"
--InterfaceOptions_AddCategory(panel)
-- Function to add a new category
local function addCategory(name, parent)
    local category, layout = Settings.RegisterCanvasLayoutCategory(panel, name)
    if parent then
        Settings.SetCategoryParent(category, parent)
    end
    Settings.RegisterAddOnCategory(category)
    return category, layout
end

-- Register your addon category
local category, layout = addCategory("KamberQuests")
panel.category = category

-- Function to create a checkbox
local function CreateCheckbox(label, description, variable)
    local checkbox = CreateFrame("CheckButton", "KamberQuests" .. variable .. "Checkbox", panel, "UICheckButtonTemplate")
    checkbox.text = _G[checkbox:GetName() .. "Text"]
    checkbox.text:SetText(label)
    checkbox.tooltipText = description
    checkbox:SetScript("OnClick", function(self)
        KamberQuestsDB[variable] = self:GetChecked()
        UpdateQuestWatch()
    end)
    return checkbox
end

-- Function to toggle all settings on or off
local function SetAllTracking(onoff)
    -- Iterate over all keys in KamberQuestsDB
    for key, _ in pairs(KamberQuestsDB) do
        -- Check if the key is a tracking option (add any exceptions as needed)
        -- excluding the trackAll key as part of the "all on" option
        if key ~= "version" and key ~= "trackAll" then
            KamberQuestsDB[key] = onoff
        end
    end
    
    UpdateQuestWatch()
    InitializeOptions()
    
end


-- Create a large title label for the header
local titleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
titleLabel:SetPoint("TOPLEFT", 16, -16)
titleLabel:SetText(KQversion)

-- Create a description text for the panel
local descriptionText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
descriptionText:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, -8)
descriptionText:SetJustifyH("LEFT")
descriptionText:SetText("Select the types of quests you want to automatically track.\nPress Reset Tracking to clear any manually tracked quests in your log.\nAlternatively you can use:\n     /kq status, /kq config, /kq trackall, /kq reset, /kq daily, /kq weekly,\n     /kq zone, /kq completed, /kq raid, /kq dungeon, /kq professions, /kq pvp, /kq important")

-- Create the reset tracking button
local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetButton:SetSize(120, 25)  -- Adjust the size as needed
resetButton:SetPoint("TOPLEFT", descriptionText, "BOTTOMLEFT", 0, -8)  -- Adjust the position as needed
resetButton:SetText("Reset Tracking")
resetButton:SetScript("OnClick", ResetQuestTracking)

-- Create the all_on tracking button
local allonButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
allonButton:SetSize(120, 25)  -- Adjust the size as needed
allonButton:SetPoint("TOPLEFT", resetButton, "TOPRIGHT", 10, 0)  -- Adjust the position as needed
allonButton:SetText("Set All On")
allonButton:SetScript("OnClick", function() SetAllTracking(true) end)

-- Create the all_off tracking button
local alloffButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
alloffButton:SetSize(120, 25)  -- Adjust the size as needed
alloffButton:SetPoint("TOPLEFT", allonButton, "TOPRIGHT", 10, 0)  -- Adjust the position as needed
alloffButton:SetText("Set All Off")
alloffButton:SetScript("OnClick", function() SetAllTracking(false) end)

-- Create the default tracking button
local defaultButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
defaultButton:SetSize(120, 25)  -- Adjust the size as needed
defaultButton:SetPoint("TOPLEFT", alloffButton, "TOPRIGHT", 10, 0)  -- Adjust the position as needed
defaultButton:SetText("Set Defaults")
defaultButton:SetScript("OnClick", function()
    SetAllDefaults()
    UpdateQuestWatch()
    InitializeOptions()
end)

-- Create checkboxes for each setting
local trackAllCheckbox = CreateCheckbox("Track ALL Quests", "Toggle tracking of ALL quests. (none of the other settings will matter if this is on)", "trackAll")
trackAllCheckbox:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -8)

local dailyCheckbox = CreateCheckbox("Track Daily Quests", "Toggle tracking of daily quests.", "daily")
dailyCheckbox:SetPoint("TOPLEFT", trackAllCheckbox, "BOTTOMLEFT", 0, -8)

local weeklyCheckbox = CreateCheckbox("Track Weekly Quests", "Toggle tracking of weekly quests.", "weekly")
weeklyCheckbox:SetPoint("TOPLEFT", dailyCheckbox, "BOTTOMLEFT")

local zoneCheckbox = CreateCheckbox("Track Current Zone Quests", "Toggle tracking of quests in the current zone.", "zone")
zoneCheckbox:SetPoint("TOPLEFT", weeklyCheckbox, "BOTTOMLEFT")

local completedCheckbox = CreateCheckbox("Track Completed Quests", "Toggle tracking of quests with all objectives completed.", "completed")
completedCheckbox:SetPoint("TOPLEFT", zoneCheckbox, "BOTTOMLEFT")

local raidCheckbox = CreateCheckbox("Track Raid Quests", "Toggle tracking of Raid quests.", "raid")
raidCheckbox:SetPoint("TOPLEFT", completedCheckbox, "BOTTOMLEFT")

local dungeonCheckbox = CreateCheckbox("Track Dungeon Quests", "Toggle tracking of Dungeon/Delve/Scenario quests.", "dungeon")
dungeonCheckbox:SetPoint("TOPLEFT", raidCheckbox, "BOTTOMLEFT")

local professionsCheckbox = CreateCheckbox("Track Professions Quests", "Toggle tracking of Professions quests.", "professions")
professionsCheckbox:SetPoint("TOPLEFT", dungeonCheckbox, "BOTTOMLEFT")

local pvpCheckbox = CreateCheckbox("Track PvP Quests", "Toggle tracking of PvP quests.", "pvp")
pvpCheckbox:SetPoint("TOPLEFT", professionsCheckbox, "BOTTOMLEFT")

local importantCheckbox = CreateCheckbox("Track Important Quests", "Toggle tracking of Important quests.", "important")
importantCheckbox:SetPoint("TOPLEFT", pvpCheckbox, "BOTTOMLEFT")

-- Initialize checkboxes with current settings
InitializeOptions = function()
    trackAllCheckbox:SetChecked(KamberQuestsDB.trackAll)
    dailyCheckbox:SetChecked(KamberQuestsDB.daily)
    weeklyCheckbox:SetChecked(KamberQuestsDB.weekly)
    zoneCheckbox:SetChecked(KamberQuestsDB.zone)
    completedCheckbox:SetChecked(KamberQuestsDB.completed)
    raidCheckbox:SetChecked(KamberQuestsDB.raid)
    dungeonCheckbox:SetChecked(KamberQuestsDB.dungeon)
    professionsCheckbox:SetChecked(KamberQuestsDB.professions)
    pvpCheckbox:SetChecked(KamberQuestsDB.pvp)
    importantCheckbox:SetChecked(KamberQuestsDB.important)
end

panel:SetScript("OnShow", InitializeOptions)
