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

    @State private var hi = 0
    @State private var lo = 0
    @State private var condition = ""
    @State private var icon = ""
    @State private var rainMax = 0
    @State private var hourlyRain: [Int] = []
    @State private var hourlyTemp: [Double] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        DashboardSection(title: "WEATHER", subtitle: "Prospect, KY", theme: theme) {
            if isLoading {
                Text("loading...")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(theme.fgDim)
            } else if let error {
                Text("✗ \(error)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Sol.red)
            } else {
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

    @ViewBuilder
    private var rainBox: some View {
        let blocks: [Character] = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

        VStack(alignment: .leading, spacing: 2) {
            Text("┌─ HOURLY RAIN % ─────────────────┐")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.fgDim)

            HStack(spacing: 0) {
                ForEach(6...23, id: \.self) { i in
                    let pct = hourlyRain[i]
                    let idx = min(8, Int((Double(pct) / 100.0 * 8).rounded()))
                    let color: Color = pct > 60 ? Sol.red : pct > 40 ? Sol.orange : pct > 20 ? Sol.orange : Sol.green
                    Text(String(blocks[idx]))
                        .foregroundColor(color)
                }
            }
            .font(.system(size: 16, design: .monospaced))
            .tracking(1)

            Text("6a    9a    12p   3p    6p    9p")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.fgDim)

            Text("└─────────────────────────────────┘")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.fgDim)
        }
        .padding(8)
        .overlay(Rectangle().stroke(theme.border, lineWidth: 1))
    }

    @ViewBuilder
    private var tempBox: some View {
        let blocks: [Character] = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        let slice = Array(hourlyTemp[6...23])
        let minT = slice.min() ?? 0
        let maxT = slice.max() ?? 100
        let range = max(maxT - minT, 1)

        VStack(alignment: .leading, spacing: 2) {
            Text("┌─ HOURLY TEMP °F ─────────────────────────────────────┐")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.fgDim)

            HStack(spacing: 2) {
                ForEach(0..<slice.count, id: \.self) { i in
                    let t = slice[i]
                    let norm = (t - minT) / range
                    let idx = min(8, Int((norm * 8).rounded()))
                    let color: Color = t > 90 ? Sol.red : t > 75 ? Sol.orange : t > 55 ? Sol.magenta : Sol.cyan
                    Text(String(blocks[idx]))
                        .foregroundColor(color)
                }
            }
            .font(.system(size: 26, design: .monospaced))
            .tracking(3)

            Text("6a       9a       12p      3p       6p       9p")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.fgDim)

            Text("└────────────────────────────────────────────────────────┘")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.fgDim)
        }
        .padding(8)
        .overlay(Rectangle().stroke(theme.border, lineWidth: 1))
    }

    private func loadWeather() async {
        isLoading = true
        error = nil
        do {
            let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(DashboardConfig.lat)&longitude=\(DashboardConfig.lon)&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode&hourly=precipitation_probability,temperature_2m&temperature_unit=fahrenheit&timezone=America/New_York&forecast_days=1"
            let (data, _) = try await URLSession.shared.data(from: URL(string: urlStr)!)
            let resp = try JSONDecoder().decode(WeatherResponse.self, from: data)
            hi = Int(resp.daily.temperature_2m_max[0].rounded())
            lo = Int(resp.daily.temperature_2m_min[0].rounded())
            let code = resp.daily.weathercode[0]
            condition = wmoConditions[code] ?? "Unknown"
            icon = wmoIcons[code] ?? "?"
            rainMax = resp.daily.precipitation_probability_max[0]
            hourlyRain = resp.hourly.precipitation_probability
            hourlyTemp = resp.hourly.temperature_2m
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
