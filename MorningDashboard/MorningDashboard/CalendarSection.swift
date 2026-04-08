import SwiftUI
import EventKit

private struct CalendarEvent: Identifiable {
    let id = UUID()
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColor: Color

    var timeString: String {
        if isAllDay { return "ALL DAY" }
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return "\(df.string(from: startDate))–\(df.string(from: endDate))"
    }

    var isNow: Bool {
        !isAllDay && startDate <= Date() && endDate > Date()
    }

    var isPast: Bool {
        !isAllDay && endDate < Date()
    }
}

private enum CalendarState {
    case loading
    case denied
    case empty
    case events([CalendarEvent])
    case error(String)
}

struct CalendarSectionView: View {
    let theme: Theme
    let refreshTrigger: Int

    @State private var state: CalendarState = .loading

    var body: some View {
        Button {
            if let url = URL(string: "calshow://") {
                UIApplication.shared.open(url)
            }
        } label: {
            DashboardSection(title: "SCHEDULE", subtitle: "Today", theme: theme) {
                switch state {
                case .loading:
                    Text("loading...")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(theme.fgDim)
                case .denied:
                    Text("Calendar access denied. Enable in Settings > Privacy > Calendars.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(theme.fgDim)
                case .empty:
                    Text("No events today")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(theme.fgDim)
                        .italic()
                case .events(let events):
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(events) { event in
                            eventRow(event)
                        }
                    }
                case .error(let msg):
                    Text("✗ \(msg)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Sol.red)
                }
            }
        }
        .buttonStyle(.plain)
        .task(id: refreshTrigger) {
            await loadCalendar()
        }
    }

    @ViewBuilder
    private func eventRow(_ event: CalendarEvent) -> some View {
        let borderColor: Color = event.isAllDay ? Sol.violet : event.isNow ? Sol.green : Sol.cyan

        HStack(spacing: 0) {
            Rectangle()
                .fill(borderColor)
                .frame(width: 3)
                .padding(.trailing, 10)

            Group {
                if event.isNow {
                    Text("▸ ").foregroundColor(Sol.green).bold() +
                    Text(event.timeString).foregroundColor(Sol.yellow).bold() +
                    Text(": ").foregroundColor(theme.fgDim) +
                    Text(event.title).foregroundColor(theme.fgEmphasis)
                } else {
                    Text(event.timeString).foregroundColor(Sol.yellow).bold() +
                    Text(": ").foregroundColor(theme.fgDim) +
                    Text(event.title).foregroundColor(theme.fgEmphasis)
                }
            }
            .font(.system(size: 14, design: .monospaced))
            .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .opacity(event.isPast ? 0.5 : 1.0)
        .background(event.isNow ? theme.bgHighlight : Color.clear)
    }

    private func loadCalendar() async {
        let store = EKEventStore()

        do {
            let granted = try await store.requestFullAccessToEvents()
            guard granted else {
                state = .denied
                return
            }
        } catch {
            state = .error(error.localizedDescription)
            return
        }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else {
            state = .error("Could not compute end of day")
            return
        }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        let events = ekEvents.map { ev in
            CalendarEvent(
                title: ev.title ?? "Untitled",
                startDate: ev.startDate,
                endDate: ev.endDate,
                isAllDay: ev.isAllDay,
                calendarColor: Color(cgColor: ev.calendar.cgColor)
            )
        }
        .sorted { a, b in
            if a.isAllDay && !b.isAllDay { return true }
            if !a.isAllDay && b.isAllDay { return false }
            return a.startDate < b.startDate
        }

        if events.isEmpty {
            state = .empty
        } else {
            state = .events(events)
        }
    }
}
