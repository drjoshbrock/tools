import SwiftUI

// MARK: - View

struct RedsSectionView: View {
    let games: [RedsGameType]
    let error: String?
    let record: String?
    let standings: [NLCentralTeam]
    let theme: Theme

    var body: some View {
        Button {
            if let url = URL(string: "https://www.mlb.com/reds") {
                UIApplication.shared.open(url)
            }
        } label: {
            DashboardSection(title: "REDS", subtitle: "Cincinnati", record: record, theme: theme) {
                if let error {
                    Text("✗ \(error)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Sol.red)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(games.enumerated()), id: \.offset) { _, game in
                            gameView(game)
                        }
                    }
                }
                standingsChart
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - NL Central Standings Chart

    @ViewBuilder
    private var standingsChart: some View {
        if !standings.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("NL CENTRAL")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.fgDim)
                    .padding(.bottom, 2)

                HStack(spacing: 6) {
                    Text("").frame(width: 30)
                    Text("").frame(maxWidth: .infinity)
                    Text("W-L").frame(width: 48, alignment: .trailing)
                    Text("GB").frame(width: 36, alignment: .trailing)
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.fgDim)

                ForEach(standings, id: \.abbr) { team in
                    standingsRow(team)
                }
            }
            .padding(10)
            .overlay(Rectangle().stroke(theme.border, lineWidth: 1))
            .padding(.top, 10)
        }
    }

    private func standingsRow(_ team: NLCentralTeam) -> some View {
        HStack(spacing: 6) {
            Text(team.abbr)
                .font(.system(size: 13, design: .monospaced))
                .fontWeight(team.isReds ? .bold : .regular)
                .foregroundColor(team.color)
                .frame(width: 30, alignment: .leading)

            GeometryReader { geo in
                let maxWins = standings.first?.wins ?? 1
                let barWidth = geo.size.width * CGFloat(team.wins) / CGFloat(max(maxWins, 1))
                ZStack(alignment: .leading) {
                    Rectangle().fill(theme.bgHighlight)
                        .overlay(Rectangle().stroke(theme.border, lineWidth: 1))
                    Rectangle().fill(team.color.opacity(team.isReds ? 1.0 : 0.6))
                        .frame(width: barWidth)
                }
            }
            .frame(height: 14)

            Text("\(team.wins)-\(team.losses)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(team.color)
                .frame(width: 48, alignment: .trailing)

            Text(team.gamesBack)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(team.rank == 1 ? Sol.green : team.color)
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Game Views

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
                Text(detail).foregroundColor(Sol.orange)
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
                Text(time).foregroundColor(Sol.orange)
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
}
