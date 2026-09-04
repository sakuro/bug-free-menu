# Sync factorio-mod-scaffold Updates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring bug-free-menu's tooling, CI, and docs back in line with `factorio-mod-scaffold` changes made since the last sync (scaffold `d3dd5e6` → `e382ecf`).

**Architecture:** No application logic changes. This is a mechanical sync of scaffold's generic project tooling (task runner layout, git-archive export rules, git hooks, dependency automation, release workflow, docs) into an already-generated repo, adapted where bug-free-menu's file set or explicit non-goals (no busted) differ from scaffold's current template.

**Tech Stack:** mise (task runner/tool manager), hk (git hooks via Pkl config), Renovate, GitHub Actions, Lua 5.2 (Factorio's runtime), bash.

Full rationale for every decision below is in
`doc/superpowers/specs/2026-09-04-sync-scaffold-updates-design.md` — read it
first if a step here seems under-explained.

## Global Constraints

- Do not add busted, `.busted`, `spec/`, `tasks/test`, `.github/workflows/ci.yml`, or a `lua` mise tool — no code in this mod currently meets the "pure logic, no Factorio runtime globals" bar busted specs require. (Design §D)
- Keep `mise.toml`'s `[env]` block (`MOD_LICENSE`, `MOD_CATEGORY`, `MOD_TAGS`) — `tasks/release/portal` reads these three variables at release time. (Design §B)
- Branch protection on `main` requires 0 approving reviews (solo maintainer) and **no required status checks** — this sync adds no CI workflow, so there is no check to require. (Design §G)
- `.git/hooks/` cleanup (dangling symlinks to a removed dotfiles path) is untracked local machine state, not part of this plan.
- All work happens on branch `sync-scaffold-updates` (already created, with the design doc committed as `715b263`).

---

### Task 1: Move `menu-simulation-categories.lua` into `lib/`

**Files:**
- Create: `lib/menu-simulation-categories.lua` (moved, content unchanged)
- Delete: `menu-simulation-categories.lua`
- Modify: `data-final-fixes.lua:1`

**Interfaces:**
- Produces: `lib/menu-simulation-categories.lua`, required from Lua as `lib.menu-simulation-categories` (consumed by `data-final-fixes.lua`, and by scaffold's `.gitattributes` whitelist pattern `*/**/*.lua` in Task 3).

- [ ] **Step 1: Move the file and update the require path**

```bash
mkdir -p lib
git mv menu-simulation-categories.lua lib/menu-simulation-categories.lua
```

Edit `data-final-fixes.lua` line 1:

```lua
local categories = require("lib.menu-simulation-categories")
```

(was `require("menu-simulation-categories")`)

- [ ] **Step 2: Verify the module still resolves correctly**

Run (from repo root; uses mise's own Lua install ad hoc, without adding `lua` as a project tool — see Global Constraints):

```bash
mise exec lua@5.2.4 -- lua -e "
package.path = './?.lua;' .. package.path
local m = require('lib.menu-simulation-categories')
assert(type(m.biters) == 'table' and #m.biters > 0)
assert(type(m.pentapods) == 'table' and #m.pentapods > 0)
assert(type(m.demolishers) == 'table' and #m.demolishers > 0)
print('lib.menu-simulation-categories: ok')
"
```

Expected: `lib.menu-simulation-categories: ok`, exit code 0.

- [ ] **Step 3: Commit**

```bash
git add menu-simulation-categories.lua lib/menu-simulation-categories.lua data-final-fixes.lua
git commit -m ':recycle: Move menu-simulation-categories.lua into lib/'
```

(Staging the deleted path alongside the new one records the move; `git mv` already staged both.)

- [ ] **Step 4: Verify the archived MOD still contains the module at its new path**

```bash
git archive --format=tar HEAD | tar tf - | grep menu-simulation-categories
```

Expected: exactly one line, `lib/menu-simulation-categories.lua` (no root-level entry).

---

### Task 2: Move `scripts/` into `tasks/` for mise file-task discovery

**Files:**
- Create: `tasks/build`, `tasks/clean`, `tasks/install`, `tasks/release/github`, `tasks/release/portal`
- Delete: `scripts/build.sh`, `scripts/clean.sh`, `scripts/install.sh`, `scripts/release-github.sh`, `scripts/release-portal.sh`
- Modify: `mise.toml`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: mise tasks `build`, `clean`, `install`, `release:github`, `release:portal` (same names/behavior as before — later tasks and CI reference these by name, unchanged). `mise.toml` now has `[task_config]` in place of `[tasks.*]` blocks; Task 4 edits `[tools]`/adds `[hooks]`/`[env]` in this same file.

- [ ] **Step 1: Move each script, adding an `#MISE` metadata header**

```bash
mkdir -p tasks/release
git mv scripts/build.sh tasks/build
git mv scripts/clean.sh tasks/clean
git mv scripts/install.sh tasks/install
git mv scripts/release-github.sh tasks/release/github
git mv scripts/release-portal.sh tasks/release/portal
rmdir scripts
```

Edit `tasks/build` (insert line 2, right after the shebang):

```bash
#!/usr/bin/env bash
#MISE description="Build MOD archive"
set -euo pipefail

mod_name=$(jq -r .name info.json)
mod_version=$(jq -r .version info.json)
mkdir -p dist
archive="dist/${mod_name}_${mod_version}.zip"

if [ -f "$archive" ]; then
  stale=0
  while IFS= read -r source; do
    if [ -n "$source" ] && [ "$source" -nt "$archive" ]; then
      stale=1
      break
    fi
  done < <(git archive --format=tar HEAD | tar tf - | grep -v '/$')
  if [ "$stale" -eq 0 ]; then
    exit 0
  fi
fi

rm -f "$archive"
git archive --prefix "${mod_name}_${mod_version}/" HEAD -o "$archive"
```

Edit `tasks/clean`:

```bash
#!/usr/bin/env bash
#MISE description="Remove build artifacts"
set -euo pipefail

rm -rf dist
```

Edit `tasks/install` (two `#MISE` lines: description and depends):

```bash
#!/usr/bin/env bash
#MISE description="Install MOD locally"
#MISE depends=["build"]
set -euo pipefail

mod_name=$(jq -r .name info.json)
mod_version=$(jq -r .version info.json)
archive="dist/${mod_name}_${mod_version}.zip"
mod_dir=$(factorix path --json | jq -r .mod_dir)
cp "$archive" "$mod_dir"
```

Edit `tasks/release/github`:

```bash
#!/usr/bin/env bash
#MISE description="Create GitHub Release"
#MISE depends=["build"]
set -euo pipefail

if [ -z "${GITHUB_ACTIONS:-}" ]; then
  echo "release:github task must be run from GitHub Actions" >&2
  exit 1
fi

mod_name=$(jq -r .name info.json)
mod_version=$(jq -r .version info.json)
archive="dist/${mod_name}_${mod_version}.zip"
tag="v${mod_version}"
notes=$(factorix mod changelog extract --version "$mod_version" --json | \
  jq -r '.entries | to_entries | map("### \(.key)\n" + (.value | map("- " + .) | join("\n"))) | join("\n\n")')

gh release create "$tag" --title "${mod_name} ${tag}" --notes "$notes" "$archive"
```

Edit `tasks/release/portal`:

```bash
#!/usr/bin/env bash
#MISE description="Publish MOD to Factorio MOD Portal"
#MISE depends=["build"]
set -euo pipefail

if [ -z "${GITHUB_ACTIONS:-}" ]; then
  echo "release:portal task must be run from GitHub Actions" >&2
  exit 1
fi

mod_name=$(jq -r .name info.json)
mod_version=$(jq -r .version info.json)
archive="dist/${mod_name}_${mod_version}.zip"
source_url=$(git remote get-url origin)

factorix mod upload "$archive" \
  --category "$MOD_CATEGORY" \
  --license "$MOD_LICENSE" \
  --source-url "$source_url" \
  --description "$(cat README.md)"

factorix mod edit "$mod_name" \
  --summary "$(jq -r .description info.json)" \
  --tags "$MOD_TAGS"
```

- [ ] **Step 2: Replace `mise.toml`'s `[tasks.*]` blocks with `[task_config]`**

Remove the five `[tasks.*]` blocks (`build`, `install`, `clean`,
`"release:portal"`, `"release:github"`). In their place, right after
`[settings]`, add:

```toml
[task_config]
includes = ["tasks"]
```

Resulting full `mise.toml`:

```toml
[tools]
gh = "2.96.0"
jq = "1.8.2"
"github:sakuro/factorix" = "0.21.0"

[settings]
minimum_release_age = "3d"

[task_config]
includes = ["tasks"]

[env]
MOD_LICENSE = "default_mit"
MOD_CATEGORY = "tweaks"
MOD_TAGS = ""
```

- [ ] **Step 3: Verify task discovery and confirm executability**

```bash
test -x tasks/build && test -x tasks/clean && test -x tasks/install \
  && test -x tasks/release/github && test -x tasks/release/portal \
  && echo "all task files executable"
mise tasks ls -l
```

Expected: `all task files executable`, and the `mise tasks ls -l` output
lists `build`, `clean`, `install`, `release:github`, `release:portal` with
their descriptions (`install`, `release:github`, `release:portal` showing a
dependency on `build`).

- [ ] **Step 4: Verify the build task still works end to end**

```bash
mise run clean
mise run build
ls dist/
```

Expected: `dist/bug-free-menu_0.5.0.zip` is created, no errors.

- [ ] **Step 5: Commit**

```bash
git status --short   # sanity check: scripts/*.sh deletions and tasks/* additions both staged from `git mv`
git add tasks/ mise.toml
git commit -m ':wrench: Move task scripts into tasks/ for mise file-task discovery'
```

---

### Task 3: Convert `.gitattributes` to a whitelist model

**Files:**
- Modify: `.gitattributes`

**Interfaces:**
- Consumes: final file layout from Task 1 (`lib/menu-simulation-categories.lua`) and Task 2 (`tasks/`, no more `scripts/`).
- Produces: the `export-ignore` ruleset every later task's `git archive`-based verification relies on.

- [ ] **Step 1: Replace `.gitattributes` content**

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

- [ ] **Step 2: Commit**

```bash
git add .gitattributes
git commit -m ':wrench: Convert .gitattributes to a whitelist model'
```

- [ ] **Step 3: Verify the archive includes exactly the expected files**

```bash
listing=$(git archive --format=tar HEAD | tar tf -)

for f in README.md changelog.txt LICENSE.txt info.json \
         locale/en/bug-free-menu.cfg locale/ja/bug-free-menu.cfg \
         settings.lua data-final-fixes.lua \
         lib/menu-simulation-categories.lua thumbnail.png; do
  echo "$listing" | grep -qx "$f" \
    && echo "OK included: $f" \
    || echo "FAIL missing: $f"
done

for f in AGENTS.md CLAUDE.md CONTRIBUTING.md mise.toml .gitignore .gitattributes; do
  echo "$listing" | grep -qx "$f" \
    && echo "FAIL should be excluded: $f" \
    || echo "OK excluded: $f"
done

for prefix in tasks/ .github/ doc/; do
  echo "$listing" | grep -q "^${prefix}" \
    && echo "FAIL should be excluded: ${prefix}" \
    || echo "OK excluded: ${prefix}"
done
```

Expected: every line reads `OK ...`, no `FAIL` lines.

- [ ] **Step 4: Rebuild and sanity-check the archive contents match**

```bash
mise run clean
mise run build
unzip -l dist/bug-free-menu_0.5.0.zip | grep -E 'lib/menu-simulation-categories.lua|AGENTS.md'
```

Expected: `lib/menu-simulation-categories.lua` present under the
`bug-free-menu_0.5.0/` prefix; no `AGENTS.md` line at all.

---

### Task 4: Add hk git hooks, bump `gh`/`factorix` tool versions

**Files:**
- Create: `hk.pkl`
- Modify: `mise.toml`

**Interfaces:**
- Consumes: `mise.toml` as left by Task 2.
- Produces: local git hook config (`hook.hk-*` in `.git/config`, via `mise install`'s `postinstall` hook) that later clones/collaborators get automatically; `HK_MISE` env var relied on by any future `hk install` invocation.

- [ ] **Step 1: Add `hk.pkl`**

```pkl
amends "package://github.com/jdx/hk/releases/download/v1.57.0/hk@1.57.0#/Config.pkl"

import "package://github.com/jdx/hk/releases/download/v1.57.0/hk@1.57.0#/Builtins.pkl"
import "package://github.com/sakuro/git-hooks/releases/download/v0.1.1/git-hooks@0.1.1#/Steps.pkl" as GitHooks

hooks {
  ["commit-msg"] {
    steps {
      ["emoji-enforced"] = GitHooks.emoji_enforced
    }
  }
  ["prepare-commit-msg"] {
    steps {
      ["merge-prefix"] = GitHooks.merge_prefix
    }
  }
  ["pre-commit"] {
    steps {
      ["gitleaks"] = Builtins.gitleaks
    }
  }
  ["pre-push"] {
    steps {
      ["case-conflict"] = Builtins.check_case_conflict
      ["newlines"] = Builtins.newlines
    }
  }
}
```

- [ ] **Step 2: Update `mise.toml`**

Bump `gh` and `factorix`, add `hk`/`gitleaks` tools, add `[hooks]` and
`HK_MISE`. Resulting full file:

```toml
[tools]
gh = "2.98.0"
jq = "1.8.2"
hk = "1.57.0"
gitleaks = "8.30"
"github:sakuro/factorix" = "0.23.0"

[hooks]
postinstall = 'test -n "$CI" || hk install'

[settings]
minimum_release_age = "3d"

[task_config]
includes = ["tasks"]

[env]
HK_MISE = "1"
MOD_LICENSE = "default_mit"
MOD_CATEGORY = "tweaks"
MOD_TAGS = ""
```

- [ ] **Step 3: Install the new tools and let `postinstall` wire up hooks**

```bash
mise install
```

Expected: `hk` and `gitleaks` install successfully; since `CI` is unset
locally, `hk install` runs as part of `postinstall`.

- [ ] **Step 4: Verify the hook config was installed**

```bash
git config --get-regexp '^hook\.hk-'
```

Expected: four `hook.hk-*.command` / `.event` pairs (`commit-msg`,
`prepare-commit-msg`, `pre-commit`, `pre-push`), each `.command` invoking
`mise x -- hk run ... --from-hook` (confirming `HK_MISE=1` took effect).

- [ ] **Step 5: Commit**

```bash
git add hk.pkl mise.toml
git commit -m ':wrench: Add hk git hooks and bump gh/factorix tool versions'
```

(This commit itself will run through the newly installed `commit-msg`,
`prepare-commit-msg`, and `pre-commit` hooks — confirming they work.)

---

### Task 5: Add Renovate configuration

**Files:**
- Create: `.github/renovate.json`

**Interfaces:**
- Consumes: `hk.pkl`'s package references from Task 4 (the `customManagers` regexes match version strings inside it).
- Produces: nothing consumed elsewhere in this plan — Renovate itself reads this file once merged and enabled on GitHub.

- [ ] **Step 1: Create `.github/renovate.json`**

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

Note: unlike scaffold's own `renovate.json`, this omits the `packageRules`
entry disabling `lua` updates — bug-free-menu tracks no `lua` mise tool
(Global Constraints), so that rule would reference a nonexistent dependency.

- [ ] **Step 2: Validate JSON syntax**

```bash
jq . .github/renovate.json
```

Expected: pretty-printed JSON echoed back, no parse error.

- [ ] **Step 3: Commit**

```bash
git add .github/renovate.json
git commit -m ':heavy_plus_sign: Add Renovate configuration'
```

---

### Task 6: Stop Release Publish from pushing to protected `main`; update docs

**Files:**
- Modify: `.github/workflows/release-publish.yml`
- Modify: `AGENTS.md`
- Modify: `CONTRIBUTING.md`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: the post-Task-6 changelog contract (`changelog.txt` starts each
  inter-release period with the last released version; no auto-reopened
  `Unreleased` section) that Task 8's branch protection assumes (no
  workflow needs push access to `main` anymore).

- [ ] **Step 1: Rewrite `.github/workflows/release-publish.yml`**

Full replacement (removes the `Set git user`, `Checkout main branch`, `Add
Unreleased section to changelog.txt`, `Verify changelog.txt format`, and
`Commit and push changelog update` steps; drops the trailing summary line;
also bumps the two pinned Action versions — folding in Task 7's change for
this one file to avoid a second edit pass):

```yaml
name: Release Publish

# This workflow handles the actual MOD publishing after PR merge.
# Most validations are already performed by the Release Validation workflow.

env:
  MOD_NAME: ${{ github.event.repository.name }}

on:
  pull_request:
    types: [closed]
    branches: [main]

jobs:
  publish-release:
    if: github.event.pull_request.merged == true && startsWith(github.head_ref, 'release-v')
    runs-on: ubuntu-latest
    permissions:
      contents: write      # Required for GitHub Release creation

    environment: release   # Links to MOD Portal API key in protected environment

    steps:
    - name: Extract version from branch name
      id: version
      env:
        BRANCH_NAME: ${{ github.head_ref }}
      run: |
        VERSION=${BRANCH_NAME#release-v}
        echo "version=$VERSION" >> "$GITHUB_OUTPUT"
        echo "tag=v$VERSION" >> "$GITHUB_OUTPUT"

    - name: Checkout release tag
      uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
      with:
        ref: ${{ steps.version.outputs.tag }}
        fetch-depth: 0

    - name: Verify version consistency
      env:
        EXPECTED_VERSION: ${{ steps.version.outputs.version }}
      run: |
        FILE_VERSION="$(jq -r '.version' info.json)"
        if [ "$FILE_VERSION" != "$EXPECTED_VERSION" ]; then
          echo "❌ Error: Version mismatch. File: $FILE_VERSION, Expected: $EXPECTED_VERSION"
          exit 1
        fi
        echo "✅ Version consistency verified: $FILE_VERSION"

    - name: Setup mise
      uses: jdx/mise-action@c2a87611a18de5b3828c5652fe268e992400cb5c # v4

    - name: Build and upload MOD to Factorio MOD portal
      env:
        FACTORIO_API_KEY: ${{ secrets.FACTORIO_API_KEY }}
      run: mise run release:portal

    - name: Create GitHub Release
      env:
        GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      run: mise run release:github

    - name: Post-release summary
      run: |
        echo "🎉 Release ${{ steps.version.outputs.tag }} published successfully!"
        echo "- MOD built from tagged commit and published to Factorio MOD portal"
        echo "- GitHub release created with changelog and assets"
```

- [ ] **Step 2: Validate the workflow YAML parses**

```bash
ruby -ryaml -e "YAML.load_file('.github/workflows/release-publish.yml'); puts 'yaml ok'"
```

Expected: `yaml ok`.

- [ ] **Step 3: Update `AGENTS.md`**

Full replacement:

```markdown
# Project

Factorio MOD.

# Development

## Available tasks

Run `mise tasks ls -l` to list tasks defined in this project. The `-l` (`--local`) flag excludes tasks inherited from mise's global config, which are unrelated to this project.

## Build and Install

- `mise run install` - Install to local Factorio MOD directory. Uses `git archive` internally, so only committed files are included — commit changes before running.

## Temporary files

Use the `tmp/` directory for temporary files. Create it if it doesn't exist. It is gitignored.

## Lua source layout

Root-level Lua files are limited to the Factorio stage entry points (`settings.lua`, `data.lua`, `control.lua`, and their `-updates`/`-final-fixes` variants). Put additional Lua code in a subdirectory:

- `prototypes/` - declarative prototype definitions (`data:extend({...})`), used from both the settings stage (setting prototypes) and the data stage (item/recipe/entity/etc. prototypes)
- `lib/` - runtime code: control-stage logic and helpers shared across stages

## Release

Releases are handled by GitHub Actions workflows. Do not run `mise run release:*` tasks manually.

Changelog is managed by `factorix mod changelog` and follows Factorio's changelog.txt specification.

### What to write in changelog.txt

- Regular releases: limit entries to user-visible changes only.
- Initial release: write "Initial release" only, under the `Features` category.

### Updating the changelog during development

`Version: Unreleased` marks the not-yet-released section. The release workflow renames it to the released version and does not open a new one, so between releases `changelog.txt` starts with the last released version. Add a fresh `Unreleased` section at the top for the first user-visible change of a new cycle; put later entries in that same section.

Do not create a section for the next release version directly — version bumping is handled by the GitHub Actions release workflow.

# Document Map

- README.md: Project overview
- CONTRIBUTING.md: Pull request guidelines

# External References

- [Factorio API](https://lua-api.factorio.com/latest/)
- [Factorio Wiki](https://wiki.factorio.com/)
- [factorio-data](https://github.com/wube/factorio-data) — base game's data definitions; clone locally if needed
- Game directories (mod dir, user dir, data dir, etc.): `factorix path --json | jq -r .<field>` (e.g. `.mod_dir`)
```

(Deliberately omits scaffold's "## Tests" section — no busted in this repo,
per Global Constraints.)

- [ ] **Step 4: Update `CONTRIBUTING.md`**

Full replacement:

~~~markdown
# Contributing

When opening a pull request:

- Do not change the version in `info.json`. Version bumping is handled by the release workflow.
- Document any user-visible change in `changelog.txt` (see below).

## Changelog

`changelog.txt` uses Factorio's changelog format. On top of that, this project
marks the section for not-yet-released changes as `Version: Unreleased`. The
release workflow renames that section to the released version and does not open
a new one, so between releases the file starts with the last released version.

The first user-visible change of a new cycle therefore needs a fresh
`Unreleased` section at the top of the file:

```
---------------------------------------------------------------------------------------------------
Version: Unreleased
  Changes:
    - Describe the change here.
```

Add later entries to that same section. Do not create a section for the next
version number — the release workflow does the version bump.
~~~

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/release-publish.yml AGENTS.md CONTRIBUTING.md
git commit -m ':bug: Stop Release Publish from pushing changelog to protected main'
```

---

### Task 7: Bump Action pins in the remaining release workflows

**Files:**
- Modify: `.github/workflows/release-preparation.yml`
- Modify: `.github/workflows/release-validation.yml`

**Interfaces:**
- Consumes: nothing from earlier tasks (independent of Task 6's behavioral fix).

- [ ] **Step 1: Bump pins in `release-preparation.yml`**

Two one-line changes:

`.github/workflows/release-preparation.yml:26`, was:
```yaml
      uses: actions/checkout@93cb6efe18208431cddfb8368fd83d5badbf9bfd # v5
```
becomes:
```yaml
      uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
```

`.github/workflows/release-preparation.yml:55`, was:
```yaml
      uses: jdx/mise-action@e6a8b3978addb5a52f2b4cd9d91eafa7f0ab959d # v4
```
becomes:
```yaml
      uses: jdx/mise-action@c2a87611a18de5b3828c5652fe268e992400cb5c # v4
```

- [ ] **Step 2: Bump pins in `release-validation.yml`**

`.github/workflows/release-validation.yml:25`, was:
```yaml
      uses: actions/checkout@93cb6efe18208431cddfb8368fd83d5badbf9bfd # v5
```
becomes:
```yaml
      uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
```

`.github/workflows/release-validation.yml:108`, was:
```yaml
      uses: jdx/mise-action@e6a8b3978addb5a52f2b4cd9d91eafa7f0ab959d # v4
```
becomes:
```yaml
      uses: jdx/mise-action@c2a87611a18de5b3828c5652fe268e992400cb5c # v4
```

- [ ] **Step 3: Validate both workflow files parse, and confirm no stale pins remain**

```bash
ruby -ryaml -e "YAML.load_file('.github/workflows/release-preparation.yml'); puts 'preparation yaml ok'"
ruby -ryaml -e "YAML.load_file('.github/workflows/release-validation.yml'); puts 'validation yaml ok'"
grep -rn '93cb6efe18208431cddfb8368fd83d5badbf9bfd\|e6a8b3978addb5a52f2b4cd9d91eafa7f0ab959d' .github/workflows/ || echo "no stale pins"
```

Expected: both `yaml ok` lines, then `no stale pins`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release-preparation.yml .github/workflows/release-validation.yml
git commit -m ':arrow_up: Bump actions/checkout and jdx/mise-action pins'
```

---

### Task 8: Apply GitHub repository settings

**Files:** none (repository settings, not tracked in git — see Design §G).

**Interfaces:** none.

- [ ] **Step 1: Check current settings**

```bash
gh api repos/sakuro/bug-free-menu --jq '{allow_auto_merge, delete_branch_on_merge, has_discussions}'
gh api repos/sakuro/bug-free-menu/branches/main/protection 2>&1 || true
```

Expected (per investigation already done): `allow_auto_merge: false`,
`delete_branch_on_merge`/`has_discussions: true` already, and `Branch not
protected` (404) for `main`.

- [ ] **Step 2: Enable auto-merge**

```bash
gh api --method PATCH repos/sakuro/bug-free-menu -F allow_auto_merge=true
```

- [ ] **Step 3: Require pull requests on `main`, with no required status checks**

```bash
gh api --method PUT repos/sakuro/bug-free-menu/branches/main/protection --input - <<'PROTECTION_JSON'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
PROTECTION_JSON
```

- [ ] **Step 4: Verify**

```bash
gh api repos/sakuro/bug-free-menu --jq '.allow_auto_merge'
gh api repos/sakuro/bug-free-menu/branches/main/protection --jq '{required_pull_request_reviews, allow_force_pushes: .allow_force_pushes.enabled, allow_deletions: .allow_deletions.enabled}'
```

Expected: `true`; and an object showing
`required_approving_review_count: 0`, `allow_force_pushes: false`,
`allow_deletions: false`.

No commit — nothing here is tracked in git.

---

### Task 9: Open the pull request

**Files:** none.

- [ ] **Step 1: Push the branch**

```bash
git push -u origin sync-scaffold-updates
```

- [ ] **Step 2: Open the PR**

Use the `create-pr` skill (follows this repo's PR conventions) to open a
pull request from `sync-scaffold-updates` into `main`, summarizing Tasks
1–7 (the tracked-file changes) and noting Task 8's repository-setting
changes as already applied outside the PR's diff. Reference
`doc/superpowers/specs/2026-09-04-sync-scaffold-updates-design.md` for full
rationale.

- [ ] **Step 3: Verify**

```bash
gh pr view sync-scaffold-updates --json url,title,state
```

Expected: `state: OPEN`, a valid `url`.
