# Carbon — Spec Pack

Ten documents. Written to be fed to Claude Code as project context and to v0 as design prompts.

---

## The files

| File | Purpose | Who reads it |
|---|---|---|
| `CLAUDE.md` | Operating instructions, non-negotiables, conventions, definition of done | **Claude Code, every session.** Goes at the repo root, not in `docs/`. |
| `01-idea-brief.md` | Product scope, the user, evidence, judging alignment, what's out | Everyone. Source of truth. |
| `02-system-design.md` | Extraction pipeline, degradation ladder, performance budgets, errors, privacy | Claude Code, Eng A/B |
| `03-architecture.md` | Package layout, service protocols, DI, concurrency, tests, CI | Claude Code, Eng A |
| `04-data-model.md` | Complete SwiftData schema, snapshots, storage, migration | Claude Code, Eng C |
| `05-uiux-spec.md` | Tokens, components, screen specs, copy rules, motion, a11y + **v0 prompt pack in §9** | v0, then Claude Code, Eng D |
| `06-revenuecat-spec.md` | Entitlements, offering, gating matrix, purchase edge cases, tests | Claude Code, Eng D |
| `07-build-plan.md` | 7 days, 50-person split, cut order, corpus protocol, prize/credit | Everyone |
| `08-readme-template.md` | The judged README | Docs owner, Day 6 |
| `09-demo-video-script.md` | Shot list with timecodes, production notes | Video owner, Day 1 onward |

## Setup

**1. Repo, before anything else**

```
carbon/
├── CLAUDE.md          ← from this pack
├── docs/
│   ├── 01-idea-brief.md … 09-demo-video-script.md
│   └── design/        ← v0 screenshots land here
├── LICENSE            ← unmodified MIT, Day 1
└── README.md          ← stub Day 1, real Day 6
```

Make it **public from Day 1**. Judges look at project state over time, and a repo that appears fully-formed at the end reads badly.

**2. v0**

Run the six prompts in `05-uiux-spec.md` §9. Use the preamble verbatim every time — it carries the design system, and dropping it is how six screens end up looking like six apps. Export PNGs to `docs/design/`.

Ask v0 for *mockups*, never for code you intend to keep. You are buying pictures.

**3. Claude Code**

```
Read CLAUDE.md and docs/01-idea-brief.md through docs/04-data-model.md.
Then set up the project skeleton per docs/03-architecture.md §1 and every
service protocol in §2 with live stubs and fakes. Nothing else yet.
```

Protocols before implementations is the whole trick. Once they exist, four engineers work behind them in parallel without blocking each other, and every screen gets a preview with realistic data on Day 1.

## Three decisions to make before Day 1

**Name.** `Carbon` is a working title used consistently across all ten files. If you change it, change it everywhere before code exists — renaming a Swift package mid-week is an afternoon. Trademark and App Store search first. Alternates: Onionskin, Counterfoil, Duplicate, Tallysheet.

**The demo form.** One specific form, chosen now, that the whole team collects and the video features. A **daily sales or stock register** is the recommendation: ruled, tabular, genuinely re-filled daily, and it makes table mode — the more impressive of the two modes — the default demo.

**Team and prize.** `07-build-plan.md` §6. Split, credit convention, and the email to `shipaton@revenuecat.com` about the team shape. In writing, Day 1, before anyone writes code.

## What's deliberately not in this pack

No API reference — the specs name the frameworks and Claude Code should read Apple's current docs rather than trust a summary written today. No pixel-perfect mockups — that's v0's job. No test files — those come with the code they test.

## Two things worth re-reading before you start

**The iOS 26 decision** (`01-idea-brief.md` §7, restated in `CLAUDE.md`). Foundation Models image input is iOS 27, in beta during your build window. Depending on it means judges need a beta OS to run your repo. Vision does layout, the model does text-only mapping. Being able to explain that choice is one of the four judging criteria, so it belongs in the README verbatim.

**The corpus** (`07-build-plan.md` §5). Twenty people producing 250 labelled real-form photographs is the one thing a solo builder cannot do in a week. It converts into an honest accuracy table in the README, which is the most credible artefact in the whole submission — nearly every competing entry will claim its extraction works and almost none will have measured it. Note the privacy rule: invented data only, and the corpus itself never goes in the public repo.
