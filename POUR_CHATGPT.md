# Valdrune — notes de passation pour l'intégration Supabase

This document describes the state of the project at **version 9.4**.

## The project

- Godot **4.3** project, written in GDScript. To open it, use `project.godot`.
- Android export uses the "Android" preset in `export_presets.cfg`. The keystore and its passwords are **left blank on purpose**, so the owner has to supply their own signing key.
- The entry scene is `main.tscn`, which uses `main.gd`.
- The save game is the `Game.S` dictionary in `game.gd`. It is stored locally in `user://valdrune_save.json`.

## What is already connected to Supabase (`net.gd`)

- **URL and key:** `net.gd` uses the project URL `https://xtbolgcxyegdwpvpcupc.supabase.co` and the **publishable** key only. No secret key appears anywhere in the code, and none should ever be added.
- **Anonymous guest account:** created automatically on first launch through `POST /auth/v1/signup`. The refresh token is kept in `user://net.json`.
- **`profiles` table:** name, power (PI) and current map, upserted every 2 minutes.
- **`saves` table:** a backup copy of `Game.S` as jsonb, upserted every 2 minutes and when the app goes to the background.
- **`chat` table:** "Monde" chat. The game polls it every 6 s and shows messages in the in-game chat.
- **Script:** `SUPABASE_SETUP.sql` creates these 3 tables with their RLS policies.
- **Prerequisite:** in Supabase, enable **Authentication › Anonymous sign-ins**.
- **No network:** if the network is down, the game keeps running solo. The status is shown in Menu › "Serveur".

Note: the shell this project was built from could not reach supabase.co, so **these requests have never been tested against the real server**. They need to be checked on the first real launch.

## What remains to be done (priority order)

1. **Run `SUPABASE_SETUP.sql` and turn on anonymous sign-in.** Then check on a phone that Menu › Serveur shows "En ligne".

2. **Security of crowns and purchases.**
   - Today the crowns (`Game.S.crowns`) live in the save file, which the client writes itself. A player can cheat them.
   - Before any real money is involved:
     - add a `wallets` table (or a column) that **only an Edge Function** can write;
     - verify Google Play Billing purchases server-side, using the Google Play Developer API from that Edge Function;
     - have the client only *read* its balance.
   - Spending points in the code, to be routed to an RPC or Edge Function:
     - `main.gd` → `shop_claim()` (crowns);
     - `real_buy()`: real-money purchases, **simulated** today.

3. **Real PvP.**
   - The ranked arena (`main.gd` → `start_ranked()`) currently pits the player against **simulated** opponents.
   - The leaderboard (`hud.gd` → `_arena_ranked()`) is also generated locally.
   - Minimal real version:
     - a `pvp_ratings` table (user_id, elo, wins, losses, season) that a function writes after each fight;
     - the leaderboard is read from it;
     - the opponent stays simulated, but is built from **a real player's profile** (name, éveil, power).
   - Live PvP between two phones would need real-time networking: Supabase Realtime is too slow for combat, so it would need a dedicated server.

4. **Real-player leaderboard.**
   - `net.gd` → `_fetch_top()` already reads `profiles` sorted by power.
   - It could replace `Game.ranking()`, which today is generated with bots.

5. **Restoring the save on a new phone.**
   - The `saves` table exists, but nothing reads it back on startup yet.
   - Two pieces are needed:
     - a "Récupérer ma partie" flow, with a real account (email or Google);
     - a reliable link between the anonymous account and that account (`linkIdentity`).

## Map of the code (useful files)

| File | Contents |
|---|---|
| `game.gd` | Data and rules: items, prices, tiers, Éveil, ranked PvP, familiars (PETS), crowns, save |
| `main.gd` | Gameplay: combat, loot, quests, shop (`_shop_effect`), arena, familiars, dungeons |
| `hud.gd` | All the UI (panels, shop `OFFERS`, Arène & Éveil, Ménagerie…) |
| `net.gd` | Supabase |
| `world.gd` | Map generation. Map 1 is loaded from `decor/map_1.json` + `forest_1.json` + `sites_1.json` |
| `builder.gd` / `prefab.gd` / `villagegen.gd` | In-game construction mode (Menu › Mode Construction) |
| `enemy.gd` | Monsters and their attacks (lines and zones on the ground) |
| `player.gd` | Hero and spells |
| `pet.gd` | Tamer's familiars |
| `arena.gd` | Arena: ranked fights and Awakening trials |
| `bake.gd` / `bake.tscn` | Tool that regenerates the thumbnails into `ui/gen/` |

## Rules to follow

- Never put the `service_role` / secret key or the database password in the game.
- Only the URL and the publishable key may go into `net.gd`.
- Anything involving money or crowns must be decided **server-side**.
