# A「夜航」图册（VA12）

- 日期：2026-11-01
- 分支：`codex/mileaf-v1`（本地提交，未推送）
- 生成入口：`test/a_gallery_render_test.dart`（opt-in；未设置 `MILEAF_RENDER_OUTPUT` 时跳过）
- 生成条件：360×800 逻辑像素、pixelRatio 2（PNG 720×1600）；Inter 400/500/600 + 渲染机 CJK fallback（Arial Unicode）。
- 数据：`test/support/a_gallery_fixture.dart`（`aGalleryClient`）复用 `test/support/c_fixture.dart` 的合成快照；不是真实站点。
- 外观：由 `AppearanceController` + 内存 `AppearancePreferenceStore` 强制浅/深，不依赖 `platformBrightnessTestValue`。

## 指纹

- 132 张 PNG：`42c5e5c468dd02ca2c9c4671ceb0d51ac3ed3c84b65eeac0523369c8eaa6cca8`
  （`sha256` over 排序后的「文件名:文件 sha256」行）
- 页面/组件/入口源码：`ad125a523d2ae660f107ecd70c01f0f383c1d865f0a86d38da22be47def9f8f7`
  （`find lib/src -name '*.dart'` + `test/a_gallery_render_test.dart` + `test/support/a_gallery_fixture.dart` + `test/support/c_fixture.dart`，按路径排序后拼接）

## 矩阵：11 页 × 3 态 × 2 外观 × 2 字号 = 132 张

| 页面 | 文件前缀 | normal | empty | missing |
| --- | --- | --- | --- | --- |
| 概览 | `overview-*` | 浅/深 × 100/200 | 浅/深 × 100/200 | 浅/深 × 100/200 |
| 行程 | `drives-*` | ✓ 4 | ✓ 4 | ✓ 4 |
| 充电 | `charging-*` | ✓ 4 | ✓ 4 | ✓ 4 |
| 统计（总览） | `statistics-*` | ✓ 4 | ✓ 4 | ✓ 4 |
| 行程详情 | `drive-detail-*` | ✓ 4 | ✓ 4 | ✓ 4 |
| 充电详情 | `charge-detail-*` | ✓ 4 | ✓ 4 | ✓ 4 |
| 专题·节奏 | `topic-rhythm-*` | ✓ 4 | ✓ 4 | ✓ 4 |
| 专题·能耗 | `topic-energy-*` | ✓ 4 | ✓ 4 | ✓ 4 |
| 专题·补能 | `topic-charging-*` | ✓ 4 | ✓ 4 | ✓ 4 |
| 专题·长期续航 | `topic-range-*` | ✓ 4 | ✓ 4 | ✓ 4 |
| 专题·停放观察 | `topic-parking-*` | ✓ 4 | ✓ 4 | ✓ 4 |

共 **132 张**。132 个文件哈希互不相同；66 对 light/dark（同页同态同字号）全部不同；66 对 100/200% 全部不同。

专题入口遵循正式路径：统计页 2×2 章节（节奏/能耗/补能/长期），长期页再以「展开长期续航」「展开停放观察」进入两个长期专题，因此两个长期专题各自 ≥1 张。

## 三种状态的定义（不伪造数据）

- `normal`：2026-10-26 合成快照原值（概览 1,198.6 km · 46 趟；统计净电耗 158 Wh/km；充电 234.7 kWh · ¥186.4；行程 32.9 km；充电详情 46.8 kWh · 18→82%）。
- `empty`：真实「无记录/无采样」。概览与统计的月度分桶为空、总额为 0；行程/充电列表 `items: []` 且分桶为空；两个详情的「empty」是**无采样**——记录存在（`/drives/17`、`/charging-sessions/9` 正常返回），系列返回 0 点，页面显示「无采样数据 / 没有采样点」「此充电没有序列采样」。为保持详情可达，概览的「最近」用 9 月的旧记录（本月为空是真实结论）。
- `missing`：字段未知而非零。概览的 state/battery/功率/续航/经纬度/最近项为 `null` → `—`；行程与统计的电耗/能耗为 `null` → `—`；五专题的时长、分位、温度分组电耗、费用、续航中位数、分桶 SOC 为 `null` → `—`（停放另显示「分桶SOC变化缺失，不补零」）。
- 两类详情的 `missing` 走真实失败：行程详情 `/drives/17` 返回 503（明细 503，整页「服务暂不可用，请稍后重试」+「重试行程明细」），充电详情 `/charging-sessions/9/series` 返回 503（系列 503，三结果与电量弧保留、「重试充电曲线」）。两条都不展示假成功值。

## 每张证明什么

- `overview-*`：深色 hero（额定续航 + 电量环）、本月主数、每日里程主图与参照虚线；200% 下三读数换行、无裁切；空态不画全零，缺失 `—`。
- `drives-*`：期间主数 + 节奏条带 + 最近的路；空态 0.0 km / 0 趟 / 净电耗 `—` 与「这段时间还没有行程」。
- `charging-*`：深色费用 hero + 覆盖 + 三读数 + stem；空态「这段时间还没有充电记录」，不画全零补能图；缺失费用 `—`、次数 9 保留。
- `statistics-*`：结论 + 深色里程主图 + 2×2 章节；200% 读数换行不裁切；缺失不硬编码。
- `drive-detail-*`：地图/路线示意、三结果、速度曲线与电量区间（「出发/到达」）；empty 显示「无采样数据」。
- `charge-detail-*`：电量弧 hero 全出血（左右到屏幕边）、三结果 2×2 换行、功率曲线；missing 保留 46.8 kWh / ¥71.28 / 34 分钟。
- `topic-rhythm-*`：活跃天数、每日用车热图、证据 2×2。
- `topic-energy-*`：温度分组主数 + 分组点图 + 证据；空态「区间内无已完成行程」。
- `topic-charging-*`：已知支出 `¥186.4`、均价 `¥0.87/kWh`、覆盖 `8 / 9 次`、入电量走势、地点账目。
- `topic-range-*`：6/12 个月窗口、所选月中位数 432.0 km、P10–P90 波动带；空态「观察窗口内无充电记录」。
- `topic-parking-*`：有效窗口 SOC 变化 hero、分桶柱、状态分布；缺失显示「分桶SOC变化缺失，不补零」。

## 与原型 / 旧 C 的差异

1. 导航 active 标记在顶部（Spec §7.7 / ADR §6.1）；原型画在图标下方。
2. 概览 100% 下「最近」从首屏下缘开始，需轻微滚动；主图与读数完整在首屏。
3. 充电详情电量弧 hero 已全出血（VA09/VA12 修正）；`charge-detail-*` 为证。
4. 缺失统一 `—`；费用无币种时显示金额 +「币种未记录」，不默认 CNY。
5. 概览/统计没有 C 的彩色 tile 与五等权 tab；章节用 1px 分线；停放状态分布与分桶柱改为单绿色阶 + 灰阶（本轮由 Material 调色板改为 A token），分桶起点按本地日历显示（不再贴服务端 ISO）。
6. 补能专题在 0 条记录时展示真实 0 与「0 / 0 次」，不计入空态分支：该页的空态判定依赖请求失败前的 `totals == null`，本轮不改页面行为，图册按真实渲染记录。

## 验证

- `tool/flutterw analyze --no-pub`：通过（0 issue）。
- `tool/flutterw test --no-pub`：**352 通过、22 跳过**（跳过为 opt-in 渲染入口、历史 C 图册与平台占位）。
- 本目录 132 张由正式页面渲染；`a_gallery_render_test.dart` 对每页每态断言至少一条主数字/图表或空/缺失文案，断言失败会打印该页实际文本。
- 各页面另有 A 回归：`a_overview_test.dart`、`a_drives_test.dart`、`a_charging_test.dart`、`a_statistics_test.dart`、`a_drive_detail_test.dart`、`a_charging_detail_test.dart`、`a_micro_spark_test.dart`。

## 外部 gate（不因本图册通过而关闭）

- 真机字体回退、状态栏/安全区、TalkBack/VoiceOver。
- 真实站点数据、地图底图/CRS/许可、大陆网络。
- 性能（冷启动/概览/详情帧时间）与双端隔离构建验收。
- 360×800 之外的真实设备宽度与系统 reduce motion 手工体验。

## 复现

```sh
tool/flutterw test --no-pub \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/a-renders/gallery \
  --dart-define=MILEAF_RENDER_FONT="/System/Library/Fonts/Supplemental/Arial Unicode.ttf" \
  test/a_gallery_render_test.dart
```
