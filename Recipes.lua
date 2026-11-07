----------------------------------------------------------------------
-- Recipes.lua — which vendor sells which recipe (Places.lua: NorgannonDB's vendor
-- lists, item data from Blizzard's Forever API). For other addons:
--
--   VoidGPS.Recipes:All()        -> { { item, name, line, skill, buy, limited, vendors }, ... }
--                                   vendors your faction can use, nearest first
--   VoidGPS.Recipes:Get(item)    -> that entry, or nil
--   VoidGPS.Recipes:Go(item)     -> route to the nearest vendor of it: ok, vendor, map, yards
--
-- line = the profession's skill line (171 Alchemy, 164 Blacksmithing, 185 Cooking,
-- 333 Enchanting, 202 Engineering, 129 First Aid, 356 Fishing, 165 Leatherworking,
-- 197 Tailoring); skill = skill needed to learn it; buy = vendor price in copper;
-- limited = at least one vendor has it in limited stock (it comes back after a while).
----------------------------------------------------------------------
local _, ns = ...
local G, Geo = ns.G, ns.Geo
local R = {}
ns.Recipes = R
G.Recipes = R

local byItem   -- item -> entry (built once, for your faction)

local function build()
    byItem = {}
    local fac = G:FactionLetter()
    for _, v in ipairs(ns.RECIPE_VENDORS or {}) do
        local item, vendor, map, x, y, f, lim = v[1], v[2], v[3], v[4], v[5], v[6], v[7]
        local info = ns.RECIPES and ns.RECIPES[item]
        if info and (fac == "" or f:find(fac, 1, true)) then
            local e = byItem[item]
            if not e then
                e = { item = item, name = info[1], line = info[2], skill = info[3], buy = info[4], limited = false, vendors = {} }
                byItem[item] = e
            end
            e.vendors[#e.vendors + 1] = { name = vendor, map = map, x = x / 10000, y = y / 10000, limited = lim == 1 }
            if lim == 1 then e.limited = true end
        end
    end
end

-- yards from you to a vendor (nil when on another continent)
local function yards(v, cont, px, py)
    if not cont then return nil end
    local c, wx, wy = Geo.ToWorld(v.map, v.x, v.y)
    if c ~= cont then return nil end
    return Geo.Dist(px, py, wx, wy)
end

local function sortVendors(e, cont, px, py)
    for _, v in ipairs(e.vendors) do v.yards = yards(v, cont, px, py) end
    table.sort(e.vendors, function(a, b)
        if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
        if a.yards and b.yards and a.yards ~= b.yards then return a.yards < b.yards end
        return a.name < b.name
    end)
end

function R:All()
    if not byItem then build() end
    local cont, px, py = Geo.Player()
    local out = {}
    for _, e in pairs(byItem) do
        sortVendors(e, cont, px, py)
        out[#out + 1] = e
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function R:Get(item)
    if not byItem then build() end
    local e = byItem[item]
    if e then
        local cont, px, py = Geo.Player()
        sortVendors(e, cont, px, py)
    end
    return e
end

-- route to one given vendor (an entry of e.vendors): ok
function R:GoVendor(v, recipeName)
    if not (v and v.map) then return false end
    ns.Guide:Start({ name = v.name, sub = recipeName and ("Sells " .. recipeName) or "Vendor", map = v.map, x = v.x, y = v.y })
    return true
end

function R:Go(item)
    local e = self:Get(item)
    local v = e and e.vendors[1]
    if not v then return false end
    -- (not npc = true: that adds the Target / "is it up?" button, meant for rares)
    ns.Guide:Start({ name = v.name, sub = "Sells " .. e.name, map = v.map, x = v.x, y = v.y })
    return true, v.name, v.map, v.yards
end
