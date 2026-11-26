local addonName, ns = ...
local events = CreateFrame("Frame")
local form, panel, queued, merchantOpen, goldwrightHooked
local reagentScroll, reagentContent, scrollBar, scrollRecipeID
local reagentContainers = { "Reagents", "OptionalReagents", "FinishingReagents", "Concentrate" }

local function scrollMaterials(_, delta)
    scrollBar:SetValue(math.max(0, math.min(reagentScroll:GetVerticalScrollRange(),
        reagentScroll:GetVerticalScroll() - delta * 40)))
end

local function createScrollArea()
    reagentScroll = CreateFrame("ScrollFrame", nil, form)
    reagentScroll:EnableMouseWheel(true)
    reagentScroll:SetScript("OnMouseWheel", scrollMaterials)
    reagentContent = CreateFrame("Frame", nil, reagentScroll)
    reagentContent:SetSize(1, 1)
    reagentScroll:SetScrollChild(reagentContent)

    -- Keep the scrollbar in the narrow margin beside the two reagent columns.
    scrollBar = CreateFrame("Slider", nil, form)
    scrollBar:SetWidth(5)
    scrollBar:SetPoint("TOPRIGHT", reagentScroll, "TOPRIGHT", 5, -2)
    scrollBar:SetPoint("BOTTOMRIGHT", reagentScroll, "BOTTOMRIGHT", 5, 2)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValue(0)
    scrollBar:Hide()
    local thumb = scrollBar:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(5, 28)
    thumb:SetColorTexture(0.65, 0.51, 0.29, 0.8)
    scrollBar:SetThumbTexture(thumb)
    scrollBar:SetScript("OnValueChanged", function(_, value)
        reagentScroll:SetVerticalScroll(value)
    end)
    scrollBar:EnableMouseWheel(true)
    scrollBar:SetScript("OnMouseWheel", scrollMaterials)
    reagentScroll:SetScript("OnScrollRangeChanged", function(_, _, range)
        range = math.max(0, range)
        local value = math.min(scrollBar:GetValue(), range)
        scrollBar:SetMinMaxValues(0, range)
        scrollBar:SetValue(value)
        scrollBar:SetShown(range > 0)
    end)
end

local function label(parent, text, x, y, width, template)
    local font = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    local face, _, flags = font:GetFont()
    font:SetFont(face, 11, flags)
    font:SetPoint("TOPLEFT", x, y)
    font:SetWidth(width)
    font:SetJustifyH("LEFT")
    font:SetText(text)
    return font
end

local function showTooltip()
    local result = panel.result
    if not result then return end
    local costsOnly = panel.costOnly or result.isBindOnPickup
    GameTooltip:SetOwner(panel, "ANCHOR_RIGHT")
    GameTooltip:AddLine("BlazeCraftProfit", 1, 0.82, 0)
    GameTooltip:AddLine("All amounts are per craft, regardless of materials in your bags.", 1, 1, 1, true)
    GameTooltip:AddLine("Material prices: known vendor purchase price, otherwise Goldwright.", 1, 1, 1, true)
    GameTooltip:AddLine("Vendor prices are learned from unlimited, money-only offers and saved per character.", 1, 1, 1, true)
    local names = { "Minimum", "Market value" }
    for row = 1, 2 do
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(names[row] .. " material cost", ns.Money(result.costs[row]))
        if not costsOnly then
            GameTooltip:AddDoubleLine("Profit selling at minimum", ns.Money(result.profits[row][1], true))
            GameTooltip:AddDoubleLine("Profit selling at market value", ns.Money(result.profits[row][2], true))
        end
    end
    GameTooltip:AddLine(" ")
    if result.market and not costsOnly then
        GameTooltip:AddLine(string.format("AH fee: %g%%. Deposits and failed auctions are not included.", result.market.cut * 100), 1, 1, 1, true)
    elseif not result.market then
        GameTooltip:AddLine("Goldwright prices are unavailable.", 1, 0.6, 0.3, true)
    end
    if result.isBindOnPickup then
        GameTooltip:AddLine(result.note, 1, 0.6, 0.3, true)
    elseif panel.costOnly then
        GameTooltip:AddLine("Craft cost only: this enchant modifies an item.", 1, 1, 1, true)
    elseif result.variableOutput then
        GameTooltip:AddLine(string.format("Estimated output: %g per craft (midpoint of %g-%g).", result.quantity, result.quantityMin, result.quantityMax), 1, 1, 1, true)
    elseif result.quantity then
        GameTooltip:AddLine(string.format("Output: %g per craft.", result.quantity), 1, 1, 1, true)
    end
    if costsOnly then
        GameTooltip:AddLine("Unknown means a required material price or reagent choice is unavailable.", 0.7, 0.7, 0.7, true)
    else
        GameTooltip:AddLine("Unknown means a required price, reagent choice or saleable output is unavailable.", 0.7, 0.7, 0.7, true)
        if result.note then GameTooltip:AddLine(result.note, 1, 0.6, 0.3, true) end
    end
    GameTooltip:Show()
end

local function createPanel()
    createScrollArea()
    panel = CreateFrame("Frame", nil, reagentContent)
    panel:SetSize(318, 97)
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", scrollMaterials)
    panel:SetScript("OnEnter", showTooltip)
    panel:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel:SetScript("OnHide", function()
        if GameTooltip:IsOwned(panel) then GameTooltip:Hide() end
    end)
    panel.fullTable = CreateFrame("Frame", nil, panel)
    panel.fullTable:SetAllPoints()
    local tableFrame = panel.fullTable
    -- Only internal dividers: let the profession artwork show through.
    local function divider(x, y, width, height, alpha)
        local line = tableFrame:CreateTexture(nil, "BORDER")
        line:SetPoint("TOPLEFT", x, y)
        line:SetSize(width, height)
        line:SetColorTexture(0.65, 0.51, 0.29, alpha)
        return line
    end
    divider(66, -30, 1, 58, 0.35)
    panel.profitRegions = { divider(140, -30, 1, 58, 0.35), divider(218, -30, 1, 58, 0.35) }
    panel.rowDividers = { divider(0, -48, 306, 1, 0.55), divider(0, -70, 306, 1, 0.25) }
    panel.title = label(tableFrame, "BlazeCraftProfit", 0, -10, 306, "GameFontNormal")
    local columns = { 0, 70, 144, 222 }
    local widths = { 62, 66, 70, 84 }
    local headers = { "Materials", "Craft cost", "Profit: min", "Profit: market" }
    for column = 1, 4 do
        local header = label(tableFrame, headers[column], columns[column], -33, widths[column], "GameFontNormal")
        if column > 2 then panel.profitRegions[#panel.profitRegions + 1] = header end
    end
    panel.cells = { {}, {} }
    for scenario = 1, 2 do
        local y = -33 - scenario * 21
        label(tableFrame, scenario == 1 and "Minimum" or "Market", 0, y, widths[1])
        for metric = 1, 3 do
            local column = metric + 1
            local cell = label(tableFrame, "", columns[column], y, widths[column])
            cell:SetWordWrap(false)
            panel.cells[scenario][metric] = cell
            if metric > 1 then panel.profitRegions[#panel.profitRegions + 1] = cell end
        end
    end
    panel.costView = CreateFrame("Frame", nil, panel)
    panel.costView:SetAllPoints()
    local costTitle = label(panel.costView, "BlazeCraftProfit - Cost", 0, -2, 160, "GameFontNormal")
    costTitle:SetHeight(20) -- Match the Optional Target label's text box.
    panel.costCells = {}
    for row = 1, 2 do
        local y = -7 - row * 17
        label(panel.costView, row == 1 and "Minimum" or "Market", 0, y, 58)
        local cell = label(panel.costView, "", 62, y, 98)
        cell:SetWordWrap(false)
        panel.costCells[row] = cell
    end
end

local function positionPanel()
    -- Init reanchors Reagents below the description. Move that anchor onto the
    -- viewport; only the materials and everything below them should scroll.
    local point, relative, relativePoint, x, y = form.Reagents:GetPoint(1)
    if point and relative ~= reagentContent then
        reagentScroll:ClearAllPoints()
        reagentScroll:SetPoint(point, relative, relativePoint, x, y)
        reagentScroll:SetPoint("BOTTOMRIGHT", form, "BOTTOMRIGHT", -6, 38)
    end
    reagentContent:SetWidth(reagentScroll:GetWidth())
    for _, key in ipairs(reagentContainers) do
        local container = form[key]
        if container then container:SetParent(reagentContent) end
    end
    form.Reagents:ClearAllPoints()
    form.Reagents:SetPoint("TOPLEFT", reagentContent, "TOPLEFT")

    local anchor = form.Reagents
    for _, key in ipairs({ "OptionalReagents", "FinishingReagents", "Concentrate", "enchantSlot" }) do
        local candidate = form[key]
        if candidate and candidate:IsVisible() and candidate:GetBottom()
            and (not anchor or not anchor:GetBottom() or candidate:GetBottom() < anchor:GetBottom()) then
            anchor = candidate
        end
    end
    -- Choose the view per recipe, not per profession: Enchanting also makes
    -- saleable items, which still need the complete profit table.
    local enchantSlot = form.enchantSlot
    panel.costOnly = enchantSlot and enchantSlot:IsVisible() or false
    panel.fullTable:SetShown(not panel.costOnly)
    panel.costView:SetShown(panel.costOnly)
    if panel.costOnly then panel:SetSize(160, 60) else panel:SetSize(318, 97) end

    local top, bottom = reagentContent:GetTop(), anchor:GetBottom()
    local slotRight = panel.costOnly and enchantSlot:GetRight()
    -- The slot frame has unused space after its item-name label. Place the
    -- costs beside that label rather than after the full slot frame.
    local nameRight = panel.costOnly and enchantSlot.Name and enchantSlot.Name:GetRight() or slotRight
    local besideSlot = slotRight and nameRight and reagentContent:GetRight()
        and reagentContent:GetRight() - nameRight >= panel:GetWidth() + 8
    panel:ClearAllPoints()
    if besideSlot then
        local targetLabel = form.OptionalReagents and form.OptionalReagents.Label
        local panelTop = targetLabel and targetLabel:GetTop()
        panelTop = panelTop and panelTop + 2 or enchantSlot:GetTop()
        local offsetY = panelTop and enchantSlot:GetTop() and panelTop - enchantSlot:GetTop() or 0
        panel:SetPoint("TOPLEFT", enchantSlot, "TOPRIGHT", nameRight - slotRight + 8, offsetY)
        if bottom and panelTop then
            bottom = math.min(bottom, panelTop - panel:GetHeight())
        end
    else
        panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
        if bottom then bottom = bottom - 10 - panel:GetHeight() end
    end
    if top and bottom then
        local height = top - bottom + 8
        reagentContent:SetHeight(math.max(reagentScroll:GetHeight(), math.ceil(height)))
        reagentScroll:UpdateScrollChildRect()
    end
    local recipeInfo = form:GetRecipeInfo()
    local recipeID = recipeInfo and recipeInfo.recipeID
    if recipeID ~= scrollRecipeID then
        scrollRecipeID = recipeID
        scrollBar:SetValue(0)
    end
end

local function refresh()
    if not form or not form:IsShown() or InCombatLockdown() then return end
    local result = ns.ReadRecipe(form)
    if not result then
        if panel then panel:Hide() end
        return
    end
    if not panel then createPanel() end
    panel.result = result
    panel.title:SetText(result.isBindOnPickup and "BlazeCraftProfit - Cannot be auctioned (BoP)" or "BlazeCraftProfit")
    for _, region in ipairs(panel.profitRegions) do region:SetShown(not result.isBindOnPickup) end
    for _, line in ipairs(panel.rowDividers) do line:SetWidth(result.isBindOnPickup and 136 or 306) end
    for row = 1, 2 do
        panel.cells[row][1]:SetText(ns.Money(result.costs[row]))
        panel.costCells[row]:SetText(ns.Money(result.costs[row]))
        panel.cells[row][2]:SetText(ns.Money(result.profits[row][1], true))
        panel.cells[row][3]:SetText(ns.Money(result.profits[row][2], true))
    end
    positionPanel()
    panel:Show()
    if GameTooltip:IsOwned(panel) then showTooltip() end
end

local function schedule()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        refresh()
    end)
end

local function attach()
    if InCombatLockdown() then return end
    if not goldwrightHooked and type(Goldwright) == "table" and type(Goldwright.ResetCache) == "function" then
        hooksecurefunc(Goldwright, "ResetCache", schedule)
        goldwrightHooked = true
    end
    local candidate = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
    if not form and candidate and type(candidate.GetRecipeInfo) == "function"
        and type(candidate.GetTransaction) == "function" then
        form = candidate
        hooksecurefunc(form, "Init", schedule)
        hooksecurefunc(form, "UpdateOutputItem", schedule)
        form:HookScript("OnShow", schedule)
        form:HookScript("OnSizeChanged", schedule)
        form:HookScript("OnHide", function() if panel then panel:Hide() end end)
        for _, key in ipairs(reagentContainers) do
            local container = form[key]
            if container then container:HookScript("OnSizeChanged", schedule) end
        end
    end
    schedule()
end

events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == addonName then ns.InitializeDatabase() end
        if name == addonName or name == "Goldwright" or name == "Blizzard_Professions" then attach() end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" or event == "TRADE_SKILL_SHOW" then
        attach()
    elseif event == "MERCHANT_SHOW" then
        merchantOpen = true
        ns.ReadMerchant()
        schedule()
    elseif event == "MERCHANT_UPDATE" then
        if merchantOpen then ns.ReadMerchant(); schedule() end
    elseif event == "MERCHANT_CLOSED" then
        merchantOpen = false
    elseif event == "TRADE_SKILL_CLOSE" then
        if panel then panel:Hide() end
    else
        schedule()
    end
end)

for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE",
    "TRADE_SKILL_DETAILS_UPDATE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
    "CRAFTING_DETAILS_UPDATE", "GET_ITEM_INFO_RECEIVED", "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED",
}) do
    events:RegisterEvent(event)
end
