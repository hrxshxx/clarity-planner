import SwiftUI

struct GoalsView: View {
    @Environment(Planner.self) private var planner
    @State private var adding = false

    var body: some View {
        @Bindable var planner = planner
        NavigationStack {
            List {
                Section {} header: {
                    // A header, not a row: rows get clipped by the section's rounded corners.
                    Text("A win-win goal benefits you and the people you serve. Each runs for six months.")
                        .font(.subheadline).textCase(nil)
                }
                if planner.goals.isEmpty {
                    ContentUnavailableView {
                        Label("No goals yet", systemImage: "target")
                    } description: {
                        Text("Add your first six-month goal.")
                    } actions: {
                        Button("Add goal") { adding = true }.buttonStyle(.borderedProminent)
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach($planner.goals) { $goal in
                    Section { GoalCard(goal: $goal) }
                }
                .onDelete { planner.goals.remove(atOffsets: $0) }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Wash())
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add goal", systemImage: "plus") { adding = true }
                }
            }
            .sheet(isPresented: $adding) { NewGoalSheet() }
        }
    }
}

private struct GoalCard: View {
    @Binding var goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(goal.title).font(.headline)
            Text("\(goal.start.formatted(.dateTime.day().month())) → \(goal.end.formatted(.dateTime.day().month())) · \(goal.daysLeft()) days left · \(Int((goal.timeUsed() * 100).rounded()))% of time used")
                .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
            if !goal.myWin.isEmpty { win("My win", goal.myWin, "person.fill") }
            if !goal.theirWin.isEmpty { win("Their win", goal.theirWin, "person.2.fill") }
            HStack {
                Text("Progress").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int((goal.progress * 100).rounded()))%").font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            .padding(.top, 4)
            Slider(value: $goal.progress, in: 0...1, step: 0.05)
                .accessibilityLabel("Progress for \(goal.title)")
        }
        .padding(.vertical, 6)
    }

    private func win(_ label: String, _ text: String, _ icon: String) -> some View {
        Label {
            Text("\(Text(label).bold()): \(text)").font(.subheadline)
        } icon: {
            Image(systemName: icon).foregroundStyle(.brand)
        }
    }
}

private struct NewGoalSheet: View {
    @Environment(Planner.self) private var planner
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var myWin = ""
    @State private var theirWin = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal, e.g. Launch my signature program", text: $title, axis: .vertical)
                Section("My win") { TextField("What I gain", text: $myWin, axis: .vertical) }
                Section("Their win") { TextField("Who else benefits, and how", text: $theirWin, axis: .vertical) }
            }
            .navigationTitle("New 6-month goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", systemImage: "checkmark") {
                        planner.addGoal(title: title, myWin: myWin, theirWin: theirWin)
                        dismiss()
                    }
                    .disabled(title.trimmed.isEmpty)
                }
            }
        }
    }
}
