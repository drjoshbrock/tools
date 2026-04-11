# Horizon App - Technical Structure & Implementation Details

## Project Layout

```
Horizon/
├── Horizon.xcodeproj/
│   └── project.pbxproj
└── Horizon/
    ├── HorizonApp.swift          # @main entry point
    ├── ContentView.swift         # Main layout, shared components, utility functions
    ├── SolarizedTheme.swift      # Sol colors, Theme struct, DashboardConfig
    ├── DashboardMode.swift       # Morning/evening mode logic
    ├── WeatherSection.swift      # Weather display + Open-Meteo API
    ├── CalendarSection.swift     # Calendar display + EventKit
    ├── RedsSection.swift         # Reds game cards + NL Central standings
    ├── ESPNSection.swift         # ESPN team configs + game cards
    ├── SportsDataStore.swift     # All API models, data loading, shared types
    ├── Info.plist                # Calendar permissions, LSApplicationQueriesSchemes
    └── Assets.xcassets/
        ├── AccentColor.colorset/ # Solarized cyan accent
        └── AppIcon.appiconset/   # Light + Dark app icons (PNG)
```

## Build Configuration

- **Deployment Target**: iOS 26.0
- **Swift Version**: 5.0
- **Bundle ID**: `com.joshdb.horizon`
- **Display Name**: Horizon
- **Dev Team**: 863Q697NG4
- **Supported Orientations**: Portrait only (iPhone), all (iPad)

## Architecture Overview

### App Entry (`HorizonApp.swift`)

```swift
@main
struct HorizonApp: App {
    @State private var dashboardMode = DashboardMode()
    // DashboardMode injected via .environment() into ContentView
}
```

### Theme System (`SolarizedTheme.swift`)

**`Sol` enum** -- all 16 Solarized colors as static `Color` properties (base03 through base3, yellow through green).

**`Theme` struct** -- takes `ColorScheme`, provides semantic colors:
- `bg` / `bgHighlight` -- background colors (swap between dark/light)
- `fg` / `fgDim` / `fgEmphasis` -- foreground text hierarchy
- `border` -- section dividers

**`DashboardConfig` enum** -- static constants:
- `lat` / `lon` -- 38.40 / -85.61 (Prospect, KY)
- `redsId` -- 113 (MLB team ID)
- `tz` -- America/New_York

### Dashboard Mode (`DashboardMode.swift`)

`@Observable` class with morning/evening mode logic:
- **Auto mode**: Morning before 3pm, evening 3pm-1am
- **Manual toggle**: User can override, resets on app foreground
- **`targetDate`**: Today (morning) or tomorrow (evening)
- **`greeting`**: "GOOD MORNING" / "GOOD EVENING"
- **`calendarSubtitle`**: "Today" / "Tomorrow"

### Content View (`ContentView.swift`)

#### Global Utility Functions

- `formattedTime()` -- current time as "h:mm a"
- `todayString()` / `yesterdayString()` / `tomorrowString()` -- "yyyy-MM-dd" format
- `dateOffsetString(days:)` -- "yyyyMMdd" format (for ESPN API)
- `parseISO8601(_:)` -- parses ISO 8601 dates with/without fractional seconds
- `openLink(appScheme:webURL:)` -- tries app URL scheme, falls back to web URL

#### Main Layout

```
ScrollView
  VStack(spacing: 0)
    TitleBarView          -- greeting + date
    WeatherSectionView    -- weather data
    CalendarSectionView   -- calendar events
    [Loading placeholders OR sports sections]
    FooterView            -- refresh time + button
  .frame(maxWidth: 500)   -- constrains column width
  .frame(maxWidth: .infinity) -- centers in available space
```

**Refresh mechanism**: `refreshTrigger` (Int) incremented on manual refresh or app foreground. Each section uses `.task(id: refreshTrigger)` to reload data.

**Sports loading**: `SportsDataStore` is `@State` on ContentView. Shows `LoadingDotsView` placeholders until `hasLoadedOnce` is true, then conditionally shows sections that have data.

#### Shared Components

- **`DashboardSection`** -- reusable section wrapper with title bar (blue title, green record, dim subtitle), border lines, content padding
- **`GameCardContainer`** -- card with "┌ LABEL" header, used for individual games
- **`ScoreBarView`** -- horizontal bar chart proportional to score, uses GeometryReader
- **`ScoreRow`** -- team abbr (34pt) + score bar + score number (34pt)
- **`MatchupView`** -- "TEAM vs OPP / @ Venue" display for upcoming games
- **`FooterView`** -- "refreshed TIME" + "[ refresh ]" button
- **`LoadingDotsView`** -- animated dots using `TimelineView(.periodic(from:by:0.3))`

### Weather Section (`WeatherSection.swift`)

**API**: Open-Meteo (`api.open-meteo.com/v1/forecast`)
- Fetches 2 days (today + tomorrow) in one call
- Morning mode uses day 0, evening mode uses day 1
- Parameters: daily (temp max/min, weathercode, precip probability), hourly (precip, temp)
- Temperature unit: Fahrenheit

**WMO Code Maps**:
- `wmoConditions: [Int: String]` -- weather code to condition name
- `wmoSFSymbols: [Int: (name: String, color: Color)]` -- weather code to SF Symbol + solarized color

**Weather Icon**: `Image(systemName: iconName)` at 36pt, colored with solarized color from `wmoSFSymbols`

**Charts** (Rectangle-based):
- **Temp chart**: Shown when `hourlyTemp.count >= 24`. Slices hours 6-23 (6am-11pm). 8 quantized height levels. Colors: >90 red, >75 orange, >55 magenta, else cyan.
- **Rain chart**: Shown when `hourlyRain.count >= 24` AND any hour 6-23 has >=5% chance. Colors: >60 red, >40 orange, >20 orange, else green.
- **Chart height**: 36pt
- **Label row**: GeometryReader with positioned Text labels at ["6a","9a","12p","3p","6p","9p"], 11pt monospaced

**Deep link**: Opens Carrot Weather app (`carrotweather://`), falls back to weather.com

### Calendar Section (`CalendarSection.swift`)

**API**: EventKit (`EKEventStore`)
- Requests full calendar access
- Fetches events for `dashboardMode.targetDate` (today or tomorrow)
- Sorts: all-day events first, then by start time

**Display**:
- State machine: `.loading` / `.denied` / `.empty` / `.events([])` / `.error(String)`
- Each event has a colored left border (violet=all-day, green=now, cyan=future)
- Current events get "▸ " prefix and highlighted background
- Past events get 0.5 opacity
- Time format: compact ("9AM-10AM" style, strips ":00" and spaces)

**Deep link**: Opens Apple Calendar (`calshow://`)

### Reds Section (`RedsSection.swift`)

Displays Reds games and NL Central standings.

**Game cards**: Three types via `RedsGameType` enum:
- `.final_` -- score bars, W/L/S pitchers, venue
- `.live` -- score bars, inning detail
- `.upcoming` -- matchup view, probable pitchers

**Standings chart**:
- Column headers: W-L, GB
- Each team row: colored abbreviation, proportional bar, record, games back
- Reds row is bold, all teams use their team color
- First-place GB shows in green

**Deep link**: Opens MLB At Bat (`mlbatbat://`), falls back to mlb.com/reds

### ESPN Section (`ESPNSection.swift`)

**`ESPNTeamConfig` struct** defines each team:
- Lakers: NBA, daily mode, team ID 13, violet color
- Dolphins: NFL, weekly mode, team ID 15, cyan color
- UK Basketball: College basketball, weekly mode, team ID 96, blue color
- UK Football: College football, weekly mode, team ID 96, blue color

Game cards: Three types via `ESPNGameInfo` enum (same pattern as Reds but with configurable team colors).

**Deep link**: Opens ESPN/SportsCenter (`sportscenter://`), falls back to ESPN web URL

### Sports Data Store (`SportsDataStore.swift`)

`@Observable` class managing all sports data loading.

**Data properties**:
- `reds: SportsResult<RedsGameType>` -- Reds games
- `redsRecord: String?` -- e.g. "45-32"
- `espnResults: [String: SportsResult<ESPNGameInfo>]` -- keyed by config ID
- `nlCentralStandings: [NLCentralTeam]` -- sorted by division rank
- `hasLoadedOnce: Bool` -- controls loading placeholder display

**`loadAll(mode:)`** -- launches 6 concurrent tasks via `withTaskGroup`:
1. `loadReds(mode:)` -- MLB Stats API, fetches 2 days based on mode
2. `loadNLCentralStandings()` -- MLB Standings API, finds Reds' division dynamically
3-6. `loadESPN(config:mode:)` for each of 4 teams

**MLB Stats API** (`statsapi.mlb.com/api/v1/schedule`):
- Hydrates: probablePitcher, linescore, decisions, team
- Fetches 2 dates: yesterday+today (morning) or today+tomorrow (evening)

**MLB Standings API** (`statsapi.mlb.com/api/v1/standings`):
- Fetches all NL standings (`leagueId=104`)
- Finds the division containing `DashboardConfig.redsId` dynamically
- Team info lookup by ID: `nlCentralInfo: [Int: (color: Color, abbr: String)]`

**ESPN API** (`site.api.espn.com/apis/site/v2/sports/...`):
- Daily mode: fetches 2 specific dates (like MLB)
- Weekly mode: fetches -7 to +7 day range, shows most recent past game + next future game

**Team abbreviation helpers**:
- `mlbTeams: [String: String]` -- full name to abbreviation for all 30 MLB teams
- `mlbAbbr(_:)` -- lookup with `String(name.prefix(3)).uppercased()` fallback

**Error handling pattern** (all catch blocks):
```swift
} catch is CancellationError {
    return
} catch {
    if Task.isCancelled { return }
    // show error
}
```

## Info.plist

- `LSApplicationQueriesSchemes`: mlbatbat, sportscenter, carrotweather
- `NSCalendarsFullAccessUsageDescription`: "Horizon needs access to your calendars..."
- `NSCalendarsUsageDescription`: same

## Font & Typography System

All text uses `.system(design: .monospaced)`:
- Title: 22pt bold, orange, tracking 2
- Section titles: 17pt bold, blue, tracking 1
- Body text: 14pt
- Dim/meta text: 12-13pt
- Chart labels: 11pt
- Records in headers: 13pt, green

## Color Usage Conventions

- **Orange**: greeting, time values, live game details
- **Blue**: section titles
- **Green**: win indicators, records, first-place GB
- **Red**: loss indicators, errors, Reds team color, high temp/rain
- **Cyan**: refresh button, loading dots, mode toggle, future events
- **Violet**: probable pitchers, all-day events
- **Magenta**: weather condition text, mid-range temps
