-- Initialize the SavedVariables table
AMGitsAuctionStats = AMGitsAuctionStats or {}

local function PrintTable(tbl)
    for key, value in pairs(tbl) do
        print(key .. ": " .. tostring(value))
    end
end

local function SaveAuctionData()
    local numAuctions = GetNumAuctionItems("list")
    for i = 1, numAuctions do
        local name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, 
            bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", i)
        local viewDate = date("%Y-%m-%d-%H")

        --print("Auction [" .. i .."]:", name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, 
        --    bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo)

        table.insert(AMGitsAuctionStats[viewDate],
            {
                itemName = name,
                itemId = itemId,
                quantity = count,
                buyoutTotal = buyoutPrice,
                buyoutPer = buyoutPrice,
                bidTotal = minBid,
                bidPer = minBid,
                owner = owner
            }
        )

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