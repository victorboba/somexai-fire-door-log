import SwiftUI
import SwiftData

/// One opening's details. Filled in once, usually while standing in front of it.
struct DoorEditorView: View {
    @Bindable var door: Door
    let building: Building
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Opening number", text: $door.openingNumber)
                    TextField("Location", text: $door.location)
                    TextField("Floor or wing", text: $door.floor)
                } header: {
                    Text("Where it is")
                } footer: {
                    Text("The opening number is how the facility refers to this door and how whoever repairs it finds it again.")
                }

                Section {
                    Picker("Rating", selection: $door.rating) {
                        ForEach(FireRating.allCases) { Text($0.name).tag($0) }
                    }
                    Text(door.rating.typicalUse).font(.caption).foregroundStyle(.secondary)
                    Picker("Assembly", selection: $door.assembly) {
                        ForEach(AssemblyType.allCases) { Text($0.name).tag($0) }
                    }
                } header: {
                    Text("The assembly")
                }

                Section {
                    Toggle("Pair of leaves", isOn: $door.isPair)
                    if door.isPair {
                        Toggle("Has a coordinator", isOn: $door.hasCoordinator)
                    }
                    Toggle("Has glazing or a vision light", isOn: $door.hasGlazing)
                    Toggle("Has a hold-open device", isOn: $door.hasHoldOpen)
                } header: {
                    Text("What it has")
                } footer: {
                    Text("These decide which items the inspection asks about. A door with no coordinator is never failed for one, and is never shown the question.")
                }

                Section {
                    TextField("Label manufacturer", text: $door.labelManufacturer)
                    TextField("Label number", text: $door.labelNumber)
                    PhotoField(data: $door.photoData, label: "Photo of the opening or its label")
                } header: {
                    Text("Label")
                } footer: {
                    Text("Off the metal tag on the hinge edge. A photograph of it settles arguments later, and a label that cannot be read is itself a finding.")
                }

                Section {
                    Stepper("Route position: \(door.routeOrder)", value: $door.routeOrder, in: 0...9999)
                } header: {
                    Text("Order")
                } footer: {
                    Text("The register is walked in this order. Number them the way the corridor runs and you never backtrack.")
                }

                Section("Notes") {
                    TextField("Anything worth remembering", text: $door.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if !door.sortedInspections.isEmpty {
                    Section("History") {
                        ForEach(door.sortedInspections) { inspection in
                            HStack {
                                Image(systemName: inspection.verdict.symbol)
                                    .foregroundStyle(inspection.verdict == .deficient ? .red : .secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(inspection.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                    Text(inspection.verdict.headline)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }

                Section {
                    Button("Delete this opening", role: .destructive) {
                        context.delete(door)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle(door.openingNumber.isEmpty ? "New opening" : door.openingNumber)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if door.building == nil { door.building = building }
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

/// The building, and who ends up asking for the record.
struct BuildingEditorView: View {
    @Bindable var building: Building
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Building") {
                    TextField("Name", text: $building.name)
                    TextField("Address", text: $building.address, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    TextField("Authority having jurisdiction", text: $building.authority)
                    TextField("Owner contact", text: $building.ownerContact)
                } header: {
                    Text("Who asks")
                } footer: {
                    Text("The fire marshal, the state agency, or the accreditor who surveys the building. It prints on the record so the right name is on the right page.")
                }

                Section("Notes") {
                    TextField("Anything worth remembering", text: $building.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Building details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { try? context.save(); dismiss() }
                }
            }
        }
    }
}
