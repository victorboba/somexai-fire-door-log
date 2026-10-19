import Foundation

/// The one file to edit when starting a new app from this template.
/// Everything user-facing that changes per app (name, copy, product IDs, links) lives here.
/// Compiled into both the app and the widget, so keep it free of UIKit/SwiftUI imports.
enum AppConfig {
    // MARK: Identity
    static let appName = "Fire Door Inspection Log"
    static let bundleID = "com.example.fire-door-log"
    static let appGroupID = "group.com.example.fire-door-log"
    /// Your App Store ID once the app is live. The Rate button stays hidden while it is empty.(the number in the App Store URL).
    static let appStoreID = ""

    // MARK: Sync
    /// Set to true only after enabling iCloud + CloudKit on the App ID (see docs/capabilities.md).
    /// With false, SwiftData stores locally and the app works with no Apple capabilities at all.
    static let iCloudSyncEnabled = false

    // MARK: StoreKit (must match App Store Connect and StoreKit/Products.storekit)
    /// Apple allows only letters, digits, underscores and periods in product IDs, so hyphens in the bundle ID are dropped.
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    /// Hosted copy of PrivacyPolicyView, one page per app under somexai.com/privacy (somexai_corp repo, scripts/privacy.py).
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/fire-door-log/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: Copy
    /// What the app calls one record. "Entry" for a generic log; "Dose", "Visit", "Inspection" in real apps.
    static let entryNoun = "Inspection"
    static let entryNounPlural = "Inspections"
    /// File name stem for exports: "fire-door-log-2026-09-11.csv".
    static let exportFileStem = "fire-door-log"

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "building.2", title: "A register, not a job list",
                       body: "Every fire door assembly in the building, in the order you walk the corridor. NFPA 80 wants each one inspected annually."),
        OnboardingPage(symbol: "checkmark.circle", title: "Built for a morning of doors",
                       body: "One tap passes an assembly. You only slow down on what is actually wrong — usually the closer, the latch, or a wedge under the door."),
        OnboardingPage(symbol: "doc.richtext", title: "The record they ask for",
                       body: "One PDF per building: every opening, who inspected it, and every deficiency. Your data stays on your phone."),
    ]

    static let paywallSymbol = "checkmark.seal.fill"
    static let paywallHeadline = "Unlock \(appName)"
    static let paywallBenefits = [
        "Unlimited buildings, openings and inspections",
        "The annual inspection record as a PDF",
        "Photographs on deficiencies and labels",
        "No ads, no account, no tracking",
    ]

    // MARK: How-to guide (Settings → How do I use this app; also the ? button on the home screen)
    static let howToIntro = "Four steps. Building the register takes the longest, and only happens once."
    static let howTo: [HowToStep] = [
        HowToStep(symbol: "building.2", title: "Add the building",
                  body: "Tap Add a building and give it a name and address. Put the authority having jurisdiction in too — the fire marshal, the state agency, or the accreditor — because it prints on the record.",
                  tip: "One building per register. A campus with four buildings gets four."),
        HowToStep(symbol: "door.left.hand.closed", title: "Add the openings",
                  body: "Open the building and tap Add an opening. The opening number and where it is will do to start. Number the route position the way the corridor actually runs and you will never backtrack.",
                  tip: "Photograph the label on the hinge edge while you are standing there. It settles arguments later."),
        HowToStep(symbol: "checkmark.circle", title: "Walk it",
                  body: "Tap a door to inspect it. Tap Mark everything remaining as passing, then change only the items that are wrong. Any item you mark as a deficiency asks you to describe it, because a deficiency nobody can read is one nobody can repair.",
                  tip: "The To do tab shows only the openings with no inspection in the last twelve months."),
        HowToStep(symbol: "doc.richtext", title: "Produce the record",
                  body: "From the register, tap the ⋯ menu and choose Inspection record (PDF). It lists every opening, including the ones that passed, and the counts a surveyor reads first. Send it by Mail, AirDrop it, or save it to Files."),
        HowToStep(symbol: "wrench.and.screwdriver", title: "Close out the repairs",
                  body: "NFPA 80 asks for deficiencies to be repaired without delay. Reopen the inspection, write what was done, and switch Repaired on, so the fix stays attached to the finding."),
    ]

    /// Display prices used only by DEBUG screenshot runs (`-mockPrices`). Keep in sync with StoreKit/Products.storekit.
    static let mockPrices = (annual: "$19.99", lifetime: "$49.99")

    // MARK: Behaviour
    /// Ask for an App Store review after this many successful saves (once per app version).
    static let reviewAfterSuccesses = 3
}

struct HowToStep: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
    var tip: String? = nil
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
