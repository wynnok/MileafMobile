# MC03 记录：图标家族扩充 4 个字形

## 做了什么

- `lib/src/design/icons.dart`：`MileafIconName` 追加 `leaf` / `thermometer` / `speed` / `share`；painter 追加四个 `case`，只用既有的 `moveTo/lineTo/cubicTo/addArc/addRRect/addOval` 与 `filled` 列表，**没有新增绘制 API、没有第二套图标库**，既有 25 个字形的路径一个字未动。
- `lib/src/design/components/icons.dart`：`MileafIconFamily.semanticLabels` 追加四句——「续航与效率」「温度」「速度」「分享」；既有 25 条语义一字未动。
- `test/icon_family_test.dart`：家族清单由隐式读枚举改成**显式 29 项 manifest**（多一个字形必须显式改这里），新增「MC03 新增四字形（CL11）」组 4 个用例：清单 29 与枚举一致、四句语义登记、16/20/24 等比缩放与 24 视觉盒内、`leaf` 在 16 视觉盒下仍读成两瓣+中脉。既有断言一条未放宽。
- 跨票连带（合同 §5）：`test/support/copy_guard_baseline/icons.dart.txt` 25 → 29——新增 4 句中文 `semanticLabel` 会让 `components/icons.dart` 的中文字面量行 25→29，基线按 basename 归属本文件，故上调并在此写理由。
- 跨票连带（合同 §6⑥ → 总控授权 A 后就地改）：`test/apple_polish_ap01_test.dart`（`values.length` 与 `findsNWidgets` 两处 25→29、测试名「25 个图标」→「29 个图标」）、`test/design_tokens_test.dart`（`values.length` 25→29、测试名同改、注释补一行 MC03 来由）。断言语义未变，只是图标总数跟着家族走。

## 绘制要点（24 网格 / 1.5 描边 / 圆头圆角 / 无填充，CL10+CL11）

| 字形 | 语义 | 坐标（网格单位） |
| --- | --- | --- |
| `leaf` | 续航与效率 | 轮廓 `(12,20.2) → cubic(5.5,17.0)(5.5,7.4)→(12,4.2) → cubic(18.5,7.4)(18.5,17.0)→(12,20.2)`；中脉 `(12,20.2)→(12,6.4)`；叶柄 `(12,20.2)→(12,21.6)`。最宽处 x≈5.63/18.37（宽 12.75），中线 y≈12.2；不加叶脉 |
| `thermometer` | 温度 | 药丸球管 `RRect(x9.9,y3.4,w4.2,h11.2,r2.1)`；圆球 `addOval(center 12,17.6,r3.1)`（球顶 14.5 接球管底 14.6）；刻度 `(6.6,8.4)-(8.6,8.4)`、`(6.6,11.6)-(8.6,11.6)`、`(6.6,14.8)-(8.6,14.8)` |
| `speed` | 速度 | 表盘 `addArc(center 12,14.6, r7.4, start π, sweep π)`；指针 `(12,14.6)→(8.9,10.4)`（10 点钟）；中心实心点 `filled` r1.15 |
| `share` | 分享 | 三节点 `addOval`：(18,5.8) / (6,12) / (18,18.2)，均 r2.1；连线 `(7.9,11.0)→(16.1,6.9)`、`(7.9,13.0)→(16.1,17.1)`（起止落在左中圆与右侧圆的切点处） |

四个字形笔画外接框实测均在 0.5–23.5 内（`test/icon_family_test.dart` 逐字形像素探针）。

## 证据

- `./tool/flutterw analyze --no-pub`：3 条既有诊断（`creator/` 2 条 + `test/apple_polish_ap10_test.dart:342` 的 `prefer_interpolation_to_compose_strings`），本票 4 个改动文件 0 诊断。
- `./tool/flutterw test --no-pub test/icon_family_test.dart`：8 通过 / 1 跳过（跳过的是 opt-in 渲染入口 `DM02`，需 MILEAF_RENDER_OUTPUT/FONT）。
- `./tool/flutterw test --no-pub test/apple_polish_ap01_test.dart test/design_tokens_test.dart`：41 通过 / 0 失败（守卫改到 29 后复跑）。
- 全量快照 `./tool/flutterw test --no-pub`（收尾前一次）：1283 通过 / 55 跳过 / 5 失败——其中 3 条就是上面那三处 25 守卫（已改并复跑绿），另 2 条 `days_migration_material_guard_test` 是 MC05 在途改 `pull_down.dart` 玻璃的瞬时红（单独重跑已绿，归 MC05）。按总控要求收口时**不再重跑全量**：当时 5 个页面包 agent 并发改 overview/drives/charging/statistics/session，全量必然是噪声。
- 渲染自检（临时机位，跑完即删，图不入库）：16 / 20 / 24 / 48 四档、浅深双模式。`leaf` 16px 仍是「左瓣 · 中脉 · 右瓣」三段；`thermometer` 药丸+圆球+三刻度可辨；`speed` 半圆+指针+中心点成表盘；`share` 三节点两连线清晰，深色同形。

## 遗留

1. 三处图标总数守卫已按总控授权 A 改到 29（见「做了什么」最后一条）；收尾后的**最终全量**由总控在 MC12 合并后统一跑——本票只保证这 5 个文件与 `icon_family_test` 自测绿。
2. `thermometer` 在 16px 下三条刻度距管壁 1.3 网格单位（≈0.87px），视觉略「粘」。按 CL11 给定坐标原样实现；若视觉裁定要留白，把刻度线收到 `(6.8,…)-(8.4,…)` 即可，属视觉裁定不属本票自裁。
3. `leaf` 取规格措辞「两条对称三次贝塞尔」，形制偏「立叶/眼形」。要更像叶需改非对称控制点，同样留视觉裁定。
4. 本票不出图册：按 MC12 统一归档；本轮只做临时自检渲染，未在仓库留图。

## 收口（总控合并后）

合并全部切片后的终验：`analyze --no-pub lib test` 仅 1 条既有 info；全量 **1334 通过 / 55 跳过 / 0 失败**（基线 1176，新增 158 个用例）。本票的三处 25→29 守卫断言在终验中全绿。