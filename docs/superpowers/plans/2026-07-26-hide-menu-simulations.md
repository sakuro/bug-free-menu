# Hide Native-Creature Menu Simulations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let players independently hide title-screen menu simulations that feature Nauvis biters/spitters/worms, Gleba pentapods, or Vulcanus demolishers, via three startup mod settings (default: hidden).

**Architecture:** Entirely data-stage. A static Lua table (`menu-simulation-categories.lua`) maps each creature family to the vanilla/Space Age/Elevated Rails simulation names that show it. `data-final-fixes.lua` deletes the corresponding keys from `data.raw["utility-constants"]["default"].main_menu_simulations` for every category whose startup setting is `true`. No `control.lua` changes.

**Tech Stack:** Factorio 2.1 data-stage Lua (`data.lua`/`data-final-fixes.lua`/`settings.lua`), `factorix` CLI for install/mod-management, `factorio.exe --dump-data` + `jq` for verification (no Lua test framework exists in this project).

**Design doc:** `docs/superpowers/specs/2026-07-26-hide-menu-simulations-design.md`

## Global Constraints

- `factorio_version` is `2.1`; `base >= 2.1` is already a required dependency in `info.json` — do not change it.
- `space-age` and `elevated-rails` are **optional** dependencies: `? space-age >= 2.1`, `? elevated-rails >= 2.1`. The mod must work correctly with only `base` present.
- Mod setting names use the `bug-free-menu-` prefix (no other prefix, e.g. not `bfm-`): `bug-free-menu-hide-biters`, `bug-free-menu-hide-pentapods`, `bug-free-menu-hide-demolishers`.
- All three settings are `bool-setting`, `setting_type = "startup"`, `default_value = true`.
- The Nauvis setting's `localised_name` must spell out "biter, spitter, and worm" — "biter" alone is not a strong enough umbrella term (per user feedback). Pentapod and demolisher settings do not need this enumeration.
- Commit changes before running `mise run install` — it uses `git archive HEAD`, so uncommitted files are silently excluded.
- `factorix mod enable` cannot enable a mod that has no entry yet in `mod-list.json` (known bug). The first time `bug-free-menu` is installed, its `mod-list.json` entry must be added directly (see Task 1 Step 4) before `factorix mod enable`/`factorix mod list` will see it.
- `factorio.exe --dump-data` writes to the user's real Factorio `script-output` directory (via `factorix path` → `script_output_dir`). This is expected and fine — it's scratch output, not user data — but don't run it more than needed.
- The current real dev machine has `base` and `elevated-rails` enabled and `space-age` installed but **disabled**. Automated verification in this plan is written against that state (26 baseline `main_menu_simulations` keys: 23 from base + 3 from elevated-rails). If `space-age` is enabled later, counts will differ — that's expected, not a bug.

---

### Task 1: Declare optional dependencies

**Files:**
- Modify: `info.json`

**Interfaces:**
- Produces: `info.json` with `dependencies` including `"? space-age >= 2.1"` and `"? elevated-rails >= 2.1"`, consumed conceptually by later tasks (no code reads this directly, but `factorix mod check` validates it).

- [ ] **Step 1: Edit `info.json`**

Change the `dependencies` array from:

```json
  "dependencies": [
    "base >= 2.1"
  ]
```

to:

```json
  "dependencies": [
    "base >= 2.1",
    "? space-age >= 2.1",
    "? elevated-rails >= 2.1"
  ]
```

- [ ] **Step 2: Verify JSON is well-formed**

Run: `jq . info.json`
Expected: pretty-printed JSON with no error, showing the 3-element `dependencies` array.

- [ ] **Step 3: Commit**

```bash
git add info.json
git commit -m ":wrench: Declare optional space-age/elevated-rails dependencies"
```

- [ ] **Step 4: Install and register the mod**

`mise run install` only copies the zip into the mods directory — it does not register or enable it. `factorix mod enable` cannot add a missing `mod-list.json` entry (known bug), so add the entry directly first:

```bash
mise run install
MOD_LIST=$(factorix path --json | jq -r .mod_list_path)
jq --arg name "bug-free-menu" \
  '.mods |= (if any(.name == $name) then . else . + [{"name": $name, "enabled": true}] end)' \
  "$MOD_LIST" > /tmp/mod-list.json.tmp && mv /tmp/mod-list.json.tmp "$MOD_LIST"
factorix mod enable bug-free-menu -y
factorix mod check
```

Expected: `factorix mod list --json | jq '.[] | select(.name=="bug-free-menu")'` shows `"enabled": true`, and `factorix mod check` reports no errors for `bug-free-menu` (optional deps are satisfied since `elevated-rails` is enabled and `space-age`, though disabled, is a valid optional either way).

---

### Task 2: Add startup mod settings

**Files:**
- Modify: `settings.lua`
- Modify: `locale/en/bug-free-menu.cfg`

**Interfaces:**
- Produces: three startup settings — `bug-free-menu-hide-biters`, `bug-free-menu-hide-pentapods`, `bug-free-menu-hide-demolishers` — each a `bool-setting` with `default_value = true`. Task 3's `data-final-fixes.lua` reads these by exact name via `settings.startup["<name>"].value`.

- [ ] **Step 1: Replace the placeholder in `settings.lua`**

Replace the entire commented-out file content with:

```lua
data:extend({
  {
    type = "bool-setting",
    name = "bug-free-menu-hide-biters",
    setting_type = "startup",
    default_value = true,
    order = "a",
    localised_name = {"mod-setting-name.bug-free-menu-hide-biters"},
    localised_description = {"mod-setting-description.bug-free-menu-hide-biters"}
  },
  {
    type = "bool-setting",
    name = "bug-free-menu-hide-pentapods",
    setting_type = "startup",
    default_value = true,
    order = "b",
    localised_name = {"mod-setting-name.bug-free-menu-hide-pentapods"},
    localised_description = {"mod-setting-description.bug-free-menu-hide-pentapods"}
  },
  {
    type = "bool-setting",
    name = "bug-free-menu-hide-demolishers",
    setting_type = "startup",
    default_value = true,
    order = "c",
    localised_name = {"mod-setting-name.bug-free-menu-hide-demolishers"},
    localised_description = {"mod-setting-description.bug-free-menu-hide-demolishers"}
  }
})
```

- [ ] **Step 2: Add locale entries to `locale/en/bug-free-menu.cfg`**

Append these two new sections after the existing `[mod-description]` section:

```
[mod-setting-name]
bug-free-menu-hide-biters=Hide biter, spitter, and worm demos
bug-free-menu-hide-pentapods=Hide pentapod demos
bug-free-menu-hide-demolishers=Hide demolisher demos

[mod-setting-description]
bug-free-menu-hide-biters=Hides main menu simulations featuring Nauvis native creatures (biters, spitters, or worms).
bug-free-menu-hide-pentapods=Hides main menu simulations featuring Gleba native creatures (pentapods).
bug-free-menu-hide-demolishers=Hides main menu simulations featuring Vulcanus native creatures (demolishers).
```

- [ ] **Step 3: Cross-check every locale key has a matching setting name**

Run:

```bash
grep -oP '(?<=name = ")bug-free-menu-[a-z-]+' settings.lua | sort > /tmp/setting-names.txt
grep -oP '^bug-free-menu-[a-z-]+(?==)' locale/en/bug-free-menu.cfg | sort -u > /tmp/locale-names.txt
diff /tmp/setting-names.txt /tmp/locale-names.txt
```

Expected: no diff output (each setting name appears exactly once in the locale file's key list; the locale file lists each name twice — once per section — but `sort -u` collapses that).

- [ ] **Step 4: Commit**

```bash
git add settings.lua locale/en/bug-free-menu.cfg
git commit -m ":sparkles: Add startup settings to hide native-creature demos"
```

- [ ] **Step 5: Install and verify the settings are registered correctly**

```bash
mise run install
FACTORIO="/mnt/c/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe"
"$FACTORIO" --dump-data
SO="/mnt/c/Users/sakuro/AppData/Roaming/Factorio/script-output"
jq '.["bool-setting"] | {
  "bug-free-menu-hide-biters",
  "bug-free-menu-hide-pentapods",
  "bug-free-menu-hide-demolishers"
}' "$SO/mod-settings-dump.json"
```

Expected: all three keys present, each with `"setting_type": "startup"` and `"default_value": true`.

---

### Task 3: Classify simulations and filter them at data-final-fixes

**Files:**
- Create: `menu-simulation-categories.lua`
- Create: `data-final-fixes.lua`

**Interfaces:**
- Consumes: `bug-free-menu-hide-biters` / `-pentapods` / `-demolishers` startup settings from Task 2 (exact names, read via `settings.startup[name].value`).
- Produces: `data.raw["utility-constants"]["default"].main_menu_simulations` with category-matching keys removed when their setting is `true`. Nothing downstream consumes this in code — it's the final observable effect of the mod.

- [ ] **Step 1: Create `menu-simulation-categories.lua`**

```lua
return {
  biters = {
    "nauvis_mining_defense",
    "nauvis_artillery",
    "nauvis_biter_base_steamrolled",
    "nauvis_biter_base_spidertron",
    "nauvis_biter_base_artillery",
    "nauvis_biter_base_player_attack",
    "nauvis_biter_base_laser_defense",
    "nauvis_chase_player",
    "nauvis_big_defense",
    "nauvis_brutal_defeat",
  },
  pentapods = {
    "gleba_pentapod_ponds",
    "gleba_egg_escape",
    "gleba_farm_attack",
  },
  demolishers = {
    "vulcanus_crossing",
    "vulcanus_punishmnent",
  },
}
```

Note: `vulcanus_punishmnent` is spelled exactly like that (missing "e") — it matches a typo in the base game's own key name. Do not "fix" the spelling; it must match exactly or the deletion will silently no-op.

- [ ] **Step 2: Create `data-final-fixes.lua`**

```lua
local categories = require("menu-simulation-categories")

local setting_names = {
  biters = "bug-free-menu-hide-biters",
  pentapods = "bug-free-menu-hide-pentapods",
  demolishers = "bug-free-menu-hide-demolishers",
}

local simulations = data.raw["utility-constants"]["default"].main_menu_simulations

for category, setting_name in pairs(setting_names) do
  if settings.startup[setting_name].value then
    for _, simulation_name in pairs(categories[category]) do
      simulations[simulation_name] = nil
    end
  end
end
```

- [ ] **Step 3: Record the baseline key count before installing**

```bash
SO="/mnt/c/Users/sakuro/AppData/Roaming/Factorio/script-output"
jq '.["utility-constants"].default.main_menu_simulations | keys | length' "$SO/data-raw-dump.json"
```

Expected: `26` (this is the dump from Task 2's verification, still on disk; if it's missing, re-run `--dump-data` first without the new files to get a fresh baseline).

- [ ] **Step 4: Commit**

```bash
git add menu-simulation-categories.lua data-final-fixes.lua
git commit -m ":sparkles: Filter native-creature demos from the main menu"
```

- [ ] **Step 5: Install and verify the filtering behavior**

```bash
mise run install
FACTORIO="/mnt/c/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe"
"$FACTORIO" --dump-data
SO="/mnt/c/Users/sakuro/AppData/Roaming/Factorio/script-output"

jq '.["utility-constants"].default.main_menu_simulations | keys | length' "$SO/data-raw-dump.json"
```

Expected: `16` (26 baseline − 10 `biters` entries; `pentapods`/`demolishers` contribute 0 removals since `space-age` is disabled on this machine, which is exactly the "no-op when the optional mod is absent" behavior the design calls for).

- [ ] **Step 6: Verify none of the removed keys remain, and unrelated keys survive**

```bash
SO="/mnt/c/Users/sakuro/AppData/Roaming/Factorio/script-output"
jq '.["utility-constants"].default.main_menu_simulations | keys' "$SO/data-raw-dump.json" > /tmp/after-keys.json

jq -e '
  (. as $after | [
    "nauvis_mining_defense","nauvis_artillery","nauvis_biter_base_steamrolled",
    "nauvis_biter_base_spidertron","nauvis_biter_base_artillery",
    "nauvis_biter_base_player_attack","nauvis_biter_base_laser_defense",
    "nauvis_chase_player","nauvis_big_defense","nauvis_brutal_defeat"
  ] | all(. as $k | ($after | index($k)) == null))
  and
  (. as $after | ["nauvis_lab","nauvis_spider_ponds","nauvis_river_bridge"] | all(. as $k | ($after | index($k)) != null))
' /tmp/after-keys.json
```

Expected: `true` printed, and exit code `0` — confirms all 10 `biters` keys are gone and three representative untouched keys (`nauvis_lab`, `nauvis_spider_ponds`, `nauvis_river_bridge`) are still present.

---

### Task 4: Manual acceptance verification

This task cannot be automated — it requires watching the actual title screen and (optionally) toggling real mod settings through the Factorio UI. The person running this task should be the project maintainer, not an automated worker, since it involves subjective visual judgment on the ★-marked entries from the design doc.

**Files:** none (verification only).

- [ ] **Step 1: Confirm default behavior in-game**

Launch Factorio normally (not `--dump-data`) with `bug-free-menu` enabled and default settings. Watch the title screen through several simulation cycles (a few minutes). Confirm no biter/spitter/worm demo appears (the design doc lists the specific `nauvis_*` names to watch for if you want to cross-reference).

- [ ] **Step 2: Resolve the ★-marked classification entries**

From `docs/superpowers/specs/2026-07-26-hide-menu-simulations-design.md`, the entries `nauvis_artillery`, `gleba_farm_attack`, and `vulcanus_punishmnent` were classified by name/theme only, without direct scripting evidence. Since they're hidden by default, confirming them requires temporarily setting the relevant category's setting to `false` in Startup Mod Settings, restarting, and watching for that specific demo (simulations cycle through in order, so this may take a few restarts to catch the right one). If a ★ entry turns out to not show the expected creature (or an excluded entry turns out to show one), update `menu-simulation-categories.lua` and repeat Task 3's Step 5–6 verification.

- [ ] **Step 3: Confirm the "all disabled" regression case**

In Startup Mod Settings, set all three `bug-free-menu-*` settings to `false` and restart. Confirm the full vanilla/DLC demo rotation is unchanged from before this mod was installed (i.e. the mod does nothing when fully disabled).

- [ ] **Step 4: Restore settings**

Set the three settings back to `true` (the intended default for normal use) before finishing.
