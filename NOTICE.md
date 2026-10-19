# 来源与致谢 / Attribution

## DriveVerse

本项目「沿途 Along / CarPlayLyrics」是 [DriveVerse](https://github.com/praveetgupta/driveverse) 的修改版本。上游作者：**Praveet Gupta**。

基础提交：`d2ecd418f85883a94881d3d810d00ee1f830ab22`。

上游许可证：MIT，原文及 `Copyright (c) 2026 Praveet Gupta` 完整保留在根目录 [LICENSE](LICENSE)，请在复制或分发本项目及其重要部分时继续保留。该声明适用于上游贡献，不应被解释为上游作者编写或认可本改版的全部内容。

本仓库从修改后的源码快照建立独立 Git 历史，而非 GitHub fork 网络中的分支；这不改变其衍生关系。主 App / Widget 的基础架构、同步引擎、歌词解析与获取、后台机制、基础图标资产等来自上游。

本改版由 [thaddywu](https://github.com/thaddywu) 维护，主要改动包括中文界面、固定双行歌词区域、CarPlay 卡片排版、简繁转换、匹配降级与歌手别名、失败重试、Spotify 连接及手机播放控制完善，并增加相应测试与文档。本项目修改同样按 MIT 提供。

## 第三方服务与系统组件

- [LRCLIB](https://lrclib.net/)：运行时歌词查询服务。服务来源署名不等同于歌词权利授权。
- Apple Music / MediaPlayer、ActivityKit、WidgetKit、CarPlay：Apple 平台服务与框架。
- Spotify Web API：可选的播放状态、用户授权与播放控制服务。
- 系统苹方字体由设备系统提供，本仓库不打包或分发字体文件。

相关名称和商标归各自权利人所有，仅用于说明兼容性与来源；无隶属、赞助或官方认可关系。

## 媒体与内容

HTML 预览中的示例文字为本项目制作，地图是代码绘制的示意图。当前预览不嵌入商业歌曲、歌词库或真实用户车端照片。上游演示视频、动图和原始屏幕录像未纳入此次公开快照。保留的应用图标来自上游，沿用上游 MIT 许可声明；如发现其他权利问题，请通过仓库反馈渠道联系维护者核实处理。

MIT 软件许可不覆盖由第三方保留的歌词、录音、专辑封面、商标或平台授权。
