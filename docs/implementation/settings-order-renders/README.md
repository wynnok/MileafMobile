# 设置页秩序重排图证

渲染命令（照抄 map-key-renders / settings-renders 先例）：

```sh
tool/flutterw test --no-pub test/map_key_render_test.dart \
  --dart-define=MILEAF_MAP_RENDER_OUTPUT=docs/implementation/settings-order-renders/map \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'

tool/flutterw test --no-pub test/settings_render_test.dart \
  --dart-define=MILEAF_SETTINGS_RENDER_OUTPUT=docs/implementation/settings-order-renders/settings \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

- `map/`：设置 → 地图页，empty / saved / restart / help（申请帮助展开）/ privacy（数据使用说明展开）/ large（320 宽 200% 字号）/ keyboard 七状态 × 浅深。
- `settings/`：设置首页与连接子页，home / home-large / connection / edit / edit-large / keyboard / service 七场景 × 浅深。

对照基线（旧实现，未入库）：`.dsh-tmp/baseline/{map,settings}/`，渲染自改前工作树。
