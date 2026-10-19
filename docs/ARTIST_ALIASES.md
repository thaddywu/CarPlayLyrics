# 歌手别名

当前共 36 组，大小写与中文简繁体自动兼容。只用于歌词查找和歌手身份校验，不修改播放器元数据。

| 主名称 | 对应名称 |
| --- | --- |
| 陶喆 | david tao / tao, david |
| 李荣浩 | ronghao li / li, ronghao |
| the weeknd | weeknd / abel tesfaye / abel makkonen tesfaye |
| 周杰伦 | jay chou |
| 林俊杰 | jj lin / j.j. lin |
| 陈奕迅 | eason chan |
| 邓紫棋 | g.e.m. / g.e.m.邓紫棋 / gem邓紫棋 |
| 张信哲 | jeff chang |
| 黄丽玲 | a-lin / a-lin 黄丽玲 |
| 薛之谦 | joker xue |
| 萧敬腾 | jam hsiao |
| 杨宗纬 | aska yang |
| 孙燕姿 | stefanie sun |
| 蔡依林 | jolin tsai |
| 张惠妹 | a-mei / amei |
| 莫文蔚 | karen mok |
| 王力宏 | leehom wang / wang leehom |
| 王菲 | faye wong |
| 刘德华 | andy lau |
| 张学友 | jacky cheung |
| 张国荣 | leslie cheung |
| 梁静茹 | fish leong |
| 梁咏琪 | gigi leung |
| 容祖儿 | joey yung |
| 杨千嬅 | miriam yeung |
| 许茹芸 | valen hsu |
| 林宥嘉 | yoga lin |
| 刘若英 | rene liu |
| 王心凌 | cyndi wang |
| 田馥甄 | hebe tien |
| 杨丞琳 | rainie yang |
| 周兴哲 | eric chou |
| bruno mars | peter gene hernandez |
| lady gaga | stefani germanotta / stefani joanne angelina germanotta |
| post malone | austin post / austin richard post |
| lana del rey | elizabeth grant / elizabeth woolridge grant |

实现位置：`DriveVerse/Core/Lyrics/LyricsMatcher.swift`。修改源表后需补充或运行匹配测试；仍要求标题相符及已知时长误差不超过三秒。未知昵称不会按相似字符串合并，乐队与主唱也不会自动视作同一歌手。

名称核对参考：

- [Apple Music：JJ Lin](https://music.apple.com/us/artist/jj-lin/216635866)
- [Apple Music：Eason Chan](https://music.apple.com/hk/artist/eason-chan/137938148?l=en)
- [Apple Music：Joker Xue](https://music.apple.com/us/artist/joker-xue/160809474)
- [Apple Music：Jam Hsiao](https://music.apple.com/us/artist/jam-hsiao/283971013)
- [GRAMMY：Post Malone](https://www.grammy.com/artists/post-malone/243389/)

这些来源为部分对应关系的核对入口，不代表已联网验证名单中每位歌手的全部歌曲。歌词源仍可能缺失或返回网络错误。
