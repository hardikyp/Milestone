import Foundation
import UIKit

struct DailyVolumePoint: Identifiable {
    var id: Date { date }
    let date: Date
    let volumeKg: Double
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var monthDate: Date = Date()
    @Published var highlightedDays: Set<Int> = []
    @Published var last7DayVolumes: [DailyVolumePoint] = []
    @Published var greetingText: String = "Hello"
    @Published var greetingSubtext: String = "What would you like to work on today?"
    @Published var activeSession: Session?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let calendar = Calendar(identifier: .gregorian)

    func load(sessionRepository: SessionRepository, statsService: StatsService) async {
        isLoading = true

        do {
            let now = Date()
            monthDate = now
            greetingText = Self.makeGreeting(firstName: Self.resolveFirstName())
            activeSession = try sessionRepository.fetchMostRecentActiveSession()
            try loadMonthHighlights(sessionRepository: sessionRepository, month: now)

            let last7 = try loadSessionsForLast7Days(sessionRepository: sessionRepository, now: now)
            var volumeByDay: [Date: Double] = [:]

            for session in last7 {
                let dayStart = calendar.startOfDay(for: session.startDateTime)
                let sessionVolume = try statsService.totalVolumeKg(sessionId: session.id)
                volumeByDay[dayStart, default: 0] += sessionVolume
            }

            let startOfToday = calendar.startOfDay(for: now)
            let firstDay = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday

            var points: [DailyVolumePoint] = []
            for offset in 0..<7 {
                let day = calendar.date(byAdding: .day, value: offset, to: firstDay) ?? firstDay
                points.append(
                    DailyVolumePoint(
                        date: day,
                        volumeKg: volumeByDay[day, default: 0]
                    )
                )
            }

            last7DayVolumes = points
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadActiveSession(sessionRepository: SessionRepository) async {
        do {
            activeSession = try sessionRepository.fetchMostRecentActiveSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func shiftMonth(by delta: Int, sessionRepository: SessionRepository) async {
        guard let newMonth = calendar.date(byAdding: .month, value: delta, to: monthDate) else {
            return
        }

        monthDate = newMonth
        do {
            try loadMonthHighlights(sessionRepository: sessionRepository, month: newMonth)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMonthHighlights(sessionRepository: SessionRepository, month: Date) throws {
        let monthlySessions = try sessionRepository.fetchSessionsForMonth(month: month)
        highlightedDays = Set(monthlySessions.map { calendar.component(.day, from: $0.startDateTime) })
    }

    private func loadSessionsForLast7Days(sessionRepository: SessionRepository, now: Date) throws -> [Session] {
        let startOfToday = calendar.startOfDay(for: now)
        let startBoundary = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday

        let pageSize = 100
        var offset = 0
        var result: [Session] = []

        while true {
            let page = try sessionRepository.fetchSessions(limit: pageSize, offset: offset)
            if page.isEmpty {
                break
            }

            for session in page {
                if session.startDateTime >= startBoundary {
                    result.append(session)
                }
            }

            if let oldest = page.last?.startDateTime, oldest < startBoundary {
                break
            }

            if page.count < pageSize {
                break
            }

            offset += page.count
        }

        return result
    }

    private static func makeGreeting(firstName: String) -> String {
        "Welcome, \(firstName)!"
    }

    private static func resolveFirstName() -> String {
        let savedName = UserDefaults.standard.string(forKey: "settings.firstName")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let savedName, !savedName.isEmpty {
            return savedName
        }

        let deviceName = UIDevice.current.name

        let apostropheSplit = deviceName.split(separator: "'").first.map(String.init) ?? deviceName
        let trimmed = apostropheSplit.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstWord = trimmed.split(separator: " ").first.map(String.init)

        if let firstWord, !firstWord.isEmpty {
            return firstWord
        }
        return "User"
    }
}
