# Sync factorio-mod-scaffold Updates — Design

## Purpose

Bring bug-free-menu's tooling/CI/docs back in line with
[factorio-mod-scaffold](https://github.com/sakuro/factorio-mod-scaffold),
covering scaffold changes made since the last sync.

## Baseline

- Last sync: bug-free-menu `8d70422`, which incorporated scaffold changes up
  to `d3dd5e6` (2026-07-27).
- Target: scaffold `e382ecf` (2026-09-03), i.e. everything from `91e6ee2`
  onward.

## A. Move root Lua files into `lib/`

`menu-simulation-categories.lua` is a non-entry-point Lua file living at the
project root. Scaffold's new `.gitattributes` whitelist (see C) only ships
root-level Factorio stage entry points (`settings.lua`, `data.lua`,
`control.lua`, and their `-updates`/`-final-fixes` variants) plus anything
under a subdirectory (`*/**/*.lua`). A root-level non-entry-point file would
silently drop out of the MOD archive under the new `.gitattributes`, breaking
`data-final-fixes.lua`'s `require` at runtime.

- Move `menu-simulation-categories.lua` → `lib/menu-simulation-categories.lua`
  (keep the hyphenated basename — Lua's `require` treats it as an opaque
  path segment, hyphens are not special).
- Update `data-final-fixes.lua`: `require("menu-simulation-categories")` →
  `require("lib.menu-simulation-categories")`.

## B. `scripts/` → `tasks/`

Scaffold moved mise task bodies from `scripts/*.sh` into extension-less
files under `tasks/`, using `#MISE description=...` / `#MISE depends=[...]`
comments for task metadata (mise's file-task discovery), and dropped the
`[tasks.*]` blocks from `mise.toml` in favor of `[task_config] includes =
["tasks"]`.

Apply the same move, keeping each script's existing body unchanged:

| From | To |
|---|---|
| `scripts/build.sh` | `tasks/build` |
| `scripts/clean.sh` | `tasks/clean` |
| `scripts/install.sh` | `tasks/install` |
| `scripts/release-github.sh` | `tasks/release/github` |
| `scripts/release-portal.sh` | `tasks/release/portal` |

Task names are unchanged (`release:portal`/`release:github` come from the
`tasks/release/` subdirectory).

`mise.toml`'s `[env]` block (`MOD_LICENSE`, `MOD_CATEGORY`, `MOD_TAGS`) is
kept — scaffold dropped it from its own `mise.toml` because `bin/initialize`
writes it into each generated repo via `mise set`, but `tasks/release/portal`
still reads these three variables, so a generated repo the sync targets
(bug-free-menu) must keep them.

## C. `.gitattributes` → whitelist model

Adopt scaffold's blacklist→whitelist rewrite, adapted to bug-free-menu's
actual file set:

```
* text=auto export-ignore

/README.md export-ignore=false

/changelog.txt export-ignore=false
/LICENSE.txt export-ignore=false

/info.json export-ignore=false

/locale/*/*.cfg export-ignore=false

/settings.lua export-ignore=false
/settings-updates.lua export-ignore=false
/settings-final-fixes.lua export-ignore=false
/data.lua export-ignore=false
/data-updates.lua export-ignore=false
/data-final-fixes.lua export-ignore=false
/control.lua export-ignore=false
*/**/*.lua export-ignore=false

/thumbnail.png export-ignore=false binary
*/**/*.png export-ignore=false binary

*/**/*.ogg export-ignore=false binary

*/ export-ignore=false
.*/ export-ignore
/tasks/ export-ignore
/doc/ export-ignore
```

Differences from scaffold's copy: no `/spec/ export-ignore` line (bug-free-menu
has no `spec/` directory — see D on why busted isn't being added). Entries for
files bug-free-menu doesn't currently have (`data.lua`, `control.lua`, etc.)
are kept for parity with scaffold and to need no further edits if those stages
are added later.

`*/**/*.lua export-ignore=false` covers `lib/menu-simulation-categories.lua`
from A.

## D. hk hooks, Renovate, tool versions — busted excluded

### hk git hooks

Add `hk.pkl` (identical to scaffold's — no mod-specific content):

- `commit-msg`: enforce emoji-prefixed commit messages
- `prepare-commit-msg`: merge-commit prefix handling
- `pre-commit`: gitleaks
- `pre-push`: case-conflict check, newline check

`mise.toml`: add `hk` and `gitleaks` to `[tools]`; add `[hooks] postinstall
= 'test -n "$CI" || hk install'`; add `[env] HK_MISE = "1"` (makes `hk
install` — whether run by postinstall or manually — generate hooks that
resolve mise-managed tools via `mise x`, without needing shell activation).

Local per-clone git hook setup (`hk install --mise`, verified against this
checkout's Git 2.55 using config-based hooks rather than `.git/hooks/`
files) is out of scope for this change — it's local machine state, not
tracked by git.

### Renovate

Add `.github/renovate.json`, copied from scaffold with one adjustment: drop
the `packageRules` entry disabling `lua` updates. That rule exists in
scaffold because its `mise.toml` pins `lua` for `luarocks`/busted; since this
sync isn't adding busted (see below), bug-free-menu tracks no `lua` tool and
the rule would be dead configuration.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "minimumReleaseAge": "3 days",
  "automerge": true,
  "platformAutomerge": true,
  "packageRules": [
    {
      "matchUpdateTypes": ["major"],
      "automerge": false
    },
    {
      "matchDepNames": ["hk", "jdx/hk"],
      "groupName": "hk"
    }
  ],
  "customManagers": [
    {
      "customType": "regex",
      "managerFilePatterns": ["/\\.pkl$/"],
      "matchStrings": [
        "package://github.com/jdx/hk/releases/download/v(?<currentValue>[^/]+)/hk@[^#\"]+"
      ],
      "datasourceTemplate": "github-releases",
      "depNameTemplate": "jdx/hk"
    },
    {
      "customType": "regex",
      "managerFilePatterns": ["/\\.pkl$/"],
      "matchStrings": [
        "package://github.com/sakuro/git-hooks/releases/download/v(?<currentValue>[^/]+)/git-hooks@[^#\"]+"
      ],
      "datasourceTemplate": "github-releases",
      "depNameTemplate": "sakuro/git-hooks"
    }
  ]
}
```

### Tool version bumps

`gh` 2.96.0 → 2.98.0, `github:sakuro/factorix` 0.21.0 → 0.23.0 (matching
scaffold's current pins).

### busted — explicitly not added

Scaffold added busted unit-test tooling (`.busted`, `spec/`, `tasks/test`,
`.github/workflows/ci.yml`, a `lua` tool pin, `luarocks install --local
busted` in `postinstall`), scoped to pure logic that doesn't touch Factorio
runtime globals (`game`, `data`, `settings`, etc.).

bug-free-menu's only code is `lib/menu-simulation-categories.lua` (a static
lookup table, not logic) and `data-final-fixes.lua` (which directly mutates
`data.raw`/reads `settings.startup` — runtime-coupled by scaffold's own
criterion). There is currently nothing meeting the bar for a busted spec.
None of busted's tooling is added in this sync. Revisit if/when the mod
grows logic worth unit-testing in `lib/`.

## E. `release-publish.yml` fix + doc updates

Scaffold fixed a bug where the release-publish workflow pushed a new
`Unreleased` changelog section straight to protected `main` (which fails
once branch protection is in place — see G). Remove, matching scaffold:

- The `Set git user` step
- The `Checkout main branch` step
- The `Add Unreleased section to changelog.txt` step
- The `Verify changelog.txt format` step
- The `Commit and push changelog update` step
- The trailing "Unreleased section added..." line from `Post-release summary`

Behavioral consequence: between releases, `changelog.txt` now starts with
the last released version (no empty `Unreleased` section). The first
user-visible change of a new cycle must add a fresh `Unreleased` section
itself.

Update docs to match scaffold's current wording:

- `AGENTS.md`: add "Available tasks" (`mise tasks ls -l`) and "Lua source
  layout" (`prototypes/` vs `lib/`) sections; reword the changelog
  subsections to explain the no-reopened-`Unreleased`-section behavior; add
  the `factorix path --json` game-directories line to External References.
  Do **not** add the "Tests" section (busted is out of scope, per D).
- `CONTRIBUTING.md`: replace the one-line changelog bullet with scaffold's
  expanded "## Changelog" section explaining the same behavior.

## F. GitHub Actions pin updates

Across `.github/workflows/{release-preparation,release-publish,release-validation}.yml`:

- `actions/checkout` v5 → v7 (pinned hash)
- `jdx/mise-action` hash bump (same v4 tag, newer pinned commit)

## G. Repository settings (not tracked in git)

Applied via `gh api`/`gh repo edit` against `sakuro/bug-free-menu`, mirroring
what scaffold's `bin/initialize` now does for newly generated repos:

Current state: `delete_branch_on_merge=true` ✓ already set,
`has_discussions=true` ✓ already set, `allow_auto_merge=false` ✗, no branch
protection on `main` ✗.

- Enable auto-merge (`allow_auto_merge=true`) — required for Renovate's
  `platformAutomerge` (D).
- Add branch protection on `main` requiring pull requests: 0 required
  approving reviews (solo maintainer, matches scaffold's own default),
  `allow_force_pushes=false`, `allow_deletions=false`, `enforce_admins=false`.
  Unlike scaffold's `bin/initialize` (which requires status check `test`,
  the busted CI job), **no required status check is set** — this sync adds
  no CI workflow (per D), so there is no `test` check to require.

## Out of scope

- busted and everything gated on it (`.busted`, `spec/`, `tasks/test`,
  `.github/workflows/ci.yml`, the `lua` tool pin, the Renovate rule
  disabling its updates) — see D.
- Local `.git/hooks/` cleanup (dangling symlinks to a since-removed dotfiles
  git-template path) — untracked, per-clone machine state, not part of the
  repository; handled separately outside version control.
