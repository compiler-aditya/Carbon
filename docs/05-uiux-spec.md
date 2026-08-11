# Carbon — UI/UX Design Specification

Two audiences: **v0 (Vercel)** to generate visual mockups you can look at and iterate on, and **Claude Code** to build the real SwiftUI. Section 9 is the v0 prompt pack. Everything before it is the spec both should follow.

---

## 1. Design thesis

The subject is **paper forms** — registers, carbon copies, ruled ledgers, rubber stamps, index tabs. The design should come from that world rather than from generic iOS-utility conventions, and it should look like nothing else in the Next Gen submission pile.

**The core metaphor: an extracted value is a filled-in form field.** It sits *on* a ruled baseline, the way ink sits on a printed line. That single idea drives the whole interface.

**The signature element: the confidence rule.** The line under every extracted value carries information:

| Confidence | Rule | Meaning |
|---|---|---|
| ≥ 0.85 | solid, `ink` | read cleanly, ignore it |
| 0.60 – 0.85 | dashed, `carbon` | glance at it |
| < 0.60 or unresolved | dotted, `stamp` red | needs you |
| user-edited | solid, `carbon`, with a small filled tick at the line's end | you fixed this |

This is structure encoding real content, not decoration. It makes the human-in-the-loop story legible in a single glance — including in a two-minute video, where a reviewer has no time to read a legend. Spend the design boldness here and keep everything around it quiet.

## 2. Tokens

### Colour

Derived from carbon-copy paper: violet duplicating ink, second-copy stock, olive rule lines, stamp red.

```
Light
  paper        #EDEDE4   app background — pale warm grey-green, second-copy stock
  paperRaised  #F6F6F0   cards, sheets, rows
  ink          #1E1B2E   primary text — near-black with a violet cast
  inkMuted     #5C566E   secondary text, labels
  carbon       #3D2E8C   PRIMARY ACCENT — carbon-copy violet
  carbonSoft   #E4E0F4   accent fills, selection
  rule         #8E9384   hairline rules, dividers, table grid
  stamp        #B3322A   needs-review, destructive
  stampSoft    #F5E3E0
  confirm      #4A6B3F   confirmed state — muted olive, never a bright green

Dark
  paper        #16151C
  paperRaised  #201F28
  ink          #EDEDE4
  inkMuted     #9A94AC
  carbon       #9B8CFF
  carbonSoft   #2A2540
  rule         #4A4857
  stamp        #E0776C
  stampSoft    #2E1E1C
  confirm      #8FB27F
```

Do not add a fourth hue. Three (violet, red, olive) plus neutrals is the whole palette.

### Type

All three faces are Apple system faces: zero bundle weight, zero licensing, and the *pairing* is what makes it distinctive. iOS utilities almost never use a serif display face, and almost never set data in mono.

```
Display   New York (serif)      — screen titles, template names, empty-state headlines
Body/UI   SF Pro                — labels, buttons, body copy, navigation
Data      SF Mono               — every extracted value, every number, every cell
```

The mono choice has a functional justification, which matters if anyone asks: monospaced digits disambiguate `1/7`, `0/O`, `5/S` — exactly the characters OCR confuses. It is a legibility decision that happens to look right.

```
title          New York Semibold 28 / 34
sectionHeader  SF Pro Semibold 13, tracking +0.6, UPPERCASE
fieldLabel     SF Pro Medium 12, inkMuted
dataValue      SF Mono Regular 17, ink            ← the workhorse
dataValueLarge SF Mono Medium 22
body           SF Pro Regular 16
caption        SF Pro Regular 13, inkMuted
```

Use `.dynamicTypeSize(...DynamicTypeSize.accessibility3)` bounds, and let everything scale. The mono data style must remain readable at accessibility sizes — test it.

### Spacing, radius, elevation

- 4pt grid. Spacing tokens: 4, 8, 12, 16, 24, 32, 48.
- Radius: 10 for cards and sheets, 6 for chips and buttons, 0 for rules and table cells. **Table cells have square corners** — grids are grids.
- No drop shadows anywhere. Separation comes from hairline `rule` borders and the `paperRaised` fill. Shadows would fight the paper metaphor.
- Hairlines are 1px physical (`1 / displayScale`), colour `rule` at 50% opacity.

## 3. Component inventory

Build these once in `DesignSystem/`; every screen composes them. This is what keeps four engineers' screens looking like one app.

| Component | Description |
|---|---|
| `FieldRow` | Label above, `dataValue` on a confidence rule. Read-only and editable variants. **The most important component in the app.** |
| `ConfidenceRule` | The rule itself. Style driven by a `Confidence` value, not by a bool. |
| `TemplateCard` | Symbol, name in New York, subtitle, record count in mono, last-used relative date. |
| `RecordRow` | Dataset list row: 2–3 primary field values in mono, status dot, timestamp. |
| `CellGrid` | Table-mode review grid. Square cells, hairline grid, horizontally scrollable, sticky header row. |
| `StampBadge` | Status chip in the rubber-stamp idiom: outlined, slightly rotated (−2°), uppercase, letterspaced. Used for `NEEDS REVIEW` / `CONFIRMED`. This is where a little personality is allowed. |
| `PrimaryButton` / `SecondaryButton` / `DestructiveButton` | Filled `carbon`, outlined, `stamp` text. Full-width in sheets, inline elsewhere. |
| `SectionHeader` | Uppercase `sectionHeader` with a trailing hairline running to the edge. |
| `EmptyState` | Symbol, New York headline, one line of body, one primary action. |
| `MeterBar` | Free-tier usage. Hairline track, `carbon` fill, mono count. Never red until the limit is actually hit. |
| `ProcessingIndicator` | Not a spinner. See §6. |

## 4. Screen specs

### 4.1 Templates (root, tab 1)

- Large title **Templates** in New York.
- Grid of `TemplateCard`, two columns on iPhone, three on iPad.
- Each card: symbol top-left, name, subtitle, `142 records` in mono, `2h ago`.
- Primary action: a prominent **New template** card at the end of the grid — outlined, dashed `rule` border, plus symbol. It looks like a blank form waiting to be filled.
- Free tier at the limit: the New-template card stays visible but shows a small lock and the meter; tapping presents the paywall. **Never hide the action** — a hidden action teaches nothing, a gated action teaches what Pro is for.
- Toolbar: overflow → Archived templates, Settings.
- Empty state: "No templates yet." / "A template teaches Carbon the shape of one paper form. You'll only do this once per form." / **Create your first template** + a secondary **Use a sample form**.

### 4.2 Template detail

- Title = template name (New York), subtitle beneath.
- Big primary action at top: **Scan** — a wide `carbon` button with the camera symbol. This is the verb of the app; it should be the largest tappable thing on screen.
- Then `SectionHeader` "FIELDS" and a compact read-only list of field label + type chip.
- Then "RECENT" — five most recent `RecordRow`s, and **View all 142 records**.
- Toolbar: Edit template, Export, overflow (Duplicate, Archive, Delete).

### 4.3 Template editor

Two-step sheet, and the order matters — the reference scan first is what makes field mapping feel grounded rather than abstract.

**Step 1 — Reference.** "Scan the form once so Carbon can see its shape." Camera or photo library, or **Skip**. The captured page is shown at the top of step 2 for the rest of the flow.

**Step 2 — Fields.**
- Name, subtitle, symbol picker, mode picker (Record / Table) with one line of explanation under each option.
- Field list, reorderable, swipe-to-delete. Each row: label, type chip, required dot.
- Add field → inline expanding row: label text field, type picker (segmented for common four, menu for the rest), required toggle, and type-specific extras (choices editor for `.choice`, currency picker for `.currency`, date convention for `.date`).
- **The assist:** if a reference scan exists and the mode is Table, offer **Use detected columns** — pre-fill fields from the recognised header row, with types guessed from cell content. One tap creates the whole template. This is the highest-value 90 seconds of interaction design in the app and it should be the first thing shown in the video's setup beat.
  - **Built.** `ColumnDetector` in `CarbonCore`; the editor offers **Scan the blank form** / **Choose a photo of the form**, then lists each column with its guessed type and the first few values behind the guess before anything is accepted. Showing the evidence is the same posture as the confidence rules: a guess is offered as a guess.
  - **The body decides the type, not the heading.** A column called "Amount" holding words is text. The heading only decides when the column is empty — which is what lets the assist work on a blank form, where there is nothing but headings.
  - Accepting **appends**, skipping any label already present, so a user who typed two fields first does not lose them.
  - A heading merged across two columns names neither, so it is skipped rather than guessed at, and a blank gutter column is not a field.
- Save is disabled until name is non-empty and there is ≥1 field. Explain why inline, never with a disabled button and no reason.

### 4.4 Capture and processing

- Full-screen system document camera. No custom chrome.
- On dismiss: immediately show the **processing** screen with the captured page as a dimmed backdrop, so the user sees their own photo and knows it landed.
- Processing states, in this order, as text (not a spinner): `Reading page…` → `Matching fields…` → `Checking values…`. Each with the `ProcessingIndicator`. If Tier 2 runs, `Matching fields…` may sit for a few seconds — that is why the label is specific.
- Auto-advance to Review. No confirmation tap.

### 4.5 Review — record mode

- Header: page thumbnail (tap → full-screen zoom), `StampBadge` status, capture timestamp.
- `FieldRow` list. **Fields needing review sort to the top** and the first is auto-focused.
- Tapping a value: inline edit with the correct keyboard (`.decimalPad`, `.numberPad`, date wheel, choice menu). Never a generic text keyboard for a typed field.
- Tapping the small page icon on a row: zooms the source image to that field's `frame`. This is a small feature that does an enormous amount of work on camera — it proves the app is reading the actual page rather than inventing values.
- Bottom bar: **Save record** (primary), and `3 need review` in mono when applicable.
- Saving with unresolved required fields: allowed, with a one-line inline note. Do not block. The user knows more than the app.

### 4.6 Review — table mode

- `CellGrid`: sticky header, square hairline cells, horizontal scroll, row numbers in the leading gutter.
- Cell background tinted `stampSoft` when below threshold — the grid version of the confidence rule.
- Tap a cell → inline edit, `Tab`/next moves along the row (real keyboard support on iPad matters here).
- Header: `14 rows found · 3 cells need review`.
- Bottom bar: **Save 14 records**, plus row-level swipe-to-discard.

### 4.7 Dataset

- Search field (searches all normalized values).
- Sort menu: newest, oldest, or by any field.
- Filter chips: All / Needs review / Confirmed.
- `RecordRow` list, paginated fetch.
- Toolbar: **Export** — always visible. If not Pro, it shows a small lock and presents the paywall. Gate the outcome, not the discoverability.
- Empty state: "No records yet." / "Scan the form and the rows land here." / **Scan**

### 4.8 Export

Small sheet, not a screen: format (CSV; XLSX shown greyed with "Coming soon" — honest, and it signals roadmap), scope (All / Filtered / Needs-review-excluded), row count in mono, then `ShareLink`. Log to `ExportLog` on success.

### 4.9 Paywall

Built with **RevenueCat Paywalls V2**, configured in the dashboard, not hand-coded. Give the dashboard designer these constraints so it matches the app: `paper` background, New York headline, `carbon` primary button, mono for prices, no gradients, no shadows, no illustration.

Headline: **Carbon Pro**. Sub: "Unlimited templates and records. Export whenever you want."
Feature list, four lines, each a concrete capability rather than a benefit adjective:
- Unlimited templates
- Unlimited records
- CSV export
- Everything stays on your device

Packages: Monthly, Annual (badge the annual saving), Lifetime. Restore purchases as a text link. Terms and Privacy links.

Two copy constraints that are easy to get wrong in a dashboard editor:

- **The saving is ~50%, and it must be computed, not typed.** $4.99 × 12 against $29.99 is 49.9%. Paywalls V2 derives this from the packages themselves — typing "Save 40%" (or any literal) into the badge is the same mistake as hardcoding a price, and it goes stale the moment pricing moves.
- **The trial is Annual-only, so the button label cannot be "Start free trial" unconditionally.** It is wrong the instant someone selects Monthly or Lifetime — and Lifetime is a non-consumable that can never carry a trial. Either bind the label to the selected package's offer, or use one honest label for all three ("Continue") and let the Annual card carry the trial wording.

### 4.10 Settings

Sections: **Usage** (`MeterBar`, records and templates this period, Pro status, Restore purchases) · **Storage** (total size, delete scan images for confirmed records) · **Extraction** (on-device intelligence status line, default date convention) · **Privacy** (a real paragraph: nothing leaves the device except RevenueCat's own SDK traffic) · **About** (version, GitHub link, licences).

### 4.11 Onboarding

Three screens, skippable, each one sentence in New York plus one line of body:
1. "Paper you can't get rid of." — the problem.
2. "Map the form once." — the template.
3. "Then every photo is a row." — the payoff.
Then: **Start with a sample form** / **Create my own**. Never a permissions prompt on screen 1; ask for camera at first actual use.

## 5. Copy rules

From the design skill, and they apply to every string in the app:

- Name things by what the person controls, never by how the system works. "Fields," not "schema." "Scan," not "capture pipeline." Never "OCR," never "LLM," never "AI-powered."
- Active voice, and an action keeps its name through the whole flow: the button says **Export**, the toast says **Exported**.
- Errors state what happened and what to do, in the interface's voice. No apologies, no vagueness.
- Empty states are invitations with one action, not mood pieces.
- Numbers always in mono, always with a unit or noun: `142 records`, not `142`.
- Sentence case everywhere except `sectionHeader` and `StampBadge`.

## 6. Motion

One orchestrated moment; everything else quiet.

**The signature animation:** on arriving at Review, values appear on their rules in sequence — 40ms stagger, 180ms each, slight upward offset and opacity, as if typed onto the form. Then, 200ms later, the rules themselves resolve to their confidence style (dashed and dotted rules draw in). The order is deliberate: *value first, judgement second*.

Everything else: default SwiftUI transitions, 200ms, standard easing. No parallax, no bounce, no shimmer, no confetti — not even on purchase. A tool does not celebrate at you.

Respect `accessibilityReduceMotion`: all values appear at once, rules render statically, no stagger.

## 7. Accessibility — a quality floor, not a feature

- Dynamic Type through accessibility3 on every screen, including the mono data style.
- VoiceOver: `FieldRow` reads "Quantity, 14, high confidence" — **confidence must be spoken**, since the rule style is purely visual and it carries real information.
- Confidence is never conveyed by colour alone: solid/dashed/dotted is the primary channel, colour is secondary, and `StampBadge` carries the word.
- All contrast ≥ 4.5:1 for text. **Checked:** every text token in §2 passes in both themes. `inkMuted` on `paper` — the pair flagged as at risk — is 5.9:1, and the tightest pair in the whole palette is `stamp` on `paper` at 5.2:1. Dark mode is more comfortable throughout (6.1:1 and above). No token needs adjusting; re-check only if a hue changes.
- Minimum 44×44pt targets. Cell edit taps in `CellGrid` need care; expand the hit area beyond the visual cell.
- Full keyboard support on iPad in `CellGrid`: Tab, Shift-Tab, arrows, Return to commit.

## 8. iPad

Not a separate design, but must not look broken — one of the four criteria is care.

- `NavigationSplitView`: templates in the sidebar, detail on the right.
- Template grid goes to three columns.
- `CellGrid` gets more visible columns and real keyboard navigation.
- Sheets present as form sheets, not full-screen.
- Test in Split View at 1/3 width. That is where naive SwiftUI layouts fall apart, and it is thirty minutes of fixing.

### 8.1 As built

Verified on an iPad Pro 11-inch (M5) simulator, portrait, at default type and at accessibility3.

| Spec item | Built | Note |
|---|---|---|
| Sidebar | `.tabViewStyle(.sidebarAdaptable)` on the root `TabView` | Not `NavigationSplitView` — see below |
| Three-column grid | Done | `.adaptive(minimum: 240)` on regular width; three in portrait, four in landscape, two on a phone |
| Readable measure | Done | `carbonReadableWidth()` on every prose-and-buttons screen |
| `CellGrid` columns | Done | Columns absorb spare width up to 2× the base; five fields fit an 834pt page with no scrolling |
| Form sheets | Already correct | `.sheet` is a form sheet on iPad by default; camera and processing stay `fullScreenCover`, which is right for both |
| Keyboard navigation in the grid | **Not built** | See below |

**Why not `NavigationSplitView`.** The root is a `TabView`, and on iPadOS 26 `.sidebarAdaptable` already turns the tab bar into a sidebar. Putting a split view inside a tab of that sidebar produces a sidebar inside a sidebar. The spec was written before the root settled on tabs; one sidebar is the intent, and this is the one that costs nothing on iPhone.

**Why not keyboard navigation.** Arrow-key cell selection needs a focus model, key handling and scroll-to-focus, and none of it can be driven on a simulator without a hardware keyboard — it would ship unverified, which the definition of done forbids. Touch is how a judge will use the grid. Left out deliberately.

**Split View at 1/3 width is inferred, not driven.** At that width the app is in a compact horizontal size class, which is the same layout verified extensively on iPhone including at accessibility3. The `horizontalSizeClass` branches above are what make that true. The Split View gesture itself was not performed.

One system behaviour worth knowing: at accessibility sizes the taller tab pill displaces the large navigation title on the templates screen, so the title is not drawn. The pill itself names the tab, so the screen still identifies itself. Not our layout, and not worth fighting.

---

## 9. v0 prompt pack

v0 produces React/Tailwind. You are using it to **see and iterate on the design**, then hand screenshots plus this document to Claude Code. Do not ask v0 for iOS code.

**Paste this preamble before every screen prompt:**

> Design a single mobile screen (390×844 viewport, iPhone) as a static React + Tailwind component. This is a **design mockup for translation to native SwiftUI** — no routing, no state management, no backend, hardcode all data.
>
> Design system, follow exactly:
> - Background `#EDEDE4`, raised surfaces `#F6F6F0`, primary text `#1E1B2E`, secondary text `#5C566E`, accent `#3D2E8C`, accent fill `#E4E0F4`, hairlines `#8E9384` at 50%, alert `#B3322A`, alert fill `#F5E3E0`, confirm `#4A6B3F`.
> - Typography: a **serif** face for screen titles and headlines (substitute a serif close to Apple's New York); a neutral sans for labels, buttons and body; a **monospaced** face for every data value and number. This pairing is deliberate — do not use the sans for data values.
> - No drop shadows anywhere. Separation is hairline borders plus surface fill only.
> - Radius 10 on cards and sheets, 6 on chips and buttons, **0 on table cells and rules**.
> - 4pt spacing grid.
> - The signature element: every extracted data value sits **on a horizontal rule**, like ink on a printed form line. The rule's style encodes confidence — solid dark = high, dashed accent = medium, dotted red = needs review. Render all three states somewhere on screen.
> - Tone: a precise, unshowy tool for someone doing a job. Not playful, not enterprise-grey. Think ledger paper and rubber stamps, not SaaS dashboard.
> - No gradients, no glassmorphism, no emoji, no stock illustration.

**Then append one of these:**

1. **Templates** — "Screen title 'Templates' in the serif face. A two-column grid of template cards; each card has an outlined icon, a serif name, a small sans subtitle, a record count in mono, and a relative timestamp. Use realistic names: 'Daily Register', 'Delivery Challan', 'Intake Form', 'Stock Count'. The last grid item is an empty 'New template' card with a dashed border and a plus icon. Bottom tab bar with two items: Templates, Settings."

2. **Review, record mode** — "A page thumbnail at top with an outlined, slightly rotated 'NEEDS REVIEW' stamp badge in uppercase letterspaced type beside it. Below, a list of six field rows. Each row: small uppercase sans label, then the value in mono sitting on a confidence rule. Show two solid rules, two dashed accent rules, and two dotted red rules — one of the red ones with an empty value. Reordered so the red ones are at the top. Bottom bar: full-width accent 'Save record' button with '3 need review' in mono beside it."

3. **Review, table mode** — "A data grid with square cells and hairline borders, a sticky header row of column names in uppercase sans, row numbers in a narrow leading gutter, and all cell values in mono. Eight rows, five columns ('Date', 'Item', 'Qty', 'Rate', 'Amount'). Three individual cells tinted with the pale red alert fill. Header above the grid reads '14 rows found · 3 cells need review'. Bottom bar with an accent 'Save 14 records' button. Grid scrolls horizontally."

4. **Template editor** — "A sheet. At top, a small thumbnail of a scanned paper form. Then a name field, a subtitle field, and a two-option segmented control 'Record / Table' with one line of explanatory text under the selection. Then an uppercase section header 'FIELDS' with a trailing hairline running to the screen edge, and a reorderable list of five field rows, each with a label, a small outlined type chip ('Text', 'Date', 'Number', 'Currency'), and a drag handle. Below, an outlined 'Add field' row. Above it, a subtle accent-filled suggestion row: 'Use detected columns — 5 found'."

5. **Paywall** — "Serif headline 'Carbon Pro'. One line of sans subtext. Four feature lines, each with a small outlined check: 'Unlimited templates', 'Unlimited records', 'CSV export', 'Everything stays on your device'. Three selectable price cards — Monthly $4.99, Annual $29.99 (with a small outlined 'Save 50%' badge and a line reading '7-day free trial'), Lifetime $49.99 — all prices in mono, the Annual one selected with an accent border and accent fill. Full-width accent 'Continue' button. Small 'Restore purchases' text link, then tiny Terms and Privacy links."

6. **Empty state** — "A centred empty state: a large thin outlined document icon, a serif headline 'No templates yet.', one line of sans body 'A template teaches Carbon the shape of one paper form. You'll only do this once per form.', a full-width accent 'Create your first template' button, and a secondary text button 'Use a sample form'."

**After v0 generates:** screenshot each screen, drop the images into the repo under `docs/design/`, and reference them from `CLAUDE.md`. Claude Code builds SwiftUI from the screenshots **plus** this spec — not from v0's JSX. Tell it explicitly to ignore web idioms: hover states, `cursor-pointer`, web-style nav bars, and CSS transitions all have native equivalents or no equivalent, and translating them literally is how a native app ends up feeling like a website.
