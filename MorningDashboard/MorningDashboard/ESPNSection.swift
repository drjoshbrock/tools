import SwiftUI

// MARK: - ESPN API Models

private struct ESPNResponse: Codable {
    let events: [ESPNEvent]?
}

private struct ESPNEvent: Codable {
    let competitions: [ESPNCompetition]?
}

private struct ESPNCompetition: Codable {
    let competitors: [ESPNCompetitor]
    let status: ESPNStatus?
    let venue: ESPNVenue?
    let date: String
    let odds: [ESPNOdds]?
}

private struct ESPNCompetitor: Codable {
    let team: ESPNTeam
    let score: String?
    let homeAway: String?
}

private struct ESPNTeam: Codable {
    let id: String
    let abbreviation: String?
}

private struct ESPNStatus: Codable {
    let type: ESPNStatusType?
}

private struct ESPNStatusType: Codable {
    let completed: Bool?
    let state: String?
    let shortDetail: String?
}

private struct ESPNVenue: Codable {
    let fullName: String?
}

private struct ESPNOdds: Codable {
    let details: String?
}

// MARK: - Config

struct ESPNTeamConfig {
    let sport: String
    let league: String
    let teamId: String
    let teamAbbr: String
    let teamColor: Color
    let sectionTitle: String
    let sectionSubtitle: String
    let mode: Mode

    enum Mode {
        case daily, weekly
    }

    static let lakers = ESPNTeamConfig(
        sport: "basketball", league: "nba",
        teamId: "13", teamAbbr: "LAL", teamColor: Sol.violet,
        sectionTitle: "LAKERS", sectionSubtitle: "Los Angeles", mode: .daily
    )
    static let dolphins = ESPNTeamConfig(
        sport: "football", league: "nfl",
        teamId: "15", teamAbbr: "MIA", teamColor: Sol.cyan,
        sectionTitle: "DOLPHINS", sectionSubtitle: "Miami", mode: .weekly
    )
    static let ukBasketball = ESPNTeamConfig(
        sport: "basketball", league: "mens-college-basketball",
        teamId: "96", teamAbbr: "UK", teamColor: Sol.blue,
        sectionTitle: "KENTUCKY", sectionSubtitle: "Basketball", mode: .weekly
    )
    static let ukFootball = ESPNTeamConfig(
        sport: "football", league: "college-football",
        teamId: "96", teamAbbr: "UK", teamColor: Sol.blue,
        sectionTitle: "KENTUCKY", sectionSubtitle: "Football", mode: .weekly
    )
}

// MARK: - Internal Game Data

private enum ESPNGameInfo {
    case final_(label: String, myAbbr: String, myColor: Color, myScore: Int,
                oppAbbr: String, oppScore: Int, venue: String, isHome: Bool)
    case live(myAbbr: String, myColor: Color, myScore: Int,
              oppAbbr: String, oppScore: Int, detail: String)
    case upcoming(myAbbr: String, myColor: Color, oppAbbr: String,
                  vs: String, time: String, venue: String, odds: String?, label: String)
}

// MARK: - View

struct ESPNSectionView: View {
    let config: ESPNTeamConfig
    let theme: Theme
    let refreshTrigger: Int

    @State private var games: [ESPNGameInfo] = []
    @State private var hasData = false

    var body: some View {
        Group {
            if hasData {
                DashboardSection(title: config.sectionTitle, subtitle: config.sectionSubtitle, theme: theme) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(games.enumerated()), id: \.offset) { _, game in
                            espnGameView(game)
                        }
                    }
                }
            }
        }
        .task(id: refreshTrigger) {
            await loadData()
        }
    }

    @ViewBuilder
    private func espnGameView(_ game: ESPNGameInfo) -> some View {
        switch game {
        case .final_(let label, let myAbbr, let myColor, let myScore,
                     let oppAbbr, let oppScore, let venue, let isHome):
            let won = myScore > oppScore
            GameCardContainer(label: label, theme: theme) {
                if won {
                    Text("WIN").foregroundColor(Sol.green).fontWeight(.bold)
                } else {
                    Text("LOSS").foregroundColor(Sol.red).fontWeight(.bold)
                }
            } content: {
                let maxS = max(myScore, oppScore, 1)
                VStack(alignment: .leading, spacing: 4) {
                    ScoreRow(abbr: myAbbr, color: myColor, score: myScore, maxScore: maxS, theme: theme)
                    ScoreRow(abbr: oppAbbr, color: theme.fgEmphasis, score: oppScore, maxScore: maxS, theme: theme)
                    if !venue.isEmpty {
                        Text("@ \(venue) (\(isHome ? "Home" : "Away"))")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(theme.fgDim)
                            .padding(.top, 4)
                    }
                }
            }

        case .live(let myAbbr, let myColor, let myScore,
                   let oppAbbr, let oppScore, let detail):
            GameCardContainer(label: "LIVE", theme: theme) {
                Text(detail).foregroundColor(Sol.yellow)
            } content: {
                let maxS = max(myScore, oppScore, 1)
                VStack(spacing: 4) {
                    ScoreRow(abbr: myAbbr, color: myColor, score: myScore, maxScore: maxS, theme: theme)
                    ScoreRow(abbr: oppAbbr, color: theme.fgEmphasis, score: oppScore, maxScore: maxS, theme: theme)
                }
            }

        case .upcoming(let myAbbr, let myColor, let oppAbbr,
                       let vs, let time, let venue, let odds, let label):
            GameCardContainer(label: label, theme: theme) {
                Text(time).foregroundColor(Sol.yellow)
            } content: {
                VStack(spacing: 0) {
                    MatchupView(myAbbr: myAbbr, myColor: myColor, oppAbbr: oppAbbr,
                                vs: vs, venue: venue, theme: theme)
                    if let odds, !odds.isEmpty {
                        Text(odds)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Sol.yellow)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        switch config.mode {
        case .daily:
            await loadDaily()
        case .weekly:
            await loadWeekly()
        }
    }

    private func loadDaily() async {
        let yDate = yesterdayString().replacingOccurrences(of: "-", with: "")
        let tDate = todayString().replacingOccurrences(of: "-", with: "")
        let base = "https://site.api.espn.com/apis/site/v2/sports/\(config.sport)/\(config.league)/scoreboard"

        do {
            async let yData = URLSession.shared.data(from: URL(string: "\(base)?dates=\(yDate)")!)
            async let tData = URLSession.shared.data(from: URL(string: "\(base)?dates=\(tDate)")!)

            let (yBytes, _) = try await yData
            let (tBytes, _) = try await tData

            let yResp = try JSONDecoder().decode(ESPNResponse.self, from: yBytes)
            let tResp = try JSONDecoder().decode(ESPNResponse.self, from: tBytes)

            var result: [ESPNGameInfo] = []

            if let comp = findTeamGame(in: yResp, teamId: config.teamId) {
                result.append(buildGameInfo(comp, label: "YESTERDAY"))
            }
            if let comp = findTeamGame(in: tResp, teamId: config.teamId) {
                result.append(buildGameInfo(comp, label: "TODAY"))
            }

            games = result
            hasData = !result.isEmpty
        } catch {
            hasData = false
        }
    }

    private func loadWeekly() async {
        let startDate = dateOffsetString(days: -7)
        let endDate = dateOffsetString(days: 7)
        let url = "https://site.api.espn.com/apis/site/v2/sports/\(config.sport)/\(config.league)/scoreboard?dates=\(startDate)-\(endDate)"

        do {
            let (data, _) = try await URLSession.shared.data(from: URL(string: url)!)
            let resp = try JSONDecoder().decode(ESPNResponse.self, from: data)

            var pastGames: [(comp: ESPNCompetition, date: Date)] = []
            var futureGames: [(comp: ESPNCompetition, date: Date)] = []

            for event in resp.events ?? [] {
                guard let comp = event.competitions?.first,
                      comp.competitors.contains(where: { $0.team.id == config.teamId }) else { continue }

                let gameDate = parseISO8601(comp.date)
                let st = comp.status?.type

                if st?.completed == true {
                    pastGames.append((comp, gameDate))
                } else if st?.state == "in" {
                    futureGames.insert((comp, gameDate), at: 0)
                } else {
                    futureGames.append((comp, gameDate))
                }
            }

            pastGames.sort { $0.date > $1.date }
            futureGames.sort { $0.date < $1.date }

            var result: [ESPNGameInfo] = []
            let now = Date()

            if let pg = pastGames.first {
                let daysAgo = Int(round(now.timeIntervalSince(pg.date) / 86400))
                let label = daysAgo <= 1 ? "YESTERDAY" : "\(daysAgo) DAYS AGO"
                result.append(buildGameInfo(pg.comp, label: label))
            }

            if let fg = futureGames.first {
                let st = fg.comp.status?.type
                if st?.state == "in" {
                    result.append(buildGameInfo(fg.comp, label: "LIVE"))
                } else {
                    let df = DateFormatter()
                    df.timeZone = DashboardConfig.tz
                    df.dateFormat = "EEE MMM d"
                    let label = df.string(from: fg.date).uppercased()
                    result.append(buildGameInfo(fg.comp, label: label))
                }
            }

            games = result
            hasData = !result.isEmpty
        } catch {
            hasData = false
        }
    }

    private func findTeamGame(in response: ESPNResponse, teamId: String) -> ESPNCompetition? {
        for event in response.events ?? [] {
            if let comp = event.competitions?.first,
               comp.competitors.contains(where: { $0.team.id == teamId }) {
                return comp
            }
        }
        return nil
    }

    private func buildGameInfo(_ comp: ESPNCompetition, label: String) -> ESPNGameInfo {
        let my = comp.competitors.first(where: { $0.team.id == config.teamId })!
        let opp = comp.competitors.first(where: { $0.team.id != config.teamId })!
        let oppA = opp.team.abbreviation ?? "OPP"
        let st = comp.status?.type
        let isHome = my.homeAway == "home"
        let venue = comp.venue?.fullName ?? ""

        if st?.completed == true {
            let myS = Int(my.score ?? "0") ?? 0
            let oppS = Int(opp.score ?? "0") ?? 0
            return .final_(label: label, myAbbr: config.teamAbbr, myColor: config.teamColor,
                           myScore: myS, oppAbbr: oppA, oppScore: oppS, venue: venue, isHome: isHome)
        } else if st?.state == "in" {
            let myS = Int(my.score ?? "0") ?? 0
            let oppS = Int(opp.score ?? "0") ?? 0
            return .live(myAbbr: config.teamAbbr, myColor: config.teamColor,
                         myScore: myS, oppAbbr: oppA, oppScore: oppS,
                         detail: st?.shortDetail ?? "")
        } else {
            let vs = isHome ? "vs" : "@"
            let gameDate = parseISO8601(comp.date)
            let timeFmt = DateFormatter()
            timeFmt.timeZone = DashboardConfig.tz
            timeFmt.dateFormat = "h:mm a"
            let time = timeFmt.string(from: gameDate) + " ET"
            let odds = comp.odds?.first?.details
            return .upcoming(myAbbr: config.teamAbbr, myColor: config.teamColor,
                             oppAbbr: oppA, vs: vs, time: time, venue: venue,
                             odds: odds, label: "UPCOMING")
        }
    }
}

