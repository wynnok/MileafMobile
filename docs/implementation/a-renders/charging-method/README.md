# 补能方式构成环渲染（CM06）

- 日期：2026-11-01
- 依据：[设计规格](../../../specs/charging-method-share-ring.md)、[ADR 0004](../../../adr/0004-charging-method-visual.md)
- 生成入口：`test/a_charging_method_render_test.dart`（opt-in；未设置 `MILEAF_RENDER_OUTPUT` 时跳过）
- 复现：

```bash
tool/flutterw test --no-pub test/a_charging_method_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/a-renders/charging-method \
  "--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
```

## 矩阵（12 张）

| 状态 | 浅色 | 深色 |
| --- | --- | --- |
| normal 100% | `charging-method-normal-light-100.png` | `charging-method-normal-dark-100.png` |
| normal 200% | `charging-method-normal-light-200.png` | `charging-method-normal-dark-200.png` |
| empty 100% | `charging-method-empty-light-100.png` | `charging-method-empty-dark-100.png` |
| empty 200% | `charging-method-empty-light-200.png` | `charging-method-empty-dark-200.png` |
| missing 100% | `charging-method-missing-light-100.png` | `charging-method-missing-dark-100.png` |
| missing 200% | `charging-method-missing-light-200.png` | `charging-method-missing-dark-200.png` |

每张渲染前都断言该状态必须出现的文案（`AC 与 DC 接近` / `还没有充电记录` / `分类能量未记录`）与不得出现的文案，避免"空态其实是正常数据换了文案"。

## 读法

- normal：`AC 118 / DC 96 / 未知 20.7` → `AC 与 DC 接近 · 类型未知 20.7 kWh`；环 55.14% / 44.86%；三列 118 / 96 / 20.7 kWh 与 180 / 130 / 0 分钟。
- empty：空轨环 + 圆心 `—` + 「还没有充电记录」，无图例、无三列、无短注。
- missing：空轨环 + 「分类能量未记录」，三列全 `—`，短注占比 `—`。
- 200%：圆心按 fit-check 保留（`55` 能放下）；三列改单列；图例移到环下方。

## 未覆盖

- 真机、真实站点数据、字体回退差异、性能仍是独立外部 gate。
- 这些图片由合成 fixture 渲染，不代表真实环境的绝对值。
