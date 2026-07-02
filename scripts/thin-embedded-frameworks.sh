#!/usr/bin/env bash
# Thin embedded frameworks to the single architecture being built.
#
# We ship one app per architecture (never universal — download size), but
# Sparkle's SPM artifact is a prebuilt fat xcframework (arm64 + x86_64) and
# Xcode embeds prebuilt binaries as-is — a single-arch CloseUp would still
# carry both Sparkle slices (~2.8 MB instead of ~1.4 MB). This post-build
# phase (wired up in project.yml) strips every embedded Mach-O down to $ARCHS
# and re-signs what it modified, innermost code first, per Sparkle's own
# re-signing instructions. --preserve-metadata carries each component's
# original entitlements and flags over (Downloader.xpc must keep its sandbox
# entitlement; release components keep the hardened-runtime flag).
#
# Runs for Debug and Release alike (ad-hoc "-" identity included) so the same
# path is exercised locally, by `make update-test-*`, and in CI. No-op when
# the frameworks are already thin, when ARCHS lists more than one arch, or
# when nothing is embedded. Bash 3.2 compatible (Xcode script-phase PATH).
set -euo pipefail

log() { echo "thin-frameworks: $*"; }

FRAMEWORKS_DIR="${TARGET_BUILD_DIR:?}/${FRAMEWORKS_FOLDER_PATH:?}"
if [ ! -d "$FRAMEWORKS_DIR" ]; then
    log "no embedded frameworks — nothing to do"
    exit 0
fi

read -ra WANTED <<<"${ARCHS:?}"
if [ "${#WANTED[@]}" -ne 1 ]; then
    log "ARCHS='${ARCHS}' is not single-arch — leaving frameworks fat"
    exit 0
fi
ARCH="${WANTED[0]}"

IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-${CODE_SIGN_IDENTITY:-}}"
[ -n "$IDENTITY" ] || IDENTITY="-"

# Map a thinned Mach-O to the code-signing unit that owns it: the innermost
# enclosing .xpc/.app bundle, the framework itself for its main binary, or
# the bare file for standalone tools (Sparkle's Autoupdate).
sign_unit_for() {
    local f="$1" fw="$2" rel dir
    rel="${f#"$fw"/}"
    dir="$rel"
    while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
        case "$dir" in
        *.xpc | *.app)
            printf '%s/%s\n' "$fw" "$dir"
            return
            ;;
        esac
        dir="$(dirname "$dir")"
    done
    local fwname
    fwname="$(basename "${fw%.framework}")"
    if [ "$(basename "$f")" = "$fwname" ]; then
        printf '%s\n' "$fw"
    else
        printf '%s\n' "$f"
    fi
}

shopt -s nullglob
for fw in "$FRAMEWORKS_DIR"/*.framework; do
    units_file="$(mktemp)"
    thinned=0

    # -type f skips the Versions/Current symlink farm, so each binary is
    # visited exactly once via its real path.
    while IFS= read -r -d '' f; do
        archs="$(xcrun lipo -archs "$f" 2>/dev/null || true)"
        case " $archs " in
        *" $ARCH "*) ;;
        *) continue ;; # not Mach-O, or has no slice for the target arch
        esac
        [ "$archs" = "$ARCH" ] && continue # already thin
        xcrun lipo -thin "$ARCH" "$f" -output "$f.thin"
        mv -f "$f.thin" "$f"
        sign_unit_for "$f" "$fw" >>"$units_file"
        thinned=$((thinned + 1))
    done < <(find "$fw" -type f \( -perm -u+x -o -name '*.dylib' \) -print0)

    if [ "$thinned" -eq 0 ]; then
        rm -f "$units_file"
        continue
    fi

    if [ "${CODE_SIGNING_ALLOWED:-YES}" = "NO" ]; then
        log "$(basename "$fw"): thinned $thinned binaries but CODE_SIGNING_ALLOWED=NO — skipping re-sign"
        rm -f "$units_file"
        continue
    fi

    # Thinning breaks every signature that sealed a modified binary; re-sign
    # innermost-first (more path components = deeper), framework root last.
    # Only the notarized Release (Developer ID) build needs a SECURE timestamp —
    # CI rejects unstamped Developer ID signatures. Debug — ad-hoc OR the opt-in
    # self-signed dev-cert (a non-"-" identity that is never notarized) — uses
    # --timestamp=none so an OFFLINE local build never stalls contacting Apple's
    # TSA. Keyed on CONFIGURATION, not the identity, so the dev-cert path is safe.
    if [ "$IDENTITY" = "-" ] || [ "${CONFIGURATION:-}" != "Release" ]; then
        TS=--timestamp=none
    else
        TS=--timestamp
    fi
    sort -u "$units_file" \
        | awk -F/ '{print NF "\t" $0}' | sort -rn | cut -f2- \
        | while IFS= read -r unit; do
            xcrun codesign --force --sign "$IDENTITY" \
                --preserve-metadata=entitlements,flags "$TS" "$unit"
        done
    rm -f "$units_file"

    xcrun codesign --verify --strict --deep "$fw"
    log "$(basename "$fw"): thinned $thinned binaries to $ARCH and re-signed"
done
