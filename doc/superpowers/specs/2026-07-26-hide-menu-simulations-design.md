# Hide Native-Creature Menu Simulations — Design

## Purpose

Factorio's title screen cycles through "menu simulations" — short scripted
demos defined in `data.raw["utility-constants"]["default"].main_menu_simulations`.
Some of these demos feature a planet's native creatures (Nauvis biters,
Gleba pentapods, Vulcanus demolishers). This mod lets players hide those
demos, independently per creature family, via startup mod settings.

## Scope

Only menu simulations added by `base`, `space-age`, and `elevated-rails` are
classified. Simulations added by other mods are out of scope and always
remain visible — this mod does not attempt to infer their content.

## Dependencies

Only `space-age` is declared as an optional dependency in `info.json`
(`? space-age >= 2.1`), documenting that this mod is aware of its content
(the `pentapods`/`demolishers` categories). `elevated-rails` is not
declared separately, for two reasons:

- `elevated-rails`'s own menu simulations (`nauvis_ship_rails`,
  `nauvis_river_bridge`, `nauvis_t_section`) are not creature-related and
  are not referenced anywhere in `menu-simulation-categories.lua` — this
  mod has no functional interest in `elevated-rails`'s content at all.
- `space-age` itself hard-depends on `elevated-rails`
  (`"elevated-rails >= 2.1.0"`, required, in `space-age`'s own
  `info.json`), so whenever `space-age` is active, `elevated-rails` is
  guaranteed active too. A separate optional dependency on it here would
  be redundant.

`base` alone is enough for the mod to load and function (with only the
`biters` category having any effect, since all `pentapods`/`demolishers`
entries come from `space-age`).

This declaration has no effect on correctness of the filtering logic —
see "Behavior without space-age/elevated-rails" below.

## Why a startup setting

`main_menu_simulations` is a data-stage table baked into `data.raw` before
any save is loaded. Runtime/per-save mod settings are not readable at data
stage, so filtering must happen in `data-final-fixes.lua` using
`settings.startup` values. This means changing a setting requires a game
restart to take effect — there is no alternative that avoids this.

## Classification

Simulation names are hardcoded into a lookup table, since Factorio provides
no metadata tagging which creatures appear in a given simulation. An
initial pass was made by grepping the base/Space Age simulation init/update
scripts (in the Factorio installation's `data/base` and `data/space-age`
directories, located via `factorix path`) for creature-creating code
(e.g. `create_entity{name = "small-biter", ...}`), but several
simulations place creatures statically in the save's binary `level.dat`,
invisible to that grep. The classification below was finalized by an
exhaustive in-game audit (2026-07-26): a temporary branch
(`verify/creature-audit`, not merged) overrode `data-final-fixes.lua` to
show exactly one named simulation at a time, bypassing category settings,
so every one of the 49 base/Space Age/Elevated Rails simulations not
already confirmed by direct script evidence could be individually watched
on the title screen.

**biters** (Nauvis: biters, spitters, worms)
- `nauvis_mining_defense`, `nauvis_biter_base_steamrolled`,
  `nauvis_biter_base_spidertron`, `nauvis_biter_base_artillery`,
  `nauvis_biter_base_player_attack`, `nauvis_biter_base_laser_defense`,
  `nauvis_chase_player`, `nauvis_big_defense`, `nauvis_brutal_defeat` —
  confirmed via direct script evidence (`create_entity{name = "...-biter"
  or "...-spitter", ...}`).
- `nauvis_train_station` — audit-confirmed: a dead creature corpse is
  visible in the bottom-right of the scene.
- `nauvis_tank_building` — audit-confirmed: a live creature appears
  (this simulation runs on the `nauvis` surface, per `space-age/data.lua`).

**pentapods** (Gleba)
- `gleba_pentapod_ponds`, `gleba_egg_escape` — confirmed via direct
  script evidence (`pentapod` in the simulation's init/update code).
- `gleba_farm_attack` — audit-confirmed (was previously ★/unconfirmed).
- `gleba_grotto` — audit-confirmed (previously assumed excluded; the
  static, script-free scene actually places pentapods in the save).

**demolishers** (Vulcanus)
- `vulcanus_crossing` — confirmed via direct script evidence
  (`create_entity{name = "small-demolisher", ...}`).
- `vulcanus_punishmnent` — audit-confirmed (was previously ★/unconfirmed;
  key name matches the base game's own typo, do not "fix" the spelling).

**Explicitly excluded** (audit-confirmed, no native creature involvement):
`nauvis_solar_power_construction`, `nauvis_lab`, `nauvis_burner_city`,
`nauvis_forest_fire`, `nauvis_oil_pumpjacks`, `nauvis_oil_refinery`,
`nauvis_early_smelting`, `nauvis_logistic_robots`, `nauvis_nuclear_power`,
`nauvis_train_junction`, `nauvis_uranium_processing`, `nauvis_artillery`
(previously ★, audit showed no creature), `nauvis_spider_ponds`
(spidertron only — not a native creature, and separately toggleable via
the base game's own arachnophobia mode), `nauvis_ship_rails`,
`nauvis_river_bridge`, `nauvis_t_section`, `nauvis_biolab`,
`nauvis_power_up`, `nauvis_bus`, `nauvis_rocket_factory`,
`gleba_agri_towers`, `vulcanus_lava_forge`, `vulcanus_sulfur_drop`,
`platform_science`, `platform_moving`, `platform_messy_nuclear`,
`fulgora_city_crossing`, `fulgora_recycling_hell`, `fulgora_nightfall`,
`fulgora_race`, `aquilo_send_help`, `aquilo_starter`.

## Mod settings

Three independent startup `bool-setting`s, default `true` (hidden by
default, matching the mod's purpose), prefixed `bug-free-menu-` to avoid
collisions with other mods' settings:

| Name | Default | Display name |
|---|---|---|
| `bug-free-menu-hide-biters` | `true` | Hide biter, spitter, and worm demos |
| `bug-free-menu-hide-pentapods` | `true` | Hide pentapod demos |
| `bug-free-menu-hide-demolishers` | `true` | Hide demolisher demos |

"Biter" alone is too narrow a term for the Nauvis creature family (which
also includes spitters and worm turrets), so the display name and
description spell out all three explicitly. Pentapod and demolisher are
each a single family name, so no equivalent enumeration is needed there.

Locale entries go in `locale/en/bug-free-menu.cfg` under
`[mod-setting-name]` / `[mod-setting-description]`, following the existing
file's structure.

## Implementation

**`menu-simulation-categories.lua`** (new file, project root): a static
Lua table mapping category name to an array of simulation names, as listed
above. Returned as a module so it can be `require`d from data stage.

**`data-final-fixes.lua`** (new file, project root): runs after base,
Space Age, and Elevated Rails have all added their entries to
`main_menu_simulations` (data-final-fixes is the last data stage).
For each category whose corresponding startup setting is `true`, deletes
the matching keys from
`data.raw["utility-constants"]["default"].main_menu_simulations`.

No changes are needed to `control.lua` or `data.lua` — this feature is
entirely data-stage.

### Behavior without space-age/elevated-rails

Verified against the installed game (`data/base`, `data/space-age`,
`data/elevated-rails`, located via `factorix path`):

- All three mods add their `main_menu_simulations` entries directly in
  their own `data.lua` (elevated-rails has no `data-updates.lua` or
  `data-final-fixes.lua` at all). Factorio's loading is staged globally
  across all active mods — every mod's `data.lua` stage completes before
  any mod's `data-final-fixes.lua` stage begins — so this mod's
  `data-final-fixes.lua` always runs after whichever of these three mods
  are actually enabled have finished adding their entries, regardless of
  inter-mod dependency order.
- `base`'s `data.lua` unconditionally ensures
  `data.raw["utility-constants"]["default"].main_menu_simulations` exists
  (creates it as `{}` if absent). Since `base` is a mandatory dependency of
  every mod, this table is always present by the time this mod's
  `data-final-fixes.lua` runs.
- Deleting a key that was never set (`simulations[name] = nil` where
  `simulations[name]` is already `nil`) is a harmless no-op in Lua.

Together, this means `menu-simulation-categories.lua` needs no
mod-presence checks (e.g. `mods["space-age"]`): with only `base` active,
the `pentapods`/`demolishers` entries simply don't exist in the table and
their deletion attempts do nothing, while `biters` filtering still works.

## Testing

Factorio menu simulations have no automated test harness; verification is
visual. `factorio.exe --dump-data` + `jq` can confirm the *structural*
effect (which keys remain in `main_menu_simulations`), but not which
simulations actually contain a creature — that requires watching the
title screen. The full classification above was already exhaustively
verified this way (see "Classification"). Remaining checks:

- With default settings (all categories hidden): watch the title screen
  through several simulation cycles and confirm no biter/pentapod/
  demolisher demo appears.
- With all three settings set to `false`: confirm the full vanilla demo
  rotation is unchanged (regression check that the mod does nothing when
  disabled).
