----------------------------------------------------------------------
-- VoidGPS — type a place, an NPC, a service or a party member; get a route
-- that follows walked paths, takes flight paths and zeppelins, and continues
-- through zones.
--
--   Places.lua  WoW Forever NPCs, mailboxes / anvils / forges, zeppelins (generated)
--   Geo.lua     world <-> map coordinates, distances
--   Router.lua  the plan: walked trails (VoidMap), flight paths, boats / zeppelins
--   Guide.lua   the active route: next turn on Blizzard's arrow, status box
--   Draw.lua    the route on the world map and the minimap
--   Search.lua  the search box (in VoidMap's toolbar, or its own window)
--
-- Walking routes need VoidMap's recorded trails (VoidMap.Trails); without them
-- every leg is a straight line.
----------------------------------------------------------------------
local ADDON, ns = ...
VoidGPS = VoidGPS or {}
local G = VoidGPS
ns.G = G

G.FOREVER = (select(4, GetBuildInfo()) or 0) < 100000

function G:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00c7ff[VoidGPS]|r " .. tostring(msg))
end

-- The player's faction letter as NorgannonDB writes it (A / H).
function G:FactionLetter()
    local f = UnitFactionGroup("player")
    return f == "Horde" and "H" or (f == "Alliance" and "A" or "")
end

-- The any-rare alert (Hunt.lua): the "Rares" button next to the search box and /gps rares.
function G:SetRareAlerts(on)
    VoidGPSDB.rareAlerts = on and true or false
    G:Print("Rare alerts " .. (on and "on" or "off") .. ".")
    if ns.Search and ns.Search.PaintRares then ns.Search:PaintRares() end
end

local readyFns = {}
function G:OnReady(fn) readyFns[#readyFns + 1] = fn end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        VoidGPSDB = VoidGPSDB or {}
        VoidGPSDB.recent = VoidGPSDB.recent or {}
    elseif event == "PLAYER_LOGIN" then
        for _, fn in ipairs(readyFns) do
            local ok, err = pcall(fn)
            if not ok then geterrorhandler()(err) end
        end
    end
end)

SLASH_VOIDGPS1 = "/gps"
SLASH_VOIDGPS2 = "/vgps"
SlashCmdList.VOIDGPS = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "stop" then
        if ns.Guide then ns.Guide:Stop("stopped") end
    elseif msg == "rares" then
        G:SetRareAlerts(VoidGPSDB.rareAlerts == false)
    elseif msg == "rarelog" then
        if ns.RareAlert then ns.RareAlert:PrintLog(15) end
    elseif msg == "raretest" then
        -- the popup for your target (or a made-up name), not logged
        local n = UnitExists("target") and UnitName("target")
        if issecretvalue and n and issecretvalue(n) then n = nil end
        if ns.RareAlert then ns.RareAlert:Show(n or "Test Rare", "rare", UnitLevel("target")) end
    elseif msg ~= "" and ns.Search then
        ns.Search:Open(msg)
    elseif ns.Search then
        ns.Search:Open()
    end
end

BINDING_HEADER_VOIDGPS = "VoidGPS"
BINDING_NAME_VOIDGPS_SEARCH = "Search for a place"
BINDING_NAME_VOIDGPS_STOP = "Stop the route"
_G["BINDING_NAME_CLICK VoidGPSTargetButton:LeftButton"] = "Target the NPC you're heading to"
function VoidGPS_BindSearch() if ns.Search then ns.Search:Open() end end
function VoidGPS_BindStop() if ns.Guide then ns.Guide:Stop("stopped") end end

VoidHubLaunchers = VoidHubLaunchers or {}
VoidHubLaunchers.VoidGPS = {
    icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
    onClick = function(button)
        if button == "RightButton" then
            if ns.Guide then ns.Guide:Stop("stopped") end
        elseif ns.Search then
            ns.Search:Open()
        end
    end,
}

-- A switch in the Void hub's quick box (left-click the hub; VoidHubBundle.lua)
VoidHubToggles = VoidHubToggles or {}
table.insert(VoidHubToggles, {
    id = "VoidGPS.rares", group = "GPS", label = "Rare alerts",
    tip = "A sound and a Target button when a rare is near (the Rares button by VoidGPS's search box).",
    get = function() return VoidGPSDB and VoidGPSDB.rareAlerts ~= false end,
    set = function(on) G:SetRareAlerts(on) end,
})
