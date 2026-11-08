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
-- entry = { item, name, kind, line, skill, buy, qty, limited, vendors = { { name, map, x, y,
-- limited, yards }, ... } }. line = the profession's skill line (171 Alchemy, 164
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
                    e.vendors[#e.vendors + 1] = { name = npc[1], map = npc[3], x = vx, y = vy, limited = lim,
                        cont = cont, wx = wx, wy = wy }
                    if lim then e.limited = true end
                end
            end
        end
    end
end

local function sortVendors(e, cont, px, py)
    for _, v in ipairs(e.vendors) do
        v.yards = (cont and v.cont == cont) and Geo.Dist(px, py, v.wx, v.wy) or nil
    end
    table.sort(e.vendors, function(a, b)
        if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
        if a.yards and b.yards and a.yards ~= b.yards then return a.yards < b.yards end
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
    function R:Go(item)
        local e = self:Get(item)
        local v = e and e.vendors[1]
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
