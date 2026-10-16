import SwiftData
import SwiftUI

/// Creates a trip, or edits the name, date and modules of an existing one.
struct TripEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PackModule.sortIndex) private var modules: [PackModule]

    let trip: Trip?
    var onCreate: (Trip) -> Void = { _ in }

    @State private var name = ""
    @State private var hasDate = false
    @State private var date = Date.now
    @State private var selected: Set<PersistentIdentifier> = []
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip Name", text: $name)
                        .textInputAutocapitalization(.words)
                    Toggle("Date", isOn: $hasDate.animation())
                    if hasDate {
                        DatePicker("Departure", selection: $date, displayedComponents: .date)
                    }
                }

                Section {
                    if modules.isEmpty {
                        Text("You have no modules yet. Create some in the Modules tab.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(modules) { module in
                        ModuleToggleRow(module: module, isOn: selected.contains(module.persistentModelID)) {
                            toggle(module)
                        }
                    }
                } header: {
                    Text("Modules")
                } footer: {
                    Text(summary)
                }
            }
            .navigationTitle(trip == nil ? "New Trip" : "Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(trip == nil ? "Create" : "Save", role: .confirm, action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        .interactiveDismissDisabled(hasChanges)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var chosenModules: [PackModule] {
        modules.filter { selected.contains($0.persistentModelID) }
    }

    private var summary: String {
        let chosen = chosenModules
        guard !chosen.isEmpty else { return "Pick the modules this trip needs. You can change them anytime." }
        let all = chosen.flatMap { $0.leafItems.map(\.key) }
        let unique = Set(all).subtracting([""])
        let shared = all.count - unique.count
        var text = "\(unique.count) items to pack"
        if shared > 0 {
            text += " · \(shared) shared between modules, listed once"
        }
        return text
    }

    private var hasChanges: Bool {
        guard let trip else { return !trimmedName.isEmpty || !selected.isEmpty }
        return trimmedName != trip.name || Set(trip.modules.map(\.persistentModelID)) != selected
    }

    private func toggle(_ module: PackModule) {
        let id = module.persistentModelID
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let trip else { return }
        name = trip.name
        hasDate = trip.date != nil
        date = trip.date ?? .now
        selected = Set(trip.modules.map(\.persistentModelID))
    }

    private func save() {
        let target: Trip
        if let trip {
            target = trip
        } else {
            target = Trip(name: trimmedName)
            context.insert(target)
        }
        target.name = trimmedName
        target.date = hasDate ? date : nil
        target.modules = chosenModules
        dismiss()
        if trip == nil { onCreate(target) }
    }
}

private struct ModuleToggleRow: View {
    let module: PackModule
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                ModuleIcon(module)
                VStack(alignment: .leading, spacing: 1) {
                    Text(module.name)
                        .foregroundStyle(.primary)
                    Text("^[\(module.leafItems.count) item](inflect: true)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

#Preview {
    TripEditorView(trip: nil)
        .modelContainer(SeedData.previewContainer)
}
