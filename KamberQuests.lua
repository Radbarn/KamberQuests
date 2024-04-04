local KQversion = "KamberQuests v1.2.5"

-- Function to return settings to defaults
local function SetAllDefaults()
    
    KamberQuestsDB = {daily = true, weekly = true, zone = true, completed = true, pvp = false, dungeon = false, raid = false, version = KQversion}
   
end

if KamberQuestsDB == nil then
    SetAllDefaults()
end


local InitializeOptions -- placeholder

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
    local currentMapID = C_Map.GetBestMapForUnit("player")
    if not currentMapID then return false end

    local questsOnMap = C_QuestLog.GetQuestsOnMap(currentMapID)
    for _, questInfo in ipairs(questsOnMap) do
        if questInfo.questID == questID then
            return true
        end
    end

    return false
end

local function UpdateQuestWatch()
    local numQuests = C_QuestLog.GetNumQuestLogEntries()
    
    --Notify the user than there has been an update!
    if KamberQuestsDB.version ~= KQversion then
        print("You have updated to the new |cFF4169E1" .. KQversion .. "|r")
        KamberQuestsDB.version = KQversion
    end

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
            if tagInfo then  -- Checks that tagInfo is not nil
                tagID = tagInfo.tagID
            end
            
            -- Check if the quest fits the criteria to be tracked. Checks both the player's preference for tracking and whether the criteria is met.
            local isDaily = KamberQuestsDB.daily and (info.frequency == Enum.QuestFrequency.Daily)
			local isWeekly = KamberQuestsDB.weekly and (info.frequency == Enum.QuestFrequency.Weekly)
            local isComplete = KamberQuestsDB.completed and (C_QuestLog.IsComplete(questID) or IsQuestObjectivesComplete(questID))
			local isInZone = KamberQuestsDB.zone and IsQuestInCurrentZone(questID)
            local isPvP = tagID and KamberQuestsDB.pvp and (tagID == Enum.QuestTag.Pvp)
            local isRaid = tagID and KamberQuestsDB.raid and (tagID == Enum.QuestTag.Raid)
            local isDungeon = tagID and KamberQuestsDB.dungeon and (tagID == Enum.QuestTag.Dungeon)
                        
            -- If any of the criteria and settings are met then track it, otherwise remove tracking
            if isComplete or isDaily or isWeekly or isInZone or isAlwaysTracked or isPvP or isRaid or isDungeon then
                C_QuestLog.AddQuestWatch(questID, Enum.QuestWatchType.Automatic)
            else
                -- only remove the tracking if the quest was auto-tracked.  if the user manually tracked this quest then it needs to stay tracked forever.
                if C_QuestLog.GetQuestWatchType(questID) == Enum.QuestWatchType.Automatic then
                    C_QuestLog.RemoveQuestWatch(questID)
                end
            end
        end
    end
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
        local settings = string.format(outputPrefix .. "Current Settings:\nDaily Tracking: %s\nWeekly Tracking: %s\nZone Tracking: %s\nCompleted Tracking: %s\nRaid Tracking: %s\nDungeon Tracking: %s\nPvP Tracking: %s",
                                       KamberQuestsDB.daily and "ON" or "OFF",
                                       KamberQuestsDB.weekly and "ON" or "OFF",
                                       KamberQuestsDB.zone and "ON" or "OFF",
                                       KamberQuestsDB.completed and "ON" or "OFF",
                                       KamberQuestsDB.raid and "ON" or "OFF",
                                       KamberQuestsDB.dungeon and "ON" or "OFF",
                                       KamberQuestsDB.pvp and "ON" or "OFF")
        print(settings)
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
        print(outputPrefix .. "Completed Tracking: " .. (KamberQuestsDB.pvp and "ON" or "OFF"))
    elseif command == "raid" then
        KamberQuestsDB.raid = not KamberQuestsDB.raid
        print(outputPrefix .. "Completed Tracking: " .. (KamberQuestsDB.raid and "ON" or "OFF"))
    elseif command == "dungeon" then
        KamberQuestsDB.dungeon = not KamberQuestsDB.dungeon
        print(outputPrefix .. "Completed Tracking: " .. (KamberQuestsDB.dungeon and "ON" or "OFF"))
    elseif command == "reset" then
        print(outputPrefix .. "reseting all manually tracked quests.")
        ResetQuestTracking()
    else
		-- Open the Interface Options window to the KamberQuests panel
        InterfaceOptionsFrame_OpenToCategory(KamberQuestsPanel)
        InterfaceOptionsFrame_OpenToCategory(KamberQuestsPanel)  -- Call twice due to a Blizzard bug that may not open it correctly the first time
    end
    UpdateQuestWatch() -- Update quests based on new settings
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
frame:SetScript("OnEvent", UpdateQuestWatch)

-- Create the main panel for the addon's options
local panel = CreateFrame("Frame", "KamberQuestsPanel")
panel.name = "KamberQuests"
InterfaceOptions_AddCategory(panel)

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
        if key ~= "version" then
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
descriptionText:SetText("Select the types of quests you want to automatically track.\nPress Reset Tracking to clear any manually tracked quests in your log.\nAlternatively you can use:\n     /kq status, /kq config, /kq reset, /kq daily, /kq weekly, /kq zone, /kq completed, /kq raid, /kq dungeon, /kq pvp")

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
local dailyCheckbox = CreateCheckbox("Track Daily Quests", "Toggle tracking of daily quests.", "daily")
dailyCheckbox:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -8)

local weeklyCheckbox = CreateCheckbox("Track Weekly Quests", "Toggle tracking of weekly quests.", "weekly")
weeklyCheckbox:SetPoint("TOPLEFT", dailyCheckbox, "BOTTOMLEFT")

local zoneCheckbox = CreateCheckbox("Track Current Zone Quests", "Toggle tracking of quests in the current zone.", "zone")
zoneCheckbox:SetPoint("TOPLEFT", weeklyCheckbox, "BOTTOMLEFT")

local completedCheckbox = CreateCheckbox("Track Completed Quests", "Toggle tracking of quests with all objectives completed.", "completed")
completedCheckbox:SetPoint("TOPLEFT", zoneCheckbox, "BOTTOMLEFT")

local raidCheckbox = CreateCheckbox("Track Raid Quests", "Toggle tracking of Raid quests.", "raid")
raidCheckbox:SetPoint("TOPLEFT", completedCheckbox, "BOTTOMLEFT")

local dungeonCheckbox = CreateCheckbox("Track Dungeon Quests", "Toggle tracking of Dungeon quests.", "dungeon")
dungeonCheckbox:SetPoint("TOPLEFT", raidCheckbox, "BOTTOMLEFT")

local pvpCheckbox = CreateCheckbox("Track PvP Quests", "Toggle tracking of PvP quests.", "pvp")
pvpCheckbox:SetPoint("TOPLEFT", dungeonCheckbox, "BOTTOMLEFT")

-- Initialize checkboxes with current settings
InitializeOptions = function()
    dailyCheckbox:SetChecked(KamberQuestsDB.daily)
    weeklyCheckbox:SetChecked(KamberQuestsDB.weekly)
    zoneCheckbox:SetChecked(KamberQuestsDB.zone)
    completedCheckbox:SetChecked(KamberQuestsDB.completed)
    raidCheckbox:SetChecked(KamberQuestsDB.raid)
    dungeonCheckbox:SetChecked(KamberQuestsDB.dungeon)
    pvpCheckbox:SetChecked(KamberQuestsDB.pvp)
end

panel:SetScript("OnShow", InitializeOptions)