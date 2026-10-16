import SwiftData
import SwiftUI

struct ModulesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PackModule.sortIndex) private var modules: [PackModule]

    @State private var path: [PackModule] = []
    @State private var showingNewModule = false
    @State private var moduleToDelete: PackModule?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if modules.isEmpty {
                    ContentUnavailableView {
                        Label("No Modules", systemImage: "square.stack.3d.up")
                    } description: {
                        Text("A module is a set of things you always pack together, like everything for the shower.")
                    } actions: {
                        Button("New Module") { showingNewModule = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(modules) { module in
                                NavigationLink(value: module) {
                                    ModuleRow(module: module)
                                }
                                .swipeActions {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        moduleToDelete = module
                                    }
                                }
                            }
                            .onMove(perform: move)
                        } footer: {
                            Text("Touch and hold a module to reorder. Trips list modules in this order.")
                        }
                    }
                }
            }
            .navigationTitle("Modules")
            .navigationDestination(for: PackModule.self) { module in
                ModuleDetailView(module: module)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Module", systemImage: "plus") { showingNewModule = true }
                }
            }
            .sheet(isPresented: $showingNewModule) {
                ModuleEditorView(module: nil) { newModule in
                    path.append(newModule)
                }
            }
            .confirmationDialog(
                "Delete \(moduleToDelete?.name ?? "Module")?",
                isPresented: Binding(
                    get: { moduleToDelete != nil },
                    set: { if !$0 { moduleToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Module", role: .destructive) {
                    if let moduleToDelete { context.delete(moduleToDelete) }
                    moduleToDelete = nil
                }
            } message: {
                Text(deleteMessage)
            }
        }
    }

    private var deleteMessage: String {
        let count = moduleToDelete?.trips.count ?? 0
        if count == 0 { return "Its items are deleted too." }
        return "Its items are deleted too, and it's removed from \(count == 1 ? "1 trip" : "\(count) trips")."
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = modules
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, module) in ordered.enumerated() {
            module.sortIndex = index
        }
    }
}

private struct ModuleRow: View {
    let module: PackModule

    var body: some View {
        HStack(spacing: 12) {
            ModuleIcon(module, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(module.name)
                    .font(.body.weight(.medium))
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var preview: String {
        let names = module.sortedItems.map(\.name)
        return names.isEmpty ? "No items" : names.joined(separator: ", ")
    }
}

#Preview {
    ModulesListView()
        .modelContainer(SeedData.previewContainer)
}
