# CLAUDE.md — Carbon

Read this first, every session. Place at the repository root.

---

## What this is

**Carbon** is a native iOS/iPadOS app for RevenueCat Shipaton 2026, **Next Gen Award** category. It turns a repeatedly-filled paper form into a structured dataset: map the form's fields once, then every photo of that form becomes a row. Fully on-device, no server, no account.

**Build window is 7 days.** Scope discipline beats ambition. A narrow app that is genuinely finished scores better than a broad one with dead ends — that is a direct read of the judging criteria, not a preference.

## Read the specs before writing code

In `docs/`, in this order:

| File | Contains |
|---|---|
| `01-idea-brief.md` | Product scope. **Source of truth — if any doc contradicts it, it wins.** |
| `02-system-design.md` | Extraction pipeline, degradation ladder, performance budgets, error taxonomy |
| `03-architecture.md` | Package layout, service protocols, DI, concurrency, testing |
| `04-data-model.md` | Full SwiftData schema and the `Sendable` snapshot layer |
| `05-uiux-spec.md` | Design tokens, components, screen-by-screen specs, copy rules |
| `06-revenuecat-spec.md` | Entitlements, offerings, gating matrix, purchase edge cases |
| `07-build-plan.md` | Day-by-day plan, cut order, definition of done |

Design mockups are in `docs/design/` as PNGs. **Build SwiftUI from the mockups plus `05-uiux-spec.md`, never by transliterating web idioms** — no hover states, no web nav patterns, no CSS-transition equivalents. Match layout, hierarchy and tokens; use native patterns for everything else.

## Non-negotiables

1. **No network in the critical path.** Capture, recognition, extraction, storage and export are 100% on-device. The RevenueCat SDK is the only outbound traffic in the app. If a task seems to need a network call, stop and ask — it means the task is wrong.
2. **No third-party dependencies except RevenueCat.** No networking library, no DI container, no CSV library, no snapshot-testing framework. Everything else is a system framework. Proposing one requires a written justification.
3. **Never commit a secret.** Keys go in `Config/Secrets.xcconfig`, which is gitignored. `Secrets.example.xcconfig` is committed with a placeholder.
4. **The app must build and run from a fresh clone with the placeholder key.** A judge will do exactly this. Everything except purchasing must work. If a change breaks the zero-config path, it is a bug regardless of what else it fixes.
5. **The app must be fully usable when Apple Intelligence is unavailable.** Tier 1 → Tier 3 only. A judge on a simulator or an older device lands here.
6. **Target iOS 26, not 27.** Foundation Models image input is iOS 27 and was in beta during the build. Vision's `RecognizeDocumentsRequest` does layout; the model is used **text-only**. Reasoning is in `01-idea-brief.md` §7 — do not "improve" this without reading it.
7. **`@Model` objects never cross an isolation boundary.** Services take immutable `Sendable` snapshots. Swift 6 strict concurrency, no `@unchecked Sendable`.
8. **`FieldValue.rawText` is never overwritten**, not even on user correction. It is the accuracy dataset.
9. **No AI vocabulary in user-facing strings.** No "AI-powered", no "magic", no "smart", no "effortless". Say what happens: "Carbon read 14 rows. Three need checking."

## Conventions

- Swift 6.x, SwiftUI, SwiftData, Observation. No Combine, no UIKit except where a framework forces it (`VNDocumentCameraViewController`).
- `@Observable @MainActor` classes named `…Model`, one per non-trivial screen. Views hold no logic.
- Explicit state enums, never `isLoading` + `hasError` + `showSheet` booleans.
- Every service is a protocol with one live implementation and one fake. Every screen has a `#Preview` using `Services.preview()`.
- User-visible strings go in the String Catalog from the start, even though v1 is English-only.
- Files under 300 lines. One type per file. No abbreviations in names.
- Comments explain *why*. Never add `// MARK: - Properties` boilerplate.
- Conventional commits. Small PRs. `main` always green.

## Definition of done

A feature is not done until all eight are true:
1. Works on a real device
2. Has a loading state and an error state
3. Has a `#Preview` with realistic fake data
4. Strings in the String Catalog
5. Legible at Dynamic Type accessibility3
6. Correct in dark mode
7. Does not crash or dead-end when the model is unavailable
8. If in `CarbonCore`, has a test

## Working with me on this

- **Ask before adding scope.** If a task implies a feature not in `01-idea-brief.md` §6, say so instead of building it. The Out list there is a decision, not an oversight.
- **Flag API uncertainty rather than guessing.** Several APIs here are recent and the sources disagree on availability annotations — `RecognizeDocumentsRequest` in particular. Check the installed SDK, and if it differs from the spec, tell me and update the doc.
- **Prefer deleting to commenting out.** Git has the history.
- **When a spec is ambiguous, propose the smaller interpretation** and note the alternative. On a 7-day build the cheap wrong choice is recoverable; the expensive one is not.
- Do not write a migration, a sync engine, an analytics layer, or a networking layer. None is in scope.
- Do not reformat files you were not asked to touch. Four people are merging into this.

## Things that will be judged, so treat them as code

- **README** — a scored artifact. Template in `docs/08-readme-template.md`. Keep the accuracy table honest.
- **Test suite** — concentrated in normalization, Tier 1 extraction, CSV, entitlements, metering. Purchase-flow tests against Test Store are a scoring surface.
- **Commit history** — daily commits across the window. Never squash the week into one commit.
- **`LICENSE`** — unmodified MIT, detectable by GitHub in the About panel. A licence GitHub cannot parse makes the submission technically incomplete.
- **Issues board** — public, and it should show what we chose not to build.
