import Foundation

/// One row per inspection of one opening, which is how a facility reconciles a register
/// against its work orders.
enum CSVExporter {
    static func export(_ buildings: [Building]) throws -> URL {
        var header = ["building", "address", "opening", "location", "floor", "rating_minutes",
                      "assembly", "date", "inspector", "certification", "verdict",
                      "deficiencies", "corrective_action", "repaired_on", "notes"]
        header.append(contentsOf: DoorCheck.allCases.map(\.rawValue))
        var rows = [header.joined(separator: ",")]

        for building in buildings.sorted(by: { $0.name < $1.name }) {
            for door in building.sortedDoors {
                for inspection in door.sortedInspections {
                    var cells = [
                        building.name, building.address, door.openingNumber, door.location,
                        door.floor, String(door.rating.rawValue), door.assembly.name,
                        ISO8601DateFormatter.day.string(from: inspection.date),
                        inspection.inspectorName, inspection.certificationNumber,
                        inspection.verdict.headline,
                        inspection.deficiencies.map(\.name).joined(separator: "; "),
                        inspection.correctiveAction,
                        inspection.repairedOn.map { ISO8601DateFormatter.day.string(from: $0) } ?? "",
                        inspection.notes,
                    ]
                    cells.append(contentsOf: DoorCheck.allCases.map { check in
                        inspection.result(check) == .notChecked ? "" : inspection.result(check).name
                    })
                    rows.append(cells.map(escape).joined(separator: ","))
                }
            }
        }
        let text = rows.joined(separator: "\n") + "\n"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(ISO8601DateFormatter.day.string(from: .now)).csv")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ value: String) -> String {
        value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" })
            ? "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
            : value
    }
}

extension ISO8601DateFormatter {
    static let day: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
