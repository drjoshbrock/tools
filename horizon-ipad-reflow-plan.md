# Horizon App - Adaptive Reflow Layout Plan

## Goal

Make Horizon a universal app that adapts gracefully to any screen size without manual per-device layout work. The same code should handle iPhone portrait, iPhone landscape, iPad Mini, iPad Pro, and eventually Mac -- with the terminal/tiling window manager aesthetic preserved.

## Design Concept: Tiled Terminal Panes

The dashboard sections (weather, calendar, sports) are naturally independent modules. On narrow screens they stack vertically (current behavior). On wider screens they flow into multiple columns, like tiled panes in tmux or a tiling window manager. This fits the terminal aesthetic perfectly.

```
iPhone portrait (1 col)     iPad portrait (2 col)      iPad landscape / Mac (2-3 col)
┌──────────────┐            ┌──────────┬──────────┐    ┌────────┬────────┬────────┐
│  TITLE BAR   │            │     TITLE BAR       │    │       TITLE BAR          │
├──────────────┤            ├──────────┬──────────┤    ├────────┬────────┬────────┤
│   WEATHER    │            │ WEATHER  │ SCHEDULE │    │WEATHER │SCHEDULE│  REDS  │
├──────────────┤            ├──────────┼──────────┤    ├────────┼────────┼────────┤
│   SCHEDULE   │            │  REDS    │ LAKERS   │    │ LAKERS │DOLPHINS│UK BBALL│
├──────────────┤            ├──────────┼──────────┤    ├────────┼────────┼────────┤
│    REDS      │            │ DOLPHINS │ UK BBALL │    │UK FBALL│        │        │
├──────────────┤            ├──────────┼──────────┤    ├────────┴────────┴────────┤
│   LAKERS     │            │ UK FBALL │          │    │         FOOTER           │
├──────────────┤            ├──────────┴──────────┤    └─────────────────────────-┘
│  DOLPHINS    │            │       FOOTER        │
├──────────────┤            └─────────────────────┘
│  UK BBALL    │
├──────────────┤
│  UK FBALL    │
├──────────────┤
│    FOOTER    │
└──────────────┘
```

## Implementation Approach

### SwiftUI `LazyVGrid` with Adaptive Columns

The core change is replacing the current `VStack` of sections with a `LazyVGrid` using adaptive column sizing:

```swift
let columns = [GridItem(.adaptive(minimum: 340, maximum: 500))]

ScrollView {
    VStack(spacing: 0) {
        TitleBarView(theme: theme, refreshTrigger: refreshTrigger)

        LazyVGrid(columns: columns, spacing: 0) {
            WeatherSectionView(theme: theme, refreshTrigger: refreshTrigger)
            CalendarSectionView(theme: theme, refreshTrigger: refreshTrigger)
            // ... sports sections
        }

        FooterView(theme: theme, refreshTime: refreshTime) { ... }
    }
}
```

- **Minimum column width**: ~340pt (ensures each section has enough room for score bars, charts, etc.)
- **Maximum column width**: ~500pt (prevents sections from getting too wide on large screens)
- SwiftUI automatically determines the column count based on available width:
  - iPhone portrait (~390pt): 1 column
  - iPhone landscape (~844pt): 2 columns
  - iPad Mini portrait (~744pt): 2 columns
  - iPad Mini landscape (~1024pt): 2-3 columns
  - iPad Pro landscape (~1366pt): 3 columns

### What Stays Full-Width

- **TitleBarView** -- greeting + date, always spans the full width above the grid
- **FooterView** -- refresh time + button, always spans full width below the grid
- **Mode toggle bar** -- bottom safe area inset, full width

### What Goes Into the Grid

Each of these becomes a grid item:
1. WeatherSectionView
2. CalendarSectionView
3. RedsSectionView (with standings)
4. ESPNSectionView (Lakers)
5. ESPNSectionView (Dolphins)
6. ESPNSectionView (UK Basketball)
7. ESPNSectionView (UK Football)

### Section Card Treatment

Each section should be treated as an independent card within the grid:
- Add `overlay(Rectangle().stroke(theme.border, lineWidth: 1))` to each section (currently only on the outer VStack)
- Remove the current outer border from the VStack
- Sections become self-contained bordered panes
- Use grid spacing or padding between cards (e.g., 1pt gap to maintain the terminal border-touching look, or small padding for a more separated card layout)

### Key Considerations

1. **Section height variance**: Grid items in the same row will be the same height. Weather with charts will be taller than a simple "no games" sports section. This is fine -- the shorter section will have empty space at the bottom, like a terminal pane that isn't fully filled.

2. **Loading state**: The loading placeholders need to work within grid items too. Each placeholder section should maintain its bordered card appearance.

3. **Conditional sections**: Currently, sports sections are hidden when they have no data (after loading). In a grid, this could cause layout shifts. Consider always showing sections with a "No recent games" message instead, so the grid is stable.

4. **Outer border removal**: The current `overlay(Rectangle().stroke(theme.border, lineWidth: 1))` on the outer VStack should be removed. Each section card handles its own border.

5. **maxWidth constraint**: Remove the `.frame(maxWidth: 500)` on the outer VStack. The grid's `maximum: 500` on each column handles this per-section instead.

6. **Scroll direction**: Keep vertical scrolling. On wider screens with 2-3 columns, the page will be shorter but still scrollable.

7. **Mac Catalyst / macOS**: The same grid approach works for Mac via Mac Catalyst or native SwiftUI for macOS. The `openLink` function uses `UIApplication.shared` which would need `#if os(iOS)` guards for macOS support.

### Files to Modify

- **`ContentView.swift`** -- Replace VStack with LazyVGrid, remove outer maxWidth/border, adjust section wrapping
- **`DashboardSection`** -- May need border adjustment to be self-contained
- **`WeatherSection.swift`** -- May need chart minimum width considerations
- **`RedsSection.swift`** -- Standings chart uses GeometryReader, should adapt fine

### Minimal Changes Required

The sections themselves (WeatherSectionView, CalendarSectionView, etc.) should not need internal layout changes. They already use `frame(maxWidth: .infinity)` patterns that will adapt to whatever width the grid gives them. The change is primarily in `ContentView.swift`'s main layout structure.

### Testing Checklist

- [ ] iPhone portrait: single column, looks identical to current
- [ ] iPhone landscape: 2 columns, sections fill available width
- [ ] iPad Mini portrait: 2 columns
- [ ] iPad Mini landscape: 2-3 columns
- [ ] iPad Pro portrait: 2 columns (sections at max 500pt)
- [ ] iPad Pro landscape: 3 columns
- [ ] Loading state: placeholders appear correctly in grid
- [ ] Conditional sections: no jarring layout shifts
- [ ] Weather charts render correctly at different column widths
- [ ] Score bars and standings charts adapt to width
- [ ] Mode toggle bar stays full-width at bottom
- [ ] Refresh works correctly across all layouts
- [ ] Tapping sections still opens correct deep links
