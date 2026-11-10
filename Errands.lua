----------------------------------------------------------------------
-- Errands.lua — things to buy from vendors, out in the world.
--
-- The user, 2026-11-09, after VoidAH's Professions tab started naming the vendor for each
-- vendor-sold material: "with the list of places i have to run to get stuff from npc, how
-- will i rem without having to come back to ah".
--
--   VoidGPS.Errands:Add(item, qty, why)   have qty MORE than you hold now (bags + bank)
--   VoidGPS.Errands:Remove(item) / :Clear() / :Count() / :Toggle()
--
-- A small box lists them by vendor, nearest vendor first; a vendor line routes there, a
-- right-click drops an item. Lines go away by themselves as the items reach your bags. At
-- a merchant who sells some of them, one button buys what's left.
-- Kept per character in VoidGPSDB.errands[<character>] (no new SavedVariables).
----------------------------------------------------------------------
local _, ns = ...
local G = ns.G
local E = {}
ns.Errands = E
G.Errands = E

local A = { 0, 0.78, 1 }
local FONT = "Fonts\\FRIZQT__.TTF"
local box, merchantBtn
local hidden = false   -- closed with X: back when the list changes

local function charKey()
    local n, r = UnitName("player"), GetRealmName()
    return (n or "?") .. "-" .. (r or "?")
end

local function list()
    VoidGPSDB = VoidGPSDB or {}
    VoidGPSDB.errands = VoidGPSDB.errands or {}
    local k = charKey()
    VoidGPSDB.errands[k] = VoidGPSDB.errands[k] or {}
    return VoidGPSDB.errands[k]
end

local function have(item)
    return (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(item, true)) or 0
end

local function left(e) return math.max(0, (e.goal or 0) - have(e.item)) end

local function money(c)
    c = math.floor(c + 0.5)
    local g, s, cp = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
    if g > 0 then return ("%dg %ds %dc"):format(g, s, cp) end
    if s > 0 then return ("%ds %dc"):format(s, cp) end
    return cp .. "c"
end

-- Drop what's bought. True when something changed.
local function prune()
    local L, changed = list(), false
    for i = #L, 1, -1 do
        if left(L[i]) <= 0 then table.remove(L, i); changed = true end
    end
    return changed
end

----------------------------------------------------------------------
-- API
----------------------------------------------------------------------
-- Adding the same item again sets its goal anew (a plan says how many it still needs).
function E:Add(item, qty, why)
    item, qty = tonumber(item), math.ceil(tonumber(qty) or 0)
    if not item or qty <= 0 then return false end
    local L = list()
    local goal = have(item) + qty
    local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item))
    local entry = G.Goods and G.Goods:Get(item)
    name = name or (entry and entry.name) or ("item " .. item)
    for _, e in ipairs(L) do
        if e.item == item then e.goal, e.why, e.name = goal, why or e.why, name; self:Refresh(true) return true end
    end
    L[#L + 1] = { item = item, goal = goal, why = why, name = name }
    self:Refresh(true)
    return true
end

function E:Remove(item)
    local L = list()
    for i = #L, 1, -1 do if L[i].item == item then table.remove(L, i) end end
    self:Refresh(true)
end

function E:Clear() wipe(list()); self:Refresh(true) end

function E:Count() prune() return #list() end

function E:Toggle()
    if box and box:IsShown() then hidden = true; box:Hide() else hidden = false; self:Refresh(true) end
end

----------------------------------------------------------------------
-- The box
----------------------------------------------------------------------
-- { { v = vendor, items = { e, ... } }, ... } nearest first; items no vendor of yours sells: v = nil
local function groups()
    local byV, out = {}, {}
    for _, e in ipairs(list()) do
        local entry = G.Goods and G.Goods:Get(e.item)   -- vendors sorted nearest first
        local v
        for _, x in ipairs(entry and entry.vendors or {}) do
            if not x.cost then v = x; break end
        end
        v = v or (entry and entry.vendors and entry.vendors[1])
        local k = v and (v.name .. "|" .. tostring(v.map)) or "?"
        local g = byV[k]
        if not g then g = { v = v, items = {} }; byV[k] = g; out[#out + 1] = g end
        g.items[#g.items + 1] = e
    end
    table.sort(out, function(a, b)
        local ya, yb = a.v and a.v.yards, b.v and b.v.yards
        if (ya ~= nil) ~= (yb ~= nil) then return ya ~= nil end
        if ya and yb and ya ~= yb then return ya < yb end
        return (a.v and a.v.name or "~") < (b.v and b.v.name or "~")
    end)
    return out
end

local function zoneName(map)
    local info = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return info and info.name
end

local function buildBox()
    box = CreateFrame("Frame", "VoidGPSErrands", UIParent)
    box:SetSize(260, 60)
    box:SetFrameStrata("MEDIUM")
    box:SetClampedToScreen(true)
    box:SetMovable(true)
    box:EnableMouse(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", box.StartMoving)
    box:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        local p, _, rp, x, y = self:GetPoint()
        VoidGPSDB.errandsPos = { p, rp, x, y }
    end)
    local pos = VoidGPSDB.errandsPos
    if pos then box:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else box:SetPoint("RIGHT", UIParent, "RIGHT", -260, 120) end
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.07, 0.9)
    local edge = box:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(2)
    edge:SetColorTexture(A[1], A[2], A[3], 1)
    box.title = box:CreateFontString(nil, "OVERLAY")
    box.title:SetFont(FONT, 12, "OUTLINE")
    box.title:SetPoint("TOPLEFT", 10, -7)
    box.title:SetTextColor(A[1], A[2], A[3])
    local close = CreateFrame("Button", nil, box)
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", -4, -4)
    local ct = close:CreateFontString(nil, "OVERLAY")
    ct:SetFont(FONT, 12, "OUTLINE")
    ct:SetPoint("CENTER")
    ct:SetText("|cffff5050x|r")
    close:SetScript("OnClick", function() hidden = true; box:Hide() end)
    close:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Hide the list", 1, 1, 1)
        GameTooltip:AddLine("It comes back when the list changes. Shift-click: clear the list.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    close:SetScript("OnLeave", function() GameTooltip:Hide() end)
    close:HookScript("OnClick", function() if IsShiftKeyDown() then E:Clear() end end)
    box.lines = {}
end

local function line(i)
    local b = box.lines[i]
    if b then return b end
    b = CreateFrame("Button", nil, box)
    b:SetHeight(15)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(FONT, 10, "")
    b.text:SetPoint("LEFT")
    b.text:SetPoint("RIGHT")
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(A[1], A[2], A[3], 0.12)
    b:SetScript("OnClick", function(self, button)
        if self.vendor and button == "LeftButton" then
            G.Goods:GoVendor(self.vendor, self.label)
        elseif self.item and button == "RightButton" then
            E:Remove(self.item)
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.vendor then
            GameTooltip:AddLine(self.vendor.name, 1, 0.82, 0)
            local z = zoneName(self.vendor.map)
            if z then GameTooltip:AddLine(z, 1, 1, 1) end
            GameTooltip:AddLine("Click: show the way.", 0.6, 0.6, 0.6)
        elseif self.item then
            GameTooltip:SetItemByID(self.item)
            if self.why then GameTooltip:AddLine("For: " .. self.why, 0, 0.78, 1) end
            GameTooltip:AddLine("Right-click: take it off the list.", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    box.lines[i] = b
    return b
end

function E:Refresh(changed)
    if changed then hidden = false end
    prune()
    local L = list()
    if merchantBtn and MerchantFrame and MerchantFrame:IsShown() then E:Merchant() end
    if #L == 0 then if box then box:Hide() end return end
    if hidden then return end
    if not box then buildBox() end
    box.title:SetText(("Errands (%d)"):format(#L))
    local n, y = 0, -26
    for _, g in ipairs(groups()) do
        n = n + 1
        local h = line(n)
        h.vendor, h.item, h.why = g.v, nil, nil
        h.label = g.items[1].name
        local where = g.v and (g.v.name .. "  |cff888888" .. (zoneName(g.v.map) or "") ..
            (g.v.yards and (" · %d yd"):format(g.v.yards) or "") .. "|r") or "|cff888888no vendor known|r"
        h.text:SetText("|cffffd200" .. where .. "|r")
        h:ClearAllPoints(); h:SetPoint("TOPLEFT", 10, y); h:SetPoint("RIGHT", -8, 0); h:Show()
        y = y - 15
        for _, e in ipairs(g.items) do
            n = n + 1
            local b = line(n)
            b.vendor, b.item, b.why = nil, e.item, e.why
            b.text:SetText(("   %d  %s"):format(left(e), e.name or ("item " .. e.item)))
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 10, y); b:SetPoint("RIGHT", -8, 0); b:Show()
            y = y - 15
        end
        y = y - 3
    end
    for i = n + 1, #box.lines do box.lines[i]:Hide() end
    box:SetHeight(-y + 6)
    box:Show()
end

----------------------------------------------------------------------
-- At a merchant: one button buys what's left of the list that this merchant sells
----------------------------------------------------------------------
local function merchantOffers()
    local want = {}
    for _, e in ipairs(list()) do want[e.item] = e end
    local out, cost = {}, 0
    for i = 1, (GetMerchantNumItems and GetMerchantNumItems() or 0) do
        local id = GetMerchantItemID and GetMerchantItemID(i)
        local e = id and want[id]
        local n = e and left(e) or 0
        if n > 0 then
            local price, per, avail, ext
            local ok, info = pcall(C_MerchantFrame and C_MerchantFrame.GetItemInfo, i)
            if ok and type(info) == "table" then
                price, per, avail, ext = info.price, info.stackCount, info.numAvailable, info.hasExtendedCost
            elseif GetMerchantItemInfo then   -- gone on retail (Sol, 2026-11-09)
                local _, _, p, q, a, _, _, x = GetMerchantItemInfo(i)
                price, per, avail, ext = p, q, a, x
            end
            per = math.max(1, per or 1)
            if not ext and (price or 0) > 0 then   -- gold only: never spend tokens / currencies here
                -- limited stock: read as items (Sol) -- at worst a little short, never too many
                if avail and avail >= 0 then n = math.min(n, avail) end
                local buys = math.min(math.ceil(n / per), 40)   -- 40 = the most single buys per click
                if buys > 0 then
                    out[#out + 1] = { index = i, e = e, items = buys * per, per = per, buys = buys }
                    cost = cost + buys * price
                end
            end
        end
    end
    return out, cost
end

function E:Merchant()
    if not (MerchantFrame and MerchantFrame:IsShown()) then return end
    if not merchantBtn then
        merchantBtn = CreateFrame("Button", nil, MerchantFrame)
        merchantBtn:SetSize(200, 22)
        merchantBtn:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 4, -30)
        local bg = merchantBtn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.07, 0.95)
        local edge = merchantBtn:CreateTexture(nil, "BORDER")
        edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(2)
        edge:SetColorTexture(A[1], A[2], A[3], 1)
        local hl = merchantBtn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(A[1], A[2], A[3], 0.15)
        merchantBtn.text = merchantBtn:CreateFontString(nil, "OVERLAY")
        merchantBtn.text:SetFont(FONT, 11, "OUTLINE")
        merchantBtn.text:SetPoint("CENTER", 2, 0)
        merchantBtn:SetScript("OnClick", function() E:BuyHere() end)
        merchantBtn:SetScript("OnEnter", function(self)
            local offers, cost = merchantOffers()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Buy your errands here", 0, 0.78, 1)
            for _, o in ipairs(offers) do GameTooltip:AddLine(("%d  %s"):format(o.items, o.e.name), 1, 1, 1) end
            GameTooltip:AddLine("Total: " .. money(cost), 1, 0.82, 0)
            GameTooltip:Show()
        end)
        merchantBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local offers, cost = merchantOffers()
    if #offers == 0 then merchantBtn:Hide() return end
    merchantBtn.text:SetText(("Buy my errands here (%s)"):format(money(cost)))
    merchantBtn:SetWidth(merchantBtn.text:GetStringWidth() + 20)
    merchantBtn:Show()
end

local busyUntil = 0
function E:BuyHere()
    -- one click at a time: the bags count the items a moment after the buy, and a second
    -- click before that would buy them all again (Sol, 2026-11-09)
    if GetTime() < busyUntil then return end
    local offers, cost = merchantOffers()
    if #offers == 0 then return end
    if cost > GetMoney() then G:Print("Not enough money for the errands here (" .. money(cost) .. ").") return end
    local bought = {}
    for _, o in ipairs(offers) do
        local maxStack = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(o.index)) or 1
        if maxStack > 1 then
            local n = o.items
            while n > 0 do
                local q = math.min(n, maxStack)
                BuyMerchantItem(o.index, q)
                n = n - q
            end
        else
            for _ = 1, o.buys do BuyMerchantItem(o.index) end
        end
        busyUntil = GetTime() + 2
        bought[#bought + 1] = o.items .. " " .. o.e.name
    end
    G:Print("Bought " .. table.concat(bought, ", ") .. " (" .. money(cost) .. ").")
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "ZONE_CHANGED_NEW_AREA", "MERCHANT_SHOW",
    "MERCHANT_UPDATE", "MERCHANT_CLOSED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e)
    if e == "MERCHANT_CLOSED" then
        if merchantBtn then merchantBtn:Hide() end
        return
    end
    if e == "MERCHANT_SHOW" or e == "MERCHANT_UPDATE" then E:Merchant() return end
    if e == "PLAYER_LOGIN" then hidden = false end
    E:Refresh(false)
end)
-- nearest vendor first: re-sort now and then while walking
C_Timer.NewTicker(5, function()
    if box and box:IsShown() then E:Refresh(false) end
end)
