import Testing
import Foundation
import PDFKit
@testable import FireDoorLog

/// The checklist has to fit the assembly in front of the inspector. A door with no coordinator
/// must never be failed for one, and must never be asked about it either.
struct ApplicableCheckTests {
    private func door(pair: Bool = false, coordinator: Bool = false, glazing: Bool = false) -> Door {
        let d = Door(openingNumber: "101", location: "Corridor")
        d.isPair = pair; d.hasCoordinator = coordinator; d.hasGlazing = glazing
        return d
    }

    @Test func aSingleLeafIsNeverAskedAboutACoordinator() {
        #expect(!door().applicableChecks.contains(.coordinator))
    }

    @Test func aPairWithoutACoordinatorIsNotAskedEither() {
        #expect(!door(pair: true, coordinator: false).applicableChecks.contains(.coordinator))
    }

    @Test func aPairWithACoordinatorIs() {
        #expect(door(pair: true, coordinator: true).applicableChecks.contains(.coordinator))
    }

    @Test func glazingIsOnlyAskedWhereThereIsGlass() {
        #expect(!door().applicableChecks.contains(.glazing))
        #expect(door(glazing: true).applicableChecks.contains(.glazing))
    }

    @Test func everySolidSingleLeafStillGetsTheCoreItems() {
        let checks = Set(door().applicableChecks)
        for required: DoorCheck in [.label, .holes, .alignment, .missingParts, .clearances,
                                    .selfClosing, .latching, .auxiliaryHardware,
                                    .fieldModifications, .gasketing, .signage] {
            #expect(checks.contains(required), "\(required) is a minimum item")
        }
    }
}

struct VerdictTests {
    private func inspected(_ configure: (DoorInspection, Door) -> Void) -> DoorInspection {
        let d = Door(openingNumber: "104", location: "Kitchen")
        let i = DoorInspection(date: .now)
        i.door = d
        d.inspections = [i]
        configure(i, d)
        return i
    }

    @Test func anUntouchedInspectionIsNotAPass() {
        let i = inspected { _, _ in }
        #expect(i.verdict == .incomplete, "silence is not compliance")
        #expect(i.checkedCount == 0)
    }

    @Test func allPassesIsCompliant() {
        let i = inspected { i, d in for c in d.applicableChecks { i.set(.pass, for: c) } }
        #expect(i.verdict == .compliant)
    }

    @Test func oneDeficiencyOutranksEveryPass() {
        let i = inspected { i, d in
            for c in d.applicableChecks { i.set(.pass, for: c) }
            i.set(.deficient, for: .latching)
        }
        #expect(i.verdict == .deficient)
        #expect(i.deficiencies == [.latching])
    }

    @Test func notApplicableCountsAsAnsweredButNotAsAFailure() {
        let i = inspected { i, d in for c in d.applicableChecks { i.set(.notApplicable, for: c) } }
        #expect(i.verdict == .compliant)
    }

    @Test func oneItemLeftBlankKeepsItIncomplete() {
        let i = inspected { i, d in
            for c in d.applicableChecks.dropLast() { i.set(.pass, for: c) }
        }
        #expect(i.verdict == .incomplete)
    }

    @Test func resultsAreKeptByNameSoAddingACheckCannotRewriteHistory() {
        let i = inspected { i, _ in i.set(.deficient, for: .selfClosing) }
        #expect(i.resultsRaw["selfClosing"] == "deficient")
        #expect(i.result(.latching) == .notChecked)
    }
}

/// Annual means annual, and a register that has never been walked must not look current.
struct RegisterTests {
    private func building(doors: [(days: Int?, deficient: Bool)]) -> Building {
        let b = Building(name: "Meridian General", address: "400 Chandler St")
        var list: [Door] = []
        for (index, spec) in doors.enumerated() {
            let d = Door(openingNumber: "\(100 + index)", location: "Corridor")
            d.routeOrder = index
            d.building = b
            if let days = spec.days {
                let i = DoorInspection(date: Calendar.current.date(byAdding: .day, value: -days, to: .now)!)
                i.door = d
                for c in d.applicableChecks { i.set(.pass, for: c) }
                if spec.deficient { i.set(.deficient, for: .latching) }
                d.inspections = [i]
            }
            list.append(d)
        }
        b.doors = list
        return b
    }

    @Test func aDoorNeverInspectedIsNotCurrent() {
        let b = building(doors: [(nil, false)])
        #expect(!b.sortedDoors[0].isCurrent())
        #expect(b.doorsInspected() == 0)
        #expect(b.overdueDoors().count == 1)
    }

    @Test func insideTwelveMonthsIsCurrentAndBeyondIsNot() {
        let b = building(doors: [(30, false), (400, false)])
        #expect(b.sortedDoors[0].isCurrent())
        #expect(!b.sortedDoors[1].isCurrent())
        #expect(b.doorsInspected() == 1)
    }

    @Test func progressIsNilRatherThanZeroWhenThereIsNoRegister() {
        let empty = Building(name: "Annexe", address: "")
        #expect(empty.progress() == nil, "no denominator, so no percentage")
        #expect(building(doors: [(30, false), (nil, false)]).progress() == 0.5)
    }

    @Test func deficientDoorsAreCountedSeparatelyFromOverdueOnes() {
        let b = building(doors: [(30, true), (400, false), (20, false)])
        #expect(b.deficientDoors().count == 1)
        #expect(b.overdueDoors().count == 1, "a deficient door inspected last month is not overdue")
    }

    @Test func doorsComeBackInRouteOrder() {
        let b = building(doors: [(nil, false), (nil, false), (nil, false)])
        #expect(b.sortedDoors.map(\.routeOrder) == [0, 1, 2])
    }
}

struct ExportTests {
    private func loaded() -> Building {
        let b = Building(name: "Meridian General", address: "400 Chandler St")
        b.authority = "State Fire Marshal"
        let clean = Door(openingNumber: "101A", location: "Main corridor")
        clean.routeOrder = 1
        clean.building = b
        let ci = DoorInspection(date: Calendar.current.date(byAdding: .day, value: -30, to: .now)!)
        ci.inspectorName = "A. Reyes"
        ci.certificationNumber = "FDAI 24-1187"
        for c in clean.applicableChecks { ci.set(.pass, for: c) }
        ci.door = clean
        clean.inspections = [ci]

        let bad = Door(openingNumber: "104", location: "Kitchen to corridor")
        bad.routeOrder = 2
        bad.rating = .sixty
        bad.building = b
        let bi = DoorInspection(date: Calendar.current.date(byAdding: .day, value: -30, to: .now)!)
        bi.inspectorName = "A. Reyes"
        for c in bad.applicableChecks { bi.set(.pass, for: c) }
        bi.set(.deficient, for: .auxiliaryHardware)
        bi.setNote("Rubber wedge under the door.", for: .auxiliaryHardware)
        bi.correctiveAction = "Wedge removed, staff briefed."
        bi.door = bad
        bad.inspections = [bi]

        let never = Door(openingNumber: "210", location: "Records store")
        never.routeOrder = 3
        never.building = b

        b.doors = [clean, bad, never]
        return b
    }

    @Test func csvHasAHeaderAndOneRowPerInspection() throws {
        let text = try String(contentsOf: try CSVExporter.export([loaded()]), encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 3, "the never-inspected opening contributes no inspection row")
        #expect(lines[0].hasPrefix("building,address,opening,location,floor,rating_minutes"))
        #expect(lines[0].contains("selfClosing"))
    }

    @Test func csvQuotesANoteContainingAComma() throws {
        let b = loaded()
        b.sortedDoors[1].latest?.correctiveAction = "Wedge removed, staff briefed"
        let text = try String(contentsOf: try CSVExporter.export([b]), encoding: .utf8)
        #expect(text.contains("\"Wedge removed, staff briefed\""))
    }

    @Test func thePdfLeadsWithTheCountsASurveyorReadsFirst() throws {
        let url = try PDFExporter.export(loaded())
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("Fire door inspection record"))
        #expect(text.contains("3 openings in the register"))
        #expect(text.contains("2 inspected within twelve months"))
        #expect(text.contains("1 with deficiencies"))
    }

    @Test func thePdfNamesTheGapRatherThanHidingIt() throws {
        let url = try PDFExporter.export(loaded())
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("1 openings have no inspection inside the last twelve months"))
        #expect(text.contains("never inspected"))
    }

    @Test func thePdfListsThePassingOpeningsToo() throws {
        let url = try PDFExporter.export(loaded())
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // A record of only the failures is not evidence that anything else was looked at.
        #expect(text.contains("101A"))
        #expect(text.contains("Compliant"))
    }

    @Test func thePdfCarriesTheDeficiencyAndItsNote() throws {
        let url = try PDFExporter.export(loaded())
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("No interfering hardware: Rubber wedge under the door."))
        #expect(text.contains("Corrective action: Wedge removed"))
    }

    @Test func thePdfDoesNotClaimToApproveAnything() throws {
        let url = try PDFExporter.export(loaded())
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("does not inspect, certify or approve any assembly"))
    }

    @Test func anEmptyRegisterSaysSo() throws {
        let url = try PDFExporter.export(Building(name: "Annexe", address: ""))
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("No openings have been added to this register"))
    }
}
