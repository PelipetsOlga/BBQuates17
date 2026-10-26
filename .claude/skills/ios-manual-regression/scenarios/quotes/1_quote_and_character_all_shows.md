# quote_and_character_all_shows
Start: current state. `launch` (cold start), no reset.

This scenario checks the random quote and the character sheet on each of the three tabs. The content is random: check its shape, and
write the quote, the character name and the status you saw into the report.

Real labels confirmed on the simulator (1.0 (1), iOS 26.2): the quote is a text in double quotes near the top of the screen; the
character name is a text over the bottom of the photo (the photo itself has no label: tap the name to open the sheet). The sheet shows
"<name>", "Portrayed By: ...", "<name> Character Info", "Born: ...", "Occupations:", "Nicknames:", the collapsed button
"Status (spoiler alert!)" (below the screen edge: `scroll down` first), and a photo pager "page 1 of N".

FOR EACH TAB, in this order: "Breaking Bad", "Better Call Saul", "El Camino":

1. tap "<tab>" -> expect the background of that tab (`see "breakingbad"` / `"bettercallsaul"` / `"elcamino"`)
2. tap "Get Random Quote" -> wait up to 20s until `texts` shows a quote (a text that starts with `"`) and a character name below it.
   `shot`: the quote is readable (not cut off), the character photo has loaded (not a spinner)
3. tap "<character name>" -> expect the sheet: `wait "Portrayed By"`, and "Born:", "Occupations:", "Nicknames:" in `texts`.
   The first line of the sheet is the same name as on the main screen
4. scroll down, then tap "Status (spoiler" -> expect a status text under it (seen on the simulator: "Alive", "Dead").
   If the status is "Dead": expect "How: ..." and "Last words: ..." too, and a death image (`shot`)
5. dismiss -> expect `see "Get Random Quote"` (the sheet is closed, the same quote is still shown)

After the three tabs: `logs` -> expect no crash report.

Success: on each tab a quote with a character photo and name appears, the character sheet opens with the info and the spoiler status,
and closes again; no crash.
