import SwiftUI

enum ModuleStyle {
    static let colorNames = [
        "red", "orange", "yellow", "green", "mint", "teal",
        "cyan", "blue", "indigo", "purple", "pink", "brown", "gray",
    ]

    static let symbols = [
        "bag.fill", "suitcase.fill", "tshirt.fill", "shower.fill", "drop.fill", "pills.fill",
        "cross.case.fill", "figure.run", "dumbbell.fill", "figure.pool.swim", "figure.hiking", "bicycle",
        "soccerball", "tennis.racket", "figure.skiing.downhill", "tent.fill", "mountain.2.fill", "leaf.fill",
        "sun.max.fill", "beach.umbrella.fill", "snowflake", "airplane", "car.fill", "tram.fill",
        "briefcase.fill", "laptopcomputer", "doc.text.fill", "creditcard.fill", "camera.fill", "headphones",
        "gamecontroller.fill", "book.fill", "music.note", "fork.knife", "cup.and.saucer.fill", "moon.zzz.fill",
        "pawprint.fill", "figure.and.child.holdinghands", "gift.fill", "party.popper.fill", "star.fill",
    ]

    static func color(_ name: String) -> Color {
        switch name {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "mint": .mint
        case "teal": .teal
        case "cyan": .cyan
        case "blue": .blue
        case "indigo": .indigo
        case "purple": .purple
        case "pink": .pink
        case "brown": .brown
        default: .gray
        }
    }
}

/// The colored rounded square that represents a module everywhere in the app.
struct ModuleIcon: View {
    let symbol: String
    let colorName: String
    var size: CGFloat = 30

    var body: some View {
        let color = ModuleStyle.color(colorName)
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 0.5, y: 0.5)
            }
            .accessibilityHidden(true)
    }
}

extension ModuleIcon {
    init(_ module: PackModule, size: CGFloat = 30) {
        self.init(symbol: module.symbol, colorName: module.colorName, size: size)
    }
}

/// Overlapping module icons, so a trip shows at a glance which blocks it is built from.
struct ModuleStack: View {
    let modules: [PackModule]
    var size: CGFloat = 22
    var limit = 6

    var body: some View {
        HStack(spacing: -size * 0.28) {
            ForEach(modules.prefix(limit)) { module in
                ModuleIcon(module, size: size)
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                            .stroke(Color(.systemBackground), lineWidth: 1.5)
                    }
            }
            if modules.count > limit {
                Text("+\(modules.count - limit)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, size * 0.4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(modules.map(\.name).formatted(.list(type: .and)))
    }
}

struct ProgressRing: View {
    let packed: Int
    let total: Int
    var lineWidth: CGFloat = 5

    private var fraction: Double { total == 0 ? 0 : Double(packed) / Double(total) }
    private var isDone: Bool { total > 0 && packed == total }

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.tint)
            }
        }
        .animation(.snappy, value: fraction)
        .accessibilityHidden(true)
    }
}
