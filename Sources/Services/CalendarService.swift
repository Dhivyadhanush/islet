import AppKit
import EventKit

/// Today's calendar, read locally. Access is requested only when the user asks
/// for it (the calendar pane or settings), never silently at launch.
@MainActor
final class CalendarService: ObservableObject {
    struct EventItem: Identifiable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let calendarName: String
        let location: String?
        let color: NSColor
        let url: URL?
    }

    @Published private(set) var events: [EventItem] = []
    @Published private(set) var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private let store = EKEventStore()
    private var timer: Timer?
    private var observer: NSObjectProtocol?

    var nextEvent: EventItem? {
        let now = Date()
        return events.first { $0.end > now }
    }

    func start() {
        status = EKEventStore.authorizationStatus(for: .event)
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }

        if status == .fullAccess { refresh() }

        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.status = EKEventStore.authorizationStatus(for: .event)
                if granted { self.refresh() }
            }
        }
    }

    /// Used by `--snapshot` to render the design with sample events.
    func previewSeed(status: EKAuthorizationStatus, events: [EventItem]) {
        self.status = status
        self.events = events
    }

    func refresh() {
        status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            events = []
            return
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let found = store.events(matching: predicate)
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.startDate < rhs.startDate
            }
            .map { event in
                EventItem(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title?.isEmpty == false ? event.title : "Untitled event",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarName: event.calendar?.title ?? "",
                    location: event.location,
                    color: event.calendar?.color ?? .systemGray,
                    url: event.url
                        ?? Self.firstURL(in: event.notes)
                        ?? Self.firstURL(in: event.location)
                )
            }
        events = found
    }

    private static func firstURL(in text: String?) -> URL? {
        guard let text, !text.isEmpty else { return nil }
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.url
    }
}
