# 概览读数区重排图证

2026-11-16 由正式 Flutter App、固定夹具与共享组件生成。所有图像为 390×844 或 320×844 逻辑像素、DPR 2；时区为 `Asia/Shanghai`，采样时刻为夹具 `2026-10-26T10:40:00Z`，中文回退为 Arial Unicode，Inter 使用项目字体。

| 文件 | 内容 |
| --- | --- |
| `before-light.png`、`before-dark.png` | 改动前的同一读数区：图表读值 3 行正文与 7 行本期指标连成一段 |
| `overview-reading-light-390-100.png`、`overview-reading-dark-390-100.png` | 改动后：图表读值（日期 → 60.0 km → 参照 → 差 +4.6 km）、1px 分隔线、本期四格读数表与费用覆盖 |
| `overview-reading-light-320-100.png`、`overview-reading-dark-320-100.png` | 320 宽：两列仍成立，参照与差值各占一行、不挤压单位 |
| `overview-reading-light-390-200.png`、`overview-reading-dark-390-200.png` | 200% 字号：读值区自然堆叠，图表占满首屏 |
| `overview-reading-plate-light-390-200.png`、`overview-reading-plate-dark-390-200.png` | 200% 字号下滚动到本期读数表：四格改单列 |

脚注（`缺失的费用不表示免费。净电耗与驾驶消耗为估算。`）在 100% 首屏位于底栏之下，需继续滚动才可见；200% 的读数表裁切帧同样受限于一屏。

## 复现

```sh
./tool/flutterw test --no-pub test/overview_reading_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/overview-reading-renders \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

`before-*` 由改动前的 `overview_page.dart` 与 `charts.dart`、同一夹具与同一滚动规则（`每日里程` 对齐 15%）临时生成；当前入口只生成改动后的样张。图证证明本地 Flutter 合成与排版，不替代真机字体回退、读屏与性能验收。
