# VoidGPS Changelog

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
