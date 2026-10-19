import SwiftUI
import SwiftData

/// The inspection itself, built for speed.
///
/// Most fire doors pass. So the screen opens with everything unanswered, one button marks the
/// whole assembly as passing, and the inspector only slows down on the items that are wrong.
/// That is the opposite of a form you fill top to bottom, and it is the difference between
/// forty openings in a morning and twelve.
struct InspectionView: View {
    @Bindable var inspection: DoorInspection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var noteFor: DoorCheck?

    private var door: Door? { inspection.door }
    private var checks: [DoorCheck] { door?.applicableChecks ?? DoorCheck.allCases }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        for check in checks where inspection.result(check) == .notChecked {
                            inspection.set(.pass, for: check)
                        }
                    } label: {
                        Label("Mark everything remaining as passing", systemImage: "checkmark.circle.fill")
                    }
                } footer: {
                    Text("Then tap only what is wrong. Most assemblies pass; the ones that do not are usually the closer, the latch, or something wedged under the door.")
                }

                Section {
                    ForEach(checks) { check in
                        CheckRow(check: check,
                                 result: inspection.result(check),
                                 note: inspection.note(check)) { result in
                            inspection.set(result, for: check)
                            if result == .deficient { noteFor = check }
                        } editNote: {
                            noteFor = check
                        }
                    }
                } header: {
                    Text("NFPA 80 items")
                } footer: {
                    Text("These are the minimum items the standard asks for. Your authority having jurisdiction may ask for more.")
                }

                Section("Inspector") {
                    TextField("Name", text: $inspection.inspectorName)
                    TextField("Certification number", text: $inspection.certificationNumber)
                    DatePicker("Date", selection: $inspection.date, displayedComponents: .date)
                }

                if inspection.verdict == .deficient {
                    Section {
                        TextField("What needs doing", text: $inspection.correctiveAction, axis: .vertical)
                            .lineLimit(2...5)
                        PhotoField(data: $inspection.deficiencyPhoto, label: "Photo of the deficiency")
                        Toggle("Repaired", isOn: Binding(
                            get: { inspection.repairedOn != nil },
                            set: { inspection.repairedOn = $0 ? Date() : nil }))
                        if let repaired = inspection.repairedOn {
                            DatePicker("Repaired on", selection: Binding(
                                get: { repaired },
                                set: { inspection.repairedOn = $0 }),
                                displayedComponents: .date)
                        }
                    } header: {
                        Text("Corrective action")
                    } footer: {
                        Text("NFPA 80 requires deficiencies to be repaired without delay. Recording the repair here keeps the closing evidence with the finding.")
                    }
                }

                Section("Notes") {
                    TextField("Anything else worth recording", text: $inspection.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    VerdictRow(verdict: inspection.verdict,
                               answered: inspection.checkedCount,
                               total: checks.count)
                }
            }
            .navigationTitle(door?.title ?? "Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                }
            }
            .sheet(item: $noteFor) { check in
                DeficiencyNoteView(check: check, text: inspection.note(check)) { text in
                    inspection.setNote(text, for: check)
                }
            }
        }
    }

    private func cancel() {
        // An inspection that was never answered is not a record; do not leave an empty one behind.
        if inspection.checkedCount == 0 { context.delete(inspection) }
        try? context.save()
        dismiss()
    }

    private func save() {
        UserDefaults.standard.set(inspection.inspectorName, forKey: "inspector.name")
        UserDefaults.standard.set(inspection.certificationNumber, forKey: "inspector.cert")
        if inspection.checkedCount == 0 { context.delete(inspection) }
        try? context.save()
        WidgetSync.update(with: (try? context.fetch(FetchDescriptor<Building>())) ?? [])
        if inspection.verdict != .incomplete {
            ReviewPrompter.recordSuccess(request: requestReview)
        }
        dismiss()
    }
}

private struct CheckRow: View {
    let check: DoorCheck
    let result: CheckResult
    let note: String
    let setResult: (CheckResult) -> Void
    let editNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(check.name).font(.subheadline.weight(.medium))
                        if check.isCommonlyCited {
                            Image(systemName: "flag.fill")
                                .font(.caption2).foregroundStyle(.orange)
                                .accessibilityLabel("Commonly cited")
                        }
                    }
                    Text(check.hint).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
            }

            ChoiceChips(options: [.pass, .deficient, .notApplicable],
                        selection: Binding(get: { result }, set: setResult),
                        title: \.name,
                        tint: { result in
                            switch result {
                            case .deficient: .red
                            case .pass: .green
                            default: .secondary
                            }
                        })

            if result == .deficient {
                Button(action: editNote) {
                    Label(note.isEmpty ? "Describe the deficiency" : note,
                          systemImage: note.isEmpty ? "square.and.pencil" : "text.alignleft")
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct VerdictRow: View {
    let verdict: DoorVerdict
    let answered: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(verdict.headline, systemImage: verdict.symbol)
                .font(.headline)
                .foregroundStyle(tint)
            Text(verdict.detail).font(.caption).foregroundStyle(.secondary)
            if verdict == .incomplete {
                Text("\(answered) of \(total) items answered")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var tint: Color {
        switch verdict {
        case .deficient: .red
        case .compliant: .green
        case .incomplete: .secondary
        }
    }
}

/// A deficiency with no description is a deficiency nobody can repair, so writing one is its
/// own small screen rather than a field to scroll past.
private struct DeficiencyNoteView: View {
    let check: DoorCheck
    @State var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What is wrong with it", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text(check.name)
                } footer: {
                    Text(check.hint)
                }
            }
            .navigationTitle("Deficiency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(text); dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
