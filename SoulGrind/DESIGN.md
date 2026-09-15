# Soul Grind: system and retention design

This MVP is built around Roblox's current Recommended For You signals. It records ordinary game state only; Roblox calculates discovery and Creator Rewards metrics itself.

| System | Player experience | Signal it supports |
| --- | --- | --- |
| Immediate shade at spawn | The player sees the target, objective, and ATTACK button as soon as the UI loads. | First-play bounce, qualified play sessions |
| Authored underworld arena | Ruined arches, braziers, soul embers, cliffs, a stone path, restrained neon accents, and distinct color grading establish the fantasy before the first input. | Play-through rate and first-play bounce |
| Readable darkness | The theme stays violet and moody, but ambient light, a lit floor, a glowing floor grid, bright cliff veins and a per-zone obelisk keep every surface distinguishable from the void. A dark mood the player cannot navigate reads as a broken game, not an atmospheric one. | First-play bounce |
| Enemy silhouettes | Each archetype has its own body colour, a neon collar and a permanent `Highlight` rim, so it is identifiable at a glance and never vanishes into the floor or the fog. | First-play bounce, qualified sessions |
| Input that always answers | Every ability press produces something visible even when it fails: the strike swings, an out-of-reach strike names the distance, a rejected press drains the button's cooldown overlay, and a locked Pulse says which level unlocks it. A silent ability is indistinguishable from a broken one. | First-play bounce, qualified sessions |
| One reach, one number | `Config.AttackRange` is read by both the server and the HUD, so the target plate's "IN RANGE" is the same reach the server enforces. | First-play bounce |
| Pointer and touch parity | Soul Strike fires from **F**, the on-screen button, a left click and a touch tap through one code path. Input that the HUD already consumed does not also strike the world. | Qualified sessions on mobile |
| Three-hit Soul Strike | Fast strikes build into a slower, high-damage third hit with knockback and a visible Soul Break payoff. Timing replaces repetitive single-click combat without raising the entry barrier. | Qualified sessions and D1 playtime |
| Soul Step dodge | A three-second movement skill lets players evade normal attacks and phase through the Warden's telegraphed slam. It creates a learnable skill test rather than a stat-only grind. | Qualified sessions and mastery-driven return play |
| Enemy archetypes | Shades, fast Wisps, durable Reavers, and the Warden have different silhouettes, health, speed, damage, ranges, and rewards. Players change priorities instead of fighting reskinned copies. | Playtime and D2-7 play days |
| Target, health, and hit feedback | A nearby-enemy health plate, player body bar, damage numbers, particles, hit flashes, combo callouts, and damage flashes make every action legible. | First-play bounce and qualified sessions |
| Telegraphing Warden boss | The Warden grows a visible danger field before its slam; Soul Step completely avoids it. The encounter tests a mechanic the player owns instead of only checking damage level. | D2-7 play days and qualified sessions |
| Fast first upgrade | The first kill gives 10 Souls and the first upgrade costs 20. The player makes a visible power choice in the opening minute. | D1 playtime, qualified sessions |
| Soul Level and Pulse | Repeated upgrades increase damage; Level 3 adds an area attack instead of only increasing a number. | D1 playtime |
| Ash Gate | 150 Souls permanently opens Frozen Purgatory, where enemies and rewards change. The gate always has a free gameplay path. | D2-7 play days |
| Rebirth | At 500 Souls after opening Zone 2, the run resets while zones, collection, and a permanent 10% damage bonus remain. A confirmation states exactly what resets. | D2-7 and D8-28 play days |
| Sigil collection | First kill, 25 kills, Zone 2, the Warden, first rebirth, seven distinct days, and a visible Hollow Crown on day 20 create targetable long-term goals. | D8-28 play days |
| Ember Chain | The chain grows on each distinct return day and never resets after a missed day. | Play days without punitive loss |
| Daily shade goal | Ten kills award three free cosmetic flares. | Play days, qualified sessions |
| Active check-in | Ten active minutes plus three kills awards two free flares. Progress pauses after 90 seconds without an action. | Meaningful playtime; supports a natural ten-minute session |
| Friend invite and co-play bonus | An explicit native invite button is always available. Friends in the same server earn 10% more Souls together. No reward is granted merely for sending an invite. | Intentional co-play days |
| Public Soul Level | Leaderstats and an overhead rank make progress visible. | Social identity and repeat play |
| Soul Flare developer product | When the player's free flares reach zero and they press the flare button, the game explains the repeatable cosmetic pack. The purchase dialog opens only after a second explicit click. | Spend days and Robux spent |
| Violet Aura pass | Pressing the aura control without ownership shows a permanent cosmetic offer. | Spend days and Robux spent |

## Monetization rules

- There are no paid randomized rewards.
- Paid items do not change damage, drop rates, access, or PvP strength.
- Daily play supplies Soul Flares for free.
- Product IDs default to `0`, so unfinished commerce never opens an invalid checkout.
- All developer-product rewards are granted on the server through the single `ProcessReceipt` callback.
- `PurchaseId` and the flare grant are written atomically in the player's profile with `UpdateAsync`. A redelivered receipt sees the stored ID and grants nothing again.
- Paid receipts remain unresolved when durable data storage is disabled, preventing a purchase from being acknowledged without a durable grant.

## Prototype ceiling

Player progression is written after each kill. That is simple and safe for an MVP test with a small server. Before raising server capacity or shortening enemy fights, replace kill-by-kill writes with an operation journal and periodic merged saves. Receipt grants should remain immediate and durable.

The enemy and session loops each run one `pcall`-wrapped step on a timer. That keeps one bad tick from killing behaviour for the rest of the server's life, at the cost of swallowing the cause into a `warn`. If enemy behaviour ever needs to scale past a handful of spawns per zone, move the per-tick player scan out of the per-enemy loop before adding more enemies.

Targeting picks the nearest living enemy inside `Config.AttackRange`. That is forgiving, which is the right trade for touch, but it means a player cannot deliberately pick a farther target. Add a facing cone or an explicit lock-on before adding enemies whose priority actually matters.

## How this stays true

`tests/gameplay_cli.luau` runs the real server and client scripts against a stub Roblox API and asserts the claims in this table that can be checked without a renderer: the ability wiring on every input route, the server cooldowns, the reach parity, the feedback-on-failure rule, and a readability floor on lighting, arena and enemy colours. Changing a palette to something unreadable, dropping the pointer binding, or making a miss silent again fails the suite rather than the playtest.
