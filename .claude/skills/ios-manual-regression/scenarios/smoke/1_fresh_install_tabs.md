# fresh_install_tabs
Start: fresh install. ALWAYS run `scripts/device-qa/ios-device.sh reset --yes` first, without asking: the user has given standing permission
for this scenario (it wipes the app's local data, so the app starts as just installed).

This scenario checks that the app starts and that the three shows are reachable. Nothing is fetched from the network in this scenario.

Real labels confirmed on the simulator (1.0 (1), iOS 26.2): tabs "Breaking Bad", "Better Call Saul", "El Camino"; buttons "Get Random Quote",
"Get Random Episode"; the background image has the asset name as label: "breakingbad", "bettercallsaul", "elcamino".

1. reset --yes -> expect "data cleared"
2. launch -> expect "launched"
3. wait "Get Random Quote" 20 -> expect the main screen; `texts` shows the buttons "Get Random Quote" and "Get Random Episode" and the
   three tabs. `shot`: the Breaking Bad tab is selected, the background is the desert landscape, no quote and no spinner yet
4. `see "breakingbad"` -> expect the Breaking Bad background
5. tap "Better Call Saul" -> expect `see "bettercallsaul"`, both buttons still there, no quote shown. `shot`: the tab is selected
6. tap "El Camino" -> expect `see "elcamino"`, both buttons still there, no quote shown. `shot`: the tab is selected
7. tap "Breaking Bad" -> expect `see "breakingbad"` again
8. `logs` -> expect no crash report

Success: from a cleared state the app starts on the Breaking Bad tab, each tab shows its own background and the two buttons, nothing is
loaded before a button is tapped, no crash.
