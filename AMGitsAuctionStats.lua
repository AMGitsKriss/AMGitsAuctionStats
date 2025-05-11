-- Initialize the SavedVariables table
AMGitsAuctionStats = AMGitsAuctionStats or {}
ServerName = nil

local function PrintTable(tbl)
    for key, value in pairs(tbl) do
        print(key .. ": " .. tostring(value))
    end
end

local function GetServerName()
    return GetRealmName().."-"..GetCVar("portal")
end

local function GetAuctionHouseFaction()
    if GetSubZoneText() == "Booty Bay" then
        return "Neutral"
    end
    return UnitFactionGroup("player")
end

local function BulkScanAuctionHouse()
    print("Starting bulk auction.")
    
    local query = {
        searchString = "",
        sorts = {
            {sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false},
            {sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false},
        }
    }
    C_AuctionHouse.SendBrowseQuery(query)
end

local function SaveAuctionDataBatch(startIndex, endIndex)
    local numAuctions = GetNumAuctionItems("list")
    local serverName = GetServerName()
    local ahFaction = GetAuctionHouseFaction()

    local rawServerTime = C_DateAndTime.GetCurrentCalendarTime()
    local viewDate = format("%04d-%02d-%02d %02d:00", rawServerTime.year, rawServerTime.month, rawServerTime.monthDay, rawServerTime.hour)

    if endIndex > numAuctions then
        endIndex = numAuctions 
    end

    for i = startIndex, endIndex do
        local itemName, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, 
            bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", i)

        local unitPrice = buyoutPrice / count

        if AMGitsAuctionStats[serverName] == nil then
            AMGitsAuctionStats[serverName] = {}    
        end   
        if AMGitsAuctionStats[serverName][ahFaction] == nil then
            AMGitsAuctionStats[serverName][ahFaction] = {}    
        end   
        if AMGitsAuctionStats[serverName][ahFaction][viewDate] == nil then
            AMGitsAuctionStats[serverName][ahFaction][viewDate] = {}
        end

        local itemStats = AMGitsAuctionStats[serverName][ahFaction][viewDate][itemId]
        if itemStats == nil then 
            itemStats = {
                itemId = itemId,
                itemName = itemName,
                minUnitPrice = unitPrice,
                maxUnitPrice = unitPrice
            } 
        else
            if unitPrice > 0 and itemStats.minUnitPrice > unitPrice then
                itemStats.minUnitPrice = unitPrice
            elseif unitPrice > 0 and itemStats.maxUnitPrice < unitPrice then
                itemStats.maxUnitPrice = unitPrice
            end
        end
        AMGitsAuctionStats[serverName][ahFaction][viewDate][itemId] = itemStats
    end

    print("Pricessed items ".. startIndex .. " through to ".. endIndex .. " auctions")

    if endIndex < numAuctions then
        C_Timer.After(0, function() SaveAuctionDataBatch(endIndex+1, endIndex+1000) end)
    end
    
end

print("AMGitsAuctionStats Loaded.")
-- Create a frame to listen for events
local frame = CreateFrame("Frame")
frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")

frame:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_ITEM_LIST_UPDATE" then
        SaveAuctionDataBatch(1, 1000)
    end
end)


SLASH_AMG1 = "/amg"  -- Defines "/myaddon" as a slash command
SlashCmdList.AMG = function(msg)
    if msg == "clear" then
        AMGitsAuctionStats = {}
        print("Cleared all data.")
    elseif msg == "faction" then
        print(GetAuctionHouseFaction())
    elseif msg == "scan" then
        print(BulkScanAuctionHouse())
    end
end