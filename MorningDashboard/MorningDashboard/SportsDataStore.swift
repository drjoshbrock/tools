import SwiftUI

// MARK: - MLB API Models

struct MLBResponse: Codable {
    let dates: [MLBDateEntry]?
}

struct MLBDateEntry: Codable {
    let games: [MLBGame]?
}

struct MLBGame: Codable {
    let gameDate: String?
    let status: MLBGameStatus?
    let teams: MLBTeamsPair?
    let venue: MLBVenue?
    let decisions: MLBDecisions?
    let linescore: MLBLinescore?
}

struct MLBGameStatus: Codable {
    let detailedState: String?
}

struct MLBTeamsPair: Codable {
    let home: MLBTeamEntry
    let away: MLBTeamEntry
}

struct MLBTeamEntry: Codable {
    let team: MLBTeamInfo
    let score: Int?
    let probablePitcher: MLBPerson?
}

struct MLBTeamInfo: Codable {
    let id: Int
    let name: String
}

struct MLBVenue: Codable {
    let name: String?
}

struct MLBDecisions: Codable {
    let winner: MLBPerson?
    let loser: MLBPerson?
    let save: MLBPerson?
}

struct MLBPerson: Codable {
    let fullName: String?
}

struct MLBLinescore: Codable {
    let currentInningOrdinal: String?
    let inningHalf: String?
}

// MARK: - MLB Standings API Models

struct MLBStandingsResponse: Codable {
    let records: [MLBStandingsRecord]?
}

struct MLBStandingsRecord: Codable {
    let teamRecords: [MLBTeamRecord]?
}

struct MLBTeamRecord: Codable {
    let team: MLBTeamInfo
    let wins: Int
    let losses: Int
    let divisionRank: String?
    let gamesBack: String?
    let winningPercentage: String?
}

// MARK: - ESPN API Models

struct ESPNResponse: Codable {
    let events: [ESPNEvent]?
}

struct ESPNEvent: Codable {
    let competitions: [ESPNCompetition]?
}

struct ESPNCompetition: Codable {
    let competitors: [ESPNCompetitor]?
    let status: ESPNStatus?
    let venue: ESPNVenue?
    let date: String?
    let odds: [ESPNOdds]?
}

struct ESPNCompetitor: Codable {
    let team: ESPNTeam
    let score: String?
    let homeAway: String?
    let records: [ESPNRecord]?
}

struct ESPNRecord: Codable {
    let type: String?
    let summary: String?
}

struct ESPNTeam: Codable {
    let id: String
    let abbreviation: String?
}

struct ESPNStatus: Codable {
    let type: ESPNStatusType?
}

struct ESPNStatusType: Codable {
    let completed: Bool?
    let state: String?
    let shortDetail: String?
}

struct ESPNVenue: Codable {
    let fullName: String?
}

struct ESPNOdds: Codable {
    let details: String?
}

// MARK: - Team Abbreviations

let mlbTeams: [String: String] = [
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

func mlbAbbr(_ name: String) -> String {
    mlbTeams[name] ?? String(name.prefix(3)).uppercased()
}

// MARK: - Game Types

enum RedsGameType {
    case final_(label: String, myScore: Int, oppAbbr: String, oppScore: Int,
                venue: String, isHome: Bool, winP: String?, loseP: String?, saveP: String?)
    case live(myScore: Int, oppAbbr: String, oppScore: Int, detail: String)
    case upcoming(oppAbbr: String, vs: String, time: String, venue: String,
                  redsPitcher: String?, oppPitcher: String?, oppPitcherAbbr: String?)
}

enum ESPNGameInfo {
    case final_(label: String, myAbbr: String, myColor: Color, myScore: Int,
                oppAbbr: String, oppScore: Int, venue: String, isHome: Bool)
    case live(myAbbr: String, myColor: Color, myScore: Int,
              oppAbbr: String, oppScore: Int, detail: String)
    case upcoming(myAbbr: String, myColor: Color, oppAbbr: String,
                  vs: String, time: String, venue: String, odds: String?, label: String)
}

// MARK: - Section Result

struct SportsResult<T> {
    var games: [T] = []
    var error: String?
    var record: String?
}

struct NLCentralTeam {
    let abbr: String
    let wins: Int
    let losses: Int
    let gamesBack: String
    let rank: Int
    let color: Color
    let isReds: Bool
}

// MARK: - Data Store

@Observable
class SportsDataStore {
    var reds = SportsResult<RedsGameType>()
    var redsRecord: String?
    var espnResults: [String: SportsResult<ESPNGameInfo>] = [:]
    var nlCentralStandings: [NLCentralTeam] = []
    var hasLoadedOnce = false

    func loadAll(mode: DashboardModeType = .morning) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadReds(mode: mode) }
            group.addTask { await self.loadNLCentralStandings() }
            group.addTask { await self.loadESPN(.lakers, mode: mode) }
            group.addTask { await self.loadESPN(.dolphins, mode: mode) }
            group.addTask { await self.loadESPN(.ukBasketball, mode: mode) }
            group.addTask { await self.loadESPN(.ukFootball, mode: mode) }
        }
        hasLoadedOnce = true
    }

    // MARK: - Reds Loading

    private func loadReds(mode: DashboardModeType) async {
        let redsId = DashboardConfig.redsId
        let isEvening = mode == .evening

        // Morning: yesterday + today. Evening: today + tomorrow.
        let date1 = isEvening ? todayString() : yesterdayString()
        let date2 = isEvening ? tomorrowString() : todayString()
        let label1 = isEvening ? "TODAY" : "YESTERDAY"
        let label2 = isEvening ? "TOMORROW" : "TODAY"

        do {
            try Task.checkCancellation()
            let url1 = "https://statsapi.mlb.com/api/v1/schedule?teamId=\(redsId)&date=\(date1)&sportId=1&hydrate=probablePitcher,linescore,decisions,team"
            let url2 = "https://statsapi.mlb.com/api/v1/schedule?teamId=\(redsId)&date=\(date2)&sportId=1&hydrate=probablePitcher,linescore,decisions,team"

            async let data1 = URLSession.shared.data(from: URL(string: url1)!)
            async let data2 = URLSession.shared.data(from: URL(string: url2)!)

            let (bytes1, _) = try await data1
            let (bytes2, _) = try await data2
            try Task.checkCancellation()

            let resp1 = try JSONDecoder().decode(MLBResponse.self, from: bytes1)
            let resp2 = try JSONDecoder().decode(MLBResponse.self, from: bytes2)

            var result: [RedsGameType] = []

            if let game1 = resp1.dates?.first?.games?.first {
                if let gt = processMLBGame(game1, label: label1, redsId: redsId) {
                    result.append(gt)
                }
            }

            if let game2 = resp2.dates?.first?.games?.first {
                if let gt = processMLBGame(game2, label: label2, redsId: redsId) {
                    result.append(gt)
                }
            }

            reds = SportsResult(games: result, error: nil)
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            reds = SportsResult(games: [], error: error.localizedDescription)
        }
    }

    private func processMLBGame(_ game: MLBGame, label: String, redsId: Int) -> RedsGameType? {
        guard let teams = game.teams else { return nil }
        let state = game.status?.detailedState ?? ""
        let isHome = teams.home.team.id == redsId
        let redsTeam = isHome ? teams.home : teams.away
        let opp = isHome ? teams.away : teams.home
        let oppA = mlbAbbr(opp.team.name)

        if state.hasPrefix("Final") || state == "Game Over" {
            let dec = game.decisions
            return .final_(
                label: label,
                myScore: redsTeam.score ?? 0,
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
                myScore: redsTeam.score ?? 0,
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

    // MARK: - NL Central Standings

    private let nlCentralInfo: [Int: (color: Color, abbr: String)] = [
        113: (Sol.red, "CIN"),       // Cincinnati Reds
        138: (Sol.magenta, "STL"),   // St. Louis Cardinals
        112: (Sol.blue, "CHC"),      // Chicago Cubs
        158: (Sol.cyan, "MIL"),      // Milwaukee Brewers
        134: (Sol.orange, "PIT"),    // Pittsburgh Pirates
    ]

    private func loadNLCentralStandings() async {
        let year = Calendar.current.component(.year, from: Date())
        // Fetch all NL standings and find the Reds' division dynamically
        let urlStr = "https://statsapi.mlb.com/api/v1/standings?leagueId=104&season=\(year)&standingsTypes=regularSeason"

        do {
            try Task.checkCancellation()
            let (data, _) = try await URLSession.shared.data(from: URL(string: urlStr)!)
            try Task.checkCancellation()
            let resp = try JSONDecoder().decode(MLBStandingsResponse.self, from: data)

            // Find the division record that contains the Reds
            guard let redsRecord = resp.records?.first(where: { record in
                record.teamRecords?.contains(where: { $0.team.id == DashboardConfig.redsId }) == true
            }), let teamRecords = redsRecord.teamRecords else {
                nlCentralStandings = []
                return
            }

            var teams: [NLCentralTeam] = []

            for tr in teamRecords {
                let info = nlCentralInfo[tr.team.id]
                let abbr = info?.abbr ?? mlbAbbr(tr.team.name)
                let color = info?.color ?? Sol.base01
                let isReds = tr.team.id == DashboardConfig.redsId
                let rank = Int(tr.divisionRank ?? "0") ?? 0
                let gb = tr.gamesBack ?? "-"
                let gbDisplay = gb == "-" ? "—" : gb

                teams.append(NLCentralTeam(
                    abbr: abbr,
                    wins: tr.wins,
                    losses: tr.losses,
                    gamesBack: gbDisplay,
                    rank: rank,
                    color: color,
                    isReds: isReds
                ))

                if isReds {
                    self.redsRecord = "\(tr.wins)-\(tr.losses)"
                }
            }

            teams.sort { $0.rank < $1.rank }
            nlCentralStandings = teams
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            nlCentralStandings = []
        }
    }

    // MARK: - ESPN Loading

    private func loadESPN(_ config: ESPNTeamConfig, mode: DashboardModeType = .morning) async {
        let key = config.id
        switch config.mode {
        case .daily:
            await loadESPNDaily(config, key: key, mode: mode)
        case .weekly:
            await loadESPNWeekly(config, key: key)
        }
    }

    private func loadESPNDaily(_ config: ESPNTeamConfig, key: String, mode: DashboardModeType) async {
        let isEvening = mode == .evening
        // Morning: yesterday + today. Evening: today + tomorrow.
        let date1Str = isEvening ? todayString().replacingOccurrences(of: "-", with: "") : yesterdayString().replacingOccurrences(of: "-", with: "")
        let date2Str = isEvening ? tomorrowString().replacingOccurrences(of: "-", with: "") : todayString().replacingOccurrences(of: "-", with: "")
        let label1 = isEvening ? "TODAY" : "YESTERDAY"
        let label2 = isEvening ? "TOMORROW" : "TODAY"
        let base = "https://site.api.espn.com/apis/site/v2/sports/\(config.sport)/\(config.league)/scoreboard"

        do {
            try Task.checkCancellation()
            async let data1 = URLSession.shared.data(from: URL(string: "\(base)?dates=\(date1Str)")!)
            async let data2 = URLSession.shared.data(from: URL(string: "\(base)?dates=\(date2Str)")!)

            let (bytes1, _) = try await data1
            let (bytes2, _) = try await data2
            try Task.checkCancellation()

            let resp1 = try JSONDecoder().decode(ESPNResponse.self, from: bytes1)
            let resp2 = try JSONDecoder().decode(ESPNResponse.self, from: bytes2)

            var result: [ESPNGameInfo] = []
            var record: String?

            if let comp = findTeamGame(in: resp1, teamId: config.teamId),
               let built = buildGameInfo(comp, config: config, label: label1) {
                result.append(built.game)
                record = record ?? built.record
            }
            if let comp = findTeamGame(in: resp2, teamId: config.teamId),
               let built = buildGameInfo(comp, config: config, label: label2) {
                result.append(built.game)
                record = record ?? built.record
            }

            espnResults[key] = SportsResult(games: result, error: nil, record: record)
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            espnResults[key] = SportsResult(games: [], error: error.localizedDescription)
        }
    }

    private func loadESPNWeekly(_ config: ESPNTeamConfig, key: String) async {
        let startDate = dateOffsetString(days: -7)
        let endDate = dateOffsetString(days: 7)
        let url = "https://site.api.espn.com/apis/site/v2/sports/\(config.sport)/\(config.league)/scoreboard?dates=\(startDate)-\(endDate)"

        do {
            try Task.checkCancellation()
            let (data, _) = try await URLSession.shared.data(from: URL(string: url)!)
            try Task.checkCancellation()
            let resp = try JSONDecoder().decode(ESPNResponse.self, from: data)

            var pastGames: [(comp: ESPNCompetition, date: Date)] = []
            var futureGames: [(comp: ESPNCompetition, date: Date)] = []

            for event in resp.events ?? [] {
                guard let comp = event.competitions?.first,
                      let competitors = comp.competitors,
                      competitors.contains(where: { $0.team.id == config.teamId }) else { continue }

                let gameDate = parseISO8601(comp.date ?? "")
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
            var record: String?
            let now = Date()

            if let pg = pastGames.first {
                let daysAgo = Int(round(now.timeIntervalSince(pg.date) / 86400))
                let label = daysAgo <= 1 ? "YESTERDAY" : "\(daysAgo) DAYS AGO"
                if let built = buildGameInfo(pg.comp, config: config, label: label) {
                    result.append(built.game)
                    record = record ?? built.record
                }
            }

            if let fg = futureGames.first {
                let st = fg.comp.status?.type
                let label: String
                if st?.state == "in" {
                    label = "LIVE"
                } else {
                    let df = DateFormatter()
                    df.timeZone = DashboardConfig.tz
                    df.dateFormat = "EEE MMM d"
                    label = df.string(from: fg.date).uppercased()
                }
                if let built = buildGameInfo(fg.comp, config: config, label: label) {
                    result.append(built.game)
                    record = record ?? built.record
                }
            }

            espnResults[key] = SportsResult(games: result, error: nil, record: record)
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            espnResults[key] = SportsResult(games: [], error: error.localizedDescription)
        }
    }

    private func findTeamGame(in response: ESPNResponse, teamId: String) -> ESPNCompetition? {
        for event in response.events ?? [] {
            if let comp = event.competitions?.first,
               let competitors = comp.competitors,
               competitors.contains(where: { $0.team.id == teamId }) {
                return comp
            }
        }
        return nil
    }

    private func buildGameInfo(_ comp: ESPNCompetition, config: ESPNTeamConfig, label: String) -> (game: ESPNGameInfo, record: String?)? {
        guard let competitors = comp.competitors,
              let my = competitors.first(where: { $0.team.id == config.teamId }),
              let opp = competitors.first(where: { $0.team.id != config.teamId }) else {
            return nil
        }
        let oppA = opp.team.abbreviation ?? "OPP"
        let st = comp.status?.type
        let isHome = my.homeAway == "home"
        let venue = comp.venue?.fullName ?? ""
        let record = my.records?.first(where: { $0.type == "total" })?.summary

        if st?.completed == true {
            let myS = Int(my.score ?? "0") ?? 0
            let oppS = Int(opp.score ?? "0") ?? 0
            return (.final_(label: label, myAbbr: config.teamAbbr, myColor: config.teamColor,
                           myScore: myS, oppAbbr: oppA, oppScore: oppS, venue: venue, isHome: isHome), record)
        } else if st?.state == "in" {
            let myS = Int(my.score ?? "0") ?? 0
            let oppS = Int(opp.score ?? "0") ?? 0
            return (.live(myAbbr: config.teamAbbr, myColor: config.teamColor,
                         myScore: myS, oppAbbr: oppA, oppScore: oppS,
                         detail: st?.shortDetail ?? ""), record)
        } else {
            let vs = isHome ? "vs" : "@"
            let gameDate = parseISO8601(comp.date ?? "")
            let timeFmt = DateFormatter()
            timeFmt.timeZone = DashboardConfig.tz
            timeFmt.dateFormat = "h:mm a"
            let time = timeFmt.string(from: gameDate) + " ET"
            let odds = comp.odds?.first?.details
            return (.upcoming(myAbbr: config.teamAbbr, myColor: config.teamColor,
                             oppAbbr: oppA, vs: vs, time: time, venue: venue,
                             odds: odds, label: "UPCOMING"), record)
        }
    }
}
