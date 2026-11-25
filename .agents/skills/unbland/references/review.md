# Screenshots and the fresh-eyes review

## Screenshots

From the user, or from an Android device on `adb` with a debug build installed. Use
`screencap` on the device and `adb pull` (redirecting `adb exec-out` in PowerShell can
corrupt the PNG). Folder `.craft/shots/`:

```sh
mkdir -p .craft/shots          # PowerShell: New-Item -ItemType Directory -Force .craft/shots
adb shell screencap -p /sdcard/craft.png
adb pull /sdcard/craft.png .craft/shots/home.png
```

iOS simulator: `xcrun simctl io booted screenshot .craft/shots/home.png`.

Large-text pass on Android (always restore afterwards):

```sh
adb shell settings put system font_scale 1.3
# same screenshots, then:
adb shell settings put system font_scale 1.0
```

Narrow-width pass: `adb shell wm density 560` makes a 1080px phone about 308dp wide;
restore with `adb shell wm density reset`. Tell the user before changing device settings.

Suggest adding `.craft/` to `.gitignore`; don't edit it without asking. View each image
before judging it.

## Fresh-eyes review

The auditor is biased toward its own reading. Hand the review to a sub-agent with only:
the screenshots, the screen's source paths, the design contract, `references/gates.md`,
and the prompt below. No audit notes, no intent. Fill in the product line from the
contract's Direction.

### Prompt

> You are reviewing screens of <app name>, <one-line description from the contract>. You
> did not design them and won't be told why anything is the way it is. Judge what is on
> screen.
>
> Look at every screenshot first; open source files only to locate a finding.
>
> First line, one word: `ship` (nothing owed), `fix` (findings follow), `rework` (the
> screen fails its job or the system wholesale), or `recapture` (a screenshot is missing,
> blank or wrong; list what to retake and stop).
>
> Then at most eight findings, ranked by cost to the user, one line each: gate id or plain
> defect, where, what you'd do. Check in this order:
> 1. Can you tell in two seconds what this screen is for and what matters most? (squint test)
> 2. Anything unreadable, too small to tap, clipped at large text, or hidden under the nav?
> 3. Anything that reads as a default nobody chose: gradient, glow, glass, emoji icon,
>    tracked-caps label, icon-in-tile, box-everything, accent on everything? Name it and where.
> 4. Would any heading or line of copy work unchanged in a competitor's app? Quote it.
> 5. Does it look like the same product as the other screens (type, spacing, radius, colour)?
>
> Not findings: a direction you'd have chosen differently; anything the contract sets on
> purpose.
>
> Close with one line: what is good here and must not be diluted while fixing. Don't fix anything.
