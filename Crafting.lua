local _, ns = ...

-- Selections are indexed by Blizzard's dataSlotIndex, not their visual position.
-- For ordinary Forever recipes each required slot has one fixed reagent.
function ns.Materials(schematic, allocations)
    local materials, complete = {}, true
    local bySlot = {}
    for _, allocation in ipairs(allocations or {}) do
        local quantity = ns.Positive(allocation.quantity)
        if quantity then
            local key = allocation.dataSlotIndex
            if key then
                bySlot[key] = bySlot[key] or {}
                bySlot[key][#bySlot[key] + 1] = allocation
            end
        end
    end
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        local selected = bySlot[slot.dataSlotIndex] or {}
        local used = 0
        for _, allocation in ipairs(selected) do
            local itemID = allocation.reagent and ns.Positive(allocation.reagent.itemID)
            if itemID then
                materials[#materials + 1] = { itemID = itemID, quantity = allocation.quantity }
            else
                complete = false
            end
            used = used + allocation.quantity
        end
        if slot.required or slot.reagentType == Enum.CraftingReagentType.Basic then
            local required = ns.Positive(slot.quantityRequired)
            if not required then
                complete = false
            elseif used < required then
                local choices = slot.reagents or {}
                -- Do not silently assume a quality or currency conversion.
                local itemID = #choices == 1 and ns.Positive(choices[1].itemID)
                if itemID then
                    materials[#materials + 1] = { itemID = itemID, quantity = required - used }
                else
                    complete = false
                end
            end
        end
    end
    if type(schematic.reagentSlotSchematics) ~= "table" then complete = false end
    return materials, complete
end

function ns.Calculate(schematic, allocations, outputItemID, market, saleable)
    local materials, complete = ns.Materials(schematic, allocations)
    local result = { costs = {}, profits = { {}, {} }, market = market, materials = materials, materialsComplete = complete }
    local sums, known = { 0, 0 }, { complete, complete }
    for _, material in ipairs(materials) do
        local minimum, value = ns.MaterialPrices(material.itemID, market)
        local prices = { minimum, value }
        material.costs = {}
        for column = 1, 2 do
            if prices[column] then
                material.costs[column] = prices[column] * material.quantity
                sums[column] = sums[column] + material.costs[column]
            else
                known[column] = false
            end
        end
    end
    for column = 1, 2 do
        if known[column] then result.costs[column] = sums[column] end
    end
    local low, high = ns.Positive(schematic.quantityMin), ns.Positive(schematic.quantityMax)
    if low and high and high >= low then
        result.quantity = (low + high) / 2
        result.variableOutput = low ~= high
        result.quantityMin, result.quantityMax = low, high
    end
    local minimum, value = ns.AuctionPrices(outputItemID, market)
    result.sales = { minimum, value }
    if market and result.quantity and saleable then
        for costIndex = 1, 2 do
            for saleIndex = 1, 2 do
                local cost, sale = result.costs[costIndex], result.sales[saleIndex]
                if cost and sale then
                    result.profits[costIndex][saleIndex] = sale * result.quantity * (1 - market.cut) - cost
                end
            end
        end
    end
    return result
end

function ns.ReadRecipe(form)
    local info = form:GetRecipeInfo()
    if not info then return nil end
    local schematic = form.recipeSchematic
    if not schematic or schematic.recipeID ~= info.recipeID then return nil end
    local transaction = form:GetTransaction()
    local allocations = transaction and transaction:CreateCraftingReagentInfoTbl() or {}
    local output = C_TradeSkillUI.GetRecipeOutputItemData(info.recipeID, allocations,
        transaction and transaction:GetAllocationItemGUID() or nil)
    local itemID = output and ns.Positive(output.itemID) or ns.Positive(schematic.outputItemID)
    local saleable = false
    local itemBindType
    if itemID then
        local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = C_Item.GetItemInfo(itemID)
        itemBindType = ns.Number(bindType)
        -- Uncached or bound outputs must not acquire a speculative AH profit.
        saleable = itemBindType == 0 or itemBindType == 2 or itemBindType == 3
    end
    -- A direct enchant modifies a target item: its AH value is not recipe revenue.
    -- Pricing scrolls would also require a verified scroll mapping and vellum cost.
    if info.isEnchantingRecipe then saleable = false end
    local result = ns.Calculate(schematic, allocations, itemID, ns.Market(), saleable)
    -- ItemBind.OnAcquire = 1 in Forever's ItemConstantsDocumentation.
    result.isBindOnPickup = itemBindType == 1 and not info.isEnchantingRecipe
    if schematic.isRecraft or info.isSalvageRecipe or info.isGatheringRecipe then
        result.costs, result.profits = {}, { {}, {} }
        result.note = "This recipe type is not priced."
    elseif result.isBindOnPickup then
        result.note = "The crafted item is Bind on Pickup and cannot be auctioned."
    elseif not itemID or not saleable then
        result.note = "No known auctionable output."
    end
    return result
end
