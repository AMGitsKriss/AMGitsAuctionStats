-- Initialize the SavedVariables table
AMGitsAuctionStats = AMGitsAuctionStats or {}

local function PrintTable(tbl)
    for key, value in pairs(tbl) do
        print(key .. ": " .. tostring(value))
    end
end

local function GetServerName()
    return GetRealmName().."-"..GetCVar("portal")
end

local function SaveAuctionData()
    local numAuctions = GetNumAuctionItems("list")
    for i = 1, numAuctions do
        local itemName, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, 
            bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", i)
        local rawServerTime = C_DateAndTime.GetCurrentCalendarTime()
        local viewDate = format("%04d-%02d-%02d %02d:00", rawServerTime.year, rawServerTime.month, rawServerTime.monthDay, rawServerTime.hour)
        print(viewDate)
        --print("Auction [" .. i .."]:", itemName, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, 
        --    bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo)

        local unitPrice = buyoutPrice / count

        if AMGitsAuctionStats[GetServerName()] == nil then
            AMGitsAuctionStats[GetServerName()] = {}    
        end   
        if AMGitsAuctionStats[GetServerName()][viewDate] == nil then
            AMGitsAuctionStats[GetServerName()][viewDate] = {}
        end

        local itemStats = AMGitsAuctionStats[GetServerName()][viewDate][itemId]
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
        AMGitsAuctionStats[GetServerName()][viewDate][itemId] = itemStats

        -- PrintTable(AMGitsAuctionStats[auctionId .. "|" .. viewDate])
    end
end


print("AMGitsAuctionStats Loaded.")
-- Create a frame to listen for events
local frame = CreateFrame("Frame")
frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")

frame:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_ITEM_LIST_UPDATE" then
        SaveAuctionData()
    end
end)


SLASH_AMG1 = "/amg"  -- Defines "/myaddon" as a slash command
SlashCmdList.AMG = function(msg)
    if msg == "clear" then
        AMGitsAuctionStats = {}
        print("Cleared all data.")
    end
end