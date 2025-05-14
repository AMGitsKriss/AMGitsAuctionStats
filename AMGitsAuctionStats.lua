-- Initialize the SavedVariables table
AMGitsAuctionStats = AMGitsAuctionStats or {}
AMGPriceCache = AMGPriceCache or {}
AMGRunPriceScan = false
ServerName = nil
AMGRawServerTime = nil
AMGViewDate = nil

local function GetServerName()
    return GetRealmName().."-"..GetCVar("portal")
end

local function GetAuctionHouseFaction()
    if GetSubZoneText() == "Booty Bay" then
        return "Neutral"
    end
    return UnitFactionGroup("player")
end

--
--  SECTION - Iterate over a valid AH bulk scan.
--

local function GetMedianUnitPrice(itemList)
    -- Extract unit prices into a separate table as to not re-order the existing one mid-process.
    local prices = {}
    for _, item in ipairs(itemList) do
        table.insert(prices, item.unitPrice)
    end

    -- Sort the prices table
    table.sort(prices)

    -- Compute median
    local count = #prices
    if count == 0 then
        return nil -- Return nil if list is empty
    elseif count % 2 == 1 then
        return prices[math.ceil(count / 2)] -- Odd count: middle element
    else
        local mid1 = count / 2
        local mid2 = mid1 + 1
        return (prices[mid1] + prices[mid2]) / 2 -- Even count: average of two middle elements
    end
end

local function ProcessCache(viewDate, serverName, ahFaction) 
    for itemId, itemList in pairs(AMGPriceCache[serverName][ahFaction][viewDate]) do
        if AMGitsAuctionStats[serverName] == nil then
            AMGitsAuctionStats[serverName] = {}    
        end   
        if AMGitsAuctionStats[serverName][ahFaction] == nil then
            AMGitsAuctionStats[serverName][ahFaction] = {}    
        end   
        if AMGitsAuctionStats[serverName][ahFaction][viewDate] == nil then
            AMGitsAuctionStats[serverName][ahFaction][viewDate] = {}
        end

        for _, item in ipairs(itemList) do
            local itemStats = AMGitsAuctionStats[serverName][ahFaction][viewDate][itemId]
            if itemStats == nil then 
                itemStats = {
                    itemId = item.itemId,
                    itemName = item.itemName,
                    minUnitPrice = item.unitPrice,
                    maxUnitPrice = item.unitPrice,
                    medianUnitPrice = GetMedianUnitPrice(itemList),
                    auctionCount = #itemList,
                    itemCount = item.stackSize
                } 
            else
                if itemStats.minUnitPrice > item.unitPrice then
                    itemStats.minUnitPrice = item.unitPrice
                elseif itemStats.maxUnitPrice < item.unitPrice then
                    itemStats.maxUnitPrice = item.unitPrice
                end
                if itemStats.itemName == "" and item.itemName ~= "" then
                    itemStats.itemName = item.itemName
                end
                itemStats.itemCount = itemStats.itemCount + item.stackSize
            end

            AMGitsAuctionStats[serverName][ahFaction][viewDate][itemId] = itemStats
        end
    end

    print("[AMG "..viewDate.."] Finished processing cache.")
    print("[AMG "..viewDate.."] Ending scan ".. viewDate)
    AMGPriceCache = {}
end

local function AddItemToCache(itemId, itemName, stackSize, unitPrice, viewDate, serverName, ahFaction)
    if AMGPriceCache == nil then
        AMGPriceCache = {}    
    end
    if AMGPriceCache[serverName] == nil then
        AMGPriceCache[serverName] = {}    
    end
    if AMGPriceCache[serverName][ahFaction] == nil then
        AMGPriceCache[serverName][ahFaction] = {}    
    end
    if AMGPriceCache[serverName][ahFaction][viewDate] == nil then
        AMGPriceCache[serverName][ahFaction][viewDate] = {}
    end
    if AMGPriceCache[serverName][ahFaction][viewDate][itemId] == nil then
        AMGPriceCache[serverName][ahFaction][viewDate][itemId] = {}
    end

    item = {
        itemId = itemId,
        itemName = itemName,
        stackSize = stackSize,
        unitPrice = unitPrice
    }

    table.insert(AMGPriceCache[serverName][ahFaction][viewDate][itemId], item)
end

local function SaveAuctionDataBatch(startIndex, endIndex, numAuctions, viewDate, serverName, ahFaction)
    if endIndex == nil or numAuctions == nil then
        return
    end

    if endIndex > numAuctions then
        endIndex = numAuctions 
    end

    print("[AMG "..viewDate.."] Batch "..tostring(startIndex).." to "..tostring(endIndex)..".")

    for i = startIndex, endIndex do
        local itemName, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, 
            bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", i)

        local unitPrice = math.ceil(buyoutPrice / count)

        if unitPrice > 0 then
            AddItemToCache(itemId, itemName, count, unitPrice, viewDate, serverName, ahFaction)
        end
    end

    if endIndex < numAuctions then -- More pages
        C_Timer.After(0, function() SaveAuctionDataBatch(endIndex+1, endIndex+1000, numAuctions, viewDate, serverName, ahFaction) end)
    else -- done
        print("[AMG "..viewDate.."] Processing cache.")
        ProcessCache(viewDate, serverName, ahFaction)
        --C_Timer.After(0, function() ProcessCache(1, 10, viewDate, serverName, ahFaction) end)
    end    
end

local function StartAuctionScrape()
    if AMGRunPriceScan then
        print("[AMG] AUCTION_ITEM_LIST_UPDATE triggered.")
        print("[AMG] Disabling scan flag to prevent multiple searches triggering.")
        AMGRunPriceScan = false
        local rawServerTime = C_DateAndTime.GetCurrentCalendarTime()
        local viewDate = format("%04d-%02d-%02d %02d:%02d:%02d", rawServerTime.year, rawServerTime.month, rawServerTime.monthDay, rawServerTime.hour, rawServerTime.minute, rawServerTime.second)
        local serverName = GetServerName()
        local ahFaction = GetAuctionHouseFaction()

        local numAuctions = GetNumAuctionItems("list")
        print("[AMG "..viewDate.."] Caching "..tostring(numAuctions).." search results.")
        SaveAuctionDataBatch(1, 1000, numAuctions, viewDate, serverName, ahFaction)
    end
end

--
--  SECTION - Run a bulk search using the /command.
--

local function DoSearch(viewDate, serverName, ahFaction)

    canQuery,canQueryAll = CanSendAuctionQuery()
    if not canQueryAll then
        AMGRunPriceScan = false
        print("[AMG] Scan skipped. Too soon since last scan.")
    end

    local query = ""
    local minLevel = nil
    local maxLevel = nil
    local page = 0
    local usable = false
    local rarity = nil
    local getAll = true
    local exactMatch = false
    local filterData = nil
    QueryAuctionItems(query, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData)    
    print("[AMG] Starting search & scan.")
end

local function RunAuctionScan()
    print("[AMG] Enabling scrape.")
    AMGPriceCache = {}
    AMGRunPriceScan = true
        
    -- Fire off a bullk scan
    --DoSearch(viewDate, serverName, ahFaction)
end

print("[AMG] AMGitsAuctionStats Loaded.")
-- Create a frame to listen for events
local frame = CreateFrame("Frame")
frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")

frame:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_ITEM_LIST_UPDATE" then
        StartAuctionScrape()
    end
end)


SLASH_AMG1 = "/amg"  -- Defines "/myaddon" as a slash command
SlashCmdList.AMG = function(msg)
    if msg == "clear" then
        AMGitsAuctionStats = {}
        print("[AMG] Cleared all data.")
    elseif msg == "scan" then
        RunAuctionScan()
    end
end