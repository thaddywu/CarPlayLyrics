import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    private let mint = Color(red: 0.68, green: 0.94, blue: 0.79)

    private var isLoading: Bool {
        if case .loading = model.lyricsState { return true }
        return false
    }

    private var currentLine: String {
        if let line = model.position?.currentLine { return line.isEmpty ? "间奏 · 享受旋律" : line }
        switch model.lyricsState {
        case .loading: return "正在寻找歌词…"
        case .notFound: return "还没有找到这首歌的歌词"
        case .failed: return "歌词加载失败"
        case .instrumental: return "纯音乐 · 享受旋律"
        case .plain: return "歌词源暂未提供同步版本"
        default: return model.nowPlaying == nil ? "让音乐，陪你出发。" : "前奏 · 即将开始"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.055, green: 0.075, blue: 0.075).ignoresSafeArea()
                RadialGradient(colors: [mint.opacity(0.13), .clear], center: .topTrailing, startRadius: 0, endRadius: 450).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("沿途").font(.custom("PingFangSC-Semibold", size: 28, relativeTo: .title))
                            }
                            Spacer()
                            NavigationLink(destination: SettingsView()) {
                                Image(systemName: "slider.horizontal.3").font(.title3).padding(13).background(.white.opacity(0.07), in: Circle())
                            }
                        }
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [mint.opacity(0.65), Color(red: 0.19, green: 0.34, blue: 0.32), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                                Image(systemName: "waveform").font(.system(size: 25, weight: .light)).foregroundStyle(.white.opacity(0.9))
                            }.frame(width: 66, height: 66)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(model.nowPlaying?.title ?? "等待音乐播放").font(.custom("PingFangSC-Medium", size: 17, relativeTo: .headline))
                                Text(model.nowPlaying.map { $0.artist + " · " + $0.source.displayName } ?? "播放 Apple Music 或 Spotify 后自动显示").font(.caption).foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Button { model.retryLyrics() } label: {
                                ZStack {
                                    Circle().fill(mint.opacity(0.1))
                                    if isLoading {
                                        ProgressView().tint(mint)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(mint)
                                    }
                                }.frame(width: 52, height: 52)
                            }
                            .buttonStyle(.plain)
                            .disabled(model.nowPlaying == nil || isLoading)
                            .opacity(model.nowPlaying == nil ? 0.4 : 1)
                            .accessibilityLabel("重新匹配歌词")
                        }
                        NavigationLink {
                            LyricsScreen()
                        } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(currentLine)
                                .font(.custom("PingFangSC-Semibold", size: 32, relativeTo: .title))
                                .lineSpacing(6)
                                .lineLimit(3)
                                .minimumScaleFactor(0.65)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 110, alignment: .leading)
                                .clipped()
                                .contentTransition(.opacity)
                            Text(model.position?.nextLine ?? "♪")
                                .font(.custom("PingFangSC-Regular", size: 18, relativeTo: .body))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44, alignment: .topLeading)
                                .clipped()
                            ProgressView(value: model.position?.trackProgress ?? 0).tint(mint)
                            HStack {
                                Text(time(model.position?.positionMs ?? 0))
                                Spacer()
                                Text(time(model.nowPlaying?.durationMs ?? 0))
                            }.font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.35))
                        }
                        .padding(24)
                        .frame(height: 300)
                        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 28))
                        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.07)))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.3))
                                .padding(20)
                        }
                        .animation(.easeInOut(duration: 0.2), value: currentLine)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("查看完整歌词")
                        .accessibilityHint("打开当前歌曲的完整歌词页面")

                        HStack(spacing: 24) {
                            Spacer()
                            Button { Task { await model.togglePlayback() } } label: {
                                Group {
                                    if model.isControllingPlayback { ProgressView().tint(.black) }
                                    else { Image(systemName: model.nowPlaying?.isPlaying == true ? "pause.fill" : "play.fill").font(.system(size: 23, weight: .semibold)) }
                                }
                                .frame(width: 60, height: 60)
                                .foregroundStyle(.black)
                                .background(mint, in: Circle())
                            }
                            .accessibilityLabel(model.nowPlaying?.isPlaying == true ? "暂停" : "播放")
                            Button { Task { await model.nextTrack() } } label: {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 23, weight: .semibold))
                                    .frame(width: 52, height: 52)
                                    .foregroundStyle(mint)
                                    .background(mint.opacity(0.1), in: Circle())
                            }
                            .accessibilityLabel("下一首")
                            Spacer()
                        }
                        .buttonStyle(.plain)
                        .disabled(model.nowPlaying == nil || model.isControllingPlayback)
                        .opacity(model.nowPlaying == nil ? 0.4 : 1)
                        if let error = model.playbackError {
                            Text(error).font(.caption).foregroundStyle(.orange)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: Binding(get: { model.lyricsEnabled }, set: { model.setLyricsEnabled($0) })) {
                                Label("显示歌词", systemImage: "text.quote").font(.headline)
                            }.tint(mint)
                        }.padding(20).background(mint.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))

                        if model.appleMusicAuth == .denied {
                            Text("请在系统设置中允许「媒体与 Apple Music」访问。").font(.caption).foregroundStyle(.orange)
                        }
                        if let message = model.errorMessage {
                            Text(message).font(.caption).foregroundStyle(.orange)
                        }
                    }.padding(24)
                }
            }
            .foregroundStyle(.white)
#if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
#endif
            .preferredColorScheme(.dark)
            .task { model.start() }

        }
    }

    private func time(_ ms: Int) -> String { String(format: "%d:%02d", max(0, ms) / 60000, max(0, ms) / 1000 % 60) }
}
