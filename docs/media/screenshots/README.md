# Screenshots

**1179×2556, no device frame** — the size `07-build-plan.md` Day 6 asks for. That is an
iPhone 15 Pro; an iPhone 16 Pro is 1206×2622 and an iPhone 17 is different again, so the device
matters if these are ever regenerated.

Numbered in gallery order, payoff first. A judge scrolling a Devpost gallery sees the first two
and decides whether to look at the rest, so "one photo became seven rows" leads and the home
screen comes last.

| File | What it shows |
|---|---|
| `01-rows-from-one-photo.png` | One photograph of a register, seven rows in the grid. The product in one image |
| `02-map-the-form-once.png` | **Use detected columns — 5 found**, each with its guessed type and the values behind the guess |
| `03-confidence-on-every-value.png` | A record, every value on a rule whose style is its confidence |
| `04-where-it-came-from.png` | The photograph zoomed to the exact cell a value was read from, boxed in red |
| `05-one-dataset.png` | The dataset, with All / Needs review / Confirmed carrying their counts |
| `06-the-template.png` | The template that produced it all, with the types read off the page |
| `07-home.png` | Templates. One is the free tier, which is why the second card is locked |

Everything on screen is real: the values were extracted from
`Carbon/Resources/SampleForms/daily-register.jpg` by the actual pipeline. Nothing is mocked, and
no row says `Test Item`.

## Regenerating them

```bash
xcrun simctl create "Carbon Shots" com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5
xcrun simctl boot <udid>
xcrun simctl status_bar <udid> override --time "9:41" --batteryState charged \
  --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3
xcrun simctl addmedia <udid> Carbon/Resources/SampleForms/daily-register.jpg
xcrun simctl io <udid> screenshot shot.png
```

The status-bar override is what gives every shot 9:41 and a full battery. Without it each frame
carries a different clock and a half-drained battery, which is the detail that makes a set of
screenshots look assembled rather than captured.
