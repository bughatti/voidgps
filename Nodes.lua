----------------------------------------------------------------------
-- Nodes.lua — herbs and ore: every spot each one can spawn (Places.lua, from
-- NorgannonDB). One target at a time: a route to the nearest spot, never a
-- cloud of dots on the map.
--
--   search "briarthorn", "tin vein"   -> route to the nearest spot it can spawn
--   VoidGPS.Nodes, for other addons (VoidProf's leveling plan):
--     Nodes:Has(name)            -> true when VoidGPS knows that node
--     Nodes:Zones(names)         -> { { map, name, n, cont, contName }, ... } most spots first
--     Nodes:Nearest(names)       -> map, x, y, name, yards (yards nil when not on your continent)
--     Nodes:Go(names)            -> ok, name, map, yards: starts the route
----------------------------------------------------------------------
local _, ns = ...
local G, Geo = ns.G, ns.Geo
local N = {}
ns.Nodes = N
G.Nodes = N

N.KIND = { h = "Herb", m = "Ore" }

local function data(name) return ns.NODES and ns.NODES[name] end

function N:Has(name) return data(name) ~= nil end
function N:Kind(name) local d = data(name); return d and d[1] end

-- the spots of one map: "xxxyyy..." -> fn(x, y), 0..1
local function each(s, fn)
    for i = 1, #s - 5, 6 do
        fn(tonumber(s:sub(i, i + 2)) / 999, tonumber(s:sub(i + 3, i + 5)) / 999)
    end
end

local contOf = {}
local function continent(map)
    if contOf[map] == nil then contOf[map] = Geo.ContinentMap(map) or false end
    return contOf[map] or nil
end

function N:Zones(names)
    local count = {}
    for _, name in ipairs(names or {}) do
        local d = data(name)
        if d then
            for map, s in pairs(d[2]) do count[map] = (count[map] or 0) + #s / 6 end
        end
    end
    local out = {}
    for map, n in pairs(count) do
        local c = continent(map)
        out[#out + 1] = { map = map, name = Geo.MapName(map), n = n, cont = c, contName = c and Geo.MapName(c) or nil }
    end
    table.sort(out, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.map < b.map
    end)
    return out
end

-- Spots decoded once per node and map: { cont, { x, y, wx, wy }, ... } (Codex: search
-- re-decoded every spot on each keystroke).
local decoded = {}
local function spots(name, map, s)
    local key = name .. "|" .. map
    local d = decoded[key]
    if d then return d end
    d = { cont = Geo.ToWorld(map, 0.5, 0.5) or false }
    if d.cont then
        each(s, function(x, y)
            local c, wx, wy = Geo.ToWorld(map, x, y)
            if c == d.cont then d[#d + 1] = { x, y, wx, wy } end
        end)
    end
    decoded[key] = d
    return d
end

-- Where Go sent you lately: picked again, it heads for the next one (the one you
-- reached may be picked already).
local sentTo = {}
local SKIP_FOR, SKIP_YARDS = 600, 30
local function skipped(wx, wy)
    local now = GetTime()
    for i = #sentTo, 1, -1 do
        local r = sentTo[i]
        if now - r.t > SKIP_FOR then table.remove(sentTo, i)
        elseif Geo.Dist(r.wx, r.wy, wx, wy) < SKIP_YARDS then return true end
    end
    return false
end

-- The nearest spot on your continent; off it, a spot in the middle of the zone with
-- the most spots (the route takes you across). skipSent: leave out spots Go sent you to.
function N:Nearest(names, skipSent)
    local cont, px, py = Geo.Player()
    local best, bestD
    if cont then
        for _, name in ipairs(names or {}) do
            local d = data(name)
            if d then
                for map, s in pairs(d[2]) do
                    local list = spots(name, map, s)
                    if list.cont == cont then
                        for _, p in ipairs(list) do
                            local dd = Geo.Dist(px, py, p[3], p[4])
                            if (not bestD or dd < bestD) and not (skipSent and skipped(p[3], p[4])) then
                                best, bestD = { map, p[1], p[2], name, p[3], p[4] }, dd
                            end
                        end
                    end
                end
            end
        end
    end
    if best then
        self.lastWorld = { best[5], best[6] }
        return best[1], best[2], best[3], best[4], bestD
    end
    self.lastWorld = nil
    if best then return best[1], best[2], best[3], best[4], bestD end
    local z = self:Zones(names)[1]
    if not z then return nil end
    local cx, cy, cn, cd = 0.5, 0.5, nil, nil
    for _, name in ipairs(names) do
        local d = data(name)
        local s = d and d[2][z.map]
        if s then
            each(s, function(x, y)
                local dd = (x - 0.5) ^ 2 + (y - 0.5) ^ 2
                if not cd or dd < cd then cx, cy, cn, cd = x, y, name, dd end
            end)
        end
    end
    return z.map, cx, cy, cn or names[1], nil
end

function N:Go(names)
    local map, x, y, name, yd = self:Nearest(names, true)
    if not map then return false end
    if self.lastWorld then sentTo[#sentTo + 1] = { wx = self.lastWorld[1], wy = self.lastWorld[2], t = GetTime() } end
    ns.Guide:Start({ name = name, sub = (self.KIND[self:Kind(name)] or "Node") .. " · nearest spot", map = map, x = x, y = y, node = true })
    return true, name, map, yd
end
