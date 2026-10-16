import SwiftData
import SwiftUI

@main
struct PacklistApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Trip.self, PackModule.self, PackItem.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            Tab("Trips", systemImage: "suitcase.fill") {
                TripsListView()
            }
            Tab("Modules", systemImage: "square.stack.3d.up.fill") {
                ModulesListView()
            }
        }
        .task {
            SeedData.seedIfNeeded(context)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demoTrip") {
                SeedData.insertDemoTrip(into: context)
            }
            #endif
        }
    }
}

#Preview {
    RootView()
        .modelContainer(SeedData.previewContainer)
}
