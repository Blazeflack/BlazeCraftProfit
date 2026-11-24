local _, ns = ...

function ns.Number(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) == "number" and value == value and value > -math.huge and value < math.huge then
        return value
    end
end

function ns.Positive(value)
    value = ns.Number(value)
    return value and value > 0 and value or nil
end

function ns.InitializeDatabase()
    if type(BlazeCraftProfitDB) ~= "table" then BlazeCraftProfitDB = {} end
    if type(BlazeCraftProfitDB.vendorPrices) ~= "table" then BlazeCraftProfitDB.vendorPrices = {} end
    ns.vendorPrices = BlazeCraftProfitDB.vendorPrices
end

-- Goldwright owns market selection, scan merging and cache invalidation.
-- Only read its published Lua namespace; never edit its data.
function ns.Market()
    local gw = Goldwright
    if type(gw) ~= "table" or type(gw.House) ~= "function" or type(gw.ItemData) ~= "function" then
        return nil
    end
    local ok, house = pcall(gw.House)
    if not ok or type(house) ~= "table" then return nil end
    local side = house.side
    if side ~= "A" and side ~= "H" and side ~= "N" then return nil end
    local cut = type(gw.CUT) == "table" and ns.Number(gw.CUT[side]) or nil
    if not cut or cut < 0 or cut >= 1 then cut = side == "N" and 0.15 or 0.05 end
    return { side = side, cut = cut, provider = gw }
end

function ns.AuctionPrices(itemID, market)
    if not ns.Positive(itemID) or not market then return nil, nil end
    local ok, data = pcall(market.provider.ItemData, itemID)
    if not ok or type(data) ~= "table" or type(data[market.side]) ~= "table" then return nil, nil end
    local entry = data[market.side]
    return ns.Positive(entry.min), ns.Positive(entry.mv)
end

function ns.MaterialPrices(itemID, market)
    local vendor = itemID and ns.vendorPrices and ns.Positive(ns.vendorPrices[itemID])
    if vendor then return vendor, vendor end
    return ns.AuctionPrices(itemID, market)
end

function ns.RememberVendorItem(itemID, info)
    if not ns.Positive(itemID) or type(info) ~= "table" then return end
    local price, count = ns.Positive(info.price), ns.Positive(info.stackCount)
    -- A money-only, unlimited offer can be used for future crafting estimates.
    -- Do not treat token costs, limited stock or free offers as ordinary prices.
    if ns.Number(info.numAvailable) ~= -1 or info.hasExtendedCost or not info.isPurchasable then return end
    if price and count then ns.vendorPrices[itemID] = price / count end
end

function ns.ReadMerchant()
    if not ns.vendorPrices or not C_MerchantFrame or not C_MerchantFrame.GetItemInfo
        or not GetMerchantNumItems or not GetMerchantItemID then return end
    local count = ns.Number(GetMerchantNumItems())
    if not count then return end
    for index = 1, count do
        -- Read the ID and price synchronously: no callbacks can outlive this vendor visit.
        ns.RememberVendorItem(GetMerchantItemID(index), C_MerchantFrame.GetItemInfo(index))
    end
end

function ns.Money(value, profit)
    if value == nil then return "|cff999999Unknown|r" end
    local rounded = math.floor(math.abs(value) + 0.5)
    local gold, silver, copper = math.floor(rounded / 10000), math.floor(rounded / 100) % 100, rounded % 100
    local result = {}
    if gold > 0 then result[#result + 1] = gold .. "g" end
    if silver > 0 then result[#result + 1] = silver .. "s" end
    if copper > 0 or #result == 0 then result[#result + 1] = copper .. "c" end
    local sign = value < 0 and "-" or (profit and value > 0 and "+" or "")
    local color = profit and (value < 0 and "|cffff6060" or "|cff55dd77") or "|cffffffff"
    local text = table.concat(result, " ")
    if not profit then
        local currencyColors = { g = "|cffffd700", s = "|cffc7c7cf", c = "|cffd99559" }
        text = text:gsub("[gsc]", function(unit)
            return currencyColors[unit] .. unit .. "|r|cffffffff"
        end)
    end
    return color .. sign .. text .. "|r"
end
