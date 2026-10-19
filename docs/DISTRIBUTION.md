# 内容权利与分发边界

更新：2026-10-19。本文件记录项目现状与待解决的问题，不是法律意见、授权证书或零风险保证。

## 代码与内容是两种权利

本仓库代码沿用上游 MIT，必须保留版权与许可声明。MIT 不自动授予商业歌曲的歌词、录音、封面、字体或商标权利。接口公开、无需 API key、免费提供、个人开发或写上免责声明，都不能据此推导获得内容展示或再分发授权。

歌词在运行时来自 LRCLIB；没有核实到覆盖本项目公开发行用途的完整歌词授权。请使用自己有权使用的内容；不要向仓库提交歌词库、抓取结果、商业歌曲演示音视频或含未获许可内容的截图。服务开放与代码开源不能替代内容许可。参考：[LRCLIB API 文档](https://lrclib.net/docs)。

## 当前后台机制

「显示歌词」开启后使用定位会话维持后台执行，但应用不提供基于位置的实际服务。该方式与 Apple 对后台服务及定位用途的要求存在明显冲突风险。公开源码不表示 Apple 批准这种方式，也不表示可原样提交 App Store / TestFlight。需要重新评估并实现符合用途的后台方案，且重新验证锁屏同步；不能通过修改文案或增加无实际用途的定位界面解决。

参考：[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) 中 2.5.4、5.1.5，以及涉及第三方权利的 5.2。系统对 Live Activity 的生命周期、刷新和车机布局也有约束。

## Spotify 与公开用户

Spotify 政策不仅涉及配额，还涉及跨服务内容整合、录音与视觉媒体同步、来源署名及回链要求（Developer Policy II.4、III.5–6）。这些条款如何适用于本项目的外部歌词同步尚未确认，也未取得 Spotify 的明确许可；不能据此声称当前集成符合公开运营要求。公开面向用户运营前需解决这些问题，必要时移除相关集成。

Spotify 集成仍属实验性，用户需自行配置开发者应用并授权。开发模式的账号资格、用户数量、调用配额和公开发行要求受 Spotify 当前政策约束。自行填写 Client ID 不是绕开服务条款或配额限制的方式；不要共享账号、token 或 Client Secret。扩大用户范围前需重新核实政策与所需许可。

参考：[Developer Policy](https://developer.spotify.com/policy)、[Quota modes](https://developer.spotify.com/documentation/web-api/concepts/quota-modes)。

## 演示、品牌与权利反馈

项目未获 Apple、Spotify、LRCLIB 或上游作者背书，不使用官方合作或审核通过的宣传表述。CarPlay 预览是系统界面示意，不保证真实设备一致。请停车时测试，遵守当地交通规则。

若认为仓库文件涉及权利问题，请在 [Issues](https://github.com/thaddywu/CarPlayLyrics/issues) 指明文件路径、相关权利与可公开的说明；维护者将核实并按情况移除或修正。敏感身份资料不要公开提交。此渠道与免责声明不构成对权利问题的免责。
