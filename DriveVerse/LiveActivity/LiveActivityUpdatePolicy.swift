import Foundation

/// Gate for Activity.update calls, per CLAUDE.md §5: update only when the
/// current line index changes, play/pause flips, or the track itself changes —
/// never on the 500 ms tick.
/// Pure value type so the policy is unit-testable without ActivityKit.
struct LiveActivityUpdatePolicy {
    private struct Snapshot: Equatable {
        var trackKey: String
        var lineIndex: Int?
        var isPlaying: Bool
        var text: String
    }

    private var last: Snapshot?
    private(set) var isEnabled: Bool

    init(isEnabled: Bool = true) { self.isEnabled = isEnabled }

    mutating func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled { reset() }
    }

    mutating func shouldUpdate(trackKey: String, lineIndex: Int?, isPlaying: Bool, text: String = "") -> Bool {
        guard isEnabled else { return false }
        let snapshot = Snapshot(trackKey: trackKey, lineIndex: lineIndex, isPlaying: isPlaying, text: text)
        guard snapshot != last else { return false }
        last = snapshot
        return true
    }

    /// Call after starting a fresh activity whose initial content already
    /// reflects the given state, or after ending one.
    mutating func seed(trackKey: String, lineIndex: Int?, isPlaying: Bool, text: String = "") {
        last = Snapshot(trackKey: trackKey, lineIndex: lineIndex, isPlaying: isPlaying, text: text)
    }

    mutating func reset() {
        last = nil
    }
}
