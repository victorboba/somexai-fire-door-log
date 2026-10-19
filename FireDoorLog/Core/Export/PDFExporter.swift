import Foundation
import PDFKit
import UIKit

/// The annual fire door inspection record.
///
/// This is the document the authority having jurisdiction asks for, and the reason the app
/// exists. So it leads with the count that a surveyor checks first — how many openings are in
/// the register and how many were actually inspected — then lists every opening, including the
/// ones that passed, because a report containing only deficiencies is not evidence that the
/// rest of the building was looked at.
enum PDFExporter {
    static func export(_ building: Building, asOf today: Date = .now) throws -> URL {
        let pageWidth: CGFloat = 612, pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(ISO8601DateFormatter.day.string(from: today)).pdf")

        try renderer.writePDF(to: url) { ctx in
            var y: CGFloat = margin
            ctx.beginPage()

            func line(_ text: String, size: CGFloat = 11, weight: UIFont.Weight = .regular,
                      colour: UIColor = .label, indent: CGFloat = 0, gapAfter: CGFloat = 4) {
                let font = UIFont.systemFont(ofSize: size, weight: weight)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colour]
                let width = pageWidth - margin * 2 - indent
                let bounding = (text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                if y + bounding.height > pageHeight - margin { ctx.beginPage(); y = margin }
                (text as NSString).draw(
                    with: CGRect(x: margin + indent, y: y, width: width, height: bounding.height),
                    options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                y += bounding.height + gapAfter
            }
            func rule(gap: CGFloat = 10) {
                y += gap / 2
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: y))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                UIColor.separator.setStroke(); path.lineWidth = 0.5; path.stroke()
                y += gap / 2
            }

            line("Fire door inspection record", size: 22, weight: .semibold)
            line("Annual inspection of fire door assemblies, NFPA 80", size: 11, colour: .secondaryLabel)
            rule()

            line(building.name.isEmpty ? "Unnamed building" : building.name, size: 13, weight: .semibold, gapAfter: 2)
            if !building.address.isEmpty { line(building.address, size: 10, colour: .secondaryLabel, gapAfter: 2) }
            if !building.authority.isEmpty { line("Authority having jurisdiction: \(building.authority)", size: 10, colour: .secondaryLabel, gapAfter: 2) }
            line("Record produced \(today.formatted(date: .long, time: .omitted))", size: 10, colour: .secondaryLabel)
            rule()

            // The three numbers a surveyor reads first.
            let total = building.doorCount
            let done = building.doorsInspected(inCycleEnding: today)
            let deficient = building.deficientDoors(asOf: today).count
            line("\(total) openings in the register  ·  \(done) inspected within twelve months  ·  \(deficient) with deficiencies",
                 size: 11, weight: .semibold,
                 colour: deficient > 0 ? .systemOrange : (done < total ? .systemOrange : .systemGreen))
            if done < total {
                line("\(total - done) openings have no inspection inside the last twelve months.",
                     size: 10, colour: .systemOrange)
            }
            rule()

            if building.sortedDoors.isEmpty {
                line("No openings have been added to this register.", colour: .secondaryLabel)
            }

            for door in building.sortedDoors {
                let inspection = door.latest
                let verdict = inspection?.verdict
                let colour: UIColor = switch verdict {
                case .some(.deficient): .systemRed
                case .some(.compliant): .label
                default: .systemOrange
                }
                var head = door.openingNumber.isEmpty ? "Unnumbered" : door.openingNumber
                if !door.location.isEmpty { head += "  \(door.location)" }
                if !door.floor.isEmpty { head += "  (\(door.floor))" }
                line(head, size: 10, weight: .semibold, colour: colour, gapAfter: 1)

                var parts = ["\(door.rating.name) rated", door.assembly.name]
                if !door.labelNumber.isEmpty { parts.append("label \(door.labelNumber)") }
                if let inspection {
                    parts.append(ISO8601DateFormatter.day.string(from: inspection.date))
                    parts.append(inspection.verdict.headline)
                    if !inspection.inspectorName.isEmpty {
                        let cert = inspection.certificationNumber.isEmpty ? "" : " (\(inspection.certificationNumber))"
                        parts.append(inspection.inspectorName + cert)
                    }
                } else {
                    parts.append("never inspected")
                }
                line(parts.joined(separator: "  ·  "), size: 9, colour: .secondaryLabel, indent: 12, gapAfter: 1)

                if let inspection {
                    for check in inspection.deficiencies {
                        let note = inspection.note(check)
                        line("\(check.name)\(note.isEmpty ? "" : ": \(note)")",
                             size: 9, colour: .systemRed, indent: 12, gapAfter: 1)
                    }
                    if !inspection.correctiveAction.isEmpty {
                        let repaired = inspection.repairedOn
                            .map { " — repaired \(ISO8601DateFormatter.day.string(from: $0))" } ?? ""
                        line("Corrective action: \(inspection.correctiveAction)\(repaired)",
                             size: 9, colour: .secondaryLabel, indent: 12, gapAfter: 1)
                    }
                }
                y += 3
            }

            rule()
            line("Each opening above was inspected and tested against the minimum items of NFPA 80 "
                 + "by the inspector named against it, on the date shown. Deficiencies are required to "
                 + "be repaired without delay. \(AppConfig.appName) records what the inspector entered; "
                 + "it does not inspect, certify or approve any assembly, and the authority having "
                 + "jurisdiction remains the judge of the record.",
                 size: 9, colour: .secondaryLabel)
        }
        return url
    }
}
