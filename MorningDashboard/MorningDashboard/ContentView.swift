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

func tomorrowString() -> String {
    let df = DateFormatter()
    df.timeZone = DashboardConfig.tz
    df.dateFormat = "yyyy-MM-dd"
    return df.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
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

func openLink(appScheme: String, webURL: String) {
    if let appURL = URL(string: appScheme),
       UIApplication.shared.canOpenURL(appURL) {
        UIApplication.shared.open(appURL)
    } else if let url = URL(string: webURL) {
        UIApplication.shared.open(url)
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DashboardMode.self) private var dashboardMode
    @State private var refreshTrigger = 0
    @State private var refreshTime = ""
    @State private var sportsStore = SportsDataStore()

    private var theme: Theme { Theme(colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TitleBarView(theme: theme, refreshTrigger: refreshTrigger)

                WeatherSectionView(theme: theme, refreshTrigger: refreshTrigger)
                CalendarSectionView(theme: theme, refreshTrigger: refreshTrigger)

                if !sportsStore.hasLoadedOnce {
                    // Show loading placeholders on first load
                    DashboardSection(title: "REDS", subtitle: "Cincinnati", theme: theme) {
                        LoadingDotsView(theme: theme)
                    }
                    ForEach([ESPNTeamConfig.lakers, .dolphins, .ukBasketball, .ukFootball],
                            id: \.id) { config in
                        DashboardSection(title: config.sectionTitle, subtitle: config.sectionSubtitle, theme: theme) {
                            LoadingDotsView(theme: theme)
                        }
                    }
                } else {
                    if !sportsStore.reds.games.isEmpty || sportsStore.reds.error != nil
                        || !sportsStore.nlCentralStandings.isEmpty {
                        RedsSectionView(games: sportsStore.reds.games,
                                        error: sportsStore.reds.error,
                                        record: sportsStore.redsRecord,
                                        standings: sportsStore.nlCentralStandings,
                                        theme: theme)
                    }

                    ForEach([ESPNTeamConfig.lakers, .dolphins, .ukBasketball, .ukFootball],
                            id: \.id) { config in
                        let result = sportsStore.espnResults[config.id]
                        if let result, !result.games.isEmpty || result.error != nil {
                            ESPNSectionView(config: config, games: result.games,
                                            error: result.error,
                                            record: result.record, theme: theme)
                        }
                    }
                }

                FooterView(theme: theme, refreshTime: refreshTime) {
                    refreshTime = formattedTime()
                    refreshTrigger += 1
                }
            }
            .overlay(Rectangle().stroke(theme.border, lineWidth: 1))
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            modeToggleBar
        }
        .background(theme.bg)
        .onAppear { refreshTime = formattedTime() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                dashboardMode.resetToAuto()
                refreshTime = formattedTime()
                refreshTrigger += 1
            }
        }
        .task(id: refreshTrigger) {
            await sportsStore.loadAll(mode: dashboardMode.activeMode)
        }
    }

    private var modeToggleBar: some View {
        Button {
            dashboardMode.toggle()
            refreshTrigger += 1
        } label: {
            HStack {
                Spacer()
                Text("[ switch to \(dashboardMode.otherModeLabel) ]")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Sol.cyan)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.vertical, 10)
            .background(theme.bgHighlight)
            .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .top)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Title Bar

struct TitleBarView: View {
    let theme: Theme
    let refreshTrigger: Int
    @Environment(DashboardMode.self) private var dashboardMode

    private var dateStr: String {
        let df = DateFormatter()
        df.timeZone = DashboardConfig.tz
        df.dateFormat = "EEEE, MMMM d"
        return df.string(from: dashboardMode.targetDate).uppercased()
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(dashboardMode.greeting)
                .font(.system(size: 22, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Sol.orange)
                .tracking(2)
            Text(dateStr)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(theme.fgDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(theme.bgHighlight)
        .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .bottom)
    }
}

// MARK: - Dashboard Section

struct DashboardSection<Content: View>: View {
    let title: String
    let subtitle: String
    let record: String?
    let theme: Theme
    @ViewBuilder let content: () -> Content

    init(title: String, subtitle: String, record: String? = nil,
         theme: Theme, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.record = record
        self.theme = theme
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(theme.border).frame(height: 1)

            HStack {
                Text(title)
                    .font(.system(size: 17, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Sol.blue)
                    .tracking(1)
                if let record {
                    Text("(\(record))")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Sol.green)
                }
                Spacer()
                Text(subtitle)
                    .font(.system(size: 14, design: .monospaced))
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
                .frame(width: 34, alignment: .trailing)
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

// MARK: - Loading Animation

struct LoadingDotsView: View {
    let theme: Theme

    private let frames = ["·     ", "· ·   ", "· · · ", "  · · ", "    · ", "      "]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { context in
            let idx = Int(context.date.timeIntervalSince1970 / 0.3) % frames.count
            Text(frames[idx])
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Sol.cyan)
        }
    }
}
