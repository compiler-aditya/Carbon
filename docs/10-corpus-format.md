# Carbon — Corpus Format

What a collector produces, and what `CorpusHarness` reads. Companion to `07-build-plan.md` §5.

**The corpus is never committed.** Even with invented data, a public folder of photographed
forms is a liability and a distraction. Keep it in shared storage; commit only the aggregate
numbers and a handful of explicitly-cleared examples as `Carbon/Resources/SampleForms/`.

---

## Directory

```
corpus/
├── manifest.json
├── daily-register_priya_01.jpg
├── daily-register_priya_01.json
├── daily-register_priya_02.jpg
├── daily-register_priya_02.json
└── intake_arun_01.jpg   …
```

One image per photograph, named `<formtype>_<collector>_<nn>.jpg`, and one `.json` of ground
truth beside it with the same stem. An image with no `.json` is skipped and reported — that is
a collection mistake, not a result.

## `manifest.json`

Declares a template per form type. The harness needs it because extraction is meaningless
without a template: measuring Carbon means measuring it doing the thing it actually does.

```json
{
  "templates": [
    {
      "formType": "daily-register",
      "name": "Daily Register",
      "mode": "table",
      "dateConvention": "dayMonthYear",
      "fields": [
        { "key": "date",   "label": "Date",   "type": "text" },
        { "key": "item",   "label": "Item",   "type": "text",     "aliases": ["particulars"] },
        { "key": "qty",    "label": "Qty",    "type": "integer",  "aliases": ["quantity"] },
        { "key": "amount", "label": "Amount", "type": "currency", "aliases": ["amt"] }
      ]
    }
  ]
}
```

`mode` is `record` or `table`. `type` is any `FieldType` raw value. `aliases` and `choices` are
optional.

## Ground truth

```json
{
  "formType": "daily-register",
  "isHandwritten": true,
  "conditions": ["glare", "skew"],
  "records": [
    { "date": "01/04/2026", "item": "Basmati rice 5kg", "qty": "12", "amount": "6720.00" },
    { "date": "01/04/2026", "item": "Mustard oil 1L",   "qty": "8",  "amount": "1484.00" }
  ]
}
```

- **One entry per ruled row**, in page order, for a table form. Exactly one for a record form.
- **`isHandwritten`** splits the headline number. Printed and handwritten behave so differently
  that one blended figure hides the interesting result, and the README reports them separately.
- **`isRendered`** marks a page this repository drew rather than photographed. Optional, and
  false by default, because a collected page is the normal case and should not have to declare
  itself. It exists for one reason: a rendered page has no camera in it — no skew, no shadow, no
  paper, no lens — so scoring against one measures the harness, never accuracy. When *every*
  page in a run carries it, the report prints its own disclaimer above the table, so a run with
  nothing photographed behind it cannot be pasted into the README as an accuracy claim. See
  `corpus-smoke/`, which ships with the repo so the harness can be run from a fresh clone.
- **`conditions`** is free-form and optional — `shadow`, `glare`, `skew`, `crease`, `low-light`,
  `flash`. It lets a bad number be attributed to a hard page rather than a regression.
- **Type values as Carbon would normalize them.** `6720.00`, not `₹6,720.00`. Scoring is an
  exact match on the normalized value, because a near-match is still a value the user has to
  fix, and a metric that forgives near-misses would report an accuracy the correction editor
  contradicts.
- **A field you leave out is not scored.** Omit anything genuinely illegible rather than
  guessing at it.

## Running it

```bash
cd Packages/CarbonCore
swift run CorpusHarness ../../corpus              # summary to the terminal
swift run CorpusHarness ../../corpus --markdown   # the README table
```

Progress goes to stderr, so `--markdown > accuracy.md` produces a clean file.

## What it reports, and why each number is there

| Number | What it answers |
|---|---|
| Records needing no correction | **The headline.** What a user experiences as "I didn't have to touch that row". |
| Field-level precision | How often an individual value is right. |
| Resolved by Tier 1 alone | Whether the deterministic path really carries the load, as the architecture claims. If this is low, the README is describing an app that does not exist. |
| Rows found correctly | Whether table detection found the right number of rows. A missed row is a different failure from a misread cell, and it is counted separately rather than folded in. |
| Median and p95 latency | Against the budgets in `02-system-design.md` §4. |
| Precision by field type | Where the weak spots actually are. |
| Where it fails | The fields that go wrong most often, so the README's failure section is specific rather than a shrug. |

Percentages are **truncated, never rounded up**. Understating is the whole posture of the
table: its argument is that the numbers are honest, and rounding in our own favour would
undercut that for a tenth of a percent.

A column with no pages behind it prints `—`, not `0.0%`. Absent data is not failure, and this
table goes into the README exactly as printed.

## Privacy

From `07-build-plan.md` §5, and not optional:

1. Collectors fill in blank forms themselves, or photograph **their own** documents.
2. **No real third-party personal data.** No customer names, phone numbers, addresses, ID
   numbers, medical or financial information belonging to anyone else. Invent the data.
3. The corpus stays out of the public repository.
