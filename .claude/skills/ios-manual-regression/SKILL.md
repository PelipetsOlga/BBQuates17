---
name: ios-manual-regression
description: Manually-style QA of the BBQuotes build installed on the iOS Simulator, driven from outside through simctl + AXe (no XCUITest target, no Maestro). iOS counterpart of the Android mb-manual-regression skill. Use when asked to run a scenario, check that a screen/flow works, or smoke-test the app. Looks at the screen, taps elements by text, and verifies the next screen.
argument-hint: [scenario name or free-form steps] (empty = show the list of scenarios to choose from)
allowed-tools: Bash(scripts/device-qa/ios-device.sh *), Bash(find .claude/skills/ios-manual-regression/scenarios *), Read, Write, AskUserQuestion
---

# iOS Manual Regression (simulator build, driven from outside)

Drive the app that is **already installed on the booted simulator** (bundle id `com.opelypets.BBQuates17`) through
`scripts/device-qa/ios-device.sh`. The skill does not build or install anything; it checks the build the tester installed.

## Tools

`scripts/device-qa/ios-device.sh <command>`: `launch`, `deeplink "url"`, `reset --yes`, `shot [file]`, `texts`, `see "text"`,
`wait "text" [sec]`, `tap "text"`, `tapxy x y`, `type "text"` (emails and names only), `scroll up|down`, `back`, `dismiss`,
`info`, `logs`. Set `BUNDLE=...` to drive another app.

How it maps to the Android `device.sh`:

| Android (adb) | iOS (this script) | Note |
|---|---|---|
| `uiautomator dump` | `axe describe-ui` | accessibility tree; labels come from `accessibilityLabel` / `Text` / button titles |
| `input tap x y` | `axe tap -x -y` | coordinates are screen **points** (402x874 on iPhone 17 Pro), not pixels |
| `am force-stop` + `monkey` | `simctl terminate` + `simctl launch` | |
| `pm clear` | wipe the app data container + `simctl privacy reset` | the simulator keychain is NOT cleared |
| `KEYCODE_BACK` | `back` = swipe from the left edge, `dismiss` = swipe a sheet down | iOS has no system Back button |
| `screencap` | `simctl io screenshot` | |
| `logcat -b crash` | `~/Library/Logs/DiagnosticReports/<app>*.ips` + `log show` | |
| `dumpsys package` | `info` (Info.plist of the installed app) | |

Exactly one simulator is booted, and all work is done on it. Never pick a simulator yourself (no `UDID=...`). If the script says
zero or more than one simulator is booted, stop and tell the user instead of picking one.

Screenshots go to the scratchpad directory, never into the repo (and they are DELETED at the end of every run, see "Cleanup"): always
pass a full scratchpad path to `shot`.

## Reading `texts`

- Each line is `[x1,y1][x2,y2]  <type>  '<label>'`, in points.
- `(covered)`: the element belongs to a screen under a sheet / modal. It cannot be tapped and `tap`/`see`/`wait` ignore it.
- `(off-screen)`: the element is outside the visible area (e.g. further down a scroll view). `tap`/`see`/`wait` ignore it:
  `scroll down` first.
- Images have the asset name or the SF Symbol name as label (e.g. `breakingbad`, `car`); this tells which background is shown.
- Elements without a label (e.g. an `AsyncImage` photo) are not listed. Tap a text inside or next to them, or `tapxy`, and say so.

## Choosing a scenario (when the skill is called without an argument)

If the user invoked the skill with no argument (or with `list` / `menu` / "what scenarios are there" in any language), do NOT touch
the simulator yet. Show the list of all scenarios and let the user pick exactly one to run:

1. Print the list below as a numbered list in chat, as it is, without scanning the `scenarios/` folder.
   The name of a scenario is its path relative to `scenarios/` without `.md`. Translate the descriptions to the language the user writes in.

   | # | Scenario | Description |
   |---|---|---|
   | 1 | `smoke/1_fresh_install_tabs` | fresh install (always `reset --yes`), launch, all three tabs and both buttons are there, each tab shows its own background, nothing is loaded before a tap |
   | 2 | `quotes/1_quote_and_character_all_shows` | on each of the three tabs: random quote with character photo and name, open the character sheet, read the info, open the spoiler "Status", close the sheet |
   | 3 | `episodes/1_random_episode_all_shows` | on each of the three tabs: random episode with title, season/episode, image, synopsis, writer, director, air date; then a quote on the same tab replaces the episode |

2. KEEP THE LIST IN SYNC: whenever a scenario file is added, renamed, moved or deleted, or its title/`Start:` changes, update the table
   above in the same change. Order: by folder, then by file name. If a requested scenario is not in the table, check the folder once with
   `find .claude/skills/ios-manual-regression/scenarios -name '*.md' | sort` and fix the table.
3. Ask which one to run: the number or the name. One scenario per run.
4. After the user answers, run the chosen scenario as described below.

If the argument is given (a scenario name/path or free-form steps), skip this section.

## How to run a scenario

1. Read the scenario from `.claude/skills/ios-manual-regression/scenarios/<name>.md`, or take the steps from the user.
2. Run `info` once at the start (version, build, simulator) and keep the result for the final summary.
3. Start from a known state. `launch` always cold-starts the app. Use `reset --yes` only when the scenario says "fresh install" **and**
   the user has agreed in this conversation. Exception: `smoke/1_fresh_install_tabs` ALWAYS starts with `reset --yes`, with no question
   (standing permission, written in its `Start:` line).
   If a scenario does not define an answer, or you are in doubt on a question screen, choose the FIRST option.
4. For every step: act, then verify.
   - Act with `tap "<text>"`. Prefer labels from `texts` over coordinates. Use `tapxy` only if the element has no label, and say so.
   - Verify with `wait "<expected text>"` for the next screen, and take a `shot` and actually look at it when the check is visual
     (layout, image loaded, color, text cut off).
   - Network content (quotes, episodes, photos) is random: check its *shape* (a quote in quotes, a name, "Written By: ..."),
     not exact values, and write the values you saw into the report.
5. On any failed check: stop, save a `shot`, run `logs`, and report which step failed, what was expected, what is on screen, and any
   crash/error lines. Do not continue past a failure or retry blindly.
6. Finish with a table: step, expected, result (pass/fail), and notes.
7. After the table, always write the short "Final summary" (also when the run failed or was stopped).
8. Cleanup: at the very end of every run delete the screenshots of this run from the scratchpad (only the PNG files this run created)
   and make sure no PNG is left in the repo (`git status --short | grep png`). Tell the user in one line that they were deleted.

## Hard rules

- Never type passwords, card numbers, one-time codes or other credentials. If a step needs them (Apple ID password, Face ID, card),
  stop and ask the user to do that step in the simulator, then continue.
- Before the final confirmation of any purchase (StoreKit sheet "Subscribe" / "Buy" / "Confirm"), stop and ask the user in chat,
  even for a sandbox account. Never tap it on your own.
- Do not run `reset --yes`, uninstall, or change simulator settings unless the user asked for it (the standing permission of
  `smoke/1_fresh_install_tabs` counts as asked; it does not extend to any other scenario).
- Never swipe down from the top 40 points of the screen: on iOS that opens Notification Center over the app, and the accessibility
  tree still shows the app under it, so `texts` would lie. Use `dismiss` for sheets, it starts below that zone.
- Report what you observed. If a check could not be performed, say so instead of assuming it passed.

## When `texts` and the screen disagree

The tree comes from the app's accessibility, not from the pixels. System overlays (Notification Center, Control Center, Spotlight,
the home screen) are NOT in it: the old app screen is still listed while it is not visible. If a `tap` had no effect, or the next
`wait` times out although `texts` shows the expected screen, take a `shot` and look. If a system overlay is open, close it
(`axe gesture swipe-from-bottom-edge` or `launch`), write it down in the report, and repeat the step once.

## System dialogs

- Notification permission ("“<app>” Would Like to Send You Notifications"): always `tap "Allow"`, then check it is gone with `texts`.
  Any other permission dialog (location, camera, contacts, tracking): ask first. Not yet verified: whether system alerts show up in
  the AXe tree on this iOS version; if `texts` does not list the alert buttons, use a `shot` and `tapxy`, and say so.

## Unexpected screens on the way (close them, do not stop)

Any screen that is NOT listed in the scenario steps and appears on the way to the screen the scenario waits for: run `texts` (and a
`shot` if visual), write down its title and main content in the report as an extra row, pass it with the least committing action
(close "X" / "Close" / "Cancel" / "Not now" / "Continue", `dismiss` for a sheet, or the FIRST option on a question screen), and go on.
Stop only if it has no safe way out, or it asks for credentials or money.

## Final summary (end of every scenario run)

A few plain lines, in the language the user writes in:

1. Header facts, one line each, from `info`:
   - App: the bundle id, and which build it is (simulator Release / Debug, as the tester said)
   - Version: `CFBundleShortVersionString` and `CFBundleVersion`
   - Device: the simulator model and iOS version
   - Scenario: its name
2. Then 2-5 sentences about what was checked and what was seen (e.g. which characters and episodes came up, whether every photo
   loaded). Finish with the verdict: passed / failed at step N / stopped, and any crash found.

## Real iPhone and TestFlight (not supported yet)

This skill drives the **simulator** only, because AXe only works there. To run the same scenarios against a TestFlight build on a
real iPhone (the counterpart of the Google Play internal test on Android), the plan is to give `ios-device.sh` a second backend with
the same commands:

- `launch` / `info` / `reset`: `xcrun devicectl device process launch --terminate-existing`, `devicectl device info apps`.
  There is no `pm clear` on a real device: a fresh install means the tester deletes the app and installs it again from TestFlight.
- `texts` / `tap` / `type` / `shot`: WebDriverAgent (the XCUITest runner from Appium), signed with the team's certificate, running on the
  phone and reached over USB; its `/source`, `/wda/tap` and `/screenshot` endpoints replace AXe.

Scenarios and this file stay the same; only the backend changes.

## Scenario format

One markdown file per scenario in `scenarios/`:

```
# <name>
Start: fresh install | current state
1. tap "Get Random Quote" -> expect "<text on next screen>"
2. ...
Success: <what must be true at the end>
```
