import SwiftUI

struct VolumeLast7DaysView: View {
    let points: [DailyVolumePoint]
    var showsTitle: Bool = true

    private var maxVolume: Double {
        max(points.map(\.volumeKg).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsTitle {
                Text("Volume Last 7 Days")
                    .uiAssetText(.h4)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(points) { point in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(point.volumeKg > 0 ? UIAssetColors.accent : Color.gray.opacity(0.25))
                            .frame(height: barHeight(for: point.volumeKg))

                        Text(Self.dayFormatter.string(from: point.date))
                            .font(.app(.caption2))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)

            Text(totalText)
                .font(.app(.caption))
                .foregroundStyle(.secondary)
        }
    }

    private var totalText: String {
        let total = points.reduce(0) { $0 + $1.volumeKg }
        return String(format: "Total: %.1f kg", total)
    }

    private func barHeight(for volume: Double) -> CGFloat {
        if volume <= 0 {
            return 2
        }
        return max(4, CGFloat(volume / maxVolume) * 100)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
}

#Preview {
    let calendar = Calendar(identifier: .gregorian)
    let today = calendar.startOfDay(for: Date())
    let points = (0..<7).map { offset in
        DailyVolumePoint(
            date: calendar.date(byAdding: .day, value: offset - 6, to: today) ?? today,
            volumeKg: [0, 800, 0, 1200, 600, 0, 1400][offset]
        )
    }

    return VolumeLast7DaysView(points: points)
}
