import SwiftData
import SwiftUI

struct TripDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var trip: Trip

    @AppStorage("hidePacked") private var hidePacked = false
    @State private var showingEditor = false
    @State private var confirmingReset = false
    @State private var collapsed: Set<AnyHashable> = []
    @State private var newItemName = ""
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        let sections = trip.packSections
        let extras = trip.extraEntries
        let progress = trip.progress
        let isDone = progress.total > 0 && progress.packed == progress.total

        List {
            Section {
                ProgressHeader(trip: trip, packed: progress.packed, total: progress.total) {
                    showingEditor = true
                }
            }

            if trip.modules.isEmpty && trip.extraItems.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to Pack", systemImage: "square.stack.3d.up")
                } description: {
                    Text("Add modules to build this trip's pack list.")
                } actions: {
                    Button("Choose Modules") { showingEditor = true }
                }
            }

            ForEach(sections) { section in
                let entries = visible(section.entries)
                if !entries.isEmpty {
                    Section {
                        ForEach(entries) { entry in
                            rows(for: entry, tint: ModuleStyle.color(section.module.colorName), deletable: false)
                        }
                    } header: {
                        SectionHeader(module: section.module, entries: section.entries, trip: trip)
                    }
                }
            }

            Section {
                ForEach(visible(extras)) { entry in
                    rows(for: entry, tint: .accentColor, deletable: true)
                }
                AddItemField(text: $newItemName, focused: $addFieldFocused, onSubmit: addExtraItem)
            } header: {
                Text("Just for This Trip")
            } footer: {
                Text("Things you only need this time. They aren't added to any module.")
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.large)
        .animation(.default, value: hidePacked)
        .sensoryFeedback(.success, trigger: isDone) { _, done in done }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Edit Trip", systemImage: "pencil") { showingEditor = true }
                    Toggle(isOn: $hidePacked) {
                        Label("Hide Packed Items", systemImage: "eye.slash")
                    }
                    Divider()
                    Button("Unpack All", systemImage: "arrow.counterclockwise", role: .destructive) {
                        confirmingReset = true
                    }
                    .disabled(trip.packedKeys.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            TripEditorView(trip: trip)
        }
        .confirmationDialog("Unpack all items?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Unpack All", role: .destructive) {
                withAnimation { trip.packedKeys = [] }
            }
        } message: {
            Text("Every item is marked as not packed. Use this to reuse the list for your next trip.")
        }
    }

    /// A plain item is one row; a group is its own row followed by its sub-items while expanded.
    @ViewBuilder
    private func rows(for entry: PackEntry, tint: Color, deletable: Bool) -> some View {
        if entry.isGroup {
            let packedCount = entry.children.filter { trip.isPacked($0.key) }.count
            let isExpanded = !collapsed.contains(entry.id)
            GroupRow(
                name: entry.name,
                packed: packedCount,
                total: entry.children.count,
                isExpanded: isExpanded,
                tint: tint,
                toggle: { toggleGroup(entry) },
                expand: { toggleExpanded(entry) }
            )
            .deletable(deletable) { delete(entry.item) }

            if isExpanded {
                ForEach(visible(entry.children)) { child in
                    PackRow(
                        name: child.name,
                        alsoIn: child.alsoIn,
                        isPacked: trip.isPacked(child.key),
                        tint: tint,
                        isIndented: true
                    ) {
                        toggle(child.key)
                    }
                    .deletable(deletable) { delete(child.item) }
                }
            }
        } else {
            PackRow(name: entry.name, alsoIn: entry.alsoIn, isPacked: trip.isPacked(entry.key), tint: tint) {
                toggle(entry.key)
            }
            .deletable(deletable) { delete(entry.item) }
        }
    }

    private func visible(_ entries: [PackEntry]) -> [PackEntry] {
        guard hidePacked else { return entries }
        return entries.filter { !$0.leafKeys.allSatisfy(trip.isPacked) }
    }

    private func toggle(_ key: String) {
        withAnimation(.snappy) {
            trip.togglePacked(key)
        }
    }

    private func toggleGroup(_ entry: PackEntry) {
        withAnimation(.snappy) {
            trip.togglePacked(group: entry.leafKeys)
        }
    }

    private func toggleExpanded(_ entry: PackEntry) {
        withAnimation(.snappy) {
            if collapsed.contains(entry.id) {
                collapsed.remove(entry.id)
            } else {
                collapsed.insert(entry.id)
            }
        }
    }

    private func delete(_ item: PackItem) {
        if let parent = item.parent {
            parent.children.removeAll { $0 == item }
        } else {
            trip.extraItems.removeAll { $0 == item }
        }
        context.delete(item)
    }

    private func addExtraItem() {
        trip.addExtraItem(from: newItemName)
        newItemName = ""
        addFieldFocused = true
    }
}

private extension View {
    @ViewBuilder
    func deletable(_ isDeletable: Bool, action: @escaping () -> Void) -> some View {
        if isDeletable {
            swipeActions {
                Button("Delete", systemImage: "trash", role: .destructive, action: action)
            }
        } else {
            self
        }
    }
}

private struct ProgressHeader: View {
    let trip: Trip
    let packed: Int
    let total: Int
    let editModules: () -> Void

    var body: some View {
        let isDone = total > 0 && packed == total
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(isDone ? "All packed" : "\(packed) of \(total) packed")
                    .font(.title2.weight(.bold))
                    .contentTransition(.numericText())
                Spacer()
                if let date = trip.date {
                    Text(date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: Double(packed), total: Double(max(total, 1)))
                .accessibilityLabel("Packing progress")

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(trip.sortedModules) { module in
                        ModuleChip(module: module)
                    }
                    Button(action: editModules) {
                        Label(trip.modules.isEmpty ? "Add Modules" : "Edit", systemImage: "plus")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 34)
                            .background(.fill.tertiary, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(trip.modules.isEmpty ? "Add Modules" : "Edit Modules")
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.vertical, 6)
    }
}

private struct ModuleChip: View {
    let module: PackModule

    var body: some View {
        HStack(spacing: 6) {
            ModuleIcon(module, size: 22)
            Text(module.name)
                .font(.subheadline.weight(.medium))
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .frame(minHeight: 34)
        .background(ModuleStyle.color(module.colorName).opacity(0.14), in: .capsule)
    }
}

private struct SectionHeader: View {
    let module: PackModule
    let entries: [PackEntry]
    let trip: Trip

    var body: some View {
        let keys = entries.flatMap(\.leafKeys)
        let packed = keys.filter(trip.isPacked).count
        HStack(spacing: 8) {
            ModuleIcon(module, size: 20)
            Text(module.name)
            Spacer()
            Text("\(packed)/\(keys.count)")
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("\(packed) of \(keys.count) packed")
        }
    }
}

private struct PackRow: View {
    let name: String
    let alsoIn: [String]
    let isPacked: Bool
    let tint: Color
    var isIndented = false
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: isPacked ? "checkmark.circle.fill" : "circle")
                    .font(isIndented ? .title3 : .title2)
                    .foregroundStyle(isPacked ? tint : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .foregroundStyle(isPacked ? .secondary : .primary)
                        .strikethrough(isPacked, color: .secondary)
                    if !alsoIn.isEmpty {
                        Text("Also in \(alsoIn.formatted(.list(type: .and)))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, isIndented ? 38 : 0)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isPacked ? "Packed" : "Not packed")
        .accessibilityAddTraits(isPacked ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isPacked)
    }
}

/// A group like "Hygiene": its checkbox packs every sub-item, the rest of the row expands or collapses it.
private struct GroupRow: View {
    let name: String
    let packed: Int
    let total: Int
    let isExpanded: Bool
    let tint: Color
    let toggle: () -> Void
    let expand: () -> Void

    private var isPacked: Bool { packed == total }

    private var symbol: String {
        if isPacked { return "checkmark.circle.fill" }
        return packed > 0 ? "circle.lefthalf.filled" : "circle"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(packed > 0 ? tint : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(minWidth: 28, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPacked ? "Unpack all in \(name)" : "Pack all in \(name)")
            .sensoryFeedback(.selection, trigger: packed)

            Button(action: expand) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isPacked ? .secondary : .primary)
                            .strikethrough(isPacked, color: .secondary)
                        Text("\(packed) of \(total) packed")
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)
            .accessibilityValue("\(packed) of \(total) packed")
            .accessibilityHint(isExpanded ? "Hides the sub-items" : "Shows the sub-items")
        }
    }
}

#Preview {
    let container = SeedData.previewContainer
    let trip = try! container.mainContext.fetch(FetchDescriptor<Trip>()).first!
    return NavigationStack {
        TripDetailView(trip: trip)
    }
    .modelContainer(container)
}
