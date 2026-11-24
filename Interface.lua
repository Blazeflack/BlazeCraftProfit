local addonName, ns = ...
local events = CreateFrame("Frame")
local form, panel, queued, merchantOpen, goldwrightHooked

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
    GameTooltip:SetOwner(panel, "ANCHOR_RIGHT")
    GameTooltip:AddLine("BlazeCraftProfit", 1, 0.82, 0)
    GameTooltip:AddLine("All amounts are per craft, regardless of materials in your bags.", 1, 1, 1, true)
    GameTooltip:AddLine("Material prices: known vendor purchase price, otherwise Goldwright.", 1, 1, 1, true)
    GameTooltip:AddLine("Vendor prices are learned from unlimited, money-only offers and saved per character.", 1, 1, 1, true)
    local names = { "Minimum", "Market value" }
    for row = 1, 2 do
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(names[row] .. " material cost", ns.Money(result.costs[row]))
        GameTooltip:AddDoubleLine("Profit selling at minimum", ns.Money(result.profits[row][1], true))
        GameTooltip:AddDoubleLine("Profit selling at market value", ns.Money(result.profits[row][2], true))
    end
    GameTooltip:AddLine(" ")
    if result.market then
        GameTooltip:AddLine(string.format("AH fee: %g%%. Deposits and failed auctions are not included.", result.market.cut * 100), 1, 1, 1, true)
    else
        GameTooltip:AddLine("Goldwright prices are unavailable.", 1, 0.6, 0.3, true)
    end
    if result.variableOutput then
        GameTooltip:AddLine(string.format("Estimated output: %g per craft (midpoint of %g-%g).", result.quantity, result.quantityMin, result.quantityMax), 1, 1, 1, true)
    elseif result.quantity then
        GameTooltip:AddLine(string.format("Output: %g per craft.", result.quantity), 1, 1, 1, true)
    end
    GameTooltip:AddLine("Unknown means a required price, reagent choice or saleable output is unavailable.", 0.7, 0.7, 0.7, true)
    if result.note then GameTooltip:AddLine(result.note, 1, 0.6, 0.3, true) end
    GameTooltip:Show()
end

local function createPanel()
    panel = CreateFrame("Frame", nil, form)
    panel:SetSize(318, 97)
    panel:EnableMouse(true)
    panel:SetScript("OnEnter", showTooltip)
    panel:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel:SetScript("OnHide", function()
        if GameTooltip:IsOwned(panel) then GameTooltip:Hide() end
    end)
    -- Only internal dividers: let the profession artwork show through.
    local function divider(x, y, width, height, alpha)
        local line = panel:CreateTexture(nil, "BORDER")
        line:SetPoint("TOPLEFT", x, y)
        line:SetSize(width, height)
        line:SetColorTexture(0.65, 0.51, 0.29, alpha)
    end
    for _, x in ipairs({ 66, 140, 218 }) do
        divider(x, -30, 1, 58, 0.35)
    end
    divider(0, -48, 306, 1, 0.55)
    divider(0, -70, 306, 1, 0.25)
    label(panel, "BlazeCraftProfit", 0, -10, 306, "GameFontNormal")
    local columns = { 0, 70, 144, 222 }
    local widths = { 62, 66, 70, 84 }
    local headers = { "Materials", "Craft cost", "Profit: min", "Profit: market" }
    for column = 1, 4 do
        label(panel, headers[column], columns[column], -33, widths[column], "GameFontNormal")
    end
    panel.cells = { {}, {} }
    for scenario = 1, 2 do
        local y = -33 - scenario * 21
        label(panel, scenario == 1 and "Minimum" or "Market", 0, y, widths[1])
        for metric = 1, 3 do
            local column = metric + 1
            local cell = label(panel, "", columns[column], y, widths[column])
            cell:SetWordWrap(false)
            panel.cells[scenario][metric] = cell
        end
    end
end

local function positionPanel()
    local anchor = form.Reagents
    for _, key in ipairs({ "OptionalReagents", "FinishingReagents", "Concentrate" }) do
        local candidate = form[key]
        if candidate and candidate:IsShown() and candidate:GetBottom()
            and (not anchor or not anchor:GetBottom() or candidate:GetBottom() < anchor:GetBottom()) then
            anchor = candidate
        end
    end
    panel:ClearAllPoints()
    if anchor and anchor:GetBottom() and form:GetBottom()
        and anchor:GetBottom() - form:GetBottom() >= panel:GetHeight() + 38 then
        panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    else
        -- Long descriptions/reagent lists must not be covered. Keep the same
        -- compact panel attached just below the profession window in that case.
        panel:SetPoint("TOPLEFT", ProfessionsFrame, "BOTTOMLEFT", 320, -5)
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
    for row = 1, 2 do
        panel.cells[row][1]:SetText(ns.Money(result.costs[row]))
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
