--KamberQuests v1.0.3

-- Name of Addon
local name = "KamberQuests"

-- Settings, retrieving from SavedVariables or using defaults
KQ_setting_active = KQ_setting_active or true		-- if false the addon will not do anything (stops autotracking temporarily)
KQ_setting_debug = KQ_setting_debug or false	-- if true the addon will print verbose chat messages to help debug
KQ_setting_watchweekly = KQ_setting_watchweekly or true	-- if true the addon will force weekly quests to be always tracked
KQ_setting_watchdaily = KQ_setting_watchdaily or true		-- if true the addon will force daily quests to be always tracked
local KQ_started = false		-- using this to prevent spamming messages

-- Select events to be watched
local function watchEvents()
	local events = {
		"ZONE_CHANGED",
		"ZONE_CHANGED_NEW_AREA",
		"QUEST_LOG_UPDATE",
		"QUEST_FINISHED",
		"QUEST_TURNED_IN",
		"QUEST_GREETING",
		"QUEST_ACCEPTED",
		"QUEST_POI_UPDATE",
		"QUEST_WATCH_UPDATE",
		"ADDON_LOADED"
		}
	
	return events
end


-- Create frame to catch events
local frame = CreateFrame("FRAME", "DUMMY_FRAME");

-- Register events with frame
for _,event in ipairs(watchEvents()) do
	frame:RegisterEvent(event)
end

-- Our Actual Handler
local function KQHandler()

	if not KQ_setting_active then return false end

	if UnitOnTaxi("player") then 
		if KQ_setting_debug then print("KQ On Taxi") end
		return false
	end

	--Get current location/map/zone
	local map = C_Map.GetBestMapForUnit("player")
	if map == nil then 
		return false 
	end
	local mapname = C_Map.GetMapInfo(map).name
	local maptype = C_Map.GetMapInfo(map).mapType
	
	-- If map is empty then quit cause wtf
	if map == nil then
		if KQ_setting_debug then print ("KQ map was nil") end
		return
	end

	
	-- Only retrack quests if maptype is Cosmic, Zone, Micro, or Orphan
	if maptype == 0 or maptype == 3 or maptype == 5 or maptype == 6 then
		if KQ_setting_debug then 
			print("KQ maptype was valid to track quests: " .. maptype)
			print("KQ current map is: " .. mapname .. " (" .. map .. ")")
		end

		-- Setup variables, we are ready to do stuff
		local QuestsOnMap = C_QuestLog.GetQuestsOnMap(map)
		local NumQuestLogEntries, numQuests = C_QuestLog.GetNumQuestLogEntries();
		local tableQuestsWatch = {}
		local tableQuestsOnMap = {}

		-- get current active watchlist (tracked quests)
		for i = 1, C_QuestLog.GetNumQuestWatches() do
			tableQuestsWatch[i] = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
			if KQ_setting_debug then print(tableQuestsWatch[i] .. " Watching") end
		end
		
		-- get current list of quests on this map
		if QuestsOnMap ~= nil then
			for index, value in ipairs(QuestsOnMap) do
				-- what does type 13 represent?? we are not adding it to the list
				if (value.type == 13) then
					if KQ_setting_debug then print(value.questID .. " on the map and type 13") end
				else
					tableQuestsOnMap[value] = value.questID
					if KQ_setting_debug then print(value.questID .. " on the map " .. value.type) end
				end
			end
		end
		
		--Check each quest in the quest log
		for i = 1, NumQuestLogEntries + 1 do
			--if its not a blank index
			if C_QuestLog.GetQuestIDForLogIndex(i) ~= nil and C_QuestLog.GetTitleForQuestID(C_QuestLog.GetQuestIDForLogIndex(i)) ~= nil then
				-- if the questID is not 0
				if C_QuestLog.GetQuestIDForLogIndex(i) ~= 0 then
					-- series of ELSEIF checks to turn quests on and off in the tracker
					if C_QuestLog.GetInfo(i).frequency == 1 and KQ_setting_watchdaily then
						-- Daily quest and setting is true - ADD
						C_QuestLog.AddQuestWatch(C_QuestLog.GetInfo(i).questID,0)
						if KQ_setting_debug then print("Daily Quest Turning On: " .. " i: " .. i .. " QID: " .. C_QuestLog.GetQuestIDForLogIndex(i) .. " Freq: " .. C_QuestLog.GetInfo(i).frequency .." Title: " .. C_QuestLog.GetTitleForQuestID(C_QuestLog.GetQuestIDForLogIndex(i))) end
					elseif C_QuestLog.GetInfo(i).frequency == 2 and KQ_setting_watchweekly then
						-- Weekly quest and setting is true - ADD
						C_QuestLog.AddQuestWatch(C_QuestLog.GetInfo(i).questID,0)
						if KQ_setting_debug then print("Weekly Quest Turning On: " .. " i: " .. i .. " QID: " .. C_QuestLog.GetQuestIDForLogIndex(i) .. " Freq: " .. C_QuestLog.GetInfo(i).frequency .." Title: " .. C_QuestLog.GetTitleForQuestID(C_QuestLog.GetQuestIDForLogIndex(i))) end
					elseif exists(tableQuestsOnMap,C_QuestLog.GetQuestIDForLogIndex(i)) then
						-- Quest is on this map - ADD
						C_QuestLog.AddQuestWatch(C_QuestLog.GetInfo(i).questID,0)
						if KQ_setting_debug then print("Map Quest Turning On: " .. " i: " .. i .. " QID: " .. C_QuestLog.GetQuestIDForLogIndex(i) .. " Freq: " .. C_QuestLog.GetInfo(i).frequency .." Title: " .. C_QuestLog.GetTitleForQuestID(C_QuestLog.GetQuestIDForLogIndex(i))) end
					elseif not exists(tableQuestsOnMap,C_QuestLog.GetQuestIDForLogIndex(i)) then
						-- Quest is not on this map - REMOVE
						C_QuestLog.RemoveQuestWatch(C_QuestLog.GetQuestIDForLogIndex(i))
						if KQ_setting_debug then print("NonMap Quest Removing: " .. " i: " .. i .. " QID: " .. C_QuestLog.GetQuestIDForLogIndex(i) .. " Freq: " .. C_QuestLog.GetInfo(i).frequency .. " Title: " .. C_QuestLog.GetTitleForQuestID(C_QuestLog.GetQuestIDForLogIndex(i))) end
					end
				end
			end
		end
	else
		if KQ_setting_debug then
			print("KQ maptype was invalid to track quests: " .. maptype)
			print("KQ current map is: " .. mapname .. " (" .. map .. ")")
		end
		return false 
	end
		
	
end

-- Handle event from game
local function eventHandler(self, event, arg1, ...)
	if event == "ADDON_LOADED" and name == arg1 then
		if not KQ_started then 
			if KQ_setting_active then
				print("|cFF4169E1Kamber Quest Tracking: |cFF00FF00On")
			else
				print("|cFF4169E1Kamber Quest Tracking: |cFFFF0000Off")
			end
			KQ_started = true
		end
	elseif event == "ADDON_LOADED" then
		return false
	else
		KQHandler()
	end
end

-- Check value exists in table
function exists(tab, value)
    local v
    for _, v in pairs(tab) do
        if v == value then
            return true
        elseif type(v) == "table" then
            return exists(v, value)
        end
    end
    return false
end

--tie the game events to the our game handler
frame:SetScript("OnEvent", eventHandler);

-- Define the function for the slash command
SlashCmdList["KQ"] = function(msg)
	local command, arg = strsplit(" ", msg, 2)
	
	if command == "debug" then
		-- Toggle the value
		KQ_setting_debug = not KQ_setting_debug
		-- Print the new value to the chat window
		print("|cFF4169E1KQ |cFFFFFFFFDebug Mode is now: ", KQ_setting_debug)
	elseif command == "daily" then
	    -- Toggle the value
		KQ_setting_watchdaily = not KQ_setting_watchdaily
		-- Print the new value to the chat window
		print("|cFF4169E1KQ |cFFFFFFFFDaily Tracking is now: ", KQ_setting_watchdaily)
	elseif command == "weekly" then
		-- Toggle the value
		KQ_setting_watchweekly = not KQ_setting_watchweekly
		-- Print the new value to the chat window
		print("|cFF4169E1KQ |cFFFFFFFFWeekly Tracking is now: ", KQ_setting_watchweekly)
	elseif command == "active" then
		-- Toggle the value
		KQ_setting_active = not KQ_setting_active
		-- Print the new value to the chat window
		print("|cFF4169E1KQ |cFFFFFFFFAutotracking is now: ", KQ_setting_active)
	elseif command == "on" then
		-- Set the value
		KQ_setting_active = true
		-- Print the new value to the chat window
		print("|cFF4169E1KQ |cFFFFFFFFAutotracking is now: ", KQ_setting_active)
	elseif command == "off" then
		-- Set the value
		KQ_setting_active = false
		-- Print the new value to the chat window
		print("|cFF4169E1KQ |cFFFFFFFFAutotracking is now: ", KQ_setting_active)
	elseif command == "status" then
		print("|cFF4169E1KQ |cFFFFFFFFAutotracking is currently: ", KQ_setting_active)
		print("|cFF4169E1KQ |cFFFFFFFFDaily Tracking is currently: ", KQ_setting_watchdaily)
		print("|cFF4169E1KQ |cFFFFFFFFWeekly Tracking is currently: ", KQ_setting_watchweekly)
	elseif command == nil or command == "" or command == " " then
		print("|cFF4169E1KQ |cFFFFFFFFAutotracking is currently: ", KQ_setting_active)
	else
		print("|cFF4169E1KQ |cFFFF0000unrecognized command: " .. command)
	end
	KQHandler()
end

-- Bind the slash command to the function
SLASH_KQ1 = "/kq"
SLASH_KQ2 = "/kamberquests"