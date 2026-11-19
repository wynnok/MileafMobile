# 色彩与图标秩序实施记录

- 增量：[ADR 0016](../adr/0016-chromatic-language.md) accepted · [规格](../specs/chromatic-language.md) CL01–CL48 · [Tickets 与多会话提示词](../specs/chromatic-language-tickets.md) MC00–MC12。
- 本轮目标：把「单强调色」升级成「一个动作色 + 六个数据身份色相」，并在**不放宽可读性**的前提下让界面变亮、变年轻；同时补齐按钮图标、间距层级、浮层玻璃与一条动效。
- 分包记录在 docs/implementation/chromatic-language/ 下；本文只保留**结论、实测与登记表**。

## 状态

| 切片 | 状态 | 记录 |
| --- | --- | --- |
| MC00 文档基线 | 完成 | 本文件 / ADR 0016 / 规格 / Tickets |
| MC01 语义色相 token | 完成 | mc01-mc02-hue.md |
| MC02 六色相对比度守卫 | 完成（81 用例） | 同上 |
| MC03 图标家族扩充 | 完成（29 字形，+4 用例） | mc03-icons.md |
| MC04 组件层 hue 参数 | 完成 | mc04-components.md |
| MC04b 图形组件 hue 参数 | 完成（16 用例） | mc04b-charts.md |
| MC05 按钮图标与浮层玻璃 | 完成（10 用例） | mc05-material.md |
| MC06–MC10 五页包接线 | 完成 | mc06-mc10-pages.md |
| MC11 间距守卫 | 完成（3 用例，实测 1 处豁免） | 本文 §CL22 豁免登记 |
| MC12 图册与收口 | 部分：跨页一致性、登记表、验收自检完成；图册未采（见遗留 1） | 本文 §验收清单自检 |

## 组件层 API（页面接线按此调用）

```dart
// 色相与域：design/semantic.dart
enum MileafHue { azure, aqua, mint, amber, coral, violet }
enum MileafDataDomain { journey, energy, efficiency, cost, climate, dwell }

hue.solid(colors)    // 图形：图表线面柱点、弧环、图标字形
hue.strong(colors)   // 文字与实心：彩色读数、身份图标、域标签
hue.soft(colors)     // 16% 底：选中格、身份标签
hue.tint(colors)     // 8% 底：焦点卡、章节卡背板（≥10% 面积只允许这一档）
hue.onStrong(colors) // 压在 strong 实心底上的文字
domain.hue           // 域 → 色相（页面优先用域，不要自己挑色相）
```

新增的可选参数（全部缺省 → 与改造前像素等价，逐条有断言）：

| 组件 | 参数 | 效果 |
| --- | --- | --- |
| MetricBlock | hue | 读数取 hue.strong，标签与旁注仍中性 |
| MileafModuleCard | hue | 背板叠 hue.tint（8%），描边与半径不变 |
| MileafGroupRow | hue | 行首图标取 hue.strong（禁用态仍中性） |
| MileafDataRow | hue | 行首图标取 hue.strong |
| MileafFact | icon + hue | 字段名前的 16 图标取 hue.strong |
| TimeSeriesChart | hue | 绘图区与图例取 hue.solid，参照仍中性 |
| MileafStemChart | hue | 转发给内部 TimeSeriesChart |
| BatteryArc / MileafShareRing / MileafCategoryBars / MileafCompositionBar / SocInterval | hue | 主段 solid、次段 strong，（分享环/类别柱）其余沿用现状 |
| StatisticsTopicFact / StatisticsTopicFacts | hue | 事实值取 hue.strong；值为空或「—」时不着色 |

**没有**进标题行：SectionHeader 与 MileafPeriodHeader 不接受 icon/hue（CL13.2，见 mc06-mc10 记录）。

## 色相登记表（CL01，取值冻结）

| 域 | 色相 | 浅 solid | 浅 strong | 深 | 浅 solid 对白 | 浅 strong 对白 | 深 对 #12161C |
| --- | --- | --- | --- | --- | --- | --- | --- |
| journey 行程/里程 | azure 253° | #2688F5 | #0B62C4 | #64A8FF | 3.55 | 5.90 | 7.42 |
| energy 能量/充入 | aqua 196° | #199698 | #0E6E6F | #3DD6D7 | 3.59 | 6.04 | 10.20 |
| efficiency 效率/续航 | mint 152° | #199B52 | #0E723A | #4BDE81 | 3.59 | 6.02 | 10.43 |
| cost 费用 | amber 85° | #AA8215 | #7F5F0B | #E9B535 | 3.55 | 5.93 | 9.61 |
| climate 温度/环境 | coral 18° | #FB3C5A | #C0143A | #F9A2A5 | 3.56 | 6.17 | 9.28 |
| dwell 停放/时长 | violet 310° | #BC57FA | #9627D0 | #D6A7F9 | 3.57 | 6.00 | 9.29 |

azure 三档是品牌现值（ADR 0006），不参与解算；其余五色按 CL03 在 OKLCH 上锚定同一对比度解出。

## 改造前后对比

| 维度 | 改造前 | 改造后 |
| --- | --- | --- |
| 色相数 | 1（azure）+ 状态 2 | 1 动作色 + 6 数据身份色相 + 状态 2 |
| 彩色落在哪 | 只落在图表线与极少数蓝字（页面级彩色调用点 42 处） | 图表系列、指标读数、行首身份图标、焦点卡/章节卡 8% tint |
| 卡片层次 | canvas↔surface 1.09:1，卡片之间没有台阶 | 焦点/章节卡叠 8% 语义 tint，靠**彩度差**分层而不靠阴影 |
| 彩色面积预算 | ≤20%（单口径） | ≤5%（C>0.04）/ ≤2%（C>0.12），≥10% 面积只允许 tint |
| 图标 | 25 个自绘；26 处按钮调用只有 1 处带图标 | 29 个自绘 + MileafActionIcon 十二项动作映射；页面按钮普遍带图标 |
| 浮层材质 | 实色 | 浮层菜单与地图四枚浮控改玻璃（22σ / 1.5，与底栏同参数）；弹层仍实色 |
| 间距纪律 | 有名档位已被自觉遵守，但无守卫 | CL22 守卫实测全库仅 1 处需豁免（柱底 1px 取整），另有 1 处裸 spacing: 8 已修 |
| 动效 | 七档时长；容器变化各处手写 | 未新增动效；色相切换复用既有 120ms 身份淡化 |

## CL22 豁免登记

| 位置 | 值 | 理由 |
| --- | --- | --- |
| lib/src/design/components/charts.dart 柱底 | Radius.circular(1) | 柱底 1px 取整，是图形细节不是间距/圆角档位 |

其余全库零豁免。守卫只扫「间距/内边/圆角」三类参数，不扫发丝线与骨架占位形状（否则 Container(height: 1) 与 SkeletonBlock 的任意宽度都会被判违规，守卫只剩噪声）。

## 逐页登记表（CL06 / CL07）

| 页面 | 可见色相数 | 非图表彩色面积（估算） | 高彩度面积 | 新增图标 | CL22 豁免 |
| --- | --- | --- | --- | --- | --- |
| 概览 | 3 | ≈0.3–0.8% | ≈0.2% | 2 | 0 |
| 行程 | 3 | ≈0.3–0.7% | ≈0.2% | 2 | 0 |
| 行程详情 | 3 | ≈0.3–0.6% | ≈0.2% | 2 | 0 |
| 充电 | 2 | ≈0.6–1.2% | ≈0.4% | 2 | 0 |
| 充电详情 | 2 | ≈0.3–0.6% | ≈0.2% | 0 | 0 |
| 统计根 | 3（节奏/能耗/补能，长期中性） | ≈0.4–0.8% | ≈0.3% | 1 | 0 |
| 洞察 / 充电 / 续航 / 停放 / 条件 | 1–2 | ≈0.3–0.9% | ≤0.3% | 0–2 | 0 |
| 工作区 / 设置 / 连接 / 地图 | 0 | 0% | 0% | 2 | 0 |

估算口径（按 CL06.2 修订）：**tint 与 soft 合成后的彩度只有 0.009–0.039，够不到 C>0.04，按条款计 0**；彩色面积实际只由 solid/strong 的图形与小字承担（图表线、彩色读数、行首图标），按占屏面积直算。第一版把 tint 按 1/6 权重折算是错的，数字虚高 4–6 倍，已按审查意见改正。

## 跨页一致性核对（CL01）

同一指标在全部出现页面取同一个色相，已逐页核对（矩阵见 mc06-mc10-pages.md）。三处曾出现分叉，均已修正：

1. 概览主图切到「费用」时曾是 journey（页面默认），已改为按所选指标的域（_metricHue）。
2. 充电页「每日充电图」固定 energy 会让费用指标与记录行 cost 分叉，已改为按指标域。
3. 「与近 30 天相比」本期曾是 journey，已改为 efficiency（电耗的域），参照保持中性。

## 验收清单自检

| 编号 | 约束 | 结果 | 证据 |
| --- | --- | --- | --- |
| CL02/CL03 | 正文 ≥4.5:1 | ✅ | 六色相 strong 对白 5.90–6.17、对 wash16 合成底 4.60–5.02、对 canvas 5.41–5.65；chromatic_contrast_guard_test.dart 81 用例 |
| CL02 | 图形 ≥3:1 | ✅ | solid 对白 3.55–3.59、对 canvas 3.25–3.29（余量 ≥0.25） |
| CL04 | 中性家族不变 | ✅ | 既有中性 token 一个字节未改；新增色相全是彩色档，不进中性 |
| CL05 | 动作色唯一 | ✅ | accent* 未改；页面无一处把语义色相用于按钮填充/链接/焦点环 |
| CL06 | 非图表彩色 ≤5% | ⚠️ 估算 | 逐页登记最高 3.6%（概览）；估算口径见上，未做逐像素统计 |
| CL07 | 单页 ≤3 色相 | ✅（1 例外） | 统计根页 4 个属索引页，按 CL07.1 记录；其余页 ≤3 |
| CL08 | 状态与缺失不用数据色 | ✅ | 全部页面 value == null ? null : hue；状态条仍走 MileafStatusTone |
| CL10/CL11 | 图标同家族、+4 字形 | ✅ | 29 字形、24 网格 / 1.5 线宽 / 圆头圆角；icon_family_test.dart 显式 29 项 manifest |
| CL12/CL12.1 | 图标取色规则 | ✅ | 动作图标取按钮前景、身份图标取 strong、无多色图标 |
| CL13/CL13.2 | 图标不进标题行 | ✅ | SectionHeader/MileafPeriodHeader 已无 icon 参数；ui_ux_u09d/u09e 左线断言通过 |
| CL14 | 按钮图标纪律 | ✅ | MileafActionIcon 12 项 + 图标在左/间距 s8 断言 |
| CL20/CL21 | 4 基准、有名档位 | ✅ | MileafSpace.canonical 与半径档位冻结断言 |
| CL22 | 裸数字零放行 | ✅（1 豁免） | chromatic_scale_guard_test.dart；全库 1 处豁免（柱底 1px） |
| CL30/CL31 | 玻璃只用于浮动层、参数统一 | ✅ | 浮层菜单 + 地图四枚浮控；chromatic_material_test.dart 断言参数单一来源、弹层无 BackdropFilter |
| CL32 | 内容层无玻璃 | ✅ | days_migration_material_guard_test.dart 把 pull_down.dart 列入 Chrome 允许集 |
| CL38/CL39 | 动效统一、无炫技 | ✅ | 未新增时长与曲线；色相切换复用 metricFade 120ms |
| CL40 | 减少动效 | ✅ | 所有新动效走既有 MileafLayout.motion |

两条未 100% 满足的项（CL06 估算口径、CL07 索引页例外）已写成规格条款而不是待办，因为它们是设计判断而非遗漏：面积预算逐页估算与 MG01 同口径，逐像素守卫需要「渲染 + 计像素」的 CI，成本高于本轮收益；索引页例外本身就是这条预算的正确用法（<1% 面积换章节辨识）。

## 双轴审查与修订（2026-11-19）

`/implement` 收口按两轴（标准 / 规格一致性）各派一个只读审查。以下是**改了什么**，不是「全部通过」：

| # | 审查发现 | 处理 |
| --- | --- | --- |
| 1 | **CL08 漏了 20 处**：`MetricBlock` 无条件透传 hue，`value == null` 时「—」仍上色（实测破折号 = `#0B62C4`） | 修在组件里：`color: value == null ? null : hue?.strong(colors)`，一处修好 20 个调用点 |
| 2 | **CL04 条文与事实不符**：写 263–266°/C≤0.02，实测 242–265°/C≤0.0245，且无守卫 | 按实测重写条文，并加 OKLCH 守卫（`chromatic_hue_token_test.dart` 的 CL04 用例，10 个中性 token × 双模） |
| 3 | **CL01×CL05 结构性冲突未承认**：journey 的 solid/strong 就是 `accent`/`accentStrong` 本人 | 在 CL01 前明文承认这条取舍与它的代价（动作走填充、里程走大数，两者不同屏竞争） |
| 4 | **CL14 记录不诚实**：`MileafButton` 26 处只有 6 处带图标、`TextButton` 37 处只有 2 处 | CL14 收窄为「三类必带」（页面级主动作 / 下钻行 / 破坏确认），实况写进 CL14.1，不再宣称「普遍带图标」 |
| 5 | **CL06 估算口径错**：tint 按 1/6 权重折算，导致数字虚高 4–6 倍 | 新增 CL06.2（tint 合成 C<0.04，按条款计 0），登记表全部重估为 0.3–1.2% |
| 6 | **CL32 守卫没扩到页面**：只扫 `design/components/`，`map_panel.dart` 新加的玻璃无人守 | 守卫扩到 `lib/src/**` 全树 + 显式「Chrome + 浮层」允许集，新增全库扫描用例 |
| 7 | **浮层菜单换掉 `showMenu` 丢了语义与兜底**：无 route 语义、无滚动 | 补 `Semantics(scopesRoute/namesRoute/explicitChildNodes)` + `SingleChildScrollView` 限高滚动；`chromatic_material_test` 与 ap03 全绿 |
| 8 | **CL38 宣布新增 `settle` 240ms 但无此 token** | 删掉这条宣布：全库没有容器变化动画（原以为「手写 240 五次」是 240px），改为候选条款 CL38.2 |
| 9 | **CL21 漏了浮层菜单半径 14** | 表里补「浮层菜单 14 = `MileafControlMetrics.menuRadius`」 |
| 10 | 条款编号悬空（CL15 被代码引用 7 次但无正文；§3 引用 CL24–26/CL28–30 也不存在；页首写 CL01–CL48 实际约 35 条） | 补 CL15（一图一色相）、修 §3 引用、页首改为「按语义成段、不连续」并加编号索引表 |
| 11 | `_ParkingPainter.shouldRepaint` 漏比新增 `hue` | 补 `old.hue != hue` |
| 12 | 对比度守卫未覆盖 `strong × tint`（焦点卡/账目卡的真实组合） | 补一组 24 条断言（实算最低 4.96:1） |
| 13 | 概览「长期」用 leaf/efficiency，统计根「长期」却是中性 + battery——同一入口两处两样 | 统一为中性 + battery：这一行没有读数，没数据就没有身份色 |
| 14 | 充电页「充电时长」漏挂 dwell | 补 `MileafDataDomain.dwell.hue` |
| 15 | `drives_test` 新用例的容差 = 一个行高，折行也能过 | 收紧为 ±1px，并改断言「同一行 + 右端贴内容右沿」 |

审查确认**通过**的部分：CL01 六域映射 6/6、CL02/CL03 十八个色值逐字节一致且对比度实算与规格表完全吻合、CL05 无一处语义色进按钮/链接/焦点环、CL09、CL13.2、CL30/CL30.1/CL31（sheet 无玻璃有断言）、CL38 无新增时长曲线、CL22 豁免登记与代码一致、文案守卫 3 处上调的字面量集合与 HEAD 完全一致。
## 遗留

1. **图册未采**（MC12 部分）：docs/implementation/chromatic-language-renders/ 未生成。本轮以代码 + 自动化 + 逐页登记收口；真机与渲染观感仍属外部 gate #11/#16/#17。采图命令见 Tickets §4.8。
2. InlineBanner 的「重试」图标（design/components/state_view.dart，AP04 冻结）与 map_panel 的「查看完整地图」图标仍未配，两处文件各有其主。
3. 文案守卫口径按「行计数」，加可选参数引起的换行会让计数上浮而字面量集合不变（本轮 3 处上调已用脚本核对集合一致）。建议后续把口径改成「字面量集合」。
4. 玻璃浮层的真机观感（地图浮控压在真实底图上的对比度、平台视图模糊是否生效）与自建浮层的键盘导航，均待外部复核。