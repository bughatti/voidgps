----------------------------------------------------------------------
-- Search.lua — type a name, a service, a zone, coordinates or a group member.
--
--   "wulan", "trigore"         an NPC or a rare by name
--   "cooking trainer", "bank"  a service: the nearest ones first
--   "flight", "mailbox"        flight masters, mailboxes, anvils, forges
--   "desolace", "orgrimmar"    a zone or city
--   "26 69", "desolace 26 69"  coordinates (on the map you're on / that zone)
--   a party member's name      live route to them
--   a friend's name            their zone (the game tells addons no more)
-- Empty box: your recent places. Up / Down / Enter / Esc work.
--
-- The box sits in VoidMap's toolbar when VoidMap is installed; otherwise (or
-- when the map is closed) /gps, the key binding or the Void hub icon opens a
-- small search window.
----------------------------------------------------------------------
local _, ns = ...
local G = ns.G
local Geo = ns.Geo
local S = {}
ns.Search = S

local A = { 0, 0.78, 1 }
local FONT = "Fonts\\FRIZQT__.TTF"
local MAX = 8

local FLIGHT = { "wind rider master", "gryphon master", "hippogryph master", "bat handler", "flight master" }
local SYN = {
    flight = FLIGHT, fp = FLIGHT, ["flight master"] = FLIGHT, ["flight path"] = FLIGHT, flightmaster = FLIGHT,
    bank = { "banker" }, banker = { "banker" },
    inn = { "innkeeper" }, innkeeper = { "innkeeper" }, hearth = { "innkeeper" },
    mail = { "mailbox" }, mailbox = { "mailbox" },
    zeppelin = { "zeppelin master" }, zep = { "zeppelin master" },
    stable = { "stable master" },
    anvil = { "anvil" }, forge = { "forge" },
    food = { "food & drink", "innkeeper" }, drink = { "food & drink", "innkeeper" },
    rare = { "rare" },
    herb = { "herb" }, herbs = { "herb" }, herbalism = { "herb" },
    ore = { "ore" }, mining = { "ore" }, vein = { "ore" },
}

----------------------------------------------------------------------
-- Index
----------------------------------------------------------------------
local index

local function buildIndex()
    index = {}
    local fac = G:FactionLetter()
    for _, n in ipairs(ns.NPCS or {}) do
        local f = n[6]
        if f == "R" or (fac ~= "" and f:find(fac, 1, true)) then
            local rare = f == "R"
            index[#index + 1] = {
                kind = rare and "rare" or "npc", name = n[1], sub = rare and ((n[2] ~= "" and (n[2] .. " · ") or "") .. "Rare") or n[2],
                map = n[3], x = n[4] / 10000, y = n[5] / 10000, npc = true,
                lname = n[1]:lower(), lsub = rare and "rare" or n[2]:lower(),
            }
        end
    end
    for _, o in ipairs(ns.OBJECTS or {}) do
        index[#index + 1] = { kind = "obj", name = o[1], sub = "", map = o[2], x = o[3] / 10000, y = o[4] / 10000,
            lname = o[1]:lower(), lsub = o[1]:lower() }
    end
    -- herbs and ore (Nodes.lua): one entry per name, routed to the nearest spot
    for name, d in pairs(ns.NODES or {}) do
        local k = ns.Nodes and ns.Nodes.KIND[d[1]] or "Node"
        index[#index + 1] = { kind = "node", name = name, sub = k .. " · nearest spot",
            lname = name:lower(), lsub = k:lower() }
    end
    local seen = {}
    for _, root in ipairs({ 946, 947 }) do
        for _, z in ipairs(C_Map.GetMapChildrenInfo(root, Enum.UIMapType.Zone, true) or {}) do
            if not seen[z.mapID] then
                seen[z.mapID] = true
                local parent = C_Map.GetMapInfo(z.parentMapID)
                index[#index + 1] = { kind = "zone", name = z.name, sub = "Zone" .. (parent and (" · " .. parent.name) or ""),
                    map = z.mapID, x = 0.5, y = 0.5, lname = z.name:lower(), lsub = "zone" }
            end
        end
    end
end

local function zoneByName(q)
    if not index then buildIndex() end
    local best
    for _, e in ipairs(index) do
        if e.kind == "zone" then
            if e.lname == q then return e end
            if not best and e.lname:sub(1, #q) == q then best = e end
        end
    end
    return best
end

local function score(e, q, syn)
    local n, s = e.lname, e.lsub
    if n == q then return 1000 end
    if n:sub(1, #q) == q then return 800 end
    if syn then
        for _, t in ipairs(syn) do if s == t or s:find(t, 1, true) then return 650 end end
    end
    if (" " .. n):find(" " .. q, 1, true) then return 600 end
    if s ~= "" and s:find(q, 1, true) then return 550 end
    if n:find(q, 1, true) then return 400 end
    return 0
end

-- -> list of results { name, sub, map, x, y, kind, npc, unit, dist }
function S:Find(q)
    q = (q or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local out = {}
    if q == "" then
        for _, r in ipairs(VoidGPSDB.recent or {}) do
            -- the shown " · recent" must not be saved back when you pick it again (it piled
            -- up: "Rare · recent · recent · recent"); strip it from older saves too
            local base = (r.sub or ""):gsub("%s*·%s*recent", ""):gsub("^recent$", "")
            out[#out + 1] = { name = r.name, sub = (base ~= "" and (base .. " · ") or "") .. "recent", baseSub = base,
                map = r.map, x = r.x, y = r.y, npc = r.npc, kind = r.node and "node" or nil }
        end
        return out
    end

    -- coordinates: "26 69" / "26.2, 69.7" / "desolace 26 69"
    local zq, cx, cy = q:match("^(.-)%s*(%d+%.?%d*)[%s,]+(%d+%.?%d*)$")
    if cx then
        cx, cy = tonumber(cx), tonumber(cy)
        local map
        if zq and zq ~= "" then
            local z = zoneByName(zq)
            map = z and z.map
        else
            map = (WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID()) or C_Map.GetBestMapForUnit("player")
        end
        if map and cx <= 100 and cy <= 100 then
            out[#out + 1] = { name = ("%s %.1f, %.1f"):format(Geo.MapName(map), cx, cy), sub = "Coordinates", map = map, x = cx / 100, y = cy / 100, kind = "coords" }
            return out
        end
    end

    -- group members (live) and friends (their zone)
    local n = GetNumGroupMembers() or 0
    for i = 1, n do
        local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)
        local name = UnitName(unit)
        if name and not (issecretvalue and issecretvalue(name)) and name:lower():find(q, 1, true) then
            out[#out + 1] = { name = name, sub = "In your group · live", unit = unit, guid = UnitGUID(unit), kind = "unit" }
        end
    end
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, C_FriendList.GetNumFriends() or 0 do
            local f = C_FriendList.GetFriendInfoByIndex(i)
            if f and f.connected and f.name and f.name:lower():find(q, 1, true) and f.area then
                local z = zoneByName(f.area:lower())
                if z then out[#out + 1] = { name = f.name, sub = "Friend · in " .. f.area, map = z.map, x = 0.5, y = 0.5, kind = "friend" } end
            end
        end
    end

    if not index then buildIndex() end
    local syn = SYN[q]
    local hits = {}
    for _, e in ipairs(index) do
        local sc = score(e, q, syn)
        if sc > 0 then hits[#hits + 1] = { e = e, s = sc } end
    end
    -- distance for ranking: the nearest of a kind first (a service), exact names first
    local cont, px, py = Geo.Player()
    table.sort(hits, function(a, b) return a.s > b.s end)
    -- distances for every hit scoring at least the MAX-th one (all its ties: e.g. every
    -- mailbox), so the nearest of a kind is never cut off; capped for one-letter queries
    local cutoff = hits[math.min(#hits, MAX)] and hits[math.min(#hits, MAX)].s or 0
    local keep = 0
    for i = 1, #hits do
        if hits[i].s < cutoff or i > 3000 then break end
        keep = i
        local e = hits[i].e
        if e.kind == "node" then
            local _, _, _, _, yd = ns.Nodes:Nearest({ e.name })
            hits[i].d = yd or 1e7
        else
            local c, x, y = Geo.ToWorld(e.map, e.x, e.y)
            hits[i].d = (c and c == cont) and Geo.Dist(px, py, x, y) or (c and 1e7 or 2e7)
        end
    end
    for i = #hits, keep + 1, -1 do hits[i] = nil end
    table.sort(hits, function(a, b)
        if a.s ~= b.s then return a.s > b.s end
        return (a.d or 3e7) < (b.d or 3e7)
    end)
    local seen = {}
    for _, h in ipairs(hits) do
        if #out >= MAX then break end
        local e = h.e
        local k = e.name .. "|" .. (e.map or 0) .. "|" .. math.floor((e.x or 0) * 100) .. "|" .. math.floor((e.y or 0) * 100)
        if not seen[k] then
            seen[k] = true
            out[#out + 1] = { name = e.name, sub = e.sub, map = e.map, x = e.x, y = e.y, kind = e.kind, npc = e.npc,
                dist = h.d and h.d < 1e7 and h.d or nil }
        end
    end
    return out
end

----------------------------------------------------------------------
-- The widget: an edit box with a result list under it
----------------------------------------------------------------------
local widgets = {}

local function go(r)
    if not r then return end
    if r.kind == "node" and ns.Nodes then
        if not ns.Nodes:Go({ r.name }) then G:Print("No spots known for " .. r.name .. ".") end
        return
    end
    if r.unit then
        ns.Guide:Start({ name = r.name, unit = r.unit, guid = r.guid, sub = "group member" })
    else
        ns.Guide:Start({ name = r.name, sub = r.baseSub or r.sub, map = r.map, x = r.x, y = r.y, npc = r.npc })
        if WorldMapFrame and WorldMapFrame:IsShown() and r.map then WorldMapFrame:SetMapID(r.map) end
    end
end

local function makeWidget(parent, width, listParent)
    local w = {}
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(width, 20)
    eb:SetAutoFocus(false)
    eb:SetFont(FONT, 11, "")
    eb:SetTextInsets(20, 6, 0, 0)
    eb:SetMaxLetters(60)
    local bg = eb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.12, 0.15, 1)
    local edge = eb:CreateTexture(nil, "BORDER")
    edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
    edge:SetColorTexture(A[1], A[2], A[3], 0.7)
    local icon = eb:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    icon:SetSize(12, 12)
    icon:SetPoint("LEFT", 5, 0)
    icon:SetVertexColor(0.6, 0.9, 1)
    local hint = eb:CreateFontString(nil, "OVERLAY")
    hint:SetFont(FONT, 10, "")
    hint:SetPoint("LEFT", 20, 0)
    hint:SetTextColor(0.5, 0.5, 0.56)
    hint:SetText("GPS: where to? (name, service, zone)")
    w.eb = eb

    -- "Rares" toggle: the any-rare alert (Hunt.lua) on or off. The host anchors it.
    local rb = CreateFrame("Button", nil, parent)
    rb:SetSize(46, 20)
    local rbg = rb:CreateTexture(nil, "BACKGROUND")
    rbg:SetAllPoints()
    local rt = rb:CreateFontString(nil, "OVERLAY")
    rt:SetFont(FONT, 10, "")
    rt:SetPoint("CENTER")
    rt:SetText("Rares")
    w.rb = rb
    function w:PaintRares(hover)
        local on = not (VoidGPSDB and VoidGPSDB.rareAlerts == false)
        local k = hover and 0.5 or 0.35
        if on then rbg:SetColorTexture(A[1] * k, A[2] * k, A[3] * k, 1)
        else rbg:SetColorTexture(hover and 0.16 or 0.10, hover and 0.18 or 0.12, hover and 0.22 or 0.15, 1) end
        rt:SetTextColor(on and 1 or 0.55, on and 1 or 0.55, on and 1 or 0.6)
    end
    local function rareTip(self)
        local on = not (VoidGPSDB and VoidGPSDB.rareAlerts == false)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Rare alerts: " .. (on and "|cff33ff33on|r" or "|cffff5050off|r"), 1, 1, 1)
        GameTooltip:AddLine("A sound and \"<name> is up!\" when any rare shows on a nameplate, your target or your mouseover. Click to turn it " .. (on and "off." or "on."), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end
    rb:SetScript("OnEnter", function(self) w:PaintRares(true); rareTip(self) end)
    rb:SetScript("OnLeave", function() w:PaintRares(false); GameTooltip:Hide() end)
    rb:SetScript("OnClick", function(self)
        G:SetRareAlerts(VoidGPSDB.rareAlerts == false)
        if GameTooltip:IsOwned(self) then rareTip(self) end
    end)
    w:PaintRares(false)

    local list = CreateFrame("Frame", nil, listParent or parent)
    list:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", 0, -2)
    list:SetWidth(math.max(width, 300))
    list:SetFrameStrata("DIALOG")
    local lbg = list:CreateTexture(nil, "BACKGROUND")
    lbg:SetAllPoints()
    lbg:SetColorTexture(0.05, 0.05, 0.07, 0.97)
    local ledge = list:CreateTexture(nil, "BORDER")
    ledge:SetPoint("TOPLEFT"); ledge:SetPoint("BOTTOMLEFT"); ledge:SetWidth(2)
    ledge:SetColorTexture(A[1], A[2], A[3], 1)
    list:Hide()
    w.list, w.rows, w.results, w.sel = list, {}, {}, 1

    local function row(i)
        local r = w.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, list)
        r:SetHeight(32)
        r:SetPoint("TOPLEFT", 2, -(i - 1) * 32)
        r:SetPoint("RIGHT")
        r.hl = r:CreateTexture(nil, "BACKGROUND")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(A[1], A[2], A[3], 0.18)
        r.name = r:CreateFontString(nil, "OVERLAY")
        r.name:SetFont(FONT, 11, "")
        r.name:SetPoint("TOPLEFT", 8, -4)
        r.name:SetPoint("RIGHT", -8, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.sub = r:CreateFontString(nil, "OVERLAY")
        r.sub:SetFont(FONT, 9, "")
        r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
        r.sub:SetPoint("RIGHT", -8, 0)
        r.sub:SetJustifyH("LEFT")
        r.sub:SetWordWrap(false)
        r.sub:SetTextColor(0.6, 0.6, 0.66)
        r:SetScript("OnEnter", function() w.sel = i; w:Paint() end)
        r:SetScript("OnClick", function() w:Choose(i) end)
        w.rows[i] = r
        return r
    end

    function w:Paint()
        for i, r in ipairs(self.rows) do r.hl:SetShown(i == self.sel and self.results[i] ~= nil) end
    end

    function w:Update()
        local res = S:Find(eb:GetText())
        self.results = res
        self.sel = 1
        for i = 1, MAX do
            local r, e = row(i), res[i]
            if e then
                local where = e.map and Geo.MapName(e.map) or nil
                local bits = {}
                if e.sub and e.sub ~= "" then bits[#bits + 1] = e.sub end
                if where and e.kind ~= "zone" and e.kind ~= "coords" then bits[#bits + 1] = where end
                if e.dist then bits[#bits + 1] = Geo.Yards(e.dist) .. " yd" end
                r.name:SetText(e.kind == "rare" and ("|cffff6060" .. e.name .. "|r") or e.name)
                r.sub:SetText(table.concat(bits, " · "))
                r:Show()
            else
                r:Hide()
            end
        end
        list:SetHeight(math.max(1, #res) * 32 + 4)
        list:SetShown(#res > 0 and eb:HasFocus())
        self:Paint()
    end

    function w:Choose(i)
        local e = self.results[i]
        eb:ClearFocus()
        list:Hide()
        go(e)
        if self.onChosen then self.onChosen() end
    end

    eb:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        w:Update()
    end)
    eb:SetScript("OnEditFocusGained", function() w:Update() end)
    eb:SetScript("OnEditFocusLost", function() C_Timer.After(0.2, function() if not eb:HasFocus() then list:Hide() end end) end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); list:Hide(); if w.onEscape then w.onEscape() end end)
    eb:SetScript("OnEnterPressed", function() w:Choose(w.sel) end)
    eb:SetScript("OnArrowPressed", function(_, key)
        if key == "DOWN" then w.sel = math.min(#w.results, w.sel + 1)
        elseif key == "UP" then w.sel = math.max(1, w.sel - 1) end
        w:Paint()
    end)
    eb:SetScript("OnTabPressed", function() w.sel = (w.sel % math.max(1, #w.results)) + 1; w:Paint() end)
    widgets[#widgets + 1] = w
    return w
end

----------------------------------------------------------------------
-- Hosts: VoidMap's toolbar, and a small window of its own
----------------------------------------------------------------------
local inMap, window

local function buildWindow()
    window = CreateFrame("Frame", "VoidGPSSearchWindow", UIParent)
    window:SetSize(392, 34)
    window:SetPoint("TOP", UIParent, "TOP", 0, -120)
    window:SetFrameStrata("DIALOG")
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    local bg = window:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.07, 0.95)
    local t = window:CreateFontString(nil, "OVERLAY")
    t:SetFont(FONT, 11, "OUTLINE")
    t:SetPoint("LEFT", 8, 0)
    t:SetText("|cff00c7ffVoidGPS|r")
    local w = makeWidget(window, 260, window)
    w.eb:SetPoint("RIGHT", window, "RIGHT", -7, 0)
    w.rb:SetPoint("RIGHT", w.eb, "LEFT", -4, 0)
    w.onChosen = function() window:Hide() end
    w.onEscape = function() window:Hide() end
    window.w = w
    window:Hide()
end

function S:Open(text)
    if inMap and WorldMapFrame and WorldMapFrame:IsShown() then
        inMap.eb:SetFocus()
        if text then inMap.eb:SetText(text) end
        return
    end
    if not window then buildWindow() end
    window:Show()
    window.w.eb:SetText(text or "")
    window.w.eb:SetFocus()
end

local function hostInVoidMap()
    local M = VoidMap
    if inMap or not (M and M.toolbar) then return end
    inMap = makeWidget(M.toolbar, 230, WorldMapFrame)
    inMap.rb:SetPoint("RIGHT", M.toolbarRight or M.toolbar, "LEFT", -10, 0)
    inMap.eb:SetPoint("RIGHT", inMap.rb, "LEFT", -4, 0)
    inMap.eb:SetFrameLevel(M.toolbar:GetFrameLevel() + 6)
    inMap.rb:SetFrameLevel(M.toolbar:GetFrameLevel() + 6)
end

function S:PaintRares()
    for _, w in ipairs(widgets) do w:PaintRares(false) end
end

G:OnReady(function()
    hostInVoidMap()
    if not inMap then C_Timer.After(1, hostInVoidMap) end
    if WorldMapFrame then WorldMapFrame:HookScript("OnShow", hostInVoidMap) end
end)
