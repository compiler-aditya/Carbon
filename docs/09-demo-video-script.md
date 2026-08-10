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

### 0:08–0:26 · Setup, once
Phone in frame, over the register. Open Carbon → **New template** → scan the blank form → the **Use detected columns — 5 found** row appears → tap → fields populate with correct types → name it "Daily Register" → Save.

> **VO:** "You show Carbon the form once. It reads the columns and sets up the fields."

*This is the interaction that makes the whole product make sense. Give it real time — do not speed-ramp through it. Show the type chips landing correctly (Date, Text, Number, Currency): that detail is what proves it read the form rather than guessing.*

### 0:26–0:44 · The payoff beat
Same phone, same register, now a **filled** page. Tap **Scan** → document camera → shutter → processing labels tick past → Review appears with 14 rows in the grid.

Hold on the grid for a full two seconds. Let the signature animation play: values type onto their rules, then the confidence rules resolve — solid, dashed, three dotted red.

> **VO:** "After that, every photo of that form is just rows."

*This is the beat the entire video exists for. Everything before it is setup and everything after it is proof. If you get one shot perfect, make it this one.*

### 0:44–0:58 · Honesty, which is the product argument
Zoom the grid. Three cells sit on dotted red rules. Tap one → the source image zooms to exactly that cell on the page → the handwriting genuinely is ambiguous → type the correct value → the rule resolves to solid with a tick.

> **VO:** "It tells you what it isn't sure about, and shows you where on the page it came from. Fourteen rows, three worth checking."

*Do not hide the failures — feature them. Every competing entry will demo perfect extraction on synthetic data. Showing a real miss, and a one-tap fix, is more convincing than a flawless demo and it is the reason the correction editor exists. It also matches the accuracy numbers in the README, which is coherence a judge will notice.*

### 0:58–1:10 · The dataset accumulates
**Save 14 records** → the dataset screen, scrolled, showing a few hundred existing rows **accumulated over several months**. Search a term, one result. This must not be an empty demo account — populate it beforehand with believable data.

> **VO:** "It builds up as one dataset. Searchable, sorted, on the device."

*`Test Item 1` anywhere in this shot costs more than a missing feature. Real-looking data is a production requirement.*

**Seed the demo account so the free tier actually adds up.** The free tier is one template and twenty records *per calendar month* — so a dataset holding hundreds of rows has to have been built over months, not days, or the arithmetic on screen contradicts the README and the paywall beat that follows. Set the device up so the **current** month holds six records before this shot. Saving 14 then lands the meter on exactly 20 of 20, on camera, immediately before the export gate. That is not a workaround: a meter visibly filling to its limit and *then* the gate is a stronger, more legible version of the next beat than a lock appearing out of nowhere. Judges at a monetization company will do this arithmetic.

### 1:10–1:24 · The money moment
Tap **Export** → the lock and the meter — now reading 20 of 20 — are visible → paywall appears → select **Annual** → purchase completes → the sheet dismisses → **the export automatically continues** → share sheet → CSV opens in Numbers with the correct columns and typed values.

> **VO:** "Free covers one form and twenty records a month. Export is where Pro starts."

*Two things must land here: that the retry is automatic (no second tap), and that the CSV is genuinely correct in Numbers. Judges at a monetization company watch the purchase flow closely — a paywall that appears and a purchase that visibly unlocks the exact thing you tried to do is the whole criterion in twelve seconds.*

### 1:24–1:34 · One platform detail
Either: "Hey Siri, capture Daily Register" → the camera opens directly.
Or: the same app on iPad, `CellGrid` with more columns, editing a cell with a hardware keyboard.

*Pick one. Two would be padding. The Siri shot is the stronger of the two because it shows the app is a citizen of the platform rather than an island.*

### 1:34–1:42 · Close
Return to the overhead shot from 0:00. The laptop is closed. Only the register and the phone remain.

> **VO:** "The paper stays. The typing doesn't."

Final frame, held two seconds: app name, one line — *Your form, remembered.* — and the repo URL. No music sting.

---

## Production notes

**Capture.** Screen-record on device (iOS Screen Recording, not QuickTime mirroring — mirroring drops frames and reveals the Mac chrome). Shoot the physical desk shots separately on a second phone, on a tripod, in daylight. Cut between them; do not try to get both in one take.

**The desk.** One real register, one pen, matte surface, one directional daylight source. No brand logos anywhere in frame — a visible logo on a notebook or a laptop lid is a third-party trademark. Check every frame for this before uploading.

**Voiceover.** Record separately with a decent mic, in one take per line, then edit to picture. Read slower than feels natural. Total script is ~85 words across 1:42 — that is deliberately sparse. Silence over a working app reads as confidence; wall-to-wall narration reads as compensation.

**Captions.** Burn in subtitles. Many judges watch muted, and it costs twenty minutes.

**Pacing.** No shot under 1.5 seconds. Fast cuts read as hiding something. If a step is genuinely slow — a Tier 2 extraction taking six seconds — either cut on the action and rejoin, or use a printed form in the demo where Tier 1 alone resolves it in under a second. **Do not fake the wait with a speed ramp**; if extraction takes six seconds, either show six seconds honestly or demo a case that is fast.

**Two shoots.** Day 6 evening: full run, watch it back, note everything wrong. Day 7 morning: reshoot. The second take is always the one you use, and budgeting for it is the difference between a good video and the first take.

## Checklist before upload

- [ ] Under 2:00
- [ ] Every shown feature exists in `main`
- [ ] No copyrighted music, no third-party logos in any frame
- [ ] Real device footage, real data, no `Test Item`
- [ ] Free-tier numbers on screen agree with the README: one template, 20 records in the current month, meter at 20 of 20 before the export gate
- [ ] Purchase flow shown end to end, with the automatic retry visible
- [ ] Confidence rules legible at 720p on a phone screen
- [ ] Burned-in captions
- [ ] Public visibility, not unlisted — the rules require publicly visible
- [ ] Title: `Carbon — Shipaton 2026 Next Gen Award`
- [ ] Description carries the repo URL and a two-line summary
- [ ] Watched once at 0.5× to catch a stutter, and once muted to check it still reads
