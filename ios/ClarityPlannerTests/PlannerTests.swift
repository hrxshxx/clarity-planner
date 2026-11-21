import Foundation
import Testing
@testable import ClarityPlanner

@MainActor
struct PlannerTests {
    func fresh() -> Planner { Planner(defaults: UserDefaults(suiteName: UUID().uuidString)!) }

    @Test func toggleStampsAndProgress() {
        let p = fresh()
        let open = p.nextItem!
        let before = p.doneCount
        p.toggle(open)
        #expect(p.doneCount == before + 1)
        #expect(p.items.first { $0.id == open.id }?.doneAt != nil)
        p.toggle(open)
        #expect(p.doneCount == before)
    }

    @Test func pauseFreezesElapsedAndEndStamps() {
        let p = fresh()
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        p.startFocus("Write", at: t0)
        p.togglePause(at: t0.addingTimeInterval(600))         // 10 min run
        #expect(p.timer?.elapsed(at: t0.addingTimeInterval(9_999)) == 600)
        p.togglePause(at: t0.addingTimeInterval(1_200))       // resume
        p.endFocus(at: t0.addingTimeInterval(1_500))          // +5 min
        #expect(p.timer == nil)
        #expect(p.stamps.last?.note == "Write · 15 min")
    }

    @Test func weekScoreAveragesElapsedDaysAndPastWeeksCountSeven() {
        let p = fresh()
        p.items = [Item(title: "a", meta: "")]                 // today: 0%
        let wed = Calendar.mondayFirst.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 12))!
        let days = p.weekDays(offset: 0, now: wed)
        #expect(Planner.dayKey(days[0]) == "2026-11-23")      // Monday
        p.history = [Planner.dayKey(days[0]): 1.0, Planner.dayKey(days[1]): 0.5]
        #expect(p.dayProgress(days[3], now: wed) == nil)       // Thursday is in the future
        #expect(p.weekScore(offset: 0, now: wed) == 50)        // (100 + 50 + 0) / 3
        let lastWeek = p.weekDays(offset: -1, now: wed)
        p.history = [Planner.dayKey(lastWeek[0]): 0.7]
        #expect(p.weekScore(offset: -1, now: wed) == 10)       // 70 / 7
        #expect(p.weekScore(offset: 1, now: wed) == 0)
    }

    @Test func oldSaveWithoutNewFieldsStillLoads() throws {
        let d = UserDefaults(suiteName: UUID().uuidString)!
        let old = #"{"items":[{"id":"\#(UUID())","title":"Kept","meta":""}],"stamps":[],"streak":3}"#
        d.set(Data(old.utf8), forKey: "planner.v1")
        let p = Planner(defaults: d)
        #expect(p.items.map(\.title) == ["Kept"])
        #expect(p.goals.isEmpty && p.rewards.count == 3)
    }

    @Test func newDayClearsTicksKeepsHistoryAndOldStamps() {
        let p = fresh()
        let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 21))!
        let tuesday = Calendar.current.date(byAdding: .hour, value: 5, to: monday)!   // 2 AM next day
        p.items = [Item(title: "a", meta: "", doneAt: monday), Item(title: "b", meta: "")]
        p.day = Planner.dayKey(monday)
        p.stamps = [Stamp(time: monday, label: "Start day", note: "", kind: .day)]

        p.rollOverIfNeeded(now: monday)                         // same day: nothing changes
        #expect(p.doneCount == 1)

        p.rollOverIfNeeded(now: tuesday)
        #expect(p.doneCount == 0)
        #expect(p.history["2026-11-23"] == 0.5)
        #expect(p.history["2026-11-24"] == 0)
        #expect(p.day == "2026-11-24")
        #expect(p.stamps.count == 1)                            // kept…
        #expect(p.stamps(on: tuesday).isEmpty)            // …but not shown on the new day
    }

    @Test func trackerStreakAndFutureDays() {
        let p = fresh()
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let day = { cal.date(byAdding: .day, value: $0, to: start)! }
        p.tracker = Tracker(name: "Walk", start: start)
        let now = day(9).addingTimeInterval(3600)              // day 10 of 30
        for i in [2, 6, 7, 8] { p.toggleTracked(day(i), now: now) }
        p.toggleTracked(day(20), now: now)                     // future: ignored
        #expect(p.trackerDoneCount == 4)
        #expect(p.trackerStreak(now: now) == 3)                // 7, 8, 9; unmarked today doesn't break it
        p.toggleTracked(day(9), now: now)
        #expect(p.trackerStreak(now: now) == 4)
        p.restartTracker(now: now)
        #expect(p.trackerDoneCount == 0 && p.tracker.name == "Walk")
    }

    @Test func payoffFlipAndLog() {
        let p = fresh()
        p.activities = []
        p.addActivity(" Call client ", high: true)
        let a = p.activities[0]
        p.flip(a)
        #expect(p.activities[0].high == false)
        p.log(p.activities[0])
        #expect(p.stamps.last?.label == "Call client" && p.stamps.last?.note == "Low payoff")
    }

    @Test func streakCountsBackFromTodayAndStopsAtAGap() {
        let p = fresh()
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 9))!
        let key = { Planner.dayKey(cal.date(byAdding: .day, value: -$0, to: now)!) }
        p.items = [Item(title: "a", meta: "")]                  // nothing ticked today yet
        p.history = [key(1): 0.5, key(2): 1, key(3): 0, key(4): 1]
        #expect(p.streak(now: now) == 2)                         // yesterday + day before; gap at day 3
        p.items[0].doneAt = now
        #expect(p.streak(now: now) == 3)                         // ticking today extends it
        p.history[key(1)] = nil
        p.items[0].doneAt = nil
        #expect(p.streak(now: now) == 0)                         // missed yesterday: streak broken
    }

    @Test func initialsFromName() {
        let p = fresh()
        #expect(p.initials == "")
        p.name = "  sam  de souza "
        #expect(p.initials == "SD")
        p.name = "Priya"
        #expect(p.initials == "P")
    }

    @Test func persistsAcrossInstances() {
        let d = UserDefaults(suiteName: UUID().uuidString)!
        Planner(defaults: d).addItem("  New thing ")
        #expect(Planner(defaults: d).items.last?.title == "New thing")
    }
}
