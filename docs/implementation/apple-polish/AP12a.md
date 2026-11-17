# AP12a 专题：节奏、能耗、补能（P07 日历重做、P08 点图与步进、P09 充电费用）

## 1 票号与会话

- 票号：AP12a（W4，专题三页）。会话：lead（root）。模型：DeepSeek-V4.1-Flash（DSH agent）。日期：2026-11-17。
- 输入冻结点：FP3 = eeefe83（工作树从 FP3 登记提交 8ea7e29 创建）。分支：`codex/apple-polish-ap12a`。
- 工作目录：/Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile-ap12a。
- 开工核对：pwd、分支 codex/apple-polish-ap12a、HEAD 8ea7e29、git status 空，与租约表一致；命令前缀 MILEAF_FLUTTER_SDK=<主仓库>/.tooling/flutter。
- 必读：规格 R25/R29/R30、§5 P07–P09、§6；文案 CP10 与专题对照表；fp3-freeze.md、shared-symbols.md、AP07 交接；AP04/AP05/AP06 组件与文案 API。
- 结果 SHA：本票本地提交（见 git log，未推送）。

## 2 修改文件清单与 API 差异

### 2.1 持有文件（本票提交）

| 文件 | 变化 |
| --- | --- |
| lib/src/statistics_usage_page.dart | P07：身份块（用车节奏 + DF3 区间 + 按开始日期统计）、结论卡（用车 N 天 metricLg + 共 X km，平均每个用车日 Y km + 今天尚未结束）、日历卡（MileafGroupCard 无裁剪：无可见描边框、四档填充加纹理、日期 caption、数值 subheadline 600、零显 0、未知显 —、选中 2px accent 环、离卡缘 8/格距 inline2 保七列每格 ≥44）、样本明细卡（MileafModuleCard 包裹、平均记录速度→平均速度）、距离分组与星期节奏改分组卡 + 行间发丝线、页尾 MileafDataNotes 五类、CP07 状态句（staleMessage/readFailedMessage/loadingMessage/emptyMessage）、证据页改「N 趟 + 区间，按开始日期统计」、行文案「电耗」、重试统一「重试」（Semantics 补对象） |
| lib/src/statistics_conditions_page.dart | P08：身份块（不同温度下的电耗 + 刷新圆钮）、结论卡（空格组标签「−10 至 −5°C」+ metricLg + 样本较少，仅供参考 + 只反映相关性，不代表因果或优劣）、主图卡（电耗（按里程加权）/按行程平均气温分组，每组 5°C + ‹›步进圆钮（tooltip 上一组/下一组，两端禁用）+ 温度组分段保留胶囊化）、样本明细（候选→参与、有效配对→有效、平均记录速度→平均速度）、查看该温度组行程→查看这些行程（MileafGroupCard+GroupRow 下钻行）、距离分组卡、距离组覆盖与该组覆盖并入页尾说明、技术详情收 snake_case 与阈值 |
| lib/src/statistics_charging_page.dart | P09：身份块（充电费用 + 按结束日期统计，仅含已完成的充电 + 刷新圆钮）、结论卡（已记录费用 metricLg + N 次中 M 次有费用 + 充入均价 X/kWh + 币种旁注 + 覆盖进度条移除）、主图（每日充电量/每日已记录费用/充入均价/每日充电次数，readoutScale detail、删「点按读值」trailing）、样本明细（充入电池→充入电量）、充电方式（SectionHeader 改名 + 分类时长三行 MileafGroupRow 按 CP03 分级，大字走 meta 第二行）、充电地点（地点行 meta 逗号化 + 查看 AC 充电/查看 DC 充电/查看未知类型/查看这段时间的充电）、页尾 MileafDataNotes（ended_at 等技术口径进技术详情） |
| test/statistics_usage_test.dart、test/statistics_conditions_test.dart、test/statistics_charging_test.dart | 本票持有测试的等价定位更新（用车 N 天/用车节奏/样本明细/平均速度/查看这些行程/充电费用/已记录费用/充入均价/充电方式/每日充电量/重试） |
| test/ui_ux_u09a_test.dart、test/ui_ux_u09b_test.dart、test/ui_ux_u09c_test.dart | 本票持有回归的定位更新（含渲染入口的说明折叠改 MileafDisclosure、每日记录/日期矩阵标签删除、组标签空格、步进圆钮定位） |
| test/apple_polish_ap12a_test.dart | 新建：P07 8 例 + P08 3 例 + P09 3 例（骨架、对照表、CP07、步进、渲染树探针） |
| test/apple_polish_ap12a_render_test.dart | 新建：正式渲染入口（opt-in） |
| test/support/copy_guard_baseline/{statistics_usage,statistics_conditions,statistics_charging}_page.dart.txt | 本票源文件对应基线：81（持平）、50（持平）、61→59 |
| test/charging_reading_test.dart、test/navigation_bar_test.dart、test/overview_statistics_reading_test.dart、test/reading_integration_test.dart、test/owner_experience_test.dart | 总控持有：按 §3.3「失败以补丁提交」口径先落地等价定位修正，见 §7，请总控复核 |

### 2.2 公开符号

- StatisticsTopicFacts 构造签名不变，title 默认值 证据→样本明细（对照表 CP02/CP05，调用方无变化）。
- StatisticsTopicNotes 构造签名不变；内部 ExpansionTile 改 MileafDisclosure（R30.3，AP12b 调用不受影响；AP14 清理适配层）。
- conditionsShortLabel 增加伴随函数 conditionsSpacedLabel（页内私有使用、公开导出，供结论卡空格标签）；usageValue/usageMap/usageItems/openDrivingEvidence/DrivingEvidencePage/StatisticsTopicFact 签名不变。
- 未新增/删除任何冻结符号；statistics_usage_page.dart 的 StatisticsTopicNotes、StatisticsTopicFacts、usageValue、usageMap、usageItems 签名逐一核对未变。

### 2.3 冻结符号

未触及：S01–S08、全部路由与回调（openDrivingEvidence 筛选参数、openRecords、openBucket 语义不变）、全部 Key（usage-daily-plot、conditions-plot、charging-topic-plot）、请求类型与参数、数据算法、依赖与锁文件、*.g.dart、token/组件/动效/首屏预算（FP3 冻结表）。

## 3 规则映射表

| 规则 | 符号 | 测试 | 图像/证据 |
| --- | --- | --- | --- |
| R25 专题骨架（身份块→结论卡→主图卡→样本明细→关于这些数据） | _identity/_conclusion/_calendarSection/_factsSection/_dataNotes（三页） | ap12a「身份块写出区间与统计口径」「结论卡」「页尾关于这些数据五类」 | AP12a-* 渲染图册 |
| P07 日历重做 | _dayCell/_UsagePattern/_UsageSwatch | ap12a「日历格子无描边框…」、u09a 矩阵组 | AP12a-节奏-* |
| P07 结论卡 | _conclusion | ap12a「结论卡：用车天数 metricLg…」 | 同上 |
| P08 点图与步进 | _plotSection + MileafIconButton(back/chevron) | ap12a「前后操作是圆形步进圆钮…」、u09b 键盘/命中组 | AP12a-能耗-* |
| P09 结论与每日充电量 | _conclusion/_trend | ap12a「结论卡按对照表」「主图是每日充电量」 | AP12a-补能-* |
| P09 充电方式/地点 | _composition/_locationSection | ap12a「充电方式与地点按对照表命名」 | 同上 |
| R29/CP11 删「点按读值」 | _trend（trailing 删除） | ap12a「渲染树无点按读值」 | — |
| R30.2/R30.4 关于这些数据 | MileafDataNotes 五类 + technical copyable | ap12a「页尾关于这些数据五类」+ 渲染树 snake_case 探针 | — |
| R30.3 说明类折叠迁出 | StatisticsTopicNotes→MileafDisclosure；距离组覆盖并入说明 | u09b 渲染入口改「技术详情」 | — |
| CP02/CP03/CP04/CP05/CP06/CP08/CP09/CP10 | 对照表逐条见 §5 | ap12a 各文案断言 + copy_guard | — |
| R31/CP07 状态句 | copy_msg.staleMessage/readFailedMessage/loadingMessage/emptyMessage | ap12a「读取失败按 CP07 生成」「有旧数据时失败写明快照时刻」、u09a 局部失败 | — |
| §6 首屏预算（五专题：主图绘图区首 120） | 三页骨架收敛 | 渲染入口 measurements（plotVisible ≥120） | manifest |

## 4 能力迁移

| 能力 | 原入口 | 新入口 | 测试 |
| --- | --- | --- | --- |
| A33 关于这些数据（专题） | StatisticsTopicNotes（ExpansionTile） | MileafDataNotes 五类（节奏/能耗/补能三页） | ap12a 五类用例 |
| A34 样本明细卡 | StatisticsTopicFacts（画布发丝块） | SectionHeader + MileafModuleCard | u09a MetricBlock 断言沿用 |
| 步进圆钮（温度组） | 上一温度组/下一温度组 TextButton | MileafIconButton back/chevron + 语义上一组/下一组 | ap12a、u09b |
| 枚举/技术口径 | 主界面直接拼 method/version/as_of | 人话标签 + 技术详情可复制（SelectableText） | ap12a snake_case 探针 |

## 5 文案前后表（专题对照表逐条 + 对照表外按 CP01–CP11 的改动）

| 文件:位置 | 原文 | 新文 | 规则 |
| --- | --- | --- | --- |
| usage 身份块 | 2026/10/1 — 2026/10/28 + 数据说明折叠（宿主） | 用车节奏 / 10月1日–28日，按开始日期统计 | CP04、R25/R30 |
| usage 结论 | 活跃 5 天 | 用车 5 天 | CP02 |
| usage 结论上下文 | 209 km 记录里程 / 每活跃日 41.8 km | 共 209 km，平均每个用车日 41.8 km | CP02 |
| usage 日历题 | 每日用车 / 日期矩阵（显示模式小字） | 每日里程 / — | CP05 |
| usage 图例脚注 | 点按日期查看当天行程；缺日为未知… | 缺日为未知，未来日期不补零。 | CP11 |
| usage 明细题 | 证据 | 样本明细 | CP02/CP05 |
| usage 明细项 | 平均记录速度 | 平均速度 | CP02 |
| usage 失败 | 用车节奏读取失败，保留上次结果（RFC3339） | 没能读取用车节奏 / 没能更新，显示的是 HH:mm 的数据 | CP07/R31/R30.4 |
| usage 日历失败/空 | 日历暂不可用 / 还没有每日里程 / 正在读取每日里程 | 没能读取每日里程 / 这段时间没有每日里程 / 正在读取每日里程 | CP07 |
| usage 重试 | 重试用车节奏 / 重试日历（可见文字） | 重试（Semantics 补对象） | CP06 |
| usage 证据页 | 10月2日行程 / 完整匹配 1 趟 / 按开始日归期 / 2026-10-02 至 2026-10-02 | 10月2日的行程 / 1 趟 / 10月2日（或 DF3 区间），按开始日期统计 | CP02/CP04/CP05 |
| usage 证据行 | 净电耗 X Wh/km | 电耗 X Wh/km | CP02 |
| usage 证据失败 | 行程证据读取失败，已载记录保留 | 没能读取行程证据 / 没能加载更多行程，已保留当前列表 | CP07 |
| conditions 身份/结论 | 温度下的用车能耗 / 所选温度组 · −10至−5°C | 不同温度下的电耗 / −10 至 −5°C | CP05/CP09 |
| conditions 限定 | 小样本，仅供点读 / 关联观察，不代表因果或排名 | 样本较少，仅供参考 / 只反映相关性，不代表因果或优劣 | CP08 |
| conditions 图题 | 加权净电耗 · Wh/km / 行程室外均温 · 5°C半开分组 | 电耗（按里程加权）/ 按行程平均气温分组，每组 5°C | CP09 |
| conditions 步进 | 上一温度组 / 下一温度组 | 步进圆钮（语义：上一组 / 下一组） | CP06 |
| conditions 明细 | 证据 / 候选 / 有效配对 / 平均记录速度 / 该组数据覆盖 / 查看该温度组行程 | 样本明细 / 参与 / 有效 / 平均速度 / 样本覆盖（并入页尾）/ 查看这些行程 | CP02/CP06 |
| conditions 失败 | 能耗条件读取失败，保留上次结果（RFC3339） | 没能读取能耗条件 / 没能更新，显示的是 HH:mm 的数据 | CP07 |
| charging 身份/结论 | 补能账目 · 按结束日 · 仅已完成充电 / 已知支出 · 覆盖同时看 / 费用覆盖 2 / 8 次 | 充电费用（脚注按结束日期统计，仅含已完成的充电）/ 已记录费用 / 8 次中 2 次有费用 | CP02/CP05/CP09 |
| charging 均价 | 有效入电均价 0.4/kWh | 充入均价 0.4/kWh | CP02 |
| charging 图 | 入电量走势 · 按结束日（+点按读值） | 每日充电量（按结束日；提示删除） | CP05/R29/CP11 |
| charging 方式/地点 | 补能结构 · AC / DC / 未知时间分布 / 自己的地点账目 | 充电方式 / 充电地点 | CP05 |
| charging 时长 | 分类记录时长：AC 90.0 / DC 35.0 / 未知 0.0 分钟 | 表格三行：AC 1 小时 30 分钟、DC 35 分钟、未知 0 分钟 | CP03 |
| charging 下钻 | AC记录 / DC记录 / 未知分类记录 / 查看期间补能记录 | 查看 AC 充电 / 查看 DC 充电 / 查看未知类型 / 查看这段时间的充电 | CP06 |
| charging 地点行 | 8 次 · 160.0 kWh · 费用有记录 2/8次 | 8 次，160.0 kWh，其中 2 次有费用 | CP09 |
| charging 明细项 | 充入电池 | 充入电量 | CP02 |
| 三页刷新中 | 用车节奏更新中 / 补能统计更新中 | 正在更新 | R31 |

- 冻结文案（CP12）：本票未触及任何一处冻结文案。
- 对照表外的要点：可见重试统一「重试」+ Semantics 对象补全（AP07 先例）；未设置币种沿用 amountValue（不带符号）+ amountNote 旁注；「查看此期间补能」（选桶下钻，对照表未覆盖）保留原文。

## 6 命令与结果

| 命令 | 结果 |
| --- | --- |
| ./tool/flutterw analyze --no-pub | No issues found，EXIT 0 |
| ./tool/flutterw test --no-pub test/apple_polish_ap12a_test.dart | 14 通过 / 0 失败 |
| 本票持有测试 + 守卫 | 全绿（statistics_usage/conditions/charging、ui_ux_u09a/b/c、copy_guard、raw_value_guard） |
| ./tool/flutterw test --no-pub（全量） | 见 §6.1 |
| ./tool/flutterw dart format --output=none --set-exit-if-changed <本票改动文件> | 0 changed，EXIT 0 |
| git diff --check | 无输出，EXIT 0 |
| 正式渲染 | test/apple_polish_ap12a_render_test.dart → docs/implementation/apple-polish-renders/AP12a/（PNG + manifest.json，含 plotVisible 首屏测量） |

## 6.1 全量测试与既有测试补丁

- 全量基线 FP3：961 通过 / 40 跳过 / 0 失败。本票收口全量：**975 通过 / 41 跳过 / 0 失败**，EXIT 0（+14 通过 = ap12a 合同测试 14 例；+1 跳过 = 本票渲染入口未 opt-in；0 失败）。
- 既有测试失败共 11 处，全部是定位与口径迁移，未放宽任何断言；按 §3.3「失败以补丁提交」口径在本票先落地、交总控复核：

| 文件 | 失败 | 等价修正 |
| --- | --- | --- |
| test/navigation_bar_test.dart ×3 | find.text('用车节奏') 命中宿主导航与本票身份块两个 | 改为 find.descendant(of: MileafNavigationRow, matching: …) |
| test/overview_statistics_reading_test.dart ×4 | 补能账目→充电费用、这段时间的用车节奏→用车节奏（同屏两处，findsOneWidget→findsWidgets）、查看期间补能记录→查看这段时间的充电 | 见补丁 |
| test/reading_integration_test.dart ×2 | 这段时间的用车节奏→用车节奏 | 见补丁 |
| test/owner_experience_test.dart ×1 | 活跃 12 天→用车 12 天 | 见补丁 |
| test/charging_reading_test.dart ×1 | 补能账目→充电费用 | 见补丁 |

## 7 偏差账本

| ID | 规则/事实 | 触发样例 | 测量/证据 | 处理 | 影响 |
| --- | --- | --- | --- | --- | --- |
| D-AP12a-01 | R25「区间标题兼作数据说明折叠」拆开的宿主部分 | 统计首页 selectTopic 推入的专题路由头仍是 ExpansionTile（区间标题 + 数据说明），host 为 AP11 持有 | insights_page.dart:255–274 | 不改他票文件；本票身份块已按规格落地（区间进身份块、说明进页尾），宿主折叠头的移除交 AP11/总控补丁建议见 §8 | 合入前同屏短暂出现两次区间；AP11 应用后消除 |
| D-AP12a-02 | P07「格子无描边框」与 44 命中 | 格子与卡缘圆角叠加使外缘约 5px 命中弱化（旧实现经 ButtonStyle.side 组合覆盖此场景） | dbg：inset 1–5 失败、6 成功 | 格内 8px 内缩（保七列每格 ≥44，格距 inline2 基线微调档），u09a 点击点内缩 6px 并注记；未选中格描边与填充同色（视觉无边框） | 四角极小区域点击手感与旧版一致，视觉无边框 |
| D-AP12a-03 | copy 守卫只降不升 | 三页重写后 usage 81（持平）、conditions 50（持平）、charging 59（61→59） | 守卫测试 | 相邻字面量合并与共享局部变量/常量消除重复行 | 无余量（AP14 归零时复核） |
| D-AP12a-04 | 统计首页补能专题卡的「费用覆盖」进度条 | P09 线框无进度条，对照表改一句话 | 结论卡 | 移除条形与「费用覆盖」行，改「N 次中 M 次有费用」 | 覆盖信息保留为句子 |
| D-AP12a-05 | 「查看此期间补能」（选桶下钻） | 对照表未覆盖此入口 | 保留原文 | CP06 下钻行口径已满足 | — |
| D-AP12a-06 | R21.3 专题读数头 metricSm | 补能专题图 readoutScale 由 root 改 detail | u09c 断言沿用 | 组件既有参数 | 与详情一致 |

## 8 未验证与外部待验

- 真机字体、读屏、键盘、减少透明度/高对比、真实地图、设备性能与整机：继续由 #11/#16/#17 承载。
- 768 宽、safeArea=0 的 200% 组合等更长尾机位由渲染入口的 cases 覆盖 130/150%/430/320/无安全区；未做 430×200% 组合。
- 宿主（AP11）专题路由头的折叠拆分未发生（D-AP12a-01），合入集成后需复验专题页顶部与身份块不重复。
- AP12b（statistics_range/parking）引用的 StatisticsTopicNotes 内部实现已改 MileafDisclosure，AP12b 合入时需复验两页说明行展开。

## 9 临时资源

- /tmp/ap12a_full.log、/tmp/ap12a_full2.log（全量测试日志，未入库）、/tmp/*.py 占位符脚本（临时）。
- 交付物：docs/implementation/apple-polish-renders/AP12a/（渲染图册 + manifest）。
- 下一票输入：AP12b 沿用 StatisticsTopicNotes 适配层与 MileafDataNotes 五类模式；AP14 接收 §7 补丁清单与本票守卫余量（0）。

## 10 提交

- 分段提交（usage → conditions → charging），均在本票分支本地提交，不推送：
  1. AP12a: P07 节奏专题（R25 骨架、日历重做、样本明细、CP07 状态句）
  2. AP12a: P08 能耗专题（点图步进、温度组分段保留、对照表文案）
  3. AP12a: P09 补能专题 + 合同测试/渲染图册/守卫基线 + 跨票等价补丁与交接
