import SwiftUI
import SwiftData

/// The register, in the order you walk it.
///
/// An inspector does dozens of openings in a morning, so this screen is built for a corridor:
/// the doors are in route order, each row says in one glance whether it still needs doing, and
/// starting an inspection is one tap from the row.
struct RegisterView: View {
    @Bindable var building: Building
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var filter: Filter = .remaining
    @State private var inspecting: DoorInspection?
    @State private var editingDoor: Door?
    @State private var editingBuilding = false
    @State private var exportFile: ExportFile?

    enum Filter: String, CaseIterable, Identifiable {
        case remaining, deficient, all
        var id: String { rawValue }
        var name: String {
            switch self {
            case .remaining: return "To do"
            case .deficient: return "Deficient"
            case .all: return "All"
            }
        }
    }

    private var doors: [Door] {
        switch filter {
        case .remaining: return building.overdueDoors()
        case .deficient: return building.deficientDoors()
        case .all: return building.sortedDoors
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if doors.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label(emptyTitle, systemImage: emptySymbol)
                    } description: {
                        Text(emptyBody)
                    }
                }
            } else {
                Section {
                    ForEach(doors) { door in
                        DoorRow(door: door) { startInspection(on: door) }
                            .swipeActions(edge: .leading) {
                                Button { editingDoor = door } label: {
                                    Label("Edit", systemImage: "pencil")
                                }.tint(.gray)
                            }
                    }
                    .onDelete { offsets in deleteDoors(offsets, from: doors) }
                } header: {
                    Text("\(doors.count) \(doors.count == 1 ? "opening" : "openings")")
                } footer: {
                    Text("Swipe a row right to edit the opening. Tap it to inspect.")
                }
            }
        }
        .navigationTitle(building.name.isEmpty ? "Register" : building.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { addDoor() } label: { Label("Add an opening", systemImage: "plus") }
                    Button { editingBuilding = true } label: { Label("Building details", systemImage: "building.2") }
                    Divider()
                    Button { exportPDF() } label: {
                        Label("Inspection record (PDF)", systemImage: "doc.richtext")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $inspecting) { InspectionView(inspection: $0) }
        .sheet(item: $editingDoor) { DoorEditorView(door: $0, building: building) }
        .sheet(isPresented: $editingBuilding) { BuildingEditorView(building: building) }
        .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
    }

    private var emptyTitle: String {
        switch filter {
        case .remaining: return building.doorCount == 0 ? "No openings yet" : "Register is current"
        case .deficient: return "No open deficiencies"
        case .all: return "No openings yet"
        }
    }

    private var emptySymbol: String {
        filter == .deficient ? "checkmark.seal" : (building.doorCount == 0 ? "door.left.hand.closed" : "checkmark.seal.fill")
    }

    private var emptyBody: String {
        switch filter {
        case .remaining where building.doorCount == 0, .all:
            return "Add the first opening. The number on the door and where it is will do to start; the rest can come off the label when you are standing there."
        case .remaining:
            return "Every opening in this register has been inspected within the last twelve months."
        case .deficient:
            return "Nothing in this register is carrying an unrepaired deficiency."
        }
    }

    private func addDoor() {
        let door = Door()
        door.routeOrder = (building.sortedDoors.last?.routeOrder ?? 0) + 1
        door.building = building
        context.insert(door)
        try? context.save()
        editingDoor = door
    }

    private func startInspection(on door: Door) {
        // Reopen today's inspection rather than stacking a second one on the same day.
        if let today = door.latest, Calendar.current.isDateInToday(today.date) {
            inspecting = today
            return
        }
        let inspection = DoorInspection()
        inspection.inspectorName = UserDefaults.standard.string(forKey: "inspector.name") ?? ""
        inspection.certificationNumber = UserDefaults.standard.string(forKey: "inspector.cert") ?? ""
        inspection.door = door
        context.insert(inspection)
        try? context.save()
        inspecting = inspection
    }

    private func deleteDoors(_ offsets: IndexSet, from list: [Door]) {
        for index in offsets { context.delete(list[index]) }
        try? context.save()
    }

    private func exportPDF() {
        try? context.save()
        if let url = try? PDFExporter.export(building) {
            exportFile = ExportFile(url: url)
            ReviewPrompter.recordSuccess(request: requestReview)
        }
    }
}

private struct DoorRow: View {
    let door: Door
    let inspect: () -> Void

    var body: some View {
        Button(action: inspect) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(door.openingNumber.isEmpty ? "Unnumbered" : door.openingNumber)
                        .font(.headline)
                    if !door.location.isEmpty {
                        Text(door.location).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("\(door.rating.name) · \(door.assembly.name)")
                        .font(.caption).foregroundStyle(.secondary)
                    if let latest = door.latest, latest.verdict == .deficient {
                        Text(latest.deficiencies.map(\.name).joined(separator: ", "))
                            .font(.caption2).foregroundStyle(.red).lineLimit(2)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if let latest = door.latest {
                        Text(latest.date.formatted(.dateTime.month(.abbreviated).year()))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        if let days = door.daysUntilDue(), days < 0 {
                            Text("overdue").font(.caption2).foregroundStyle(.orange)
                        }
                    } else {
                        Text("never").font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }

    private var symbol: String {
        guard let latest = door.latest else { return "circle.dashed" }
        if !door.isCurrent() { return "clock.badge.exclamationmark" }
        return latest.verdict.symbol
    }

    private var tint: Color {
        guard let latest = door.latest else { return .orange }
        if !door.isCurrent() { return .orange }
        switch latest.verdict {
        case .deficient: return .red
        case .compliant: return .green
        case .incomplete: return .secondary
        }
    }
}
