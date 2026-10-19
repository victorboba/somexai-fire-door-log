import SwiftUI
import SwiftData

/// The buildings, and how far through each register you are.
///
/// Every other app in this family lists jobs. This one lists progress, because a fire door
/// inspection is not a job — it is a register of a few hundred openings that has to be got
/// through once a year, and the only question on the way in is how many are left.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Building.name) private var buildings: [Building]

    @State private var openBuilding: Building?
    @State private var editingBuilding: Building?
    @State private var showingSettings = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            Group {
                if buildings.isEmpty {
                    ContentUnavailableView {
                        Label("No buildings yet", systemImage: "building.2")
                    } description: {
                        Text("Add the building, then add its openings. You can build the register as you walk it.")
                    } actions: {
                        Button("Add a building") { addBuilding() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(buildings) { building in
                            Button { openBuilding = building } label: { BuildingRow(building: building) }
                                .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteBuildings)
                    }
                }
            }
            .navigationTitle("Fire doors")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { HowToView() } label: {
                        Label("How do I use this app?", systemImage: "questionmark.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { addBuilding() } label: { Label("Add a building", systemImage: "plus") }
                        if !buildings.isEmpty {
                            Button { exportCSV() } label: {
                                Label("Every inspection as CSV", systemImage: "tablecells")
                            }
                        }
                        Divider()
                        Button { showingSettings = true } label: { Label("Settings", systemImage: "gear") }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .navigationDestination(item: $openBuilding) { building in
                RegisterView(building: building)
            }
            .sheet(item: $editingBuilding) { BuildingEditorView(building: $0) }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    private func addBuilding() {
        let building = Building()
        context.insert(building)
        try? context.save()
        editingBuilding = building
    }

    private func deleteBuildings(_ offsets: IndexSet) {
        for index in offsets { context.delete(buildings[index]) }
        try? context.save()
        WidgetSync.update(with: buildings)
    }

    private func exportCSV() {
        do { exportFile = ExportFile(url: try CSVExporter.export(buildings)) }
        catch { exportError = error.localizedDescription }
    }
}

private struct BuildingRow: View {
    let building: Building

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(building.name.isEmpty ? "Unnamed building" : building.name)
                    .font(.headline)
                Spacer()
                Text("\(building.doorsInspected()) / \(building.doorCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if !building.address.isEmpty {
                Text(building.address).font(.subheadline).foregroundStyle(.secondary)
            }

            if let progress = building.progress() {
                ProgressView(value: progress)
                    .tint(progress >= 1 ? .green : .accentColor)
            }

            let deficient = building.deficientDoors().count
            let overdue = building.overdueDoors().count
            HStack(spacing: 14) {
                if deficient > 0 {
                    Label("\(deficient) with deficiencies", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                }
                if overdue > 0 {
                    Label("\(overdue) due", systemImage: "clock")
                        .font(.caption).foregroundStyle(.orange)
                }
                if deficient == 0 && overdue == 0 && building.doorCount > 0 {
                    Label("Register current", systemImage: "checkmark.seal.fill")
                        .font(.caption).foregroundStyle(.green)
                }
                if building.doorCount == 0 {
                    Text("No openings added yet").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
