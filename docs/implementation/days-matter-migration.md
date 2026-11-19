# 理念迁移实施与验证（DM00–DM08）

> 2026-11-19。实施依据：[ADR0015](../adr/0015-days-matter-language-migration.md)（accepted，D1–D4 用户确认按推荐）、[迁移规格](../specs/days-matter-migration.md)（MG01–MG09）、[实施 Tickets](../specs/days-matter-migration-tickets.md)。逐包细节见 [days-matter-migration-color.md](days-matter-migration-color.md)、[days-matter-migration-icons.md](days-matter-migration-icons.md)、[days-matter-migration-state.md](days-matter-migration-state.md)、[days-matter-migration-dm05.md](days-matter-migration-dm05.md)、[days-matter-migration-dm06.md](days-matter-migration-dm06.md)、[days-matter-migration-dm07.md](days-matter-migration-dm07.md)。

## 提交

| Commit | 内容 |
| --- | --- |
| `7658a57` | DM00：ADR0015 accepted（确认记录落档）、apple-polish 登记 PD12/PD13、ui-ux-refinement R07 扩展、规格与 tickets 入库 |
| `c2af0c6` | DM01/DM02/DM04：状态取色映射与对比度守卫、图标家族统一出口、StateView/InlineBanner 三要素与空态四档文案 |
| `738ff58` | DM03：MileafNumber 值变更 120ms 交叉淡化（PD13）、概览/行程卡头→焦点值 s12（PD12）、M09 现状登记已满足 |
| 本次（见下「工作区状态」） | DM05/DM06/DM07 页面包与集成收口 |

## 逐包事实摘要

- **DM01（MG01–MG03）**：`MileafStatusTone` 四档映射常量入 semantic.dart（additive，零现值改动）；对比度守卫 `days_migration_color_guard_test` 60 用例（正文 ≥4.5、图形 ≥3.0，浅深两套，实测摘要见 color.md）；textFaint 裁决=现值 #63707C/#7E8A96 保留（以 overview-chart-header.md:79 复测口径为准），overview-reading.md 文末批注订正。彩色面积登记表建立（估算法）。
- **DM02（MG04）**：盘点确认 25 个自绘图标已由 AP01 集中于 `lib/src/design/icons.dart` 单一 painter（页面直绘=0、Material Icons=0）；`components/icons.dart` 以 export 桥接 + `MileafIconFamily`（24 网格/1.5 描边/圆头圆角，与 tokens 同源）+ 25 条读屏语义（copy 基线 25）；painter 实现体迁移留 TODO（评估：桥接出口已满足「统一出口」，迁体需改 18 处 import 且涉在途 barrel，收益为零行为差异——列为候选不执行）。
- **DM03（MG06/MG08）**：`MileafNumber` 接入 120ms 交叉淡化（减动效归零、旧值移出语义树、当前值排 Stack 首位——顺带修复 ap04 单帧读旧值问题）；概览/行程卡头→焦点值 s4→s12；charts.dart M09 淡入与拖动即时已满足，不改；360×800 首屏实测未触发退让阶梯。
- **DM04（MG09）**：StateView 整页/compact 三要素（statusLine + compact 文字动作槽 44 命中）；InlineBanner 事实修正——组件在 state_view.dart 且原为三值枚举，收敛为四档 `BannerTone`（neutral/warning/error/accent，转发 `MileafStatusTone` 解析器），全库调用点零视觉变化；空态四档共享构造 `lib/src/copy/state_feedback.dart`（copy 基线 7）。
- **DM05（概览+行程）**：行程记录行 meta 串 → 「标题行 + 三格 metricSm 读值网格」（MG05，同构充电行）；分组标题 inset 迁移（MG05b）；三条失败状态条补「数据截至 HH:mm」（MG09）；彩色面积登记 概览≈1.5%/行程≈0%。
- **DM06（充电）**：详情两处错误块迁三要素 InlineBanner；记录错误条补时间行；空态四档（离线档零触发已登记）；R24 两条起始线守卫新增；彩色面积 ≈1.5%/1%；图册 14 张。
- **DM07（统计+设置+详情+连接）**：统计首页两条整页失败路径、五专题空态四档、连接/连接管理/初始化失败反馈 tone 化（消除包内最后一批裸 `colors.error` 文字）；inset 迁移连接管理两处（MetaPage 归 DM05）；图标出口全量切换（本包 9 页）；MG02 取色核对全部符合，1 处纹理刻色待裁定（见遗留）。
- **DM08（本包）**：修复 `state_feedback.dart` 裸值基线缺口（0 裸值）与两个 U 系列断言映射（见「结构映射记录」）；采集入库图册；全量验证；本记录与 AGENTS 条目。

## 结构映射记录（测试断言随结构更新，业务语义未放宽）

1. `ui_ux_u09a`：筛选无结果空态「没有匹配行程」→「筛选后没有已完成行程」（共享构造，object=已完成行程）；「未知匹配数不补零（— 趟）」断言原样保留。
2. `ui_ux_u09d`：续航样本不足空态「尚无有效续航样本」→「这段时间没有有效续航样本」；新增断言能力说明「有效样本不足时不推算额定续航。」仍在（原意图保留）。
3. `a_gallery_render_test` 图册 markers：四处专题空态文案映射到分档构造输出。
4. 各页包既有断言更新清单见各包实施记录；copy guard 基线变化（升随结构登记、降放行）见各包记录。

## 验证

- `tool/flutterw analyze`：全仓 3 条诊断，均为既有基线（`creator/video/...` 工作区 2 条——该目录不入库、`test/apple_polish_ap10_test.dart:342` info 1 条）；本增量文件 0 诊断。
- `tool/flutterw test` 全量（**取得于含在途改动的工作树**，HEAD 提交树需叠加「工作区状态」所列文件方可全绿）：首轮 1170 过 / 55 跳过 / 2 失败（`ui_ux_u09a`/`ui_ux_u09d` 为 DM07 空态分档后的断言映射缺口）；修复后复跑 1172 过 / 55 跳过 / 0 失败；双轴审查修复后**终值 1176 过 / 55 跳过 / 0 失败**（新增：连接页证书失败用例、MG07 材质守卫 3 用例；MG06 两组移入 spacing 测试文件）。
- 守卫：对比度 60 用例、文案守卫（基线登记后全绿）、裸值守卫（state_feedback 0）、图标家族、动效 8 用例、状态三要素 16 用例。
- 图册：`docs/implementation/days-matter-migration-renders/`——dm03-spacing 4 张（PD12 首屏浅深×两页）、dm05 8 张、dm06 14 张；浅深目验通过，彩色面积登记行见 color.md。

## 遗留与待用户裁定

1. **对比度豁免 4 条（待裁定）**：textFaint × segmentTrack（浅 4.17）、textFaint × accentSoft（浅 4.19 / 深合成 4.45 / 3.96）。均为占位/禁用类文字压装饰底，同底 textSecondary ≥4.5；如需抬档属调色板层独立改动（禁改未动）。
2. **停放纹理刻色（待裁定）**：`_StateSegmentPainter` 纹理刻色固定 `canvas`，宿主为 `surface` 卡面，浅深均有轻微明度差；属纹理层取值，按边界只登记不改。
3. **BannerTone 命名**：保留 `BannerTone` 为 InlineBanner 受限参数枚举（已 1:1 转发 `MileafStatusTone`）；不做全库改名（约 40 处调用点，零行为收益），tickets 中「改名收口」按此豁免。
4. **离线档零触发**：四档分档的 offline 档暂无连通性信号触发路径（充电/统计），需数据层立项后接线；文案已就位。
5. **禁改文件的 tone 化**：`currency.dart` 与 `session_pages.dart` 的 error 反馈仍为旧形式（文件在禁区），列为后续候选。
6. **MG01 量化口径**：登记表为渲染目验估算法；充电页已有精确图册，其余页精确量化列为候选。
7. **混合文件未提交**（见下）。

## 工作区状态（重要）

工作树在实施前已有他人在途未提交改动（Apple 焕新 AP 系列、period-header 切片、底栏相关：`lib/src/overview_page.dart`、`drives_page.dart`、`design/components.dart`、`tokens.dart`、`page_bar.dart`、`copy/dates.dart`、`test/design_components_test.dart`、`drives_test.dart`、`navigation_bar_test.dart`、`AGENTS.md`、`ios/Podfile.lock`、period_header 全套）。本增量的 overview/drives 改动（s12、行程记录行网格、三要素接线）与这些在途改动**同文件叠加**，无法按路径干净分离；按「不卷入他人在途改动」原则，以下文件**保持未提交**，待在途切片落地后一并处理：

`lib/src/overview_page.dart`、`lib/src/drives_page.dart`、`test/overview_test.dart`、`test/drives_test.dart`、`test/apple_polish_ap07_test.dart`、`test/a_drives_test.dart`、`test/days_migration_dm05_render_test.dart`、`test/days_migration_spacing_test.dart`（依赖两页在途结构与 period-header 组件）。

其余 DM05–DM07 成果（充电/统计/设置/连接/详情/地图设置页及其测试、基线、图册、实施记录）已选择性提交。AGENTS.md 条目追加在工作树（同文件有在途条目），随在途改动一并提交。

## 双轴审查与修复（DM08 收口）

审查汇总见 [days-matter-migration-review.md](days-matter-migration-review.md)。修复项：

1. **连接页证书校验失败回归（真 bug）**：`HandshakeException` 分支漏置 `failed`，失败被渲染为成功样式——补 `failed = true` 并新增用例（MockClient 抛 HandshakeException → error 状态条 + 重试）。
2. **充电记录空态双报**：失败分支回退为空白语义，三要素由页尾错误条承担。
3. **MG07 守卫补齐**：新增 `test/days_migration_material_guard_test.dart`（内容层组件禁引玻璃材质/类型，排除集 = page_bar/top_bar/nav_bar/glass_surface/navigation_material/components barrel；3 用例全绿）。
4. **MG06 测试拆分**：页级间距断言移至 `test/days_migration_spacing_test.dart`（工作树，随 DM05 页面接线与在途切片一并提交），`days_migration_motion_test.dart` 瘦身为纯组件级 MG08 用例，消除「已提交测试引用未提交组件」的 HEAD 编译断裂。
5. 验收口径修订见规格 §9（MG01 图册估算法口径、MG04 opt-in 图板、MG06 before 豁免、MG09 连接页场景修订、MG05b 画布层豁免）。

## 外部边界

真机字体/材质/读屏、真实站点/地图、性能（#16 每平台每指标 ≥30 样本与 p95 预算）与整机验收由 #11/#16/#17 承载，不因本增量关闭。本次未推送。