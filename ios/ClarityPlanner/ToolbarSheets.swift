import SwiftUI

struct Avatar: View {
    let initials: String
    var size: CGFloat = 28

    var body: some View {
        Group {
            if initials.isEmpty {
                Image(systemName: "person.fill").font(.system(size: size * 0.5))
            } else {
                Text(initials).font(.system(size: size * 0.43, weight: .semibold))
            }
        }
        .foregroundStyle(Color.onBrand)
        .frame(width: size, height: size)
        .background(.brand, in: .circle)
    }
}

/// Calendar button: pick any past day to see how it went.
struct DayHistorySheet: View {
    @Environment(Planner.self) private var planner
    @Environment(\.dismiss) private var dismiss
    @State private var day = Date.now

    var body: some View {
        let stamps = planner.stamps(on: day)
        let wins = planner.achievements.filter { Calendar.current.isDate($0.time, inSameDayAs: day) }
        let progress = planner.dayProgress(day)

        NavigationStack {
            List {
                Section {
                    DatePicker("Day", selection: $day, in: ...Date.now, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }

                Section {
                    LabeledContent("Checklist done") {
                        Text(progress.map { "\(Int(($0 * 100).rounded()))%" } ?? "–").monospacedDigit()
                    }
                    if let progress {
                        ProgressView(value: progress)
                    }
                } header: {
                    Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                }

                Section("Time stamps") {
                    if stamps.isEmpty {
                        Text("Nothing stamped this day.").foregroundStyle(.secondary)
                    }
                    ForEach(Array(stamps.enumerated()), id: \.element.id) { i, s in
                        TimelineRow(stamp: s, isFirst: i == 0, isLast: i == stamps.count - 1)
                    }
                }

                if !wins.isEmpty {
                    Section("Achievements") {
                        ForEach(wins) { Label($0.text, systemImage: "trophy.fill") }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !Calendar.current.isDateInToday(day) {
                        Button("Today") { day = .now }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }
}

/// Profile button: your name (sets the initials) and a summary of progress.
struct ProfileSheet: View {
    @Environment(Planner.self) private var planner
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Appearance.key) private var appearance = Appearance.system

    var body: some View {
        @Bindable var planner = planner
        let activeDays = planner.history.values.filter { $0 >= Planner.streakThreshold }.count

        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Avatar(initials: planner.initials, size: 56)
                        TextField("Your name", text: $planner.name)
                            .font(.title3.weight(.semibold))
                            .textContentType(.name)
                    }
                    .padding(.vertical, 4)
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Label($0.label, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section("Progress") {
                    LabeledContent("Current streak") { Text("^[\(planner.streak) day](inflect: true)") }
                    LabeledContent("Active days", value: "\(activeDays)")
                    LabeledContent("Goals", value: "\(planner.goals.count)")
                    LabeledContent("Time stamps", value: "\(planner.stamps.count)")
                }
                .monospacedDigit()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }
}
