#!/bin/bash
# Thin simctl + AXe wrapper for manual-style QA of an app installed on the iOS Simulator.
# iOS counterpart of the Android adb wrapper (menscoach-android scripts/device-qa/device.sh): same commands, same output.
# No XCUITest target, no test build: the app is driven from outside through the simulator's accessibility tree.
#
# Usage: scripts/device-qa/ios-device.sh <command> [args]
#
#   launch                  terminate the app, cold start it by bundle id, wait until it is running
#   reset --yes             DESTRUCTIVE: wipe the app's data container and privacy grants = fresh install state
#   deeplink "url"          open a deep link / universal link (cold start: terminate first), wait until the app is running
#   shot [file]             save a screenshot (default: ./device-qa-<timestamp>.png), prints the path
#   texts                   print all visible accessibility labels / values with their frames
#   see "text"              exit 0 if an element with that text is visible, 1 otherwise
#   wait "text" [seconds]   wait until the text is visible (default 15s), exit 1 on timeout
#   tap "text"              tap the center of the element with that text (exact match first, then "contains")
#   tapxy x y               tap a point in screen points (only for elements without a label)
#   type "text"             type text into the focused field (e.g. an email; never passwords or one-time codes, see SKILL.md hard rules)
#   scroll up|down          scroll the content (finger moves up = content goes down: "scroll down" shows what is below)
#   back                    swipe from the left edge (iOS has no system Back button)
#   dismiss                 swipe a sheet / modal down to close it
#   install path.app        install a simulator build (.app) over the current one, keeps app data
#   info                    print app version, build and device (for the final summary)
#   logs                    print recent crash reports and error/fault log lines of the app
#
# Environment:
#   BUNDLE  bundle id to drive (default: BBQuotes)
#   UDID    simulator to use, required when more than one simulator is booted (see `xcrun simctl list devices booted`)
#
# Text matching is case-insensitive and checks AXLabel, AXValue and title.
# Requires AXe for texts/see/wait/tap/type/scroll/back: brew install cameroncooke/axe/axe

set -u

BUNDLE="${BUNDLE:-com.opelypets.BBQuates17}"

die() { echo "error: $*" >&2; exit 2; }

command -v xcrun >/dev/null 2>&1 || die "xcrun not found (install Xcode and run xcode-select)"
command -v python3 >/dev/null 2>&1 || die "python3 not found"

need_axe() { command -v axe >/dev/null 2>&1 || die "axe not found (brew install cameroncooke/axe/axe)"; }

# Picks the one booted simulator into $UDID, like adb with exactly one device
check_device() {
    local booted count
    booted=$(xcrun simctl list devices booted -j | python3 -I -c '
import json, sys
for runtime, devs in json.load(sys.stdin)["devices"].items():
    for d in devs:
        if d["state"] == "Booted":
            print(d["udid"])')
    count=$(printf "%s" "$booted" | grep -c .)
    [[ "$count" == "0" ]] && die "no simulator booted (open Simulator.app or: xcrun simctl boot <udid>)"
    if [[ -z "${UDID:-}" ]]; then
        [[ "$count" -gt 1 ]] && die "$count simulators booted, set UDID=<udid> (xcrun simctl list devices booted)"
        UDID="$booted"
    fi
}

is_running() { xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep -q "UIKitApplication:$BUNDLE\["; }

# Accessibility tree JSON on stdout
dump_ui() { axe describe-ui --udid "$UDID" 2>/dev/null; }

# Reads the JSON from stdin. Modes: list | find <text> -> prints "x y frame label" of the best match
ui_query() {
    python3 -I -c '
import json, sys

mode = sys.argv[1]
needle = sys.argv[2].lower() if len(sys.argv) > 2 else ""
try:
    roots = json.load(sys.stdin)
except ValueError:
    sys.exit(3)

roots = roots if isinstance(roots, list) else [roots]
screen = roots[0].get("frame") or {"width": 0, "height": 0}

# Each child of the Application node is a presentation layer: the main window first, then sheets / alerts on top.
# Elements of lower layers stay in the tree while a sheet covers them, so only the top layer is tappable.
items = []
def walk(n, layer):
    label = ""
    for key in ("AXLabel", "AXValue", "title"):
        v = n.get(key)
        if isinstance(v, str) and v.strip():
            label = v.replace("\xa0", " ").replace("\n", " ").strip()
            break
    f = n.get("frame") or {}
    if label and f.get("width", 0) > 0 and f.get("height", 0) > 0:
        x, y, w, h = f["x"], f["y"], f["width"], f["height"]
        cx, cy = round(x + w / 2), round(y + h / 2)
        onscreen = 0 <= cx <= screen["width"] and 0 <= cy <= screen["height"]
        bounds = f"[{x:.0f},{y:.0f}][{x + w:.0f},{y + h:.0f}]"
        items.append((label, cx, cy, bounds, n.get("type") or "", layer, onscreen))
    for c in n.get("children") or []:
        walk(c, layer)
def fullscreen(n):
    f = n.get("frame") or {}
    return f.get("x") == 0 and f.get("y") == 0 and f.get("width") == screen["width"] and f.get("height") == screen["height"]
for r in roots:
    # Layers are full-screen siblings at the first node below the Application that branches;
    # a branch into content + tab bar (not both full-screen) is one layer
    while len(r.get("children") or []) == 1:
        r = r["children"][0]
    children = r.get("children") or []
    if sum(1 for c in children if fullscreen(c)) < 2:
        children = [r]
    for layer, c in enumerate(children):
        walk(c, layer)
top = max((i[5] for i in items if i[6]), default=0)

if mode == "list":
    for label, _, _, b, t, layer, onscreen in items:
        mark = "" if onscreen and layer == top else "  (off-screen)" if not onscreen else "  (covered)"
        print(f"{b}  {t:<12} {label!r}{mark}")
    sys.exit(0)

usable = [i for i in items if i[6] and i[5] == top]
exact = [i for i in usable if i[0].lower() == needle]
partial = [i for i in usable if needle in i[0].lower()]
hit = exact or partial
if not hit:
    sys.exit(1)
label, cx, cy, b = hit[0][:4]
print(f"{cx} {cy} {b} {label!r}")
' "$@"
}

wait_running() {
    local what="$1" i
    for i in $(seq 1 30); do
        if is_running; then
            sleep 2 # let the first frame settle
            echo "$what: $BUNDLE (running after ~${i}s)"
            return 0
        fi
        sleep 1
    done
    die "$BUNDLE is not running 30s after $what"
}

cmd_launch() {
    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
    xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null 2>&1 \
        || die "could not launch $BUNDLE (is it installed? xcrun simctl listapps $UDID | grep $BUNDLE)"
    wait_running launched
}

cmd_deeplink() {
    [[ $# -ge 1 ]] || die 'usage: deeplink "url"'
    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
    # No bundle id is passed on purpose: the URL goes through the system resolver exactly as a user tap would
    xcrun simctl openurl "$UDID" "$1" || die "could not open the link: $1"
    wait_running "deeplink opened"
}

cmd_reset() {
    [[ "${1:-}" == "--yes" ]] || die "reset wipes all local app data (login, settings) of $BUNDLE; re-run with: reset --yes"
    local data
    data=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data 2>/dev/null) || die "$BUNDLE is not installed on $UDID"
    [[ "$data" == */data/Containers/Data/Application/* ]] || die "unexpected data container path: $data"
    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
    # Same layout the system creates on install: empty Documents, Library, tmp
    rm -rf "$data/Documents" "$data/Library" "$data/tmp" "$data/SystemData"
    mkdir -p "$data/Documents" "$data/Library/Caches" "$data/Library/Preferences" "$data/tmp"
    xcrun simctl privacy "$UDID" reset all "$BUNDLE" >/dev/null 2>&1
    echo "data cleared: $BUNDLE (next launch starts as a fresh install; the simulator keychain is not touched)"
}

cmd_shot() {
    local out="${1:-device-qa-$(date +%Y%m%d-%H%M%S).png}"
    xcrun simctl io "$UDID" screenshot "$out" >/dev/null 2>&1 || die "screenshot failed"
    echo "$out"
}

cmd_texts() { need_axe; dump_ui | ui_query list; }

cmd_see() {
    [[ $# -ge 1 ]] || die 'usage: see "text"'
    need_axe
    local hit
    hit=$(dump_ui | ui_query find "$1") || { echo "NOT VISIBLE: $1"; return 1; }
    echo "visible: $hit"
}

cmd_wait() {
    [[ $# -ge 1 ]] || die 'usage: wait "text" [seconds]'
    need_axe
    local timeout="${2:-15}" i hit
    for i in $(seq 1 "$timeout"); do
        if hit=$(dump_ui | ui_query find "$1"); then
            echo "visible: $hit"
            return 0
        fi
        sleep 1
    done
    echo "TIMEOUT after ${timeout}s waiting for: $1"
    return 1
}

cmd_tap() {
    [[ $# -ge 1 ]] || die 'usage: tap "text"'
    need_axe
    local hit x y
    hit=$(dump_ui | ui_query find "$1") || { echo "NOT FOUND: $1"; return 1; }
    read -r x y _ <<<"$hit"
    axe tap -x "$x" -y "$y" --udid "$UDID" >/dev/null || die "tap failed at ($x,$y)"
    echo "tapped ($x,$y): ${hit#* * }"
}

cmd_tapxy() {
    [[ $# -ge 2 ]] || die 'usage: tapxy x y'
    need_axe
    axe tap -x "$1" -y "$2" --udid "$UDID" >/dev/null || die "tap failed at ($1,$2)"
    echo "tapped ($1,$2)"
}

cmd_type() {
    [[ $# -ge 1 ]] || die 'usage: type "text"'
    need_axe
    # The text itself is not echoed (it can be a personal email)
    axe type "$1" --udid "$UDID" >/dev/null || die "type failed"
    echo "typed ${#1} characters"
}

cmd_scroll() {
    need_axe
    case "${1:-}" in
        # axe presets are named after the finger: scroll-up = finger moves up = content below comes into view
        down) axe gesture scroll-up --udid "$UDID" >/dev/null ;;
        up)   axe gesture scroll-down --udid "$UDID" >/dev/null ;;
        *)    die 'usage: scroll up|down' ;;
    esac
    echo "scrolled ${1}"
}

cmd_back() {
    need_axe
    axe gesture swipe-from-left-edge --udid "$UDID" >/dev/null || die "swipe failed"
    echo "swiped from the left edge"
}

cmd_dismiss() {
    need_axe
    local w h top
    # Start just below the top edge of the sheet, at the left margin: a swipe inside a scroll view only scrolls it
    read -r w h top < <(dump_ui | python3 -I -c '
import json, sys
r = json.load(sys.stdin)[0]
screen = r["frame"]
while len(r.get("children") or []) == 1:
    r = r["children"][0]
layers = r.get("children") or [r]
# The sheet is the full-width, at least half-height container lowest down in the top layer
top = 0
def walk(n):
    global top
    f = n.get("frame") or {}
    if f.get("y", -1) >= 0 and f.get("width") == screen["width"] and f.get("height", 0) >= screen["height"] / 2:
        top = max(top, f["y"])
    for c in n.get("children") or []:
        walk(c)
walk(layers[-1])
print(round(screen["width"]), round(screen["height"]), round(top))')
    # Never start near the status bar: a swipe from there opens Notification Center over the app
    [[ "$top" -ge 40 ]] || die "no sheet on screen (the top layer starts at y=$top); a full-screen cover needs its own close button"
    axe swipe --start-x 16 --start-y $((top + 40)) --end-x 16 --end-y $((h - 40)) --duration 0.4 --udid "$UDID" >/dev/null \
        || die "swipe failed"
    echo "swiped the sheet down (from y=$((top + 40)))"
}

cmd_install() {
    [[ $# -ge 1 && -d "$1" ]] || die "usage: install path/to/App.app (a simulator build)"
    xcrun simctl install "$UDID" "$1" || die "install failed: $1"
    echo "installed: $1"
}

app_plist() {
    local app
    app=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" app 2>/dev/null) || die "$BUNDLE is not installed on $UDID"
    echo "$app/Info.plist"
}

cmd_info() {
    local plist
    plist=$(app_plist)
    echo "app:     $BUNDLE"
    echo "version: $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$plist") ($(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$plist"))"
    xcrun simctl list devices -j | python3 -I -c '
import json, sys
udid = sys.argv[1]
for runtime, devs in json.load(sys.stdin)["devices"].items():
    for d in devs:
        if d["udid"] == udid:
            os = runtime.rsplit(".", 1)[-1].replace("iOS-", "iOS ").replace("-", ".")
            print("device:  " + d["name"] + " simulator, " + os)' "$UDID"
}

cmd_logs() {
    local exe
    exe=$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$(app_plist)")
    echo "== crash reports (last 60 min) =="
    find "$HOME/Library/Logs/DiagnosticReports" -name "${exe}*" -mmin -60 2>/dev/null | while read -r f; do
        echo "-- $f"
        head -c 3000 "$f"
        echo
    done
    echo "== errors and faults (last 10 min) =="
    xcrun simctl spawn "$UDID" log show --last 10m --style compact \
        --predicate "process == \"$exe\" AND (messageType == error OR messageType == fault)" 2>/dev/null \
        | grep -v "SO_CONNECTION_IDLE" | tail -200 # simulator-only network noise on every request
}

[[ $# -ge 1 ]] || { sed -n '2,33p' "$0"; exit 2; }
check_device

cmd="$1"; shift
case "$cmd" in
    launch)   cmd_launch "$@" ;;
    deeplink) cmd_deeplink "$@" ;;
    reset)    cmd_reset "$@" ;;
    shot)     cmd_shot "$@" ;;
    texts)    cmd_texts "$@" ;;
    see)      cmd_see "$@" ;;
    wait)     cmd_wait "$@" ;;
    tap)      cmd_tap "$@" ;;
    tapxy)    cmd_tapxy "$@" ;;
    type)     cmd_type "$@" ;;
    scroll)   cmd_scroll "$@" ;;
    back)     cmd_back "$@" ;;
    dismiss)  cmd_dismiss "$@" ;;
    install)  cmd_install "$@" ;;
    info)     cmd_info "$@" ;;
    logs)     cmd_logs "$@" ;;
    *)        sed -n '2,33p' "$0"; exit 2 ;;
esac
