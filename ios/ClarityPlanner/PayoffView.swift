import SwiftUI

struct PayoffView: View {
    @Environment(Planner.self) private var planner
    @State private var newHigh = ""
    @State private var newLow = ""

    var body: some View {
        NavigationStack {
            List {
                Section {} header: {
                    // A header, not a row: rows get clipped by the section's rounded corners.
                    Text("Do high payoff first. Reduce, delegate or drop low payoff. Log adds an activity to today's time stamps; swipe to move it to the other list.")
                        .font(.subheadline).textCase(nil)
                }
                group(high: true, text: $newHigh)
                group(high: false, text: $newLow)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Wash())
            .navigationTitle("Payoff")
        }
    }

    private func group(high: Bool, text: Binding<String>) -> some View {
        let list = planner.activities.filter { $0.high == high }
        return Section {
            if list.isEmpty {
                Text("None yet.").foregroundStyle(.secondary)
            }
            ForEach(list) { ActivityRow(activity: $0) }
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.brand)
                TextField("Add activity", text: text)
                    .submitLabel(.done)
                    .onSubmit { planner.addActivity(text.wrappedValue, high: high); text.wrappedValue = "" }
            }
        } header: {
            Label(high ? "High payoff" : "Low payoff", systemImage: high ? "star.fill" : "minus.circle")
        } footer: {
            Text(high ? "Protect time for these." : "Minimise, delegate or stop.")
        }
        .headerProminence(.increased)
    }
}

private struct ActivityRow: View {
    @Environment(Planner.self) private var planner
    let activity: Activity
    @State private var logged = 0

    var body: some View {
        HStack {
            Text(activity.text)
            Spacer()
            Button {
                planner.log(activity)
                logged += 1
            } label: {
                Label("Log", systemImage: "clock.badge.checkmark")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .font(.subheadline.weight(.semibold))
            .sensoryFeedback(.success, trigger: logged)
            .accessibilityHint("Adds it to today's time stamps")
        }
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) {
                planner.activities.removeAll { $0.id == activity.id }
            }
            Button(activity.high ? "Move to low" : "Move to high", systemImage: "arrow.up.arrow.down") {
                planner.flip(activity)
            }
            .tint(.gold)
        }
    }
}
