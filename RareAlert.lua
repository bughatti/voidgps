----------------------------------------------------------------------
-- RareAlert.lua -- the "rare is up" popup and the rare log.
--
-- The user, 2026-11-08 (Silithid Harvester, The Barrens): a guildmate tagged a rare, he got
-- a hit in, and no alert was noticed. VoidSweep had seen it alive (it tried to share an "up"),
-- so the alert most likely fired as a chat line + a few seconds of center text, easy to miss
-- in a fight, but nothing was saved to prove it either way. Now:
--   * a popup that stays: the rare's name, level, rare / rare elite, a Target button; it
--     says "Killed" when it dies and goes away a few seconds later (or after 5 minutes, or
--     when you close it)
--   * VoidGPSDB.rareLog: the last 60 rares seen (alert shown, alerts off, seen dead, ...),
--     with time, how it was seen and where. /gps rarelog prints the latest.
-- The Target button is a secure button on UIParent (not a child of the popup, or the popup
-- couldn't be closed in combat): its target is set only out of combat. A rare that shows up
-- mid-fight gets its button after the fight; until then the popup says so.
----------------------------------------------------------------------
-- Borders are one screen pixel (tools/cmd/pixelfix, 2026-11-09). WoW snaps each border
-- piece to the pixel grid, and a thin line on a fractional position can snap to 0 px: a side
-- of a box vanishes. VoidPX() asks for one real pixel, and the hook below (installed once, by
-- the first Void addon loaded) turns snapping off on the edges of flat WHITE8X8 borders, like
-- Blizzard's NineSliceUtil.DisableSharpening, so a 1 px line always covers a pixel.
local function VoidPX()
    local s = UIParent and UIParent:GetEffectiveScale()
    if s and s > 0 and PixelUtil and PixelUtil.GetPixelToUIUnitFactor then return PixelUtil.GetPixelToUIUnitFactor() / s end
    return 1
end
if not _G.__VoidBorderHook and hooksecurefunc and NineSliceUtil and NineSliceUtil.ApplyLayout then
    _G.__VoidBorderHook = true
    local EDGES = { "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
                    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }
    hooksecurefunc(NineSliceUtil, "ApplyLayout", function(c)
        local i = type(c) == "table" and c.backdropInfo
        local e = i and i.edgeFile
        if type(e) ~= "string" or not e:lower():find("white8x8", 1, true) or (tonumber(i.edgeSize) or 0) > 3 then return end
        for _, k in ipairs(EDGES) do
            local t = c[k]
            if t and t.SetSnapToPixelGrid then
                t:SetSnapToPixelGrid(false)
                t:SetTexelSnappingBias(0)
            end
        end
    end)
end
local _, ns = ...
local G = ns.G
local R = {}
ns.RareAlert = R

local LOG_MAX   = 60
local LOG_QUIET = 300      -- the same rare + same outcome is logged once per this
local SHOW_FOR  = 300      -- the popup goes away after this if nothing else happens
local DEAD_HIDE = 8        -- after "Killed"

local pop, tb              -- the popup, the secure Target button
local current              -- name the popup is about
local pendingTarget        -- name to put on the button after combat
local hideTbLater          -- the button should hide after combat
local loggedAt = {}        -- name .. why -> GetTime()
local gen = 0              -- bumped per popup shown: timers close only their own

local function where()
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if not (ok and pos) then return map end
    local x, y = pos:GetXY()
    if not x or (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then return map end
    return map, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
end

-- how: "target" / "mouseover" / "nameplate"; why: "alert", "off" (alerts turned off),
-- "dead" (first seen dead), "killed" (died while the popup was up), "hunt" (the NPC you're
-- heading to: the route's own alert)
function R:Log(name, cls, how, why, level)
    if type(name) ~= "string" then return end
    local key = name .. why
    if why ~= "alert" and loggedAt[key] and GetTime() - loggedAt[key] < LOG_QUIET then return end
    loggedAt[key] = GetTime()
    VoidGPSDB = VoidGPSDB or {}
    local log = VoidGPSDB.rareLog or {}
    VoidGPSDB.rareLog = log
    local map, x, y = where()
    log[#log + 1] = { t = time(), name = name, cls = cls, how = how, why = why, level = level,
        map = map, x = x, y = y, combat = InCombatLockdown() or nil }
    while #log > LOG_MAX do table.remove(log, 1) end
end

-- While shown, a state driver hides the button for the whole of any fight: an addon can't
-- change or hide a secure button in combat, so without it the button would keep targeting
-- the rare it was set for (even after the popup closed, or moved on to another rare).
-- Changes happen only out of combat; anything asked for in combat waits for the fight to end.
-- The button sits over the popup's bottom-right corner. It is anchored to UIParent, not to the
-- popup (a secure frame anchored to the popup would make the popup protected, so it couldn't be
-- dragged in a fight); so after the popup moves, it's lined up again out of combat.
local function alignButton()
    if not (tb and tb.ready and pop) or InCombatLockdown() then return end
    local r, b = pop:GetRight(), pop:GetBottom()
    if not (r and b) then return end
    local k = pop:GetEffectiveScale() / UIParent:GetEffectiveScale()
    tb:ClearAllPoints()
    tb:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", r * k - 10, b * k + 8)
end

local function placeButton(name)
    if InCombatLockdown() or not (tb and tb.ready) then pendingTarget = name; return false end
    alignButton()
    pendingTarget, hideTbLater = nil, nil
    tb:SetAttribute("macrotext", "/targetexact " .. name)
    RegisterStateDriver(tb, "visibility", "[combat] hide; show")
    if pop and current == name then pop.note:SetText("Target it, or close with x") end
    return true
end

local function hideButton()
    pendingTarget = nil
    if not (tb and tb.ready) then return end
    if InCombatLockdown() then
        hideTbLater = true   -- already hidden by the driver for this fight
    else
        UnregisterStateDriver(tb, "visibility")
        tb:Hide()
        hideTbLater = nil
    end
end

function R:Hide()
    if pop then pop:Hide() end
    current = nil
    hideButton()
end

local function build()
    pop = CreateFrame("Frame", "VoidGPSRarePopup", UIParent, "BackdropTemplate")
    pop:SetSize(280, 74)
    pop:SetPoint("TOP", UIParent, "TOP", 0, -150)
    pop:SetFrameStrata("HIGH")
    -- drag to move, kept after a restart (the user, 11-12: every pop-up box movable)
    ns.Move(pop, { db = function() return VoidGPSDB end, key = "rarePopup", onMoved = function() alignButton() end })
    pop:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = VoidPX() })
    pop:SetBackdropColor(0.03, 0.08, 0.11, 0.94)
    pop:SetBackdropBorderColor(0.2, 1, 0.4, 0.9)
    pop:Hide()

    pop.title = pop:CreateFontString(nil, "OVERLAY")
    pop.title:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    pop.title:SetPoint("TOPLEFT", 10, -8)
    pop.title:SetTextColor(0.2, 1, 0.4)

    pop.name = pop:CreateFontString(nil, "OVERLAY")
    pop.name:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    pop.name:SetPoint("TOPLEFT", 10, -24)
    pop.name:SetPoint("RIGHT", -28, 0)
    pop.name:SetJustifyH("LEFT")

    pop.note = pop:CreateFontString(nil, "OVERLAY")
    pop.note:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    pop.note:SetPoint("BOTTOMLEFT", 10, 9)
    pop.note:SetPoint("RIGHT", pop, "RIGHT", -92, 0)
    pop.note:SetJustifyH("LEFT")
    pop.note:SetTextColor(0.6, 0.6, 0.65)

    local close = CreateFrame("Button", nil, pop)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -4, -4)
    local x = close:CreateFontString(nil, "OVERLAY")
    x:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    x:SetPoint("CENTER")
    x:SetText("x")
    x:SetTextColor(0.8, 0.4, 0.4)
    close:SetScript("OnClick", function() R:Hide() end)

    -- the Target button: secure, on UIParent, over the popup's bottom-right corner (alignButton;
    -- nothing protected is anchored to the popup); created and set up out of combat only (a
    -- /reload mid-fight: after the fight)
    local function secureSetup()
        tb = CreateFrame("Button", "VoidGPSRareTargetButton", UIParent, "SecureActionButtonTemplate")
        tb:SetSize(76, 22)
        tb:SetPoint("TOP", UIParent, "TOP", 140 - 10 - 38, -150 - 74 + 8 + 22)
        tb:SetFrameStrata("DIALOG")
        tb:RegisterForClicks("AnyUp", "AnyDown")
        tb:SetAttribute("type", "macro")
        tb:SetAttribute("macrotext", "")
        tb:Hide()
        local bg = tb:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.06, 0.25, 0.32, 1)
        local t = tb:CreateFontString(nil, "OVERLAY")
        t:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        t:SetPoint("CENTER")
        t:SetText("Target")
        tb:SetScript("OnEnter", function() bg:SetColorTexture(0.1, 0.4, 0.5, 1) end)
        tb:SetScript("OnLeave", function() bg:SetColorTexture(0.06, 0.25, 0.32, 1) end)
        tb.ready = true
        if pendingTarget and current then placeButton(pendingTarget) end
    end
    if InCombatLockdown() then R.setupLater = secureSetup else secureSetup() end
end

-- A rare that's up (Hunt.lua calls this once per rare per 5 minutes).
function R:Show(name, cls, level)
    if not pop then return end
    current = name
    pop.title:SetText(cls == "rareelite" and "RARE ELITE IS UP" or "RARE IS UP")
    pop.name:SetText(name .. ((level and level > 0) and ("  |cffaaaaaa" .. level .. "|r") or ""))
    pop:SetBackdropBorderColor(0.2, 1, 0.4, 0.9)
    pop:Show()
    if placeButton(name) then
        pop.note:SetText("Target it, or close with x")
    else
        pop.note:SetText("In combat: Target button after the fight")
    end
    gen = gen + 1
    local mine = gen   -- this popup (a later one for the same rare isn't closed by this timer)
    C_Timer.After(SHOW_FOR, function() if gen == mine then R:Hide() end end)
end

-- The rare is dead: log it (first sight dead, or killed while the popup was up) and
-- close the popup shortly after.
function R:Dead(name, cls, how)
    if current == name and pop and pop:IsShown() then
        R:Log(name, cls, how, "killed")
        pop.title:SetText("KILLED")
        pop:SetBackdropBorderColor(1, 0.3, 0.3, 0.9)
        pop.note:SetText("")
        hideButton()
        local mine = gen
        C_Timer.After(DEAD_HIDE, function() if gen == mine then R:Hide() end end)
    else
        R:Log(name, cls, how, "dead")
    end
end

-- /gps rarelog: the latest entries
function R:PrintLog(n)
    local log = VoidGPSDB and VoidGPSDB.rareLog or {}
    if #log == 0 then G:Print("No rares logged yet."); return end
    G:Print(("Last %d of %d rares seen:"):format(math.min(n, #log), #log))
    for i = math.max(1, #log - n + 1), #log do
        local e = log[i]
        local zone = e.map and C_Map.GetMapInfo(e.map)
        print(("  %s  %s (%s) - %s, by %s%s%s"):format(date("%m-%d %H:%M", e.t), e.name or "?",
            e.cls == "rareelite" and "rare elite" or "rare", e.why or "?", e.how or "?",
            zone and (", " .. zone.name) or "", e.x and (" " .. e.x .. " " .. e.y) or ""))
    end
end

G:OnReady(function()
    build()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("UNIT_HEALTH")
    ev:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_ENABLED" then
            if R.setupLater then local f = R.setupLater; R.setupLater = nil; f() end
            alignButton()   -- the popup may have been dragged during the fight
            -- (the state driver would show the button again now the fight is over)
            local want = pendingTarget   -- a rare that showed up mid-fight (hideButton clears it)
            if hideTbLater then hideButton() end
            if want and current == want and placeButton(want) then
                pop.note:SetText("Target it, or close with x")
            end
        elseif current and unit and UnitIsDead(unit) then
            local n = UnitName(unit)
            if n and not (issecretvalue and issecretvalue(n)) and n == current then
                R:Dead(n, UnitClassification(unit), unit:match("^nameplate") and "nameplate" or unit)
            end
        end
    end)
end)
