import SwiftData
import SwiftUI

struct ModuleDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var module: PackModule

    @State private var newItemName = ""
    @State private var showingEditor = false
    @State private var editingGroup: PackItem?
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    ModuleIcon(module, size: 64)
                    Text(usage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            Section {
                ForEach(module.sortedItems) { item in
                    if item.isGroup {
                        NavigationLink {
                            ItemGroupView(item: item)
                        } label: {
                            GroupSummaryRow(item: item)
                        }
                    } else {
                        ItemRow(item: item)
                            .swipeActions(edge: .leading) {
                                Button("Add Sub-items", systemImage: "list.bullet.indent") {
                                    editingGroup = item
                                }
                                .tint(.indigo)
                            }
                            .contextMenu {
                                Button("Add Sub-items", systemImage: "list.bullet.indent") {
                                    editingGroup = item
                                }
                            }
                    }
                }
                .onDelete(perform: delete)
                .onMove(perform: move)

                AddItemField(text: $newItemName, focused: $addFieldFocused, onSubmit: addItem)
            } header: {
                Text("^[\(module.leafItems.count) item](inflect: true)")
            } footer: {
                Text("To group items, type “Hygiene: Toothbrush, Toothpaste” or swipe right on an item. Changes show up in every trip that uses \(module.name).")
            }
        }
        .navigationTitle(module.name)
        .navigationDestination(item: $editingGroup) { item in
            ItemGroupView(item: item)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit Name and Icon", systemImage: "pencil") { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            ModuleEditorView(module: module)
        }
    }

    private var usage: String {
        switch module.trips.count {
        case 0: "Not used in any trip"
        case 1: "Used in 1 trip"
        case let count: "Used in \(count) trips"
        }
    }

    private func addItem() {
        module.addItem(from: newItemName)
        newItemName = ""
        addFieldFocused = true
    }

    private func delete(at offsets: IndexSet) {
        let items = module.sortedItems
        for index in offsets {
            let item = items[index]
            module.items.removeAll { $0 == item }
            context.delete(item)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = module.sortedItems
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.sortIndex = index
        }
    }
}

/// Edits an item's sub-items. Adding the first one turns a plain item into a group.
struct ItemGroupView: View {
    @Environment(\.modelContext) private var context
    @Bindable var item: PackItem

    @State private var newChildName = ""
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        List {
            Section("Name") {
                TextField("Name", text: $item.name)
                    .font(.body.weight(.medium))
            }

            Section {
                ForEach(item.sortedChildren) { child in
                    ItemRow(item: child)
                }
                .onDelete(perform: delete)
                .onMove(perform: move)

                AddItemField(
                    title: "Add Sub-item",
                    text: $newChildName,
                    focused: $addFieldFocused,
                    onSubmit: addChildren
                )
            } header: {
                Text("^[\(item.children.count) sub-item](inflect: true)")
            } footer: {
                Text("In a trip, checking \(item.name.isEmpty ? "the group" : item.name) packs all of its sub-items at once. Separate names with commas to add several.")
            }
        }
        .navigationTitle(item.name.isEmpty ? "Sub-items" : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if item.children.isEmpty { addFieldFocused = true }
        }
    }

    private func addChildren() {
        item.addChildren(named: ItemInput.list(newChildName))
        newChildName = ""
        addFieldFocused = true
    }

    private func delete(at offsets: IndexSet) {
        let children = item.sortedChildren
        for index in offsets {
            let child = children[index]
            item.children.removeAll { $0 == child }
            context.delete(child)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = item.sortedChildren
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, child) in ordered.enumerated() {
            child.sortIndex = index
        }
    }
}

private struct GroupSummaryRow: View {
    let item: PackItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(item.name)
                Text("\(item.children.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: .capsule)
                    .accessibilityLabel("\(item.children.count) sub-items")
            }
            Text(item.sortedChildren.map(\.name).joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

private struct ItemRow: View {
    @Bindable var item: PackItem

    var body: some View {
        TextField("Item", text: $item.name)
            .submitLabel(.done)
    }
}

struct AddItemField: View {
    var title = "Add Item"
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            TextField(title, text: $text)
                .focused(focused)
                .submitLabel(.next)
                .onSubmit(onSubmit)
        }
    }
}

#Preview {
    let container = SeedData.previewContainer
    let module = try! container.mainContext.fetch(
        FetchDescriptor<PackModule>(predicate: #Predicate { $0.name == "Shower" })
    ).first!
    return NavigationStack {
        ModuleDetailView(module: module)
    }
    .modelContainer(container)
}
