# OG_stims

Consumable 1-hour buffs (stims), crates to get them, and a casino machine to buy crates.
Requires `OG_core`; buffs act through `skilltrees`.

- **Stims:** each gives exactly one bonus, in five tiers (Basic / Improved / Advanced /
  Superior / Prototype = common -> legendary). Nine bonuses: max health, health regen, max
  armor, armor regen, fire rate, reload speed, bullet damage, salary, skill XP. Ids are
  `<bonus>_<rarity>`, e.g. `hp_common`, `damage_legendary`, `money_rare`.
- **Categories:** health, armor, weapon, damage, salary, experience. Only one buff per
  category is active - a new stim replaces the old one in its category - but different
  categories stack. Each stim has a short description shown in the menu.
- **Death:** dying ends buffs below epic (`OG_Stims.KeepOnDeath` in sh_config.lua, or a per-stim
  `keepOnDeath`); epic and legendary stims survive. The menu says which is which.
- **Config:** everything is data in `lua/og_stims/sh_config.lua`. The `Effects` table holds the
  five tier values per bonus and the stims are generated from it.
- **Flow:** own -> assign to one of `OG_Stims.LOADOUT_SLOTS` (6) loadout slots via `!stims`,
  the C-menu icon or `og_stims_menu` -> use in the field with `og_stims_use <slot>` (bind a key).
- **Crates & the casino machine:** `OG_Stims.Lootboxes` defines crates with a `price`
  (`money` = DarkRP, `playtime` = playtime points), `rarityWeights` and `pity`. Place an
  `og_stims_crate_machine` (Q menu > Entities > OG_Core, superadmin) in the casino and run
  `og_stims_savemachines`; it respawns every map load. Press E on it for the shop: odds and pity
  progress are shown, **Buy & Open** charges the player, rolls server-side and plays a scrolling
  reel. Buying needs a machine within `OG_Stims.MachineRange`; crates a player already owns
  (event/admin rewards) can be opened anywhere from the Lootboxes tab.
- **Pity:** per player, per crate, persisted. The Nth open without a drop of `pity.rarity` or
  better is forced to that rarity or better.
- **Playtime points** come from OG_core (`sv_playtime.lua`): 1 point per 15 minutes of active,
  non-AFK play (tune in `OG.Config.Playtime`), so the Veteran case (10 points) is about 2.5 hours.
  `!playtime` shows your points and time to the next.
- **Admin commands (SAM):** `og_stims_give` / `og_stims_revoke` (stim or crate ids),
  `og_stims_reset` (inventory, loadout, pity), `og_stims_savemachines`, `og_stims_clearmachines`.
- **Buffs** go through `OG.Stats`, so skilltrees' hooks (health, armor, regen, fire rate, reload,
  damage, salary, XP) pick them up with no changes on its side.
- **Icons:** `materials/og_stims/*.png` (nine bonuses + crate) are drawn on rarity-coloured tiles
  (`cl_icons.lua`). Clients need the PNGs: publish `og_stims_content` as a Workshop item and add
  it to `workshop.lua`, or set `OG_Stims.IconsViaFastDL = true` and serve them from FastDL.
- **Buff bar (top right):** one card per active stim - name, what it gives, and the icon with the
  time left beneath it (flashes red in the last 30s). Position and size are in `OG_Stims.HUD`.
  Time only counts down while the player is online, and active buffs survive reconnects and
  restarts.

Data persists per-SteamID via `OG.DataStore` (PData/JSON), the same model as skilltrees.
