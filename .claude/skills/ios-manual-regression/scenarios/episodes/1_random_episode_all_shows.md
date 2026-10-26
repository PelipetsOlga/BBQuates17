# random_episode_all_shows
Start: current state. `launch` (cold start), no reset.

This scenario checks the random episode card on each of the three tabs. The content is random: check its shape, and write the title and
the season/episode you saw into the report. "El Camino" is a movie: the API returns one "episode" for it, the movie itself.

Real labels confirmed on the simulator (1.0 (1), iOS 26.2): the card shows the title, "Season X Episode Y", an image (no label), the
synopsis, "Written By: ...", "Directed By: ...", "Aired: ...".

FOR EACH TAB, in this order: "Breaking Bad", "Better Call Saul", "El Camino":

1. tap "<tab>" -> expect the background of that tab (`see "breakingbad"` / `"bettercallsaul"` / `"elcamino"`)
2. tap "Get Random Episode" -> `wait "Written By" 20`, then `texts`: expect a title, "Season ... Episode ...", "Directed By: ...",
   "Aired: ...". `shot`: the episode image has loaded, the synopsis is readable, the card does not cover the two buttons
3. tap "Get Random Quote" -> expect the episode card to be replaced by a quote (a text that starts with `"`) within 20s, and
   "Written By" no longer visible (`see "Written By"` fails)

After the three tabs: `logs` -> expect no crash report.

Success: on each tab a random episode card with all fields appears, and a quote replaces it on the next tap; no crash.
