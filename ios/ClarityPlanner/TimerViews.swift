import SwiftUI

func clock(_ seconds: TimeInterval) -> String {
    let s = Int(seconds), h = s / 3600, m = s / 60 % 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
}

/// Tab bar bottom accessory: the system slot Music uses for Now Playing.
struct TimerAccessory: View {
    @Environment(Planner.self) private var planner
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Binding var showSheet: Bool

    var body: some View {
        if let t = planner.timer {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                HStack(spacing: 10) {
                    LiveDot(running: t.runningSince != nil)
                    if placement != .inline {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Focus · \(t.runningSince != nil ? "running" : "paused")")
                                .font(.caption.weight(.semibold)).foregroundStyle(.brand)
                            Text(t.task).font(.subheadline.weight(.semibold)).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    Text(clock(t.elapsed(at: ctx.date))).font(.body.weight(.semibold)).monospacedDigit()
                    Button { planner.togglePause() } label: {
                        Image(systemName: t.runningSince != nil ? "pause.fill" : "play.fill")
                    }
                    .accessibilityLabel(t.runningSince != nil ? "Pause" : "Resume")
                }
                .padding(.horizontal, 16)
                .contentShape(.rect)
                .onTapGesture { showSheet = true }
            }
        } else {
            Button("Start focus", systemImage: "play.circle.fill") { planner.startFocus(nil) }
                .font(.subheadline.weight(.semibold))
        }
    }
}

private struct LiveDot: View {
    let running: Bool
    var body: some View {
        Circle().fill(running ? Color.brand : .gold).frame(width: 9, height: 9)
            .shadow(color: running ? .glow : .clear, radius: 5)
            .phaseAnimator(running ? [1.0, 0.45] : [1.0]) { $0.opacity($1) } animation: { _ in .easeInOut(duration: 0.8) }
            .accessibilityHidden(true)
    }
}

struct TimerSheet: View {
    @Environment(Planner.self) private var planner
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let t = planner.timer {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let e = t.elapsed(at: ctx.date)
                        VStack(spacing: 0) {
                            Text(clock(e)).font(.system(size: 72, weight: .semibold, design: .rounded)).monospacedDigit()
                            Text(t.task).font(.headline).padding(.top, 10)
                            Text("Started \(t.startedAt.formatted(date: .omitted, time: .shortened)) · 50 min block")
                                .font(.footnote).foregroundStyle(.secondary).monospacedDigit().padding(.top, 2)
                            ProgressView(value: min(e / FocusTimer.block, 1))
                                .scaleEffect(y: 2).padding(.vertical, 22)
                            HStack(spacing: 10) {
                                let running = t.runningSince != nil
                                Button(running ? "Pause" : "Resume", systemImage: running ? "pause.fill" : "play.fill") {
                                    planner.togglePause()
                                }
                                .buttonStyle(.glass)
                                Button("End & stamp", systemImage: "stop.circle.fill") {
                                    planner.endFocus()
                                    dismiss()
                                }
                                .buttonStyle(.glassProminent)
                            }
                            .controlSize(.large)
                            .font(.headline)
                        }
                        .padding(.horizontal, 24)
                    }
                } else {
                    ContentUnavailableView("No focus running", systemImage: "timer")
                }
            }
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}
