# Horizon App - Conversation History & Development Log

## Overview

Horizon (originally "Morning Dashboard") is a personal iOS dashboard app built in SwiftUI with a Solarized terminal aesthetic. It shows weather, calendar events, and sports scores for the owner's favorite teams. The app was originally a PWA, then rebuilt as a native iOS app.

## Owner Preferences & Design Philosophy

- **Terminal/TUI aesthetic** is core to the identity -- monospaced fonts, box-drawing characters, solarized colors
- The owner values **conciseness** -- shorter is better, don't over-engineer
- Prefers **simple git commands** over complex tooling when possible
- Likes clean, dense information displays -- no wasted space
- Uses the app on a single iPhone with iOS 26
- Wants to expand to **iPad (Mini)** and potentially **Mac**
- Location: Prospect, KY (lat 38.40, lon -85.61, timezone America/New_York)
- Teams: Cincinnati Reds (MLB), LA Lakers (NBA), Miami Dolphins (NFL), Kentucky Wildcats (basketball + football)

## Development Timeline

### Phase 1: PWA to Native iOS

The app started as a Progressive Web App, then was rebuilt as a native SwiftUI iOS app. The native version maintained the same TUI-style visual design.

### Phase 2: Core Features Built

- Weather section using Open-Meteo API with hourly temp and rain charts
- Calendar section using EventKit with color-coded events
- Sports sections: Reds (MLB Stats API), Lakers/Dolphins/UK (ESPN API)
- Evening mode that auto-switches at 3pm, shows tomorrow's weather/calendar
- Deep links to native apps (MLB At Bat, ESPN, Carrot Weather, Calendar)
- Loading animations with bouncing dots
- App icons (light and dark variants)

### Phase 3: Chart Evolution (Important Context)

The weather charts went through **4+ iterations** -- this is important context for future work:

1. **HStack per column** -- original approach, worked but spacing issues
2. **Concatenated Text** with block characters (▁▂▃▄▅▆▇█) -- alignment issues, "12p" label wrapped
3. **Larger font size** (14pt -> 24pt) -- made labels comically large since bars and labels shared the same font
4. **Rectangle-based bars** (FINAL) -- `HStack(spacing: 0)` with Rectangle views, independent label sizing via GeometryReader. This is the current implementation and works well.

**Key lesson**: The bar chart and its labels need independent sizing. Don't try to make them share a font size or use the same text-based rendering approach.

### Phase 4: Standings & Score Fixes

- **Standings abbreviations were wrong** -- the `nlCentralColors` dict was keyed by full team name ("Cincinnati Reds") but the MLB API returned just mascot names ("Reds"). Fixed by switching to **team ID-based lookup** (`nlCentralInfo: [Int: (color: Color, abbr: String)]`).
- **3-digit scores wrapped** -- `ScoreRow` used `frame(width: 24)` which was too narrow for scores like 119. Fixed by widening to `frame(width: 34)`.
- **Column headers and colorful records** added to standings chart

### Phase 5: Cancellation Flash Fix

`URLSession` throws `URLError(.cancelled)` when a task is cancelled, which is NOT caught by `catch is CancellationError`. This caused a brief error flash on every refresh. Fixed by adding `if Task.isCancelled { return }` in every generic `catch` block across all data-loading functions (7 total catch blocks in WeatherSection, CalendarSection, SportsDataStore).

### Phase 6: SF Symbols for Weather

Replaced text emoji weather icons with SF Symbols styled in solarized colors. The `wmoSFSymbols` dictionary maps WMO weather codes to `(name: String, color: Color)` tuples. Displayed via `Image(systemName:)` at 36pt.

### Phase 7: AI Briefing (Added then Removed)

Built a full on-device AI briefing section using Apple Foundation Models (`FoundationModels` framework, iOS 26). It collected data from weather, calendar, and sports, then generated a summary styled as Jeeves from P.G. Wodehouse. Went through several personality iterations:
1. Too formal/archaic
2. Added dry humor
3. Toned down archaic language
4. Used a detailed Jeeves personality document

**The owner ultimately removed this feature**, saying "I don't think it adds enough benefit for the complexity." The `SummarySection.swift` file was deleted and all references removed. The deployment target was bumped to 26.0 during this experiment and stayed there.

### Phase 8: Deep Link Fix

The MLB and ESPN sections used plain `https://` web URLs which opened Safari instead of the native apps. Fixed by:
- Adding `openLink(appScheme:webURL:)` helper that tries custom URL scheme first via `canOpenURL`, falls back to web
- Adding `LSApplicationQueriesSchemes` to Info.plist (required for `canOpenURL`)
- Schemes: `mlbatbat://` (MLB), `sportscenter://` (ESPN), `carrotweather://` (weather)

### Phase 9: Global Rename

Renamed everything from "MorningDashboard" to "Horizon":
- Directories, xcodeproj, Swift entry point, target name, product name
- Bundle identifier changed from `com.joshdbmorningdashboard.app` to `com.joshdb.horizon`
- Info.plist calendar description updated
- Zero references to "MorningDashboard" remain

## Pending / Next Steps

### iPad & Multi-Platform Support (Agreed Direction)

The owner wants iPad support (especially iPad Mini) and potentially Mac. The agreed approach is a **reflow layout** like a tiling window manager:

- Title bar and footer stay full-width
- Dashboard sections flow into columns via `LazyVGrid` with adaptive sizing (~340pt min per column)
- iPhone portrait: 1 column (current layout)
- iPad portrait / iPhone landscape: 2 columns
- iPad landscape / Mac: 2-3 columns
- Each section keeps its terminal card style
- SwiftUI picks column count automatically -- no per-device breakpoints

See the separate `horizon-ipad-reflow-plan.md` for full implementation details.

### Separate GitHub Repo

The owner created https://github.com/drjoshbrock/Horizon.git but the code hasn't been pushed there yet (auth issues in cloud environment). The code currently lives on branch `claude/iphone-app-morning-dashboard-WV1eA` in the `drjoshbrock/tools` repo.

## Things That Did NOT Work (Avoid Repeating)

1. **Text-based spark line charts** with block characters -- alignment and sizing issues across different contexts
2. **Shared font size for chart bars and labels** -- they need independent sizing
3. **Name-based team lookups** for MLB standings -- API returns inconsistent names, use team IDs
4. **`catch is CancellationError`** alone -- doesn't catch `URLError(.cancelled)`, need `Task.isCancelled` check
5. **MCP push_files to repos outside the configured list** -- restricted by session config
6. **git push over HTTPS/SSH** in cloud Claude Code -- no auth available
7. **On-device AI briefing** -- fun experiment but the owner felt it didn't add enough value for the complexity
