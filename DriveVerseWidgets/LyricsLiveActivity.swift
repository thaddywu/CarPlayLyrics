#if canImport(ActivityKit) && canImport(WidgetKit)
import WidgetKit
import SwiftUI
import ActivityKit

@main
struct DriveVerseWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LyricsLiveActivity()
    }
}

struct LyricsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsAttributes.self) { context in
            // Lock screen — on iOS 26 this same presentation is shown on the
            // CarPlay screen, so it stays high-contrast and sparse:
            // one small meta row, two text rows, a progress bar.
            LockScreenLyricsView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPlaying ? "music.note" : "pause.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.currentLine)
                            .font(.headline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(context.state.nextLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                        .tint(.white.opacity(0.85))
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isPlaying ? "music.note" : "pause.fill")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                Text(context.state.currentLine)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(maxWidth: 72)
            } minimal: {
                Image(systemName: "music.note")
                    .foregroundStyle(.tint)
            }
        }
        // CarPlay (and the Watch Smart Stack) render the .small family;
        // without this opt-in they fall back to the compact Dynamic Island
        // views, which truncate the lyric to one short marquee.
        .supplementalActivityFamilies([.small])
    }
}

struct LockScreenLyricsView: View {
    let context: ActivityViewContext<LyricsAttributes>
    @Environment(\.activityFamily) private var family

    var body: some View {
        Group {
            if family == .small {
                smallBody
            } else {
                mediumBody
            }
        }
        .activityBackgroundTint(Color.black.opacity(0.75))
        .activitySystemActionForegroundColor(.white)
    }

    /// Short Dashboard tiles must fit two active lines plus one upcoming line.
    /// Check intrinsic height before falling back to smaller type.
    private var smallBody: some View {
        ViewThatFits(in: .vertical) {
            lyricPair(currentSize: 18, nextSize: 12, spacing: 4)
                .fixedSize(horizontal: false, vertical: true)
            lyricPair(currentSize: 16, nextSize: 11, spacing: 3)
                .fixedSize(horizontal: false, vertical: true)
            lyricPair(currentSize: 14, nextSize: 10, spacing: 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: context.state.currentLine)
    }

    private func lyricPair(currentSize: CGFloat, nextSize: CGFloat, spacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(context.state.currentLine)
                .font(.system(size: currentSize, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(.white.opacity(context.state.isPlaying ? 1 : 0.8))
                .lineSpacing(1)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .contentTransition(.opacity)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                if !context.state.isPlaying {
                    // Pause state shares the upcoming row, never a third row.
                    Image(systemName: "pause.fill")
                        .foregroundStyle(Color(red: 0.68, green: 0.94, blue: 0.79))
                        .accessibilityLabel("已暂停")
                }
                Text(context.state.nextLine.isEmpty ? "♪" : context.state.nextLine)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .contentTransition(.opacity)
            }
            .font(.system(size: nextSize, weight: .medium))
        }
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: context.state.isPlaying ? "music.note" : "pause.fill")
                    .font(.caption2)
                Text(context.state.artist.isEmpty
                     ? context.state.title
                     : "\(context.state.title) — \(context.state.artist)")
                    .font(.caption)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if !context.state.sourceName.isEmpty {
                    Text(context.state.sourceName)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.15), in: Capsule())
                }
            }
            .foregroundStyle(.secondary)

            Text(context.state.currentLine)
                .font(.title2.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Text(context.state.nextLine)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ProgressView(value: context.state.progress)
                .tint(.white.opacity(0.85))
        }
        .padding(14)
    }
}
#endif
