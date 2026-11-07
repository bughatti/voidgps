----------------------------------------------------------------------
-- Guide.lua — the active route.
--
-- The route becomes a list of steps (turns, the flight master, the zeppelin
-- tower, ...). Blizzard's own waypoint arrow points at the next step; when you
-- reach it, it moves on. Off the route by more than 60 yards, a new plan is made
-- (at most every 4 s); a new continent (after a boat or zeppelin) plans the rest.
-- A waypoint someone else sets (you, or another addon) ends the route: VoidGPS
-- never fights for the arrow.
----------------------------------------------------------------------
local _, ns = ...
local G = ns.G
local Geo = ns.Geo
local U = {}
local Guide = {}
ns.Guide = Guide

local REACH, REACH_LAST = 12, 10
local OFF_ROUTE = 60
local REPLAN_EVERY = 4

local active     -- { target, route, steps, idx, cont, lastPlan, wp }
local box

local function stepsOf(route)
    local steps = {}
    for _, leg in ipairs(route.legs) do
        if leg.kind == "walk" then
            for i = 2, #leg.pts do
                steps[#steps + 1] = { kind = "walk", cont = leg.cont, x = leg.pts[i][1], y = leg.pts[i][2], known = leg.known,
                    px = leg.pts[i - 1][1], py = leg.pts[i - 1][2] }
            end
        elseif leg.kind == "fly" then
            steps[#steps + 1] = { kind = "flyFrom", cont = leg.cont, x = leg.from.x, y = leg.from.y, to = leg.to }
            steps[#steps + 1] = { kind = "flyTo", cont = leg.cont, x = leg.to.x, y = leg.to.y, to = leg.to }
        elseif leg.kind == "ride" then
            steps[#steps + 1] = { kind = "board", cont = leg.from.c, x = leg.from.x, y = leg.from.y, name = leg.name, at = leg.at }
        end
    end
    return steps
end

----------------------------------------------------------------------
-- Blizzard's waypoint, ours only while it is ours
----------------------------------------------------------------------
local function sameWp(a, b)
    return a and b and a.uiMapID == b.uiMapID and math.abs(a.position.x - b.position.x) < 0.0005
        and math.abs(a.position.y - b.position.y) < 0.0005
end

local function setWaypoint(cont, wx, wy)
    local here = C_Map.GetBestMapForUnit("player")
    local contMap = Geo.ContinentMap(here)
    local zone = contMap and Geo.ZoneAt(contMap, cont, wx, wy)
    local tryMaps = {}   -- (no nil holes: ipairs stops at the first nil)
    for _, m in pairs({ zone or false, here or false, contMap or false }) do if m then tryMaps[#tryMaps + 1] = m end end
    for _, m in ipairs(tryMaps) do
        if C_Map.CanSetUserWaypointOnMap(m) then
            local x, y = Geo.ToMap(cont, wx, wy, m)
            if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                local p = UiMapPoint.CreateFromCoordinates(m, x, y)
                active.wp = p
                active.settingWp = true
                C_Map.SetUserWaypoint(p)
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                active.settingWp = false
                return true
            end
        end
    end
    return false
end

local function clearWaypoint()
    if active and active.wp and sameWp(C_Map.GetUserWaypoint(), active.wp) then
        active.settingWp = true
        C_Map.ClearUserWaypoint()
        active.settingWp = false
    end
end

----------------------------------------------------------------------
-- Planning
----------------------------------------------------------------------
-- a group member is kept by GUID: "party2" can be someone else after the group changes
local function unitFor(t)
    if t.unit and UnitGUID(t.unit) == t.guid then return t.unit end
    local n = GetNumGroupMembers() or 0
    for i = 1, n do
        local u = IsInRaid() and ("raid" .. i) or ("party" .. i)
        if UnitGUID(u) == t.guid then t.unit = u; return u end
    end
    return nil
end

local function targetPos(t)
    if t.unit then
        if not unitFor(t) then return nil end
        local cont, x, y, map = Geo.Unit(t.unit)
        if cont then return { cont = cont, x = x, y = y, map = map } end
        return nil
    end
    local cont, x, y = Geo.ToWorld(t.map, t.x, t.y)
    if cont then return { cont = cont, x = x, y = y, map = t.map } end
end

local function plan()
    active.lastPlan = GetTime()   -- failed tries count too: they wait like any other
    local cont, x, y, map = Geo.Player()
    if not cont then return false, "can't see where you are (instance or loading screen)" end
    active.cont = cont
    local to = targetPos(active.target)
    if not to then return false, "can't see where that is" end
    active.to = to
    local route, why = ns.Router:Plan({ cont = cont, x = x, y = y, map = map }, to)
    active.lastPlan = GetTime()
    active.cont = cont
    if not route then return false, why end
    active.blocked = nil   -- a plan that works ends any earlier "no route" state
    active.route, active.steps, active.idx = route, stepsOf(route), 1
    if #active.steps == 0 then active.steps = { { kind = "walk", cont = to.cont, x = to.x, y = to.y } } end
    setWaypoint(active.steps[1].cont, active.steps[1].x, active.steps[1].y)
    if ns.Draw then ns.Draw:Refresh() end
    return true
end

----------------------------------------------------------------------
-- Status box
----------------------------------------------------------------------
local function remaining(px, py)
    local s = active.steps
    local i = active.idx
    if not s[i] then return 0 end
    local n = Geo.Dist(px, py, s[i].x, s[i].y)
    for k = i + 1, #s do
        if s[k].cont == s[k - 1].cont then n = n + Geo.Dist(s[k - 1].x, s[k - 1].y, s[k].x, s[k].y) end
    end
    return n
end

local function instruction(step, d)
    if not step then return "" end
    if step.kind == "walk" then
        if step.known then
            return ("Follow the path · next turn in %s yd"):format(Geo.Yards(d))
        end
        return ("Head straight there · %s yd (no walked path here yet)"):format(Geo.Yards(d))
    elseif step.kind == "flyFrom" then
        return ("Take the flight to |cffffffff%s|r"):format(step.to.name or "?")
    elseif step.kind == "flyTo" then
        return ("Flying to %s"):format(step.to.name or "?")
    elseif step.kind == "board" then
        return ("Take the |cffffffff%s|r%s"):format(step.name or "boat", step.at and (" (" .. step.at .. ")") or "")
    end
    return ""
end

local function buildBox()
    local A = { 0, 0.78, 1 }
    box = CreateFrame("Frame", "VoidGPSBox", UIParent)
    box:SetSize(320, 70)
    box:SetFrameStrata("MEDIUM")   -- under the world map (the user: the map may cover it, that's fine)
    box:SetClampedToScreen(true)
    box:SetMovable(true)
    box:EnableMouse(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", box.StartMoving)
    box:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        local p, _, rp, x, y = self:GetPoint()
        VoidGPSDB.boxPos = { p, rp, x, y }
        if ns.Hunt then ns.Hunt:Anchor(self) end   -- the Target button follows (after combat if in it)
    end)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.07, 0.9)
    local edge = box:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(2)
    edge:SetColorTexture(A[1], A[2], A[3], 1)
    box.title = box:CreateFontString(nil, "OVERLAY")
    box.title:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    box.title:SetPoint("TOPLEFT", 10, -7)
    box.title:SetPoint("RIGHT", -54, 0)
    box.title:SetJustifyH("LEFT")
    box.title:SetWordWrap(false)
    box.line = box:CreateFontString(nil, "OVERLAY")
    box.line:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    box.line:SetPoint("TOPLEFT", box.title, "BOTTOMLEFT", 0, -5)
    box.line:SetPoint("RIGHT", -8, 0)
    box.line:SetJustifyH("LEFT")
    box.line:SetTextColor(0.85, 0.85, 0.9)
    box.hunt = box:CreateFontString(nil, "OVERLAY")
    box.hunt:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    box.hunt:SetPoint("BOTTOMLEFT", 10, 8)
    box.hunt:SetPoint("RIGHT", -64, 0)
    box.hunt:SetJustifyH("LEFT")
    local stop = CreateFrame("Button", nil, box)
    stop:SetSize(44, 18)
    stop:SetPoint("TOPRIGHT", -6, -5)
    local sbg = stop:CreateTexture(nil, "BACKGROUND")
    sbg:SetAllPoints()
    sbg:SetColorTexture(0.25, 0.08, 0.08, 1)
    local st = stop:CreateFontString(nil, "OVERLAY")
    st:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    st:SetPoint("CENTER")
    st:SetText("Stop")
    stop:SetScript("OnClick", function() Guide:Stop("stopped") end)
    stop:SetScript("OnEnter", function() sbg:SetColorTexture(0.45, 0.12, 0.12, 1) end)
    stop:SetScript("OnLeave", function() sbg:SetColorTexture(0.25, 0.08, 0.08, 1) end)
    box:SetScript("OnMouseUp", function(_, b)
        if b == "LeftButton" and not IsMouseButtonDown("LeftButton") and active and OpenWorldMap then
            local t = active.to
            if t and t.map and not InCombatLockdown() then OpenWorldMap(t.map) end   -- the game won't open it in combat
        end
    end)
    box:Hide()
    local p = VoidGPSDB.boxPos
    if p then box:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else box:SetPoint("TOP", UIParent, "TOP", 0, -90) end   -- top center: clear of the minimap and quest panels
    if ns.Hunt then ns.Hunt:Anchor(box) end
end

local function updateBox(px, py)
    if not box then buildBox() end
    if not active then box:Hide(); return end
    local t = active.target
    box.title:SetText("|cff00c7ffVoidGPS|r  " .. (t.name or "?") .. (t.sub and t.sub ~= "" and (" |cff8c8c9e" .. t.sub .. "|r") or ""))
    local step = active.steps and active.steps[active.idx]
    if active.blocked then
        box.line:SetText("|cffff8800" .. active.blocked .. "|r")
    elseif step and px then
        local d = Geo.Dist(px, py, step.x, step.y)
        box.line:SetText(instruction(step, d) .. ("   |cff8c8c9e%s yd to go|r"):format(Geo.Yards(remaining(px, py))))
    end
    box.hunt:SetText(ns.Hunt and ns.Hunt:Status() or "")
    box:Show()
end

----------------------------------------------------------------------
-- The loop
----------------------------------------------------------------------
local function distToSegment(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l2 = dx * dx + dy * dy
    local t = l2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2)) or 0
    return Geo.Dist(px, py, ax + t * dx, ay + t * dy)
end

local function advance()
    active.idx = active.idx + 1
    local s = active.steps[active.idx]
    if s then setWaypoint(s.cont, s.x, s.y) end
    if ns.Draw then ns.Draw:Refresh() end
end

local function tick()
    if not active then return end
    local cont, px, py = Geo.Player()
    if not cont then
        if box then box.line:SetText("|cff8c8c9eNo position here (instance): the arrow waits.|r") end
        updateBox()
        return
    end
    local now = GetTime()

    -- a moving target (party member): plan again when it moved
    if active.target.unit and now - (active.lastPlan or 0) > 3 then
        local to = targetPos(active.target)
        if to and active.to and Geo.Dist(to.x, to.y, active.to.x, active.to.y) > 25 then plan() end
    end

    if cont ~= active.cont and now - (active.lastPlan or 0) > 2 then
        local ok, why = plan()           -- a new continent: the rest of the way
        active.blocked = not ok and why or nil
        updateBox(px, py)
        return
    end
    if active.blocked then
        if now - active.lastPlan > 10 then
            local ok, why = plan()
            active.blocked = not ok and why or nil
        end
        updateBox(px, py)
        return
    end

    -- a party member: arrival is where they are NOW (not where the route was planned to)
    local to = active.target.unit and targetPos(active.target) or (not active.target.unit and active.to) or nil
    if to and to.cont == cont and Geo.Dist(px, py, to.x, to.y) < REACH_LAST then
        G:Print(("You've arrived at %s."):format(active.target.name or "your destination"))
        Guide:Stop("arrived")
        return
    end

    local step = active.steps[active.idx]
    if not step then Guide:Stop("arrived"); return end
    local d = Geo.Dist(px, py, step.x, step.y)
    if step.kind == "walk" then
        local last = active.idx == #active.steps
        if d < (last and REACH_LAST or REACH) then
            advance()
        elseif step.px and distToSegment(px, py, step.px, step.py, step.x, step.y) > OFF_ROUTE
            and now - active.lastPlan > REPLAN_EVERY then
            plan()                     -- off the route
        end
    elseif step.kind == "flyFrom" then
        if UnitOnTaxi("player") then advance()
        elseif d > 150 and now - active.lastPlan > REPLAN_EVERY then plan() end
    elseif step.kind == "flyTo" then
        if not UnitOnTaxi("player") then
            if d < 80 then advance() elseif now - active.lastPlan > REPLAN_EVERY then plan() end
        end
    elseif step.kind == "board" then
        if d > 400 and now - active.lastPlan > REPLAN_EVERY * 3 then plan() end
    end
    updateBox(px, py)
end

----------------------------------------------------------------------
-- API
----------------------------------------------------------------------
-- target = { name, sub, map, x, y } (x, y 0-1) or { name, unit }
function Guide:Start(target)
    if active then self:Stop() end
    active = { target = target }
    local ok, why = plan()
    if not ok then
        if not active.route then
            active.blocked = why
            G:Print("No route to " .. (target.name or "there") .. ": " .. (why or "?"))
        end
    end
    -- remember it for the search box
    local recent = VoidGPSDB.recent
    -- (a herb or ore is one entry by name: picked again, it goes to the then-nearest spot)
    for i = #recent, 1, -1 do
        if recent[i].name == target.name and (recent[i].map == target.map or (target.node and recent[i].node)) then table.remove(recent, i) end
    end
    if not target.unit then table.insert(recent, 1, { name = target.name, sub = target.sub, map = target.map, x = target.x, y = target.y, npc = target.npc, node = target.node }) end
    while #recent > 8 do table.remove(recent) end
    if not box then buildBox() end
    if ns.Hunt then ns.Hunt:Set(target.npc and target.name or nil) end   -- an NPC: Target button + "is it up?"
    tick()
end

function Guide:Stop(why)
    if not active then return end
    clearWaypoint()
    active = nil
    if ns.Hunt then ns.Hunt:Clear() end
    if box then box:Hide() end
    if ns.Draw then ns.Draw:Refresh() end
end

function Guide:Active() return active end

G:OnReady(function()
    C_Timer.NewTicker(0.25, tick)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("USER_WAYPOINT_UPDATED")
    ev:SetScript("OnEvent", function()
        if not active or active.settingWp or not active.wp then return end
        if not sameWp(C_Map.GetUserWaypoint(), active.wp) then
            active.wp = nil
            G:Print("Route stopped: another waypoint was set.")
            Guide:Stop("replaced")
        end
    end)
end)
