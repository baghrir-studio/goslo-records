# goslo records

Career RPG for a fictional French rapper. SwiftUI, iOS 17+, iPhone only, 100% offline.
Every character is a fictional **archetype**: no real names, no real lyrics, no real events.

## Run it

Open `GosloRecords.xcodeproj` in Xcode 16+, pick an iPhone simulator, and press ⌘R. Run the tests with ⌘U.
To run on a real iPhone: Signing & Capabilities → choose your Team.

## The game

- **10 years = 20 semesters**, with **2 actions** per semester. Each action means picking a place on the **map**:
  Le Bunker (studio), goslo records (label), Radio Bitume (media), Le quartier, Ton téléphone (social media),
  La scène (unlocked after your first project), Chez toi.
- Each place draws an **encounter** from its own events. Each place also trains a **skill** (Plume, Flow, Scène, Business).
- Some choices are **locked** behind a skill or relationship level ("PLUME 3 REQUIS").
- **Clashes**: 4 turn-based rounds, 4 moves (Punchline/Plume, Flow/Flow, Présence/Scène, Story/Business).
  Every opponent has a weak spot and a resistance. **Yanis Tracklist** (the chroniqueur) tells you both
  once your relationship with him reaches 60.
- **Secret technique**: each side fills a gauge with the damage it deals. At 35, a once-per-clash technique
  unlocks (never misses, ignores resistances) with a short cinematic. The player's depends on their style
  (e.g. "Le Sample Interdit" for Boom bap). Opponents fire theirs automatically, defined in `cast.json` under `"secret"`.
- **Relationships** (0–100) with the cast, and **quests** with steps shown on the map (● QUÊTE).
- Each semester ends with an upkeep: −2 argent, −4 streams (`GameEngine.semesterUpkeep`).
- 4 early endings (a stat at 0) and 7 endings for finishing all 10 years, including **Héritier du trône**
  (beat Le Baron in a clash).

### The cast (cast.json)

| id | Character | Archetype |
|---|---|---|
| `le_baron` | Le Baron | Self-made mogul, master of story-trolling, final boss of the "trône" quest |
| `kolosse` | Kolosse | Neighbourhood giant, announces live challenges he never finishes |
| `le_conteur` | Le Conteur | Veteran storyteller, diss tracks "en épisodes" |
| `tenebre` | Ténèbre | Dark poet, sessions at 4am, says very little |
| `orphee` | Orphée | Literary prodigy with a collectif, surprise albums |
| `scalpel` | Scalpel | Elegant technician, surgical punchlines |
| `yanis` | Yanis Tracklist | Encyclopedic chroniqueur, host of « Le Débrief » |
| `momo`, `fred`, `karim`, `lucien`, `clara_soleil`, `lil_sauge`, `kevlar_jr`, `ptit_wifi` | | Supporting cast |

Legal rule for any new content: archetypes only. Don't use a real name, an identifying nickname or a near-copy of one,
don't stack clues that point to one real person, and don't recreate a real event involving identifiable people.
Have it reviewed by a lawyer before publishing.

## Story (story.json)

The main storyline lives in `GosloRecords/Resources/story.json`:
- `chapters`: each chapter has an intro/outro cinematic and ordered `objectives`. An objective is done when its
  `conditions` hold (same format as events). Its `trigger` says where its story event fires: a door (`location`),
  a character to talk to (`npc`), or a rival who challenges you on sight (`npc` + `"spot": true`).
- `events`: story-only events (weight 0). A choice can start a boss clash (`"boss": true, "rounds": 5,
  "level_bonus": 1`) or an interview (`"interview": "<id>"`). A clash can hit harder than usual with `"opponent_power"` (default 0.85, the Baron uses 1.2: his stats are
  already maxed). A clash result can set flags (`"set_flags"`), on top
  of the automatic `clash_gagne_<id>`: useful when the rival may already have been beaten earlier.
- `cinematics`: lists of steps, one field per step: `narration`, `say {who, text}`, `title {text, subtitle}`,
  `move` / `place {who, x, y, facing}`, `despawn`, `face`, `exclaim`, `camera {x, y}`, `camera_reset`, `fade`,
  `wait`, `sound`. `who` is `"player"` or a cast id.
- `interviews`: host, show name, starting audience, pass mark, timed questions with answers (`hype` +/−,
  optional `requires`), win/lose results.
- `radio`: "Flash goslo radio" headlines, each with optional conditions.

- `concerts`: rhythm-game shows. `venue`, `start_hype`, `pass_hype`, `songs` (`title`, `bpm`, `bars`, `density` 0–1,
  optional `interlude` with crowd `options` and their `hype`), `win`/`lose` results. Start one from a choice with
  `"concert": "<id>"`. Notes are generated from the song settings (same chart every time); the Scène skill widens
  the timing window. Scoring: perfect +4, good +2, miss −5, +1 per perfect from a 10 combo.
- `negotiations`: contract duels. `opponent` (cast id), `title`, `intro`, `start_royalties`, `target_royalties`,
  `start_patience`, `clauses` (`text` printed on the contract, `pitch` said by the opponent, 2–3 `options` with
  `royalties` and `patience` deltas, a `reaction`, optional `requires`), `walkout` line, `win`/`lose` results.
  Start one from a choice with `"negotiation": "<id>"`. Patience at 0 = they leave the table (lost, retry later).
  Each two Business levels above 1 soften every demanding answer by one patience point.
- `writings`: writing sessions in a notebook. `partner` (cast id), `title`, `intro`, `duel` (the partner attacks
  before each couplet), `boss`, `start_score`, `pass_score`, `timeout_penalty`, `rounds` (optional `attack {line,
  damage}`, `setup` = first line of the couplet, `time` in seconds, 2–4 `options` with the second `line`, its
  `score`, a `reaction` and optional `requires`), `win`/`lose` results. Start one with `"writing": "<id>"`. Every
  Plume level above 1 adds half a second; the rhyme (last word) is underlined automatically.
- `items`: collectibles given by a choice (`"give_items": ["id"]`). An item can add clash levels (`clash_bonus`)
  and/or replace the player's secret technique (`secret`). Shown in the notebook, "Objets" tab.

Map characters can appear from a given chapter with `"from_chapter": 2`, and leave once a flag is set with
`"hidden_if": "flag"` (used for the "Exil immédiat à Miami" gag). Interviews can be bosses (`"boss": true`).

Written so far: chapter 1 "En bas du bloc" (boss: Kevlar Jr.), chapter 2 "La laverie" (signing at goslo records,
mixtape, clip, Lingot's exile to Miami, the American star who says no, boss: "Le Grand Débat" TV show) and
chapter 3 "Première scène" (setlist, DJ Bobine, rehearsal, promo, soundcheck with Gégé, boss: the first concert)
and chapter 4 "Le buzz" (a cat makes your chorus go viral, Lil Sauge's opportunistic feat, boss: Kolosse's live
clash, Momo's blessing, reading the 84-page contract, boss: negotiating with Victor Contrat of Hexagone Music)
and chapter 5 "Le game" (the image meeting, writing the single with Fred, release week, Le Conteur's diss series,
Scalpel's live "autopsy" on goslo radio, boss: the pen duel against Scalpel) and chapter 6 "Le trône", the finale
(the Dôme is booked, Scalpel's red pen, DJ Bobine's second turntable, then three final bosses: the clash against the
Baron, "Le Face-à-face" on goslo radio, and the concert at the Dôme). A chapter with `"finale": true` ends the career
when its outro has been watched: the ending screen and the share card follow.
Finishing chapter N sets the flag `chapitre_N`; after the last written chapter the game is free play.

Content rule (no lawyer): fictional archetypes only. No real names or nicknames, no near-copies, no stacked clues
pointing to one real person, no recreation of real events, no car brands or named landmarks.

## Sound

All music and sound effects are synthesized in code (`GosloRecords/Audio/`): no audio files, no licences to clear.
- `Synth.swift`: kick, snare, clap, hi-hats, saturated 808, keys, chiptune pulse, vinyl crackle, risers, scratches.
- `Music.swift`: four loops on a step sequencer (lo-fi menu 80 BPM, boom bap street 90 BPM, trap battle 140 BPM,
  drill rival clashes 142 BPM) and 20 effects (text blips, footsteps, doors, hits, secret technique, goslo radio jingle…).
- `SoundEngine.swift`: AVAudioEngine playback with crossfades, "ambient" session (respects the silent switch,
  doesn't stop other apps' audio), music and effects switches saved on the device.

To tweak a beat, edit its pattern in `Music.swift` (steps 0–15 per bar, MIDI notes).

## Architecture

```
GosloRecords/
├─ App/        GosloRecordsApp + RootView (routing), AppModel (engine ⇄ store ⇄ UI glue)
├─ Engine/     PURE logic (Foundation only, no SwiftUI, no I/O)
│   ├─ Stats.swift          4 stats clamped to 0–100, counters, skills/XP
│   ├─ Rapper.swift         cities, styles (starting stats and skills)
│   ├─ World.swift          locations, characters, quests
│   ├─ GameEvent.swift      events.json model, conditions, choice requirements
│   ├─ GameState.swift      Codable state (autosaved, including mid-clash)
│   ├─ GameEngine.swift     map, encounters, choices, quests, semesters
│   ├─ Clash.swift          clash rules + commentary lines
│   ├─ Story.swift          chapters, objectives, cinematics, interviews, radio, items
│   ├─ Concert.swift        rhythm-game rules (charts, timing windows, scoring)
│   ├─ Negotiation.swift    contract negotiation rules (royalties vs patience)
│   ├─ Writing.swift        writing sessions and pen duels (couplets against the clock)
│   ├─ Ending.swift         11 endings + resolution rules
│   └─ CareerRecord.swift   finished career + share-card one-liner
├─ Data/       EventLoader (events/cast/quests.json), GameStore (JSON in Documents)
├─ Resources/  events.json, cast.json, quests.json, Assets.xcassets
└─ UI/         Theme, Home, Creation, Game (+ Map, Clash, Carnet, StatsBar), Ending, ShareCard, History
GosloRecordsTests/
├─ GameEngineTests.swift    stats, skills, conditions, map, choices, semesters, clashes, quests, endings
└─ EventsDataTests.swift    validates the 3 JSON files + simulates 1,000 careers
```

## Adding an event (events.json)

```json
{
  "id": "mon_event",
  "title": "Titre court",
  "text": "Texte de la carte. {nom} et {ville} sont remplacés automatiquement.",
  "location": "studio",
  "npc": "scalpel",
  "weight": 10,
  "unique": false,
  "conditions": {
    "min_year": 2, "max_year": 8,
    "required_flags": ["signe_goslo"], "excluded_flags": ["en_clash"],
    "min_stats": { "streams": 40 }, "max_stats": { "mental": 60 },
    "min_counters": { "projets": 1 },
    "min_skills": { "plume": 3 },
    "min_relations": { "yanis": 60 }, "max_relations": { "le_baron": 30 }
  },
  "choices": [
    {
      "label": "Texte du bouton",
      "requires": { "skills": { "plume": 5 }, "relations": { "scalpel": 50 } },
      "effects": { "streams": 10, "credibilite": -5, "argent": 0, "mental": -3 },
      "xp": { "plume": 30 },
      "relations": { "scalpel": 10 },
      "set_flags": ["mon_flag"], "clear_flags": ["en_clash"],
      "counters": { "projets": 1, "disques_or": 0, "featurings": 1 },
      "consequence": "Phrase affichée après le choix.",
      "follow_up": "id_d_un_autre_event",
      "skip_turns": 0
    },
    {
      "label": "Le clasher",
      "clash": {
        "opponent": "scalpel",
        "win":  { "effects": { "credibilite": 15 }, "consequence": "Texte si victoire." },
        "lose": { "effects": { "mental": -8 },      "consequence": "Texte si défaite." }
      },
      "consequence": "Phrase d'intro du clash."
    }
  ]
}
```

| Field | Notes |
|---|---|
| `location` | `studio`, `label`, `media`, `quartier`, `reseaux`, `scene`, `chez_toi`. Required unless `weight` is 0 |
| `npc` | cast id. The character shows on the map tile and in the card header |
| `weight` | default 10. **0 = never drawn at random**, only reachable via `follow_up` |
| `unique` | at most once per career |
| `conditions` | everything must hold; bounds inclusive; years 1–10; skills in levels 1–10 |
| `choices` | 2 or 3, at least one without `requires` |
| `requires` | locked choice, shown with the requirement |
| `xp` | keys `plume`, `flow`, `scene`, `business` (60 XP = 1 level) |
| `clash` | starts a clash; the opponent needs a `clash` profile in cast.json. A clash automatically adds 1 to `beefs`, and a win sets the flag `clash_gagne_<id>` |
| `follow_up` | event shown right away, costs no action |
| `skip_turns` | extra semesters skipped (3 for a two-year break) |

## Adding a character (cast.json)

```json
{
  "id": "nouveau", "name": "Nom fictif", "role": "Archétype", "bio": "Une ligne drôle.",
  "start_relation": 50,
  "secret": { "name": "Nom de la technique", "line": "Ce qui se passe, en une phrase drôle." },
  "clash": {
    "stats": { "punchline": 6, "flow": 6, "presence": 6, "story": 6 },
    "weakness": "presence", "resistance": "punchline",
    "taunts": ["Phrase originale 1", "Phrase originale 2"]
  }
}
```
Leave out `clash` for a character that can't be clashed. Stats run 1–10 (9–10 = boss).

## Adding a quest (quests.json)

```json
{
  "id": "ma_quete", "title": "Titre", "description": "Une ligne.",
  "conditions": { "min_year": 2 },
  "steps": [
    { "label": "Étape 1", "location": "media", "conditions": { "required_flags": ["debrief_invite"] } },
    { "label": "Étape 2", "conditions": { "min_skills": { "plume": 5 } } }
  ],
  "reward": { "effects": { "credibilite": 10 }, "xp": { "plume": 40 }, "text": "Texte de récompense." }
}
```
Steps are completed in order. Finishing a quest sets the flag `quete_<id>`.

**After an edit, run the tests (⌘U).** `EventsDataTests` catches a misspelled key or location, an unknown character,
an opponent without a clash profile, a `follow_up` pointing nowhere, a required flag that no choice ever sets,
an event where every choice is locked, a place with no always-available event, or an event that never shows up
in 1,000 simulated careers.
