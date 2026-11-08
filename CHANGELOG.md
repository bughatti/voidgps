# VoidGPS Changelog

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
