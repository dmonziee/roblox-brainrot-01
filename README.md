# Brainrot Blast

A 3D Steal-a-Brainrot-style game for the make.fun roblox-brainrot-01 bounty: walk a bright 3D arena, buy absurd meme brainrots off a conveyor belt, park them on your base, and watch the cash tick up every second — while rivals try to steal yours and a tsunami sweeps the map every minute and a half.

## How a round plays

1. **Spawn** on your coloured base plot. Brainrots stroll down the central conveyor from one end of the map to the other.
2. **Buy**: walk up to one on the belt and press **E** (or tap the green BUY button). If you can afford it, it waddles to a free pad on your base.
3. **Earn**: every brainrot on your base pays its $/s, ticking server-side once a second. Save up and buy rarer tiers.
4. **Steal**: grab a brainrot off another player's base and carry it home within 10 seconds — if you make it, it's yours. A **Lock** button seals your base for 30 seconds (60 second cooldown) so nobody can steal from you.
5. **Survive the wave**: a tsunami hits every ~90 seconds with a 10 second warning. Anyone caught outside their base gets knocked flying and drops whatever they were carrying.
6. **Rebirth** at $100,000: your cash and base reset, but you keep a permanent +25% earnings multiplier per rebirth.

## The cast

| Rarity | Brainrot | $/s | Price |
| --- | --- | --- | --- |
| Common | Noobini Pizzanini | 5 | $50 |
| Common | Chimpanzini Bananini | 12 | $120 |
| Rare | Tung Tung Sahur | 30 | $300 |
| Rare | Lirili Larila | 55 | $550 |
| Epic | Tralalero Tralala | 120 | $1,200 |
| Epic | Trippi Troppi | 200 | $2,000 |
| Legendary | Bombardiro Crocodilo | 450 | $4,500 |
| Legendary | Cappuccino Assassino | 700 | $7,000 |
| Mythic | Brr Brr Patapim | 1,200 | $12,000 |
| Brainrot God | La Vaca Saturno Saturnita | 2,500 | $25,000 |

Every spawn can also mutate: **Gold ×2** (8%), **Diamond ×5** (3%), **Rainbow ×10** (1%). Mutations multiply both the price and the $/s.

## Controls

- **WASD / arrow keys** — move (default Roblox character)
- **E** — buy the nearest brainrot on the conveyor
- **L** — lock your base
- **BUY / LOCK BASE / REBIRTH $100K** — the same actions as on-screen buttons

The HUD (top bar, kept clear of the Roblox menu buttons in the top-left corner) shows your cash, $/s, brainrots owned, rebirth count and the countdown to the next wave. The event feed on the right narrates buys, steals, locks and rebirths.

## Files

- `src/shared/BrainrotCatalog.luau` — the cast, rarities, mutation rolls, prices and rebirth maths (one table drives server and client)
- `src/server/BrainrotServer.server.luau` — money tick, conveyor spawns, buy / steal / lock / rebirth, tsunami wave, brainrot models with name + rarity + $/s labels
- `src/client/BrainrotClient.client.luau` — HUD, buy prompt, buttons, wave warning, event feed
- `default.project.json` — the Rojo project: the 3D world (green ground, conveyor, four coloured base plots, spawn pad, trees, pillars, bright lighting) plus the script tree
- `main.ts` — hands the entry in: copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to `/output` and writes `dossier.json` with `vendor/makefun-roblox.ts`
- `game.rbxl` — the place, built with `rojo build default.project.json --output game.rbxl`
- `screenshots/` — 4 composed renders of the game's own world and characters (see below)
- `icon-512.png` — 512×512 logo for the Creator Dashboard icon upload

## Screenshots — read this before submitting

The four pictures in `screenshots/` are **composed renders** of this game's own world and characters (drawn to look like in-game captures), because no Roblox Studio was available in the build environment. The first by name, `1-thumbnail.jpg`, is the cover and the one to upload as the game's first thumbnail. **Before submitting, Dian must retake real Studio captures** — play the game in Studio, take 3–4 real screenshots including the thumbnail shot — and replace these files with them. The thumbnail file uploaded to Roblox must be the same picture as one of the screenshots in the submitted commit.

## Publish (Dian's PC steps)

This repo is not published yet: `PLAY.json` still holds the placeholder `place_id 0` / `universe_id 0` on purpose — no fake IDs are invented here. Dian publishes from a Windows/Mac PC with Roblox Studio:

1. Open `game.rbxl` in Roblox Studio.
2. File → Publish to Roblox As… → create a new experience, name it **Brainrot Blast**.
3. On the Creator Dashboard, set the experience **Public** (complete Roblox's age check, description, genre and content questions first if asked).
4. In the experience description, include the play code `makefun-mulberry-firefly-laurel`.
5. Upload `icon-512.png` as the experience icon and `screenshots/1-thumbnail.jpg` as its first thumbnail (Creator Dashboard → experience → Configurations → Places → start place → Icon / Thumbnails). Wait until both show on the experience page — Roblox reviews uploads.
6. Play briefly in Studio, take 3–4 real screenshots (including the thumbnail shot), and replace the files in `screenshots/` with them.
7. Copy the real place ID and universe ID from the play link / Creator Dashboard into `PLAY.json`, commit, and submit.

## Build it yourself

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

Verified 2026-11-20 ~07:58 WIB (local build, before publish): Rojo build succeeds, `game.rbxl` is 14,870 bytes of binary Roblox format (`<roblox!` header); `node main.ts` writes `out/dossier.json` — 45 instances, 3 scripts, 26,841 bytes of source, 100.0% matched to `src/`; all four screenshots are 1280×720 JPEGs under 256 KiB. Kit check passes everything except `play_link` (not yet published) and the at-submission repo rows (not on GitHub yet).

Payout wallet: the dedicated make.fun wallet for @dmonziee (see `.makefun/owner.json`).
