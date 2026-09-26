<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Display Colour Filter icon">
</p>

<h1 align="center">Display Colour Filter</h1>

<p align="center">Turn macOS colour filters on or off for each display.</p>

macOS can apply colour filters — greyscale, colour-blindness filters and a colour tint — from **System Settings › Accessibility › Display**, but only to every display at once. Display Colour Filter is a small menu bar app that lets you decide, display by display, whether a filter is applied and which one.

For example, you can keep an external monitor in greyscale to cut down on distraction while the built-in display stays in full colour for design work.

## Features

- Turn the filter on or off for each connected display independently
- Choose a filter per display: Greyscale, Red/Green (Protanopia), Green/Red (Deuteranopia), Blue/Yellow (Tritanopia) or Colour Tint
- Adjust the intensity (and the hue for Colour Tint), using the same colour matrices as macOS itself
- Settings are remembered for each display
- Optionally open at login
- Updates itself: new versions are delivered from within the app, with release notes in your language
- Interface in English, Japanese, Simplified Chinese, Traditional Chinese, Korean, French, German and Spanish

## Requirements

- macOS 26 Tahoe or later
- A Mac with Apple silicon
- Displays driven directly by the Mac (built-in, USB-C / Thunderbolt, HDMI). Filters have no effect on virtual displays such as DisplayLink, AirPlay or Sidecar.

Tested on macOS 26.4 with a MacBook Air (M2) and an external USB-C display.

## Installation

Website: <https://yota.co/DisplayColourFilter>

1. Download [`DisplayColourFilter.dmg`](https://github.com/yotashiraishi/DisplayColourFilter/releases/latest/download/DisplayColourFilter.dmg) from the [latest release](https://github.com/yotashiraishi/DisplayColourFilter/releases/latest).
2. Open the disk image and drag **DisplayColourFilter** to **Applications**.
3. Open **DisplayColourFilter** from Applications.

The app is signed ad hoc but not notarised by Apple, so macOS blocks it the first time you open it:

1. When macOS says the app can’t be opened, click **Done**.
2. Open **System Settings › Privacy & Security**, scroll down to **Security** and click **Open Anyway** next to the message about DisplayColourFilter.
3. Confirm with your password or Touch ID, then click **Open Anyway** once more.

Alternatively, remove the quarantine flag in Terminal:

```sh
xattr -dr com.apple.quarantine /Applications/DisplayColourFilter.app
```

Version 1.0.0 can’t update itself. If you have it, install the latest version once in the same way; later versions are delivered from within the app.

## Usage

Click the icon in the menu bar (three overlapping circles). For each display you can:

- switch the filter on or off
- choose the filter type
- adjust the intensity, and the hue for Colour Tint

Changes take effect immediately. The gear menu at the bottom right of the panel has **Open at Login** (start the app automatically when you log in), **About**, **Check for Updates…** and **Quit**.

Keep the system-wide colour filter (System Settings › Accessibility › Display › Colour filters) **turned off** while you use the app. If both are on, the system filter briefly appears on every display whenever macOS reapplies it.

Quitting the app removes its filters and returns every display to the system setting.

## How it works

macOS has no public API for applying a colour filter to a single display. The system applies its colour filters through a private WindowServer (SkyLight) function, `SLSSetAccessibilityAdjustments`, which takes a 3×3 colour matrix and, optionally, a target display. Display Colour Filter creates the matrices with the same MediaAccessibility functions that macOS uses, and sends one matrix per display.

macOS reapplies its own colour matrix to every display from time to time — for example when displays are reconfigured or accessibility settings change. The app listens for those events, and for wake from sleep, and reapplies its per-display matrices straight afterwards.

Because it depends on private APIs:

- a future macOS update may break it (the app shows a message if the functions it needs are missing)
- it can’t be distributed through the Mac App Store

## Building from source

Requires Xcode 26 (Swift 6.2 or later).

```sh
bash scripts/build-app.sh   # builds build/DisplayColourFilter.app
bash scripts/build-dmg.sh   # also packages dist/DisplayColourFilter.dmg
```

## Releasing

Updates are delivered with [Sparkle](https://sparkle-project.org). The app reads `https://yota.co/DisplayColourFilter/appcast.xml`, downloads the DMG from the GitHub release and checks its EdDSA signature against `SUPublicEDKey` in `Resources/Info.plist`. The private key is stored in the login keychain of the Mac that makes releases. Keep a backup (`.build/artifacts/sparkle/Sparkle/bin/generate_keys -x <file>`): without it, installed copies can’t receive updates.

1. Raise `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist` (Sparkle compares `CFBundleVersion`).
2. Write the release notes as HTML fragments in `release-notes/<version>/<language>.html` for every language (en, ja, zh-Hans, zh-Hant, ko, fr, de, es). The app shows the ones that match the user’s language, or English.
3. Build and sign:

   ```sh
   bash scripts/build-dmg.sh
   bash scripts/make-appcast.sh   # signs the DMG and rewrites site/src/appcast.xml
   ```

4. Publish the GitHub release with the same DMG, tagged `v<version>`:

   ```sh
   gh release create v1.1.0 dist/DisplayColourFilter.dmg --title "Display Colour Filter 1.1.0" --notes-file release-notes/1.1.0/en.html
   ```

5. Deploy the website and the appcast (only after the release exists, so that the download link works):

   ```sh
   cd site && npx wrangler deploy
   ```

The website in `site/` is a Cloudflare Worker that serves static files at `yota.co/DisplayColourFilter`. `site/build.mjs` generates a page for each language from `site/src/index.html` and `site/src/lang/*.json`, and takes the version number from `Resources/Info.plist`.

## Uninstalling

In the gear menu, turn off **Open at Login** if you enabled it and quit the app. Then move **DisplayColourFilter** from Applications to the Bin. Its settings are stored in `~/Library/Preferences/io.github.yotashiraishi.DisplayColourFilter.plist`.

## License

[MIT](LICENSE) © 2026 Yota Shiraishi

Display Colour Filter is not affiliated with or endorsed by Apple Inc.
