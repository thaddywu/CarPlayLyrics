# 沿途 Along

Apple Music / Spotify 双行歌词伴侣，基于 [DriveVerse](https://github.com/praveetgupta/driveverse) 的 `d2ecd41` 改造。上游 MIT 许可证保留在 LICENSE。iOS 26+ / 兼容的完整 Xcode，个人自用原型。

## 当前界面与操作

首页跟随选定来源的当前歌曲，只有一个主要开关：**显示歌词**。

- 开启：请求锁屏 / CarPlay Live Activity，并通过后台定位维持同步。
- 关闭：立即解除当前卡片、请求系统移除，停止后台定位；后续歌词更新不会重新创建卡片。手机内仍能查看歌词。
- 开关默认关闭，不会因为开始播放就自动显示车端卡片。切歌和暂停不会主动关闭已开启的会话。
- 「体验演示」「导入 LRC」「同步微调」已从原生 App 移除，旧微调和导入数据不再参与匹配。
- 手机歌词卡片固定 300pt 高，保留当前句和下一句，无「下一句」小标签；当前句最多三行、下一句最多两行，超长时缩字 / 截断，不撑高卡片。中文显式使用苹方字体。
- 繁体歌词在显示阶段转换为简体，手机和 CarPlay 共用转换后的文字；原始缓存及时间轴保留不变。
- 点击首页歌词卡片查看完整歌词；歌曲信息右侧的 52pt 刷新按钮跳过当前缓存重新匹配，搜索期间显示加载状态并避免重复点击。
- 新歌识别或手动刷新后的前 5 秒内，未找到 / 网络失败会最多追加两次查询（等待 1 秒、2 秒，只在窗口内启动）。切歌取消旧任务；已取得纯文本、同步歌词或纯音乐结果不重试。慢请求允许完成，不会在第 5 秒强制取消。

原「旅途模式」指后台保活，不是显示开关；现已合并为上面的显示开关。位置不保存也不上传，但会增加耗电。系统可能限流或结束 Live Activity，不能保证无限时运行；Apple 文档说明单个 Live Activity 有最长八小时的生命周期。

## 立即看设计预览

双击 `../preview/index.html`，或：

```sh
open preview/index.html
```

预览展示手机首页与按车端照片比例调整的 Dashboard。手机「显示歌词」开关会隐藏 / 恢复示意卡片；下面的中英文长句选择、播放进度和顶部暂停按钮仅用于设计检查，不是原生 App 的功能入口。

截图：`../preview/desktop.png`、`../preview/mobile.png`。

网页不是原生 App 截图。地图、导航提示和音乐控制由 CarPlay 系统管理，App 只提供歌词 Live Activity。预览中的卡片尺寸、重排及颜色不保证与实际车机一致。

## 安装 / 更新到 iPhone

1. 用完整 Xcode 打开 `DriveVerse.xcodeproj`；内部 target / scheme 名保留上游名称。
2. 在 `DriveVerse`、`DriveVerseWidgets` 的 Signing & Capabilities 中选择同一个 Team，开启自动签名。Bundle ID 如不可用，改成自己的主 App ID 和子扩展 ID。
3. 用 USB 连接 iOS 26+ 的 iPhone，信任电脑并按提示开启开发者模式。
4. 顶部 scheme 选择 `DriveVerse`，运行目标选择真实 iPhone，按 **⌘R**。更新现有安装也使用这个步骤。
5. 允许媒体与 Apple Music 访问，在 Apple Music 播放歌曲，回到沿途开启「显示歌词」。按需允许定位和 Live Activities。
6. 连接 CarPlay 后到 Dashboard 查看卡片。Apple Music 无需 MusicKit token；Spotify 需要下面的 Client ID 配置。

不需要卸载旧版；使用相同 Bundle ID 覆盖安装即可。新匹配器使用独立缓存版本，会自动绕过旧版纯文本 / 未找到结果。

没有车时，可从 Apple 的 [Additional Tools for Xcode](https://developer.apple.com/download/all/?q=Additional%20Tools) 下载 CarPlay Simulator，用 USB 连接真实 iPhone测试。[Apple 官方演示](https://developer.apple.com/videos/play/wwdc2025/216/)。

既有快捷指令仍兼容：CarPlay 连接 → `Start Drive Mode`（显示歌词），断开 → `Stop Drive Mode`（隐藏歌词）。

## 为什么不能直接全屏 / 删除音乐卡片

完整 CarPlay App 需要 Apple 批准对应 entitlement，并使用指定类别的系统模板；普通个人开发签名不会自动获得这些权限。不是把 SwiftUI 歌词页铺满屏幕就能在真实 CarPlay 上显示。

照片里右侧的导航卡、Now Playing 音乐控制和歌词 Live Activity 并非三个自由编辑的 widget。当前 App 无权删除系统音乐卡，也无权指定剩余空间分给歌词。独立的 Widget 页面是另一个系统界面，不能与 Dashboard 卡片混淆。

参考：[CarPlay 框架与权限](https://developer.apple.com/carplay/)、[申请 entitlement](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)。

## 歌词匹配改进

- 精确专辑匹配只有纯文本时，继续查询不带专辑的记录及搜索候选；优先带时间轴版本。
- 简繁体互查，并兼容中文歌名内空格和逗号差异。
- 搜索候选必须校验歌手、标题和时长（已知时长相差不超过三秒）。live / remix 等版本文字保留，避免串用。
- 某种文字变体搜索暂时失败，不阻止尝试其他变体；已拿到纯文本时保留它作为降级结果。
- Apple Music 与 LRCLIB 的歌词库不同。Apple Music 有同步歌词，不等于 LRCLIB 必定覆盖。

2026-10-17 联网验证：修改后的 Swift 客户端对《爱你没错》（张信哲，「还爱」，256.627 秒）返回同步 LRC 38 行；《爱 请问怎么走》（A-Lin，268 秒）返回同步 LRC 41 行。不同专辑 / 时长版本仍需设备核对，时间轴准确性不能仅凭匹配成功保证。

已定位的具体问题：LRCLIB 的《爱你没错》「还爱」256.626667 秒记录只有纯文本，而其他近时长记录有同步歌词；旧代码拿到纯文本便提前返回。A-Lin 简体精确搜索没有结果，繁体「愛 請問怎麼走」存在多条同步记录。

## 验证

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test.sh
```

已通过 **150 项测试**，覆盖搜索降级、简繁体 / 标点、同名不同歌手拒绝、旧缓存迁移、强制重试、限次自动重试 / 五秒截止 / 取消 / 挂起恢复、显示开关策略、繁简转换、歌手别名、Spotify 授权 / 限流 / 断开后的过期请求，以及原有同步与解析。

用 Xcode 27.1 对 `generic/platform=iOS Simulator` 完整构建成功，包含主 App 和 Widget extension（关闭签名的构建检查）。预览开关 / 长句 / 暂停交互及截图已检查。

此前版本已有用户提供的真实车端显示照片；**本次开关和搜索修改尚未做真实 iPhone 安装、锁屏或 CarPlay 回归验证**。请停车测试：关闭卡片是否消失、重新开启、暂停恢复、自动切歌、两首问题歌曲、锁屏持续更新。

歌词权利不属于代码的 MIT 许可。

## Spotify 连接（需要用户授权）

1. 用自己的 Premium 账号登录 [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)，创建或使用自己的开发者应用。
2. 在应用设置添加与下面**完全一致**的 Redirect URI：

   ```text
   com.thaddywu.along.spotify://callback
   ```

3. 复制 Client ID（不是 Client Secret）。运行新版沿途，打开设置，在 Spotify 区域粘贴，点「保存并连接 Spotify」，完成系统浏览器内的登录授权。Client ID 保存在手机，token 保存在钥匙串。
4. 设置中选择「Spotify」或「自动」。自动模式优先活跃的 Apple Music，否则使用 Spotify。断开 Spotify 后停止轮询，并回到自动来源。
5. 在 Spotify 播放歌曲，再开启首页「显示歌词」。Web API 默认约 5 秒读取一次播放状态；不是逐字歌词源，仍从 LRCLIB 获取歌词。服务端限流期间不会通过刷新绕过等待。

无需向聊天提供密码或 Client Secret；创建开发者应用和真实账号授权需用户完成。当前已编译并用模拟数据验证，**尚未验证真实 Spotify 授权、手机锁屏后的轮询与车端同步**。

参考：[Spotify PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow)、[开发模式账号要求](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide)、[移动端回调地址](https://developer.spotify.com/documentation/web-api/concepts/apps)。

## 新增歌曲排查

- 陶喆《王八蛋》：LRCLIB 使用 David Tao / Tao, David，已加入明确别名对应。
- 李荣浩《乌梅子酱》：库内主要为繁体歌名及 Ronghao Li / Li, Ronghao，已加入歌手别名，结合简繁互查。
- 《Save Your Tears》：库内有同步歌词，补充 Weeknd / The Weeknd 别名；约 216 秒的原版与约 191 秒的 remix 不会因同名被混用。用户设备实际缺失原因不能仅凭歌曲名称断定，仍需核对其播放版本 / 元数据和网络状态。
- 调查中也遇到 LRCLIB 间歇性 HTTP 503，网络失败与真实未收录应区分；有限自动重试与手动刷新均可用。

新缓存命名空间为 `artist-alias-v3`，避免旧匹配结果阻止本次改进生效。

本轮 Swift 客户端联网复核：陶喆《王八蛋》（255 秒）取到同步 LRC 40 行，李荣浩《乌梅子酱》（257 秒）32 行，The Weeknd《Save Your Tears》（215.667 秒）46 行。精确接口返回 503 时，现在仍尝试可用的搜索接口；也新增了对应回归测试。不同时间查询可能受 LRCLIB 故障影响，《爱你没错》在最近一次查询降级为纯文本，不能保证歌词源持续可用。

## 手机播放控制与界面精简

手机首页新增播放 / 暂停和下一首，按当前显示的来源控制系统 Apple Music 播放器或 Spotify 当前活跃设备。没有歌曲时禁用；请求进行中防止重复点击。失败会提示，不会自动重发「下一首」，避免意外多跳一首。

Spotify 新授权包含 `user-modify-playback-state`。已有登录需要在设置中重新连接以授予控制权限；没有活跃设备时需先打开 Spotify 播放歌曲。此控制路径已通过模拟 HTTP 契约测试，真实账号控制和 Apple Music 真机行为仍需设备验证。

CarPlay 歌词卡片未添加控制按钮。手机首页去掉了「此刻 · 歌词」、重复的播放状态、标语和开关说明；保留图标操作、歌曲信息、歌词、时间与「显示歌词」开关。说明与授权设置保留在设置页。

《In the Night》：补充 Abel Tesfaye / Abel Makkonen Tesfaye 与 The Weeknd / Weeknd 的已核实别名对应。原姓名查询存在 503 时，继续尝试艺名搜索；保留时长校验。Swift 客户端以 Abel Tesfaye、235.653 秒查询，已联网获得同步 LRC 43 行，新增相应回归测试；不同设备播放版本仍需核对。

## 常见歌手别名扩充

现有 36 组对应（本轮新增 33 组），覆盖常见华语中英文名和部分欧美艺名 / 本名。名单见 [歌手别名](docs/ARTIST_ALIASES.md)。身份索引预先构建，减少逐条搜索结果中的重复文字转换。已通过双向匹配、组合名称、近似昵称和不同歌手拒绝测试；实际歌词覆盖仍取决于 LRCLIB。
