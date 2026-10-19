import Foundation
import SwiftData

/// One building, and the fire door assemblies in it.
///
/// Shaped around NFPA 80, which requires every fire door assembly to be inspected and tested
/// **annually**, with a written record kept and produced for the authority having jurisdiction.
/// That written record is what this app exists to make. A hospital has hundreds of openings and
/// gets surveyed on exactly this, which is why the app is built around walking a register rather
/// than filing one job at a time.
@Model
final class Building {
    var id: UUID = UUID()
    var name: String = ""
    var address: String = ""
    /// Who gets asked for the record: the fire marshal, the state agency, the accreditor.
    var authority: String = ""
    var ownerContact: String = ""
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Door.building)
    var doors: [Door]? = nil

    var createdAt: Date = Date()

    init(name: String = "", address: String = "") {
        self.id = UUID()
        self.name = name
        self.address = address
        self.createdAt = .now
    }

    /// Route order, because an inspector walks a corridor, not an alphabet.
    var sortedDoors: [Door] {
        (doors ?? []).sorted { ($0.routeOrder, $0.openingNumber) < ($1.routeOrder, $1.openingNumber) }
    }

    func doorsInspected(inCycleEnding today: Date = .now) -> Int {
        sortedDoors.filter { $0.isCurrent(asOf: today) }.count
    }

    var doorCount: Int { (doors ?? []).count }

    /// Doors carrying an unrepaired deficiency. NFPA 80 wants these repaired without delay,
    /// so they are counted separately from doors simply not yet reached.
    func deficientDoors(asOf today: Date = .now) -> [Door] {
        sortedDoors.filter { $0.latest?.verdict == .deficient }
    }

    func overdueDoors(asOf today: Date = .now) -> [Door] {
        sortedDoors.filter { !$0.isCurrent(asOf: today) }
    }

    /// Nothing to show a percentage of when the register is empty, so this is optional
    /// rather than a tidy zero.
    func progress(asOf today: Date = .now) -> Double? {
        guard doorCount > 0 else { return nil }
        return Double(doorsInspected(inCycleEnding: today)) / Double(doorCount)
    }
}

/// One fire door assembly — the opening, not just the leaf. NFPA 80 inspects the assembly:
/// door, frame, hardware, glazing, gasketing and signage together.
@Model
final class Door {
    var id: UUID = UUID()
    /// The number on the opening. This is how a facility refers to a door, and how a
    /// deficiency gets found again by whoever repairs it.
    var openingNumber: String = ""
    var location: String = ""
    var floor: String = ""
    var routeOrder: Int = 0

    var ratingRaw: Int = 90
    var assemblyRaw: String = AssemblyType.swinging.rawValue
    var isPair: Bool = false
    var hasGlazing: Bool = false
    var hasCoordinator: Bool = false
    var hasHoldOpen: Bool = false

    /// Off the label on the hinge edge. Without a legible label the assembly is not rated,
    /// which is itself a finding.
    var labelManufacturer: String = ""
    var labelNumber: String = ""

    @Attribute(.externalStorage) var photoData: Data? = nil
    var notes: String = ""
    var building: Building? = nil

    @Relationship(deleteRule: .cascade, inverse: \DoorInspection.door)
    var inspections: [DoorInspection]? = nil

    init(openingNumber: String = "", location: String = "") {
        self.id = UUID()
        self.openingNumber = openingNumber
        self.location = location
    }

    var rating: FireRating {
        get { FireRating(rawValue: ratingRaw) ?? .ninety }
        set { ratingRaw = newValue.rawValue }
    }

    var assembly: AssemblyType {
        get { AssemblyType(rawValue: assemblyRaw) ?? .swinging }
        set { assemblyRaw = newValue.rawValue }
    }

    var sortedInspections: [DoorInspection] {
        (inspections ?? []).sorted { $0.date > $1.date }
    }

    var latest: DoorInspection? { sortedInspections.first }

    var nextDue: Date? {
        guard let last = latest else { return nil }
        return Calendar.current.date(byAdding: .year, value: 1, to: last.date)
    }

    /// Annual means annual: inspected inside the last twelve months.
    func isCurrent(asOf today: Date = .now) -> Bool {
        guard let due = nextDue else { return false }
        return due >= Calendar.current.startOfDay(for: today)
    }

    func daysUntilDue(asOf today: Date = .now) -> Int? {
        guard let due = nextDue else { return nil }
        return Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: today),
            to: Calendar.current.startOfDay(for: due)).day
    }

    var title: String {
        let number = openingNumber.isEmpty ? "Unnumbered" : openingNumber
        return location.isEmpty ? number : "\(number) — \(location)"
    }

    /// The items this particular assembly has to answer. A door with no coordinator is not
    /// failed for a coordinator, and it is not shown one either.
    var applicableChecks: [DoorCheck] {
        DoorCheck.allCases.filter { check in
            switch check {
            case .glazing: return hasGlazing
            case .coordinator: return isPair && hasCoordinator
            default: return true
            }
        }
    }
}

/// One annual inspection of one assembly.
@Model
final class DoorInspection {
    var id: UUID = UUID()
    var date: Date = Date()
    var inspectorName: String = ""
    /// FDAI or equivalent. NFPA 80 wants a knowledgeable inspector; the AHJ decides who counts.
    var certificationNumber: String = ""
    /// Raw check results, keyed by `DoorCheck.rawValue`, so adding a check later cannot
    /// invalidate a stored inspection.
    var resultsRaw: [String: String] = [:]
    var deficiencyNotes: [String: String] = [:]
    @Attribute(.externalStorage) var deficiencyPhoto: Data? = nil
    var correctiveAction: String = ""
    var repairedOn: Date? = nil
    var notes: String = ""
    var door: Door? = nil

    init(date: Date = .now) {
        self.id = UUID()
        self.date = date
    }

    func result(_ check: DoorCheck) -> CheckResult {
        CheckResult(rawValue: resultsRaw[check.rawValue] ?? "") ?? .notChecked
    }

    func set(_ result: CheckResult, for check: DoorCheck) {
        resultsRaw[check.rawValue] = result.rawValue
    }

    func note(_ check: DoorCheck) -> String { deficiencyNotes[check.rawValue] ?? "" }

    func setNote(_ text: String, for check: DoorCheck) {
        if text.isEmpty { deficiencyNotes.removeValue(forKey: check.rawValue) }
        else { deficiencyNotes[check.rawValue] = text }
    }

    var deficiencies: [DoorCheck] {
        (door?.applicableChecks ?? DoorCheck.allCases).filter { result($0) == .deficient }
    }

    var checkedCount: Int {
        (door?.applicableChecks ?? DoorCheck.allCases).filter { result($0) != .notChecked }.count
    }

    /// The line the record exists to carry.
    var verdict: DoorVerdict {
        let applicable = door?.applicableChecks ?? DoorCheck.allCases
        if !deficiencies.isEmpty { return .deficient }
        if applicable.contains(where: { result($0) == .notChecked }) { return .incomplete }
        return .compliant
    }

    var day: Date { Calendar.current.startOfDay(for: date) }
}

// MARK: - The vocabulary of the standard

/// The NFPA 80 §5.2.4 minimum inspection items, in the order an inspector actually works:
/// stand back and look at the assembly, then work the hardware, then close it.
///
/// The wording here is the plain-language version of what each item asks. The standard itself
/// is the authority; this is a field prompt, not a reprint of it.
enum DoorCheck: String, CaseIterable, Identifiable {
    case label, holes, glazing, alignment, missingParts, clearances
    case selfClosing, coordinator, latching, auxiliaryHardware
    case fieldModifications, gasketing, signage

    var id: String { rawValue }

    var name: String {
        switch self {
        case .label: return "Label legible"
        case .holes: return "No holes or breaks"
        case .glazing: return "Glazing and beads intact"
        case .alignment: return "Door, frame and hardware sound"
        case .missingParts: return "No missing or broken parts"
        case .clearances: return "Clearances within tolerance"
        case .selfClosing: return "Self-closing device works"
        case .coordinator: return "Coordinator sequences the leaves"
        case .latching: return "Latches when closed"
        case .auxiliaryHardware: return "No interfering hardware"
        case .fieldModifications: return "No label-voiding modifications"
        case .gasketing: return "Gasketing and edge seals intact"
        case .signage: return "Signage within limits"
        }
    }

    /// What the inspector is actually looking at. Written for someone in a corridor, not a
    /// code office.
    var hint: String {
        switch self {
        case .label:
            return "The rating label on the hinge edge of the door and on the frame. Painted over or missing means the assembly cannot be shown to be rated."
        case .holes:
            return "Holes from removed hardware, kick damage, drilled penetrations. Undersized filled holes count."
        case .glazing:
            return "Vision light frame, glazing beads and the glass itself: intact, correct type, securely fastened."
        case .alignment:
            return "Door, frame, hinges, hardware and threshold secure, aligned and undamaged. Look for racked frames and loose hinge screws."
        case .missingParts:
            return "Anything absent or broken: hinge screws, closer arms, astragals, latch parts."
        case .clearances:
            return "Under the door, and the gap at the top and sides on the pull side. The undercut is the one most often out."
        case .selfClosing:
            return "Open it fully and let go. It has to close on its own, every time."
        case .coordinator:
            return "On a pair: the inactive leaf must close before the active one."
        case .latching:
            return "It has to latch, not just close. Push on it after it shuts."
        case .auxiliaryHardware:
            return "Wedges, kick-down stops, chains, hold-open devices that are not fire-rated and release."
        case .fieldModifications:
            return "Anything cut, drilled or welded in the field that voids the label."
        case .gasketing:
            return "Where required: smoke seals, edge seals, intumescent strips present and unbroken."
        case .signage:
            return "Signs on the door face: within the area the standard allows, adhesive-attached, not on the glazing."
        }
    }

    /// The three items a survey writes up most often, flagged so a new inspector slows down.
    var isCommonlyCited: Bool {
        self == .selfClosing || self == .latching || self == .auxiliaryHardware
    }
}

enum CheckResult: String, CaseIterable, Identifiable {
    case notChecked, pass, deficient, notApplicable
    var id: String { rawValue }

    var name: String {
        switch self {
        case .notChecked: return "Not checked"
        case .pass: return "Pass"
        case .deficient: return "Deficiency"
        case .notApplicable: return "N/A"
        }
    }

    var symbol: String {
        switch self {
        case .notChecked: return "circle"
        case .pass: return "checkmark.circle.fill"
        case .deficient: return "exclamationmark.triangle.fill"
        case .notApplicable: return "minus.circle"
        }
    }
}

enum DoorVerdict {
    case incomplete, compliant, deficient

    var headline: String {
        switch self {
        case .incomplete: return "Not finished"
        case .compliant: return "Compliant"
        case .deficient: return "Deficiencies found"
        }
    }

    var detail: String {
        switch self {
        case .incomplete: return "Answer every item before the record counts as an inspection."
        case .compliant: return "The assembly met every item inspected on this date."
        case .deficient: return "NFPA 80 requires deficiencies to be repaired without delay. Record the repair when it is done."
        }
    }

    var symbol: String {
        switch self {
        case .incomplete: return "ellipsis.circle"
        case .compliant: return "checkmark.seal.fill"
        case .deficient: return "exclamationmark.triangle.fill"
        }
    }
}

enum FireRating: Int, CaseIterable, Identifiable {
    case twenty = 20, fortyFive = 45, sixty = 60, ninety = 90, oneEighty = 180
    var id: Int { rawValue }
    var name: String { "\(rawValue) min" }

    var typicalUse: String {
        switch self {
        case .twenty: return "Corridor and smoke barrier openings"
        case .fortyFive: return "One-hour partitions"
        case .sixty: return "One-hour walls and some stair enclosures"
        case .ninety: return "Two-hour walls, stair and shaft enclosures"
        case .oneEighty: return "Three-hour and four-hour fire walls"
        }
    }
}

enum AssemblyType: String, CaseIterable, Identifiable {
    case swinging, pairSwinging, rollingSteel, horizontalSliding, dutch, specialPurpose
    var id: String { rawValue }

    var name: String {
        switch self {
        case .swinging: return "Swinging, builders hardware"
        case .pairSwinging: return "Pair, swinging"
        case .rollingSteel: return "Rolling steel"
        case .horizontalSliding: return "Horizontal sliding"
        case .dutch: return "Dutch door"
        case .specialPurpose: return "Special purpose"
        }
    }
}
