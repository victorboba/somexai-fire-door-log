import Foundation
import WidgetKit

enum WidgetSync {
    /// One number on the Home Screen: how many openings are left in the cycle.
    static func update(with buildings: [Building]) {
        let remaining = buildings.reduce(0) { $0 + $1.overdueDoors().count }
        let deficient = buildings.reduce(0) { $0 + $1.deficientDoors().count }
        var snapshot = WidgetSnapshot()
        snapshot.totalEntries = buildings.reduce(0) { $0 + $1.doorCount }
        snapshot.remaining = remaining
        snapshot.lastEntryTitle = deficient > 0 ? "\(deficient) with deficiencies" : nil
        snapshot.lastEntryDate = nil
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
