----------------------------------------------------------------------
-- FlightMap.lua — every flight master of your faction on the world map (zone, city and continent
-- maps), WoW Forever only (retail's map has its own). The user, 2026-11-20: "can you put all flight
-- paths on all the map zones, i need to find them".
--   green   you have this flight path
--   yellow  you don't have it yet (go talk to that flight master)
--   white   not checked yet: open any flight master's map once on this character
-- Click a dot: VoidGPS routes you there. Positions: C_TaxiMap.GetTaxiNodesForMap(the map you look at)
-- (measured 11-20, VoidDev scan: on Forever it answers for every zone map, in that map's own 0-1
-- coordinates). Which ones you have: Router's per-character list (filled at a flight master).
----------------------------------------------------------------------
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end   -- WoW Forever only
local _, ns = ...
local G = ns.G

local COLOR = {
    have = { 0.30, 1.00, 0.30 },
    need = { 1.00, 0.82, 0.00 },
    unknown = { 0.90, 0.90, 0.90 },
}

local function on() return not (VoidGPSDB and VoidGPSDB.flightPins == false) end

local function mine(n, fac)
    local F = Enum and Enum.FlightPathFaction
    if n.faction == nil or not F then return true end
    return n.faction == F.Neutral or (n.faction == F.Horde and fac == "Horde")
        or (n.faction == F.Alliance and fac == "Alliance")
end

local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local dots, nDots = {}, 0

local function onEnter(self)
    local n = self.node
    if not n then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(n.name, 1, 1, 1)
    if n.state == "have" then
        GameTooltip:AddLine("You have this flight path.", 0.3, 1, 0.3)
    elseif n.state == "need" then
        GameTooltip:AddLine("You don't have it yet: talk to the flight master here.", 1, 0.82, 0)
    else
        GameTooltip:AddLine("Not checked yet: open any flight master's map once on this character.", 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("Click: route me there", 0.5, 0.8, 1)
    GameTooltip:Show()
end

local function onClick(self)
    local n = self.node
    if n and G.RouteTo then G:RouteTo({ name = n.name, sub = "Flight master", map = n.map, x = n.x, y = n.y }) end
end

-- Right-click goes on to the map (zoom out), like Blizzard's own map pins (Codex Sol 11-20).
-- SetPassThroughButtons is blocked in combat (memory wow-map-zoom-taint-pin-guard): a dot made in a
-- fight gets it when the fight ends.
local waiting = {}
local function passRight(d)
    if InCombatLockdown() then waiting[#waiting + 1] = d; return end
    if d.SetPassThroughButtons then pcall(d.SetPassThroughButtons, d, "RightButton") end
end
local regen = CreateFrame("Frame")
regen:RegisterEvent("PLAYER_REGEN_ENABLED")
regen:SetScript("OnEvent", function()
    local list = waiting
    waiting = {}
    for _, d in ipairs(list) do passRight(d) end
end)

local function dot()
    nDots = nDots + 1
    local d = dots[nDots]
    if not d then
        d = CreateFrame("Button", nil, provider.frame)
        d:RegisterForClicks("LeftButtonUp")
        passRight(d)
        d.ring = d:CreateTexture(nil, "BACKGROUND")
        d.ring:SetPoint("TOPLEFT", -1, 1); d.ring:SetPoint("BOTTOMRIGHT", 1, -1)
        d.ring:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        d.ring:SetVertexColor(0, 0, 0, 0.9)
        d.disc = d:CreateTexture(nil, "BORDER")
        d.disc:SetAllPoints()
        d.disc:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        d.icon = d:CreateTexture(nil, "ARTWORK")
        d.icon:SetPoint("TOPLEFT", 1, -1); d.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        d.icon:SetTexture("Interface\\Minimap\\Tracking\\FlightMaster")
        d:SetScript("OnEnter", onEnter)
        d:SetScript("OnLeave", function() GameTooltip:Hide() end)
        d:SetScript("OnClick", onClick)
        dots[nDots] = d
    end
    d:Show()
    return d
end

function provider:OnAdded(map)
    MapCanvasDataProviderMixin.OnAdded(self, map)
    self.frame = CreateFrame("Frame", nil, map:GetCanvas())
    self.frame:SetAllPoints()
    self:SetLevel()
    -- make the dots now (at load, out of combat) so the right-click pass-through is set on them
    for _ = 1, 30 do dot() end
    self:RemoveAllData()
end

-- Map pins sit at FIXED levels from about 2000 up (MapCanvas_PinFrameLevelsManager), the explored-area
-- art (PIN_FRAME_LEVEL_MAP_EXPLORATION) among the lowest. Measured live 11-20: at canvas + 1900 (= 1903)
-- the dots were drawn but hidden under the zone art on every zone map. Use Blizzard's own flight point
-- level: above the art, below the quest pins.
function provider:SetLevel()
    local map = self:GetMap()
    local level
    local ok, mgr = pcall(function() return map:GetPinFrameLevelsManager() end)
    if ok and mgr and mgr.GetValidFrameLevel then
        local ok2, l = pcall(mgr.GetValidFrameLevel, mgr, "PIN_FRAME_LEVEL_FLIGHT_POINT")
        if ok2 and type(l) == "number" then level = l end
    end
    self.frame:SetFrameLevel(level or 2200)
end

function provider:RemoveAllData()
    for i = 1, nDots do dots[i]:Hide(); dots[i].node = nil end
    nDots = 0
end

function provider:OnCanvasScaleChanged() self:RefreshAllData() end
function provider:OnMapChanged() self:RefreshAllData() end

-- mapID itself, or a map inside it (Orgrimmar's flight master also shows on Durotar)
local function within(zone, mapID)
    for _ = 1, 6 do
        if not zone then return false end
        if zone == mapID then return true end
        local info = C_Map.GetMapInfo(zone)
        zone = info and info.parentMapID
    end
    return false
end

-- A city drawn inside the zone you look at: its own map covers a small part of this one. Measured live
-- 11-20: Orgrimmar's parent is Kalimdor, not Durotar, so "inside" by parents alone hid Orgrimmar's
-- flight master on the Durotar map, right under the city art.
-- A small map's rectangle (a city) alone isn't enough: Thunder Bluff (Mulgore) also sits inside the
-- Barrens map's rectangle (live 11-20). So: the zone that surrounds the city on the continent map
-- (8 points just outside its edges, most votes) is its home.
local homeCache = {}
local function cityHome(city, contID)
    local key = city * 100000 + contID
    if homeCache[key] ~= nil then return homeCache[key] end
    local home = false
    local Geo = ns.Geo
    if Geo and Geo.ToWorld and Geo.ToMap then
        local c1, ax, ay = Geo.ToWorld(city, 0, 0)
        local c2, bx, by = Geo.ToWorld(city, 1, 1)
        if c1 and c2 and c1 == c2 then
            local x1, y1 = Geo.ToMap(c1, ax, ay, contID)
            local x2, y2 = Geo.ToMap(c1, bx, by, contID)
            -- city-sized on the continent. Measured live 11-20 (share of the continent map): Undercity
            -- 0.0007, Thunder Bluff 0.0008, Orgrimmar 0.0015; Moonglade (a zone of its own) 0.0039, Durotar 0.0206
            if x1 and x2 and math.abs((x2 - x1) * (y2 - y1)) < 0.0025 then
                local lx, hx, ly, hy = math.min(x1, x2), math.max(x1, x2), math.min(y1, y2), math.max(y1, y2)
                local px, py = (hx - lx) * 0.08, (hy - ly) * 0.08
                local mx, my = (lx + hx) / 2, (ly + hy) / 2
                local votes, best, bestN = {}, nil, 0
                for _, p in ipairs({ { lx - px, my }, { hx + px, my }, { mx, ly - py }, { mx, hy + py },
                    { lx - px, ly - py }, { hx + px, ly - py }, { lx - px, hy + py }, { hx + px, hy + py } }) do
                    local at = C_Map.GetMapInfoAtPosition(contID, p[1], p[2])
                    local z = at and at.mapID
                    if z and z ~= city then
                        votes[z] = (votes[z] or 0) + 1
                        if votes[z] > bestN then best, bestN = z, votes[z] end
                    end
                end
                home = best or false
            end
        end
    end
    homeCache[key] = home
    return home
end

-- A zone map's rectangle reaches into its neighbours (blank art there): measured 11-20, Darkshore's
-- map held 9 flight paths, Winterspring's among them. Keep the ones whose zone (asked of the
-- continent map, like the world map's own highlight) is this map or inside it. nodeID -> keep
local function inZone(mapID)
    local info = C_Map.GetMapInfo(mapID)
    local T = Enum.UIMapType
    if not (info and T and info.mapType and info.mapType > T.Continent) then return nil end   -- world/continent: all
    local contID = ns.Geo and ns.Geo.ContinentMap(mapID)
    if not (contID and C_Map.GetMapInfoAtPosition) then return nil end
    local keep = {}
    for _, n in ipairs(C_TaxiMap.GetTaxiNodesForMap(contID) or {}) do
        local p = n.position
        if n.nodeID and p and p.x then
            local at = C_Map.GetMapInfoAtPosition(contID, p.x, p.y)
            if at and at.mapID then   -- no answer: show it
                keep[n.nodeID] = within(at.mapID, mapID) or cityHome(at.mapID, contID) == mapID
            end
        end
    end
    return keep
end

-- The dots for one map: { name, map, x, y, state } (also used by the tests)
function ns.FlightDots(mapID)
    local out = {}
    if not (mapID and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return out end
    local fac = UnitFactionGroup("player")
    local known = ns.Router and ns.Router.KnownFlightPaths and ns.Router.KnownFlightPaths()
    local keep = inZone(mapID)
    local seen = {}
    for _, n in ipairs(C_TaxiMap.GetTaxiNodesForMap(mapID) or {}) do
        local name, pos = n.name, n.position
        if name and pos and not name:find("^zzOLD") and not seen[name] and mine(n, fac)
            and (not keep or keep[n.nodeID] ~= false) then
            local x, y = pos.x, pos.y
            if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                seen[name] = true
                local k = known and known[name]
                out[#out + 1] = { name = name, map = mapID, x = x, y = y,
                    state = (k == true and "have") or (k == false and "need") or "unknown" }
            end
        end
    end
    return out
end

function provider:RefreshAllData()
    self:RemoveAllData()
    if not on() then return end
    self:SetLevel()
    local map = self:GetMap()
    local mapID = map and map:GetMapID()
    if not mapID then return end
    local canvas = map:GetCanvas()
    local cw, ch = canvas:GetSize()
    local scale = map:GetCanvasScale() or 1
    local info = C_Map.GetMapInfo(mapID)
    local cont = info and Enum.UIMapType and info.mapType == Enum.UIMapType.Continent
    -- small, like a quest helper's marks (the user, 2026-11-21: "flight master circles are huge"; was 17 / 13)
    local size = (cont and 8 or 11) / scale
    for _, n in ipairs(ns.FlightDots(mapID)) do
        local d = dot()
        d.node = n
        d:SetFrameLevel(self.frame:GetFrameLevel() + 1)
        d:SetSize(size, size)
        local c = COLOR[n.state]
        d.disc:SetVertexColor(c[1], c[2], c[3], 1)
        d:ClearAllPoints()
        d:SetPoint("CENTER", canvas, "TOPLEFT", n.x * cw, -n.y * ch)
    end
end

function G:FlightDots(mapID) return ns.FlightDots(mapID) end   -- for checks: /run VoidGPS:FlightDots(1411)
-- for checks: what the map layer drew (dots shown, the first one's size / spot / visibility)
function G:FlightDebug()
    local d = dots[1]
    local map = provider:GetMap()
    local cv = map and map:GetCanvas()
    local s = string.format("map=%s scale=%.2f shown=%d canvas=%s/%d frame=%s/%d", tostring(map and map:GetMapID()),
        map and map:GetCanvasScale() or -1, nDots, cv and cv:GetFrameStrata() or "?", cv and cv:GetFrameLevel() or -1,
        provider.frame:GetFrameStrata(), provider.frame:GetFrameLevel())
    if d and nDots > 0 then
        local x, y = d:GetCenter()
        local es = d:GetEffectiveScale()
        s = s .. string.format(" w=%.1f vis=%s alpha=%.2f screen=%.0f,%.0f es=%.2f lvl=%d strata=%s tex=%s dvis=%s dw=%.1f",
            d:GetWidth(), tostring(d:IsVisible()), d:GetEffectiveAlpha(), (x or 0) * es, (y or 0) * es, es,
            d:GetFrameLevel(), d:GetFrameStrata(), tostring(d.disc:GetTexture()), tostring(d.disc:IsVisible()),
            d.disc:GetWidth())
    end
    return s
end

function G:SetFlightPins(v)
    VoidGPSDB = VoidGPSDB or {}
    VoidGPSDB.flightPins = v and true or false
    if WorldMapFrame and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

VoidHubToggles = VoidHubToggles or {}
table.insert(VoidHubToggles, {
    id = "VoidGPS.flights", group = "GPS", label = "Flight paths on the map",
    tip = "Every flight master of your faction on the world map: green = you have it, yellow = not yet. Click one to get a route there.",
    get = on,
    set = function(v) G:SetFlightPins(v) end,
})

G:OnReady(function()
    if WorldMapFrame then WorldMapFrame:AddDataProvider(provider) end
end)
