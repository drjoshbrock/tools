import SwiftUI
import EventKit
import FoundationModels

// MARK: - Weather Models (for summary fetch)

private struct BriefWeatherResponse: Codable {
    let daily: BriefWeatherDaily
}

private struct BriefWeatherDaily: Codable {
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let weathercode: [Int]
    let precipitation_probability_max: [Int]
}

private let briefConditions: [Int: String] = [
    0: "Clear", 1: "Mostly Clear", 2: "Partly Cloudy", 3: "Overcast",
    45: "Fog", 48: "Fog",
    51: "Light Drizzle", 53: "Drizzle", 55: "Heavy Drizzle",
    56: "Freezing Drizzle", 57: "Freezing Drizzle",
    61: "Light Rain", 63: "Rain", 65: "Heavy Rain",
    66: "Freezing Rain", 67: "Freezing Rain",
    71: "Light Snow", 73: "Snow", 75: "Heavy Snow", 77: "Snow Grains",
    80: "Light Showers", 81: "Showers", 82: "Heavy Showers",
    85: "Snow Showers", 86: "Snow Showers",
    95: "Thunderstorm", 96: "T-Storm + Hail", 99: "T-Storm + Hail",
]

// MARK: - View

struct SummarySectionView: View {
    let theme: Theme
    let sportsStore: SportsDataStore
    @Environment(DashboardMode.self) private var dashboardMode

    @State private var summary = ""
    @State private var isGenerating = false
    @State private var error: String?

    private var hasSummary: Bool { !summary.isEmpty }

    var body: some View {
        DashboardSection(title: "BRIEFING", subtitle: dashboardMode.calendarSubtitle, theme: theme) {
            if isGenerating && !hasSummary {
                LoadingDotsView(theme: theme)
            } else if let error, !hasSummary {
                Text(error)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(theme.fgDim)
                    .italic()
            } else if hasSummary {
                Text(summary)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(theme.fg)
                    .lineSpacing(3)
            }
        }
        .task(id: sportsStore.loadGeneration) {
            guard sportsStore.loadGeneration > 0 else { return }
            await generateSummary()
        }
    }

    // MARK: - Summary Generation

    private func generateSummary() async {
        isGenerating = true
        error = nil

        do {
            try Task.checkCancellation()

            async let weatherInfo = fetchWeatherInfo()
            async let calendarInfo = fetchCalendarInfo()
            let sportsInfo = describeSports()

            let weather = await weatherInfo
            let calendar = await calendarInfo

            try Task.checkCancellation()

            let mode = dashboardMode.activeMode == .morning ? "today" : "tomorrow"
            let prompt = """
                Here is the dashboard data for \(mode):

                WEATHER:
                \(weather)

                SCHEDULE:
                \(calendar)

                SPORTS:
                \(sportsInfo)

                Write a brief 2-3 sentence daily briefing.
                """

            let session = LanguageModelSession(instructions: """
                You are a concise daily briefing assistant for a personal morning dashboard. \
                Given the day's data, write a brief 2-3 sentence summary highlighting the most \
                notable items: weather worth preparing for, important calendar events, and sports \
                results. Be casual and direct. No emoji. No markdown. No bullet points. \
                No headers or labels. Just natural sentences.
                """)

            let response = try await session.respond(to: prompt)
            summary = response.content
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            self.error = "AI briefing unavailable on this device"
        }

        isGenerating = false
    }

    // MARK: - Data Collection

    private func fetchWeatherInfo() async -> String {
        let isEvening = dashboardMode.activeMode == .evening
        do {
            let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(DashboardConfig.lat)&longitude=\(DashboardConfig.lon)&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode&temperature_unit=fahrenheit&timezone=America/New_York&forecast_days=2"
            let (data, _) = try await URLSession.shared.data(from: URL(string: urlStr)!)
            let resp = try JSONDecoder().decode(BriefWeatherResponse.self, from: data)
            let dayIdx = isEvening ? 1 : 0

            guard dayIdx < resp.daily.temperature_2m_max.count else { return "No weather data" }

            let hi = Int(resp.daily.temperature_2m_max[dayIdx].rounded())
            let lo = Int(resp.daily.temperature_2m_min[dayIdx].rounded())
            let code = resp.daily.weathercode[dayIdx]
            let rain = resp.daily.precipitation_probability_max[dayIdx]
            let condition = briefConditions[code] ?? "Unknown"

            return "High \(hi)°F, Low \(lo)°F, \(condition), \(rain)% chance of rain"
        } catch {
            return "Weather data unavailable"
        }
    }

    private func fetchCalendarInfo() async -> String {
        let store = EKEventStore()
        do {
            let granted = try await store.requestFullAccessToEvents()
            guard granted else { return "Calendar access denied" }
        } catch {
            return "Calendar unavailable"
        }

        let cal = Calendar.current
        let baseDate = dashboardMode.targetDate
        let startOfDay = cal.startOfDay(for: baseDate)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else {
            return "No events"
        }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)

        if events.isEmpty { return "No events scheduled" }

        let df = DateFormatter()
        df.dateFormat = "h:mm a"

        return events.map { ev in
            if ev.isAllDay {
                return "- ALL DAY: \(ev.title ?? "Untitled")"
            } else {
                let start = df.string(from: ev.startDate)
                return "- \(start): \(ev.title ?? "Untitled")"
            }
        }.joined(separator: "\n")
    }

    private func describeSports() -> String {
        var lines: [String] = []

        // Reds
        var redsLine = "Reds"
        if let record = sportsStore.redsRecord { redsLine += " (\(record))" }
        if sportsStore.reds.games.isEmpty {
            redsLine += ": No recent games"
        } else {
            for game in sportsStore.reds.games {
                switch game {
                case .final_(let label, let myScore, let oppAbbr, let oppScore, _, _, _, _, _):
                    let result = myScore > oppScore ? "Won" : "Lost"
                    redsLine += ", \(label): \(result) \(myScore)-\(oppScore) vs \(oppAbbr)"
                case .live(let myScore, let oppAbbr, let oppScore, let detail):
                    redsLine += ", LIVE: \(myScore)-\(oppScore) vs \(oppAbbr) (\(detail))"
                case .upcoming(let oppAbbr, _, let time, _, _, _, _):
                    redsLine += ", Next: vs \(oppAbbr) at \(time)"
                }
            }
        }
        lines.append(redsLine)

        // ESPN teams
        for config in [ESPNTeamConfig.lakers, .dolphins, .ukBasketball, .ukFootball] {
            guard let result = sportsStore.espnResults[config.id] else { continue }
            var line = config.sectionTitle
            if let record = result.record { line += " (\(record))" }

            if result.games.isEmpty {
                line += ": No recent games"
            } else {
                for game in result.games {
                    switch game {
                    case .final_(let label, _, _, let myScore, let oppAbbr, let oppScore, _, _):
                        let wl = myScore > oppScore ? "Won" : "Lost"
                        line += ", \(label): \(wl) \(myScore)-\(oppScore) vs \(oppAbbr)"
                    case .live(_, _, let myScore, let oppAbbr, let oppScore, let detail):
                        line += ", LIVE: \(myScore)-\(oppScore) vs \(oppAbbr) (\(detail))"
                    case .upcoming(_, _, let oppAbbr, _, let time, _, _, _):
                        line += ", Next: vs \(oppAbbr) at \(time)"
                    }
                }
            }
            lines.append(line)
        }

        return lines.isEmpty ? "No sports data available" : lines.joined(separator: "\n")
    }
}
