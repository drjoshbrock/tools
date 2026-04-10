import SwiftUI

// MARK: - Models

private struct WeatherResponse: Codable {
    let daily: WeatherDaily
    let hourly: WeatherHourly
}

private struct WeatherDaily: Codable {
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let weathercode: [Int]
    let precipitation_probability_max: [Int]
}

private struct WeatherHourly: Codable {
    let precipitation_probability: [Int]
    let temperature_2m: [Double]
}

// MARK: - WMO Codes

private let wmoConditions: [Int: String] = [
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

private let wmoIcons: [Int: String] = [
    0: "☀️", 1: "🌤️", 2: "⛅", 3: "☁️",
    45: "🌫️", 48: "🌫️",
    51: "🌦️", 53: "🌦️", 55: "🌧️", 56: "🌧️", 57: "🌧️",
    61: "🌦️", 63: "🌧️", 65: "🌧️", 66: "🌧️", 67: "🌧️",
    71: "🌨️", 73: "🌨️", 75: "❄️", 77: "❄️",
    80: "🌦️", 81: "🌧️", 82: "⛈️",
    85: "🌨️", 86: "❄️",
    95: "⛈️", 96: "⛈️", 99: "⛈️",
]

// MARK: - View

struct WeatherSectionView: View {
    let theme: Theme
    let refreshTrigger: Int
    @Environment(DashboardMode.self) private var dashboardMode

    @State private var hi = 0
    @State private var lo = 0
    @State private var condition = ""
    @State private var icon = ""
    @State private var rainMax = 0
    @State private var hourlyRain: [Int] = []
    @State private var hourlyTemp: [Double] = []
    @State private var isLoading = true
    @State private var error: String?

    private var hasData: Bool { !condition.isEmpty }

    var body: some View {
        DashboardSection(title: "WEATHER", subtitle: "Prospect, KY", theme: theme) {
            if isLoading && !hasData {
                LoadingDotsView(theme: theme)
            } else if let error, !hasData {
                Text("✗ \(error)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Sol.red)
            } else if hasData {
                Button {
                    if let url = URL(string: "carrotweather://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    weatherContent
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: refreshTrigger) {
            await loadWeather()
        }
    }

    @ViewBuilder
    private var weatherContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(icon).font(.system(size: 42))
                VStack(alignment: .leading, spacing: 4) {
                    Text(condition)
                        .font(.system(size: 16, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Sol.magenta)
                    HStack(spacing: 14) {
                        Text("▲").foregroundColor(theme.fg) +
                        Text(" \(hi)°F").foregroundColor(Sol.orange).bold()

                        Text("▼").foregroundColor(theme.fg) +
                        Text(" \(lo)°F").foregroundColor(Sol.blue).bold()

                        Text("☂").foregroundColor(theme.fg) +
                        Text(" \(rainMax)%").foregroundColor(Sol.cyan).bold()
                    }
                    .font(.system(size: 14, design: .monospaced))
                }
            }

            if hourlyTemp.count >= 24 {
                tempBox
            }

            if hourlyRain.count >= 24 && hourlyRain[6...23].contains(where: { $0 >= 5 }) {
                rainBox
            }
        }
    }

    private let chartSize: CGFloat = 24

    private var chartLabelRow: Text {
        let labels: [(Int, String)] = [(0, "6a"), (3, "9a"), (6, "12p"), (9, "3p"), (12, "6p"), (15, "9p")]
        var chars = Array(repeating: " ", count: 18)
        for (pos, label) in labels {
            for (j, ch) in label.enumerated() {
                if pos + j < 18 { chars[pos + j] = String(ch) }
            }
        }
        return Text(chars.joined()).foregroundColor(theme.fgDim)
    }

    private func rainBarRow(_ slice: [Int]) -> Text {
        let blocks: [Character] = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        var result = Text("")
        for pct in slice {
            let idx = min(8, Int((Double(pct) / 100.0 * 8).rounded()))
            let color: Color = pct > 60 ? Sol.red : pct > 40 ? Sol.orange : pct > 20 ? Sol.orange : Sol.green
            result = result + Text(String(blocks[idx])).foregroundColor(color)
        }
        return result
    }

    private func tempBarRow(_ slice: [Double]) -> Text {
        let blocks: [Character] = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        let minT = slice.min() ?? 0
        let maxT = slice.max() ?? 100
        let range = max(maxT - minT, 1)
        var result = Text("")
        for t in slice {
            let norm = (t - minT) / range
            let idx = min(8, Int((norm * 8).rounded()))
            let color: Color = t > 90 ? Sol.red : t > 75 ? Sol.orange : t > 55 ? Sol.magenta : Sol.cyan
            result = result + Text(String(blocks[idx])).foregroundColor(color)
        }
        return result
    }

    @ViewBuilder
    private var rainBox: some View {
        let slice = Array(hourlyRain[6...23])

        VStack(alignment: .leading, spacing: 2) {
            Text("HOURLY RAIN %")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.fgDim)
            rainBarRow(slice)
                .font(.system(size: chartSize, design: .monospaced))
            chartLabelRow
                .font(.system(size: chartSize, design: .monospaced))
        }
        .padding(8)
        .overlay(Rectangle().stroke(theme.border, lineWidth: 1))
    }

    @ViewBuilder
    private var tempBox: some View {
        let slice = Array(hourlyTemp[6...23])

        VStack(alignment: .leading, spacing: 2) {
            Text("HOURLY TEMP °F")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.fgDim)
            tempBarRow(slice)
                .font(.system(size: chartSize, design: .monospaced))
            chartLabelRow
                .font(.system(size: chartSize, design: .monospaced))
        }
        .padding(8)
        .overlay(Rectangle().stroke(theme.border, lineWidth: 1))
    }

    private func loadWeather() async {
        isLoading = true
        error = nil
        let isEvening = dashboardMode.activeMode == .evening
        do {
            try Task.checkCancellation()
            // Always fetch 2 days so we have data for both modes without re-fetching
            let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(DashboardConfig.lat)&longitude=\(DashboardConfig.lon)&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode&hourly=precipitation_probability,temperature_2m&temperature_unit=fahrenheit&timezone=America/New_York&forecast_days=2"
            let (data, _) = try await URLSession.shared.data(from: URL(string: urlStr)!)
            try Task.checkCancellation()
            let resp = try JSONDecoder().decode(WeatherResponse.self, from: data)
            let dayIdx = isEvening ? 1 : 0
            hi = Int(resp.daily.temperature_2m_max[dayIdx].rounded())
            lo = Int(resp.daily.temperature_2m_min[dayIdx].rounded())
            let code = resp.daily.weathercode[dayIdx]
            condition = wmoConditions[code] ?? "Unknown"
            icon = wmoIcons[code] ?? "?"
            rainMax = resp.daily.precipitation_probability_max[dayIdx]
            // Hourly data: each day has 24 hours. In evening mode, use hours 24-47 (tomorrow).
            let hourlyOffset = isEvening ? 24 : 0
            let allRain = resp.hourly.precipitation_probability
            let allTemp = resp.hourly.temperature_2m
            if allRain.count >= hourlyOffset + 24 {
                hourlyRain = Array(allRain[hourlyOffset..<hourlyOffset + 24])
            } else {
                hourlyRain = allRain
            }
            if allTemp.count >= hourlyOffset + 24 {
                hourlyTemp = Array(allTemp[hourlyOffset..<hourlyOffset + 24])
            } else {
                hourlyTemp = allTemp
            }
            error = nil
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
