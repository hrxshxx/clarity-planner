import SwiftUI

struct ThirtyDaysView: View {
    @Environment(Planner.self) private var planner
    @State private var confirmRestart = false

    var body: some View {
        @Bindable var planner = planner
        let done = planner.trackerDoneCount
        let streak = planner.trackerStreak()

        NavigationStack {
            List {
                Section {
                    TextField("Habit or challenge", text: $planner.tracker.name)
                        .font(.headline)
                    DatePicker("Started", selection: $planner.tracker.start, displayedComponents: .date)
                } footer: {
                    Text("Tap a day to mark it done.")
                }

                Section {
                    HStack {
                        stat("\(done)/30", "days done")
                        Spacer()
                        stat("\(streak)", "day streak", icon: "flame.fill", alignment: .trailing)
                    }
                    ProgressView(value: Double(done), total: 30)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(Array(planner.trackerDays().enumerated()), id: \.offset) { i, d in
                            DayCell(number: i + 1, date: d,
                                    done: planner.tracker.done.contains(Planner.dayKey(d))) {
                                planner.toggleTracked(d)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    Button("Restart 30 days", systemImage: "arrow.counterclockwise", role: .destructive) {
                        confirmRestart = true
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Wash())
            .navigationTitle("30 Days")
            .confirmationDialog("Restart from today?", isPresented: $confirmRestart, titleVisibility: .visible) {
                Button("Restart and clear \(done) marked days", role: .destructive) { planner.restartTracker() }
            }
        }
    }

    private func stat(_ value: String, _ label: String, icon: String? = nil,
                      alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).foregroundStyle(.gold) }
                Text(value).font(.system(.title, design: .rounded).bold()).monospacedDigit()
            }
            Text(label).font(.footnote).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DayCell: View {
    let number: Int, date: Date, done: Bool
    let toggle: () -> Void

    var body: some View {
        let future = Planner.dayKey(date) > Planner.dayKey(.now)
        let today = Calendar.current.isDateInToday(date)
        Button(action: toggle) {
            VStack(spacing: 1) {
                Text("\(number)").font(.headline).monospacedDigit()
                Text(date.formatted(.dateTime.day().month(.defaultDigits)))
                    .font(.system(size: 9)).monospacedDigit()
                    .opacity(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(done ? Color.onBrand : .primary)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(done ? Color.brand : Color.brand.opacity(0.08))
                    .shadow(color: done ? .glow : .clear, radius: 8)
            }
            .overlay {
                if today { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.brand, lineWidth: 2) }
            }
        }
        .buttonStyle(.plain)
        .disabled(future)
        .opacity(future ? 0.4 : 1)
        .sensoryFeedback(.success, trigger: done) { _, new in new }
        .accessibilityLabel("Day \(number), \(date.formatted(date: .abbreviated, time: .omitted))")
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}
