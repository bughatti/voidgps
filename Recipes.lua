----------------------------------------------------------------------
-- Recipes.lua — what vendors sell and where (Places.lua: NorgannonDB's vendor
-- lists, item data from Blizzard's Forever API; holiday vendors left out).
--
--   VoidGPS.Goods:All(kind)      -> { entry, ... } vendors your faction can use, nearest first;
--                                   kind nil = everything, or one of:
--                                   r recipe, p pet, g gear, t trade goods / reagent, c consumable, o other
--   VoidGPS.Goods:Get(item)      -> that entry, or nil
--   VoidGPS.Goods:Go(item)       -> route to the nearest vendor of it: ok, vendor, map, yards
--   VoidGPS.Goods:GoVendor(v, label)
--   VoidGPS.Recipes              -> the same for recipes only (VoidProf 1.2.0 uses it)
--
-- entry = { item, name, kind, line, skill, buy, qty, limited, gold, vendors = { { name, map, x, y,
-- limited, yards, cost, rep }, ... } }. cost = nil when it's bought with gold, else Costs:Offer's
-- table (Merchant's Favor / another currency); rep = reputation the offer needs ("Friendly"),
-- gold or not; gold = some vendor sells it for gold. line = the profession's skill line (171 Alchemy, 164
-- Blacksmithing, 185 Cooking, 333 Enchanting, 202 Engineering, 129 First Aid, 356 Fishing,
-- 165 Leatherworking, 197 Tailoring); skill = skill needed to learn it; buy = vendor price
-- in copper for qty of it; limited = some vendor has it in limited stock.
----------------------------------------------------------------------
local _, ns = ...
local G, Geo = ns.G, ns.Geo

local byItem   -- item -> entry (built once, for your faction)

local function build()
    byItem = {}
    local fac = G:FactionLetter()
    local goods = ns.GOODS or {}
    for idx, list in pairs(ns.SELLS or {}) do
        local npc = ns.NPCS and ns.NPCS[idx]
        if npc and (fac == "" or npc[6]:find(fac, 1, true)) then
            local vx, vy = npc[4] / 10000, npc[5] / 10000
            local cont, wx, wy = Geo.ToWorld(npc[3], vx, vy)   -- once per vendor
            for tok in list:gmatch("[^,]+") do
                local item = tonumber(tok:match("^%d+"))
                local lim = tok:sub(-1) == "*"
                local info = item and goods[item]
                if info then
                    local e = byItem[item]
                    if not e then
                        e = { item = item, name = info[1], kind = info[2], line = info[3], skill = info[4],
                              buy = info[5], qty = info[6] or 1, limited = false, vendors = {} }
                        byItem[item] = e
                    end
                    -- what this vendor wants for it besides gold (Costs.lua): Merchant's Favor + reputation, or a currency
                    -- v.cost only when it's paid with something else; v.rep = reputation it needs either way
                    local c = ns.Costs and ns.Costs:Offer(npc[1], npc[3], item, info[2])
                    local cost = c and c.pay and c or nil
                    e.vendors[#e.vendors + 1] = { name = npc[1], map = npc[3], x = vx, y = vy, limited = lim,
                        cont = cont, wx = wx, wy = wy, cost = cost, rep = c and c.rep }
                    if lim then e.limited = true end
                    if not cost then e.gold = true end   -- at least one vendor sells it for gold
                end
            end
        end
    end
    -- What you've SEEN vendors sell (Costs.lua, VoidGPSDB.stock) wins over NorgannonDB: a
    -- vendor you opened that doesn't stock an item drops off that item; a vendor that does is
    -- added (or moved to where you stood), marked verified. (Wrong vial vendor, 2026-11-09.)
    local stock = VoidGPSDB and VoidGPSDB.stock
    if stock then
        local byName = {}
        for _, s in pairs(stock) do
            if s.name and (fac == "" or not s.fac or s.fac == fac) then byName[s.name] = s end
        end
        for _, e in pairs(byItem) do
            for i = #e.vendors, 1, -1 do
                local v = e.vendors[i]
                local s = byName[v.name]
                if s and s.map == v.map and not s.items[e.item] then table.remove(e.vendors, i) end
            end
        end
        for _, s in pairs(byName) do
            local cont, wx, wy = Geo.ToWorld(s.map, s.x, s.y)
            for item, it in pairs(s.items) do
                local e = byItem[item]
                if not e then
                    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(item)
                    local classID = select(6, C_Item.GetItemInfoInstant(item))
                    local kind = (classID == 9 and "r") or (classID == 7 and "t") or (classID == 0 and "c")
                        or ((classID == 2 or classID == 4) and "g") or "o"
                    e = { item = item, name = name or ("item " .. item), kind = kind, buy = it.buy or 0,
                          qty = it.qty or 1, limited = false, vendors = {} }
                    byItem[item] = e
                end
                local have
                for _, v in ipairs(e.vendors) do
                    if v.name == s.name then have = v end
                end
                if have then
                    have.verified = true
                    have.map, have.x, have.y, have.cont, have.wx, have.wy = s.map, s.x, s.y, cont, wx, wy
                else
                    -- what it costs there besides gold, as for listed vendors (Sol review)
                    local c = ns.Costs and ns.Costs:Offer(s.name, s.map, item, e.kind)
                    local cost = c and c.pay and c or nil
                    e.vendors[#e.vendors + 1] = { name = s.name, map = s.map, x = s.x, y = s.y, cont = cont,
                        wx = wx, wy = wy, limited = it.limited or false, verified = true, cost = cost, rep = c and c.rep }
                    if not cost and it.buy then e.gold = true end
                end
            end
        end
    end
end

-- a vendor scan learned a cost (Costs.lua): build again on next use
function ns.GoodsDirty() byItem = nil end

local function sortVendors(e, cont, px, py)
    for _, v in ipairs(e.vendors) do
        v.yards = (cont and v.cont == cont) and Geo.Dist(px, py, v.wx, v.wy) or nil
    end
    table.sort(e.vendors, function(a, b)
        if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
        -- a vendor you have seen selling it (verified) wins over a listed one up to 150 yards nearer
        if a.yards and b.yards then
            local da = a.yards - (a.verified and 150 or 0)
            local db = b.yards - (b.verified and 150 or 0)
            if da ~= db then return da < db end
        end
        return a.name < b.name
    end)
end

local function make(onlyKind)
    local R = {}
    function R:All(kind)
        kind = onlyKind or kind
        if not byItem then build() end
        local cont, px, py = Geo.Player()
        local out = {}
        for _, e in pairs(byItem) do
            if not kind or e.kind == kind then
                sortVendors(e, cont, px, py)
                out[#out + 1] = e
            end
        end
        table.sort(out, function(a, b) return a.name < b.name end)
        return out
    end
    function R:Get(item)
        if not byItem then build() end
        local e = byItem[item]
        if not e or (onlyKind and e.kind ~= onlyKind) then return nil end
        local cont, px, py = Geo.Player()
        sortVendors(e, cont, px, py)
        return e
    end
    -- route to one given vendor (an entry of e.vendors)
    function R:GoVendor(v, label)
        if not (v and v.map) then return false end
        ns.Guide:Start({ name = v.name, sub = label and ("Sells " .. label) or "Vendor", map = v.map, x = v.x, y = v.y })
        return true
    end
    -- the nearest vendor that sells it for plain gold; only if none does, the nearest one at all
    -- (a recipe route led to a Merchant's Favor vendor, 2026-11-07)
    function R:Go(item)
        local e = self:Get(item)
        if not e then return false end
        local v
        for _, x in ipairs(e.vendors) do if not x.cost then v = x; break end end
        v = v or e.vendors[1]
        if not v then return false end
        self:GoVendor(v, e.name)
        return true, v.name, v.map, v.yards
    end
    return R
end

ns.Goods = make(nil)
G.Goods = ns.Goods
ns.Recipes = make("r")
G.Recipes = ns.Recipes
