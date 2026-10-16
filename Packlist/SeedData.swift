import Foundation
import SwiftData

enum SeedData {
    private static let seededKey = "didSeedModules"

    /// Adds starter modules on first launch. Runs once, so deleted modules stay deleted.
    static func seedIfNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)

        let existing = (try? context.fetchCount(FetchDescriptor<PackModule>())) ?? 0
        guard existing == 0 else { return }
        insertStarterModules(into: context)
    }

    static func insertStarterModules(into context: ModelContext) {
        let starters: [(String, String, String, [String])] = [
            ("Essentials", "bag.fill", "blue",
             ["Phone charger", "Wallet", "Keys", "Headphones", "Medication", "Water bottle"]),
            ("Clothes", "tshirt.fill", "indigo",
             ["T-shirts", "Underwear", "Socks", "Trousers", "Sweater", "Pajamas", "Shoes"]),
            ("Shower", "shower.fill", "teal",
             ["Towel", "Flip-flops", "Hygiene: Toothbrush, Toothpaste, Shampoo, Shower gel, Deodorant, Hairbrush"]),
            ("Sport", "figure.run", "orange",
             ["Sport shirt", "Shorts", "Running shoes", "Sport socks", "Towel", "Water bottle", "Headphones"]),
            ("Beach", "sun.max.fill", "yellow",
             ["Swimsuit", "Sunscreen", "Sunglasses", "Beach towel", "Hat", "Flip-flops"]),
            ("Work", "briefcase.fill", "brown",
             ["Laptop", "Laptop charger", "Notebook", "Pen", "Business clothes"]),
            ("Flight", "airplane", "purple",
             ["Passport", "Boarding pass", "Neck pillow", "Snacks", "Power bank"]),
            ("Cold Weather", "snowflake", "cyan",
             ["Winter jacket", "Gloves", "Scarf", "Beanie", "Thermal layer"]),
        ]

        for (index, starter) in starters.enumerated() {
            let module = PackModule(name: starter.0, symbol: starter.1, colorName: starter.2, sortIndex: index)
            context.insert(module)
            for item in starter.3 {
                module.addItem(from: item)
            }
        }
    }

    static func insertDemoTrip(into context: ModelContext) {
        let modules = (try? context.fetch(FetchDescriptor<PackModule>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? []
        let trip = Trip(name: "Weekend in Lisbon", date: .now.addingTimeInterval(86_400 * 5))
        context.insert(trip)
        trip.modules = modules.filter { ["Shower", "Sport"].contains($0.name) }
        trip.packedKeys = ["towel", "toothbrush", "shampoo"]
    }

    @MainActor
    static var previewContainer: ModelContainer {
        let container = try! ModelContainer(
            for: Trip.self, PackModule.self, PackItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        insertStarterModules(into: container.mainContext)
        insertDemoTrip(into: container.mainContext)
        return container
    }
}
