# 设置正式 Flutter 渲染

2026-11-09。通过实际 MileafApp 的设置入口生成，使用合成站点、内存配置和可控 HTTP。

```sh
./tool/flutterw test test/settings_render_test.dart \
  --dart-define=MILEAF_SETTINGS_RENDER_OUTPUT=docs/implementation/settings-renders \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

浅深各 7 张，共 14 张。普通视口 390×844，large 为 320×844、200% 字号，输出比例 2。keyboard 使用底部 300 的键盘 inset，系统键盘本身由 Flutter 测试环境留空。中文字体使用 Arial Unicode 替代加载，真机中文字体表现另行验收。

| 页面 | 浅色 | 深色 |
| --- | --- | --- |
| 设置首页 | [查看](settings-light-home.png) | [查看](settings-dark-home.png) |
| 首页双倍字号 | [查看](settings-light-home-large.png) | [查看](settings-dark-home-large.png) |
| 连接摘要 | [查看](settings-light-connection.png) | [查看](settings-dark-connection.png) |
| 编辑连接 | [查看](settings-light-edit.png) | [查看](settings-dark-edit.png) |
| 编辑双倍字号 | [查看](settings-light-edit-large.png) | [查看](settings-dark-edit-large.png) |
| 键盘展开 | [查看](settings-light-keyboard.png) | [查看](settings-dark-keyboard.png) |
| 服务信息 | [查看](settings-light-service.png) | [查看](settings-dark-service.png) |

每张输出前检查 Flutter 异常，大字号页另滚动到最后一个操作检查可达性。实际地图配置页复用 [地图图册](../map-key-renders/README.md)。
