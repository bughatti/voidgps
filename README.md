# VoidGPS - Route Finder & Travel Directions

**Works on:** WoW Forever · WoW Midnight (search for zones, coordinates and party members)

**Type where you want to go. VoidGPS draws the way: along paths people actually walk, by flight path and zeppelin, through zones.**

---

### Search for anything
- **An NPC or a rare by name**: "Wulan", "Trigore"
- **A service**, nearest first: "cooking trainer", "bank", "innkeeper", "flight", "mailbox", "anvil"
- **A zone or city**: "Desolace", "Orgrimmar"
- **Coordinates**: "26 69" on the map you're on, or "Desolace 26 69"
- **A party member**: a live route to them. **A friend**: their zone
- **A herb or ore**: "briarthorn", "tin vein", "herb", "ore": a route to the nearest spot it can spawn
- **Something a vendor sells** (WoW Forever): "mining pick" (or "pick axe"), "fishing pole", "flint and tinder", "simple wood": the nearest vendor of your faction that sells it for gold, and the way there. Vendors in zones well above your level come last
- Your **recent places** when the box is empty. Up / Down / Enter / Esc work

**The search box stays on screen** (WoW Forever; on retail turn it on with `/gps dock`): drag it by its "VoidGPS" label to where you like. Its **x** hides it (bring it back with `/gps dock` or the Void hub's quick box); then `/gps`, the **Void hub icon** or a key (Key Bindings > AddOns > VoidGPS) opens it when you need it. It also sits in **VoidMap's** toolbar on the world map.

### The way there
- **A line on the world map and the minimap**: cyan along walked paths, orange dashed where no one has walked yet (a straight line), white dashed for a flight, purple for a boat or zeppelin
- **Blizzard's own arrow** points at the next turn and moves on as you reach it
- **Flight paths you know** are used when they're quicker. **Zeppelins** are built in; **boats** are learned the first time you ride one
- **Routes for your quests** (with **VoidQuest**): hover a quest in another zone for the steps to get there, shift-click it to be guided
- Off the route? It plans a new one. Another continent? It plans the rest when you get there
- A small box shows where you're going, the next step and how far. **Stop** ends it

### Errands
- Vendor items you need (from **VoidAH**'s Professions tab, **Vendor stops to errands**) go on a small list out in the world, grouped by vendor, nearest first, with how far. Click a vendor for the way there
- Items tick off by themselves as they reach your bags; right-click one to drop it
- At the vendor, **Buy my errands here** buys what's left in one click: gold only, and only if you can afford it

### Vendors it has seen
- Opening a merchant records what it really sells and where it stands. A vendor seen not selling an item drops off that item, and one seen selling it is added and preferred, so a wrong vendor in the bundled list fixes itself

### Is it up?
For a rare that doesn't always spawn, or any NPC you're heading to:
- A **Target** button in the box (and a key in Key Bindings) that tries to target it. Each press is one try
- VoidGPS watches nameplates, your target and your mouseover, and tells you with a sound the moment it shows up: **"is up!"** or **"is dead"**
- **Any rare, not just your target:** the moment any rare shows on a nameplate, your target or your mouseover, you get a sound and "Rathorian is up!", then quiet for 5 minutes for that rare. The **Rares** button next to the search box turns it off or on (or `/gps rares`)

### Walking routes come from VoidMap
**VoidMap** records the paths you walk. The more you play, the more routes follow real paths instead of straight lines. Without VoidMap every leg is a straight line.

---

## Compatibility

- **WoW Forever**: everything (all the NPCs, services, rares and zeppelins)
- **WoW Midnight** 12.1.5 (Season 2): search for zones, coordinates and party members
- Works best with **VoidMap**. No other addon needed
- English game client

---

## Credits

The WoW Forever NPC, rare, object, herb, ore, vendor recipe, mob drop and zeppelin data comes from **NorgannonDB** (GPL-3.0), built on **QuestieDB** and pfQuest. Thank you to both projects.

---

*Part of the Void addon family by Vede · GPL-3.0 licensed · [Source & bug reports](https://github.com/bughatti/voidgps) · [All Void addons](https://www.curseforge.com/members/bughatti/projects) · free M+ & raid player lookups at [voidscout.io](https://voidscout.io) · more at [tinkerline.io](https://tinkerline.io/addons/voidgps/) · [Discord](https://discord.gg/7ZHmx7zMDh)*
