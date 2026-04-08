import SwiftUI

// MARK: - MLB API Models

private struct MLBResponse: Codable {
    let dates: [MLBDateEntry]?
}

private struct MLBDateEntry: Codable {
    let games: [MLBGame]?
}

private struct MLBGame: Codable {
    let gameDate: String?
    let status: MLBGameStatus?
    let teams: MLBTeamsPair?
    let venue: MLBVenue?
    let decisions: MLBDecisions?
    let linescore: MLBLinescore?
}

private struct MLBGameStatus: Codable {
    let detailedState: String?
}

private struct MLBTeamsPair: Codable {
    let home: MLBTeamEntry
    let away: MLBTeamEntry
}

private struct MLBTeamEntry: Codable {
    let team: MLBTeamInfo
    let score: Int?
    let probablePitcher: MLBPerson?
}

private struct MLBTeamInfo: Codable {
    let id: Int
    let name: String
}

private struct MLBVenue: Codable {
    let name: String?
}

private struct MLBDecisions: Codable {
    let winner: MLBPerson?
    let loser: MLBPerson?
    let save: MLBPerson?
}

private struct MLBPerson: Codable {
    let fullName: String?
}

private struct MLBLinescore: Codable {
    let currentInningOrdinal: String?
    let inningHalf: String?
}

// MARK: - Team Abbreviations

private let mlbTeams: [String: String] = [
    "Cincinnati Reds": "CIN", "St. Louis Cardinals": "STL", "Chicago Cubs": "CHC",
    "Milwaukee Brewers": "MIL", "Pittsburgh Pirates": "PIT", "Atlanta Braves": "ATL",
    "New York Mets": "NYM", "Philadelphia Phillies": "PHI", "Washington Nationals": "WSH",
    "Miami Marlins": "MIA", "Los Angeles Dodgers": "LAD", "San Francisco Giants": "SF",
    "San Diego Padres": "SD", "Arizona Diamondbacks": "ARI", "Colorado Rockies": "COL",
    "New York Yankees": "NYY", "Boston Red Sox": "BOS", "Tampa Bay Rays": "TB",
    "Toronto Blue Jays": "TOR", "Baltimore Orioles": "BAL", "Minnesota Twins": "MIN",
    "Cleveland Guardians": "CLE", "Chicago White Sox": "CWS", "Detroit Tigers": "DET",
    "Kansas City Royals": "KC", "Houston Astros": "HOU", "Texas Rangers": "TEX",
    "Seattle Mariners": "SEA", "Los Angeles Angels": "LAA", "Oakland Athletics": "OAK",
]

private func mlbAbbr(_ name: String) -> String {
    mlbTeams[name] ?? String(name.prefix(3)).uppercased()
}

// MARK: - Internal Game Data

private enum RedsGameType {
    case final_(label: String, myScore: Int, oppAbbr: String, oppScore: Int,
                venue: String, isHome: Bool, winP: String?, loseP: String?, saveP: String?)
    case live(myScore: Int, oppAbbr: String, oppScore: Int, detail: String)
    case upcoming(oppAbbr: String, vs: String, time: String, venue: String,
                  redsPitcher: String?, oppPitcher: String?, oppPitcherAbbr: String?)
}

// MARK: - View

struct RedsSectionView: View {
    let theme: Theme
    let refreshTrigger: Int

    @State private var games: [RedsGameType] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if !isLoading && error == nil && games.isEmpty {
                EmptyView()
            } else if let error, !isLoading {
                DashboardSection(title: "REDS", subtitle: "Cincinnati", theme: theme) {
                    Text("✗ \(error)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Sol.red)
                }
            } else if !games.isEmpty {
                Button {
                    if let url = URL(string: "mlb://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    DashboardSection(title: "REDS", subtitle: "Cincinnati", theme: theme) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(games.enumerated()), id: \.offset) { _, game in
                                gameView(game)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: refreshTrigger) {
            await loadData()
        }
    }

    @ViewBuilder
    private func gameView(_ game: RedsGameType) -> some View {
        switch game {
        case .final_(let label, let myScore, let oppAbbr, let oppScore,
                     let venue, let isHome, let winP, let loseP, let saveP):
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
                    ScoreRow(abbr: "CIN", color: Sol.red, score: myScore, maxScore: maxS, theme: theme)
                    ScoreRow(abbr: oppAbbr, color: theme.fgEmphasis, score: oppScore, maxScore: maxS, theme: theme)

                    VStack(alignment: .leading, spacing: 2) {
                        if let w = winP {
                            (Text("W").foregroundColor(Sol.green).bold() +
                             Text(": ").foregroundColor(theme.fgDim) +
                             Text(w).foregroundColor(Sol.violet))
                                .font(.system(size: 13, design: .monospaced))
                        }
                        if let l = loseP {
                            (Text("L").foregroundColor(Sol.red).bold() +
                             Text(": ").foregroundColor(theme.fgDim) +
                             Text(l).foregroundColor(Sol.violet))
                                .font(.system(size: 13, design: .monospaced))
                        }
                        if let s = saveP {
                            (Text("S: ").foregroundColor(theme.fgDim) +
                             Text(s).foregroundColor(Sol.violet))
                                .font(.system(size: 13, design: .monospaced))
                        }
                        if !venue.isEmpty {
                            Text("@ \(venue) (\(isHome ? "Home" : "Away"))")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(theme.fgDim)
                        }
                    }
                    .padding(.top, 4)
                }
            }

        case .live(let myScore, let oppAbbr, let oppScore, let detail):
            GameCardContainer(label: "LIVE", theme: theme) {
                Text(detail).foregroundColor(Sol.yellow)
            } content: {
                let maxS = max(myScore, oppScore, 1)
                VStack(spacing: 4) {
                    ScoreRow(abbr: "CIN", color: Sol.red, score: myScore, maxScore: maxS, theme: theme)
                    ScoreRow(abbr: oppAbbr, color: theme.fgEmphasis, score: oppScore, maxScore: maxS, theme: theme)
                }
            }

        case .upcoming(let oppAbbr, let vs, let time, let venue,
                       let redsPitcher, let oppPitcher, let oppPitcherAbbr):
            GameCardContainer(label: "UPCOMING", theme: theme) {
                Text(time).foregroundColor(Sol.yellow)
            } content: {
                VStack(spacing: 0) {
                    MatchupView(myAbbr: "CIN", myColor: Sol.red, oppAbbr: oppAbbr,
                                vs: vs, venue: venue, theme: theme)

                    if redsPitcher != nil || oppPitcher != nil {
                        VStack(alignment: .leading, spacing: 3) {
                            Rectangle().fill(theme.border).frame(height: 1)
                                .padding(.bottom, 8)

                            HStack(spacing: 8) {
                                Text("CIN").foregroundColor(Sol.red)
                                    .fontWeight(.bold).frame(width: 34, alignment: .leading)
                                Text(redsPitcher ?? "TBD").foregroundColor(Sol.violet)
                            }
                            .font(.system(size: 13, design: .monospaced))

                            HStack(spacing: 8) {
                                Text(oppPitcherAbbr ?? oppAbbr).foregroundColor(theme.fgEmphasis)
                                    .fontWeight(.bold).frame(width: 34, alignment: .leading)
                                Text(oppPitcher ?? "TBD").foregroundColor(Sol.violet)
                            }
                            .font(.system(size: 13, design: .monospaced))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        let redsId = DashboardConfig.redsId
        let yesterday = yesterdayString()
        let today = todayString()

        do {
            let yUrl = "https://statsapi.mlb.com/api/v1/schedule?teamId=\(redsId)&date=\(yesterday)&sportId=1&hydrate=probablePitcher,linescore,decisions,team"
            let tUrl = "https://statsapi.mlb.com/api/v1/schedule?teamId=\(redsId)&date=\(today)&sportId=1&hydrate=probablePitcher,linescore,decisions,team"

            async let yData = URLSession.shared.data(from: URL(string: yUrl)!)
            async let tData = URLSession.shared.data(from: URL(string: tUrl)!)

            let (yBytes, _) = try await yData
            let (tBytes, _) = try await tData

            let yResp = try JSONDecoder().decode(MLBResponse.self, from: yBytes)
            let tResp = try JSONDecoder().decode(MLBResponse.self, from: tBytes)

            var result: [RedsGameType] = []

            if let yGame = yResp.dates?.first?.games?.first {
                if let gt = processGame(yGame, label: "YESTERDAY", redsId: redsId) {
                    result.append(gt)
                }
            }

            if let tGame = tResp.dates?.first?.games?.first {
                if let gt = processGame(tGame, label: "TODAY", redsId: redsId) {
                    result.append(gt)
                }
            }

            games = result
            isLoading = false
            error = nil
        } catch {
            isLoading = false
            self.error = error.localizedDescription
        }
    }

    private func processGame(_ game: MLBGame, label: String, redsId: Int) -> RedsGameType? {
        guard let teams = game.teams else { return nil }
        let state = game.status?.detailedState ?? ""
        let isHome = teams.home.team.id == redsId
        let reds = isHome ? teams.home : teams.away
        let opp = isHome ? teams.away : teams.home
        let oppA = mlbAbbr(opp.team.name)

        if state.hasPrefix("Final") || state == "Game Over" {
            let dec = game.decisions
            return .final_(
                label: label,
                myScore: reds.score ?? 0,
                oppAbbr: oppA,
                oppScore: opp.score ?? 0,
                venue: game.venue?.name ?? "",
                isHome: isHome,
                winP: dec?.winner?.fullName,
                loseP: dec?.loser?.fullName,
                saveP: dec?.save?.fullName
            )
        } else if state == "In Progress" || state == "Warmup" || state.contains("Progress") {
            let inning = "\(game.linescore?.inningHalf ?? "") \(game.linescore?.currentInningOrdinal ?? "")"
            return .live(
                myScore: reds.score ?? 0,
                oppAbbr: oppA,
                oppScore: opp.score ?? 0,
                detail: inning.trimmingCharacters(in: .whitespaces)
            )
        } else {
            let gameDate = parseISO8601(game.gameDate ?? "")
            let timeFmt = DateFormatter()
            timeFmt.timeZone = DashboardConfig.tz
            timeFmt.dateFormat = "h:mm a"
            let timeStr = timeFmt.string(from: gameDate) + " ET"
            let vs = isHome ? "vs" : "@"
            let rP = isHome ? teams.home.probablePitcher : teams.away.probablePitcher
            let oP = isHome ? teams.away.probablePitcher : teams.home.probablePitcher
            return .upcoming(
                oppAbbr: oppA,
                vs: vs,
                time: timeStr,
                venue: game.venue?.name ?? "",
                redsPitcher: rP?.fullName,
                oppPitcher: oP?.fullName,
                oppPitcherAbbr: oppA
            )
        }
    }

}
