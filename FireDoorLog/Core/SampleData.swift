import Foundation
import SwiftData

/// Debug fixtures: a register part-way through its annual cycle, with two real deficiencies.
/// A screen of green ticks would not show what the app is for.
enum SampleData {
    static func insert(into context: ModelContext) {
        let hospital = Building(name: "Meridian General", address: "400 Chandler St")
        hospital.authority = "State Fire Marshal / Joint Commission"
        hospital.ownerContact = "T. Okafor, Facilities"
        context.insert(hospital)

        func door(_ number: String, _ location: String, _ floor: String, order: Int,
                  rating: FireRating = .ninety, pair: Bool = false, glazing: Bool = false,
                  inspected daysAgo: Int? = nil,
                  deficiencies: [(DoorCheck, String)] = []) {
            let d = Door(openingNumber: number, location: location)
            d.floor = floor
            d.routeOrder = order
            d.rating = rating
            d.isPair = pair
            d.hasCoordinator = pair
            d.hasGlazing = glazing
            d.assembly = pair ? .pairSwinging : .swinging
            d.labelManufacturer = "Curries"
            d.labelNumber = "WH-\(Int.random(in: 100000...999999))"
            d.building = hospital
            context.insert(d)

            guard let daysAgo else { return }
            let i = DoorInspection(date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now)
            i.inspectorName = "A. Reyes"
            i.certificationNumber = "FDAI 24-1187"
            for check in d.applicableChecks { i.set(.pass, for: check) }
            for (check, note) in deficiencies {
                i.set(.deficient, for: check)
                i.setNote(note, for: check)
            }
            if !deficiencies.isEmpty {
                i.correctiveAction = "Work order raised with the door contractor."
            }
            i.door = d
            context.insert(i)
        }

        door("101A", "Main corridor to east wing", "1", order: 1, pair: true, glazing: true, inspected: 34)
        door("101B", "East wing stair enclosure", "1", order: 2, inspected: 34)
        door("104", "Kitchen to corridor", "1", order: 3, rating: .sixty, inspected: 33,
             deficiencies: [(.auxiliaryHardware, "Rubber wedge kicked under the door, holding it open."),
                            (.latching, "Does not latch; strike plate is out of alignment.")])
        door("112", "Soiled utility", "1", order: 4, rating: .fortyFive, inspected: 33)
        door("118", "Electrical room", "1", order: 5, inspected: 30)
        door("201", "Ward corridor cross-corridor", "2", order: 6, pair: true, inspected: 29,
             deficiencies: [(.selfClosing, "Right leaf stops about 50 mm short of the frame.")])
        door("204", "Linen store", "2", order: 7, rating: .fortyFive, inspected: 28)
        door("207", "West stair enclosure", "2", order: 8, inspected: 28)
        // The rest of the register: still to walk this cycle.
        door("210", "Records store", "2", order: 9, rating: .sixty)
        door("301", "Theatre corridor", "3", order: 10, pair: true, glazing: true)
        door("305", "Plant room", "3", order: 11, rating: .oneEighty)
        door("309", "North stair enclosure", "3", order: 12)

        let annexe = Building(name: "Meridian Annexe", address: "12 Chandler St")
        annexe.authority = "State Fire Marshal"
        context.insert(annexe)

        try? context.save()
    }
}
