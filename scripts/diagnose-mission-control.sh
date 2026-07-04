#!/bin/bash
# CloseUp field diagnostic — "no overlay icons in Mission Control".
#
# Zero dependencies: runs on a stock macOS install (JXA + /usr/bin/log only).
# It captures WHERE the Dock draws Mission Control's surfaces (window layers)
# and CloseUp's own live debug log during one manual reproduction, then writes
# a single report file to send back to the developers.
#
# Usage:
#   bash diagnose-mission-control.sh          # interactive (asks you to open MC)
#   bash diagnose-mission-control.sh --auto   # non-interactive self-test (short)
#
# Output: ~/Desktop/closeup-diagnostic-<timestamp>.txt
set -u

AUTO=0
[ "${1:-}" = "--auto" ] && AUTO=1

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$HOME/Desktop/closeup-diagnostic-$STAMP.txt"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/closeup-diag.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

say() { printf '%s\n' "$*"; }
section() { printf '\n=== %s ===\n' "$*" >> "$OUT"; }

# --- JXA window dump: TSV = windowNumber pid layer owner x y w h alpha -------
cat > "$WORK/dump.js" <<'EOF'
ObjC.import("CoreGraphics");
function run() {
    const ref = $.CGWindowListCopyWindowInfo(1 /* kCGWindowListOptionOnScreenOnly */, 0);
    const arr = ObjC.deepUnwrap(ObjC.castRefToObject(ref)) || [];
    return arr.map(w => {
        const b = w.kCGWindowBounds || {};
        return [
            w.kCGWindowNumber, w.kCGWindowOwnerPID, w.kCGWindowLayer,
            (w.kCGWindowOwnerName || "?").replace(/\t/g, " "),
            Math.round(b.X || 0), Math.round(b.Y || 0),
            Math.round(b.Width || 0), Math.round(b.Height || 0),
            w.kCGWindowAlpha
        ].join("\t");
    }).join("\n");
}
EOF
dump_windows() { osascript -l JavaScript "$WORK/dump.js" 2>>"$OUT"; }

say "CloseUp Mission Control diagnostic → $OUT"
say ""

# --- 1. System / app info ----------------------------------------------------
: > "$OUT"
section "SYSTEM"
{ sw_vers; echo "arch: $(uname -m)"; echo "date: $(date -u '+%Y-%m-%d %H:%M:%SZ')"; } >> "$OUT" 2>&1

section "CLOSEUP APP"
APP="/Applications/CloseUp.app"
if [ -d "$APP" ]; then
    {
        echo "version: $(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist" 2>/dev/null) ($(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist" 2>/dev/null))"
        codesign -dv "$APP" 2>&1 | grep -E 'Identifier|Authority|Signature' || true
    } >> "$OUT"
else
    echo "NOT FOUND at $APP" >> "$OUT"
fi
RUNNING="$(pgrep -x CloseUp || true)"
echo "running pid: ${RUNNING:-NOT RUNNING}" >> "$OUT"
if [ -z "$RUNNING" ]; then
    say "⚠️  CloseUp is not running — start it (and enable it) first, then re-run."
fi
DOCK_PID="$(pgrep -x Dock || true)"
WM_PID="$(pgrep -x WindowManager || true)"
echo "Dock pid: ${DOCK_PID:-?}   WindowManager pid: ${WM_PID:-none}" >> "$OUT"

# --- 2. Window-layer dump: baseline vs Mission Control open ------------------
section "WINDOW DUMP: BASELINE (Mission Control closed)"
dump_windows > "$WORK/baseline.tsv"
sort -t$'\t' -k3,3nr -k2,2n "$WORK/baseline.tsv" >> "$OUT"

capture_mc_dump() {  # $1 = label
    sleep 1.5
    dump_windows > "$WORK/mc.tsv"
    section "WINDOW DUMP: $1"
    sort -t$'\t' -k3,3nr -k2,2n "$WORK/mc.tsv" >> "$OUT"
}

say "Opening Mission Control automatically…"
open -b com.apple.exposelauncher 2>>"$OUT" || echo "open exposelauncher FAILED" >> "$OUT"
capture_mc_dump "MISSION CONTROL OPEN (auto-trigger)"
open -b com.apple.exposelauncher 2>/dev/null || true   # toggle back closed
sleep 1

# Windows present during MC but not at baseline — where the exposé surface lives.
new_windows() {
    awk -F'\t' 'NR==FNR { seen[$1]=1; next } !($1 in seen)' "$WORK/baseline.tsv" "$WORK/mc.tsv"
}
NEW="$(new_windows)"
if [ -z "$NEW" ] && [ "$AUTO" = "0" ]; then
    say ""
    say "Auto-trigger produced no new windows — manual round needed."
    say "Press Enter, then IMMEDIATELY open Mission Control yourself (F3 / Control+↑ / 3-finger swipe up) and keep it open ~3 seconds."
    read -r
    capture_mc_dump "MISSION CONTROL OPEN (manual trigger)"
    NEW="$(new_windows)"
    say "You can close Mission Control now (Esc)."
fi

section "ANALYSIS: windows that appeared while Mission Control was open"
if [ -n "$NEW" ]; then printf '%s\n' "$NEW" >> "$OUT"; else echo "(none captured)" >> "$OUT"; fi

section "ANALYSIS: verdicts"
{
    echo "layer-0 window count: baseline=$(awk -F'\t' '$3==0' "$WORK/baseline.tsv" | wc -l | tr -d ' ') during-MC=$(awk -F'\t' '$3==0' "$WORK/mc.tsv" | wc -l | tr -d ' ')"
    if [ -n "$DOCK_PID" ]; then
        echo "Dock-owned layers baseline:  $(awk -F'\t' -v p="$DOCK_PID" '$2==p {print $3}' "$WORK/baseline.tsv" | sort -un | tr '\n' ' ')"
        echo "Dock-owned layers during MC: $(awk -F'\t' -v p="$DOCK_PID" '$2==p {print $3}' "$WORK/mc.tsv" | sort -un | tr '\n' ' ')"
    fi
    if [ -n "$WM_PID" ]; then
        echo "WindowManager-owned layers during MC: $(awk -F'\t' -v p="$WM_PID" '$2==p {print $3}' "$WORK/mc.tsv" | sort -un | tr '\n' ' ')"
    fi
    # CloseUp's open-detection signal, both generations: Dock@18 (macOS ≤26) or
    # WindowManager@19 (macOS 27+). Either one present during MC = signal intact.
    DOCK18=0; WM19=0
    [ -n "$DOCK_PID" ] && awk -F'\t' -v p="$DOCK_PID" '$2==p && $3==18 {found=1} END {exit !found}' "$WORK/mc.tsv" && DOCK18=1
    [ -n "$WM_PID" ] && awk -F'\t' -v p="$WM_PID" '$2==p && $3==19 {found=1} END {exit !found}' "$WORK/mc.tsv" && WM19=1
    if [ "$DOCK18" = "1" ]; then
        echo "VERDICT: Dock layer-18 exposé surface PRESENT during MC (macOS ≤26 signal intact)"
    elif [ "$WM19" = "1" ]; then
        echo "VERDICT: WindowManager layer-19 exposé surface PRESENT during MC (macOS 27+ signal intact; needs CloseUp ≥ the PR #5 fix)"
    else
        echo "VERDICT: NO known exposé surface during MC (neither Dock@18 nor WindowManager@19)  ← open-detection signal moved again; see the during-MC dump above"
    fi
} >> "$OUT"

# --- 3. Live CloseUp log during one manual reproduction ----------------------
LOGWIN=30
[ "$AUTO" = "1" ] && LOGWIN=5
section "LIVE LOG (debug) during manual reproduction, ${LOGWIN}s"
/usr/bin/log stream --predicate 'subsystem == "com.oomol.CloseUp"' --debug --style compact > "$WORK/live.log" 2>&1 &
LOGPID=$!
say ""
say "Live log capture started — you have ${LOGWIN} seconds. Please now:"
say "  1. Open Mission Control with the REAL trackpad gesture (3/4-finger swipe up) or F3"
say "  2. Move the cursor onto 2-3 window thumbnails, pausing ~2s on each"
say "  3. Press Esc to close Mission Control"
sleep "$LOGWIN"
# SIGINT (the streamer's Ctrl-C clean-shutdown path), not SIGTERM, so `log` runs its
# normal teardown and flushes any pending output before exiting; `wait` then reaps it.
kill -INT "$LOGPID" 2>/dev/null; wait "$LOGPID" 2>/dev/null
cat "$WORK/live.log" >> "$OUT"
if ! grep -q "com.oomol.CloseUp:" "$WORK/live.log"; then
    echo "(no live CloseUp log lines captured — is CloseUp running and enabled? was Mission Control opened during the window?)" >> "$OUT"
fi

# --- 4. Persisted notice-level history (covers reproductions before this run)
section "PERSISTED LOG (last 30 min, notice+)"
/usr/bin/log show --last 30m --predicate 'subsystem == "com.oomol.CloseUp"' --info --style compact >> "$OUT" 2>&1

say ""
say "Done. Please send this file back:"
say "  $OUT"
