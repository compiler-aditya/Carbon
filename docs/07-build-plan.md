# Carbon — 7-Day Build Plan

Assumes a start on Day 1 and a finished submission on Day 7, with the Devpost entry left as a draft until closer to Sep 30.

---

## 1. Team split

Fifty people is an asset for some work and a liability for other work. Adding engineers to a seven-day greenfield SwiftUI codebase with no established architecture does not compress the timeline, it fragments the output — and in this category the fragmentation is *visible*, because one of the four criteria is care in how the app was built and judges read the repository. Four styling conventions and three approaches to state in one git log is a scored defect.

So the codebase is capped and the rest of the team goes where throughput actually scales with headcount.

| Group | People | Owns |
|---|---|---|
| **Engineering** | 4 | The entire codebase. No more. |
| — Eng A (lead) | | Architecture, protocols, `CarbonCore` skeleton, capture + Vision recognition. Final say on merges. |
| — Eng B | | Extraction ladder (Tiers 1–3), Foundation Models, normalization, the corpus harness. |
| — Eng C | | SwiftData model, persistence, export, App Intents, metering. |
| — Eng D | | Design system, all screens, paywall, onboarding, empty and error states. |
| **Corpus** | 20 | Collect and label the real-form photograph set. See §5. |
| **QA** | 12 | Device matrix, the degradation matrix, the Test Store checklist, bug triage. |
| **Design** | 5 | v0 mockups, icon, App Store-style screenshots, paywall design in the RevenueCat dashboard. |
| **Video & docs** | 5 | The 2-minute video (one person owns it for the whole week), README, Devpost copy. |
| **Build-in-public** | 4 | Daily posts, tagged `#Shipaton`. Separate award, ~$30k pool, judged on the story rather than audience size. |

Two rules that make this work:
1. **Only Engineering commits code.** Everyone else files issues. A 50-person contributor graph on a 7-day app looks like chaos, not collaboration.
2. **One person owns the video for seven days.** Not "we'll film it at the end." In a category judged from video and repo, the video is half the deliverable and it deserves a dedicated owner from Day 1.

## 2. Day by day

Each day ends with a **demoable state** and a merge to `main`. If a day's acceptance criteria are not met, cut scope from a later day — never borrow from Day 7.

### Day 1 — Skeleton, protocols, and the money

The highest-leverage day. Two things must be true by tonight: the repo is public and building, and a purchase completes.

**Eng A** — Xcode project, `CarbonCore` + `CarbonTestFixtures` packages, Swift 6 strict concurrency on. Write **every service protocol** from `03-architecture.md` §2 and the `Services` DI struct with fakes. Push. This unblocks B, C and D to work in parallel for the rest of the week; it is worth doing carefully and it should be the first PR merged.
**Eng B** — `withTimeout` helper; normalization module scaffold with the first ten unit tests (currency, decimals). Pure Swift, no dependencies, testable immediately.
**Eng C** — Full SwiftData schema from `04-data-model.md`, `ModelContainer` setup, `@ModelActor` write path, snapshot conversion layer. Verify `#Index` and the enum-as-raw-string approach compile against the installed SDK.
**Eng D** — Design tokens, `FieldRow`, `ConfidenceRule`, `StampBadge`, `PrimaryButton`. RevenueCat SDK integrated, `LiveEntitlementService`, Paywalls V2 paywall presenting, `pro` entitlement gating one hardcoded thing. **A Test Store purchase completes on device.**
**Design** — v0 prompts run, screenshots into `docs/design/`. Paywall built in the RevenueCat dashboard.
**Corpus** — Collection brief issued (§5). Photography starts today.

**Acceptance:** repo public with LICENSE and README stub, CI green, app launches, paywall presents, a Test Store purchase flips a visible state. **The mandatory competition requirement is satisfied on Day 1.**

### Day 2 — Core loop end to end, ugly

**Eng A** — Document camera wrapped, pages persisted to disk before processing, `RecognizeDocumentsRequest` producing `RecognizedPage`. Confirm the availability annotation and record the answer in the README.
**Eng B** — Tier 1 deterministic extraction: table-mode header matching and record-mode label anchoring.
**Eng C** — Write path from `ExtractionResult` to SwiftData. Template and field CRUD.
**Eng D** — Templates list, template detail, template editor, review screen (record mode). Real screens, real navigation, `.preview()` fakes.

**Acceptance:** on a real device — create a template by hand, scan a printed form, see extracted values on screen, save the record. It can be ugly. It must be real.

### Day 3 — The differentiators

Exactly two features today, no more.

**Eng B** — Tier 2 Foundation Models pass with `@Generable` output, availability gate, timeout, Tier 3 fallback. The full ladder works.
**Eng A** — **Use detected columns**: build a template from a reference scan's header row with guessed types. This is the app's best interaction and the setup beat of the video.
**Eng C** — CSV export with full RFC-4180 handling, `FileDocument` + `ShareLink`, `ExportLog`. Usage metering with all of §6's gate decisions.
**Eng D** — Table-mode review (`CellGrid`), dataset screen with search, sort and filter.
**QA** — Device matrix begins. **Explicitly test the model-unavailable path** — a judge on a simulator will land there.

**Acceptance:** scan a register → 14 rows → correct a cell → export CSV → open it in Numbers. Free-tier gates fire correctly.

### Day 4 — Platform integration and the first corpus run

**Eng A** — Photo-library import path, bundled sample forms so the app is fully explorable with no camera. Tap-to-zoom from a field to its region on the source image.
**Eng B** — Corpus harness running over the collected set; first accuracy table. `learnedHeaderAliases` written back on user correction.
**Eng C** — `CaptureFromTemplateIntent` + `AppShortcutsProvider`. Storage management in Settings, with file cleanup on record delete (and a test for it).
**Eng D** — Settings, onboarding, `MeterBar`, every empty state.
**QA** — Full degradation matrix from `02-system-design.md` §7, one issue per row.

**Acceptance:** "Hey Siri, capture Daily Register" works. First honest accuracy number exists. The app is usable on a fresh simulator with no camera and no model.

### Day 5 — The finished-app surfaces

This is the day that separates the submission from the pile. Nothing new; everything unfinished becomes finished.

**All four engineers** on the bug list. Specifically:
- Every error case in `CarbonError` has real copy and a real presentation. No `fatalError`, no silent catch, no default alert.
- Every screen has an empty state.
- Every async operation has a loading state, and none of them is a bare spinner.
- Every typed field opens the right keyboard.
- Correct behaviour on: kill during capture, background during extraction, permission denied, storage full, 500-record dataset.
- Purchase edge cases from `06-revenuecat-spec.md` §7, all nine, verified on device.
- Dynamic Type to accessibility3 on every screen. VoiceOver speaks confidence.
- iPad: split view, three-column grid, keyboard nav in `CellGrid`, 1/3-width Split View.

**Acceptance:** two hours of adversarial use by a QA member who has not seen the app produces no crash and no dead end.

### Day 6 — Polish, identity, assets

**Eng D + Design** — App icon (paper and violet ink, legible at 29pt). The signature stagger animation on Review, with `reduceMotion` respected. Dark mode pass. Haptics: one `.success` on record save, one on export. Nothing else.
**Eng A/B/C** — Performance pass against the budgets in `02-system-design.md` §4, measured on the oldest device available. Fix the worst two. Delete all dead code and debug scaffolding.
**Design** — Screenshots at 1179×2556, no device frame. 1024×1024 icon export.
**Video** — Shoot. Twice. See `09-demo-video-script.md`.
**Docs** — README written properly from `08-readme-template.md`, with real accuracy numbers.
**Everyone** — Name check: trademark and App Store search for the final name.

**Acceptance:** a stranger given only the README can clone, build, run, and complete a capture without asking a question.

### Day 7 — Submission

- Final corpus run; paste the real numbers into the README.
- Architecture note in the README, including the iOS 26 / iOS 27 reasoning verbatim from `01-idea-brief.md` §7.
- Repo tidy: no TODOs in `main`, no commented-out code, LICENSE detectable in GitHub's About panel, CI badge green, `docs/` committed, issues board showing deliberate cuts.
- Video edited, uploaded public to YouTube, under 2:00, no copyrighted music.
- Devpost draft: description, 1024×1024 icon, screenshot at 1179×2556 with no device frame, repo URL, video URL, student email confirmed on the account.
- **Save as draft. Do not submit.** There are weeks left; if the second app finishes early, come back for a polish pass and reshoot.

**Acceptance:** every box in `01-idea-brief.md` §9 ticked.

## 3. Cut order

If you fall behind, cut in this order. Never improvise the order under pressure — decide it now, while nobody is tired.

1. Tap-to-zoom on source region
2. `learnedHeaderAliases` write-back
3. App Intent
4. Table-mode `CellGrid` (fall back to record mode only — halves the demo's impact, so this is a painful but survivable cut)
5. Tier 2 Foundation Models pass (Tier 1 + Tier 3 still ships a working app)

**Never cut:** the paywall, error and empty states, the README, the video, or the corpus accuracy number. Those are the scored surfaces.

## 4. Definition of done

A feature is done when: it works on a real device; it has a loading state and an error state; it has a `#Preview` using `.preview()` fakes; the strings are in the String Catalog; it works at accessibility3 type size; it works in dark mode; it does not crash when the model is unavailable; and if it is in `CarbonCore`, it has a test.

Nothing merges to `main` without all eight. Eng A enforces this and is allowed to be unpopular about it.

## 5. Corpus protocol — 20 people, and a privacy obligation

The corpus is the most valuable thing 20 people can produce in a week, and it is the reason our accuracy claim will be credible when everyone else's is a vibe.

**Target:** ≥250 photographs across ≥8 distinct form types, ≥15 handwriting styles, in varied lighting including deliberately bad conditions (shadow, glare, skew, crease, low light, phone flash).

**Protocol**
1. Each collector fills in blank forms themselves or photographs **their own** documents.
2. **No real third-party personal data.** No customer names, phone numbers, addresses, ID numbers, medical or financial information belonging to anyone else. Fill forms with invented data. This is not optional, and one person owns enforcement.
3. Each photo gets a companion `.json` with the ground-truth field values, typed by the collector.
4. Naming: `<formtype>_<collector>_<nn>.jpg`.
5. **The corpus is not committed to the public repo.** Even with invented data, a public folder of form photographs is a liability and a distraction. Keep it in shared storage; commit only the aggregate numbers and 3–5 clean, explicitly-cleared examples as `Resources/SampleForms/`.
6. Deliver in two waves: 100 photos by end of Day 2 (so Eng B can build against reality on Day 3), the rest by Day 4.

**What the harness reports, and what goes in the README:**
- Per-field precision, by field type
- % of records requiring at least one correction ← **the headline number, and the honest one**
- Mean and p95 latency per page
- Tier attribution: what share of values Tier 1 resolved without the model

Report these numbers whatever they are. A submission that says "68% of records needed no correction, and here is exactly where it fails" is more convincing than one that claims 99% and shows a synthetic demo. Judges who build software recognise the difference instantly, and the honesty is itself a product argument — it is why the correction editor exists.

## 6. Prize and credit, settled before any code

Do this on Day 1, in writing, in a pinned issue.

- The prize is paid to a single Representative who allocates it. Agree the split now — $15,000 across fifty people is $300 each, and retroactive negotiation is how these end badly.
- Prize awards are subject to verifying each winner's **role in creating the submission**, and Next Gen additionally requires student status. A fifty-person roster with mixed student status and very uneven contribution is exactly the case that becomes awkward at verification.
- **Email `shipaton@revenuecat.com` on Day 1**, describe the team shape honestly, and get the answer in writing before you build. Cheap insurance, and there is no version of this where asking hurts.
- Decide the credit convention now: `CONTRIBUTORS.md` listing everyone by role, engineering commits from four accounts. Everyone is credited; not everyone commits.
