# Carbon — Idea Brief

> **Working title:** Carbon (from *carbon copy* — the duplicate you used to get from a paper form).
> Trademark/App Store name check is a Day 6 task. Alternates held in reserve: Onionskin, Duplicate, Counterfoil, Tallysheet.
>
> **Status:** source of truth for product scope. If any other document in this set contradicts this one, this one wins.
> **Target:** RevenueCat Shipaton 2026 — **Next Gen Award** (student category) only.
> **Build window:** 7 days. Submission deadline Sep 30, 2026, 11:45pm PDT.

---

## 1. One sentence

Carbon turns the paper form you already have to fill in into a structured dataset — you map the form's fields once, and every photo of that form after that becomes a row.

## 2. The problem, stated precisely

A large class of work still runs on paper that **cannot be removed from the workflow**:

- A legal or regulatory register that must be kept on paper (attendance registers, visitor logs, statutory inspection books).
- A form that gets a physical signature (delivery challans, consent forms, handover sheets).
- A site with no connectivity, where paper is the capture medium of necessity.
- A form printed and supplied by a third party (a lab requisition, a government form, a customer's own PO).

In all four cases the paper is mandatory and the digital copy is a **second job**: someone retypes the same fields, in the same order, from the same form, over and over. The retyping is where the errors, the delay, and the resentment live.

Existing tools solve the wrong half of this:

| Tool class | What it does | Why it misses |
|---|---|---|
| Digital form builders (Jotform, Fulcrum, GoCanvas, KoBoToolbox, ODK) | Give you a digital form to fill in on a phone | Assumes you can *replace* the paper. If the paper is mandatory, these add a third step rather than removing one. |
| Generic scanners (Adobe Scan, Microsoft Lens, Apple Notes) | Produce an image or flat text | No structure, no schema, no dataset. You still retype. |
| "Photo → spreadsheet" converters (a crowded App Store segment) | One-shot table extraction | Stateless. Every scan starts from zero. No memory of *your* form, no accumulating dataset, no reason to open the app tomorrow. |

**Carbon's wedge is memory of the form.** The first scan costs you 60 seconds of mapping. Every scan after that is instant and lands in the same shaped dataset. That is the entire product.

## 3. Who it is for

**Primary user (build and demo for exactly this person):** someone who fills in or collects **the same form, repeatedly, on paper**, and is responsible for the digital record afterwards.

Pick **one** for the demo video and write all UI copy for them. Recommended: a **site or shop daily register** — a supervisor or owner who fills a ruled register each day (date, item, quantity, amount, signature) and has to produce a monthly summary.

Secondary users, same shape, do not build for them yet: clinic front desk (intake forms), lab technician (result sheets), field surveyor (survey sheets), fleet operator (trip sheets), workshop (job cards).

**Anti-user:** the person who wants to extract a table *once* from a PDF they found. That is the converter market. We are deliberately not serving it, and the free tier's shape (one template) makes that explicit.

## 4. Why this idea, with the evidence

Every claim below should appear, in compressed form, in the Devpost description. Judges reward product thinking that shows its work.

**4.1 The category is the one RevenueCat itself has flagged.** RevenueCat's *State of Subscription Apps 2026* concludes that Business is the category that monetizes and retains best, that users are generally unhappy with existing solutions in it, and that combining consumer-grade craft with business monetization is one of the largest developer opportunities of 2026. Business is also ~76.5% pure-subscription. Meanwhile, essentially every student hackathon submission is a consumer app. Building prosumer means arguing from the judges' own published research.

**4.2 The same report rules out the obvious AI play.** That report also shows AI apps' 12-month payer retention dipping sharply in 2026 once users had had time to evaluate them, with the explicit read that shipping fast or leaning on AI hype is not enough. Consequence for us: **AI is one step inside a workflow, never the product.** Carbon's pitch is never "AI reads your form." It is "your form, remembered." The model is plumbing.

**4.3 Differentiation has to be structural.** New subscription app launches went from roughly 2,000/month in January 2022 to over 14,700/month by January 2026. A cosmetic difference does not register. The template is a structural difference: it creates a switching cost and a reason to return that a stateless converter cannot have.

**4.4 There is a technical unlock that is worth more in this category than in any other.** Apple's Foundation Models framework gives an on-device LLM with **no API key, no network, and no per-token cost**, and Vision's `RecognizeDocumentsRequest` (iOS 26) natively detects tables with rows and columns, on device, in 26 languages.

Next Gen judges **clone the repository and build it**. Any competing entry that depends on a cloud LLM either commits a key (a security failure, and likely revoked by judging in October) or hands the judge an error screen and fails the "is the core functionality clear from the code" criterion. Carbon runs from `git clone` with zero configuration. It is also 100% gross margin, which the people who run a monetization company will notice immediately.

**4.5 The team shape fits this idea specifically.** The scarcest input for Carbon is not code — it is a corpus of real forms in real handwriting. Fifty people at five photos each is 250 genuine samples inside a day. That is embarrassingly parallel, it is the one thing a solo builder categorically cannot do in a week, and it feeds directly into the "meaningful progress toward a working app" and "care in how it was built" criteria. Nearly every other Next Gen entry will be demoed on synthetic data by the person who wrote it.

## 5. Mapping to the Next Gen judging criteria

The official criteria, and how each is answered:

| Criterion | How Carbon answers it |
|---|---|
| Is the app idea clear, useful, interesting or original? Does it solve a real problem? | One-sentence pitch. A named user with a named recurring task. A competitive gap stated in one line. Evidence in §4. |
| Does the project demonstrate meaningful progress toward a working app? Is core functionality clear from video and repo? | One vertical slice, complete: capture → extract → review → export. Zero-config build. README with exact run instructions. Real-corpus accuracy numbers in the README. |
| Does it thoughtfully use RevenueCat to support monetization? | Meter tied to the unit of value (templates + records), gate at the moment of value (export), Paywalls V2, multi-package offering, restore + all purchase edge cases handled, purchase-flow unit tests. See `06-revenuecat-spec.md`. |
| Does it show thoughtful technical choices, product thinking and care? | Stable-OS API choice over shiny beta (see §7). Graceful degradation ladder. Human-in-the-loop correction as a product decision, surfaced in the UI. Architecture note in the README. Public issue tracker showing what we chose *not* to build. |

## 6. Scope — v1.0 (the 7 days)

### In
1. **Capture** a form page with the system document scanner (edge detection, dewarp, multi-page).
2. **Define a template**: name it, then declare fields (label, type, optional choices, required flag). Two template modes:
   - **Record mode** — one page produces one record (an intake form).
   - **Table mode** — one page produces N records, one per detected table row (a register).
3. **Extract**: Vision structured document read, then a text-only Foundation Models pass that maps detected content to the template's declared fields, with per-field confidence.
4. **Review and correct**: a cell editor. Confidence is visible. Every edit is recorded as user-corrected.
5. **Dataset view** per template: all records, sortable, searchable.
6. **Export** to CSV.
7. **Paywall** (Paywalls V2), entitlement gating, restore, usage meter.
8. **One App Intent**: "Capture <template>" — Shortcuts and Action-button drivable.
9. Settings, onboarding (3 screens), empty states, error states.

### Out — explicitly, and say so in the README
CloudKit/iCloud sync · macOS target · XLSX and JSON export · multi-page merge into one dataset · team sharing · signature capture · barcode-keyed lookups · a server of any kind · localization beyond English · iPad-optimised layout beyond "does not look broken".

Each of these is a real v1.1 candidate. Listing them in the README as deliberate cuts reads as scope discipline; leaving them half-built reads as an unfinished app. **The distinction the judges care about is complete-and-narrow versus broad-and-broken.**

## 7. The one technical decision to get right on Day 1

Foundation Models gained **image input** at WWDC 2026 — but that ships with iOS 27, which is in beta during our build window. Depending on it would mean judges need a beta OS to run the repo.

**Decision:** target **iOS 26**. Vision's `RecognizeDocumentsRequest` does the layout and OCR work (native tables, rows, columns, on-device, stable). Foundation Models is used **text-only** to map recognized content onto the template schema and normalize values. Image input into the model is an explicitly-marked optional enhancement path behind an availability check, not a dependency.

Write this reasoning into the README architecture note verbatim. Choosing the stable API over the shiny one, and being able to explain why, *is* the "thoughtful technical choices" criterion.

## 8. Positioning and copy

**Tagline:** Your form, remembered.

**Subhead:** Map a paper form once. Every photo after that becomes a row.

**Voice:** plain, competent, unshowy. This is a tool for someone doing a job. Never "AI-powered," never "magic," never "effortless." Say what happens: "Carbon read 14 rows. Three need checking."

**Never claim** perfect accuracy. The confidence display and the correction editor are the product's honesty, and honesty is a differentiator in a segment full of apps that pretend extraction is solved.

## 9. Success criteria for the submission

- [ ] `git clone` → open in Xcode → run on device, with no key, no account, no config file.
- [ ] Capture → extract → correct → export completes on a real form on a real device, on camera, in under 30 seconds.
- [ ] A purchase completes through RevenueCat Test Store and unlocks export, on camera.
- [ ] Accuracy measured on a corpus of ≥200 real photographs, reported honestly in the README (per-field precision, and the % of records needing at least one correction).
- [ ] README readable in under 4 minutes, with a GIF above the fold.
- [ ] Repo has a detectable open-source licence visible in GitHub's About panel.
- [ ] Demo video ≤ 2:00, shot on a real device, every feature shown exists in the code.
