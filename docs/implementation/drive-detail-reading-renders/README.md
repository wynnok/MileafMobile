# 行程详情「对照电量」与「驾驶与环境」重排图证

2026-11-16 由正式 Flutter App、固定夹具（`cGalleryClient` / drive 17）生成。所有图像为 390×844、360×844 或 320×844 逻辑像素、DPR 2；时区为 `Asia/Shanghai`，采样时刻为夹具 `2026-10-26T10:40:00Z`，中文回退为 Arial Unicode，Inter 使用项目字体。

| 文件 | 内容 |
| --- | --- |
| `before-chart-{light,dark}-390-100.png` | 改动前：`对照电量` 是 `TextButton`，标签缩进 16、与上下说明行不成一条竖线，且与相邻蓝色链接抢重要性 |
| `before-paired-{light,dark}-390-100.png` | 改动前：展开后的第二张图由页面 `paired` 状态直接追加，入口排在两张说明之下 |
| `before-facts-{light,dark}-390-100.png` | 改动前：`驾驶与环境` 是 5 行「字段名 + 值」拼成的一段正文，17/25、同色同重、无分隔 |
| `after-chart-{light,dark}-{390-100,320-100,390-200}.png` | 改动后：`对照电量` 与 `速度数据说明`／`采样数据说明`／图表标题共用一条左线；动作行 17/500 正文色 + 12 号说明 + 1px 顶线 |
| `after-paired-{light,dark}-{390-100,320-100,390-200}.png` | 改动后：展开就地长出 `电量过程` 图，箭头翻到朝上 |
| `after-facts-{light,dark}-{390-100,320-100,390-200}.png` | 改动后：字段名 14 `textMuted` 在左、值 17/500 在右、单位 14 `textFaint` 占定宽列；行间 1px 分隔，末行不封口，`更多行程指标` 作为动作行带顶线收尾 |
| `after-facts-{light,dark}-320-200.png` | 最窄 + 最大字：事实表改「字段名在上、值在下」，无横向溢出 |
| `after-facts-{light,dark}-360-150.png` | 150% 是 `MileafLayout.largeText`（`scale(14) ≥ 21`）的临界点，换版式在这一档就已成立 |

`-{390,320}-100` 为 100% 字号，`-390-200`／`-320-200` 为 200%，`-360-150` 为 150%。大字下折叠行的箭头固定在标签首行中线。

## 复现

```sh
./tool/flutterw test --no-pub test/drive_detail_reading_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/drive-detail-reading-renders \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

`before-*` 由改动前的 `drive_detail_page.dart`／`sample_chart.dart` 生成，命令同上加
`--dart-define=MILEAF_RENDER_STAGE=before`；只保留 390·100% 的对照帧。图证证明本地
Flutter 合成与排版，不替代真机字体回退、读屏与性能验收。
