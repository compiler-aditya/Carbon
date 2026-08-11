# Carbon — Demo Video Script & Shot List

In Next Gen there is no store listing, so **judges cannot download and use the app.** The video is how they see it work. Combined with the repository it is effectively the whole submission, and the rules are explicit that judges are not required to watch beyond two minutes.

One person owns this for the full seven days. Shoot it twice.

---

## Hard requirements

- **≤ 2:00.** Target 1:40 so there is room for a slower reveal if the app needs it.
- Public on YouTube or Vimeo, link on the Devpost form.
- Real device footage showing the app running on the platform it was built for.
- **No third-party trademarks. No copyrighted music.** Voiceover over silence, or silence with captions. Do not risk a takedown or a disqualification for a backing track.
- **Every feature shown must exist in the repository.** The Shipaton team said explicitly that they compare the video against the code, and a mismatch is the failure they named by name. If a feature got cut on Day 5, it does not appear in the video.

## The one rule of structure

Lead with the payoff. A judge who has watched thirty videos decides in the first ten seconds whether this one is a real app. Do not open with a logo, a title card, a problem-statement slide, or a talking head. **Open with paper and a phone.**

---

## Shot list

Total 1:42. Timecodes are targets; shoot each beat separately and cut to fit.

### 0:00–0:08 · The problem, shown not stated
Overhead, static. A filled paper register on a desk — real, ruled, handwritten. A laptop beside it with a half-typed spreadsheet. A hand types one row, checks the paper, types again.

> **VO:** "This register has to stay on paper. The spreadsheet has to exist too. So every day, someone types it twice."

*No app yet. Eight seconds of establishing that the problem is real buys you the rest of the video.*

### 0:08–0:22 · Setup, once
Phone in frame, over the register. Open Carbon → **New template** → name it "Daily Register" → mode **Table** → add five fields, typing each label and picking its type: Date, Item (text), Qty (number), Rate (currency), Amount (currency) → Save.

> **VO:** "You show Carbon the form once — its name, and what its columns are."

*Shorter than the original plan, because the **Use detected columns** assist was never built (see [As built](#as-built)). Without it this beat is honest work rather than magic, so do not linger: keep the typing tight, let the type pickers land visibly, and let the VO carry the point that this happens once per form and never again. The payoff beat is what has to breathe, not this one.*

*Type the labels rather than pasting them. A field appearing fully formed reads as a cut.*

### 0:22–0:42 · The payoff beat
Same phone, same register, now a **filled** page. Tap **Scan** → document camera → shutter → processing labels tick past — `Reading page…`, `Matching fields…`, `Checking values…` — → Review appears as a grid, one row per ruled line on the paper.

Hold on the grid for a full two seconds. Doubtful cells carry a tinted background; the rest are plain.

> **VO:** "After that, every photo of that form is just rows."

*This is the beat the entire video exists for. Everything before it is setup and everything after it is proof. If you get one shot perfect, make it this one.*

*The **signature animation does not play here** — it lives on the record-mode review screen, not in `CellGrid`. It has its own beat at 0:56. Do not narrate it over the grid; the claim would not match what is on screen.*

*`<R>` throughout this script is the number of ruled lines on the page you actually film — read it off the paper and use the same number in every VO line and on the Save button. This script used to hard-code fourteen, which was true of no register that exists.*

### 0:42–0:56 · Honesty, which is the product argument
Zoom the grid. Three cells sit tinted. Tap one → the editor opens carrying **"Read from the page as …"** → tap **Show on the page** → the photograph zooms to exactly that cell, boxed in red → the handwriting genuinely is ambiguous → type the correct value → Save → the cell loses its tint and gains a tick.

> **VO:** "It tells you what it isn't sure about, and shows you where on the page it came from. `<R>` rows, three worth checking."

*Do not hide the failures — feature them. Every competing entry will demo perfect extraction on synthetic data. Showing a real miss, and a one-tap fix, is more convincing than a flawless demo and it is the reason the correction editor exists.*

*This beat used to claim it "matches the accuracy numbers in the README". The README's accuracy table is deliberately empty — no corpus has been collected — so do not make that claim in the VO or the description. Showing a miss is convincing on its own; a judge who checks the README and finds no numbers to match would be right to hold it against the video.*

### 0:56–1:10 · The dataset accumulates, and the one moment of motion
**Save `<R>` records** → the dataset screen, scrolled, showing a few hundred existing rows **accumulated over several months**. Search a term, one result. This must not be an empty demo account — populate it beforehand with believable data.

Then tap one row. It opens as a single record, and **this is where the signature animation plays**: the values land in sequence, as if typed onto the form, and only then do the rules under them resolve into their confidence styles — solid, dashed, dotted red.

> **VO:** "It builds up as one dataset, on the device. Open a row and you get the values first — then how sure it was about each one."

*Hold two full seconds on the record after it opens. The whole animation is under half a second and a judge who blinks will miss the one piece of motion in the app. This is also the only place the confidence rules are legible at full size, so it doubles as the shot that explains the grid tints from the previous beat.*

*`Test Item 1` anywhere in this shot costs more than a missing feature. Real-looking data is a production requirement.*

**Seed the demo account so the free tier actually adds up.** The free tier is one template and twenty records *per calendar month* — so a dataset holding hundreds of rows has to have been built over months, not days, or the arithmetic on screen contradicts the README and the paywall beat that follows.

Count the rows on the register you shoot — call it **R** — and set the device up so the **current** month holds exactly **20 − R** records before this shot. Saving the page then lands the meter on 20 of 20, on camera, immediately before the export gate. That is not a workaround: a meter visibly filling to its limit and *then* the gate is a stronger, more legible version of the next beat than a lock appearing out of nowhere. Judges at a monetization company will do this arithmetic, so get it right for the page you actually filmed rather than for the one this script imagined.

### 1:10–1:24 · The money moment
Tap **Export** → the lock and the meter — now reading 20 of 20 — are visible → paywall appears → select **Annual** → purchase completes → the sheet dismisses → **the export automatically continues** → share sheet → CSV opens in Numbers with the correct columns and typed values.

> **VO:** "Free covers one form and twenty records a month. Export is where Pro starts."

*Two things must land here: that the retry is automatic (no second tap), and that the CSV is genuinely correct in Numbers. Judges at a monetization company watch the purchase flow closely — a paywall that appears and a purchase that visibly unlocks the exact thing you tried to do is the whole criterion in twelve seconds.*

### 1:24–1:34 · One platform detail
Either: **"Scan a form with Carbon"** to Siri → Carbon opens on the template and goes straight to the camera.
Or: the same app on iPad — the sidebar, and `CellGrid` filling the page with every column visible at once.

*Pick one. Two would be padding. The Siri shot is the stronger of the two because it shows the app is a citizen of the platform rather than an island.*

*Say the phrase exactly. The shortcut is registered as "Capture a form with Carbon", "Scan a form with Carbon" or "New Carbon record" — there is **no per-template phrase**, so "Hey Siri, capture Daily Register" (which this script used to specify) will not work. The intent takes a template parameter; only the spoken shortcut does not.*

*The iPad alternative used to say "editing a cell with a hardware keyboard". Keyboard navigation in the grid was deliberately not built — see `05-uiux-spec.md` §8.1 — so shoot the sidebar and the full-width grid instead, both of which are real.*

### 1:34–1:42 · Close
Return to the overhead shot from 0:00. The laptop is closed. Only the register and the phone remain.

> **VO:** "The paper stays. The typing doesn't."

Final frame, held two seconds: app name, one line — *Your form, remembered.* — and the repo URL. No music sting.

---

## As built

This script was written on Day 1, before the app existed. Every beat above has since been walked
against `main`, because the one failure the Shipaton team named by name is a video showing
something the repository does not contain. Four things had drifted:

| The script said | `main` says | What changed above |
|---|---|---|
| **Use detected columns — 5 found** prefills the template from a scanned header row | Not built. No such code exists | Setup beat is now typed by hand, and shortened from 18s to 14s |
| The signature animation plays over the grid in the payoff beat | It is on `FieldRow`, so it plays on the record-mode review screen. `CellGrid` has no animation | Moved to its own beat at 0:56, where a saved record is opened from the dataset |
| "Hey Siri, capture Daily Register" | The registered phrases are *"Capture a form with Carbon"*, *"Scan a form with Carbon"*, *"New Carbon record"*. No per-template phrase | Phrase corrected; say it exactly |
| iPad alternative shows keyboard cell navigation | Deliberately not built — `05-uiux-spec.md` §8.1 | iPad shot is the sidebar and the full-width grid |

Two further claims were quietly false and are now removed: that the honesty beat "matches the
accuracy numbers in the README" (that table is empty on purpose), and the hard-coded fourteen
rows and six seed records (the arithmetic is now expressed in terms of the page you actually
film).

### Not yet run on hardware

Every beat above is shootable, but three depend on paths that have only ever run in a simulator
or against a stub. None is a repository mismatch — the code is there — but each is a shoot-day
risk worth knowing before the tripod is up:

- **The document camera.** Never executed on a device. The whole payoff beat runs through it.
- **The purchase flow.** Needs a RevenueCat Test Store key, which does not exist yet. Without it
  the paywall cannot be reached at all, and the money moment — twelve seconds a monetization
  company's judges will watch closely — cannot be filmed.
- **Tier 2.** Never executed against the real on-device model. Not directly on screen, but it is
  what decides whether extraction takes half a second or six on the day.

Shoot the beats that do not depend on these first, so a blocker on shoot day costs one shot
rather than the video.

### If there is time to build one more thing

**Use detected columns.** It is the only cut feature whose absence the video actually feels:
the setup beat is now five fields typed by hand where it was meant to be one tap that proves the
app read the form. `05-uiux-spec.md` §4.3 calls it "the highest-value
90 seconds of interaction design in the app". The scan already produces a recognised header row
in table mode, so the work is mapping that row onto draft fields with guessed types — not a new
pipeline. This is a scope call, not a task: it is not in `01-idea-brief.md` §6.

## Production notes

**Capture.** Screen-record on device (iOS Screen Recording, not QuickTime mirroring — mirroring drops frames and reveals the Mac chrome). Shoot the physical desk shots separately on a second phone, on a tripod, in daylight. Cut between them; do not try to get both in one take.

**The desk.** One real register, one pen, matte surface, one directional daylight source. No brand logos anywhere in frame — a visible logo on a notebook or a laptop lid is a third-party trademark. Check every frame for this before uploading.

**Voiceover.** Record separately with a decent mic, in one take per line, then edit to picture. Read slower than feels natural. Total script is ~115 words across 1:42, about 67 a minute — that is deliberately sparse. Silence over a working app reads as confidence; wall-to-wall narration reads as compensation.

**Captions.** Burn in subtitles. Many judges watch muted, and it costs twenty minutes.

**Pacing.** No shot under 1.5 seconds. Fast cuts read as hiding something. If a step is genuinely slow — a Tier 2 extraction taking six seconds — either cut on the action and rejoin, or use a printed form in the demo where Tier 1 alone resolves it in under a second. **Do not fake the wait with a speed ramp**; if extraction takes six seconds, either show six seconds honestly or demo a case that is fast.

**Two shoots.** Day 6 evening: full run, watch it back, note everything wrong. Day 7 morning: reshoot. The second take is always the one you use, and budgeting for it is the difference between a good video and the first take.

## Checklist before upload

- [ ] Under 2:00
- [ ] Every shown feature exists in `main` — re-walk [As built](#as-built) against the tree you are filming, not against this list
- [ ] No feature named in the VO that is absent from the screen, and none named in the description that is absent from both
- [ ] No copyrighted music, no third-party logos in any frame
- [ ] Real device footage, real data, no `Test Item`
- [ ] Every `<R>` replaced with the row count of the page actually filmed, and the same number in every place it is said or shown
- [ ] Free-tier numbers on screen agree with the README: one template, 20 records in the current month, meter at 20 of 20 before the export gate
- [ ] No claim, spoken or written, about measured accuracy — that table is empty until a corpus exists
- [ ] Purchase flow shown end to end, with the automatic retry visible
- [ ] Confidence rules legible at 720p on a phone screen
- [ ] Burned-in captions
- [ ] Public visibility, not unlisted — the rules require publicly visible
- [ ] Title: `Carbon — Shipaton 2026 Next Gen Award`
- [ ] Description carries the repo URL and a two-line summary
- [ ] Watched once at 0.5× to catch a stutter, and once muted to check it still reads
