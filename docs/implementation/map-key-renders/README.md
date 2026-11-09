# 地图设置正式 Flutter 渲染

2026-11-09，复用当前外观 v2 的主题、文字、共享行与表单。本代对应[地图设置页视觉 Spec](../../specs/map-settings-visual.md)的三段细线列表重排：`label` 眉标、状态结论行、Key 摘要行、destructive 清除行、两个默认折叠区。生成入口为 `test/map_key_render_test.dart`，默认跳过，仅显式指定输出目录时运行。

```sh
./tool/flutterw test --no-pub test/map_key_render_test.dart \
  --dart-define=MILEAF_MAP_RENDER_OUTPUT=docs/implementation/map-key-renders \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

- 正式页面 `MapPrivacyPage`，合成 Key 与绑定信息，独立内存存储。
- 浅深各 7 张，共 14 张。基准 360×800，`large` 为 320×800、200% 字号，`keyboard` 为底部 300 的键盘 inset。
- `pixelRatio=2`，输出 720×1600 或 640×1600 PNG。字体沿用既有图册的 Inter／系统中文替代加载方式。
- 每张输出前检查 Flutter 异常与布局溢出。图册为组件级渲染，真实底图另行验收。

| 状态 | 浅色 | 深色 |
| --- | --- | --- |
| 未配置 | [查看](map-light-empty.png) | [查看](map-dark-empty.png) |
| 已保存 | [查看](map-light-saved.png) | [查看](map-dark-saved.png) |
| 待重启 | [查看](map-light-restart.png) | [查看](map-dark-restart.png) |
| 申请帮助（展开） | [查看](map-light-help.png) | [查看](map-dark-help.png) |
| 隐私详情（展开） | [查看](map-light-privacy.png) | [查看](map-dark-privacy.png) |
| 窄屏双倍字号 | [查看](map-light-large.png) | [查看](map-dark-large.png) |
| 键盘展开 | [查看](map-light-keyboard.png) | [查看](map-dark-keyboard.png) |
