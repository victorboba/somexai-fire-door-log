# Fire Door Inspection Log

The annual NFPA 80 inspection record for every fire door assembly in a building, produced in the corridor instead of typed up afterwards. It is for facility staff and independent fire door inspectors.

One of a set of niche iPhone apps built from a shared SwiftUI template. It was never released on the App Store; the code is here for anyone to use. The template is [somexai-ios-template](https://github.com/victorboba/somexai-ios-template) and the rest of the collection is in [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- A register, not a job list. The home screen shows how far through each building you are, and openings are ordered the way the corridor runs.
- One tap marks an assembly as passing every item, so you only slow down on what is wrong.
- The checklist fits the assembly: a single leaf is never asked about a coordinator, and a solid door is never asked about glazing.
- Marking an item deficient asks you to describe it. The corrective action and repair date stay attached to the finding.
- One PDF per building leads with openings in the register, openings inspected inside twelve months and openings with deficiencies, then lists every opening, including the ones that passed. A CSV has one row per inspection.
- Home Screen widget, a Siri/Shortcuts action, and a How do I use guide.

## The boundary

The app records what the inspector entered. It does not inspect, certify or approve any assembly, it is not an approved form for any jurisdiction, and the authority having jurisdiction remains the judge of the record. The checklist is a plain-language version of the standard's minimum items, not a reprint of it, and an authority may ask for more.

## Privacy

Everything is stored on the device in SwiftData. There is no account, no analytics and no network access, and iCloud sync is off (`iCloudSyncEnabled = false`). CSV and PDF files leave the phone only when you share them.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), iOS 17+ (iPhone).

```bash
xcodegen generate
open FireDoorLog.xcodeproj
```

Pick the `FireDoorLog` scheme and an iPhone simulator, then Run.

- Tests: `xcodebuild -scheme FireDoorLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test`
- Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings.
- To run on your own device or ship it: set your team in `project.yml` (`DEVELOPMENT_TEAM`), change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`, and update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Notes for developers

The unit tests cover which items apply to which assembly, the verdict logic (no answer is not a pass, and one deficiency outranks every pass), the annual clock, and the export contents.

## Project layout

- `FireDoorLog/App/`: app entry point and `RootView`, the single gate (onboarding, paywall, then the app).
- `FireDoorLog/Core/`: StoreKit entitlement, CSV and PDF export, review prompt, and the App Shortcut.
- `FireDoorLog/Features/`: the screens.
- `FireDoorLog/Models/`: SwiftData models and the logic on them.
- `FireDoorLogWidget/`: the Home Screen widget.
- `FireDoorLogTests/`, `FireDoorLogUITests/`: unit and UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, product IDs, links, how-to guide).

## License

MIT. See [LICENSE](LICENSE).
