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
G.SearchModule = S   -- (for /run timing checks: debugprofilestop around VoidGPS.SearchModule:Find(q))

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

-- what people call a vendor item -> its real name (the user, 2026-11-10: "mining pick or pick axe
-- doesnt show anything")
local ITEM_ALIAS = {
    ["pick axe"] = "mining pick", pickaxe = "mining pick", ["pick-axe"] = "mining pick", pick = "mining pick",
    ["fishing rod"] = "fishing pole", rod = "fishing pole", pole = "fishing pole",
    flint = "flint and tinder", tinder = "flint and tinder", ["flint & tinder"] = "flint and tinder",
    ["skinning knife"] = "skinning knife", knife = "skinning knife",
    hammer = "blacksmith hammer", ["smith hammer"] = "blacksmith hammer",
    vial = "empty vial", vials = "empty vial", thread = "coarse thread",
}

----------------------------------------------------------------------
-- Index
----------------------------------------------------------------------
local index
local goods   -- vendor items your faction can buy: { item, name, lname } (Recipes.lua's Goods)
local quests  -- quest names (VoidQuest's data): searched from 3 letters on, so short queries stay fast

local function buildIndex()
    index = {}
    goods = {}
    quests = {}
    if ns.Goods then
        for _, e in ipairs(ns.Goods:All() or {}) do
            if e.name and #e.vendors > 0 then goods[#goods + 1] = { item = e.item, name = e.name, lname = e.name:lower(), lsub = "" } end
        end
    end
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
    -- quest rewards (Rewards.lua, WoW Forever): an item routes to the giver of the quest that gives
    -- it (the user, 2026-11-13: "Sword of Omen is a sword from sm and i cant find it")
    for _, r in ipairs(ns.QREWARDS or {}) do
        local side = r[6]
        if side == "" or fac == "" or side == fac then
            local sub = "Quest reward · " .. r[3] .. (r[5] > 0 and (" (" .. r[5] .. "+)") or "")
                .. (r[11] == 1 and " · pick one" or "") .. " · from " .. r[7]
            index[#index + 1] = { kind = "reward", name = r[1], sub = sub, map = r[8], x = r[9] / 10000, y = r[10] / 10000,
                npc = true, item = r[2], giver = r[7], quest = r[3], lname = r[1]:lower(), lsub = "quest reward" }
        end
    end
    -- quests by name (WoW Forever, with VoidQuest's data). Where it sends you depends on where you are
    -- with the quest (the user, 2026-11-18: "if i dont have a quest and i look it up, it make sense to send
    -- me to the quest giver, not where the quest is"): questTarget() below, worked out when you search.
    local vq = rawget(_G, "VoidQuest")
    if vq and vq.ForeverQuests then
        local side = vq.ForeverFaction or {}
        for qid, r in pairs(vq.ForeverQuests) do
            local title = type(r) == "table" and r[1]
            local f = side[qid]
            if type(title) == "string" and title ~= "" and f ~= "X" and (not f or fac == "" or f == fac) then
                quests[#quests + 1] = { kind = "quest", qid = qid, name = title, sub = "Quest",
                    lname = title:lower(), lsub = "quest" }
            end
        end
        -- One name, several quests (the user, 2026-11-19: "i am on the second part of Broken Alliances and
        -- voidgps doesnt seem to be able to find it, its only looking for the first part ... there are lots of
        -- quests like this": 838 Forever titles are shared). Each part is its own result, numbered when the
        -- chain proves the order (VoidQuest's ForeverRules: a part's earlier quests, py), and ranked by where
        -- you are with it (Find: in your log first, done last).
        local byName = {}
        for _, e in ipairs(quests) do
            byName[e.lname] = byName[e.lname] or {}
            table.insert(byName[e.lname], e)
        end
        local rules = vq.ForeverRules or {}
        for _, group in pairs(byName) do
            if #group > 1 then
                local inGroup = {}
                for _, e in ipairs(group) do inGroup[e.qid] = true; e.shared = true end
                -- how many same-named quests come before this one in its chain (walks earlier quests)
                -- (Sol 2026-11-20: a visit-once `seen` cut a branch short -- Q4 needing Q2 and Q3 counted 2, not 3;
                -- now the loop guard covers only the path being walked, and each answer is kept)
                local memo, onPath = {}, {}
                local function depth(q)
                    if memo[q] then return memo[q] end
                    if onPath[q] then return 0 end   -- a loop in the data
                    onPath[q] = true
                    local best = 0
                    for _, p in ipairs((rules[q] and rules[q].py) or {}) do
                        local d = depth(p) + (inGroup[p] and 1 or 0)
                        if d > best then best = d end
                    end
                    onPath[q] = nil
                    memo[q] = best
                    return best
                end
                local chained = false
                for _, e in ipairs(group) do
                    e.depth = depth(e.qid)
                    if e.depth > 0 then chained = true end
                end
                if chained then
                    table.sort(group, function(a, b)
                        if a.depth ~= b.depth then return a.depth < b.depth end
                        return a.qid < b.qid
                    end)
                    -- parts only when every quest sits on one line (no two at the same step)
                    local line = true
                    for i = 2, #group do
                        if group[i].depth == group[i - 1].depth then line = false end
                    end
                    if line then
                        for i, e in ipairs(group) do
                            e.name = ("%s (part %d of %d)"):format(e.name, i, #group)
                        end
                    end
                end
            end
        end
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
    -- word-start forms, made once (score() used to build them per entry per keystroke)
    for _, list in ipairs({ index, goods, quests }) do
        for _, e in ipairs(list) do e.wn, e.ws = " " .. e.lname, " " .. (e.lsub or "") end
    end
end

----------------------------------------------------------------------
-- Quests: where a quest sends you right now (VoidQuest's data, WoW Forever)
--   not taken      -> its giver            done            -> nowhere ("done")
--   in your log    -> the nearest spot of what it needs (kill / use / loot targets first, droppers next)
--   ready          -> the turn-in NPC      (a step we have no spot for falls back to the giver)
----------------------------------------------------------------------
local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if ok then return r end
end

-- a key's spots as world points, decoded once (Sol: not on every keystroke)
local ptCache = {}
local function pointsOf(vq, key)
    local pts = ptCache[key]
    if pts then return pts end
    pts = {}
    for map, s in pairs(vq.ForeverSpawns and vq.ForeverSpawns[key] or {}) do
        for i = 1, #s - 5, 6 do
            local x, y = tonumber(s:sub(i, i + 2)), tonumber(s:sub(i + 3, i + 5))
            if x and y then
                x, y = x / 1000, y / 1000
                local c, wx, wy = Geo.ToWorld(map, x, y)
                pts[#pts + 1] = { map = map, x = x, y = y, c = c, wx = wx, wy = wy }
            end
        end
    end
    ptCache[key] = pts
    return pts
end

-- an objective you've already finished, by its name in the quest log ("Vale Screecher slain: 3/3")
local function finishedFor(qid)
    local done = {}
    local objs = safeCall(C_QuestLog and C_QuestLog.GetQuestObjectives, qid)
    for _, o in ipairs(type(objs) == "table" and objs or {}) do
        if o.finished and type(o.text) == "string" and not (issecretvalue and issecretvalue(o.text)) then
            done[#done + 1] = o.text:lower()
        end
    end
    return done
end

local function nearestObjective(vq, qid)
    local refs = vq.ForeverMobs and vq.ForeverMobs[qid]
    if not refs then return nil end
    local cont, px, py = Geo.Player()
    local done = finishedFor(qid)
    local function finished(name)
        if not name then return false end
        local l = name:lower()
        for _, t in ipairs(done) do if t:find(l, 1, true) then return true end end
        return false
    end
    for pass = 1, 2 do   -- 1: what the quest itself names; 2: mobs that drop what it needs
        local best, bestD
        for _, ref in ipairs(refs) do
            local kind, key = ref[1], ref[2]
            local dropper = kind == "d" or kind == "r"
            local name = vq.ForeverMobNames and vq.ForeverMobNames[key] or nil
            if (pass == 1) ~= dropper and not finished(name) then
                for _, p in ipairs(pointsOf(vq, key)) do
                    -- this continent first by distance; another continent after any here
                    local d = (p.c and cont and p.c == cont and px) and Geo.Dist(px, py, p.wx, p.wy) or (p.c and 1e7 or 2e7)
                    if not bestD or d < bestD then
                        bestD = d
                        best = { map = p.map, x = p.x, y = p.y, name = name }
                    end
                end
            end
        end
        if best then return best end
    end
end

-- A quest whose target only shows up after you do something at an object (VoidQuest's ForeverSteps: Facing
-- Negolash -> load the Ruined Lifeboat with wine and buzzard wings, then Negolash comes out of the water). The
-- user, 2026-11-20: "I'd like it to where it takes somebody to the boat first and then pop up the boss". The
-- step counts as done once you hand in the object's little quest (QUEST_TURNED_IN, kept 20 min: the boss
-- despawns, and then it's the boat again) or once an objective is finished.
local STEP_FRESH = 20 * 60
local function stepKey(qid) return tostring(UnitGUID("player") or "?") .. ":" .. qid end
local function stepDone(qid)
    local t = VoidGPSDB and VoidGPSDB.stepDone and VoidGPSDB.stepDone[stepKey(qid)]
    return t and time() - t < STEP_FRESH or false
end
local function firstStep(vq, qid)
    local s = vq.ForeverSteps and vq.ForeverSteps[qid]
    if not s or stepDone(qid) or #finishedFor(qid) > 0 then return nil end
    local cont, px, py = Geo.Player()
    local best, bestD
    for map, str in pairs(s.spots or {}) do
        for i = 1, #str - 5, 6 do
            local x, y = tonumber(str:sub(i, i + 2)), tonumber(str:sub(i + 3, i + 5))
            if x and y then
                x, y = x / 1000, y / 1000
                local c, wx, wy = Geo.ToWorld(map, x, y)
                local d = (c and cont and c == cont and px) and Geo.Dist(px, py, wx, wy) or (c and 1e7 or 2e7)
                if not bestD or d < bestD then bestD, best = d, { map = map, x = x, y = y } end
            end
        end
    end
    if not best then return nil end
    local bring = {}
    for _, id in ipairs(s.items or {}) do
        local n = C_Item and C_Item.GetItemNameByID and safeCall(C_Item.GetItemNameByID, id)
        if type(n) == "string" then
            bring[#bring + 1] = n
        elseif C_Item and C_Item.RequestLoadItemDataByID then
            safeCall(C_Item.RequestLoadItemDataByID, id)   -- not loaded yet: there next time you look
        end
    end
    return { step = "first: " .. s.name, name = s.name, map = best.map, x = best.x, y = best.y, npc = false, stepOf = qid,
             sub = "Quest · in your log · first: " .. s.name .. (#bring > 0 and (" (bring " .. table.concat(bring, ", ") .. ")") or "")
                   .. " · " .. Geo.MapName(best.map) }
end

-- { step, name, sub, map, x, y, npc } or { step = "done" } or nil (VoidQuest not loaded / no data)
local function questTarget(qid)
    local vq = rawget(_G, "VoidQuest")
    if not (vq and qid) then return nil end
    if safeCall(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, qid) then
        return { step = "done", sub = "Quest · already done" }
    end
    local inLog = safeCall(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, qid)
    local St = vq.Starts
    if inLog then
        if safeCall(C_QuestLog and C_QuestLog.IsComplete, qid) then
            local t = St and safeCall(St.TurninSpot, St, qid)
            local who = St and safeCall(St.Turnin, St, qid)
            if t and t.m then
                return { step = "turn in", name = who or "turn-in", map = t.m, x = t.x, y = t.y, npc = true,
                         sub = "Quest · ready: turn in to " .. (who or "the turn-in") .. " · " .. Geo.MapName(t.m) }
            end
        else
            local f = firstStep(vq, qid)   -- the boat before the boss
            if f then return f end
            local o = nearestObjective(vq, qid)
            if o then
                return { step = "objective", name = o.name or "objective", map = o.map, x = o.x, y = o.y,
                         sub = "Quest · in your log · " .. (o.name and (o.name .. ", ") or "") .. Geo.MapName(o.map) }
            end
        end
    end
    local s = St and safeCall(St.Get, St, qid)
    local giver = St and safeCall(St.Giver, St, qid)
    -- not takeable yet (an earlier part, a level) or never: say so instead of "take it from" (2026-11-19,
    -- Broken Alliances part 2 before part 1)
    local state, why
    if not inLog and vq.Forever and vq.Forever.Rule then
        local ok, a, b = pcall(vq.Forever.Rule, vq.Forever, qid)
        if ok then state, why = a, b end
    end
    if s and s.m and s.x and s.y then
        local how = (inLog and "Quest · in your log, from " or "Quest · take it from ") .. (giver or "its giver")
        if state == "later" and why then how = "Quest · not yet: " .. why .. " · from " .. (giver or "its giver")
        elseif state == "never" and why then how = "Quest · not for you: " .. why end
        return { step = "pick up", name = giver or "quest giver", map = s.m, x = s.x, y = s.y, npc = s.how ~= "object",
                 sub = how .. " · " .. Geo.MapName(s.m) }
    end
    return { step = "unknown", sub = inLog and "Quest · in your log (no spot known)" or "Quest · where it starts isn't known yet" }
end

-- A creature or object a quest needs: "for 'Screecher Spirits': take it from Yeh'kinya first" (the user,
-- 2026-11-18: VoidGPS sent them to Feralas for a quest they hadn't picked up yet). nil when it's no quest's.
local questsOf   -- [lower name] = { qid, ... }
local function questNote(name)
    local vq = rawget(_G, "VoidQuest")
    if not (vq and vq.ForeverMobs and vq.ForeverMobNames and name) then return nil end
    if not questsOf then
        questsOf = {}
        for qid, refs in pairs(vq.ForeverMobs) do
            for _, ref in ipairs(refs) do
                local n = vq.ForeverMobNames[ref[2]]
                if n then
                    local l = n:lower()
                    questsOf[l] = questsOf[l] or {}
                    table.insert(questsOf[l], qid)
                end
            end
        end
    end
    local fallback
    for _, qid in ipairs(questsOf[name:lower()] or {}) do
        local r = vq.ForeverQuests and vq.ForeverQuests[qid]
        local title = r and r[1]
        if title and not safeCall(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, qid) then
            if safeCall(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, qid) then
                return ("for '%s' (in your log)"):format(title)
            end
            if not fallback then
                local giver = vq.Starts and safeCall(vq.Starts.Giver, vq.Starts, qid)
                fallback = giver and ("for '%s': take it from %s first"):format(title, giver)
                    or ("for '%s' (not taken yet)"):format(title)
            end
        end
    end
    return fallback
end
S.QuestTarget, S.QuestNote = questTarget, questNote   -- (tools/cmd/vgps-quest-test)

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

local fuzzyAll = false   -- Find sets it for its second try, when nothing matched

-- Typos: is q within 1 edit (2 for 6+ letters) of the start of n? A swap counts as one edit, so
-- "ogr" and "ogrimmar" find Orgrimmar (the user, 2026-11-10: "it doesnt find ogr").
-- (three rows reused for every call: the typo pass runs this over thousands of names, and a new
-- table per row made each of those keystrokes freeze the screen, 2026-11-16)
local R1, R2, R3 = {}, {}, {}
local function editDist(a, b, maxd)
    local la, lb = #a, #b
    if math.abs(la - lb) > maxd then return maxd + 1 end
    local prev2, prev, cur = R1, R2, R3
    for j = 0, lb do prev[j] = j end
    for i = 1, la do
        cur[0] = i
        local best = i
        local ai = a:byte(i)
        for j = 1, lb do
            local cost = (ai == b:byte(j)) and 0 or 1
            local v = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            if i > 1 and j > 1 and ai == b:byte(j - 1) and a:byte(i - 1) == b:byte(j) then
                v = math.min(v, prev2[j - 2] + 1)   -- a swap ("ogr" / "org")
            end
            cur[j] = v
            if v < best then best = v end
        end
        if best > maxd then return maxd + 1 end   -- can't get back under: stop early
        prev2, prev, cur = prev, cur, prev2   -- rotate: row i becomes prev, row i-1 prev2
    end
    return prev[lb]
end

local function nearPrefix(n, q)
    if #q < 3 then return false end
    local maxd = #q >= 6 and 2 or 1
    for len = #q - maxd, #q + maxd do   -- 2 edits can be 2 extra / missing letters (Sol review)
        if len >= 1 and len <= #n and editDist(q, n:sub(1, len), maxd) <= maxd then return true end
    end
    return false
end

-- e.wn / e.ws = " " .. name / " " .. sub, made once in buildIndex (building them for every entry on
-- every keystroke was most of the garbage); qs = " " .. q, made once per search.
local function score(e, q, syn, qs)
    local n, s = e.lname, e.lsub
    if n == q then return 1000 end
    local at = n:find(q, 1, true)
    if at == 1 then return 800 end
    local ws = e.ws or (" " .. s)
    if syn then
        -- from the start of a word: "ore" is in "armorer" ("mining" listed Armorer & Shieldcrafters, 2026-11-10)
        for _, t in ipairs(syn) do if s == t or ws:find(" " .. t, 1, true) then return 650 end end
    end
    qs = qs or (" " .. q)
    if at and (e.wn or (" " .. n)):find(qs, 1, true) then return 600 end
    -- a service: from the start of a word, or anywhere for 4+ letters ("smith" -> Blacksmithing
    -- Supplies; "ore" must not find Armorers)
    if s ~= "" and (ws:find(qs, 1, true) or (#q >= 4 and s:find(q, 1, true))) then return 550 end
    if at then return 400 end
    -- a zone or city spelled a bit wrong: always (few of them); anything else: only when asked, and
    -- only names starting with the same letter (the whole-list typo pass froze the screen per key)
    if e.kind == "zone" and nearPrefix(n, q) then return 620 end
    if fuzzyAll and n:byte(1) == q:byte(1) and nearPrefix(n, q) then return 300 end
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
    local iq = ITEM_ALIAS[q]
    local hits, ih
    local qs = " " .. q
    local function collect()
        hits, ih = {}, {}
        for _, e in ipairs(index) do
            local sc = score(e, q, syn, qs)
            -- a quest reward ranks under a vendor selling the same item (the shop next to you, not a
            -- quest across the world: "mining pick" is also a Stepping Stones reward)
            if sc > 0 and e.kind == "reward" then sc = sc - 2 end
            if sc > 0 then hits[#hits + 1] = { e = e, s = sc } end
        end
        if #q >= 3 then
            -- quests: the name only, no typo matching (4,600 names on every keystroke; the user, 2026-11-16:
            -- "whenever i type in it it lags"). Same scale as score(): exact 1000, start 800, a word 600.
            for _, e in ipairs(quests) do
                local n = e.lname
                local sc = (n == q and 1000) or (n:find(q, 1, true) == 1 and 800) or (e.wn:find(qs, 1, true) and 600) or 0
                -- a name several quests share: the part you're on first, then ones still to do, done last
                -- (only these: two quest-log calls each, not for every quest a short query matches)
                if sc > 0 and e.shared then
                    if safeCall(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, e.qid) then
                        sc = sc + 20
                    elseif safeCall(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, e.qid) then
                        sc = sc - 20
                    end
                end
                if sc > 0 then hits[#hits + 1] = { e = e, s = sc } end
            end
        end
        -- items vendors sell: the alias AND what you typed ("thread" -> Coarse Thread first, Fine
        -- Thread still listed; Sol review)
        for _, g in ipairs(goods or {}) do
            local sc = score(g, q, nil, qs)
            if iq then sc = math.max(sc, score(g, iq, nil)) end
            if sc > 0 then ih[#ih + 1] = { g = g, s = sc - 1 } end   -- a place with the same name wins a tie
        end
    end
    collect()
    if #hits == 0 and #ih == 0 then   -- nothing at all: try again allowing a typo in any name
        fuzzyAll = true
        collect()
        fuzzyAll = false
    end
    -- items: routed to the nearest vendor that has it (for gold first). The best 8 matches only,
    -- so a short query doesn't sort every vendor of a thousand items.
    table.sort(ih, function(a, b) if a.s ~= b.s then return a.s > b.s end return a.g.name < b.g.name end)
    for i = 1, math.min(#ih, MAX) do
        local e = ns.Goods:Get(ih[i].g.item)
        local v
        for _, x in ipairs(e and e.vendors or {}) do if not x.cost then v = x; break end end
        v = v or (e and e.vendors[1])
        if v then
            hits[#hits + 1] = { s = ih[i].s, d = v.yards or 1e7, e = { kind = "item", name = e.name,
                sub = "Sold by " .. v.name, map = v.map, x = v.x, y = v.y, npc = true, vendor = v } }
        end
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
        if hits[i].d then
            -- an item: its vendor's distance is already known
        elseif e.kind == "quest" then
            -- ranking only: where it starts (cheap). The real destination is worked out for the few shown
            -- (questTarget below), not for every quest a short query matches (keystroke lag, 2026-11-16)
            local vq = rawget(_G, "VoidQuest")
            local t = vq and vq.Starts and safeCall(vq.Starts.Get, vq.Starts, e.qid)
            if t and t.m and t.x then
                local c, x, y = Geo.ToWorld(t.m, t.x, t.y)
                hits[i].d = (c and c == cont) and Geo.Dist(px, py, x, y) or (c and 1e7 or 2e7)
            else
                hits[i].d = 2e7
            end
        elseif e.kind == "node" then
            local _, _, _, _, yd = ns.Nodes:Nearest({ e.name })
            hits[i].d = yd or 1e7
        else
            local c, x, y = Geo.ToWorld(e.map, e.x, e.y)
            hits[i].d = (c and c == cont) and Geo.Dist(px, py, x, y) or (c and 1e7 or 2e7)
        end
    end
    local kept = {}   -- a fresh list, not a nil-trimmed one (a sort over trailing nil slots can see nil)
    for i = 1, keep do kept[i] = hits[i] end
    hits = kept
    -- parts of one quest name in the same state rank as one: by the nearest part's distance, then part order
    -- (in game 2026-11-20: both done, part 2 showed above part 1 because its giver was nearer). One key per
    -- hit, so the sort below stays a proper order.
    local near = {}
    for _, h in ipairs(hits) do
        if h.e.shared then
            local k = h.e.lname .. "\0" .. h.s
            near[k] = math.min(near[k] or 3e7, h.d or 3e7)
        end
    end
    for _, h in ipairs(hits) do
        if h.e.shared then h.gd = near[h.e.lname .. "\0" .. h.s] end
    end
    table.sort(hits, function(a, b)
        if a.s ~= b.s then return a.s > b.s end
        local ad, bd = a.gd or a.d or 3e7, b.gd or b.d or 3e7
        if ad ~= bd then return ad < bd end
        local ae, be = a.e, b.e
        if (ae.lname or "") ~= (be.lname or "") then return (ae.lname or "") < (be.lname or "") end
        if (ae.depth or 0) ~= (be.depth or 0) then return (ae.depth or 0) < (be.depth or 0) end
        return (ae.name or "") < (be.name or "")   -- a full tie: by name, so the list never shuffles
    end)
    local seen = {}
    for _, h in ipairs(hits) do
        if #out >= MAX then break end
        local e = h.e
        if e.kind == "quest" then
            -- where this quest sends you now: its giver, what it needs, or its turn-in
            local t = questTarget(e.qid) or { sub = "Quest" }
            e = { kind = "quest", name = e.name, qid = e.qid, sub = t.sub, map = t.map, x = t.x, y = t.y, npc = t.npc, target = t }
            -- the distance shown is to where it sends you now (objective, turn-in), not where it starts;
            -- none for a quest that's done or has no spot (in game 2026-11-18: "already done · 7,618 yd")
            local qd
            if t.map then
                local c, wx, wy = Geo.ToWorld(t.map, t.x, t.y)
                qd = (c and c == cont and px) and Geo.Dist(px, py, wx, wy) or nil
            end
            h = { e = h.e, s = h.s, d = qd }
        elseif e.kind == "npc" or e.kind == "rare" or e.kind == "obj" then
            -- a quest's creature or object: say which quest (worked out per search: you may take it later)
            local note = questNote(e.name)
            if note then
                local c = {}
                for k2, v in pairs(e) do c[k2] = v end
                c.sub = (e.sub and e.sub ~= "" and (e.sub .. " · ") or "") .. note
                e = c
            end
        end
        -- (a quest by its ID: two parts of one name with no spot each are still two results)
        local k = (e.qid and ("q" .. e.qid .. "|") or "") .. e.name .. "|" .. (e.map or 0) .. "|" .. math.floor((e.x or 0) * 100) .. "|" .. math.floor((e.y or 0) * 100)
        if not seen[k] then
            seen[k] = true
            out[#out + 1] = { name = e.name, sub = e.sub, map = e.map, x = e.x, y = e.y, kind = e.kind, npc = e.npc,
                vendor = e.vendor, giver = e.giver, quest = e.quest, qid = e.qid, target = e.target,
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
    if r.kind == "item" and r.vendor and ns.Goods then
        ns.Goods:GoVendor(r.vendor, r.name)   -- the way to the vendor ("Sells Mining Pick")
        return
    end
    if r.kind == "quest" then
        -- where it sends you NOW: you may have taken, finished or turned it in since you typed (Sol)
        local t = questTarget(r.qid) or r.target or {}
        if not t.map then G:Print(r.name .. ": " .. (t.sub or r.sub or "no spot known")); return end
        -- arrival names the NPC or creature; the subtitle says which quest and what to do there
        ns.Guide:Start({ name = t.name or r.name, sub = r.name .. " · " .. (t.step or "quest"), map = t.map, x = t.x, y = t.y, npc = t.npc,
                         stepOf = t.stepOf, qname = r.name })
        if WorldMapFrame and WorldMapFrame:IsShown() then WorldMapFrame:SetMapID(t.map) end
        return
    end
    if r.kind == "reward" and r.giver then
        -- the way to the quest giver (named for arrival), the item and quest in the subtitle
        ns.Guide:Start({ name = r.giver, sub = r.quest .. " · reward: " .. r.name, map = r.map, x = r.x, y = r.y, npc = true })
        if WorldMapFrame and WorldMapFrame:IsShown() and r.map then WorldMapFrame:SetMapID(r.map) end
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
        r:SetScript("OnClick", function() w:Choose(i, true) end)
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

    function w:Choose(i, fromClick)
        -- a row clicked while a search is still waiting belongs to the old text: show the new list
        -- instead of routing somewhere you didn't mean (Sol review)
        if fromClick and self.dirty then
            self.dirty = nil
            self:Update()
            return
        end
        local e = self.results[i]
        eb:ClearFocus()
        list:Hide()
        go(e)
        if self.onChosen then self.onChosen() end
    end

    -- Search once you pause typing, not on every letter: a search over every NPC, item and quest
    -- reward per keystroke lagged the whole screen, worst in a fight (the user, 2026-11-16). Enter and
    -- the arrows run a waiting search first, so they always act on what's typed.
    local pendingTok = 0
    local function flush()
        if w.dirty then w.dirty = nil; w:Update() end
    end
    eb:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        hint:SetShown(text == "")
        if text == "" then w.dirty = nil; w:Update() return end   -- recent places: instant
        w.dirty = true
        pendingTok = pendingTok + 1
        local tok = pendingTok
        C_Timer.After(InCombatLockdown() and 0.35 or 0.15, function()
            if tok == pendingTok then flush() end
        end)
    end)
    eb:SetScript("OnEditFocusGained", function() w.dirty = nil; w:Update() end)
    eb:SetScript("OnEditFocusLost", function() C_Timer.After(0.2, function() if not eb:HasFocus() then list:Hide() end end) end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); list:Hide(); if w.onEscape then w.onEscape() end end)
    eb:SetScript("OnEnterPressed", function() flush(); w:Choose(w.sel) end)
    eb:SetScript("OnArrowPressed", function(_, key)
        flush()
        if key == "DOWN" then w.sel = math.min(#w.results, w.sel + 1)
        elseif key == "UP" then w.sel = math.max(1, w.sel - 1) end
        w:Paint()
    end)
    eb:SetScript("OnTabPressed", function() flush(); w.sel = (w.sel % math.max(1, #w.results)) + 1; w:Paint() end)
    widgets[#widgets + 1] = w
    return w
end

----------------------------------------------------------------------
-- Hosts: VoidMap's toolbar, and a small window of its own
----------------------------------------------------------------------
local inMap, window

-- Docked: the search box stays on screen, where you dragged it (the user, 2026-11-10: "that gps
-- box needs to always be up"). On by default; its x (or the Void hub's quick box, /gps dock)
-- turns it off, and then /gps opens it as a popup that closes after a pick, as before.
-- Default: on in WoW Forever (vendors, herbs, ore to find), off on retail (zones and coordinates only).
local function docked()
    local v = VoidGPSDB and VoidGPSDB.searchDock
    if v == nil then return G.FOREVER and true or false end
    return v
end

local function placeWindow()
    window:ClearAllPoints()
    -- docked and popup each keep their own spot (the user, 11-12: every box stays where it was moved)
    local p = VoidGPSDB and VoidGPSDB[docked() and "searchPos" or "searchPopPos"]   -- (an and/or on the values mixed them up)
    if type(p) == "table" and p[1] then
        window:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    else
        window:SetPoint("TOP", UIParent, "TOP", 0, docked() and -72 or -120)
    end
    window:SetFrameStrata(docked() and "MEDIUM" or "DIALOG")   -- docked: never over dialogs and bags
end

local function buildWindow()
    window = CreateFrame("Frame", "VoidGPSSearchWindow", UIParent)
    window:SetSize(408, 30)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint(1)
        if point and VoidGPSDB then
            VoidGPSDB[docked() and "searchPos" or "searchPopPos"] = { point, rel, math.floor(x + 0.5), math.floor(y + 0.5) }
        end
    end)
    local bg = window:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.07, 0.95)
    local t = window:CreateFontString(nil, "OVERLAY")
    t:SetFont(FONT, 11, "OUTLINE")
    t:SetPoint("LEFT", 8, 0)
    t:SetText("|cff00c7ffVoidGPS|r")
    -- x: docked, it turns the docked box off; else it just closes the popup
    local x = CreateFrame("Button", nil, window)
    x:SetSize(16, 16)
    x:SetPoint("RIGHT", -5, 0)
    local xt = x:CreateFontString(nil, "OVERLAY")
    xt:SetFont(FONT, 11, "")
    xt:SetPoint("CENTER")
    xt:SetText("x")
    xt:SetTextColor(0.6, 0.6, 0.66)
    x:SetScript("OnEnter", function(self)
        xt:SetTextColor(1, 0.4, 0.4)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        if docked() then
            GameTooltip:SetText("Hide the search box", 1, 1, 1)
            GameTooltip:AddLine("Bring it back with /gps dock or the Void hub's quick box (left-click the hub icon). /gps still opens it any time.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:SetText("Close", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    x:SetScript("OnLeave", function() xt:SetTextColor(0.6, 0.6, 0.66); GameTooltip:Hide() end)
    x:SetScript("OnClick", function()
        GameTooltip:Hide()
        if docked() then S:SetDocked(false) else window:Hide() end
    end)
    local w = makeWidget(window, 260, window)
    w.eb:SetPoint("RIGHT", x, "LEFT", -4, 0)
    w.rb:SetPoint("RIGHT", w.eb, "LEFT", -4, 0)
    w.onChosen = function()
        if docked() then w.eb:SetText("") else window:Hide() end
    end
    w.onEscape = function()
        if docked() then w.eb:SetText("") else window:Hide() end
    end
    window.w = w
    placeWindow()
    window:Hide()
end

function S:Docked() return docked() end
function S:SetDocked(on)
    VoidGPSDB.searchDock = on and true or false
    if not window then buildWindow() end
    placeWindow()
    window:SetShown(on)
    if not on then G:Print("search box hidden. /gps opens it when you need it; /gps dock keeps it on screen again.") end
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
    if docked() then
        if not window then buildWindow() end
        window:Show()
    end
    hostInVoidMap()
    if not inMap then C_Timer.After(1, hostInVoidMap) end
    if WorldMapFrame then WorldMapFrame:HookScript("OnShow", hostInVoidMap) end
    -- build the search index a few seconds after login, out of combat, so the first letter you type
    -- doesn't pay for it (it was the slowest keystroke of all)
    local function warm()
        if index then return end
        if InCombatLockdown() then C_Timer.After(5, warm) return end
        buildIndex()
    end
    C_Timer.After(6, warm)
end)

-- The object's little quest handed in (Enticing Negolash at the lifeboat): the boss is coming. Remember it 20 min
-- and, if the arrow was on the object, turn it to the boss (questTarget now skips the step).
local stepEv = CreateFrame("Frame")
stepEv:RegisterEvent("QUEST_TURNED_IN")
stepEv:SetScript("OnEvent", function(_, _, questID)
    local vq = rawget(_G, "VoidQuest")
    local steps = vq and vq.ForeverSteps
    if not (steps and questID and VoidGPSDB) then return end
    for parent, s in pairs(steps) do
        if s.child == questID and safeCall(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, parent) then
            local db = VoidGPSDB.stepDone or {}
            VoidGPSDB.stepDone = db
            for k, t in pairs(db) do if time() - t >= STEP_FRESH then db[k] = nil end end
            db[stepKey(parent)] = time()
            local a = ns.Guide and ns.Guide:Active()
            if a and a.target and a.target.stepOf == parent then
                local t = questTarget(parent)
                if t and t.map then
                    local qname = a.target.qname or "quest"
                    ns.Guide:Start({ name = t.name or qname, sub = qname .. " · " .. (t.step or "quest"), map = t.map, x = t.x, y = t.y,
                                     npc = t.npc, qname = qname })
                    G:Print(("%s done: now %s."):format(s.name, t.name or "the objective"))
                end
            end
        end
    end
end)
