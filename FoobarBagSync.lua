local FBS = select(2, ...) --grab the addon namespace
FBS = LibStub("AceAddon-3.0"):NewAddon(FBS, "FoobarBagSync", "AceEvent-3.0", "AceConsole-3.0")

local debugf = tekDebug and tekDebug:GetFrame("FoobarBagSync")

function FBS:Debug(...)
    if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end
end

--testing variables
FBS.enableFaction = true
FBS.enableGuild = true
FBS.enableBNetAccountItems = true
FBS.enableCrossRealmsItems = true
FBS.enableTooltipGreenCheck = true
FBS.enableFactionIcons = true
FBS.enableRealmIDTags = true
FBS.enableRealmAstrickName = false
FBS.enableRealmShortName = false
FBS.enableTooltips = true
FBS.enableTooltipSeperator = true
FBS.tooltipOnlySearch = false
FBS.showGuildNames = true
FBS.showTotal = true
FBS.enableUnitClass = true
FBS.enableTooltipItemID = true
FBS.enableNoItemExclusion = true

local FBSL = {}
FBSL.TooltipBag = "Bags:"
FBSL.TooltipBank = "Bank:"
FBSL.TooltipEquip = "Equip:"
FBSL.TooltipGuild = "Guild:"
FBSL.TooltipMail = "Mail:"
FBSL.TooltipVoid = "Void:"
FBSL.TooltipReagent = "Reagent:"
FBSL.TooltipAuction = "AH:"
FBSL.TooltipTotal = "Total:"
FBSL.TooltipItemID = "[ItemID]:"
FBSL.TooltipDelimiter = ", "

local function match(search, ...)
  for i = 1, select('#', ...) do
    local text = select(i, ...)
    if text and text:lower():find(search) then
      return true
    end
  end
  return false
end

local function pairsByKeys (t, f)
	local a = {}
		for n in pairs(t) do table.insert(a, n) end
		table.sort(a, f)
		local i = 0      -- iterator variable
		local iter = function ()   -- iterator function
			i = i + 1
			if a[i] == nil then return nil
			else return a[i], t[a[i]]
			end
		end
	return iter
end

local function rgbhex(r, g, b)
	if type(r) == "table" then
		if r.r then
			r, g, b = r.r, r.g, r.b
		else
			r, g, b = unpack(r)
		end
	end
	return string.format("|cff%02x%02x%02x", (r or 1) * 255, (g or 1) * 255, (b or 1) * 255)
end

local function tooltipColor(color, str)
	return string.format("|cff%02x%02x%02x%s|r", (color.r or 1) * 255, (color.g or 1) * 255, (color.b or 1) * 255, tostring(str))
end

local function ParseItemLink(link)
	if not link then return nil end
	if tonumber(link) then return link end
	local result = link:match("item:([%d:]+)") --strip the item: portion of the string
	
	if result then
		result = gsub(result, ":0:", "::") --supposedly blizzard removed all the zero's in patch 7.0. Lets do it just in case!
		--split everything into a table so we can count up to the bonusID portion
		local countSplit = {strsplit(":", result)}
		
		--make sure we have a bonusID count
		if countSplit and #countSplit > 13 then
			local count = countSplit[13] or 0 -- do we have a bonusID number count?
			count = count == "" and 0 or count --make sure we have a count if not default to zero
			count = tonumber(count)
			
			--check if we have even anything to work with for the amount of bonusID's
			--btw any numbers after the bonus ID are either upgradeValue which we don't care about or unknown use right now
			--http://wow.gamepedia.com/ItemString
			if count > 0 and countSplit[1] then
				--return the string with just the bonusID's in it
				local newItemStr = ""
				
				--11th place because 13 is bonus ID, one less from 13 (12) would be technically correct, but we have to compensate for ItemID we added in front so substract another one (11).
				--string.rep repeats a pattern.
				newItemStr = countSplit[1]..string.rep(":", 11)
				
				--lets add the bonusID's, ignore the end past bonusID's
				for i=13, (13 + count) do
					--check for certain bonus ID's
					if i == 14 and tonumber(countSplit[i]) == 3407 then
						--the tradeskill window returns a 1:3407 for bonusID on regeant info and craft item in C_TradeSkillUI, ignore it
						return result:match("^(%d+):")
					end
					newItemStr = newItemStr..":"..countSplit[i]
				end
				
				--add the unknowns at the end, upgradeValue doesn't always have to be supplied.
				newItemStr = newItemStr..":::"

				return newItemStr
			end
		end
		
		--we don't have any bonusID's that we care about, so return just the ItemID which is the first number
		return result:match("^(%d+):")
	end
	
	--nothing to return so return nil
	return nil
end

local function ToShortItemID(link)
	if not link then return nil end
	if tonumber(link) then return link end
	link = gsub(link, ":0:", "::")
	return link:match("^(%d+):") or nil
end


-----------------------
--    LOGIN HANDLER         --
------------------------------

function FBS:OnEnable()

	--lets grab the first player information from the DB as default
	for realm, rd in pairs(FBS_DB) do
		for k, v in pairs(rd) do
			if v.guild and v.faction and v.realm then

				self.currentPlayer = k
				self.currentRealm = v.realm
				self.playerClass = v.class
				self.playerFaction = v.faction

				break
			end
		end
	end
	

	local realmList = {} --we are going to use this to store a list of connected realms, including the current realm
	local autoCompleteRealms = GetAutoCompleteRealms() or { self.currentRealm }
	
	table.insert(realmList, self.currentRealm)
	
	self.crossRealmNames = {}
	for k, v in pairs(autoCompleteRealms) do
		if v ~= self.currentRealm then
			self.crossRealmNames[v] = true
			table.insert(realmList, v)
		end
	end
	
	self.options = {}
	if self.options.colors == nil then self.options.colors = {} end
	if self.options.colors.first == nil then self.options.colors.first = { r = 128/255, g = 1, b = 0 }  end
	if self.options.colors.second == nil then self.options.colors.second = { r = 1, g = 1, b = 1 }  end
	if self.options.colors.total == nil then self.options.colors.total = { r = 244/255, g = 164/255, b = 96/255 }  end
	if self.options.colors.guild == nil then self.options.colors.guild = { r = 101/255, g = 184/255, b = 192/255 }  end
	if self.options.colors.cross == nil then self.options.colors.cross = { r = 1, g = 125/255, b = 10/255 }  end
	if self.options.colors.bnet == nil then self.options.colors.bnet = { r = 53/255, g = 136/255, b = 1 }  end
	if self.options.colors.itemid == nil then self.options.colors.itemid = { r = 82/255, g = 211/255, b = 134/255 }  end
	
	
	--hook the tooltips
	self:HookTooltip(GameTooltip)
	self:HookTooltip(ItemRefTooltip)
	
	local ver = GetAddOnMetadata("FoobarBagSync","Version") or 0
	self:Print("[v|cFFDF2B2B"..ver.."|r] /bgs, /FoobarBagSync")

end

function FBS:FilterDB(dbSelect)

	local xIndex = {}
	local dbObj = FBS_DB
	
--[[ 	if dbSelect and dbSelect == 1 then
		--use BagSyncPROFESSION_DB
		dbObj = self.db.profession
	elseif dbSelect and dbSelect == 2 then
		--use BagSyncCURRENCY_DB
		dbObj = self.db.currency
	end ]]

	--add more realm names if necessary based on BNet or Cross Realms
	if FBS.enableBNetAccountItems then
		for k, v in pairs(dbObj) do
			for q, r in pairs(v) do
				--we do this incase there are multiple characters with same name
				xIndex[q.."^"..k] = r
			end
		end
	elseif FBS.enableCrossRealmsItems then
		for k, v in pairs(dbObj) do
			if k == FBS.currentRealm or FBS.crossRealmNames[k] then
				for q, r in pairs(v) do
					----we do this incase there are multiple characters with same name
					xIndex[q.."^"..k] = r
				end
			end
		end
	else
		--do only the current realm if they don't have anything else configured
		for k, v in pairs(dbObj) do
			if k == FBS.currentRealm then
				for q, r in pairs(v) do
					----can't have multiple characters on same realm, but we need formatting anyways
					xIndex[q.."^"..k] = r
				end
			end
		end
	end
	
	return xIndex
end

function FBS:GetRealmTags(srcName, srcRealm, isGuild)
	
	local tagName = srcName
	local xDBGuild = FBS_GUILD_DB
	local xDBRealmKey = FBS_REALMKEY
	local xDBPlayer = FBS_DB[FBS.currentRealm][FBS.currentPlayer]
		
	local fullRealmName = srcRealm --default to shortened realm first
	
	if xDBRealmKey[srcRealm] then fullRealmName = xDBRealmKey[srcRealm] end --second, if we have a realmkey with a true realm name then use it
	
	if not isGuild then
		local ReadyCheck = [[|TInterface\RaidFrame\ReadyCheck-Ready:0|t]]
		--local NotReadyCheck = [[|TInterface\RaidFrame\ReadyCheck-NotReady:0|t]]
		--Interface\\TargetingFrame\\UI-PVP-FFA

		--put a green check next to the currently logged in character name, make sure to put it as current realm only.  You can have toons with same name on multiple realms
		if srcName == FBS.currentPlayer and srcRealm == FBS.currentRealm and FBS.enableTooltipGreenCheck then
			tagName = tagName.." "..ReadyCheck
		end
	else
		--sometimes a person has characters on multiple connected servers joined to the same guild.
		--the guild information is saved twice because although the guild is on the connected server, the characters themselves are on different servers.
		--too compensate for this, lets check the connected server and return only the guild name.  So it doesn't get processed twice.
		for k, v in pairs(FBS.crossRealmNames) do
			--check to see if the guild exists already on a connected realm and not the current realm
			if k ~= srcRealm and xDBGuild[k] and xDBGuild[k][srcName] then
				--return non-modified guild name, we only want the guild listed once for the cross-realm
				return srcName
			end
		end
	end
	
	--make sure we work with player data not guild data
	if FBS.enableFactionIcons and FBS_DB[srcRealm] and FBS_DB[srcRealm][srcName] then
		local FactionIcon = [[|TInterface\Icons\Achievement_worldevent_brewmaster:18|t]]
		
		if FBS_DB[srcRealm][srcName].faction == "Alliance" then
			FactionIcon = [[|TInterface\Icons\Inv_misc_tournaments_banner_human:18|t]]
		elseif FBS_DB[srcRealm][srcName].faction == "Horde" then
			FactionIcon = [[|TInterface\Icons\Inv_misc_tournaments_banner_orc:18|t]]
		end
		
		tagName = FactionIcon.." "..tagName
	end

	--add Cross-Realm and BNet identifiers to Characters not on same realm
	local crossString = ""
	local bnetString = ""
	
	if FBS.enableRealmIDTags then
		crossString = "XR-"
		bnetString = "BNet-"
	end
	
	if FBS.enableRealmAstrickName then
		fullRealmName = "*"
	elseif FBS.enableRealmShortName then
		fullRealmName = string.sub(fullRealmName, 1, 5) --only use 5 characters of the server name
	end
	
	if FBS.enableBNetAccountItems then
		if srcRealm and srcRealm ~= FBS.currentRealm then
			if not FBS.crossRealmNames[srcRealm] then
				tagName = tagName.." "..rgbhex(FBS.options.colors.bnet).."["..bnetString..fullRealmName.."]|r"
			else
				tagName = tagName.." "..rgbhex(FBS.options.colors.cross).."["..crossString..fullRealmName.."]|r"
			end
		end
	elseif FBS.enableCrossRealmsItems then
		if srcRealm and srcRealm ~= FBS.currentRealm then
			tagName = tagName.." "..rgbhex(FBS.options.colors.cross).."["..crossString..fullRealmName.."]|r"
		end
	end
		
	return tagName
end

function FBS:CreateItemTotals(countTable)
	local info = ""
	local total = 0
	local grouped = 0
	
	--order in which we want stuff displayed
	local list = {
		[1] = { "bag", 			FBSL.TooltipBag },
		[2] = { "bank", 		FBSL.TooltipBank },
		[3] = { "reagentbank", 	FBSL.TooltipReagent },
		[4] = { "equip", 		FBSL.TooltipEquip },
		[5] = { "guild", 		FBSL.TooltipGuild },
		[6] = { "mailbox", 		FBSL.TooltipMail },
		[7] = { "void", 		FBSL.TooltipVoid },
		[8] = { "auction", 		FBSL.TooltipAuction },
	}
		
	for i = 1, #list do
		local count = countTable[list[i][1]]
		if count > 0 then
			grouped = grouped + 1
			info = info..FBSL.TooltipDelimiter..tooltipColor(self.options.colors.first, list[i][2]).." "..tooltipColor(self.options.colors.second, count)
			total = total + count
		end
	end

	--remove the first delimiter since it's added to the front automatically
	info = strsub(info, string.len(FBSL.TooltipDelimiter) + 1)
	if string.len(info) < 1 then return nil end --return nil for empty strings
	
	--if it's groupped up and has more then one item then use a different color and show total
	if grouped > 1 then
		info = tooltipColor(self.options.colors.second, total).." ("..info..")"
	end
	
	return info
end

function FBS:GetClassColor(sName, sClass)
	if not FBS.enableUnitClass then
		return tooltipColor(self.options.colors.first, sName)
	else
		if sName ~= "Unknown" and sClass and RAID_CLASS_COLORS[sClass] then
			return rgbhex(RAID_CLASS_COLORS[sClass])..sName.."|r"
		end
	end
	return tooltipColor(self.options.colors.first, sName)
end

function FBS:AddItemToTooltip(frame, link) --workaround
	if not FBS.enableTooltips then return end
	
	--if we can't convert the item link then lets just ignore it altogether	
	local itemLink = ParseItemLink(link)
	if not itemLink then
		frame:Show()
		return
	end

	--use our stripped itemlink, not the full link
	local shortItemID = ToShortItemID(itemLink)

	--short the shortID and ignore all BonusID's and stats
	if FBS.enableNoItemExclusion then itemLink = shortItemID end
	
	--only show tooltips in search frame if the option is enabled
	if FBS.tooltipOnlySearch and frame:GetOwner() and frame:GetOwner():GetName() and string.sub(frame:GetOwner():GetName(), 1, 16) ~= "FoobarBagSyncSearchRow" then
		frame:Show()
		return
	end
	
	local permIgnore ={
		[6948] = "Hearthstone",
		[110560] = "Garrison Hearthstone",
		[140192] = "Dalaran Hearthstone",
		[128353] = "Admiral's Compass",
	}
	
	--ignore the hearthstone and blacklisted items
	if shortItemID and tonumber(shortItemID) then
		if permIgnore[tonumber(shortItemID)] then
			frame:Show()
			return
		end
	end
	
	--lag check (check for previously displayed data) if so then display it
	if self.PreviousItemLink and itemLink and itemLink == self.PreviousItemLink then
		if table.getn(self.PreviousItemTotals) > 0 then
			for i = 1, #self.PreviousItemTotals do
				local ename, ecount  = strsplit("@", self.PreviousItemTotals[i])
				if ename and ecount then
					local color = self.options.colors.total
					frame:AddDoubleLine(ename, ecount, color.r, color.g, color.b, color.r, color.g, color.b)
				else
					local color = self.options.colors.second
					frame:AddLine(self.PreviousItemTotals[i], color.r, color.g, color.b)				
				end
			end
		end
		frame:Show()
		return
	end

	--reset our last displayed
	self.PreviousItemTotals = {}
	self.PreviousItemLink = itemLink
	
	--this is so we don't scan the same guild multiple times
	local previousGuilds = {}
	local previousGuildsXRList = {}
	local grandTotal = 0
	local first = true
	
	local xDB = FBS:FilterDB()
	local xDBGuild = FBS_GUILD_DB
	local xDBRealmKey = FBS_REALMKEY
	--make sure to set the DB player and Realm in the FoobarSync.LUA
	local xDBPlayer = FBS_DB[FBS.currentRealm][FBS.currentPlayer]
		
	--loop through our characters
	--k = player, v = stored data for player
	for k, v in pairs(xDB) do

		local allowList = {
			["bag"] = 0,
			["bank"] = 0,
			["reagentbank"] = 0,
			["equip"] = 0,
			["mailbox"] = 0,
			["void"] = 0,
			["auction"] = 0,
			["guild"] = 0,
		}
	
		local yName, yRealm  = strsplit("^", k)
		local playerName = FBS:GetRealmTags(yName, yRealm)
				
		local infoString
		local pFaction = v.faction or FBS.playerFaction --just in case ;) if we dont know the faction yet display it anyways
		
		--check if we should show both factions or not
		if FBS.enableFaction or pFaction == FBS.playerFaction then
		
			--now count the stuff for the user
			--q = bag name, r = stored data for bag name
			for q, r in pairs(v) do
				--only loop through table items we want
				if allowList[q] and type(r) == "table" then
					--bagID = bag name bagID, bagInfo = data of specific bag with bagID
					for bagID, bagInfo in pairs(r) do
						--slotID = slotid for specific bagid, itemValue = data of specific slotid
						if type(bagInfo) == "table" then
							for slotID, itemValue in pairs(bagInfo) do
								local dblink, dbcount = strsplit(",", itemValue)
								if dblink and FBS.enableNoItemExclusion then dblink = ToShortItemID(dblink) end
								if dblink and dblink == itemLink then
									allowList[q] = allowList[q] + (dbcount or 1)
									grandTotal = grandTotal + (dbcount or 1)
								end
							end
						end
					end
				end
			end
		
			if FBS.enableGuild then
				local guildN = v.guild or nil
			
				--check the guild bank if the character is in a guild
				if guildN and xDBGuild[v.realm][guildN] then
					--check to see if this guild has already been done through this run (so we don't do it multiple times)
					--check for XR/B.Net support, you can have multiple guilds with same names on different servers
					local gName = FBS:GetRealmTags(guildN, v.realm, true)
					
					--check to make sure we didn't already add a guild from a connected-realm
					local trueRealmList = xDBRealmKey[0][v.realm] --get the connected realms
					if trueRealmList then
						table.sort(trueRealmList, function(a,b) return (a < b) end) --sort them alphabetically
						trueRealmList = table.concat(trueRealmList, "|") --concat them together
					else
						trueRealmList = v.realm
					end
					trueRealmList = guildN.."-"..trueRealmList --add the guild name in front of concat realm list

					if not previousGuilds[gName] and not previousGuildsXRList[trueRealmList] then
						--we only really need to see this information once per guild
						local tmpCount = 0
						for q, r in pairs(xDBGuild[v.realm][guildN]) do
							local dblink, dbcount = strsplit(",", r)
							if dblink and FBS.enableNoItemExclusion then dblink = ToShortItemID(dblink) end
							if dblink and dblink == itemLink then
								--if we have show guild names then don't show any guild info for the character, otherwise it gets repeated twice
								if not FBS.showGuildNames then
									allowList["guild"] = allowList["guild"] + (dbcount or 1)
								end
								tmpCount = tmpCount + (dbcount or 1)
								grandTotal = grandTotal + (dbcount or 1)
							end
						end
						previousGuilds[gName] = tmpCount
						previousGuildsXRList[trueRealmList] = true
					end
				end
			end
			
			infoString = FBS:CreateItemTotals(allowList)

			if infoString then
				local yName, yRealm  = strsplit("^", k)
				local playerName = FBS:GetRealmTags(yName, yRealm)
				table.insert(self.PreviousItemTotals, FBS:GetClassColor(playerName or "Unknown", v.class).."@"..(infoString or "unknown"))
			end
			
		end
		
	end
	
	--sort it
	table.sort(self.PreviousItemTotals, function(a,b) return (a < b) end)
	
	--show guildnames last
	if FBS.enableGuild and FBS.showGuildNames then
		for k, v in pairsByKeys(previousGuilds) do
			--only print stuff higher then zero
			if v > 0 then
				table.insert(self.PreviousItemTotals, tooltipColor(self.options.colors.guild, k).."@"..tooltipColor(self.options.colors.second, v))
			end
		end
	end
	
	--show grand total if we have something
	--don't show total if there is only one item
	if FBS.showTotal and grandTotal > 0 and getn(self.PreviousItemTotals) > 1 then
		table.insert(self.PreviousItemTotals, tooltipColor(self.options.colors.total, FBSL.TooltipTotal).."@"..tooltipColor(self.options.colors.second, grandTotal))
	end
	
	--add ItemID if it's enabled
	if FBS.enableTooltipItemID and shortItemID and tonumber(shortItemID) then
		table.insert(self.PreviousItemTotals, 1 , tooltipColor(self.options.colors.itemid, FBSL.TooltipItemID).." "..tooltipColor(self.options.colors.second, shortItemID))
	end
	
	--now check for seperater and only add if we have something in the table already
	if table.getn(self.PreviousItemTotals) > 0 and FBS.enableTooltipSeperator then
		table.insert(self.PreviousItemTotals, 1 , " ")
	end
	
	--add it all together now
	if table.getn(self.PreviousItemTotals) > 0 then
		for i = 1, #self.PreviousItemTotals do
			local ename, ecount  = strsplit("@", self.PreviousItemTotals[i])
			if ename and ecount then
				local color = self.options.colors.total
				frame:AddDoubleLine(ename, ecount, color.r, color.g, color.b, color.r, color.g, color.b)
			else
				local color = self.options.colors.second
				frame:AddLine(self.PreviousItemTotals[i], color.r, color.g, color.b)				
			end
		end
	end

	frame:Show()
end

function FBS:HookTooltip(tooltip)

	tooltip.isModified = false
	
	tooltip:HookScript("OnHide", function(self)
		self.isModified = false
		self.lastHyperLink = nil
	end)	
	tooltip:HookScript("OnTooltipCleared", function(self)
		self.isModified = false
	end)

	tooltip:HookScript("OnTooltipSetItem", function(self)
		if self.isModified then return end
		local name, link = self:GetItem()

		if link and ParseItemLink(link) then
			self.isModified = true
			FBS:AddItemToTooltip(self, link)
			return
		end
		--sometimes we have a tooltip but no link because GetItem() returns nil, this is the case for recipes
		--so lets try something else to see if we can get the link.  Doesn't always work!  Thanks for breaking GetItem() Blizzard... you ROCK! :P
		if not self.isModified and self.lastHyperLink then
			local xName, xLink = GetItemInfo(self.lastHyperLink)
			--local title = _G[tooltip:GetName().."TextLeft1"]
			-- if xName and xLink and title and title:GetText() and title:GetText() == xName and ParseItemLink(xLink) then  --only show info if the tooltip text matches the link
				-- self.isModified = true
				-- FBS:AddItemToTooltip(self, xLink)
			-- end
			if xLink and ParseItemLink(xLink) then  --only show info if the tooltip text matches the link
				self.isModified = true
				FBS:AddItemToTooltip(self, xLink)
			end		
		end
	end)

	---------------------------------
	--Special thanks to GetItem() being broken we need to capture the ItemLink before the tooltip shows sometimes
	hooksecurefunc(tooltip, "SetBagItem", function(self, tab, slot)
		local link = GetContainerItemLink(tab, slot)
		if link and ParseItemLink(link) then
			self.lastHyperLink = link
		end
	end)
	hooksecurefunc(tooltip, "SetInventoryItem", function(self, tab, slot)
		local link = GetInventoryItemLink(tab, slot)
		if link and ParseItemLink(link) then
			self.lastHyperLink = link
		end
	end)
	hooksecurefunc(tooltip, "SetGuildBankItem", function(self, tab, slot)
		local link = GetGuildBankItemLink(tab, slot)
		if link and ParseItemLink(link) then
			self.lastHyperLink = link
		end
	end)
	hooksecurefunc(tooltip, "SetHyperlink", function(self, link)
		if self.isModified then return end
		if link and ParseItemLink(link) then
			--I'm pretty sure there is a better way to do this but since Recipes fire OnTooltipSetItem with empty/nil GetItem().  There is really no way to my knowledge to grab the current itemID
			--without storing the ItemLink from the bag parsing or at least grabbing the current SetHyperLink.
			if tooltip:IsVisible() then self.isModified = true end --only do the modifier if the tooltip is showing, because this interferes with ItemRefTooltip if someone clicks it twice in chat
			self.isModified = true
			FBS:AddItemToTooltip(self, link)
		end
	end)
	---------------------------------

	--lets hook other frames so we can show tooltips there as well, sometimes GetItem() doesn't work right and returns nil
	hooksecurefunc(tooltip, "SetVoidItem", function(self, tab, slot)
		if self.isModified then return end
		local link = GetVoidItemInfo(tab, slot)
		if link and ParseItemLink(link) then
			self.isModified = true
			FBS:AddItemToTooltip(self, link)
		end
	end)
	hooksecurefunc(tooltip, "SetVoidDepositItem", function(self, slot)
		if self.isModified then return end
		local link = GetVoidTransferDepositInfo(slot)
		if link and ParseItemLink(link) then
			self.isModified = true
			FBS:AddItemToTooltip(self, link)
		end
	end)
	hooksecurefunc(tooltip, "SetVoidWithdrawalItem", function(self, slot)
		if self.isModified then return end
		local link = GetVoidTransferWithdrawalInfo(slot)
		if link and ParseItemLink(link) then
			self.isModified = true
			FBS:AddItemToTooltip(self, link)
		end
	end)
	hooksecurefunc(tooltip, "SetRecipeReagentItem", function(self, recipeID, reagentIndex)
		if self.isModified then return end
		local link = C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, reagentIndex)
		if link and ParseItemLink(link) then
			self.isModified = true
			FBS:AddItemToTooltip(self, link)
		end
	end)
	hooksecurefunc(tooltip, "SetRecipeResultItem", function(self, recipeID)
		if self.isModified then return end
		local link = C_TradeSkillUI.GetRecipeItemLink(recipeID)
		if link and ParseItemLink(link) then
			self.isModified = true
			FBS:AddItemToTooltip(self, link)
		end
	end)	
	hooksecurefunc(tooltip, "SetQuestLogItem", function(self, itemType, index)
		if self.isModified then return end
		local link = GetQuestLogItemLink(itemType, index)
		if link and ParseItemLink(link) then
			self.isModified = true
			FBS:AddItemToTooltip(self, link)
		end
	end)
	hooksecurefunc(tooltip, "SetQuestItem", function(self, itemType, index)
		if self.isModified then return end
		local link = GetQuestItemLink(itemType, index)
		if link and ParseItemLink(link) then
			self.isModified = true
			FBS:AddItemToTooltip(self, link)
		end
	end)	
	-- hooksecurefunc(tooltip, 'SetItemByID', function(self, link)
		-- if self.isModified or not BagSyncOpt.enableTooltips then return end
		-- if link and ParseItemLink(link) then
			-- self.isModified = true
			-- FBS:AddItemToTooltip(self, link)
		-- end
	-- end)
	
	--------------------------------------------------
	hooksecurefunc(tooltip, "SetCurrencyToken", function(self, index)
		if self.isModified then return end
		self.isModified = true
		local currencyName = GetCurrencyListInfo(index)
		FBS:AddCurrencyTooltip(self, currencyName)
	end)
	hooksecurefunc(tooltip, "SetCurrencyByID", function(self, id)
		if self.isModified then return end
		self.isModified = true
		local currencyName = GetCurrencyInfo(id)
		FBS:AddCurrencyTooltip(self, currencyName)
	end)
	hooksecurefunc(tooltip, "SetBackpackToken", function(self, index)
		if self.isModified then return end
		self.isModified = true
		local currencyName = GetBackpackCurrencyInfo(index)
		FBS:AddCurrencyTooltip(self, currencyName)
	end)

end
