import SwiftUI

func formattedTime() -> String {
    let df = DateFormatter()
    df.timeZone = DashboardConfig.tz
    df.dateFormat = "h:mm a"
    return df.string(from: Date())
}

func todayString() -> String {
    let df = DateFormatter()
    df.timeZone = DashboardConfig.tz
    df.dateFormat = "yyyy-MM-dd"
    return df.string(from: Date())
}

func yesterdayString() -> String {
    let df = DateFormatter()
    df.timeZone = DashboardConfig.tz
    df.dateFormat = "yyyy-MM-dd"
    return df.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
}

func dateOffsetString(days: Int) -> String {
    let df = DateFormatter()
    df.timeZone = DashboardConfig.tz
    df.dateFormat = "yyyyMMdd"
    return df.string(from: Calendar.current.date(byAdding: .day, value: days, to: Date())!)
}

func parseISO8601(_ string: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: string) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: string) ?? Date()
}

// MARK: - Content View

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var refreshTrigger = 0
    @State private var refreshTime = ""

    private var theme: Theme { Theme(colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TitleBarView(theme: theme, refreshTrigger: refreshTrigger)

                WeatherSectionView(theme: theme, refreshTrigger: refreshTrigger)
                CalendarSectionView(theme: theme, refreshTrigger: refreshTrigger)
                RedsSectionView(theme: theme, refreshTrigger: refreshTrigger)

                ESPNSectionView(config: .lakers, theme: theme, refreshTrigger: refreshTrigger)
                ESPNSectionView(config: .dolphins, theme: theme, refreshTrigger: refreshTrigger)
                ESPNSectionView(config: .ukBasketball, theme: theme, refreshTrigger: refreshTrigger)
                ESPNSectionView(config: .ukFootball, theme: theme, refreshTrigger: refreshTrigger)

                FooterView(theme: theme, refreshTime: refreshTime) {
                    refreshTime = formattedTime()
                    refreshTrigger += 1
                }
            }
            .overlay(Rectangle().stroke(theme.border, lineWidth: 1))
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .background(theme.bg)
        .onAppear { refreshTime = formattedTime() }
    }
}

// MARK: - Title Bar

struct TitleBarView: View {
    let theme: Theme
    let refreshTrigger: Int

    private var dateStr: String {
        let df = DateFormatter()
        df.timeZone = DashboardConfig.tz
        df.dateFormat = "EEE MMM d"
        return df.string(from: Date())
    }

    private var timeStr: String {
        let df = DateFormatter()
        df.timeZone = DashboardConfig.tz
        df.dateFormat = "h:mm a"
        return df.string(from: Date())
    }

    var body: some View {
        HStack {
            (Text("▸").foregroundColor(Sol.cyan) +
             Text(" morning-dashboard").foregroundColor(Sol.green))
                .font(.system(size: 14, design: .monospaced))
                .fontWeight(.bold)
            Spacer()
            (Text(dateStr).foregroundColor(Sol.yellow) +
             Text(" · ").foregroundColor(theme.fgDim) +
             Text(timeStr).foregroundColor(theme.fgDim))
                .font(.system(size: 13, design: .monospaced))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(theme.bgHighlight)
        .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .bottom)
    }
}

// MARK: - Dashboard Section

struct DashboardSection<Content: View>: View {
    let title: String
    let subtitle: String
    let theme: Theme
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(theme.border).frame(height: 1)

            HStack {
                Text(title)
                    .font(.system(size: 13, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Sol.blue)
                    .tracking(1)
                Spacer()
                Text(subtitle)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(theme.fgDim)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(theme.bgHighlight)

            Rectangle().fill(theme.border).frame(height: 1)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Footer

struct FooterView: View {
    let theme: Theme
    let refreshTime: String
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(theme.border).frame(height: 1)

            HStack {
                Text("refreshed \(refreshTime)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.fgDim)
                Spacer()
                Button(action: onRefresh) {
                    Text("[ refresh ]")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Sol.cyan)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .overlay(Rectangle().stroke(theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.bgHighlight)
        }
    }
}

// MARK: - Game Card Components

struct GameCardContainer<HeaderRight: View, Content: View>: View {
    let label: String
    let theme: Theme
    @ViewBuilder let headerRight: () -> HeaderRight
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("┌ \(label)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.fgDim)
                    .tracking(0.5)
                Spacer()
                headerRight()
                    .font(.system(size: 12, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(theme.bgHighlight)

            Rectangle().fill(theme.border).frame(height: 1)

            content().padding(10)
        }
        .overlay(Rectangle().stroke(theme.border, lineWidth: 1))
        .padding(.bottom, 10)
    }
}

struct ScoreBarView: View {
    let score: Int
    let maxScore: Int
    let color: Color
    let theme: Theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(theme.bgHighlight)
                    .overlay(Rectangle().stroke(theme.border, lineWidth: 1))
                if maxScore > 0 {
                    Rectangle().fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / CGFloat(maxScore))
                }
            }
        }
        .frame(height: 14)
    }
}

struct ScoreRow: View {
    let abbr: String
    let color: Color
    let score: Int
    let maxScore: Int
    let theme: Theme

    var body: some View {
        HStack(spacing: 8) {
            Text(abbr)
                .font(.system(size: 14, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(width: 34, alignment: .leading)
            ScoreBarView(score: score, maxScore: maxScore, color: color, theme: theme)
            Text("\(score)")
                .font(.system(size: 14, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(width: 24, alignment: .trailing)
        }
    }
}

struct MatchupView: View {
    let myAbbr: String
    let myColor: Color
    let oppAbbr: String
    let vs: String
    let venue: String
    let theme: Theme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(myAbbr).foregroundColor(myColor).fontWeight(.bold)
                Text(vs).foregroundColor(theme.fgDim).font(.system(size: 12, design: .monospaced))
                Text(oppAbbr).foregroundColor(theme.fgEmphasis).fontWeight(.bold)
            }
            .font(.system(size: 18, design: .monospaced))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            Text("@ \(venue)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(theme.fgDim)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
        }
    }
}
