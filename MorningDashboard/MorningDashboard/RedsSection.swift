import SwiftUI

// MARK: - View

struct RedsSectionView: View {
    let games: [RedsGameType]
    let error: String?
    let theme: Theme

    var body: some View {
        Button {
            if let url = URL(string: "mlbatbat://") {
                UIApplication.shared.open(url)
            }
        } label: {
            DashboardSection(title: "REDS", subtitle: "Cincinnati", theme: theme) {
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
            }
        }
        .buttonStyle(.plain)
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
