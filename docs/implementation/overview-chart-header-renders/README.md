# 概览图表头重排图证

2026-11-16 由 `test/overview_reading_render_test.dart`、`test/apple_design_render_test.dart` 与 `test/drive_detail_reading_render_test.dart` 导出（390×844 / DPR 2，320 宽单列另标），字体为 Inter + 系统 CJK 回退（`/System/Library/Fonts/Supplemental/Arial Unicode.ttf`），数据来自既有 `cGalleryClient` 夹具，时区 `Asia/Shanghai`。`before-*` 为基线 `7b1ca30` 的实际渲染，`after-*` 为本次渲染。

| 文件 | 机位 | 用途 |
| --- | --- | --- |
| `before-overview-light-390.png` | 概览 · 浅色 · 390 · 100% | 改动前：单位折成第二行、图例挤在标题右侧 |
| `after-overview-light-390.png` | 概览 · 浅色 · 390 · 100% | 改动后：名称 → 度量 → 窗口同行，图例独立成行并只标注参照虚线 |
| `after-overview-dark-390.png` | 概览 · 深色 · 390 · 100% | 深色同一结构 |
| `after-overview-light-320.png` | 概览 · 浅色 · 320 · 100% | 窄屏仍单行容纳标题 / 单位 / 窗口 |
| `after-overview-light-390-200.png` | 概览 · 浅色 · 390 · 200% | 大字时窗口落到标题下一行、与标题同左缘 |
| `after-drives-light-390.png` | 行程 · 浅色 · 390 | 同一组件：`出行节奏 km` 与右端区间，与页内 `最近的路` 头同构 |
| `after-statistics-light-390.png` | 统计 · 浅色 · 390 | 同一组件：单测量 + 参照时图例只列 `参照 9/1–9/26` |
| `after-charging-detail-light-390.png` | 充电详情 · 浅色 · 390 | 同一组件：`充电曲线 kW` + 独占一行的指标控件 |
| `after-drive-detail-light-390.png` | 行程详情 · 浅色 · 390 | 同一组件：`速度过程 km/h`，提示语从窗口槽位移到读值旁，图下不再重复单位 |

说明与判定见 [实施记录](../overview-chart-header.md)。真机字体、读屏与性能不在本图册范围（#16/#17）。
