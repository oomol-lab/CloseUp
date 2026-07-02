# CloseUp Release Runbook

Contributor-only doc (English). Everything needed to take CloseUp from a clean
repo to a signed, notarized, auto-updating release. Steps can be half-done and
fail silently months later — treat this as the audit checklist.

> Status: the release pipeline (`.github/workflows/release.yml`) has **not** been
> exercised end-to-end yet. Do a throwaway release and verify an actual update
> install (see "First release" and "Update lab") before trusting it for users.

## 1. One-time setup

### 1.1 Sparkle EdDSA signing key

Sparkle verifies every update with an EdDSA (ed25519) signature. The **public**
key is embedded in every shipped build (`Info.plist` → `SUPublicEDKey`); the
**private** key signs the appcast in CI and must never be committed.

CloseUp uses its **OWN dedicated key**, stored under the keychain account
`com.oomol.CloseUp` (NOT the global `ed25519` account that LockIME and other apps
share) — so a key compromise or rotation is scoped to CloseUp alone. **Always pass
`--account com.oomol.CloseUp`** for any CloseUp key operation, or you will read/export
the wrong (shared) key.

```bash
# The tool ships inside the resolved Sparkle artifact after a build:
GENKEYS="$(find build/DerivedData/SourcePackages/artifacts -name generate_keys -type f | head -1)"
ACCT=com.oomol.CloseUp
"$GENKEYS" --account "$ACCT" -p                 # print CloseUp's public key (must match Info.plist SUPublicEDKey)
"$GENKEYS" --account "$ACCT"                     # generate it (only if it does NOT exist yet); prints the public key
"$GENKEYS" --account "$ACCT" -x "$(mktemp -u)"   # export the private key to a fresh path for the CI secret, then delete it
```

- The current public key is `87rgPjb6NxOUggn75Yv7iRylvHlLoViERAv3tRJ5JvM=` — it must
  match `Sources/CloseUp/Info.plist` → `SUPublicEDKey` (CI/Sparkle reject a mismatch).
- `generate_keys --account com.oomol.CloseUp -x <FRESH-PATH>` exports the private key.
  Use a path that does **not** exist yet (`mktemp -u`): `-x` refuses to overwrite an
  existing file and silently produces a 0-byte export otherwise. Pipe the file into
  `gh secret set SPARKLE_EDDSA_PRIVATE_KEY -R oomol-lab/CloseUp`, then delete it.
- Regenerating/changing the key breaks updates for everything already shipped with the
  old public key (they can't verify the new signatures) — **back the private key up**.
  CloseUp deliberately rotated from the shared key to this dedicated one once, while
  only `≤0.1.0-beta.2` (all orphaned anyway) existed, so that break cost nothing.

### 1.2 GitHub secrets

| Secret | Purpose |
|---|---|
| `MACOS_CERTIFICATE` | base64 of the Developer ID Application `.p12` |
| `MACOS_CERTIFICATE_PWD` | password for that `.p12` |
| `MACOS_NOTARIZATION_KEY` | base64 of the App Store Connect API key `.p8` (include the BEGIN/END lines before encoding) |
| `MACOS_NOTARIZATION_KEY_ID` | the API key's Key ID |
| `MACOS_NOTARIZATION_ISSUER_ID` | the API key's Issuer ID |
| `SPARKLE_EDDSA_PRIVATE_KEY` | the ed25519 private key from §1.1 |

Notarize with a non-expiring **API key**, not an Apple-ID password. The `.p8`
downloads exactly once. The signing team is `PWJ9VF7HHT` (oomol-lab), hardcoded
in `release.yml` and `scripts/ci/ExportOptions.plist`.

### 1.3 GitHub Pages (the appcast host)

The tiny symmetric per-arch appcasts (`appcast-arm64.xml`, `appcast-x86_64.xml`)
are served from the `gh-pages` branch; the binaries live on the Release CDN
(separate failure domains). After the first release creates the branch, **enable
Pages** in repo Settings → Pages → Deploy from branch → `gh-pages` / root. Pushing
the branch does **not** enable Pages — an unenabled feed URL 404s forever and the
app silently never updates. Each binary resolves its own feed at compile time
(`UpdaterDelegate.feedURLString`, see §5):
`https://oomol-lab.github.io/CloseUp/appcast-arm64.xml` (arm64) and
`…/appcast-x86_64.xml` (x86_64). The `Info.plist` `SUFeedURL` is a runtime no-op
default of `…/appcast.xml` — never read, since both arches pin their feed in
`feedURLString` — and it MUST keep the `appcast.xml` basename because CI's
`generate_appcast` derives each build's local working appcast filename from it
(§5).

## 2. Cutting a release

1. Ensure `main` is green (CI) and `SUPublicEDKey` is real (not the placeholder).
2. Actions → **Release** → Run workflow. Leave version empty to auto-bump the
   patch, or type an explicit `X.Y.Z` (must be greater than the latest stable
   tag — backfills are rejected).
3. The pipeline computes the version from tags, builds a Release archive **per
   architecture** (arm64 + x86_64), exports + signs (Developer ID), verifies each
   binary and its embedded Sparkle are thinned to that single arch, notarizes +
   staples, packages each arch's update zip and a notarized dmg, generates the
   EdDSA-signed appcast for each arch (seeded from gh-pages to preserve history),
   creates the GitHub Release at the built commit with all four artifacts, and
   publishes both appcasts.

### 2.1 Nightly (beta) channel

The beta channel is the nightly build (`nightly.yml`, daily at 01:00 UTC and on
manual dispatch). It ships the tip of `main` as a pre-release, versioned so that
**a nightly always sorts above the stable it was built after**:

- **Beta versions are `X.Y.(Z+1)-beta.N`** — the **next patch** of the latest
  stable tag, not `X.Y.Z-beta.N`. Stable `1.2.3` → nightly `1.2.4-beta.1`, and
  semver agrees (`1.2.4-beta.1 > 1.2.3`). Numbering betas off the *current*
  stable (`1.2.3-beta.N`) would sort them **below** it — the marketing version
  telling the opposite of the truth. `N` continues from the highest existing
  `-beta.*` tag for that base; every new stable moves the base and resets `N`
  (stable `1.3.0` ships → next nightly is `1.3.1-beta.1`). The base can never
  collide with an existing stable tag (if `vX.Y.(Z+1)` existed it would *be* the
  latest stable). Computed by `scripts/ci/compute_version.sh beta`.
- The **first stable release must exist** before nightlies can start (the beta
  base is derived from it); until then the nightly job skips. Scheduled runs also
  skip when nothing landed since the last tagged build.

**Channels within each feed** (both live in every `appcast-<arch>.xml`): stable
items carry no `sparkle:channel`, beta items are tagged `beta` (via
`generate_appcast --channel beta`). Stable users (`allowedChannels == []`) see
only stable items; beta users (`allowedChannels == ["beta"]`, from the Updates
pane's beta toggle) see **both** channels and are offered the highest version of
either. So a nightly user is auto-offered a newer **stable** the moment it ships
(`1.1.0 > 1.0.1-beta.1`), and stays on the beta channel afterward — the channel
is a client-side preference, untouched by installing an update. The beta channel
always tracks the newest build, whatever channel it came from.

## 3. First release (special-cases)

- There is **no** stable tag yet, so `compute_version.sh release` with an empty
  version produces `0.0.1`. The appcast seed step finds no existing feed for
  either arch and starts both fresh.
- The `gh-pages` branch does not exist; the publish step creates it. **Enable
  Pages afterwards** (§1.3) and re-verify the feed URL serves the XML.
- A half-published release (tag exists, feed missing) is the dangerous state:
  fix it before publishing anything else. Re-dispatching the same version for the
  same commit is safe (the version script allows it).
- **Never delete a published tag or release to "redo" it — cut a newer version
  instead.** GitHub releases are immutable (a burned tag name 422s on re-create),
  and `compute_version.sh` derives *both* the stable auto-bump and the beta base
  from whatever tags currently exist — so deleting a tag makes the next run
  recompute exactly that burned name and fail on every attempt until a newer
  version moves past it.

## 4. Update lab (verify before trusting)

Before a real release, exercise the updater against a local feed. The `make
update-test-*` targets are wired in the `Makefile` but the harness under
`scripts/update-lab/` is **not yet implemented** — building it out is the
recommended follow-up. At minimum, manually: build Release, host a loopback
appcast advertising a higher version signed with a throwaway key, and confirm
download → install → relaunch.

## 5. Architectures & update feeds

CloseUp ships **one app per architecture — never a universal binary** (download
size; a post-build phase thins the prebuilt fat Sparkle xcframework to the built
arch, see `scripts/thin-embedded-frameworks.sh`, wired in `project.yml`). Each
architecture is its own product line with its own **symmetric** Sparkle feed, and
**cross-architecture updates are unsupported by design**:

| Feed (gh-pages) | Architecture | Resolved by |
|---|---|---|
| `appcast-arm64.xml` | arm64 | `#if arch(arm64)` in `UpdaterDelegate.feedURLString(for:)` |
| `appcast-x86_64.xml` | x86_64 | `#if arch(x86_64)` in `UpdaterDelegate.feedURLString(for:)` |

The feed is pinned **at compile time** in the binary itself, so no build or CI
misconfiguration can ever point an Intel app at the arm64 feed (or vice versa).
The workflow keeps the two disjoint structurally: each arch has its own
`build/dist-<arch>/` scan root for `generate_appcast`, seeded from its own
gh-pages feed file, so a feed can only ever see its own architecture's archive.
Both channels (stable/beta) live within each feed.

The LOCAL working file inside each `build/dist-<arch>/` is always `appcast.xml`
(the arch is already in the directory name). `generate_appcast` derives that
filename from the app's `SUFeedURL` basename — which is why `Info.plist`'s
`SUFeedURL` must stay `…/appcast.xml`; the per-arch name (`appcast-<arch>.xml`)
is applied ONLY at the gh-pages boundary (seed-source + publish-destination).
This mirrors LockIME's pipeline. Do **not** force a per-arch local name with
`-o`, and do not make arm64's feed `appcast.xml` (LockIME does, but its legacy
was arm64-only; CloseUp's universal `0.1.0` also runs on Intel, so `appcast.xml`
must stay a frozen orphan that the pipeline never writes).

> **0.1.0 is an orphan, by design.** The released `0.1.0` was a *universal* build
> whose baked `SUFeedURL` is the old `appcast.xml`. The per-arch feeds are new
> files (`appcast-arm64.xml` / `appcast-x86_64.xml`), so `0.1.0` is **not carried
> forward and cannot auto-update** — this is intentional, there is no
> compatibility shim. The stale `appcast.xml` can be left on `gh-pages` or
> deleted; the pipeline never writes it again.

## 6. Known limitations / follow-ups

- **Sparkle's transient update dialogs** (the "update available" / progress
  windows) render in the **system** language, not CloseUp's in-app override —
  Sparkle's standard user driver resolves its own bundle against the system
  locale. CloseUp's own update surfaces (Settings → Updates, the menu item) are
  fully localized. A custom `SPUUserDriver` rendering native SwiftUI in the app
  language is the fix; it's deferred.
- The update lab harness is not yet ported.
- The release pipeline is **additive and untested end-to-end** — see the status
  note at the top.
