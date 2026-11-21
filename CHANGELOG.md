# VoidGPS Changelog

## 0.8.9 — 2026-11-21

- **Fixed on WoW Forever: your flight paths and errands.** The game stopped telling addons your realm's name, so VoidGPS lost track of which flight paths you know (routes could use ones you haven't found yet) and of your errands list. It finds them again under the name they were saved with.

## 0.8.8 — 2026-11-21

- **Smaller flight masters on the map.** The flight-path circles are about a third smaller on zone and continent maps.

## 0.8.7 — 2026-11-20

- **No enemy towns.** Searching a place never offers the other faction's towns (Theramore, Southshore, Astranaar for the Horde; Crossroads, Tarren Mill for the Alliance), and flight paths on the map are only your faction's and neutral ones.
- **Every flight path on the world map (WoW Forever).** Each zone, city and continent map shows your faction's flight masters: green = you have that flight path, yellow = not yet. Hover for the name, click one for a route there. Switch it off in the Void hub's quick box (Flight paths on the map).

- **Named places and who's there (WoW Forever).** Search finds the named places inside a zone (Ravenholdt Manor, The Crossroads, Booty Bay...: 603 of them, from the game's own map) and lists the people there right under them: "ravenholdt" gives Ravenholdt Manor, then Fahrad, Lord Jorach Ravenholdt and the rest, not only the guards. Picking a place takes you to where its people are.
- **Quests whose work is inside a dungeon (WoW Forever, with VoidDungeon).** A quest in your log with nothing to find outdoors now takes you to its dungeon's entrance (The Talisman of Kazdor: Zul'Farrak).
- **Spots players measured come first.** NPCs, quest givers and the mobs for crafting materials and skinning are placed where VoidQuest and VoidGPS players actually met them, wherever someone has (562 NPCs, 188 quest givers, 400 material mobs, 149 skinning spots), else where the open data puts them.

## 0.8.6 — 2026-11-20

- **More places and rewards (WoW Forever).** Updated with WoW Forever's newest content: more NPCs, vendors and objects to search, and 2,969 quest rewards you can search for (was 2,682), among them rewards like Sword of Omen that had gone missing.

## 0.8.5 — 2026-11-20

- **Quests with the same name (WoW Forever, with VoidQuest).** Hundreds of quests share a name with another part (Broken Alliances part 1 and 2). Search now lists every part, labelled "part 2 of 2" when the order is known, puts the part in your log first and done parts last, and says "not yet" for a part you can't take yet. Parts in the same state stay in order: part 1 above part 2.
- **Summon quests: the object first, then the boss (WoW Forever, with VoidQuest).** For quests where you do something at an object before the target shows up, search now takes you to the object first. Facing Negolash goes to the Ruined Lifeboat on the shore (with what to bring), not to the spot in the water where Negolash comes out; Tremors of the Earth and Broken Alliances go to the Seal of the Earth, Bride of the Embalmer to the grave. Once you hand in at the object, the arrow turns to the boss by itself.

## 0.8.4 — 2026-11-18

- **Quest search shows the right distance.** A quest's distance was to where it starts, even when it sent you to its objective or turn-in; now it's to where it sends you. A quest you already did shows no distance.

## 0.8.3 — 2026-11-18

- **Search for a quest by name (WoW Forever, with VoidQuest).** "screecher spirits" takes you where the quest needs you now: its **giver** if you haven't taken it, the nearest thing it still needs if it's in your log, the **turn-in** once it's done; and it says so if you already did it. Searching a mob or object a quest needs says which quest it's for and who to take it from first (it used to send you to Feralas for a quest you hadn't picked up in Tanaris).

## 0.8.2 — 2026-11-17

- **Fixed: vendors that VoidGPS knows sometimes didn't show up.** One odd item a vendor was seen selling could stop the whole vendor list from loading for the rest of the session, and the error was hidden, so searches and VoidProf's "buy it here" lines came up empty for items that are sold. Each item is now added on its own, a problem is reported like any other addon error, and the list is tried again on next use instead of staying half-built.

## 0.8.1 — 2026-11-16

- **Fixed: typing in the search box lagged the whole screen on every letter**, worst in a fight. It now searches once you pause typing (a little longer in combat), and each search is about ten times faster: a misspelled word that froze the game for most of a second now takes a blink. Enter, Tab and the arrow keys always act on what you typed.
- The search list is prepared a few seconds after you log in (never in combat), so the first letter you type isn't the slow one.
- Windows open in front of the Void windows already open, and come forward when you click them.

## 0.8.0 — 2026-11-15

- **Credits:** the game data this addon ships is now called **VoidDB**; full credits and licences of the open data in it are in NOTICE.txt and the README.

- **Skinnable beasts** (WoW Forever): VoidGPS knows the normal mobs you can skin in each zone, with levels and where they gather (from CMaNGOS classic-db and VoidDB). VoidProf's new Skinning guide routes you to the nearest ones.

- **Who teaches which profession recipe** (WoW Forever): VoidGPS now knows the trainers of 465 recipes, with the skill they need and the fee (from CMaNGOS classic-db, GPL-3.0). VoidProf uses it to name and route to the right trainer, for example the two Trauma Surgeons for Heavy Mageweave Bandage.

## 0.7.0 — 2026-11-13

- **Search finds quest rewards** (WoW Forever): type an item a quest gives, like "sword of omen", and you get the quest, the level it needs and who gives it (and "pick one" when the quest is known to let you choose). Click it and VoidGPS takes you to the quest giver (Varimathras in Undercity for that one). Only your faction's quests show, and when a vendor sells the same item the vendor comes first.

## 0.6.0 — 2026-11-13

- **Which mobs drop crafting materials** (WoW Forever): for 139 materials (meat, cloth, eggs, spider legs...), the normal mobs that drop them, with drop chance, level and where they spawn, from VoidDB. Mobs are ranked by drop chance times how many spawn, so a big camp beats three rare casters. VoidProf's leveling plan uses it to weigh farming a material yourself against buying it.

## 0.5.2 — 2026-11-12

- **Fixed: a side of a box could be missing**, e.g. the right line of the recipes box and its buttons when the game window is an odd number of pixels wide. Every Void box now always shows all four border lines.

## 0.5.1 — 2026-11-12

- **Fixed (WoW Forever): routes used flight paths you don't have.** Away from a flight master the game reports every flight path as known, so a route could say "fly to Stonard" to a character who has never been there. VoidGPS now learns the flight paths each character really knows (when you open a flight master's map, and when you discover a new one) and only plans with those. Open any flight master once on each character to teach it.
- **For VoidQuest's route plan:** a quick travel-time estimate between any two places (walking, flight paths, boats and zeppelins), so VoidQuest can put your quests in the best order.
- **Two characters with the same name on different realms** no longer share one list of known flight paths.
- **The rare pop-up can be dragged** and stays where you put it, even after a restart; its Target button moves with it. The search box remembers its docked and its popped-out spot separately.
- **Void hub button:** left-click opens one panel with all your Void addons by name, grouped, each with its own on/off switches (it replaces the ring of icons), with a background slider. The hub's info window now stays where you put it.

## 0.5.0

- **Search for what vendors sell** (WoW Forever): type "mining pick" (or "pick axe"), "fishing pole", "flint and tinder", "simple wood"... and get the nearest vendor of your faction that sells it for gold, with the way there. Vendors in zones well above your level come last (and in VoidAH's Professions **Go** buttons too).
- **The search box stays on screen** (WoW Forever; `/gps dock` on retail): drag it by its label where you like. Its **x** hides it; `/gps dock` or the Void hub's quick box brings it back.
- **Typos are fine:** "ogrimmar", "orgrimar", "stormwnd" find the city; a name spelled a letter off is found when nothing else matches.
- "mining" or "ore" no longer lists Armorers ("ore" was found inside "armorer").

## 0.4.0

- **Errands:** vendor items to buy (from VoidAH's Professions tab) go on a small list out in the world, grouped by vendor, nearest first. Click a vendor for the way there; items tick off as they reach your bags. At the vendor, **Buy my errands here** buys what's left in one click (gold only, checks you can afford it).
- **Learns what vendors really sell:** opening a merchant records what it stocks and where it stands. A vendor seen not selling an item drops off that item; one seen selling it is added and preferred.
- **Merchant cost scanning** only runs on WoW Forever (nothing uses it on retail).

## 0.3.8

- **Routes for your quests (with VoidQuest):** hover a quest in another zone and VoidQuest shows the way there that VoidGPS works out, step by step: "Fly to Orgrimmar (from Camp Taurajo)", "Take the zeppelin outside Orgrimmar to Grom'gol", "Walk 832 yd to Hemet Nesingwary". Shift-click the quest and VoidGPS guides you leg by leg.

## 0.3.7

- **Fixed: box borders missing a side.** Depending on where a window sat on screen, its left, right or bottom line could vanish. Borders are now exactly one screen pixel and can't round away.

## 0.3.6

- **Other Void addons can route you now:** they can hand VoidGPS a place and you get the same route as from the search box, across zones and continents. The first to use it is VoidDungeon (coming soon), which routes you to the givers of dungeon quests you haven't picked up yet.

## 0.3.5

- **Rare alerts are now a popup you can't miss:** a box near the top of the screen with the rare's name, level and "RARE IS UP" (or rare elite), plus a **Target** button. It stays until the rare dies ("KILLED", then it goes away), you close it, or 5 minutes pass. The chat line, center text and sound are still there. A rare that shows up mid-fight gets its Target button when the fight ends (the game doesn't let addons change it in combat).
- **Rare log:** every rare VoidGPS sees is noted (alert shown, alerts off, seen dead, killed), with time and place. `/gps rarelog` lists the latest; `/gps raretest` shows the popup for your target to try it.

## 0.3.4

- **Quick switch for rare alerts:** left-click the Void hub button by your minimap and a Quick switches box opens next to the addon icons, with Rare alerts on/off (also `/vquick`).

## 0.3.3

- **The route shows in VoidGather's gathering HUD.** The HUD fades the minimap away, and the route's dots faded with it; they now keep their own opacity.

## 0.3.2

- **Knows what a vendor wants besides gold.** The 14 Azeroth Commerce Authority supply-post vendors (the Barrens depot and Three Corners in Redridge) sell their recipes for Merchant's Favor and reputation. Every vendor you open is read for its real costs (gold, Merchant's Favor, other currencies) and the reputation each item needs, and remembered.
- **Routes to a recipe go to a vendor that takes gold.** A Merchant's Favor vendor is only used when nobody sells it for gold.

## 0.3.1

- **Everything vendors sell**, not just recipes: 2,067 items (recipes, pets, gear, reagents, consumables) from 1,053 vendors who are there all year, with limited stock flagged. VoidAH's Deals uses it for its Vendor -> AH list.
- **Fixed: the Target button after a /reload mid-fight.** It's now set up once combat ends instead of being blocked.

## 0.3.0

- **Which vendor sells which recipe** (677 recipes, 1,439 vendor offers, holiday vendors left out, with skill needed, price and limited stock), for VoidProf's "recipes from vendors" lists and zone popups. A click there starts a VoidGPS route to the nearest vendor.
- **A lighter route on the minimap:** smaller dots spaced evenly on screen. Zoomed in (in a city) they ran together into a thick line.
- A route to a vendor no longer shows the Target button (that one is for rares).
- **Holiday vendors say so:** Winter Veil, Hallow's End, Brewfest and Darkmoon Faire vendors show "· Winter Veil only" (and so on) in search; they were listed as if they stood in town all year.

## 0.2.0

- **Herbs and ore:** type "briarthorn", "tin vein" or just "herb" / "ore" and VoidGPS routes you to the nearest spot it can spawn: over 25,000 spots for every Classic herb and ore (and Forever's new ones). One arrow target, no dots on the map. Picked already? Choose it again for the next nearest.
- **VoidProf** uses these spots for its Herbalism and Mining leveling plan: the best zones for each step and a "Nearest spot" button.

## 0.1.1

- **Every rare, not just the one you're heading to:** the moment any rare shows on a nameplate, your target or your mouseover you get a sound and "Rathorian is up! (rare, level 15)", then quiet for 5 minutes for that rare. A **Rares** button next to the search box (on the world map and in the search window) turns it off or on; so does `/gps rares`.
- **Fixed:** picking a place from your recent list again added another "recent" to its label each time.
- **Fixed:** route planning no longer errors if the game hides your speed during a fight.

## 0.1.0

First version.

- **Search** for an NPC, a rare, a service (nearest first), a zone, coordinates, a party member or a friend's zone.
- **Routes** along the paths VoidMap recorded, with flight paths you know, zeppelins, and boats you've ridden.
- **The way on screen**: a line on the world map and minimap, Blizzard's arrow on the next turn, and a box with the next step and the distance.
- **Is it up?** A Target button and key for the NPC you're heading to, and a sound plus "is up!" the moment it shows up on a nameplate, your target or your mouseover.
