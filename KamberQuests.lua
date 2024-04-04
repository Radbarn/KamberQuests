local KQversion = "KamberQuests v1.1.0"

-- Initialize or load saved variables
KamberQuestsDB = KamberQuestsDB or {daily = true, weekly = true, zone = true, completed = true}

local function IsQuestObjectivesComplete(questID)
    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if not objectives then return false end

    for _, objective in ipairs(objectives) do
        if not objective.finished then
            return false
        end
    end
    return true
end

local function UpdateQuestWatch()
    local numQuests = C_QuestLog.GetNumQuestLogEntries()

	--back out if the player has no quests in log
	if numQuests == 0 or numQuests == nil then
		return false
	end

    local currentMapID = C_Map.GetBestMapForUnit("player")

	
	for i = 1, numQuests do
        local info = C_QuestLog.GetInfo(i)
        if not info.isHeader then
            local questID = info.questID
            local questZone = C_TaskQuest.GetQuestZoneID(questID)

            -- Check if the quest fits the criteria to be tracked. Checks both the player's preference for tracking and whether the criteria is met.
            local isDaily = KamberQuestsDB.daily and (info.frequency == Enum.QuestFrequency.Daily)
			local isWeekly = KamberQuestsDB.weekly and (info.frequency == Enum.QuestFrequency.Weekly)
            local isComplete = KamberQuestsDB.completed and (C_QuestLog.IsComplete(questID) or IsQuestObjectivesComplete(questID)) --(C_QuestLog.IsComplete(questID) or C_QuestLog.IsQuestFlaggedCompleted(questID) or IsQuestObjectivesComplete(questID))
			local isInZone = KamberQuestsDB.zone and (questZone and questZone == currentMapID)

            -- If any of the criteria and settings are met then track it, otherwise remove tracking
            if isComplete or isDaily or isWeekly or isInZone then
                C_QuestLog.AddQuestWatch(questID, Enum.QuestWatchType.Automatic)
            else
                C_QuestLog.RemoveQuestWatch(questID)
            end
        end
    end
end

-- Slash command function
local function SlashCmdHandler(msg)
    local outputPrefix = "|cFF4169E1KQ|r "
	local command = string.lower(msg)
    if command == "status" then
        -- Output current settings to chat
        local settings = string.format(outputPrefix .. "Current Settings:\nDaily Tracking: %s\nWeekly Tracking: %s\nZone Tracking: %s\nCompleted Tracking: %s",
                                       KamberQuestsDB.daily and "ON" or "OFF",
                                       KamberQuestsDB.weekly and "ON" or "OFF",
                                       KamberQuestsDB.zone and "ON" or "OFF",
                                       KamberQuestsDB.completed and "ON" or "OFF")
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

-- Create a large title label for the header
local titleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
titleLabel:SetPoint("TOPLEFT", 16, -16)
titleLabel:SetText(KQversion)

-- Create a description text for the panel
local descriptionText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
descriptionText:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, -8)
descriptionText:SetJustifyH("LEFT")
descriptionText:SetText("Select the types of quests you want to automatically track.\nAlternatively you can use /kq status, /kq config, /kq daily, /kq weekly, /kq zone, or /kq completed.")

-- Create checkboxes for each setting
local dailyCheckbox = CreateCheckbox("Track Daily Quests", "Toggle tracking of daily quests.", "daily")
dailyCheckbox:SetPoint("TOPLEFT", descriptionText, "BOTTOMLEFT", 0, -8)

local weeklyCheckbox = CreateCheckbox("Track Weekly Quests", "Toggle tracking of weekly quests.", "weekly")
weeklyCheckbox:SetPoint("TOPLEFT", dailyCheckbox, "BOTTOMLEFT")

local zoneCheckbox = CreateCheckbox("Track Current Zone Quests", "Toggle tracking of quests in the current zone.", "zone")
zoneCheckbox:SetPoint("TOPLEFT", weeklyCheckbox, "BOTTOMLEFT")

local completedCheckbox = CreateCheckbox("Track Completed Quests", "Toggle tracking of quests with all objectives completed.", "completed")
completedCheckbox:SetPoint("TOPLEFT", zoneCheckbox, "BOTTOMLEFT")

-- Initialize checkboxes with current settings
local function InitializeOptions()
    dailyCheckbox:SetChecked(KamberQuestsDB.daily)
    weeklyCheckbox:SetChecked(KamberQuestsDB.weekly)
    zoneCheckbox:SetChecked(KamberQuestsDB.zone)
    completedCheckbox:SetChecked(KamberQuestsDB.completed)
end
panel:SetScript("OnShow", InitializeOptions)