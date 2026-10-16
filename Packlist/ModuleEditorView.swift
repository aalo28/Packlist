import SwiftData
import SwiftUI

/// Creates a module, or edits the name, color and icon of an existing one.
struct ModuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PackModule.sortIndex) private var modules: [PackModule]

    let module: PackModule?
    var onCreate: (PackModule) -> Void = { _ in }

    @State private var name = ""
    @State private var colorName = "blue"
    @State private var symbol = "bag.fill"
    @State private var didLoad = false

    private let grid = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 14) {
                        ModuleIcon(symbol: symbol, colorName: colorName, size: 72)
                            .animation(.snappy, value: colorName)
                        TextField("Module Name", text: $name)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.words)
                            .padding(.vertical, 10)
                            .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                    }
                    .padding(.vertical, 8)
                }

                Section("Color") {
                    LazyVGrid(columns: grid, spacing: 12) {
                        ForEach(ModuleStyle.colorNames, id: \.self) { name in
                            Button {
                                colorName = name
                            } label: {
                                Circle()
                                    .fill(ModuleStyle.color(name).gradient)
                                    .frame(width: 32, height: 32)
                                    .padding(4)
                                    .overlay {
                                        if colorName == name {
                                            Circle().strokeBorder(.primary.opacity(0.6), lineWidth: 2.5)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .contentShape(.circle)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(name.capitalized)
                            .accessibilityAddTraits(colorName == name ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Icon") {
                    LazyVGrid(columns: grid, spacing: 12) {
                        ForEach(ModuleStyle.symbols, id: \.self) { name in
                            Button {
                                symbol = name
                            } label: {
                                Image(systemName: name)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(symbol == name ? Color.white : Color.primary)
                                    .background(
                                        symbol == name ? AnyShapeStyle(ModuleStyle.color(colorName).gradient) : AnyShapeStyle(.fill.tertiary),
                                        in: .rect(cornerRadius: 11, style: .continuous)
                                    )
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(name.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
                            .accessibilityAddTraits(symbol == name ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(module == nil ? "New Module" : "Edit Module")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(module == nil ? "Create" : "Save", role: .confirm, action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let module else { return }
        name = module.name
        colorName = module.colorName
        symbol = module.symbol
    }

    private func save() {
        if let module {
            module.name = trimmedName
            module.colorName = colorName
            module.symbol = symbol
            dismiss()
        } else {
            let next = (modules.map(\.sortIndex).max() ?? -1) + 1
            let created = PackModule(name: trimmedName, symbol: symbol, colorName: colorName, sortIndex: next)
            context.insert(created)
            dismiss()
            onCreate(created)
        }
    }
}

#Preview {
    ModuleEditorView(module: nil)
        .modelContainer(SeedData.previewContainer)
}
