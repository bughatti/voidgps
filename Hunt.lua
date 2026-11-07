----------------------------------------------------------------------
-- Hunt.lua — is it up? For an NPC you're heading to (a rare that doesn't
-- always spawn, a quest mob):
--   * a Target button (and a key in Key Bindings > AddOns > VoidGPS) that runs
--     /targetexact <name>. The game lets an addon target only from a click or
--     key press, so each press is one try; spam it as you walk in.
--   * it watches nameplates, your target and your mouseover: the moment that
--     NPC shows up you get a sound and "<name> is up!" (or "is dead" if it was
--     just killed).
-- The button is a secure button; it is set up and moved only out of combat.
----------------------------------------------------------------------
local _, ns = ...
local G = ns.G
local H = {}
ns.Hunt = H

local btn
local pendingName        -- set when the name changed in combat

local function apply(name)
    if InCombatLockdown() then pendingName = name or false; return end
    pendingName = nil
    btn:SetAttribute("macrotext", name and ("/targetexact " .. name) or "")
    btn:SetShown(name ~= nil and ns.Guide:Active() ~= nil)
end

function H:Set(name)
    self.name, self.seen, self.dead, self.alerted = name, nil, nil, nil
    apply(name)
end

function H:Clear() self:Set(nil) end

-- "Up! seen 12 s ago" / "Not seen yet"
function H:Status()
    if not self.name then return nil end
    if not self.seen then return "|cff8c8c9eNot seen yet · press Target to check|r" end
    local ago = math.floor(GetTime() - self.seen)
    if self.dead then return ("|cffff5050Dead|r · seen %d s ago"):format(ago) end
    return ("|cff33ff33Up!|r · seen %d s ago"):format(ago)
end

-- The secure button is placed over the status box's corner but NOT attached to it: a
-- protected frame anchored to (or parented by) the box would make the box protected in
-- combat (Sol review). It gets its own spot on UIParent, worked out from the box out
-- of combat, again after the box is dragged, and after combat if it changed meanwhile.
local wantBox
function H:Anchor(box)
    wantBox = box
    if InCombatLockdown() or not btn then return end
    local r, b = box:GetRight(), box:GetBottom()
    if not (r and b) then
        C_Timer.After(0.2, function() H:Anchor(box) end)
        return
    end
    btn:ClearAllPoints()
    btn:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", r - 6, b + 5)
    apply(self.name)
end

-- Any rare, not only the one you're heading to (the user, 2026-11-07, after Rathorian):
-- a sound and "<name> is up!" the first time you see it, then quiet for 5 minutes.
local seenRare = {}
local function anyRare(unit, name)
    if VoidGPSDB and VoidGPSDB.rareAlerts == false then return end
    local cls = UnitClassification(unit)
    if cls ~= "rare" and cls ~= "rareelite" then return end
    if not UnitCanAttack("player", unit) or UnitIsDead(unit) then return end
    if seenRare[name] and GetTime() - seenRare[name] < 300 then return end
    seenRare[name] = GetTime()
    PlaySound(SOUNDKIT.RAID_WARNING)
    local lv = UnitLevel(unit)
    G:Print(("|cff33ff33%s is up!|r (%s%s)"):format(name, cls == "rareelite" and "rare elite" or "rare",
        (lv and lv > 0) and (", level " .. lv) or ""))
    UIErrorsFrame:AddMessage(name .. " is up!", 0.2, 1, 0.2)
end

local function check(unit)
    if not UnitExists(unit) then return end
    local name = UnitName(unit)
    if not name or (issecretvalue and issecretvalue(name)) then return end
    if name ~= H.name then anyRare(unit, name); return end
    local dead = UnitIsDead(unit)
    H.seen, H.dead = GetTime(), dead
    if not H.alerted or GetTime() - H.alerted > 60 then
        H.alerted = GetTime()
        PlaySound(SOUNDKIT.RAID_WARNING)
        if dead then
            G:Print(("|cffff5050%s is dead|r (someone just killed it)."):format(name))
        else
            G:Print(("|cff33ff33%s is up!|r"):format(name))
            UIErrorsFrame:AddMessage(name .. " is up!", 0.2, 1, 0.2)
        end
    end
end

G:OnReady(function()
    btn = CreateFrame("Button", "VoidGPSTargetButton", UIParent, "SecureActionButtonTemplate")
    btn:SetSize(52, 18)
    btn:SetFrameStrata("MEDIUM")   -- with the status box, under the world map
    btn:SetFrameLevel(50)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", "")
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.25, 0.32, 1)
    local t = btn:CreateFontString(nil, "OVERLAY")
    t:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    t:SetPoint("CENTER")
    t:SetText("Target")
    btn:SetScript("OnEnter", function(self)
        bg:SetColorTexture(0.1, 0.4, 0.5, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Target " .. (H.name or "?"), 1, 1, 1)
        GameTooltip:AddLine("Targets it if it's near you. Each press is one try. Set a key in Key Bindings > AddOns > VoidGPS.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() bg:SetColorTexture(0.06, 0.25, 0.32, 1); GameTooltip:Hide() end)
    btn:Hide()

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then check(unit)
        elseif event == "PLAYER_TARGET_CHANGED" then check("target")
        elseif event == "UPDATE_MOUSEOVER_UNIT" then check("mouseover")
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingName ~= nil then apply(pendingName or nil) end
            if wantBox then H:Anchor(wantBox) end
        end
    end)
end)
