import SwiftUI
import Observation

extension Color {
    // Each colour has a light and a dark value; dark ones are lighter so they stay readable on dark surfaces.
    static let brand = Color(light: 0x1F6F4A, dark: 0x5DBF8E)
    static let gold = Color(light: 0xC8962B, dark: 0xE2B04F)
    static let noteBlue = Color(light: 0x2F6F9F, dark: 0x6EA9D8)
    /// Text or icons drawn on a solid `brand` fill.
    static let onBrand = Color(light: 0xFFFFFF, dark: 0x06261A)
    /// Text on a gold-tinted chip.
    static let goldText = Color(light: 0x8A6414, dark: 0xE2B04F)
    /// Base of the background wash.
    static let canvas = Color(light: 0xF6F8F5, dark: 0x0D1411)

    /// Halo for key green elements: brand green in dark mode, invisible in light (a glow reads as a smudge on white).
    static let glow = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0x5D / 255, green: 0xBF / 255, blue: 0x8E / 255, alpha: 0.75) : .clear })

    init(light: UInt32, dark: UInt32) {
        func ui(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        self.init(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

struct Item: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var meta: String
    var doneAt: Date?
}

struct Stamp: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case day, focus, focusEnd, note }
    var id = UUID()
    var time: Date
    var label: String
    var note: String
    var kind: Kind

    var color: Color {
        switch kind {
        case .day: .gold
        case .focus, .focusEnd: .brand
        case .note: .noteBlue
        }
    }
}

struct FocusTimer: Codable, Equatable {
    static let block: TimeInterval = 50 * 60
    var task: String
    var startedAt: Date
    var accumulated: TimeInterval = 0
    var runningSince: Date?

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }
}

@MainActor @Observable
final class Planner {
    private struct Snapshot: Codable {
        var items: [Item], stamps: [Stamp], timer: FocusTimer?
        // Optional so data saved before these existed still decodes instead of being replaced by the sample.
        var goals: [Goal]?, history: [String: Double]?, rewards: [Reward]?
        var claimed: Set<String>?, achievements: [Achievement]?
        var day: String?
        var tracker: Tracker?, activities: [Activity]?
        var name: String?
    }

    var items: [Item] { didSet { history[Self.dayKey(.now)] = progress; save() } }
    var stamps: [Stamp] { didSet { save() } }
    var timer: FocusTimer? { didSet { save() } }
    var goals: [Goal] { didSet { save() } }
    /// Checklist completion (0...1) per day, keyed by `dayKey`; written whenever the checklist changes.
    var history: [String: Double] { didSet { save() } }
    var rewards: [Reward] { didSet { save() } }
    var claimed: Set<String> { didSet { save() } }   // "weekKey#rewardID"
    var achievements: [Achievement] { didSet { save() } }
    /// The day the checklist ticks belong to; when it isn't today, `rollOverIfNeeded` clears them.
    var day: String { didSet { save() } }
    var tracker: Tracker { didSet { save() } }
    var activities: [Activity] { didSet { save() } }
    var name: String { didSet { save() } }

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "planner.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let s = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) } ?? Self.sample()
        items = s.items
        stamps = s.stamps
        timer = s.timer
        goals = s.goals ?? []
        history = s.history ?? [:]
        rewards = s.rewards ?? Self.defaultRewards
        claimed = s.claimed ?? []
        achievements = s.achievements ?? []
        tracker = s.tracker ?? Tracker()
        activities = s.activities ?? Self.defaultActivities
        name = s.name ?? ""
        day = s.day ?? Self.dayKey(.now)   // saves from before this field are treated as today's
        rollOverIfNeeded()
    }

    private func save() {
        let s = Snapshot(items: items, stamps: stamps, timer: timer, goals: goals,
                         history: history, rewards: rewards, claimed: claimed, achievements: achievements, day: day,
                         tracker: tracker, activities: activities, name: name)
        if let data = try? JSONEncoder().encode(s) { defaults.set(data, forKey: Self.key) }
    }

    var doneCount: Int { items.filter { $0.doneAt != nil }.count }
    var progress: Double { items.isEmpty ? 0 : Double(doneCount) / Double(items.count) }
    var nextItem: Item? { items.first { $0.doneAt == nil } }

    func toggle(_ item: Item) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].doneAt = items[i].doneAt == nil ? .now : nil
    }

    func addItem(_ title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        items.append(Item(title: t, meta: "Added today"))
    }

    func stamp(_ label: String, note: String = "", kind: Stamp.Kind, at time: Date = .now) {
        stamps.append(Stamp(time: time, label: label, note: note, kind: kind))
    }

    func startFocus(_ task: String?, at now: Date = .now) {
        endFocus(at: now) // a running block is stamped, never silently dropped
        let t = task?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = t.isEmpty ? "Focus block" : t
        stamp("Focus start", note: name, kind: .focus, at: now)
        timer = FocusTimer(task: name, startedAt: now, runningSince: now)
    }

    func togglePause(at now: Date = .now) {
        guard var t = timer else { return }
        if let since = t.runningSince {
            t.accumulated += now.timeIntervalSince(since)
            t.runningSince = nil
        } else {
            t.runningSince = now
        }
        timer = t
    }

    func endFocus(at now: Date = .now) {
        guard let t = timer else { return }
        let minutes = max(1, Int((t.elapsed(at: now) / 60).rounded()))
        stamp("Focus end", note: "\(t.task) · \(minutes) min", kind: .focusEnd, at: now)
        timer = nil
    }

    private static func sample() -> Snapshot {
        func at(_ h: Int, _ m: Int) -> Date {
            Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: .now) ?? .now
        }
        let items = [
            Item(title: "Morning reading, 20 pages", meta: "Habit", doneAt: at(7, 20)),
            Item(title: "Review Acme cohort notes", meta: "Prep · 15 min", doneAt: at(7, 58)),
            Item(title: "Send invoice to Northwind", meta: "Admin", doneAt: at(8, 15)),
            Item(title: "Deliver Q1 sales training, session 2", meta: "Northwind · 9:00 AM", doneAt: at(9, 42)),
            Item(title: "Follow up with 3 HR heads", meta: "Email · Priya, Daniel, Mei"),
            Item(title: "Draft module 3 of leadership program", meta: "Focus block"),
            Item(title: "Coaching call with Rahul Mehta", meta: "1:30 PM · Zoom"),
            Item(title: "Journal three wins", meta: "Evening"),
        ]
        let stamps = [
            Stamp(time: at(7, 5), label: "Start day", note: "Home office", kind: .day),
            Stamp(time: at(7, 45), label: "Focus start", note: "Acme cohort prep", kind: .focus),
            Stamp(time: at(8, 40), label: "Focus end", note: "55 min", kind: .focusEnd),
            Stamp(time: at(9, 0), label: "Q1 sales training", note: "Northwind, Room 4B", kind: .note),
            Stamp(time: at(9, 48), label: "Focus start", note: "Draft module 3", kind: .focus),
        ]
        let timer = FocusTimer(task: "Draft module 3", startedAt: at(9, 48),
                               accumulated: 24 * 60 + 16, runningSince: .now)
        let cal = Calendar.mondayFirst, today = cal.startOfDay(for: .now)
        var history: [String: Double] = [:]
        for (i, p) in [0.8, 1.0, 0.6, 0.9, 0.7, 1.0, 0.5].enumerated() {
            if let d = cal.date(byAdding: .day, value: -(i + 1), to: today) { history[dayKey(d)] = p }
        }
        history[dayKey(today)] = Double(items.filter { $0.doneAt != nil }.count) / Double(items.count)
        let goal = Goal(title: "Launch my signature leadership program",
                        myWin: "A repeatable offer and steadier income",
                        theirWin: "Managers get a practical playbook for their first year",
                        start: cal.date(byAdding: .month, value: -2, to: today) ?? today, progress: 0.35)
        return Snapshot(items: items, stamps: stamps, timer: timer, goals: [goal], history: history, day: dayKey(.now))
    }
}

extension ShapeStyle where Self == Color {
    static var brand: Color { Color.brand }
    static var gold: Color { Color.gold }
}

struct Goal: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var myWin: String
    var theirWin: String
    var start: Date
    var end: Date
    var progress: Double = 0

    init(title: String, myWin: String, theirWin: String, start: Date = .now, progress: Double = 0) {
        self.title = title; self.myWin = myWin; self.theirWin = theirWin
        self.start = start
        self.end = Calendar.current.date(byAdding: .month, value: 6, to: start) ?? start
        self.progress = progress
    }

    func daysLeft(at now: Date = .now) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: now), to: end).day ?? 0)
    }
    func timeUsed(at now: Date = .now) -> Double {
        let total = end.timeIntervalSince(start)
        return total > 0 ? min(max(now.timeIntervalSince(start) / total, 0), 1) : 1
    }
}

struct Reward: Identifiable, Codable, Equatable {
    var id = UUID()
    var minScore: Int
    var text: String
}

struct Achievement: Identifiable, Codable, Equatable {
    var id = UUID()
    var time: Date
    var text: String
}

extension Calendar {
    static var mondayFirst: Calendar { var c = Calendar.current; c.firstWeekday = 2; return c }
}

extension Planner {
    static let defaultRewards = [
        Reward(minScore: 40, text: "Favourite filter coffee"),
        Reward(minScore: 70, text: "Self-care evening"),
        Reward(minScore: 90, text: "Treat day out"),
    ]

    nonisolated static func dayKey(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// The 7 days (Mon–Sun) of the week `offset` weeks from the one containing `now`.
    func weekDays(offset: Int, now: Date = .now) -> [Date] {
        let cal = Calendar.mondayFirst
        let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
        let monday = cal.date(byAdding: .weekOfYear, value: offset, to: start) ?? start
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    /// nil for days after today.
    func dayProgress(_ d: Date, now: Date = .now) -> Double? {
        let k = Self.dayKey(d), today = Self.dayKey(now)
        return k > today ? nil : k == today ? progress : history[k] ?? 0
    }

    /// Average completion (0–100) over the week's elapsed days; a past week counts all 7.
    func weekScore(offset: Int, now: Date = .now) -> Int {
        let p = weekDays(offset: offset, now: now).compactMap { dayProgress($0, now: now) }
        guard !p.isEmpty else { return 0 }
        return Int((p.reduce(0, +) / Double(offset < 0 ? 7 : p.count) * 100).rounded())
    }

    func weekKey(offset: Int, now: Date = .now) -> String { Self.dayKey(weekDays(offset: offset, now: now)[0]) }

    func toggleClaim(_ r: Reward, weekKey: String) {
        let k = weekKey + "#" + r.id.uuidString
        if claimed.contains(k) { claimed.remove(k) } else { claimed.insert(k) }
    }

    func achievements(inWeek offset: Int, now: Date = .now) -> [Achievement] {
        let days = weekDays(offset: offset, now: now)
        guard let lo = days.first, let hi = Calendar.current.date(byAdding: .day, value: 7, to: lo) else { return [] }
        return achievements.filter { $0.time >= lo && $0.time < hi }.sorted { $0.time < $1.time }
    }

    func addAchievement(_ text: String) {
        guard !text.trimmed.isEmpty else { return }
        achievements.append(Achievement(time: .now, text: text.trimmed))
    }

    /// Starts a fresh checklist when the day has changed. The finished day's score is already in `history`.
    func rollOverIfNeeded(now: Date = .now) {
        let today = Self.dayKey(now)
        guard day != today else { return }
        history[day] = progress
        day = today
        for i in items.indices { items[i].doneAt = nil }
        history[today] = progress
    }

    /// The timeline shows one day at a time; every stamp stays saved.
    func stamps(on day: Date) -> [Stamp] {
        stamps.filter { Calendar.current.isDate($0.time, inSameDayAs: day) }.sorted { $0.time < $1.time }
    }

    /// Up to two initials from `name`; empty when no name is set.
    var initials: String {
        String(name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
    }

    // MARK: Streak

    /// A day counts toward the streak when at least this share of the checklist was ticked.
    static let streakThreshold = 0.01

    var streak: Int { streak(now: .now) }

    /// Consecutive qualifying days ending today; an unticked today doesn't break it yet.
    func streak(now: Date) -> Int {
        let cal = Calendar.current
        var n = dayProgress(now, now: now).map { $0 >= Self.streakThreshold ? 1 : 0 } ?? 0
        var d = cal.startOfDay(for: now)
        while let prev = cal.date(byAdding: .day, value: -1, to: d),
              (history[Self.dayKey(prev)] ?? 0) >= Self.streakThreshold {
            n += 1
            d = prev
        }
        return n
    }

    // MARK: 30-day tracker

    /// The tracker's 30 days, from its start date.
    func trackerDays() -> [Date] {
        (0..<30).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: tracker.start)) }
    }

    func toggleTracked(_ d: Date, now: Date = .now) {
        let k = Self.dayKey(d)
        guard k <= Self.dayKey(now) else { return }   // future days can't be marked
        if tracker.done.contains(k) { tracker.done.remove(k) } else { tracker.done.insert(k) }
    }

    var trackerDoneCount: Int { trackerDays().filter { tracker.done.contains(Self.dayKey($0)) }.count }

    /// Consecutive done days ending today; an unmarked today doesn't break the streak yet.
    func trackerStreak(now: Date = .now) -> Int {
        let today = Self.dayKey(now)
        var streak = 0
        for k in trackerDays().map(Self.dayKey).reversed() where k <= today {
            if tracker.done.contains(k) { streak += 1 } else if k != today { break }
        }
        return streak
    }

    func restartTracker(now: Date = .now) {
        tracker = Tracker(name: tracker.name, start: Calendar.current.startOfDay(for: now))
    }

    // MARK: Payoff activities

    func addActivity(_ text: String, high: Bool) {
        guard !text.trimmed.isEmpty else { return }
        activities.append(Activity(text: text.trimmed, high: high))
    }

    func flip(_ a: Activity) {
        guard let i = activities.firstIndex(where: { $0.id == a.id }) else { return }
        activities[i].high.toggle()
    }

    func log(_ a: Activity, at now: Date = .now) {
        stamp(a.text, note: a.high ? "High payoff" : "Low payoff", kind: .note, at: now)
    }

    func addGoal(title: String, myWin: String, theirWin: String) {
        guard !title.trimmed.isEmpty else { return }
        goals.append(Goal(title: title.trimmed, myWin: myWin.trimmed, theirWin: theirWin.trimmed))
    }
}

struct Tracker: Codable, Equatable {
    var name = "My 30-day habit"
    var start = Calendar.current.startOfDay(for: .now)
    var done: Set<String> = []   // dayKeys
}

struct Activity: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var high: Bool
}

extension Planner {
    static let defaultActivities = [
        Activity(text: "Reach out to 3 potential clients", high: true),
        Activity(text: "Prepare or deliver a session", high: true),
        Activity(text: "Scrolling social media", high: false),
        Activity(text: "Re-checking email every few minutes", high: false),
    ]
}
