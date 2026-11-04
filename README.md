# SupremeTradeChecker

Standalone Android trade calculator for Murder Mystery 2, built with Flutter.

This is a separate project. It does not modify or depend on the LiberiumHub Roblox script.

## Features

- Offline-first item catalogue stored locally in SQLite.
- Manual refresh from the public Supreme Values category pages.
- Manual offer / receive entry with quantities.
- Strict item matching: exact normalized item names only; there is no fuzzy auto-match. Ambiguous or unpriced items remain **UNKNOWN DATA** and are never treated as zero. Untradable entries are imported without invented prices.
- WIN / FAIR / LOSE result using a configurable-in-code default tolerance of ±5%.
- Atomic catalogue refresh: failed or incomplete downloads do not replace the last good database.

## Data source and limitations

Values are read from the public Supreme Values MM2 pages:
https://www.supremevalues.com/mm2/

Supreme Values is a community value list, not an official Roblox or MM2 price feed. Values can change and listed values are not guaranteed trade prices. The app shows the source/update information available from the pages and should be used as a comparison aid, not as a guarantee.

The app does not connect to Roblox, inject scripts, inspect game UI, read player inventories, or send/accept/decline trades. All trade entries are entered manually.

## Build

Requirements: Flutter stable, Android SDK, and Java 17.

```bash
flutter pub get
flutter test
flutter run
```

To produce an APK:

```bash
flutter build apk --release
```

A GitHub Actions workflow is included to generate the standard Android platform scaffold, run tests, build a release APK, and publish it as a workflow artifact.

## First launch

The local database starts empty. Open **Update database** while online once. Successful data is saved locally and remains available offline. A failed or rejected refresh leaves the previous catalogue untouched.

## Project status

Initial project scaffold. The environment used to prepare this repository did not have the Flutter/Dart SDK installed, so a local Android build could not be run here. The GitHub Actions workflow provides a reproducible Flutter build check.
