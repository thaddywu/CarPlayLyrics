import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var cleared = false
    @State private var clientID = ""
    var body: some View {
        Form {
            Section("播放来源") {
                Picker("优先来源", selection: Binding(get: { model.sourcePin }, set: { model.sourcePin = $0 })) {
                    ForEach(SourcePin.allCases) { source in Text(source.displayName).tag(source) }
                }
                Text("自动模式优先正在播放的 Apple Music，否则使用 Spotify。可手动选择，避免两个来源同时活跃时切错。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Spotify") {
                TextField("Spotify Client ID", text: $clientID)
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                HStack {
                    if model.spotifyAuth.isConnected {
                        Label(model.spotifyAuth.needsReconnect ? "需要重新授权" : "已连接", systemImage: model.spotifyAuth.needsReconnect ? "exclamationmark.circle" : "checkmark.circle")
                    } else { Text("未连接").foregroundStyle(.secondary) }
                    Spacer()
                    if model.isConnectingSpotify { ProgressView() }
                }
                Button(model.spotifyAuth.isConnected ? "重新连接 Spotify" : "保存并连接 Spotify") {
                    Task { await model.connectSpotify(clientID: clientID) }
                }.disabled(model.isConnectingSpotify || clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if model.spotifyAuth.isConnected {
                    Button("断开 Spotify", role: .destructive) { model.disconnectSpotify() }
                }
                Link("创建 Spotify 开发者应用", destination: URL(string: "https://developer.spotify.com/dashboard")!)
                Text("在开发者应用登记以下回调地址，再复制 Client ID 到上方。无需 Client Secret。")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(SpotifyAuth.redirectURI).font(.footnote.monospaced()).textSelection(.enabled)
                Text("需要应用所有者的 Premium 账号。Spotify 通过网络读取播放状态，切歌、暂停或拖动可能有几秒延迟。")
                    .font(.footnote).foregroundStyle(.secondary)
                if let issue = model.spotifyIssue { Text(issue).font(.footnote).foregroundStyle(.orange) }
                if let error = model.errorMessage { Text(error).font(.footnote).foregroundStyle(.orange) }
            }
            Section("歌词") {
                Text("从 LRCLIB 自动寻找带时间轴的歌词。繁体中文歌词自动转成简体显示，英文保持不变。")
                Button(cleared ? "在线歌词缓存已清除" : "清除在线歌词缓存") { model.clearLyricsCache(); cleared = true }
                Text("Apple Music 与 LRCLIB 是不同的歌词来源，Apple Music 有滚动歌词并不保证这里也有。").font(.footnote).foregroundStyle(.secondary)
            }
            Section("显示歌词") {
                Text("首页的「显示歌词」控制锁屏和 CarPlay 卡片。关闭后移除卡片，并停止后台定位；手机内仍可查看歌词。开启时通过后台定位维持同步，位置不存储也不上传，会增加耗电。")
                Text("可在快捷指令中设置 CarPlay 连接时运行 Start Drive Mode，断开时运行 Stop Drive Mode。自动后台启动仍需真机验证。")
            }
            Section("CarPlay") {
                Text("CarPlay：iOS 26 上启动歌词 Live Activity，连接车机，在 Dashboard 查看；也可将 iPhone 接到 Mac，用 Additional Tools for Xcode 中的 CarPlay Simulator 测试。")
                Text("系统决定车端卡片的位置和尺寸，App 无法占满整个 CarPlay 屏幕。")
            }
            Section("开源致谢") {
                Text("沿途 Along · 基于 Praveet Gupta 的 DriveVerse（MIT）改造。歌词来自 LRCLIB，内容权利归各自权利人。")
                Link("沿途源码与许可", destination: URL(string: "https://github.com/thaddywu/CarPlayLyrics")!)
                Link("隐私与数据流", destination: URL(string: "https://github.com/thaddywu/CarPlayLyrics/blob/main/PRIVACY.md")!)
                Link("DriveVerse 原项目", destination: URL(string: "https://github.com/praveetgupta/driveverse")!)
            }
        }
        .navigationTitle("设置")
        .onAppear { clientID = model.spotifyAuth.clientID ?? "" }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}
