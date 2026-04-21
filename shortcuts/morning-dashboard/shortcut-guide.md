# Morning Dashboard - iPhone Shortcut Build Guide

Build this shortcut in the Apple Shortcuts app on your iPhone. It gathers weather,
calendar, and sports data, assembles an HTML page, and displays it via Quick Look.

## Overview

| Section       | Data Source                        | Shortcut Action              |
|---------------|-------------------------------------|------------------------------|
| Weather       | CARROT Weather                     | CARROT Weather actions       |
| Calendar      | iOS Calendars                      | Find Calendar Events         |
| Reds          | MLB Stats API                      | Get Contents of URL          |
| Dolphins      | ESPN API                           | Get Contents of URL          |
| Lakers        | ESPN API                           | Get Contents of URL          |
| UK Basketball | ESPN API                           | Get Contents of URL          |
| UK Football   | ESPN API                           | Get Contents of URL          |

## Prerequisites

- **CARROT Weather** app installed with Shortcuts support enabled
- **Calendars** configured on your iPhone (work + personal)
- Internet connection for API calls

---

## Step-by-Step Shortcut Actions

### PHASE 1: Date Setup

#### Action 1: Date — Current Date
- Format: Custom — `EEEE, MMM d`
- Set variable: `CurrentDateFormatted`

#### Action 2: Date — Current Date
- Format: Custom — `h:mm a`
- Set variable: `CurrentTime`

#### Action 3: Date — Current Date
- Format: Custom — `yyyy-MM-dd`
- Set variable: `TodayISO`

#### Action 4: Date — Current Date
- Format: None (keep as Date object)
- **Adjust Date**: Subtract 1 day
- Set variable: `Yesterday`

#### Action 5: Format Date — `Yesterday`
- Format: Custom — `yyyy-MM-dd`
- Set variable: `YesterdayISO`

#### Action 6: Format Date — `Yesterday`
- Format: Custom — `yyyyMMdd`
- Set variable: `YesterdayESPN`

#### Action 7: Date — Current Date
- Format: Custom — `yyyyMMdd`
- Set variable: `TodayESPN`

---

### PHASE 2: Weather (CARROT Weather)

#### Action 8: Get Current Weather (CARROT Weather)
- Location: Current Location (or set to Prospect, KY)
- Save to variable: `CurrentWeather`

#### Action 9: Get value from `CurrentWeather`
- Get: Temperature
- Set variable: `WeatherTemp`

#### Action 10: Get value from `CurrentWeather`
- Get: Condition
- Set variable: `WeatherCondition`

#### Action 11: Get Daily Forecast (CARROT Weather)
- Location: Current Location (or Prospect, KY)
- Number of days: 1
- Save to variable: `DailyForecast`

#### Action 12: Get value from `DailyForecast`
- Get: High Temperature
- Set variable: `WeatherHigh`

#### Action 13: Get value from `DailyForecast`
- Get: Low Temperature
- Set variable: `WeatherLow`

#### Action 14: Get value from `DailyForecast`
- Get: Precipitation Chance (%)
- Set variable: `WeatherPrecipChance`

#### Action 15: Get value from `DailyForecast`
- Get: Summary / Description
- Set variable: `WeatherSummary`

#### Action 16: Get Hourly Forecast (CARROT Weather)
- Location: Current Location (or Prospect, KY)
- Number of hours: 24
- Save to variable: `HourlyForecast`

#### Action 17: Build rain chart (Text action)

This is the trickiest part. You need to iterate through the hourly forecast
and build a bar chart string. Use a **Repeat with Each** loop over `HourlyForecast`:

```
For each hour in HourlyForecast:
  Get Hour (format "H") from Repeat Item's Date
  If Hour >= 6 AND Hour <= 23:
    Get Precipitation Chance from Repeat Item
    If PrecipChance > 60:  append █ (or ▇▆ based on value)
    Else if PrecipChance > 40: append ▅▄
    Else if PrecipChance > 20: append ▃▂
    Else: append ▁ or space
    Append result to variable RainChartBars
```

**Simplified alternative**: Skip the per-character loop. Instead, just display
the precipitation chance as a number for each 3-hour block:

```
Text action:
6a:[Hour6Precip]% 9a:[Hour9Precip]% 12p:[Hour12Precip]% 3p:[Hour15Precip]% 6p:[Hour18Precip]% 9p:[Hour21Precip]%
```

Set variable: `RainChart`

#### Action 18: Weather icon mapping (Text action)

Use an **If** chain or **Choose from Menu** to map CARROT's condition to an emoji:

| Condition contains | Icon |
|-------------------|------|
| Clear / Sunny     | ☀️   |
| Partly            | ⛅    |
| Cloudy / Overcast | ☁️   |
| Rain / Drizzle    | 🌧️   |
| Thunder           | ⛈️   |
| Snow              | 🌨️   |
| Fog               | 🌫️   |
| Default           | 🌤️   |

Set variable: `WeatherIcon`

---

### PHASE 3: Calendar

#### Action 19: Find Calendar Events
- Start Date: Start of Today
- End Date: End of Today
- Sort by: Start Date (ascending)
- Save to variable: `TodayEvents`

#### Action 20: Build calendar HTML

Use **Repeat with Each** over `TodayEvents`:

```
For each event:
  Get Title → EventTitle
  Get Start Date, format "h:mm a" → EventStart
  Get End Date, format "h:mm a" → EventEnd
  Get Calendar → EventCalendar

  Text action:
  <div class="cal-event">
    <div class="cal-event-title">[EventTitle]</div>
    <div class="cal-event-time">[EventStart] – [EventEnd]</div>
    <div class="cal-event-cal">[EventCalendar]</div>
  </div>

  Append to variable: CalendarHTML
```

If `TodayEvents` count = 0, set `CalendarHTML` to:
```html
<span class="cal-none">No events today</span>
```

---

### PHASE 4: Sports — Cincinnati Reds (MLB API)

#### Action 21: Get Contents of URL (Yesterday's Reds game)
- URL: `https://statsapi.mlb.com/api/v1/schedule?teamId=113&date=[YesterdayISO]&sportId=1&hydrate=probablePitcher,linescore,decisions,team`
- Method: GET
- Save to variable: `RedsYesterday`

#### Action 22: Get Contents of URL (Today's Reds game)
- URL: `https://statsapi.mlb.com/api/v1/schedule?teamId=113&date=[TodayISO]&sportId=1&hydrate=probablePitcher,linescore,decisions,team`
- Method: GET
- Save to variable: `RedsToday`

#### Action 23: Get Contents of URL (Reds upcoming week)
- URL: `https://statsapi.mlb.com/api/v1/schedule?teamId=113&startDate=[TodayISO]&endDate=[+7 days ISO]&sportId=1&hydrate=probablePitcher,team`
- Method: GET
- Save to variable: `RedsUpcoming`

#### Action 24: Parse yesterday's Reds game

Navigate the JSON to extract game data:

```
Get Dictionary Value: dates (from RedsYesterday)
  → Get first item
  → Get Dictionary Value: games
    → Get first item → YesterdayGame

Get: teams.home.team.name → HomeTeam
Get: teams.away.team.name → AwayTeam
Get: teams.home.team.id → HomeTeamId
Get: teams.home.score → HomeScore
Get: teams.away.score → AwayScore
Get: status.detailedState → GameStatus

If HomeTeamId = 113:
  RedsScore = HomeScore, OppScore = AwayScore, OppName = AwayTeam
  RedsLocation = "Home"
Else:
  RedsScore = AwayScore, OppScore = HomeScore, OppName = HomeTeam
  RedsLocation = "Away"

If RedsScore > OppScore:
  RedsResult = "WIN" (green)
Else:
  RedsResult = "LOSS" (red)

Also get decisions if available:
Get: decisions.winner.fullName → WinningPitcher
Get: decisions.loser.fullName → LosingPitcher
Get: decisions.save.fullName → SavePitcher (may not exist)
```

#### Action 25: Build yesterday's Reds HTML (Text action)

```html
<div class="game-card">
  <div class="game-card-head">
    <span>YESTERDAY</span>
    <span class="result-[w/l]">[RedsResult]</span>
  </div>
  <div class="game-card-body">
    <div class="score-row">
      <span class="score-team team-cin">CIN</span>
      <div class="score-bar-track"><div class="score-bar-fill" style="width:[RedsBarPct]%;background:var(--red)"></div></div>
      <span class="score-num team-cin">[RedsScore]</span>
    </div>
    <div class="score-row">
      <span class="score-team team-opp">[OppAbbr]</span>
      <div class="score-bar-track"><div class="score-bar-fill" style="width:[OppBarPct]%;background:var(--fg-dim)"></div></div>
      <span class="score-num team-opp">[OppScore]</span>
    </div>
    <div class="game-meta">
      W: <span class="pitcher">[WinningPitcher]</span> ·
      L: <span class="pitcher">[LosingPitcher]</span>
    </div>
  </div>
</div>
```

If no game yesterday, use:
```html
<div class="game-card">
  <div class="game-card-head"><span>YESTERDAY</span></div>
  <div class="game-card-body"><span class="none">No game</span></div>
</div>
```

Set variable: `RedsYesterdayHTML`

#### Action 26: Parse today's Reds game
Same pattern as Action 24, but for today's game. Check status:
- If "Final" or "Game Over" → show final score
- If "In Progress" → show live score with inning
- If "Scheduled" / "Pre-Game" → show matchup with time and probable pitchers

Set variable: `RedsTodayHTML`

#### Action 27: Parse upcoming Reds games

Loop through `RedsUpcoming.dates` array (skip today):

```
For each date entry:
  Get: date → GameDate
  Get: games[0].teams.home.team.name / away.team.name → determine opponent
  Get: games[0].gameDate → format to "EEE M/d h:mm a"

  Append row to table:
  <tr><td>[GameDateShort]</td><td>vs/@ [OppAbbr]</td><td>[GameTime]</td></tr>
```

Set variable: `RedsUpcomingHTML`

#### Action 28: Combine Reds HTML (Text action)

```
[RedsYesterdayHTML]
[RedsTodayHTML]
<div class="game-card">
  <div class="game-card-head"><span>UPCOMING</span></div>
  <div class="game-card-body">
    <table class="upcoming-table">[RedsUpcomingHTML]</table>
  </div>
</div>
```

Set variable: `RedsHTML`

---

### PHASE 5: Sports — Miami Dolphins (ESPN API)

ESPN team ID for Dolphins: **15**

#### Action 29: Get Contents of URL (Dolphins scoreboard — yesterday)
- URL: `https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?dates=[YesterdayESPN]`
- Save to variable: `NFLYesterday`

#### Action 30: Get Contents of URL (Dolphins scoreboard — today)
- URL: `https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?dates=[TodayESPN]`
- Save to variable: `NFLToday`

#### Action 31: Get Contents of URL (Dolphins team schedule)
- URL: `https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/15/schedule`
- Save to variable: `DolphinsSchedule`

#### Action 32: Parse Dolphins games

For yesterday/today scoreboard data, find the Dolphins game:

```
Get: events (array) from NFLYesterday
Repeat with Each event:
  Get: competitions[0].competitors (array)
  Repeat with Each competitor:
    Get: team.id
    If team.id = "15":
      → Found Dolphins game
      Get other competitor for opponent info
      Get: score, winner, team.abbreviation
      Get: status.type.completed, status.type.description
      Build score card HTML (same pattern as Reds)
```

For upcoming games from the schedule endpoint:
```
Get: events (array) from DolphinsSchedule
Filter to events where date > today AND date < today+7
For each upcoming event:
  Get: name (e.g., "Miami Dolphins at Buffalo Bills")
  Get: date → format to "EEE M/d h:mm a"
  Build table row
```

Set variable: `DolphinsHTML`

**NFL off-season note**: During the off-season (Feb–Aug), there will be no
recent/upcoming games. Handle this with a fallback:
```html
<span class="none">Off-season — no games scheduled</span>
```

---

### PHASE 6: Sports — LA Lakers (ESPN API)

ESPN team ID for Lakers: **13**

#### Action 33: Get Contents of URL (NBA scoreboard — yesterday)
- URL: `https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates=[YesterdayESPN]`
- Save to variable: `NBAYesterday`

#### Action 34: Get Contents of URL (NBA scoreboard — today)
- URL: `https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates=[TodayESPN]`
- Save to variable: `NBAToday`

#### Action 35: Get Contents of URL (Lakers team schedule)
- URL: `https://site.api.espn.com/apis/site/v2/sports/basketball/nba/teams/13/schedule`
- Save to variable: `LakersSchedule`

#### Action 36: Parse Lakers games

Same pattern as Dolphins (Action 32), but:
- ESPN team ID to match: `"13"`
- Team class: `team-lal`
- Color: `var(--violet)`

Search yesterday and today scoreboards for Lakers game.
Parse upcoming from schedule endpoint.

Set variable: `LakersHTML`

---

### PHASE 7: Sports — UK Men's Basketball (ESPN API)

ESPN team ID for Kentucky Wildcats (MBB): **96**

#### Action 37: Get Contents of URL (NCAAM scoreboard — yesterday)
- URL: `https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard?dates=[YesterdayESPN]&groups=50`
- Save to variable: `NCAAMYesterday`

#### Action 38: Get Contents of URL (NCAAM scoreboard — today)
- URL: `https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard?dates=[TodayESPN]&groups=50`
- Save to variable: `NCAAMToday`

#### Action 39: Get Contents of URL (UK Basketball schedule)
- URL: `https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/teams/96/schedule`
- Save to variable: `UKBBSchedule`

#### Action 40: Parse UK Basketball games

Same ESPN parsing pattern:
- ESPN team ID to match: `"96"`
- Team class: `team-uk`
- Color: `var(--blue)`
- Team abbreviation: `UK`

**College basketball off-season note**: Season runs Nov–Apr (with March Madness).
During off-season, show fallback message.

Set variable: `UKBasketballHTML`

---

### PHASE 8: Sports — UK Football (ESPN API)

ESPN team ID for Kentucky Wildcats (Football): **96**

#### Action 41: Get Contents of URL (NCAAF scoreboard — yesterday)
- URL: `https://site.api.espn.com/apis/site/v2/sports/football/college-football/scoreboard?dates=[YesterdayESPN]&groups=80`
- Save to variable: `NCAAFYesterday`

#### Action 42: Get Contents of URL (NCAAF scoreboard — today)
- URL: `https://site.api.espn.com/apis/site/v2/sports/football/college-football/scoreboard?dates=[TodayESPN]&groups=80`
- Save to variable: `NCAAFToday`

#### Action 43: Get Contents of URL (UK Football schedule)
- URL: `https://site.api.espn.com/apis/site/v2/sports/football/college-football/teams/96/schedule`
- Save to variable: `UKFBSchedule`

#### Action 44: Parse UK Football games

Same ESPN parsing pattern:
- ESPN team ID to match: `"96"`
- Team class: `team-uk`
- Color: `var(--blue)`
- Team abbreviation: `UK`

**College football off-season note**: Season runs Aug–Jan (with bowl games).
During off-season, show fallback message.

Set variable: `UKFootballHTML`

---

### PHASE 9: Assemble Final HTML

#### Action 45: Text (build full HTML page)

Use a single large **Text** action. Copy the content from `template.html` and replace
each placeholder with the corresponding Shortcuts variable:

| Placeholder              | Shortcuts Variable     |
|--------------------------|------------------------|
| `CURRENT_DATE`           | `CurrentDateFormatted` |
| `CURRENT_TIME`           | `CurrentTime`          |
| `WEATHER_LOCATION`       | `CurrentWeather` Location or "Prospect, KY" |
| `WEATHER_ICON`           | `WeatherIcon`          |
| `WEATHER_CONDITION`      | `WeatherCondition`     |
| `WEATHER_HIGH`           | `WeatherHigh`          |
| `WEATHER_LOW`            | `WeatherLow`           |
| `WEATHER_PRECIP_PCT`     | `WeatherPrecipChance`  |
| `WEATHER_SUMMARY`        | `WeatherSummary`       |
| `RAIN_CHART_BARS`        | `RainChart`            |
| `CALENDAR_EVENTS_HTML`   | `CalendarHTML`         |
| `REDS_HTML`              | `RedsHTML`             |
| `DOLPHINS_HTML`          | `DolphinsHTML`         |
| `LAKERS_HTML`            | `LakersHTML`           |
| `UK_BASKETBALL_HTML`     | `UKBasketballHTML`     |
| `UK_FOOTBALL_HTML`       | `UKFootballHTML`       |

Set variable: `FinalHTML`

#### Action 46: Quick Look

- Input: `FinalHTML`
- The HTML renders in a WebView-style preview

---

## API Reference

### MLB Stats API (Reds)

**Base URL**: `https://statsapi.mlb.com/api/v1`

**Schedule endpoint**:
```
/schedule?teamId=113&date=YYYY-MM-DD&sportId=1&hydrate=probablePitcher,linescore,decisions,team
```

**Key JSON paths**:
```
dates[0].games[0].teams.home.team.id        → integer (113 = Reds)
dates[0].games[0].teams.home.team.name      → "Cincinnati Reds"
dates[0].games[0].teams.home.score          → integer
dates[0].games[0].teams.away.score          → integer
dates[0].games[0].status.detailedState      → "Final", "In Progress", "Scheduled"
dates[0].games[0].decisions.winner.fullName  → pitcher name
dates[0].games[0].decisions.loser.fullName   → pitcher name
dates[0].games[0].decisions.save.fullName    → pitcher name (may not exist)
dates[0].games[0].gameDate                   → ISO 8601 datetime
dates[0].games[0].venue.name                 → stadium name
dates[0].games[0].teams.home.probablePitcher.fullName → pitcher name
dates[0].games[0].teams.away.probablePitcher.fullName → pitcher name
```

**Team abbreviation lookup** (common opponents):
```
CIN=Reds, STL=Cardinals, CHC=Cubs, MIL=Brewers, PIT=Pirates
ATL=Braves, NYM=Mets, PHI=Phillies, WSH=Nationals, MIA=Marlins
LAD=Dodgers, SF=Giants, SD=Padres, ARI=D-backs, COL=Rockies
NYY=Yankees, BOS=Red Sox, TB=Rays, TOR=Blue Jays, BAL=Orioles
MIN=Twins, CLE=Guardians, CWS=White Sox, DET=Tigers, KC=Royals
HOU=Astros, TEX=Rangers, SEA=Mariners, LAA=Angels, OAK=Athletics
```

### ESPN API (Dolphins, Lakers, UK Basketball, UK Football)

**Base URL**: `https://site.api.espn.com/apis/site/v2/sports`

**Scoreboard endpoints** (use with `?dates=YYYYMMDD`):
```
/football/nfl/scoreboard
/basketball/nba/scoreboard
/basketball/mens-college-basketball/scoreboard
/football/college-football/scoreboard
```

**Team schedule endpoints** (returns season schedule with results):
```
/football/nfl/teams/15/schedule           → Dolphins
/basketball/nba/teams/13/schedule         → Lakers
/basketball/mens-college-basketball/teams/96/schedule  → UK Basketball
/football/college-football/teams/96/schedule            → UK Football
```

**Key JSON paths (scoreboard)**:
```
events[].competitions[0].competitors[].team.id            → string ID
events[].competitions[0].competitors[].team.abbreviation  → "MIA", "LAL", etc.
events[].competitions[0].competitors[].team.displayName   → full name
events[].competitions[0].competitors[].score              → string score
events[].competitions[0].competitors[].winner             → boolean
events[].competitions[0].competitors[].homeAway           → "home" or "away"
events[].competitions[0].status.type.completed             → boolean
events[].competitions[0].status.type.description           → "Final", etc.
events[].competitions[0].status.type.state                 → "pre", "in", "post"
events[].competitions[0].status.type.shortDetail           → "Final", "Q3 5:22"
events[].competitions[0].venue.fullName                    → venue name
events[].competitions[0].date                              → ISO 8601 datetime
```

**Key JSON paths (team schedule)**:
```
events[].date              → ISO 8601 datetime
events[].name              → "Team A at Team B"
events[].competitions[0]   → same structure as scoreboard
events[].seasonType.type   → 1=preseason, 2=regular, 3=postseason
```

---

## ESPN Team IDs Quick Reference

| Team                   | Sport | League | ESPN ID |
|------------------------|-------|--------|---------|
| Cincinnati Reds        | MLB   | MLB    | N/A (use MLB API, teamId=113) |
| Miami Dolphins         | NFL   | NFL    | 15      |
| Los Angeles Lakers     | NBA   | NBA    | 13      |
| Kentucky Wildcats BBall| NCAAM | MBB    | 96      |
| Kentucky Wildcats FBall| NCAAF | CFB    | 96      |

---

## Tips for Building in Shortcuts

1. **Test incrementally**: Build and test one section at a time. Start with
   weather + calendar (easiest), then add one sport at a time.

2. **JSON parsing in Shortcuts**: When you use "Get Contents of URL", Shortcuts
   auto-parses JSON into a Dictionary. Use "Get Dictionary Value" with key paths
   like `dates` → then "Get Item from List" (index 1) → then "Get Dictionary Value"
   with key `games`, etc.

3. **Handling missing data**: Wrap each sports section in an **If** check.
   If the API returns no games (empty `dates` array or empty `events` array),
   show the "No game" fallback HTML.

4. **Variable interpolation**: In a Text action, tap the variable button to
   insert any previously set variable inline. This is how you build the HTML
   string with dynamic data.

5. **Automation**: You can set this shortcut to run automatically via
   Shortcuts Automations → Time of Day → e.g., 6:30 AM → Run Shortcut.
   Note: iOS may require you to confirm the automation unless you disable
   "Ask Before Running."

6. **Performance**: The shortcut will make 8–10 API calls. On a good connection
   this takes 3–5 seconds. On cellular it may take longer.

7. **Debugging**: If Quick Look shows raw text instead of rendered HTML, make
   sure the Text action's output is being treated as HTML. You may need to use
   "Make HTML from Rich Text" or save to a file first:
   - Save File: Save `FinalHTML` to a temporary file with `.html` extension
   - Quick Look: Preview the saved file

8. **Saving to Files instead of Quick Look**: As an alternative to Quick Look,
   you can save the HTML to iCloud Drive or On My iPhone, then open it in Safari
   for a better rendering experience:
   - Save File → iCloud Drive/Shortcuts/morning-dashboard.html
   - Open File

9. **CARROT Weather Shortcuts actions**: If CARROT's Shortcuts actions don't
   appear, open CARROT Weather → Settings → ensure Shortcuts integration is
   enabled. The actions should appear as "Get Current Weather", "Get Daily
   Forecast", and "Get Hourly Forecast" under the CARROT Weather section in
   the action picker.

---

## Seasonal Considerations

| Sport          | Season            | Off-season fallback           |
|----------------|-------------------|-------------------------------|
| MLB (Reds)     | Late Mar – Oct    | "Off-season"                  |
| NFL (Dolphins) | Sep – Feb         | "Off-season"                  |
| NBA (Lakers)   | Oct – Jun         | "Off-season"                  |
| NCAAM (UK BBall)| Nov – Apr        | "Off-season"                  |
| NCAAF (UK FBall)| Aug – Jan        | "Off-season"                  |

During off-season for any sport, the schedule endpoints will return empty or
pre-season data. The shortcut should handle this gracefully by showing the
off-season message.
