# Carbon — Devpost Draft

Copy to paste into the Devpost form, plus the assets it asks for. **Save as draft, do not submit** —
`07-build-plan.md` Day 7 is explicit that there are weeks left before Sep 30 and a polish pass is
worth more than an early submission.

The rule this draft is written to: **it must not claim anything the repository cannot show.**
Judges in this category clone the repo and build it, and the README carries an honest-status
table. A Devpost description that oversells relative to that README is the mismatch that costs
more than a missing feature.

---

## Fill before submitting

| Field | Status |
|---|---|
| Video URL (public YouTube, ≤2:00) | ⬜ not shot — `09-demo-video-script.md` |
| Accuracy numbers, if a corpus gets collected | ⬜ table is empty by design until then |
| Screenshots — 1179×2556, no device frame | ⬜ |
| 1024×1024 icon | ✅ `Carbon/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` |
| Repo URL | ✅ https://github.com/compiler-aditya/Carbon |
| Student email confirmed on the Devpost account | ⬜ required for Next Gen eligibility |
| Category | Next Gen Award |

---

## Tagline

> **Your form, remembered.** Map a paper form once — every photo after that becomes a row.

---

## Inspiration

Some paper cannot be removed from a workflow. A statutory register has to be on paper. A delivery
challan needs a signature. A site has no connectivity. A form was printed by someone else.

In all four cases the paper is mandatory, so the digital copy becomes a **second job** — someone
retypes the same fields, in the same order, from the same form, every day. That retyping is where
the time, the errors and the resentment live.

The tools that exist solve the wrong half. Form builders assume you can replace the paper; you
can't, that's the premise. Scanners give you an image, and an image is not a row. Photo-to-
spreadsheet converters are **stateless** — a shopkeeper's register has had the same five columns
for years, and a stateless tool relearns it 365 times a year and drifts.

## What it does

Carbon turns a repeatedly-filled paper form into a structured dataset.

1. **Map the form once.** Name it and declare its columns — or photograph the blank form and tap
   **Use detected columns**, which reads the headings and sets the fields up with their types.
2. **Photograph filled copies.** One page becomes one row, or a row per ruled line.
3. **Check only what needs checking.** Every value sits on a rule whose *style is its confidence*
   — solid, dashed, or dotted red. Tap a doubtful value and Carbon zooms the photograph to the
   exact cell it read it from, so you can see whether it misread the page or the page is genuinely
   ambiguous.
4. **Export to CSV.**

The template is the product. The first scan costs a minute; every scan after that lands in the
same shaped dataset — and Carbon keeps learning, storing the page's own spelling when a column
matches fuzzily, so `Amt` becomes an exact match for `Amount` next week with no model involved.

**Everything runs on the device.** No server, no account, no network call in the critical path.
A visitor log has names and phone numbers; a clinic intake form has patient details. There is no
upload endpoint in the codebase, and Settings says so by name.

## How we built it

Swift 6, SwiftUI, SwiftData, iOS 26. One third-party dependency: RevenueCat.

**A three-tier extraction ladder.** Tier 1 is deterministic Swift — fuzzy column-header matching
in table mode, label-anchored proximity in record mode — and resolves most of a printed page in
under 100 ms with no model at all. Tier 2 sends only the fields Tier 1 could not place to Apple's
on-device Foundation Model, text only, with a hard timeout. Tier 3 leaves the field empty and
marks it for review, which is a normal outcome rather than a failure. Every value carries its tier
and a confidence, and the interface shows both.

**The model gets text, not images — deliberately.** Foundation Models gained image input in
iOS 27, in beta during this build. Depending on it would mean anyone cloning this repo needs a
beta OS. So Vision's `RecognizeDocumentsRequest` — stable since iOS 26, with native table
detection — does the layout, and the model does text-to-schema mapping only.

**The output schema is built at runtime.** `@Generable` is the obvious API and the wrong one: a
macro needs its shape at compile time, and Carbon's fields are declared by the user inside the
app. Tier 2 assembles a `DynamicGenerationSchema` per template instead.

**Degradation is the design, not a fallback.** Where Apple Intelligence is unavailable — ineligible
hardware, switched off, still downloading, or an unsupported language — Tier 2 is skipped and the
app stays completely usable on Tier 1. Availability and language are checked separately, because
the model can be present and still not cover your language. A judge on a simulator lands in this
path, and it works.

**Zero configuration.** `git clone`, open, run. No key, no account, no backend. CI builds the app
with no secrets file present on every push so that path cannot quietly stop working.

## Monetization

Carbon gates on **volume and egress, never on quality** — extraction is identical for free and Pro
users. The meters track the units of value the user actually receives (templates, records per
month, export), so the paywall arrives when Carbon has stopped being a trial and started being
their system. Limits are not errors: hitting one opens the paywall, never an alert, and a table
page that crosses the limit mid-way saves the rows that fit and reports what needs Pro.

The paywall is **Paywalls V2** with a three-package offering — monthly, annual with a 7-day trial,
and a lifetime non-consumable for the prosumers who won't take a subscription. Entitlement state
is driven by `customerInfoStream`, so a purchase, a restore, or an expiry propagates with no
manual refresh. And when entitlement flips to Pro, **the export you asked for opens by itself** —
nobody should have to tap Export twice after paying for it.

Inference is on-device, so there is no per-scan cost and gross margin is 100%.

## Challenges we ran into

**Deciding what the app does when it is not sure.** The easy build shows a number and hides the
doubt. Carbon's confidence is structural instead — the rule under each value is solid, dashed or
dotted, colour is only the secondary channel, and VoiceOver speaks the confidence because the rule
is otherwise purely visual. Tapping a doubtful value shows you the region of the photograph it
came from. Often the page really is ambiguous, and seeing that is more useful than arguing with
the number.

**Every dead end we found was a screen that had no next step.** A page that read as nothing used to
return you to where you started with no records and no explanation; the pipeline could already
fail, and nothing rendered the failure. Errors are now one exhaustive type where each case owns
both its sentence *and* an affordance, so a case cannot ship telling you what to do with no way
to do it.

**Verifying against the simulator instead of reasoning about it** caught what builds and unit
tests could not: a Form row where the whole row was one tap target so "Add" did nothing, a record
count read from a stale snapshot, a signature animation that slid rows through each other because
one transaction was animating layout as well as opacity, and an error sheet that truncated its own
title at large accessibility sizes.

## Accomplishments that we're proud of

- The **confidence rule** — structure encoding real content rather than decoration, and the whole
  human-in-the-loop argument legible in one glance without a legend.
- **Use detected columns**: photograph a blank register, and the five columns arrive with their
  types read from what is written under them, not from the headings.
- The app is **fully usable with no Apple Intelligence at all**, which is where a judge on a
  simulator starts.
- **216 tests** concentrated where extraction bugs actually live, and a corpus harness that
  measures the app without being part of it.

## Honest status

Written here for the same reason it's in the README: judges build this repo.

**Verified:** zero-config clone → build → run (enforced by CI) · the capture → extract → review →
export loop end to end on a simulator · CSV byte-level correctness · the main screens at Dynamic
Type accessibility3 and in dark mode, on iPhone and iPad · the corpus harness, which ships with a
smoke corpus so it runs from a fresh clone.

**Not yet run:** camera capture on a real device · Tier 2 against the real on-device model · the
purchase flow, which needs a RevenueCat Test Store key · **accuracy on real photographs.** The
harness is built and tested but no corpus has been collected, so the README's accuracy table is
deliberately empty. Publishing a number with no photographs behind it is the thing this project
argues against.

## What we learned

That **AI belongs one step inside a workflow, never as the product.** Carbon's pitch is never that
a model reads your form — it's that your form is remembered. The model is plumbing, and on a
printed page it usually isn't needed at all.

And that the honest version of a demo is the more convincing one. Showing a value the app got
wrong, and fixing it in one tap, argues for the product better than a flawless run on synthetic
data.

## What's next

Collect a real corpus and publish the accuracy numbers. Handwriting is where the interesting
result is, and it is the last empty row in the status table. After that: XLSX export, multi-page
merge, and the iPad keyboard navigation that was deliberately cut this week.

Not planned, and listed publicly as decisions rather than gaps: iCloud sync, a macOS app, team
sharing, a server of any kind.

---

## Built with

`swift` · `swiftui` · `swiftdata` · `ios` · `vision` · `apple-foundation-models` · `visionkit` ·
`app-intents` · `revenuecat` · `on-device-ml`

## Try it out

- Repository: https://github.com/compiler-aditya/Carbon
- Video: ⬜ *fill before submitting*

---

## Notes for whoever pastes this

- **Devpost renders Markdown.** The tables above are for this file, not for the form; the
  description fields take prose and lists.
- **Lead with What it does if a field limit forces a cut.** Inspiration is the most compressible
  section here.
- **Do not paste the accuracy table.** It is empty on purpose and an empty table in a pitch reads
  as an oversight rather than a position; the Honest status paragraph carries the point better.
- Re-check **Honest status** against `README.md` before submitting. If those two ever disagree,
  the README is right and this file is stale.
