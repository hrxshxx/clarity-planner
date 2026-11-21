import SwiftUI
import Charts

struct WeekView: View {
    @Environment(Planner.self) private var planner
    @State private var offset = 0
    @State private var newAchievement = ""

    var body: some View {
        @Bindable var planner = planner
        let days = planner.weekDays(offset: offset)
        let score = planner.weekScore(offset: offset)
        let weekKey = planner.weekKey(offset: offset)
        let wins = planner.achievements(inWeek: offset)

        NavigationStack {
            List {
                Section {
                    HStack {
                        Button("Previous week", systemImage: "chevron.left") { offset -= 1 }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("\(days[0].formatted(.dateTime.day().month())) – \(days[6].formatted(.dateTime.day().month()))")
                                .font(.headline)
                            Text(offset == 0 ? "This week" : offset < 0 ? "\(-offset) week\(offset == -1 ? "" : "s") ago" : "In \(offset) week\(offset == 1 ? "" : "s")")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Next week", systemImage: "chevron.right") { offset += 1 }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }

                Section {
                    Chart(Array(days.enumerated()), id: \.offset) { _, day in
                        let p = planner.dayProgress(day) ?? 0
                        BarMark(x: .value("Day", day, unit: .day), y: .value("Done", p * 100))
                            .foregroundStyle(Calendar.current.isDateInToday(day) ? Color.brand : Color.brand.opacity(0.45))
                            .shadow(color: Calendar.current.isDateInToday(day) ? .glow : .clear, radius: 8)
                            .clipShape(.rect(cornerRadius: 6))
                            .annotation(position: .top) {
                                if planner.dayProgress(day) != nil {
                                    Text("\(Int((p * 100).rounded()))%").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                    }
                    .chartYScale(domain: 0...110)
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        }
                    }
                    .frame(height: 180)
                    .padding(.vertical, 8)

                    HStack {
                        Text("Weekly score")
                        Spacer()
                        Text("\(score)%").font(.system(.title, design: .rounded).bold()).monospacedDigit()
                            .contentTransition(.numericText())
                    }
                } header: {
                    Text("Weekly success")
                } footer: {
                    Text("Daily checklist completion.")
                }
                .headerProminence(.increased)

                Section {
                    ForEach($planner.rewards) { $r in
                        RewardRow(reward: $r, earned: score >= r.minScore,
                                  claimed: planner.claimed.contains(weekKey + "#" + r.id.uuidString)) {
                            planner.toggleClaim(r, weekKey: weekKey)
                        }
                    }
                } header: {
                    Text("Weekly rewards")
                } footer: {
                    Text("Reach a score to unlock a reward. Edit them to what motivates you.")
                }
                .headerProminence(.increased)

                Section {
                    if wins.isEmpty {
                        Text("No achievements logged yet.").foregroundStyle(.secondary)
                    }
                    ForEach(wins) { a in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(a.time.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                                .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                                .frame(width: 92, alignment: .leading)
                            Text(a.text)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                planner.achievements.removeAll { $0.id == a.id }
                            }
                        }
                    }
                    if offset == 0 {
                        HStack(spacing: 14) {
                            Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.brand)
                            TextField("I achieved…", text: $newAchievement)
                                .submitLabel(.done)
                                .onSubmit { planner.addAchievement(newAchievement); newAchievement = "" }
                        }
                    }
                } header: {
                    Text("Achievements")
                } footer: {
                    Text("Wins from this week, big or small.")
                }
                .headerProminence(.increased)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Wash())
            .navigationTitle("Week")
            .toolbar {
                if offset != 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("This week") { offset = 0 }
                    }
                }
            }
            .animation(.snappy, value: offset)
        }
    }
}

private struct RewardRow: View {
    @Binding var reward: Reward
    let earned: Bool, claimed: Bool
    let toggleClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: earned ? "trophy.fill" : "lock.fill")
                    .foregroundStyle(earned ? Color.gold : .secondary)
                    .frame(width: 24)
                TextField("Reward", text: $reward.text)
                if earned {
                    Button(claimed ? "Claimed" : "Claim", systemImage: claimed ? "checkmark" : "gift.fill", action: toggleClaim)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(claimed ? .secondary : .brand)
                        .font(.subheadline.weight(.semibold))
                }
            }
            Stepper("Unlocks at \(reward.minScore)%", value: $reward.minScore, in: 5...100, step: 5)
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
