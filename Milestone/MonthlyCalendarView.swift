import SwiftUI

struct MonthlyCalendarView: View {
    let monthDate: Date
    let highlightedDays: Set<Int>
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void

    private let calendar = Calendar(identifier: .gregorian)

    private var monthTitle: String {
        Self.monthFormatter.string(from: monthDate)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let shift = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var dayCells: [Int?] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: monthDate),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: monthInterval.start)),
            let dayRange = calendar.range(of: .day, in: .month, for: firstDay)
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [Int?] = Array(repeating: nil, count: leading)
        cells.append(contentsOf: dayRange.map { Optional($0) })

        let trailing = (7 - (cells.count % 7)) % 7
        if trailing > 0 {
            cells.append(contentsOf: Array(repeating: nil, count: trailing))
        }

        return cells
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onPreviousMonth) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .frame(width: 32, alignment: .leading)

                Spacer()

                Text(monthTitle)
                    .font(.app(.headline))
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer()

                Button(action: onNextMonth) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .frame(width: 32, alignment: .trailing)
            }
            .padding(.bottom, 16)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(dayCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        Text("\(day)")
                            .font(.app(.subheadline))
                            .foregroundStyle(highlightedDays.contains(day) ? UIAssetColors.accent : UIAssetColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                Circle()
                                    .fill(highlightedDays.contains(day) ? UIAssetColors.accentSecondary : Color.clear)
                            )
                    } else {
                        Text(" ")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}

#Preview {
    MonthlyCalendarView(
        monthDate: Date(),
        highlightedDays: [1, 4, 9, 21],
        onPreviousMonth: {},
        onNextMonth: {}
    )
}
