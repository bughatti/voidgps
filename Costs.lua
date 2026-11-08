----------------------------------------------------------------------
-- Costs.lua — what a vendor offer really costs: gold, or Merchant's Favor and
-- reputation (WoW Forever's Azeroth Commerce Authority), or another currency.
--
-- The vendor data (Places.lua) only knows gold prices: NorgannonDB has no costs
-- and Blizzard's item API only lists the skill. So:
--   * the 14 ACA supply-post vendors' recipes are taken to cost Merchant's Favor
--     (the guides and the in-game vendor agree, 2026-11-07), and
--   * opening ANY vendor reads each item's real cost and the reputation it needs
--     (VoidGPSDB.costs, account-wide), which then wins over that guess.
--
--   VoidGPS.Costs:Offer(vendor, map, item, kind) -> nil (plain gold) or
--       { favor = n or true (amount not seen yet), rep = "Friendly", other = "5 Honor", seen = bool,
--         pay = true when it's bought with something other than gold }
--   VoidGPS.Costs:Standing() -> your Merchant's Favor, your ACA standing label, its rank (1-8)
--   VoidGPS.Costs:RepRank(label) -> 1 (Hated) .. 8 (Exalted)
----------------------------------------------------------------------
local _, ns = ...
local G = ns.G
local C = {}
ns.Costs = C
G.Costs = C

C.FAVOR = "Merchant's Favor"
C.FACTION = "Azeroth Commerce Authority"

-- NorgannonDB npc IDs 248196-248202 (Horde, the depot west of the Crossroads) and
-- 256729-256735 (Alliance, Three Corners, Redridge). Places.lua rows carry no npc ID,
-- so they're matched by name and map.
C.ACA = {
    ["Aza'bek"] = 1413, ["Apothecary Durelle"] = 1413, ["Beneris"] = 1413, ["Fizzlefuse"] = 1413,
    ["Gor'mak"] = 1413, ["Jim'bek"] = 1413, ["Pawani"] = 1413,
    ["Kalsey Sanden"] = 1433, ["Nina Surefire"] = 1433, ["Alynsia"] = 1433, ["Fritz Fizzle"] = 1433,
    ["Stondry Darkhammer"] = 1433, ["Mivin Shadowweave"] = 1433, ["Daniel Stitchsong"] = 1433,
}

local function secret(v) return issecretvalue and issecretvalue(v) end
local function safe(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local RANK
function C:RepRank(label)
    if not RANK then
        RANK = {}
        for i = 1, 8 do
            local l = _G["FACTION_STANDING_LABEL" .. i]
            if l then RANK[l] = i end
        end
    end
    return label and RANK[label]
end

function C:Offer(vendor, map, item, kind)
    local db = VoidGPSDB and VoidGPSDB.costs
    local rec = db and db[vendor .. "|" .. item]
    if rec then
        if not (rec.favor or rec.other or rec.rep) then return nil end
        -- pay = bought with something other than gold; a reputation alone still takes gold
        -- (Astra, 2026-11-07: rep-only offers fell out of the gold lists)
        return { favor = rec.favor, rep = rec.rep, other = rec.other, seen = true,
                 pay = (rec.favor or rec.other) and true or false }
    end
    if kind == "r" and C.ACA[vendor] == map then return { favor = true, seen = false, pay = true } end
    return nil
end

-- "Requires Azeroth Commerce Authority - Friendly" in the vendor's item tooltip
local function repNeeded(i)
    local data = C_TooltipInfo and safe(C_TooltipInfo.GetMerchantItem, i)
    for _, line in ipairs(data and data.lines or {}) do
        local t = line.leftText
        if type(t) == "string" and not secret(t) then
            local fac, label = t:match("^Requires (.+) %- (.+)$")
            if fac and C:RepRank(label) then return label, fac end
        end
    end
end

local function scan()
    local n = safe(GetMerchantNumItems) or 0
    local vendor = UnitName("npc")
    if n == 0 or not vendor or secret(vendor) then return end
    VoidGPSDB.costs = VoidGPSDB.costs or {}
    local db, changed = VoidGPSDB.costs, false
    for i = 1, n do
        local item = safe(GetMerchantItemID, i)
        local info = C_MerchantFrame and safe(C_MerchantFrame.GetItemInfo, i)
        if item and info and not secret(item) then
            local rec = {}
            if info.hasExtendedCost then
                for j = 1, (safe(GetMerchantItemCostInfo, i) or 0) do
                    local _, value, link, cname = safe(GetMerchantItemCostItem, i, j)
                    if value and value > 0 then
                        local cid = type(link) == "string" and tonumber(link:match("currency:(%d+)"))
                        if not cname and cid and C_CurrencyInfo then
                            local ci = safe(C_CurrencyInfo.GetCurrencyInfo, cid)
                            cname = ci and ci.name
                        end
                        cname = cname or (type(link) == "string" and link:match("%[(.-)%]")) or "?"
                        if cname == C.FAVOR then
                            rec.favor = value
                            if cid then VoidGPSDB.favorID = cid end
                        else
                            rec.other = (rec.other and (rec.other .. ", ") or "") .. value .. " " .. cname
                        end
                    end
                end
            end
            local label, fac = repNeeded(i)
            if label then rec.rep = label; rec.repFaction = fac end
            local key = vendor .. "|" .. item
            local old = db[key]
            if not old or old.favor ~= rec.favor or old.other ~= rec.other or old.rep ~= rec.rep then changed = true end
            db[key] = rec
        end
    end
    if changed and ns.GoodsDirty then ns.GoodsDirty() end
end

-- your Merchant's Favor and ACA standing
function C:Standing()
    local have
    local id = VoidGPSDB and VoidGPSDB.favorID
    if id and C_CurrencyInfo then
        local ci = safe(C_CurrencyInfo.GetCurrencyInfo, id)
        have = ci and ci.quantity
    end
    if not have and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
        for i = 1, (safe(C_CurrencyInfo.GetCurrencyListSize) or 0) do
            local ci = safe(C_CurrencyInfo.GetCurrencyListInfo, i)
            if ci and ci.name == C.FAVOR then have = ci.quantity; break end
        end
    end
    local d
    local fid = VoidGPSDB and VoidGPSDB.acaFaction
    if fid and C_Reputation and C_Reputation.GetFactionDataByID then d = safe(C_Reputation.GetFactionDataByID, fid) end
    if not d and C_Reputation and C_Reputation.GetNumFactions then
        for i = 1, (safe(C_Reputation.GetNumFactions) or 0) do
            local f = safe(C_Reputation.GetFactionDataByIndex, i)
            if f and f.name == C.FACTION then
                d = f
                if VoidGPSDB then VoidGPSDB.acaFaction = f.factionID end
                break
            end
        end
    end
    local label = d and d.reaction and _G["FACTION_STANDING_LABEL" .. d.reaction]
    return have, label, d and d.reaction
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("MERCHANT_UPDATE")
local pending
ev:SetScript("OnEvent", function()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()   -- the list fills in over a few frames
        pending = nil
        local ok, err = pcall(scan)
        if not ok then geterrorhandler()(err) end
    end)
end)
