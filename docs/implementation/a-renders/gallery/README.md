# A「夜航」图册（VA12）

- 日期：2026-11-01
- 分支：`codex/mileaf-v1`（本地提交，未推送）
- 生成入口：`test/a_gallery_render_test.dart`（opt-in；未设置 `MILEAF_RENDER_OUTPUT` 时跳过）
- 生成条件：360×800 逻辑像素、pixelRatio 2（PNG 720×1600）；Inter 400/500/600 + 渲染机 CJK fallback（Arial Unicode）。
- 数据：`test/support/c_fixture.dart` 的合成 fixture，不是真实站点。
- 来源指纹：
  - 36 张 PNG：`c5f1ce492f6ec0889533fc41168f50752cc2d12703641d77a5cd4b67388a398a`
  - 页面/组件/入口源码：`addf89bc6489d0ec733c8bdd4a4405b7a2e4aa3d4a078050f3fee63cb41b48f6`

## 矩阵

| 页面 | normal 深/浅 100/200 | empty 深 100 | missing 深 100 |
| --- | --- | --- | --- |
| 概览 | ✓ 4 张 | ✓ | ✓ |
| 行程 | ✓ 4 张 | ✓ | ✓ |
| 充电 | ✓ 4 张 | ✓ | ✓ |
| 统计 | ✓ 4 张 | ✓ | ✓ |
| 行程详情 | ✓ 4 张 | — | — |
| 充电详情 | ✓ 4 张 | — | — |
| 节奏专题 | ✓ 4 张 | — | — |

共 36 张。正常态覆盖浅/深 × 100/200%；空/缺失覆盖深色 100%；详情与一个专题覆盖四象限。五个专题的空/缺失/失败由各专题的 widget 测试覆盖，未全部进入本图册；VA12 的完整「五专题 × 12」图册仍是待补项，见文末。

### 每张证明什么

- `overview-*`：深色车况 hero、本月主数、每日里程主图与辅助读数；空态不画全零，缺失 `—`。
- `drives-*`：期间主数 + 节奏条带 + 最近的路；空态给出「这段时间还没有行程」。
- `charging-*`：深色费用 hero + 覆盖 + 三读数 + stem；空态不画全零补能图。
- `statistics-*`：结论 + 深色里程主图 + 四章节；长期显示 `—` 与「进专题查看」，不硬编码 316。
- `drive-detail-*`：地图/路线速写、覆盖说明带、三结果、速度曲线与电量区间。
- `charge-detail-*`：电量弧区间、三结果、功率曲线、技术信息。
- `topic-rhythm-*`：节奏专题的结论、主数、日历热图与证据 2×2。

## 与原型/旧 C 的差异

1. 导航 active 标记在顶部（Spec §7.7 / ADR §6.1）；原型画在图标下方。
2. 概览保留「本月/近7天 + 单一刷新」区间行，100% 下「最近」从首屏下缘开始，需轻微滚动；主图与读数完整在首屏。
3. 充电详情电量弧 hero 仍在页面 12px 内容边距内；A 规范期望电池弧作为深色锚点，实机可再评估是否全出血。
4. 缺失统一 `—`；费用无币种显示金额 + 「币种未记录」，不默认 CNY。
5. 概览/统计不再有 C 的彩色 tile 与五等权 tab；章节用 1px 分线。

## 验证

- `tool/flutterw analyze --no-pub`：通过。
- `tool/flutterw test --no-pub`：351 通过、22 跳过。
- 本目录 36 张由正式页面渲染；`a_gallery_render_test.dart` 在 normal/empty/missing 各断言关键文本。
- 各页面另有 A 回归：`a_overview_test.dart`、`a_drives_test.dart`、`a_charging_test.dart`、`a_statistics_test.dart`、`a_drive_detail_test.dart`、`a_charging_detail_test.dart`。

## 待补 / 外部 gate

- **待补**：五个专题的完整 × 浅/深 × 100/200% × normal/empty/missing 图册（当前只有节奏专题四象限；其余专题由 widget 测试覆盖）。
- 真机字体回退、状态栏/安全区、TalkBack/VoiceOver。
- 真实站点数据、地图底图/CRS/许可、性能与双端隔离构建。
- 360×800 之外的真实设备宽度与系统 reduce motion 手工体验。

## 复现

```sh
tool/flutterw test --no-pub \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/a-renders/gallery \
  --dart-define=MILEAF_RENDER_FONT="/System/Library/Fonts/Supplemental/Arial Unicode.ttf" \
  test/a_gallery_render_test.dart
```
