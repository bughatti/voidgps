----------------------------------------------------------------------
-- Router.lua — plans a route as a list of legs, in world coordinates:
--   { kind = "walk", cont, pts = { {x, y}, ... }, known = true|false }
--       known: along paths someone walked (VoidMap's trails); otherwise a
--       straight line (addons get no terrain, so it may cross a hill)
--   { kind = "fly",  cont, from = {x, y, name}, to = {x, y, name} }   a flight path you know
--   { kind = "ride", from = {c, x, y}, to = {c, x, y}, name }         zeppelin or boat
-- Walking: A* over the walked 10-yard cells (neighbour bitmask graph), entered
-- from the cell nearest you and left at the cell nearest the target.
----------------------------------------------------------------------
local _, ns = ...
local G = ns.G
local Geo = ns.Geo
local R = {}
ns.Router = R

local FLY_SPEED = 30        -- yd/s, Classic flight paths (rough)
local RIDE_TIME = 90        -- seconds per boat / zeppelin ride, waiting included (rough)
local MAX_EXPAND = 60000    -- A* node budget per search
local ENTER_CELLS = 6       -- look this far (cells) for a trail near you
local LEAVE_CELLS = 20      -- and near the target

local function runSpeed()
    local _, run = GetUnitSpeed("player")
    if not run or (issecretvalue and issecretvalue(run)) then return 7 end   -- secret in combat at times
    return math.max(7, run)
end

----------------------------------------------------------------------
-- Trails
----------------------------------------------------------------------
local function trails()
    local T = VoidMap and VoidMap.Trails
    if not (T and T.Graph and T.DIRS) then return nil end
    return T
end

local function nearestCell(T, g, x, y, radius)
    local C = T.CELL
    local cx, cy = math.floor(x / C), math.floor(y / C)
    local best, bestD
    for r = 0, radius do
        for dy = -r, r do
            for dx = -r, r do
                if math.max(math.abs(dx), math.abs(dy)) == r then
                    local k = T.Key(cx + dx, cy + dy)
                    if g[k] then
                        local px, py = (cx + dx + 0.5) * C, (cy + dy + 0.5) * C
                        local d = (px - x) ^ 2 + (py - y) ^ 2
                        if not bestD or d < bestD then best, bestD = k, d end
                    end
                end
            end
        end
        if best and r * C > math.sqrt(bestD) + C then break end
    end
    return best
end

-- binary heap of { f, key }
local function push(h, f, k)
    h[#h + 1] = { f, k }
    local i = #h
    while i > 1 do
        local p = math.floor(i / 2)
        if h[p][1] <= h[i][1] then break end
        h[p], h[i] = h[i], h[p]
        i = p
    end
end
local function pop(h)
    local top = h[1]
    local last = table.remove(h)
    if #h > 0 then
        h[1] = last
        local i = 1
        while true do
            local l, r, s = i * 2, i * 2 + 1, i
            if l <= #h and h[l][1] < h[s][1] then s = l end
            if r <= #h and h[r][1] < h[s][1] then s = r end
            if s == i then break end
            h[s], h[i] = h[i], h[s]
            i = s
        end
    end
    return top
end

-- cell path from key s to key e, or nil
local function astar(T, g, s, e)
    local ex, ey = T.Decode(e)
    local gScore, came, closed = { [s] = 0 }, {}, {}
    local h = {}
    local function heur(k)
        local x, y = T.Decode(k)
        return math.sqrt((x - ex) ^ 2 + (y - ey) ^ 2)
    end
    push(h, heur(s), s)
    local n = 0
    while #h > 0 do
        local k = pop(h)[2]
        if k == e then
            local path = { k }
            while came[k] do k = came[k]; table.insert(path, 1, k) end
            return path
        end
        if not closed[k] then
            closed[k] = true
            n = n + 1
            if n > MAX_EXPAND then return nil end
            local bits = g[k] or 0
            local x, y = T.Decode(k)
            for _, d in ipairs(T.DIRS) do
                if bit.band(bits, d[3]) ~= 0 then
                    local nk = T.Key(x + d[1], y + d[2])
                    if not closed[nk] and g[nk] then
                        local step = (d[1] ~= 0 and d[2] ~= 0) and 1.4142 or 1
                        local ng = gScore[k] + step
                        if not gScore[nk] or ng < gScore[nk] then
                            gScore[nk], came[nk] = ng, k
                            push(h, ng + heur(nk), nk)
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- keep the corners: drop points that lie within tol yards of the line between neighbours
local function simplify(pts, tol)
    if #pts < 3 then return pts end
    local function rdp(i, j, out)
        local ax, ay, bx, by = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
        local dx, dy = bx - ax, by - ay
        local len = math.sqrt(dx * dx + dy * dy)
        local far, fi = 0, nil
        for k = i + 1, j - 1 do
            local px, py = pts[k][1], pts[k][2]
            local d = len > 0 and math.abs(dy * px - dx * py + bx * ay - by * ax) / len or Geo.Dist(px, py, ax, ay)
            if d > far then far, fi = d, k end
        end
        if fi and far > tol then
            rdp(i, fi, out)
            out[#out + 1] = pts[fi]
            rdp(fi, j, out)
        end
    end
    local out = { pts[1] }
    rdp(1, #pts, out)
    out[#out + 1] = pts[#pts]
    return out
end

local function legLength(pts)
    local n = 0
    for i = 2, #pts do n = n + Geo.Dist(pts[i - 1][1], pts[i - 1][2], pts[i][1], pts[i][2]) end
    return n
end

-- Walking legs from (ax, ay) to (bx, by) on one continent: along trails when they connect.
function R:Walk(cont, ax, ay, bx, by)
    local T = trails()
    local g = T and T:Graph(cont)
    if g then
        local s = nearestCell(T, g, ax, ay, ENTER_CELLS)
        local e = s and nearestCell(T, g, bx, by, LEAVE_CELLS)
        local cells = e and s ~= e and astar(T, g, s, e)
        if s and e and s == e then
            -- start and end in one walked cell: just go there
            return { { kind = "walk", cont = cont, known = true, pts = { { ax, ay }, { bx, by } } } }, Geo.Dist(ax, ay, bx, by)
        end
        if cells and #cells >= 2 then
            local C = T.CELL
            local pts = {}
            for _, k in ipairs(cells) do
                local x, y = T.Decode(k)
                pts[#pts + 1] = { (x + 0.5) * C, (y + 0.5) * C }
            end
            local legs = {}
            local first, last = pts[1], pts[#pts]
            if Geo.Dist(ax, ay, first[1], first[2]) > 15 then
                legs[#legs + 1] = { kind = "walk", cont = cont, known = false, pts = { { ax, ay }, first } }
            else
                pts[1] = { ax, ay }
            end
            local tail = Geo.Dist(bx, by, last[1], last[2]) > 15
            if not tail then pts[#pts] = { bx, by } end
            legs[#legs + 1] = { kind = "walk", cont = cont, known = true, pts = simplify(pts, 5) }
            if tail then legs[#legs + 1] = { kind = "walk", cont = cont, known = false, pts = { last, { bx, by } } } end
            -- a trail that wanders far more than the straight line isn't worth following
            local trail = 0
            for _, l in ipairs(legs) do trail = trail + legLength(l.pts) end
            if trail < Geo.Dist(ax, ay, bx, by) * 3 + 200 then return legs, trail end
        end
    end
    return { { kind = "walk", cont = cont, known = false, pts = { { ax, ay }, { bx, by } } } }, Geo.Dist(ax, ay, bx, by)
end

----------------------------------------------------------------------
-- Flight paths you know on this continent (world coordinates)
----------------------------------------------------------------------
-- The flight paths THIS character knows. Away from a flight master, WoW Forever reports every
-- flight path as discovered (checked 2026-11-11: GetTaxiNodesForMap(Eastern Kingdoms) gave 0
-- undiscovered, Stonard included, for a character who had never been there; the route planner
-- then sent the user to the Swamp of Sorrows "by air"). The flight master's own map knows:
-- GetAllTaxiNodes gives Current / Reachable for the ones you have. Saved per character in
-- VoidGPSDB.knownFP[name] when a flight map opens, and a new flight path is added when the game
-- says "New flight path discovered" (the nearest one). Until a character has opened a flight map,
-- every flight path counts, as before; per continent, since a flight map lists that continent only.
-- Name-Realm (Codex 11-12: GetUnitName("player", true) leaves your own realm off, so the same name on
-- two realms shared one list). A list saved under the plain name moves over once.
local function charKey()
    local name = UnitName("player") or "?"
    local realm = GetRealmName and GetRealmName()
    return (realm and realm ~= "") and (name .. "-" .. realm:gsub("%s", "")) or name
end
local function knownFP()
    local d = VoidGPSDB and VoidGPSDB.knownFP
    if not d then return nil end
    local k = charKey()
    if d[k] == nil then
        local old = UnitName("player")
        if old and old ~= k and type(d[old]) == "table" then d[k], d[old] = d[old], nil end
    end
    return d[k]
end
local function flightNodes(contMapID)
    local list = {}
    if not (contMapID and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return list end
    local fac = UnitFactionGroup("player")
    local known = knownFP()
    for _, n in ipairs(C_TaxiMap.GetTaxiNodesForMap(contMapID) or {}) do
        local mine = n.faction == nil or n.faction == Enum.FlightPathFaction.Neutral
            or (n.faction == Enum.FlightPathFaction.Horde and fac == "Horde")
            or (n.faction == Enum.FlightPathFaction.Alliance and fac == "Alliance")
        local name = n.name
        if name and (name:find("^zzOLD") or (known and known[name] == false)) then mine = false end
        if mine and not n.isUndiscovered and n.position then
            local cont, x, y = Geo.ToWorld(contMapID, n.position.x, n.position.y)
            if cont then list[#list + 1] = { cont = cont, x = x, y = y, name = n.name } end
        end
    end
    return list
end

local function nearestNode(nodes, x, y)
    local best, bd
    for _, n in ipairs(nodes) do
        local d = Geo.Dist(n.x, n.y, x, y)
        if not bd or d < bd then best, bd = n, d end
    end
    return best, bd
end

-- One continent: walk, or walk + fly + walk when that's clearly quicker.
function R:SameContinent(cont, contMapID, ax, ay, bx, by)
    local run = runSpeed()
    local walkLegs, walkLen = self:Walk(cont, ax, ay, bx, by)
    local best, bestCost = walkLegs, walkLen / run
    local nodes = flightNodes(contMapID)
    local A, dA = nearestNode(nodes, ax, ay)
    local B, dB = nearestNode(nodes, bx, by)
    if A and B and A ~= B then
        local fly = Geo.Dist(A.x, A.y, B.x, B.y) * 1.3 / FLY_SPEED + 20
        local cost = dA / run + fly + dB / run
        if cost < bestCost * 0.8 then
            local legs = {}
            for _, l in ipairs((self:Walk(cont, ax, ay, A.x, A.y))) do legs[#legs + 1] = l end
            legs[#legs + 1] = { kind = "fly", cont = cont, from = A, to = B }
            for _, l in ipairs((self:Walk(cont, B.x, B.y, bx, by))) do legs[#legs + 1] = l end
            best, bestCost = legs, cost
        end
    end
    return best, bestCost
end

----------------------------------------------------------------------
-- Boats and zeppelins: seeded zeppelins (Places.lua) + rides VoidMap learned
----------------------------------------------------------------------
local function links()
    local list = {}
    local fac = G:FactionLetter()
    -- the city a tower serves = where its return trip goes ("the zeppelin outside Orgrimmar", the user
    -- 2026-11-09): the row starting at this row's far end goes back to "Orgrimmar"
    local backTo = {}
    for _, z in ipairs(ns.ZEPPELINS or {}) do backTo[z[1]] = z[9] end
    for _, z in ipairs(ns.ZEPPELINS or {}) do
        if z[10]:find(fac, 1, true) then
            local c1, x1, y1 = Geo.ToWorld(z[2], z[3] / 10000, z[4] / 10000)
            local c2, x2, y2 = Geo.ToWorld(z[6], z[7] / 10000, z[8] / 10000)
            if c1 and c2 then
                list[#list + 1] = { from = { c = c1, x = x1, y = y1 }, to = { c = c2, x = x2, y = y2 },
                    name = "zeppelin to " .. z[9], at = z[1], dest = z[9], fromMap = z[2], near = backTo[z[5]] }
            end
        end
    end
    local T = VoidMap and VoidMap.Trails
    for _, l in ipairs(T and T.Links and T:Links() or {}) do
        list[#list + 1] = { from = l.a, to = l.b, name = "boat or zeppelin (you rode it)", learned = true }
    end
    return list
end
R.Links = links

----------------------------------------------------------------------
-- The plan
----------------------------------------------------------------------
-- from = { cont, x, y, map }, to = { cont, x, y, map } (world)
-- -> { legs = {...}, cost = seconds } or nil, why
function R:Plan(from, to)
    if not (from and to and from.cont and to.cont) then return nil, "no position" end
    if from.cont == to.cont then
        local contMap = Geo.ContinentMap(from.map)
        local legs, cost = self:SameContinent(from.cont, contMap, from.x, from.y, to.x, to.y)
        -- a boat inside one continent (to an island, across a bay) can beat walking or flying
        local run = runSpeed()
        for _, l in ipairs(links()) do
            if l.from.c == from.cont and l.to.c == from.cont then
                local c2 = Geo.Dist(from.x, from.y, l.from.x, l.from.y) / run + RIDE_TIME
                    + Geo.Dist(l.to.x, l.to.y, to.x, to.y) / run
                if c2 < cost * 0.8 then
                    local viaLegs = self:SameContinent(from.cont, contMap, from.x, from.y, l.from.x, l.from.y)
                    viaLegs[#viaLegs + 1] = { kind = "ride", from = l.from, to = l.to, name = l.name, at = l.at, dest = l.dest, fromMap = l.fromMap, near = l.near }
                    for _, x in ipairs((self:SameContinent(from.cont, contMap, l.to.x, l.to.y, to.x, to.y))) do viaLegs[#viaLegs + 1] = x end
                    legs, cost = viaLegs, c2
                end
            end
        end
        return { legs = legs, cost = cost }
    end
    -- another continent: the cheapest known ride from here to there
    local run = runSpeed()
    local best, bestCost
    for _, l in ipairs(links()) do
        if l.from.c == from.cont and l.to.c == to.cont then
            local cost = Geo.Dist(from.x, from.y, l.from.x, l.from.y) / run + RIDE_TIME
                + Geo.Dist(l.to.x, l.to.y, to.x, to.y) / run
            if not bestCost or cost < bestCost then best, bestCost = l, cost end
        end
    end
    if not best then
        return nil, "no known boat or zeppelin from here to there yet: take one once and VoidGPS remembers it"
    end
    local legs = self:SameContinent(from.cont, Geo.ContinentMap(from.map), from.x, from.y, best.from.x, best.from.y)
    legs[#legs + 1] = { kind = "ride", from = best.from, to = best.to, name = best.name, at = best.at, dest = best.dest, fromMap = best.fromMap, near = best.near }
    -- the rest is planned again on arrival (a new continent, new flight paths)
    legs[#legs + 1] = { kind = "walk", cont = to.cont, known = false, pts = { { best.to.x, best.to.y }, { to.x, to.y } } }
    return { legs = legs, cost = bestCost }
end

----------------------------------------------------------------------
-- A quick travel-time estimate, no path search (for VoidQuest's route planner, the user
-- 2026-11-11: "start the route planner", which needs the time between every two stops of
-- a quest log). Same continent: walking a straight line (x1.3 for the bends) or the
-- nearest flight paths when clearly quicker; another continent: the cheapest known boat or
-- zeppelin. from / to = { cont, x, y, map } (world). -> seconds, or nil when no way is known.
----------------------------------------------------------------------
local nodeCache = {}   -- [contMapID] = { t = GetTime(), list }
local function cachedNodes(contMapID)
    local c = contMapID and nodeCache[contMapID]
    if c and GetTime() - c.t < 60 then return c.list end
    local list = flightNodes(contMapID)
    if contMapID then nodeCache[contMapID] = { t = GetTime(), list = list } end
    return list
end
local function sameContEstimate(contMapID, ax, ay, bx, by, run)
    local cost = Geo.Dist(ax, ay, bx, by) * 1.3 / run
    local nodes = cachedNodes(contMapID)
    local A, dA = nearestNode(nodes, ax, ay)
    local B, dB = nearestNode(nodes, bx, by)
    if A and B and A ~= B then
        local fly = dA * 1.3 / run + Geo.Dist(A.x, A.y, B.x, B.y) * 1.3 / FLY_SPEED + 20 + dB * 1.3 / run
        if fly < cost then cost = fly end
    end
    return cost
end
function R:Estimate(from, to, linkList)
    if not (from and to and from.cont and to.cont) then return nil end
    local run = runSpeed()
    if from.cont == to.cont then
        return sameContEstimate(Geo.ContinentMap(from.map), from.x, from.y, to.x, to.y, run)
    end
    local best
    for _, l in ipairs(linkList or links()) do
        if l.from.c == from.cont and l.to.c == to.cont then
            local cost = sameContEstimate(Geo.ContinentMap(from.map), from.x, from.y, l.from.x, l.from.y, run)
                + RIDE_TIME + Geo.Dist(l.to.x, l.to.y, to.x, to.y) * 1.3 / run
            if not best or cost < best then best = cost end
        end
    end
    return best
end

----------------------------------------------------------------------
-- Learning which flight paths this character knows (see knownFP above)
----------------------------------------------------------------------
local function learned(name, known)
    if not name or name == "" then return end
    VoidGPSDB = VoidGPSDB or {}
    VoidGPSDB.knownFP = VoidGPSDB.knownFP or {}
    knownFP()   -- moves a list saved under the plain name over first
    local key = charKey()
    VoidGPSDB.knownFP[key] = VoidGPSDB.knownFP[key] or {}
    -- false = the flight map says you don't have it; flight paths never seen stay nil and count, so a
    -- continent whose flight map you haven't opened yet keeps working as before
    VoidGPSDB.knownFP[key][name] = known and true or false
    wipe(nodeCache)
end
local fpEv = CreateFrame("Frame")
fpEv:RegisterEvent("TAXIMAP_OPENED")
fpEv:RegisterEvent("UI_INFO_MESSAGE")
fpEv:SetScript("OnEvent", function(_, event, _, msg)
    if event == "TAXIMAP_OPENED" then
        -- WoW Forever's flight map answers the classic calls (checked 2026-11-11: GetTaxiMapID nil,
        -- GetAllTaxiNodes empty; NumTaxiNodes lists EVERY flight path of the continent: CURRENT 1 and
        -- REACHABLE 5 = the ones you have, DISTANT 8 = the ones you DON'T (Stonard, Light's Hope,
        -- Thorium Point ...)); the newer calls as a fallback
        local n = NumTaxiNodes and NumTaxiNodes() or 0
        for i = 1, n do
            local kind = TaxiNodeGetType and TaxiNodeGetType(i)
            learned(TaxiNodeName(i), kind == "CURRENT" or kind == "REACHABLE")
        end
        if n == 0 then
            local mapID = GetTaxiMapID and GetTaxiMapID()   -- a global, not C_TaxiMap (Codex 11-12)
            local nodes = mapID and C_TaxiMap.GetAllTaxiNodes and C_TaxiMap.GetAllTaxiNodes(mapID) or {}
            local S = Enum.FlightPathState or {}
            for _, nd in ipairs(nodes) do
                learned(nd.name, nd.state == (S.Current or 0) or nd.state == (S.Reachable or 1))
            end
        end
    elseif type(msg) == "string" and ERR_NEWTAXIPATH and msg == ERR_NEWTAXIPATH then
        -- "New flight path discovered!": the flight master you're standing at
        local cont, x, y, map = Geo.Player()
        local contMap = map and Geo.ContinentMap(map)
        if not (cont and contMap) then return end
        local best, bd
        for _, n in ipairs(C_TaxiMap.GetTaxiNodesForMap(contMap) or {}) do
            local c2, nx, ny
            if n.position then c2, nx, ny = Geo.ToWorld(contMap, n.position.x, n.position.y) end   -- (not "and": it keeps one value)
            if c2 == cont and nx then
                local d = Geo.Dist(nx, ny, x, y)
                if not bd or d < bd then best, bd = n, d end
            end
        end
        if best and bd < 60 then learned(best.name, true) end
    end
end)
R.KnownFlightPaths = function() return knownFP() end
