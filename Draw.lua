----------------------------------------------------------------------
-- Draw.lua — the active route on the world map (lines on the map canvas) and
-- on the minimap (dots along the way ahead).
--   cyan solid     along walked paths
--   orange dashed  straight, no walked path known
--   white dashed   a flight
--   purple dashed  boat / zeppelin
----------------------------------------------------------------------
local _, ns = ...
local G = ns.G
local Geo = ns.Geo
local D = {}
ns.Draw = D

local COLORS = {
    known = { 0.00, 0.85, 1.00 },
    straight = { 1.00, 0.55, 0.10 },
    fly = { 1.00, 1.00, 1.00 },
    ride = { 0.75, 0.45, 1.00 },
}

-- What to draw: list of { cont, pts = {{x,y},...}, color, dashed } for the steps still ahead.
local function segments()
    local a = ns.Guide:Active()
    if not (a and a.route) then return {} end
    local out = {}
    local cont, px, py = Geo.Player()
    local steps, idx = a.steps or {}, a.idx or 1
    -- from you to the current step, then each later step
    local prevX, prevY, prevC = px, py, cont
    for i = idx, #steps do
        local s = steps[i]
        if s.kind == "walk" then
            if prevC == s.cont and prevX then
                out[#out + 1] = { cont = s.cont, a = { prevX, prevY }, b = { s.x, s.y },
                    color = s.known and COLORS.known or COLORS.straight, dashed = not s.known }
            end
        elseif s.kind == "flyTo" then
            if prevC == s.cont and prevX then
                out[#out + 1] = { cont = s.cont, a = { prevX, prevY }, b = { s.x, s.y }, color = COLORS.fly, dashed = true }
            end
        elseif s.kind == "flyFrom" or s.kind == "board" then
            if prevC == s.cont and prevX then
                out[#out + 1] = { cont = s.cont, a = { prevX, prevY }, b = { s.x, s.y }, color = COLORS.straight, dashed = true }
            end
        end
        prevX, prevY, prevC = s.x, s.y, s.cont
    end
    -- the ride itself (when both ends are on this continent the line shows)
    for _, leg in ipairs(a.route.legs) do
        if leg.kind == "ride" and leg.from.c == leg.to.c then
            out[#out + 1] = { cont = leg.from.c, a = { leg.from.x, leg.from.y }, b = { leg.to.x, leg.to.y }, color = COLORS.ride, dashed = true }
        end
    end
    return out
end

----------------------------------------------------------------------
-- World map: a data provider drawing Line objects on the canvas
----------------------------------------------------------------------
local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local lines, nLines = {}, 0

local function line()
    nLines = nLines + 1
    local l = lines[nLines]
    if not l then
        l = provider.frame:CreateLine(nil, "OVERLAY")
        lines[nLines] = l
    end
    l:Show()
    return l
end

function provider:OnAdded(map)
    MapCanvasDataProviderMixin.OnAdded(self, map)
    self.frame = CreateFrame("Frame", nil, map:GetCanvas())
    self.frame:SetAllPoints()
    self.frame:SetFrameLevel(map:GetCanvas():GetFrameLevel() + 2000)
end

function provider:RemoveAllData()
    for i = 1, nLines do lines[i]:Hide() end
    nLines = 0
end

function provider:OnCanvasScaleChanged() self:RefreshAllData() end
function provider:OnMapChanged() self:RefreshAllData() end

function provider:RefreshAllData()
    self:RemoveAllData()
    local map = self:GetMap()
    local mapID = map and map:GetMapID()
    if not mapID then return end
    local canvas = map:GetCanvas()
    local cw, ch = canvas:GetSize()
    local scale = map:GetCanvasScale() or 1
    local thick = 3.5 / scale
    local dash = 14 / scale
    for _, s in ipairs(segments()) do
        local ax, ay = Geo.ToMap(s.cont, s.a[1], s.a[2], mapID)
        local bx, by = Geo.ToMap(s.cont, s.b[1], s.b[2], mapID)
        if ax and bx and math.max(ax, bx) > -0.1 and math.min(ax, bx) < 1.1 and math.max(ay, by) > -0.1 and math.min(ay, by) < 1.1 then
            local x1, y1, x2, y2 = ax * cw, ay * ch, bx * cw, by * ch
            local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
            local pieces = s.dashed and math.max(1, math.floor(len / dash)) or 1
            for i = 0, pieces - 1, s.dashed and 2 or 1 do
                local t1, t2 = i / pieces, math.min(1, (i + 1) / pieces)
                local l = line()
                l:SetThickness(thick)
                l:SetColorTexture(s.color[1], s.color[2], s.color[3], 0.95)
                l:SetStartPoint("TOPLEFT", canvas, x1 + (x2 - x1) * t1, -(y1 + (y2 - y1) * t1))
                l:SetEndPoint("TOPLEFT", canvas, x1 + (x2 - x1) * t2, -(y1 + (y2 - y1) * t2))
            end
        end
    end
end

----------------------------------------------------------------------
-- Minimap: small dots along the way ahead, DOT_GAP pixels apart, inside the minimap
----------------------------------------------------------------------
local DOT_GAP, DOT_SIZE = 9, 3
local dots, nDots = {}, 0
local holder

local function dot()
    nDots = nDots + 1
    local t = dots[nDots]
    if not t then
        t = holder:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetSize(DOT_SIZE, DOT_SIZE)
        dots[nDots] = t
    end
    t:Show()
    return t
end

local cache = { mapID = nil, segs = nil, stamp = nil }

local function minimapUpdate()
    nDots = 0
    local a = ns.Guide:Active()
    local mapID, px, py = Geo.PlayerMapPos()
    if a and mapID then
        local w, h = C_Map.GetMapWorldSize(mapID)
        if w and h and w > 0 and h > 0 then
            -- the route in this map's coordinates (the first piece starts at you, so it's live)
            cache.segs = {}
            for _, s in ipairs(segments()) do
                local ax, ay = Geo.ToMap(s.cont, s.a[1], s.a[2], mapID)
                local bx, by = Geo.ToMap(s.cont, s.b[1], s.b[2], mapID)
                if ax and bx then cache.segs[#cache.segs + 1] = { ax, ay, bx, by, s.color } end
            end
            local radius = (C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()) or 133
            if radius <= 0 then radius = 133 end
            local half = Minimap:GetWidth() / 2
            local scale = half / radius
            local rotate = GetCVar("rotateMinimap") == "1"
            local facing = rotate and (GetPlayerFacing() or 0) or 0
            local sinF, cosF = math.sin(facing), math.cos(facing)
            local lim = (half - 3) ^ 2
            for _, s in ipairs(cache.segs) do
                -- only the part of the leg within the minimap's range of you, a dot every 8 yards
                local dxY, dyY = (s[3] - s[1]) * w, (s[4] - s[2]) * h
                local yards = math.sqrt(dxY * dxY + dyY * dyY)
                local t0, t1 = 0, 1
                if yards > 0 then
                    local tc = (((px - s[1]) * w) * dxY + ((py - s[2]) * h) * dyY) / (yards * yards)
                    local win = (radius * 1.5) / yards
                    t0, t1 = math.max(0, tc - win), math.min(1, tc + win)
                end
                -- spaced on screen, not in yards: zoomed in (a city) 8-yard dots merged into a
                -- thick solid line (the user, 2026-11-07)
                local n = math.max(1, math.floor((t1 - t0) * yards * scale / DOT_GAP))
                for i = 0, (t1 >= t0) and n or -1 do
                    if nDots >= 160 then break end
                    local t = t0 + (t1 - t0) * i / n
                    local mx, my = s[1] + (s[3] - s[1]) * t, s[2] + (s[4] - s[2]) * t
                    local sx = (mx - px) * w * scale
                    local sy = -((my - py) * h) * scale
                    if rotate then sx, sy = sx * cosF + sy * sinF, -sx * sinF + sy * cosF end
                    if sx * sx + sy * sy <= lim then
                        local d = dot()
                        d:SetVertexColor(s[5][1], s[5][2], s[5][3], 0.75)
                        d:ClearAllPoints()
                        d:SetPoint("CENTER", Minimap, "CENTER", sx, sy)
                    end
                end
            end
        end
    end
    for i = nDots + 1, #dots do dots[i]:Hide() end
end

-- Called by Guide when the route or the current step changes.
function D:Refresh()
    D.stamp = (D.stamp or 0) + 1
    if WorldMapFrame and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

G:OnReady(function()
    if WorldMapFrame then WorldMapFrame:AddDataProvider(provider) end
    holder = CreateFrame("Frame", nil, Minimap)
    holder:SetAllPoints()
    holder:SetFrameLevel(Minimap:GetFrameLevel() + 6)
    holder.voidKeep = true          -- VoidGather's HUD keeps it on the minimap
    local acc = 0
    holder:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.03 then return end
        acc = 0
        minimapUpdate()
    end)
    -- the line from you to the next turn follows you on the open world map
    C_Timer.NewTicker(0.5, function()
        if ns.Guide:Active() and WorldMapFrame and WorldMapFrame:IsShown() then provider:RefreshAllData() end
    end)
end)
