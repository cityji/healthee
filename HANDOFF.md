# Handoff: Zepp import and the app redesign

Written 11 Oct 2026 for the next session. Delete this file before any pull request to
the developer (`afkcodes/healthee`); it is a working note, not part of the product.

The owner is Nikhil (`cityji`). He works from a phone, in Termux, and reaches his server
with `ssh oracle`. He has no laptop. Write to him in short, plain sentences: no jargon,
no long dashes, real numbers. He called a technically correct explanation "gibberish"
once; assume he will again.

Read first, in this order: `CLAUDE.md`, `CONTRIBUTING.md`, `docs/ENGINEERING_STANDARDS.md`,
`docs/APP_DESIGN.md`, `scripts/zepp_import/README.md`, `design/mobile-preview/README.md`.

## Where everything is

| Thing | Where |
|---|---|
| His fork | `github.com/cityji/healthee` |
| The developer's repo | `github.com/afkcodes/healthee` (remote `upstream` if you add it) |
| His live server | `https://healthee.sjmcdavv.in`, Oracle Cloud, Ubuntu 24.04, containers `healthee-api` and `healthee-db` |
| Zepp importer | `scripts/zepp_import/`, launcher `scripts/zepp-import`. On his fork's `main` since pull request #1 was merged on 11 Oct |
| Redesign | branch `design/read-in-one-look` (this branch). It already contains `main` |

His fork's `main` is the developer's `main` at `8e8d600` plus the importer. Before any
new work, check whether the developer has pushed since and merge it in. He asked for that
once and it was missed; he noticed.

## Part 1: the Zepp importer

### What exists

A standard-library Python tool (3.10 or newer, nothing to install) that copies workouts
recorded in the Zepp app into Healthee: the workout itself and its GPS route. It writes
through the two endpoints the phone app uses, `POST /ingest/helio` and
`POST /api/workout/gps`. Version 0.2.0. 369 tests, run with:

```sh
python3 -m unittest discover -s scripts/zepp_import/tests -t scripts
```

It already runs with nobody at the keyboard. Every setting can come from a file:

```sh
python3 scripts/zepp-import --env-file /path/to/file --yes
```

The file holds `HEALTHEE_URL`, `HEALTHEE_EMAIL`, `HEALTHEE_PASSWORD`, `ZEPP_EMAIL`,
`ZEPP_PASSWORD`. The tool refuses a file other users can read (`chmod 600`). `--yes`
imports without asking, routes included. Exit status is 0 for success, 1 for a failure.
Running it twice imports nothing twice.

### What has NOT been proven

**Nobody has run it against a real Zepp account.** No password was ever available. What
was checked live, without credentials: Zepp accepts the sign-in request format, all 13
Zepp hosts answer the workout path, and his server answers the sign-in handshake. Zepp's
API is unofficial, so the first real run may stop with "Zepp answered ... in a way this
tool does not understand". That message is by design; `--verbose` then prints the reply's
field names and types (never values) so the parser can be fixed.

Ask him whether he has done a first manual run and what it printed.

### What he asked for next

1. **Import other useful Zepp data that Healthee does not have.**

Running the importer every night by itself was planned and then dropped: it stays a
manual command, or something he schedules himself with `--env-file`, `--yes` and `--days`.

### How to do 1

Do not start by writing code. First find out what is actually missing:

1. Read what Healthee stores and accepts: `apps/server/src/healthee/ingest/models.py`,
   `ingest/upsert.py`, `db/schema.sql`.
2. Find out what Zepp's cloud holds beyond workouts. The open-source clients named at the
   bottom of `scripts/zepp_import/README.md` are the reference for the unofficial API.
3. Write him a short list: each item, whether Healthee already gets it from the strap
   over Bluetooth, and whether importing it would double count.
4. Build only what he picks.

Rules that decide most of it. The strap already sends heart rate, sleep, steps and
auto-detected activity over Bluetooth, so importing Zepp's copy of those counts them
twice; the importer skips auto-detected activity for exactly this reason. `CLAUDE.md`
allows one definition per metric. Write only through the existing ingest endpoints, so
the server validates as it does for the app.

### Things that will bite

- **The Healthee login.** He believed Healthee has no email or password, because the
  app's welcome screen says "Healthee has no account of its own". It has one: the email
  and password typed into the app on "Sign in to your server". The password lives in his
  Supabase project (`uewgobgqqstqcoooctzp`), not on the server. If he has forgotten it,
  do not tell him to sign out of the app. To list the email, on the server:
  `docker exec healthee-db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select email from app_user where email is not null"'`
- **Never ask him to paste a password or token into a chat.** He types them into his own
  terminal.
- **CI is red on his fork for a reason that is not ours.** `Server` and `Knowledge` fail
  at "Sync dependencies" on the developer's untouched code too: `uv sync --frozen` picks
  CPython 3.15 and `onnxruntime 1.30.0` has no wheel for it. Pinning the CI's Python to
  3.13 fixes it. That is its own small change, and worth offering the developer.

## Part 2: the app redesign

### What he said is wrong with the app

1. The sleep charts look broken, and the shapes are confusing.
2. The biological-age card has a border he finds odd.
3. Charts read like a stock market: no way to tell good from bad, which direction is
   better, where his own median is, or what to do about it.
4. Recovery, sleep and movement are the key numbers and do not feel like it.
5. The chat button covers content on every screen.
6. Sleep debt is a big number with no time frame.
7. Sleep-check numbers are coloured brown and green with nothing explaining the colours.

What he likes: the Zepp app's charts (a value on every bar, a dashed average line, the
change against the last period, a word such as OPTIMAL or FAIR beside a reading) and its
night chart. He wants the design "heavily influenced" by Apple Health, Samsung Health and
Whoop. He likes the app's own theme system and wants it kept; themes follow the system
setting. His screenshots were sent in the previous session and are not in the repo; ask
him to resend any you need.

### The developer's rules win

`docs/APP_DESIGN.md` is binding and the developer rejects work that breaks it. Two of its
rules contradict the apps he wants copied: no single 0 to 100 score without its
breakdown, and no red, amber and green. So take the clarity from those apps, not the
look. He was told this and accepted it.

### The design, agreed so far

The developer designs in HTML first and ports to Flutter second. `design/mobile-preview/`
is that HTML design. The proposal sits beside it in three files, on the same colour
tokens: `proposal.js`, `proposal-sleep.js`, `proposal.css`. It adds three screens:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory design/mobile-preview
# then open  /#p-today   /#p-sleep   /#p-trends
```

Screenshot them with Playwright at 390 wide, in both themes, and look at them. Hide
`.bottom-nav` and `.preview-bar` for full-page shots. All numbers are invented samples.
Never put his real health data in the repo.

The grammar every screen follows:

- **Range bar.** A track, the person's own usual range shaded on it, and a mark for
  today. Used for the three key numbers, the overnight vitals and the four sleep checks.
- **A verdict in words.** "In your usual range", "Below your usual", "Within", "Late".
  Amber only where a reading is on the worse side. No traffic lights.
- **One sentence that reads the chart.** "5 of 6 nights were inside your normal range."
- **Trend card.** A tag saying which direction is better, the period's average, the
  change against the period before, a shaded band for his normal range, a value on the
  points, a dashed line for the average.
- **Night chart.** One continuous band: every minute belongs to a block, each stage on
  its own level, blocks meeting edge to edge, a thin dotted join between levels, awake
  as a short cap on top. A second panel puts heart rate above the same band and
  breathing below it, with one cursor through all three. Naps use the same band, small.

His verdict on each part:

| Part | Status |
|---|---|
| Today (`#p-today`): age card without its border, three full-width key numbers, chat button moved to the header | He said "looks good" |
| Trends (`#p-trends`) | He said "looks good" |
| Sleep (`#p-sleep`): must keep every section of the current screen | Rebuilt to keep everything. He said "go ahead build it" |
| Night chart: must be the continuous Zepp-style band, "not the dots" | Redrawn that way in the preview. He has not seen the redraw yet |

Not done in the preview:

- The age card in light mode is still a dark block. He showed a pale version he likes;
  it needs the particle animation recoloured.
- The Week, Month and 6 months buttons are drawn but do nothing.
- The "what should I do to improve this" line. It must come from the app's research
  notes (`packages/knowledge`), because the developer enforces citations.
- Activity and Insights are untouched.
- No proper study of Apple Health, Samsung Health and Whoop was done. The draft leans on
  his Zepp screenshots.

### The Flutter work

Flutter is pinned to 3.44.7 (`.github/workflows/ci.yml`). The app is `apps/mobile`.

Started, one commit (`feat(mobile): draw the night as blocks ...`): the night chart
painter, `lib/shared/charts/v02/hypnogram_painter.dart`, redrawn as the continuous band,
and its panel made 156 tall instead of 196. The analyzer is clean and the existing sleep
and chart tests pass. **It has not been rendered or looked at, and it has no tests of its
own.** Finish that first: render it, look, then add tests for the joins, the awake cap
and the edge-to-edge blocks, and update `test/features/sleep_charts_test.dart`, whose
comments still describe the old ribbon.

Looking at a screen without a phone: `test/render/render_screens.dart` writes PNGs to
`build/renders/`. Two things are broken in it. It derives the font family from the file
name, so text draws as blocks; load `Figtree` and `HealtheeSymbols` the way
`test/features/_sleep_host.dart` does. And its `pumpAndSettle` hung for nine minutes on
the Sleep screen; pump fixed durations instead. Its sample night has three stages, too
few to judge a night chart; use a realistic night.

Then, one small commit each, tests in the same commit:

1. Night chart (finish it).
2. A range-bar widget, then the four sleep checks and the overnight vitals on it.
3. Today: the age card without its border, the three key numbers at full width, the
   chat button out of the way of content.
4. The trend card, then the sleep trends on it.
5. Night detail with heart rate and breathing, and naps as bands.
6. The remaining Sleep sections, then Activity and Insights.

Show him screenshots after each step. He catches things early when he sees them.

### The test APK

He wants an APK to try. Android refuses an update signed by anyone but the developer, so
a test build cannot install over his current app. Build it as a separate app that sits
beside the real one: a different `applicationId` (the real one is `codes.afk.healthee`)
and a different name. His current app and its data stay untouched; he signs in and pairs
the strap again in the test copy. Build it with GitHub Actions on his fork or locally;
neither was started. A build needs `--dart-define=HELIO_API=https://healthee.sjmcdavv.in`.

### The pull request to the developer

He will show the developer screenshots first; they know each other. Then:

- Small pieces, each with before and after screenshots. One giant redesign will not be
  merged.
- Conventional Commits. **No Claude or Anthropic attribution on any commit**: no
  `Co-Authored-By`, no session trailer. `CONTRIBUTING.md` forbids it and a hook rejects
  it. Commits made so far are authored as "Claude"; re-author them as him before
  proposing anything upstream.
- 400 lines per file at most. Tests in the same commit. `dart format`, and
  `flutter analyze` with zero warnings.
- Remove this file.
