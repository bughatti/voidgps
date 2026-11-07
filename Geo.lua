----------------------------------------------------------------------
-- Geo.lua — positions in world coordinates (continent, x, y in yards), which is
-- what routes are planned in, and back to map coordinates for drawing.
----------------------------------------------------------------------
local _, ns = ...
local Geo = {}
ns.Geo = Geo

local function vec(x, y) return CreateVector2D(x, y) end

-- map (0-1) -> world
function Geo.ToWorld(mapID, x, y)
    if not (mapID and x and y) then return nil end
    local ok, cont, wp = pcall(C_Map.GetWorldPosFromMapPos, mapID, vec(x, y))
    if not ok or not cont or not wp then return nil end
    return cont, wp.x, wp.y
end

-- world -> map (0-1, may be outside 0-1 when the point is off that map)
function Geo.ToMap(cont, wx, wy, mapID)
    if not (cont and wx and mapID) then return nil end
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, vec(wx, wy), mapID)
    if not ok or not pos then return nil end
    return pos.x, pos.y
end

function Geo.PlayerMapPos()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not pos then return nil end
    local x, y = pos:GetXY()
    if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return nil end
    if not x or (x == 0 and y == 0) then return nil end
    return mapID, x, y
end

-- the player in world coordinates: cont, x, y, mapID
function Geo.Player()
    local mapID, x, y = Geo.PlayerMapPos()
    if not mapID then return nil end
    local cont, wx, wy = Geo.ToWorld(mapID, x, y)
    if not cont then return nil end
    return cont, wx, wy, mapID
end

-- a group member in world coordinates
function Geo.Unit(unit)
    local mapID = C_Map.GetBestMapForUnit(unit)
    if not mapID then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
    if not ok or not pos then return nil end
    local x, y = pos:GetXY()
    if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return nil end
    if not x or (x == 0 and y == 0) then return nil end
    local cont, wx, wy = Geo.ToWorld(mapID, x, y)
    return cont, wx, wy, mapID, x, y
end

function Geo.Dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

-- the continent map (UI map) a map belongs to
function Geo.ContinentMap(mapID)
    local info = mapID and MapUtil.GetMapParentInfo(mapID, Enum.UIMapType.Continent, true)
    return info and info.mapID or nil
end

function Geo.MapName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name or "?"
end

-- the zone a world point is in, as seen from a continent map
function Geo.ZoneAt(contMapID, cont, wx, wy)
    local x, y = Geo.ToMap(cont, wx, wy, contMapID)
    if not x then return nil end
    local info = C_Map.GetMapInfoAtPosition(contMapID, x, y)
    return info and info.mapID or nil, info and info.name or nil
end

-- "1,240"
function Geo.Yards(n)
    n = math.floor((n or 0) + 0.5)
    local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return s
end
