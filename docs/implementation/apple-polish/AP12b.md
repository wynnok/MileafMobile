# AP12b 专题：长期续航、停放观察

## 1 票号与会话

- 票号：AP12b（W4）。会话：lead（root）。日期：2026-11-17。
- 输入冻结点：FP3 = eeefe83（登记提交 8ea7e29）。分支：codex/apple-polish-ap12b。
- 工作目录：/Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile-ap12b。
- 开工核对：pwd、分支、HEAD（8ea7e29）、`git status --short` 为空，与租约表一致；`.cache/pub` 已按 §3.1 克隆并 `pub get --offline` 通过。
- 结果 SHA：本票分支本地提交（见 git log -1；SHA 不写入本文档自身）。

## 2 修改文件清单与 API 差异

### 2.1 变更（均为本票持有）

| 文件 | 内容 |
| --- | --- |
| `lib/src/statistics_range_page.dart` | P10 按 R25 专题骨架重排：身份块（术语标题 + 统计口径一句）→ 结论卡（`MetricBlock` metricLg「月中位数」+ CP08 限定）→ 主图卡（6/12 分段、`MileafChartReadout` 完整读数头 + 步进圆钮、绘图区 200、X 轴下图例、纵轴脚注）→ `StatisticsTopicFacts` 样本明细 → `MileafDataNotes` 五类；绘图区改 R29 语法：Y 轴刻度右置、X 轴首中末 + 同文本去重、1px 竖线 + 描边点选中（取消光晕）；文案按对照表（见 §5）；错误/空态走 CP07 共享句 |
| `lib/src/statistics_parking_page.dart` | P11 同骨架：结论卡（metricLg「停车电量变化」+「N 段停车，共 X 小时；折合每天 …」+「只反映已记录的变化，不预测未来。」）→ 主图卡「每段停车」（读数头 + 正负柱 + X 轴日期去重）→ 「停车时状态」占比条 + 状态/时长/占比表格行 + 窗口统计人话标签 → 「停车记录」分组卡逐行 `MileafDisclosure`（内容类保留原位折叠，标题改 CP10 人话标签，明细行改 CP03/CP10 读法）→ 「加载更多停车记录」→ `MileafDataNotes` 五类（技术详情可复制） |
| `test/statistics_range_test.dart`、`test/statistics_parking_test.dart` | 本票持有测试的等价修正（见 §7） |
| `test/ui_ux_u09d_test.dart`、`test/ui_ux_u09e_test.dart` | 同上：图例/轴注记/步进圆钮/宽屏对齐等价改断言 |
| `test/support/copy_guard_baseline/statistics_range_page.dart.txt` | 41 → 37 |
| `test/support/copy_guard_baseline/statistics_parking_page.dart.txt` | 47 → 47（内容全部替换，行数持平，见 D-AP12b-01） |

### 2.2 新建

- `test/apple_polish_ap12b_test.dart`：10 例（P10 4、P11 4、CP09 渲染树探针 2）。
- `test/apple_polish_ap12b_render_test.dart`：P10/P11 状态矩阵渲染入口（opt-in，`MILEAF_RENDER_OUTPUT`/`MILEAF_RENDER_FONT`）。
- `docs/implementation/apple-polish-renders/AP12b/`：PNG + `manifest.json`（含首屏实测）。

### 2.3 公开符号

未新增、未变更任何公开符号。`RangeObservationPage`/`ParkingObservationPage` 构造参数、路由、Key（`range-observation-chart`、`parking-trend-chart`、`parking-state-bar` 新增为本票页面私有 Key）、回调、数据算法、请求类型与参数、生成契约均未改。私有成员：range `_local/_monthHeading/_conclusionSemantics/_readoutSentence/_readoutContext/_notes`，parking `_local/hours/ppValue/windowSummary/_readout/_readoutSentence/_conclusionSemantics/_records/_recordMeta/_recordDetail/_eventType/_notes/_stateNames/_eventTypes`（全私有）。

### 2.4 冻结符号

未触及。只读消费：`statistics_insights_page.dart`（`StatisticsInsightsContext`、`MileafNavigationRow`）、`statistics_usage_page.dart`（`StatisticsTopicFacts`/`StatisticsTopicFact`，签名冻结）、FP3 冻结组件（`MileafModuleCard`/`MileafGroupCard`/`MileafGroupHeader`/`MileafGroupRow`/`MileafDataNotes`/`MileafChartReadout`/`MileafChartGrammar`/`MetricBlock`/`SectionHeader`/`ChipRow`/`StatusChip`/`StateView`/`InlineBanner`）、copy 库六文件、`number_format.applyMinusSign`。S01–S08、全部路由、回调、Key、测试钩子、能力分支、数据算法、请求类型与参数、依赖与锁文件、生成契约均未修改。

## 3 规则映射表

| 规则 | 符号 | 测试 | 图像/证据 |
| --- | --- | --- | --- |
| R25 专题骨架 | 两页 build 的身份块/结论卡/主图卡/明细/页尾结构 | ap12b「身份块、结论卡、主图卡…」「结论卡给出主值…」 | `AP12b-*-normal-glass-*-top.png` |
| R29 图表语法 | 两页 `_trendChart`/`_RangePainter`/`_ParkingPainter`（Y 轴右置、X 轴去重、竖线+描边点）、`MileafChartReadout`（读数头在绘图区之上、专题 metricSm、步进圆钮） | u09d「趋势带与中位数折线…」「200%下…」「趋势图支持键盘左右…」；u09e 同型 | 过程图机位 |
| R30 信息披露 | 两页 `_notes`（`MileafDataNotes` 五类，技术详情 copyable）；停放记录逐行明细保留原位折叠（R30.3 内容类） | ap12b「页尾『关于这些数据』五类，技术详情可复制」；u09d/e notes 机位 | `*-notes.png` |
| R31 状态与反馈 | `messages.readFailedMessage/staleMessage/paginationFailedMessage/unsupportedMessage` + `StateView` 各空态 | range「续航资源失败…」、parking「停车资源失败…」「无有效窗口…」 | `*-error.png`、`*-empty.png` |
| R32 工程约束 | 裸值守卫基线 0 维持；`grep 'Icons\.'` 两文件无输出；`NoSplash` 沿主题 | `apple_polish_raw_value_guard_test` | — |
| CP02 术语 | `terms.ratedRange/parkingSocChange/percentagePoint/parkingRecord`；「月中位数」「每段停车」「停车时状态」「有效天数」 | ap12b 各例；domain 测试 | — |
| CP03 时长与单位 | `units.valueUnit`（真负号、个百分点）、`durations.duration`（「2 小时」「6 分钟」「19 小时 54 分钟」）、`nf.applyMinusSign` | u09e「窄片段按真实比例…」「全零分桶…」 | — |
| CP04 日期 | `copy.formatMonth/formatDay/formatDayTime/formatTime/formatPrecise`；X 轴 M/D + 同文本去重 | u09d「趋势图支持键盘左右…」（9月/10月（本月未结束））；parking domain 测试 | — |
| CP06 步进 | `MileafChartReadout` 步进圆钮（默认语义「上一个数据点/下一个数据点」，canRequestFocus:false 沿组件） | domain/u09d/u09e 200% 触控与点击 | — |
| CP07 状态句 | `messages.*` 九函数中的四类 | domain 失败用例 | — |
| CP08 限定语 | 「根据行程记录估算，不是电池健康检测」「样本较少，仅供参考」「只反映已记录的变化，不预测未来。」 | ap12b、domain | — |
| CP09 禁止形式 | 「·」拼接/单位当标签/pp 符号全部清除；主界面经 `copy_probe` 断言折叠态无 snake_case | ap12b 探针 2 例 | — |
| CP10 枚举标签 | `labels.parkingQualityLabel/exclusionReasonLabel`；窗口统计句、未计入原因句、记录行标题 | ap12b「停车记录行用人话标签…」「停车时状态…」；parking domain | — |
| §6 首屏预算 | 两专题主图可见 ≥120（360x800、safeArea 24、100%），实测记录进 manifest `first_screen_measurements`；退让第 2 步（结论卡内边 12） | 渲染入口断言 | manifest |

## 4 能力迁移

| 能力 | 原入口 | 新入口 | 测试 |
| --- | --- | --- | --- |
| A24 关于这些数据 | 长期续航/停放观察 `StatisticsTopicNotes`/`ExpansionTile「数据说明」` | `MileafDataNotes` 五类；技术详情 copyable | ap12b、u09d/e notes 机位 |
| A27 文案守卫 | range 41 行、parking 47 行 | 37 / 47 行（只降不升；未到 0，见 D-AP12b-01） | `apple_polish_copy_guard_test` |
| A28 裸值守卫 | 两页基线 0 | 仍 0 | `apple_polish_raw_value_guard_test` |
| A29 图表读数头 | 两页自绘 live-region 读值块 + TextButton 步进 | `MileafChartReadout`（完整读数头 + 步进圆钮，专题 metricSm） | u09d/e、ap12b |
| A33（建议登记）X 轴日期去重 | 两页自绘 X 轴可能重复同日/同月文本 | 绘制层同文本去重（CP04） | 渲染图册（同日多桶只画一个刻度） |

以上行为总控合并进 capability-map.md 的候选行（本票不持有该表）。

## 5 文案前后表（要点）

### 5.1 长期续航

| 原文 | 新文 | 规则 |
| --- | --- | --- |
| 满电等效额定续航 | 满电额定续航（估算）（`terms.ratedRange`） | CP02 |
| 独立N个月观察窗口 | 删除；身份块新增「独立本地月窗口，逐月估算额定续航」 | R25、分段已表达 |
| 满电等效额定续航 · 记录估计 · 非电池健康检测 | 根据行程记录估算，不是电池健康检测 | CP08、CP09.1 |
| 所选月中位数 | 月中位数 | CP10 |
| 月中位数 · P10–P90有效日波动带（km） | 图例：月中位数 / 日常波动范围（P10–P90） | CP09.2 |
| 纵轴 410–460 km，非零起点 | 纵轴从 410 km 起 | CP09.5、对照表 |
| 2026/10 · 未结束月 | 10月（本月未结束）（`formatMonth`） | CP04、CP09.1 |
| 中位 X km / P10 X / P90 Y km | 读数头值「432.0 km」+ context「P10 422.0 km，P90 449.0 km」 | R29 |
| 有效日 8 · 有效样本 / 样本稀疏，仅供点读 | 事实「有效天数 8 天」+ 稀疏旁注「样本较少，仅供参考」 | CP02、CP08、CP09.1 |
| 前一个月 / 后一个月 | 步进圆钮（语义「上一个数据点/下一个数据点」） | CP06、R27 |
| 续航观察读取失败，保留上次结果 / 重试续航观察 | 没能读取续航观察 / 没能更新，显示的是 {DF7} 的数据 / 重试 | CP07 |
| 当前数据源不支持额定续航观察 | 当前站点暂不支持额定续航观察 | CP07 |
| 观察窗口内无充电记录 / 换一个观察窗口或继续记录充电。 | 观察窗口内没有充电记录 / 换一个观察窗口，或继续记录充电。 | CP09.1 微调 |
| notes：N个本地月 · from 至 to / 查询生成时间：… / 窗口内首次有效采样：… / 逐月 · 有效日 … | 五类分组：口径与估算（原口径句整体保留）、记录与缺失（逐月「M月：有效天数 X 天、有效会话 Y 次、有效采样 Z 点」）、时间与时区、来源与生成时间（DF 精确时间）、技术详情（method/version/range_kind/soc_source/time_basis/from/to，可复制） | R30、CP04、R30.4 |

### 5.2 停放观察

| 原文 | 新文 | 规则 |
| --- | --- | --- |
| 有效窗口SOC变化 | 停车电量变化（`terms.parkingSocChange`） | CP02 |
| pp = SOC 百分点 / 单位 pp / -2.0 pp | 删除说明行；主值「−2.0 个百分点」（`terms.percentagePoint` + 真负号） | CP09.4、CP03 |
| 有效窗口 2 · 观测 12.0 h · 标准化率 -4.0 pp/24h | 2 段停车，共 12 小时；折合每天 −4.0 个百分点 | CP02、CP03、CP09.1 |
| 正值回升、负值下降都只是观测变化；标准化率为已观测结果，不预测未来24小时。 | 只反映已记录的变化，不预测未来。 | CP08 对照表 |
| 停放SOC变化 / 状态时间分布 / 分母为有效窗口观测小时 | 每段停车 / 停车时状态 / 按有效停车时长计算占比 | CP02 |
| 在线 2.0 h · 16.7%（四行） | 表格行：状态 / 时长（2 小时、6 分钟、19 小时 54 分钟）/ 占比（16.7%…；缺失为 —） | CP03、CP09.1 |
| 候选 4 · 排除 1 · 开放 1 / 排除原因：missing_soc ×1 | 共 4 段，未计入 1 段，尚未结束 1 段 / 未计入原因：缺少电量数据 1 段（`labels.exclusionReasonLabel`） | CP10、CP09.1 |
| `${window_id} · ${有效/未计入} · ${quality}` | 行标题 `labels.parkingQualityLabel`（完整 / 状态记录不完整（仍计入）/ 未计入 / 尚未结束）+ meta 窗口起止（DF4/DF5） | CP10、CP04、CP09.1 |
| 前一点 / 后一点 / 加载更多窗口 | 步进圆钮 / 加载更多停车记录 | CP06、CP02 |
| 持续 14.0 h · -1.0 pp · -1.7 pp/24h / 负里程诊断 true / `edge 事件 … · SOC …%（来源）· …` | 持续 14 小时，变化 −1.0 个百分点，折合每天 −1.7 个百分点；里程变化 … km，里程表读数回退；起点 行车，10月28日 06:00，电量 70%（来源），里程 … km（来源），位置 …（逐类单行） | CP03、CP10、CP09.1、CP09.4 |
| 匹配窗口 4 · 已载证据 3（匹配数不等于有效数） | 分组脚注：已载入 3 条记录，匹配 4 段；匹配数不等于有效数 | CP09.1 |
| 状态：available · 查询生成：… / 方法 closed-window-soc-v1 · provisional · 阈值 … | 来源类「查询生成于 {DF}」；技术详情（status/method/validation/thresholds/from/to/bucket，可复制）；口径类补「状态记录不完整的窗口仍计入统计。」 | R30、R30.4 |
| 停放观察读取失败，保留上次结果 / 窗口证据读取失败 / 重试停放观察 | 没能读取停放观察 / 没能加载更多停放记录，已保留当前列表 / 没能更新，显示的是 {DF7} 的数据 / 重试 | CP07 |
| 当前站点不支持停放观察（+副句） | 当前站点暂不支持停放观察（副句删除，见 D-AP12b-04） | CP07、CP10 |
| 暂无有效窗口，不能判断SOC变化 / 暂无有效窗口样本 | 暂无有效停车窗口，无法判断电量变化 / 暂无有效窗口样本 | CP02 |
| 分桶SOC变化缺失，不补零 | 分桶电量变化缺失，不补零 | CP02 |

冻结文案确认：CP12 六类原文（HTTP 信任确认、地图隐私与底图授权、清除已保存 Key、退出此设备、费用补录后果、连接替换说明）未出现在本票文件，未改任何一处。

## 6 命令与结果

| 命令 | 结果 |
| --- | --- |
| `MILEAF_FLUTTER_SDK=<主仓库>/.tooling/flutter ./tool/flutterw pub get --offline` | OK |
| `./tool/flutterw analyze --no-pub` | No issues found，EXIT 0 |
| `./tool/flutterw test --no-pub test/apple_polish_ap12b_test.dart` | 10 通过 / 0 失败 |
| 本票持有测试（range/parking/u09d/u09e/ap12b） | 46 通过 / 2 跳过（渲染入口 opt-in）/ 0 失败 |
| `./tool/flutterw test --no-pub`（全量） | **971 通过 / 41 跳过 / 0 失败**（FP3 基线 961/40；+10 通过 = ap12b 合同测试，+1 跳过 = 本票渲染入口未 opt-in）；无跨票失败 |
| `./tool/flutterw test --no-pub test/apple_polish_copy_guard_test.dart test/apple_polish_raw_value_guard_test.dart` | 通过（基线 37/47 只降不升） |
| 正式渲染（§5，`MILEAF_RENDER_OUTPUT=…/AP12b`） | PNG + `manifest.json`（浅深 × 390/360/320/390-150/safeArea0、两专题状态、完整滚动与 notes 展开；首屏实测主图可见 ≥120） |
| `./tool/flutterw dart format --output=none --set-exit-if-changed <8 文件>` | 0 changed，EXIT 0 |
| `git diff --check` | 无输出 |

## 7 既有测试的等价修正（本票持有）

| 文件:用例 | 原断言 | 新断言 | 原因 |
| --- | --- | --- | --- |
| statistics_range「续航专题读取…」 | 独立6个月观察窗口 / 所选月中位数 / 独立6/12个本地月窗口 | 满电额定续航（估算）/ 独立本地月窗口，逐月估算额定续航 / 月中位数 | 对照表与 R25 |
| statistics_range「稀疏…」「缺月…」 | 样本稀疏，仅供点读 / 中位 — km / TextButton 前一个月 | 样本较少，仅供参考 / 暂无有效月样本 + 本月未结束 / 语义「上一个数据点」步进圆钮 | CP08、R29 读数头 |
| statistics_range「资源失败…」 | 续航观察读取失败 / 重试续航观察 | 没能读取续航观察 / 重试 | CP07 |
| statistics_parking 各例 | 后一点/前一点 TextButton、-2.0 pp、停放SOC变化、数据说明 ExpansionTile、加载更多窗口、open-tail/partial_state_coverage 原值可见 | 步进圆钮语义查找、−2.0 个百分点、每段停车、关于这些数据 + 技术详情（SelectableText）、加载更多停车记录、折叠后人话标签（尚未结束）+ 展开后可见编号 | R29/CP02/CP03/CP10/R30 |
| u09d「趋势带…」 | P10–P90有效日波动带 / 纵轴 410–460 km，非零起点 / 独立6个月观察窗口 | 日常波动范围（P10–P90）/ 纵轴从 410 km 起 / 独立本地月窗口，逐月估算额定续航 | CP09、对照表 |
| u09d「单月…」 | TextButton 前一个月 onPressed==null | 单月时读数头不渲染步进圆钮（findsNothing） | R27 步进圆钮 |
| u09d/e「200%…」 | TextButton 矩形 ≥44 | 步进圆钮矩形 ≥44（组件命中 44） | R27 |
| u09d/e「键盘左右…」 | 2026/9 · 完整月 / 变化 0.0 pp | 9月 / 0.0 个百分点 | CP04、CP09.4 |
| u09d/e「宽屏…」 | 图区左线与标题左线 closeTo | MileafModuleCard 外缘左线与身份块标题左线 closeTo（卡内内容由卡内边对齐） | R24 卡片语法 |
| u09d/e 渲染机位 | ExpansionTile 数据说明 / TextButton 前一点 | MileafDisclosure 技术详情 / 语义步进圆钮 | R30、R27 |

全部为定位/等价改写，未放宽任何业务阈值；首屏预算断言反而按规格 §6 保留（≥120）。

## 8 偏差账本

| ID | 规则/条目 | 触发样例 | 测量 | 最小修订 | 影响 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| D-AP12b-01 | 「两个文件守卫计数降到 0」 | 页面级词（月中位数、每段停车、停车时状态、纵轴从…起、条/段/天/点 等量词与标题）不在 AP06 冻结 `copy/*` 内，页面无法只靠共享构造器写完全部文案 | `chineseLiteralCount`：range 41→37、parking 47→47（内容全部按对照表替换，行数持平的原因是停放页新增了 R30 五类说明与人话明细行） | 归零需 AP14 或由总控在 copy 库补词（补丁建议：`terms.dart` 增 `monthMedian/eachStop/parkingState/axisFrom/validDays…` 等常量） | 主页文案仍以字面量存在于页面文件；守卫阈值只降不升 | 交 AP14/总控 |
| D-AP12b-02 | R30.4 技术值进技术详情 | 停放记录逐行明细（折叠后展开）保留 window_id、事件 type 原值兜底、soc_source/odometer_source 等原值 | 折叠态渲染树经 `copy_probe` 无 snake_case；展开态明细属 R30.3 内容类「保留原位」 | 折叠态已合规；如需彻底归位，把明细原值移入技术详情或给明细行加 technical 豁免，交 AP14 统一 | 展开态明细行仍见原值 | 交 AP14 |
| D-AP12b-03 | CP02 证据→样本明细 | range 样本明细区标题沿 `StatisticsTopicFacts` 默认 `title = '证据'`（AP12a 冻结组件默认值） | — | 由 AP12a 改组件默认值或 AP14 统一，本票不传 title（避免新增字面量） | 标题仍为「证据」 | 交 AP12a/AP14 |
| D-AP12b-04 | 文案删减 | 停放「当前站点暂不支持停放观察」StateView 副句「站点未声明停放观察能力。」删除 | — | 标题已含能力语义（CP07 模板），为守卫计数收敛 | 信息量微降 | 已登记 |
| D-AP12b-05 | CP09.1 边缘 | 记录与缺失 note 逐月行「有效天数 X 天、有效会话 Y 次、有效采样 Z 点」为三项顿号列举 | — | 属技术计数列举（非「·」、非逗号），保留顿号列举形式 | 探针不命中（说明折叠） | 已登记 |

## 9 未验证与外部待验项

- 真机字体、读屏（TalkBack/VoiceOver 实机语义步进）、触觉与滚动性能仍在 #16/#17，不因本票关闭。
- 真实站点 range/parking 观测数据的真实形态（12 个月窗口、大量停车记录分页）仅在夹具层验证。
- D-AP12b-01/02/03 待 AP14/总控处置。

## 10 临时资源与下一票输入

- 无临时进程/工作树；图册与 manifest 已入 `docs/implementation/apple-polish-renders/AP12b/`。
- AP14 输入：D-AP12b-01 的 copy 库补词补丁建议；D-AP12b-02 明细原值归位；两文件守卫基线（37/47）继续只降不升。
- AP15 输入：本票渲染入口（opt-in）与首屏实测值（两专题 plotVisible 见 manifest）。
