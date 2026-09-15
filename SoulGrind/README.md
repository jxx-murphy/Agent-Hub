# Soul Grind: Underworld Rising

A playable Roblox Studio MVP with an auto-built two-zone world, server-authoritative combat, persistent progression, daily goals, friend co-play, fair cosmetic monetization, and an idempotent developer-product receipt handler.

## Fastest setup

1. Open `dist/SoulGrind_Underworld_Rising.rbxlx` in Roblox Studio.
2. Press **Play**. The map, enemies, interface, and controls are created automatically.
3. Publish the experience before enabling purchases or persistence.
4. In **Game Settings → Security**, enable **Studio Access to API Services** only when testing data with an isolated test experience.
5. Set `StudioPersistence = true` in `ReplicatedStorage/SoulGrind/Config` when you deliberately want Studio tests to touch DataStores. Leave it `false` for ordinary editing.

## Controls

| Input | Action |
| --- | --- |
| **F**, **left click**, or **tap** | Soul Strike. Three-hit chain; the third hit is a slower Soul Break with knockback. |
| **Q** | Soul Pulse. Area attack, unlocks at Soul Level 3. |
| **E** | Soul Step. Dash with a short invulnerability window; phases through the Warden's slam. |
| On-screen bar | The same three actions, sized for touch. The bar scales down on narrow screens. |

Every press produces feedback even when it does not connect: the strike still swings, an out-of-reach strike reports the distance to the nearest enemy, and each button drains a cooldown overlay so a rejected input never looks like a dead key. Clicks that land on the HUD do not also strike the world.

The target plate at the top of the screen uses `Config.AttackRange`, the same value the server enforces, so "IN RANGE" always means the server will land the hit.

## Tuning the look

Everything visual is built at runtime by `src/server/Main.server.luau`:

- `Lighting.ClockTime` (currently `5.7`) is the main taste knob. Lower is darker; `12` is flat noon.
- `Config.Zones[n].Ground`, `GroundAlt`, `Stone`, and `Color` set each arena's palette.
- `archetypes[kind].Body` and `.Trim` set enemy readability. Every enemy also carries a `Highlight` rim so it never disappears into the floor or the fog.
- `tools/build-place.mjs` pins `Lighting.Technology` to `ShadowMap` in the place file. Scripts cannot set it, and anything below ShadowMap silently ignores `Atmosphere` and the environment scales.

## Enable the optional cosmetics

Create one developer product named **5 Soul Flares** and one pass named **Eternal Violet Aura** in Creator Hub. Copy their numeric asset IDs into `Config.luau`:

```luau
Products = { FlarePack = { Id = 123456789, ... } },
Passes = { Aura = { Id = 987654321, ... } },
```

The IDs intentionally ship as `0`. Gameplay and free daily flares work without configuring commerce.

## Data safety

`Store.luau` serializes updates per player and uses `UpdateAsync`. `Commerce.luau` is the only script that assigns `MarketplaceService.ProcessReceipt`; it validates the player, product ID, and purchase ID before changing data. The flare balance and receipt ID commit in the same profile update, so Roblox can redeliver an interrupted receipt safely.

Do not grant developer products from `PromptProductPurchaseFinished`; that client-facing event does not prove the receipt was durably processed.

## Run the tests

The Luau suites run outside Studio. Install [Lune](https://github.com/lune-org/lune/releases), put it on `PATH` (or set `LUNE=/path/to/lune`), then:

```bash
node tools/run-tests.mjs
```

That runs three suites and rebuilds the place file:

| Suite | What it covers |
| --- | --- |
| `tests/model_cli.luau` | Profile normalization, daily rollover, milestones, costs, damage. |
| `tests/receipt_cli.luau` | Receipt grants, duplicates, unknown products, spend-day counting. |
| `tests/gameplay_cli.luau` | The whole game loop. It runs the real `Main.server.luau` and `Client.client.luau` against `tests/roblox_stub.luau`. |

`gameplay_cli` is the one that matters when changing combat or visuals. It asserts that each ability fires from its key, its on-screen button, a mouse click and a touch tap; that server cooldowns reject early repeats; that a miss reports why; that the HUD and server agree on attack range; that lighting, floor and enemy colors clear a readability floor; that the enemy loop survives a character disappearing mid-tick; and that a paid receipt stays unresolved while saving is off.

`tests/roblox_stub.luau` is a minimal Roblox API, not an emulator. Geometry is translation-only and nothing is rendered, so it catches wiring, reach, cooldown and palette regressions — not shader or physics behaviour. Play Solo is still the final check.

`tests/CommerceSpec.luau` additionally runs inside Studio. During Play Solo, open **View → Command Bar**, switch to the server, and run:

```luau
require(game.ServerStorage.SoulGrindTests.CommerceSpec)()
```

## Rojo option

The source tree also includes `default.project.json`. If you already use Rojo, run `rojo serve` from this directory and connect the Studio plugin. Rojo is optional; the generated `.rbxlx` works by itself.

See `DESIGN.md` for the retention reason behind every system.
