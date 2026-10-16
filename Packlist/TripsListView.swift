import SwiftData
import SwiftUI

struct TripsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]

    @State private var path: [Trip] = []
    @State private var showingNewTrip = false
    @State private var tripToDelete: Trip?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView {
                        Label("No Trips Yet", systemImage: "suitcase")
                    } description: {
                        Text("Combine modules like Shower and Sport into one pack list for your next trip.")
                    } actions: {
                        Button("New Trip") { showingNewTrip = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(trips) { trip in
                            NavigationLink(value: trip) {
                                TripRow(trip: trip)
                            }
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    tripToDelete = trip
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trips")
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Trip", systemImage: "plus") { showingNewTrip = true }
                }
            }
            #if DEBUG
            .task {
                if ProcessInfo.processInfo.arguments.contains("-openFirstTrip"), let first = trips.first {
                    path = [first]
                }
            }
            #endif
            .sheet(isPresented: $showingNewTrip) {
                TripEditorView(trip: nil) { newTrip in
                    path.append(newTrip)
                }
            }
            .confirmationDialog(
                "Delete \(tripToDelete?.name ?? "Trip")?",
                isPresented: Binding(
                    get: { tripToDelete != nil },
                    set: { if !$0 { tripToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Trip", role: .destructive) {
                    if let tripToDelete { context.delete(tripToDelete) }
                    tripToDelete = nil
                }
            } message: {
                Text("Your modules stay. Only this trip and its packing progress are deleted.")
            }
        }
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        let progress = trip.progress
        HStack(spacing: 14) {
            ProgressRing(packed: progress.packed, total: progress.total)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 5) {
                Text(trip.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    ModuleStack(modules: trip.sortedModules)
                    if let date = trip.date {
                        Text(date, format: .dateTime.day().month(.abbreviated))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(progressText(progress))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func progressText(_ progress: (packed: Int, total: Int)) -> String {
        if progress.total == 0 { return "Nothing to pack yet" }
        if progress.packed == progress.total { return "All packed" }
        return "\(progress.packed) of \(progress.total) packed"
    }
}

#Preview {
    TripsListView()
        .modelContainer(SeedData.previewContainer)
}
