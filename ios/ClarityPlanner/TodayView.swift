import SwiftUI

struct TodayView: View {
    @Environment(Planner.self) private var planner
    @State private var newItem = ""
    @State private var nowText = ""
    @State private var showInlineTitle = false
    @State private var showAddAlert = false
    @State private var alertItem = ""
    @State private var showCalendar = false
    @State private var showProfile = false

    private var dateTitle: String { Date.now.formatted(.dateTime.day().month(.wide)) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SummaryCard()
                } header: {
                    // In the header, not a row: the section's rounded corner clipped the first letter.
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide)).uppercased())
                            .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        Text(dateTitle).font(.largeTitle.bold()).foregroundStyle(Color.primary)
                    }
                    .textCase(nil)
                    .padding(.bottom, 8)
                }

                Section {
                    ForEach(planner.items) { ChecklistRow(item: $0) }
                        .onDelete { planner.items.remove(atOffsets: $0) }
                        .onMove { planner.items.move(fromOffsets: $0, toOffset: $1) }
                    HStack(spacing: 14) {
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.brand)
                        TextField("Add item", text: $newItem)
                            .submitLabel(.done)
                            .onSubmit { planner.addItem(newItem); newItem = "" }
                    }
                    .frame(minHeight: 44)
                } header: {
                    HStack {
                        Text("Checklist")
                        Spacer()
                        EditButton().font(.body)
                    }
                } footer: {
                    Text("Each tick is time-stamped. Swipe left on an item to delete it.")
                }
                .headerProminence(.increased)

                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.pencil").foregroundStyle(.secondary)
                        TextField("What are you doing now?", text: $nowText)
                            .submitLabel(.send)
                            .onSubmit(stampNow)
                        Button(action: stampNow) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(nowText.trimmed.isEmpty ? Color.secondary.opacity(0.5) : .brand)
                        .disabled(nowText.trimmed.isEmpty)
                        .accessibilityLabel("Stamp")
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Time stamps")
                            Spacer()
                            Text("\(planner.stamps(on: .now).count) today").font(.footnote).monospacedDigit()
                        }
                        StampChips(nowText: $nowText)
                    }
                    .padding(.bottom, 6)
                }
                .headerProminence(.increased)

                Section {
                    let today = planner.stamps(on: .now)
                    ForEach(Array(today.enumerated()), id: \.element.id) { i, s in
                        TimelineRow(stamp: s, isFirst: i == 0, isLast: i == today.count - 1)
                    }
                    .onDelete { offsets in
                        let ids = Set(offsets.map { today[$0].id })
                        planner.stamps.removeAll { ids.contains($0.id) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Wash())
            .navigationTitle(showInlineTitle ? dateTitle : "")
            .navigationBarTitleDisplayMode(.inline)
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 52 } action: { _, v in
                withAnimation(.easeInOut(duration: 0.2)) { showInlineTitle = v }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // A prompt, not focusing the inline field: that row is usually off-screen, so focus did nothing.
                    Button("Add item", systemImage: "plus") { showAddAlert = true }
                    Button("Calendar", systemImage: "calendar") { showCalendar = true }
                    Button { showProfile = true } label: { Avatar(initials: planner.initials) }
                        .accessibilityLabel("Profile")
                }
            }
            .alert("New checklist item", isPresented: $showAddAlert) {
                TextField("Item", text: $alertItem)
                Button("Add") { planner.addItem(alertItem); alertItem = "" }
                Button("Cancel", role: .cancel) { alertItem = "" }
            }
            .sheet(isPresented: $showCalendar) { DayHistorySheet() }
            .sheet(isPresented: $showProfile) { ProfileSheet() }
        }
    }

    private func stampNow() {
        guard !nowText.trimmed.isEmpty else { return }
        planner.stamp(nowText.trimmed, note: "Now", kind: .note)
        nowText = ""
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

struct Wash: View {
    var body: some View {
        ZStack {
            Color.canvas
            RadialGradient(colors: [.brand.opacity(0.20), .clear], center: UnitPoint(x: 0.12, y: 0.08), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [.gold.opacity(0.16), .clear], center: UnitPoint(x: 0.92, y: 0.32), startRadius: 0, endRadius: 260)
            RadialGradient(colors: [.brand.opacity(0.10), .clear], center: UnitPoint(x: 0.3, y: 0.7), startRadius: 0, endRadius: 380)
            RadialGradient(colors: [.brand.opacity(0.16), .clear], center: UnitPoint(x: 0.85, y: 0.95), startRadius: 0, endRadius: 300)
        }
        .ignoresSafeArea()
    }
}

private struct SummaryCard: View {
    @Environment(Planner.self) private var planner

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.brand.opacity(0.12), lineWidth: 14)
                Circle().trim(from: 0, to: planner.progress)
                    .stroke(.brand, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .shadow(color: .glow, radius: 10)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.6), value: planner.progress)
                VStack(spacing: 3) {
                    Text("\(Text("\(Int((planner.progress * 100).rounded()))").font(.system(size: 34, weight: .bold, design: .rounded)))\(Text("%").font(.system(size: 18, weight: .semibold, design: .rounded)))")
                        .monospacedDigit()
                    Text("TODAY").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, height: 110)
            .padding(7)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(planner.doneCount) of \(planner.items.count) done").font(.title3.weight(.semibold))
                Text("Next: \(planner.nextItem?.title ?? "All done. Nice work.")")
                    .font(.subheadline).foregroundStyle(.secondary)
                Label("\(planner.streak)-day streak", systemImage: "flame.fill")
                    .font(.footnote.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(Color.goldText)
                    .padding(.vertical, 5).padding(.horizontal, 10)
                    .background(Color.gold.opacity(0.14), in: .capsule)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct ChecklistRow: View {
    @Environment(Planner.self) private var planner
    let item: Item

    var body: some View {
        let done = item.doneAt != nil
        Button { planner.toggle(item) } label: {
            HStack(spacing: 14) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(done ? Color.brand : Color.secondary.opacity(0.6))
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title).foregroundStyle(done ? .secondary : .primary).lineLimit(1)
                    Text(done ? "Done at \(item.doneAt!.formatted(date: .omitted, time: .shortened))" : item.meta)
                        .font(.footnote).monospacedDigit()
                        .foregroundStyle(done ? Color.brand : .secondary)
                }
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: done) { _, new in new }
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}

private struct StampChips: View {
    @Environment(Planner.self) private var planner
    @Binding var nowText: String

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip("Start day", "sunrise.fill") { planner.stamp("Start day", kind: .day) }
                chip("Focus start", "play.circle.fill") { planner.startFocus(nowText); nowText = "" }
                chip("Focus end", "stop.circle.fill") { planner.endFocus() }
                chip("End day", "moon.fill") {
                    planner.stamp("End day", note: "\(planner.doneCount) of \(planner.items.count) done", kind: .day)
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: icon, action: action)
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
    }
}

struct TimelineRow: View {
    let stamp: Stamp, isFirst: Bool, isLast: Bool
    private let line = Color.primary.opacity(0.12)

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(stamp.time.formatted(date: .omitted, time: .shortened))
                .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                .frame(width: 62, alignment: .trailing)
                .padding(.top, 12)
            VStack(spacing: 0) {
                Rectangle().fill(isFirst ? .clear : line).frame(width: 2, height: 15)
                Circle()
                    .strokeBorder(stamp.color, lineWidth: 2)
                    .background(Circle().fill(stamp.kind == .focusEnd ? Color(.secondarySystemGroupedBackground) : stamp.color))
                    .frame(width: 10, height: 10)
                Rectangle().fill(isLast ? .clear : line).frame(width: 2).frame(maxHeight: .infinity)
            }
            .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(stamp.label).font(.subheadline.weight(.semibold))
                Text(stamp.note.isEmpty ? " " : stamp.note).font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.vertical, 9)
            Spacer(minLength: 0)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
    }
}
