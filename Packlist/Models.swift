import Foundation
import SwiftData

/// A reusable group of things you always pack together, like "Shower" or "Sport".
@Model
final class PackModule {
    var name: String
    var symbol: String
    var colorName: String
    var sortIndex: Int
    var createdAt: Date

    /// Top-level items only. Sub-items hang off their parent item.
    @Relationship(deleteRule: .cascade, inverse: \PackItem.module)
    var items: [PackItem] = []

    @Relationship(inverse: \Trip.modules)
    var trips: [Trip] = []

    init(name: String, symbol: String, colorName: String, sortIndex: Int) {
        self.name = name
        self.symbol = symbol
        self.colorName = colorName
        self.sortIndex = sortIndex
        self.createdAt = .now
    }

    var sortedItems: [PackItem] {
        items.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Everything that actually goes in the bag: plain items plus the sub-items of groups.
    var leafItems: [PackItem] {
        sortedItems.flatMap(\.leaves)
    }

    /// Adds one item, or a group when the text looks like "Hygiene: Toothbrush, Toothpaste".
    func addItem(from text: String) {
        guard let input = ItemInput.parse(text) else { return }
        let next = (items.map(\.sortIndex).max() ?? -1) + 1
        let item = PackItem(name: input.name, sortIndex: next)
        items.append(item)
        item.addChildren(named: input.children)
    }
}

/// One thing to pack. Belongs to a module, directly to a trip, or to a parent item as a sub-item.
@Model
final class PackItem {
    var name: String
    var sortIndex: Int
    var module: PackModule?
    var trip: Trip?
    var parent: PackItem?

    @Relationship(deleteRule: .cascade, inverse: \PackItem.parent)
    var children: [PackItem] = []

    init(name: String, sortIndex: Int) {
        self.name = name
        self.sortIndex = sortIndex
    }

    var sortedChildren: [PackItem] {
        children.sorted { $0.sortIndex < $1.sortIndex }
    }

    var isGroup: Bool { !children.isEmpty }

    var leaves: [PackItem] { isGroup ? sortedChildren : [self] }

    func addChildren(named names: [String]) {
        var next = (children.map(\.sortIndex).max() ?? -1) + 1
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            children.append(PackItem(name: trimmed, sortIndex: next))
            next += 1
        }
    }

    /// Items with the same name in different modules are packed once.
    var key: String { PackItem.key(for: name) }

    static func key(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

enum ItemInput {
    /// "Hygiene: Toothbrush, Toothpaste" becomes a group with sub-items; anything else is one item.
    static func parse(_ text: String) -> (name: String, children: [String])? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let colon = trimmed.firstIndex(of: ":") {
            let name = trimmed[..<colon].trimmingCharacters(in: .whitespaces)
            let children = list(String(trimmed[trimmed.index(after: colon)...]))
            if !name.isEmpty && !children.isEmpty {
                return (name, children)
            }
        }
        return (trimmed, [])
    }

    /// Splits "Toothbrush, Toothpaste" into separate names.
    static func list(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// A trip combines modules into one pack list and remembers what is packed.
@Model
final class Trip {
    var name: String
    var date: Date?
    var createdAt: Date
    var modules: [PackModule] = []

    @Relationship(deleteRule: .cascade, inverse: \PackItem.trip)
    var extraItems: [PackItem] = []

    var packedKeys: [String] = []

    init(name: String, date: Date? = nil) {
        self.name = name
        self.date = date
        self.createdAt = .now
    }

    var sortedModules: [PackModule] {
        modules.sorted { $0.sortIndex < $1.sortIndex }
    }

    var sortedExtraItems: [PackItem] {
        extraItems.sorted { $0.sortIndex < $1.sortIndex }
    }

    func isPacked(_ key: String) -> Bool {
        packedKeys.contains(key)
    }

    func togglePacked(_ key: String) {
        if let index = packedKeys.firstIndex(of: key) {
            packedKeys.remove(at: index)
        } else {
            packedKeys.append(key)
        }
    }

    /// Packs every sub-item of a group, or unpacks them all when they're already packed.
    func togglePacked(group keys: [String]) {
        if keys.allSatisfy(isPacked) {
            packedKeys.removeAll { keys.contains($0) }
        } else {
            packedKeys.append(contentsOf: keys.filter { !isPacked($0) })
        }
    }

    func addExtraItem(from text: String) {
        guard let input = ItemInput.parse(text) else { return }
        let next = (extraItems.map(\.sortIndex).max() ?? -1) + 1
        let item = PackItem(name: input.name, sortIndex: next)
        extraItems.append(item)
        item.addChildren(named: input.children)
    }
}

// MARK: - Combined pack list

struct PackEntry: Identifiable {
    let id: AnyHashable
    /// The packed-state key of a plain item. Empty for groups, whose state comes from their children.
    let key: String
    let name: String
    /// Other modules in this trip that also contain the item.
    let alsoIn: [String]
    let children: [PackEntry]
    let item: PackItem

    var isGroup: Bool { !children.isEmpty }
    var leafKeys: [String] { isGroup ? children.map(\.key) : [key] }
}

struct PackSection: Identifiable {
    let module: PackModule
    let entries: [PackEntry]
    var id: PersistentIdentifier { module.persistentModelID }
}

extension Trip {
    /// Each module's items, with duplicates listed only under the first module that has them.
    var packSections: [PackSection] {
        let modules = sortedModules
        var owners: [String: [String]] = [:]
        for module in modules {
            for item in module.leafItems where !item.key.isEmpty {
                if !(owners[item.key]?.contains(module.name) ?? false) {
                    owners[item.key, default: []].append(module.name)
                }
            }
        }

        var seen = Set<String>()
        return modules.compactMap { module in
            let entries = Trip.entries(for: module.sortedItems, seen: &seen) { key in
                (owners[key] ?? []).filter { $0 != module.name }
            }
            return entries.isEmpty ? nil : PackSection(module: module, entries: entries)
        }
    }

    /// Trip-only items. They share packed state with module items of the same name.
    var extraEntries: [PackEntry] {
        var seen = Set<String>()
        return Trip.entries(for: sortedExtraItems, seen: &seen) { _ in [] }
    }

    /// Every distinct thing to pack across modules and trip-only items.
    var allKeys: Set<String> {
        let entries = packSections.flatMap(\.entries) + extraEntries
        return Set(entries.flatMap(\.leafKeys))
    }

    var progress: (packed: Int, total: Int) {
        let keys = allKeys
        return (keys.intersection(packedKeys).count, keys.count)
    }

    private static func entries(
        for items: [PackItem],
        seen: inout Set<String>,
        alsoIn: (String) -> [String]
    ) -> [PackEntry] {
        var result: [PackEntry] = []
        for item in items {
            if item.isGroup {
                var children: [PackEntry] = []
                for child in item.sortedChildren {
                    if let entry = leafEntry(child, seen: &seen, alsoIn: alsoIn) { children.append(entry) }
                }
                // A group whose sub-items are all listed elsewhere has nothing left to show.
                if !children.isEmpty {
                    result.append(PackEntry(
                        id: item.persistentModelID, key: "", name: item.name,
                        alsoIn: [], children: children, item: item
                    ))
                }
            } else if let entry = leafEntry(item, seen: &seen, alsoIn: alsoIn) {
                result.append(entry)
            }
        }
        return result
    }

    private static func leafEntry(
        _ item: PackItem,
        seen: inout Set<String>,
        alsoIn: (String) -> [String]
    ) -> PackEntry? {
        let key = item.key
        guard !key.isEmpty, seen.insert(key).inserted else { return nil }
        return PackEntry(id: key, key: key, name: item.name, alsoIn: alsoIn(key), children: [], item: item)
    }
}
