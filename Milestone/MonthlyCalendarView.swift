import SwiftUI

struct MonthlyCalendarView: View {
    let monthDate: Date
    let highlightedDays: Set<Int>
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelectDay: (Int) -> Void

    private let calendar = Calendar(identifier: .gregorian)
    @State private var displayedMonthDate: Date
    @State private var measuredPageWidth: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isSwipeTransitionInFlight = false
    private let swipeThreshold: CGFloat = 60
    private let dayCellHeight: CGFloat = 32
    private let dayRowSpacing: CGFloat = 8

    init(
        monthDate: Date,
        highlightedDays: Set<Int>,
        onPreviousMonth: @escaping () -> Void,
        onNextMonth: @escaping () -> Void,
        onSelectDay: @escaping (Int) -> Void
    ) {
        self.monthDate = monthDate
        self.highlightedDays = highlightedDays
        self.onPreviousMonth = onPreviousMonth
        self.onNextMonth = onNextMonth
        self.onSelectDay = onSelectDay
        _displayedMonthDate = State(initialValue: monthDate)
    }

    private var monthTitle: String {
        Self.monthFormatter.string(from: displayedMonthDate)
    }

    private var visibleWeekCount: Int {
        max(dayCells(for: displayedMonthDate).count / 7, 1)
    }

    private var monthGridHeight: CGFloat {
        let rows = CGFloat(visibleWeekCount)
        return rows * dayCellHeight + max(rows - 1, 0) * dayRowSpacing
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let shift = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private func dayCells(for month: Date) -> [Int?] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: month),
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
                Button(action: triggerPreviousMonth) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .frame(width: 32, alignment: .leading)

                Spacer()

                Text(monthTitle)
                    .font(UIAssetTextStyle.paragraph.font)
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer()

                Button(action: triggerNextMonth) {
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
                        .font(UIAssetTextStyle.footnote.font)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)

            GeometryReader { proxy in
                let pageWidth = proxy.size.width

                HStack(spacing: 0) {
                    monthPage(
                        for: shiftMonth(displayedMonthDate, by: -1),
                        highlightedDays: [],
                        isInteractive: false,
                        width: pageWidth,
                        height: monthGridHeight
                    )

                    monthPage(
                        for: displayedMonthDate,
                        highlightedDays: highlightedDays,
                        isInteractive: true,
                        width: pageWidth,
                        height: monthGridHeight
                    )

                    monthPage(
                        for: shiftMonth(displayedMonthDate, by: 1),
                        highlightedDays: [],
                        isInteractive: false,
                        width: pageWidth,
                        height: monthGridHeight
                    )
                }
                .frame(width: pageWidth * 3, alignment: .leading)
                .frame(height: monthGridHeight, alignment: .topLeading)
                .offset(x: -pageWidth + dragOffset)
                .gesture(monthSwipeGesture(pageWidth: pageWidth))
                .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: dragOffset)
                .frame(width: pageWidth, alignment: .leading)
                .frame(height: monthGridHeight, alignment: .topLeading)
                .clipped()
                .mask(Rectangle())
                .onAppear {
                    measuredPageWidth = pageWidth
                }
                .onChange(of: pageWidth) { _, newValue in
                    measuredPageWidth = newValue
                }
            }
            .frame(height: monthGridHeight, alignment: .top)
            .animation(.easeInOut(duration: 0.22), value: monthGridHeight)
        }
        .onChange(of: monthDate) { _, newValue in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                displayedMonthDate = newValue
                dragOffset = 0
            }
            isSwipeTransitionInFlight = false
        }
    }

    @ViewBuilder
    private func monthPage(
        for month: Date,
        highlightedDays: Set<Int>,
        isInteractive: Bool,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        VStack(alignment: .leading, spacing: 0) {
            LazyVGrid(columns: columns, spacing: dayRowSpacing) {
                ForEach(Array(dayCells(for: month).enumerated()), id: \.offset) { _, day in
                    if let day {
                        Button {
                            onSelectDay(day)
                        } label: {
                            Text("\(day)")
                                .font(UIAssetTextStyle.subtitle.font)
                                .foregroundStyle(highlightedDays.contains(day) ? UIAssetColors.accent : UIAssetColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: dayCellHeight)
                                .background(
                                    Circle()
                                        .fill(highlightedDays.contains(day) ? UIAssetColors.accentSecondary : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .frame(height: dayCellHeight)
                        .disabled(!isInteractive || !highlightedDays.contains(day) || isSwipeTransitionInFlight)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: dayCellHeight)
                    }
                }
            }
        }
        .frame(width: width, height: height, alignment: .top)
        .clipped()
    }

    private func monthSwipeGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard !isSwipeTransitionInFlight else { return }
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) else { return }

                // Dampen the drag so adjacent months peek in smoothly like a carousel.
                dragOffset = horizontal * 0.82
            }
            .onEnded { value in
                guard !isSwipeTransitionInFlight else { return }
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > abs(vertical) else {
                    resetDragOffset()
                    return
                }

                let projected = horizontal + (value.predictedEndTranslation.width - horizontal) * 0.2
                if projected <= -swipeThreshold {
                    animateMonthChange(direction: .next, pageWidth: pageWidth)
                } else if projected >= swipeThreshold {
                    animateMonthChange(direction: .previous, pageWidth: pageWidth)
                } else {
                    resetDragOffset()
                }
            }
    }

    private func resetDragOffset() {
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
            dragOffset = 0
        }
    }

    private func triggerPreviousMonth() {
        animateMonthChange(direction: .previous, pageWidth: max(measuredPageWidth, 1))
    }

    private func triggerNextMonth() {
        animateMonthChange(direction: .next, pageWidth: max(measuredPageWidth, 1))
    }

    private func animateMonthChange(direction: SwipeDirection, pageWidth: CGFloat) {
        guard !isSwipeTransitionInFlight else { return }
        isSwipeTransitionInFlight = true

        let targetOffset = direction == .next ? -pageWidth : pageWidth
        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = targetOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            switch direction {
            case .previous:
                onPreviousMonth()
            case .next:
                onNextMonth()
            }
        }
    }

    private func shiftMonth(_ date: Date, by delta: Int) -> Date {
        calendar.date(byAdding: .month, value: delta, to: date) ?? date
    }

    private enum SwipeDirection {
        case previous
        case next
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
        onNextMonth: {},
        onSelectDay: { _ in }
    )
}
