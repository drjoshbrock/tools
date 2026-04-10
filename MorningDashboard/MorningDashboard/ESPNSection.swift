import SwiftUI

// MARK: - Config

struct ESPNTeamConfig {
    let id: String
    let sport: String
    let league: String
    let teamId: String
    let teamAbbr: String
    let teamColor: Color
    let sectionTitle: String
    let sectionSubtitle: String
    let mode: Mode
    let teamURL: String

    enum Mode {
        case daily, weekly
    }

    static let lakers = ESPNTeamConfig(
        id: "lakers",
        sport: "basketball", league: "nba",
        teamId: "13", teamAbbr: "LAL", teamColor: Sol.violet,
        sectionTitle: "LAKERS", sectionSubtitle: "Los Angeles", mode: .daily,
        teamURL: "https://www.espn.com/nba/team/_/name/lal/los-angeles-lakers"
    )
    static let dolphins = ESPNTeamConfig(
        id: "dolphins",
        sport: "football", league: "nfl",
        teamId: "15", teamAbbr: "MIA", teamColor: Sol.cyan,
        sectionTitle: "DOLPHINS", sectionSubtitle: "Miami", mode: .weekly,
        teamURL: "https://www.espn.com/nfl/team/_/name/mia/miami-dolphins"
    )
    static let ukBasketball = ESPNTeamConfig(
        id: "uk-basketball",
        sport: "basketball", league: "mens-college-basketball",
        teamId: "96", teamAbbr: "UK", teamColor: Sol.blue,
        sectionTitle: "KY WILDCATS", sectionSubtitle: "Basketball", mode: .weekly,
        teamURL: "https://www.espn.com/mens-college-basketball/team/_/id/96/kentucky-wildcats"
    )
    static let ukFootball = ESPNTeamConfig(
        id: "uk-football",
        sport: "football", league: "college-football",
        teamId: "96", teamAbbr: "UK", teamColor: Sol.blue,
        sectionTitle: "KY WILDCATS", sectionSubtitle: "Football", mode: .weekly,
        teamURL: "https://www.espn.com/college-football/team/_/id/96/kentucky-wildcats"
    )
}

// MARK: - View

struct ESPNSectionView: View {
    let config: ESPNTeamConfig
    let games: [ESPNGameInfo]
    let error: String?
    let theme: Theme

    var body: some View {
        Button {
            if let url = URL(string: config.teamURL) {
                UIApplication.shared.open(url)
            }
        } label: {
            DashboardSection(title: config.sectionTitle, subtitle: config.sectionSubtitle, theme: theme) {
                if let error {
                    Text("✗ \(error)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Sol.red)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(games.enumerated()), id: \.offset) { _, game in
                            espnGameView(game)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
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
                Text(detail).foregroundColor(Sol.orange)
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
                Text(time).foregroundColor(Sol.orange)
            } content: {
                VStack(spacing: 0) {
                    MatchupView(myAbbr: myAbbr, myColor: myColor, oppAbbr: oppAbbr,
                                vs: vs, venue: venue, theme: theme)
                    if let odds, !odds.isEmpty {
                        Text(odds)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Sol.orange)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)
                    }
                }
            }
        }
    }
}
