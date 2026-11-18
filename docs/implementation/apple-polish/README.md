# Apple 质感精修（ADR0014）实施控制面

总控会话维护。设计依据见 docs/adr/0014-apple-polish.md、docs/specs/apple-polish.md、docs/specs/apple-polish-copy.md；执行合同见 docs/specs/apple-polish-delivery.md；票合同见 docs/specs/apple-polish-tickets.md。

## 冻结点

| 冻结点 | 含义 | SHA |
| --- | --- | --- |
| FP0 | AP00 完成：在途改动与设计文档两次提交已落地，集成分支已建，AP00 交付物已提交，W1 工作树已建 | 7cf8dd4（AP00 + FP0 登记） |
| FP1 | W1（AP01、AP06）合入 + 集成窗口基线补登 | c18f2fc（W1 合入） |
| FP2 | W2（AP02–AP05）合入 + 集成窗口收口，共享 API 唯一清单 | 8edd1ec（W2 合入） |
| FP3 | AP07 代表页经用户裁定通过后冻结：token 表、组件 API、动效参数、首屏预算、共享符号签名 | eeefe83（AP07 合入）；清单见 [fp3-freeze.md](fp3-freeze.md) |
| FP4 | W4（AP08、AP09、AP10、AP11、AP12a、AP12b、AP13）全部合入 + 集成窗口收口 | 773886a（W4 末次集成提交） |
| FP5 | AP14（W5 集成收口）合入：守卫归零、跨页与性能证据、AP13 归拢、统一图册索引 | 96e0cd4（AP14 合入提交） |

## 文件与测试租约（交付手册 §3.3）

| 文件域 | W1–W2 持有者 | W3 | W4 起 |
| --- | --- | --- | --- |
| tokens、semantic、typography、motion、theme、icons、brand_mark、layout（非外壳） | AP01 | 冻结 | 只读，修正交总控 |
| layout 外壳几何、top_bar、page_bar、nav_bar、glass_surface、navigation_material、large_content_viewer、workspace_page 外壳 | AP02 | 冻结 | 只读 |
| chip_row、chip、button、icon_button、sheet、focus_ring、date_range_sheet、pull_down、selection_list | AP03 | 冻结 | 只读 |
| hero、section、metric、data_row、copy_row、fact_list、disclosure、state_view、map_frame、soc_interval、module、components 导出 | AP04 | 冻结 | 只读 |
| charts、category_bars、composition_bar、battery_arc、share_ring、sample_chart | AP05 | 冻结 | 只读 |
| number_format、copy/*、非页面文件字符串字面量、文案守卫 | AP06 | 冻结 | 页面包只改自己源文件对应的守卫基线文件 |
| 代表页文件与 _VehicleSheet | — | AP07 | 交回 AP08/AP10/AP11/AP13（行程页交 AP09） |
| 页面文件 | — | — | 按 Tickets 各票持有 |
| 跨页测试、test/support/ 既有文件、统一图册、能力迁移表 | 总控 | 总控 | 总控（AP14） |

既有测试唯一修改者见交付手册 §3.3。票会话新建测试只用 test/apple_polish_apXX_*.dart 命名，新建支撑文件只用新文件名。

**新增 lib 源文件的两道守卫登记**（W1 合入时由总控落实，W2 起各票自查）：

1. 裸值守卫（AP01，`test/apple_polish_raw_value_guard_test.dart`）要求 `lib` 下每个扫描文件（排除 `lib/src/design/**` 与 `*.g.dart`）都有 `test/support/raw_value_baseline/<同路径>.txt`；缺失即失败，不是按 0 处理。新建文件时照既有格式补全 0 基线（照抄四条计数 + `total=0`，把 `# <路径>` 换成自己的）。
2. 文案守卫（AP06，`test/apple_polish_copy_guard_test.dart`）按 `test/support/copy_guard_baseline/` 的计数只降不升；新建文件的中文字面量必须同步登记基线，改字面量时同步下降计数。

## 工作树租约表

命令前缀：工作树内每条 tool/flutterw 命令都加 MILEAF_FLUTTER_SDK=<主仓库>/.tooling/flutter（构建另加 MILEAF_ANDROID_SDK）。依赖缓存用 cp -cR <主仓库>/.cache/pub <工作树>/.cache/ 后跑 pub get --offline 验证。不建符号链接。

| 票 | 工作树目录 | 分支 | 输入冻结点 | 状态 |
| --- | --- | --- | --- | --- |
| AP01 | （已删）…/MileafMobile-ap01 | codex/apple-polish-ap01 | FP0 | 已合入 FP1，工作树已删，分支保留 |
| AP06 | （已删）…/MileafMobile-ap06 | codex/apple-polish-ap06 | FP0 | 已合入 FP1，工作树已删，分支保留 |
| AP02 | （已删）…/MileafMobile-ap02 | codex/apple-polish-ap02 | FP1 | 已合入 FP2，工作树已删，分支保留 |
| AP03 | （已删）…/MileafMobile-ap03 | codex/apple-polish-ap03 | FP1 | 已合入 FP2，工作树已删，分支保留 |
| AP04 | （已删）…/MileafMobile-ap04 | codex/apple-polish-ap04 | FP1 | 已合入 FP2，工作树已删，分支保留 |
| AP05 | （已删）…/MileafMobile-ap05 | codex/apple-polish-ap05 | FP1 | 已合入 FP2，工作树已删，分支保留 |
| AP07 | （已删）…/MileafMobile-ap07 | codex/apple-polish-ap07 | FP2 | 已合入 FP3，工作树已删，分支保留 |
| AP08 | （已删）…/MileafMobile-ap08 | codex/apple-polish-ap08 | FP3 | 已合入 FP4，工作树已删，分支保留 |
| AP09 | （已删）…/MileafMobile-ap09 | codex/apple-polish-ap09 | FP3 | 已合入 FP4，工作树已删，分支保留 |
| AP10 | （已删）…/MileafMobile-ap10 | codex/apple-polish-ap10 | FP3 | 已合入 FP4，工作树已删，分支保留 |
| AP11 | （已删）…/MileafMobile-ap11 | codex/apple-polish-ap11 | FP3 | 已合入 FP4，工作树已删，分支保留 |
| AP12a | （已删）…/MileafMobile-ap12a | codex/apple-polish-ap12a | FP3 | 已合入 FP4，工作树已删，分支保留 |
| AP12b | （已删）…/MileafMobile-ap12b | codex/apple-polish-ap12b | FP3 | 已合入 FP4，工作树已删，分支保留 |
| AP13 | （已删）…/MileafMobile-ap13 | codex/apple-polish-ap13 | FP3 | 已合入 FP4，工作树已删，分支保留 |
| AP14 | （已删）…/MileafMobile-ap14 | codex/apple-polish-ap14 | FP4 | 已合入 FP5，工作树已删，分支保留 |
| AP15 | /Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile-ap15 | codex/apple-polish-ap15 | FP5 | 已更新至 FP5（0dce651，含登记提交 692263a），依赖已备 |

W3 工作树：AP07 于 2026-11-17 从 `a2707f7`（FP2 登记提交）创建，分支 `codex/apple-polish-ap07`；`.cache/pub` 已按 §3.1 用 `cp -cR` 克隆，`pub get --offline` 与 `analyze` 均通过，工作树内 `git status` 为空。W2 四票工作树已全部删除（AP04 的 `.dsh-tmp/` 只有临时日志与已归档的补丁草稿，删除前已核对）。AP07 工作树在合入 FP3 后同样已删除，分支保留。

W4 工作树：七票均于 2026-11-17 从 `8ea7e29`（FP3 登记提交）创建，`.cache/pub` 用 `cp -cR` 克隆（各 640M，APFS 共享块），`pub get --offline` 七票全部退出 0，工作树内 `git status` 均为空；ap08 实跑 `analyze` 无诊断（SDK 走 `MILEAF_FLUTTER_SDK=<主仓库>/.tooling/flutter` 前缀，与 §3.1 一致）。

## W1 合入记录（FP1 = c18f2fc）

| 顺序 | 票 | 分支 | 票提交 | 合入提交 | 合入后测试 |
| --- | --- | --- | --- | --- | --- |
| 1 | AP01 设计基础 | codex/apple-polish-ap01 | a291a86 | 5ecc372（--no-ff） | 本票 44 通过（ap01 18 + raw_value_guard 3 + design_tokens 23）、跨页 88 通过 |
| 2 | AP06 文案基础 | codex/apple-polish-ap06 | a271e00 | 0b47551（--no-ff） | 本票 28 通过（copy 26 + copy_guard 2）、跨页 88 通过 |

集成窗口（总控，c18f2fc）：AP06 新增 `lib/src/copy/` 六个文件后，AP01 的「基线覆盖全部扫描文件」用例失败；按 AP01 守卫格式补 6 个全 0 基线。这是两票的唯一交叉影响，未改任何阈值或断言。

补丁核对：AP01 交接文末的 `test/design_tokens_test.dart` 补丁已随本票提交（`press 100→120`、图标 `16→25`），与交接 diff 逐字一致，无需重复应用；AP06 交接 §7 声明既有测试补丁为无。

合入后集成状态：`analyze` 无诊断；全量 `tool/flutterw test --no-pub` 803 通过 / 35 跳过 / 0 失败（FP0 基线 754/33；+49 通过 = AP01 21 + AP06 28，+2 跳过 = AP01 渲染入口未 opt-in）。

W1 遗留交下游的事实：AP01 `AU-AP01`（controlBorder 采纳 #7A8390/#677179，否决规格候选，已实测 ≥3:1）与 `AU-AP01-1`（深色 textSecondary 在 segmentSelected 上 4.461:1）为调色板层待办，AP01 只允许两处外观变化故未修，交后续调色板/页面票；AP06 `D1`/`D2`/`D3`（session_test 与 map_key 测试钉住的原文保持不动）与 `D2` 的「已清除 · …」改逗号拼接已随票落地；`D4`/`D6`/`D7`（命令句、period 措辞、messages 模板重复）列入待确认，交 AP14/AP15 统一。

## W2 合入记录（FP2 = 8edd1ec）

| 顺序 | 票 | 分支 | 票提交 | 合入提交 | 合入后测试 |
| --- | --- | --- | --- | --- | --- |
| 1 | AP04 内容语法 | codex/apple-polish-ap04 | 1d70ac8 | bf3140e（--no-ff） | 本票 39 通过（ap04 28 + design_disclosure_fact 6 + 两道守卫 5）；跨票 78 通过（design_components 56、overview_reading、statistics_insights）；跨页 88 通过 |
| 2 | AP03 控件与弹层 | codex/apple-polish-ap03 | d48990b | 3bb83d3（--no-ff） | 本票 48；design_components 56、apple_design_f01、守卫，合计 125 通过；ui_ux_u01/02/03/11 42 通过 / 2 跳过；跨页 88 通过 |
| 3 | AP02 导航外壳 | codex/apple-polish-ap02 | c5973d8 | 0d80356（--no-ff） | 本票 21、navigation_bar 7、liquid_glass_nav 9、ui_ux_u02、守卫，合计 57 通过；跨页 88 通过 |
| 4 | AP05 图表语法 | codex/apple-polish-ap05 | 226338b（3 个提交） | 9f46e70（--no-ff） | 本票 32、chart_marks 17、data_visualization_app、u03 12 / 1 跳过、design_components、守卫，合计 126 通过；跨页 88 通过（含本节收口后） |

四次合入均无文本冲突：四票在 `components.dart` 只各加自己的导出行，`layout.dart` 与外壳文件只有 AP02 触碰。

**补丁核对**（按 §3.3，票不直接改他票文件；全部由总控在合入时应用并单独提交）：

| 来源 | 目标文件（持有票） | 内容 | 落点 |
| --- | --- | --- | --- |
| AP04 §7.1 | test/design_components_test.dart（AP03） | hero 24→20 圆角 3 处、StateView 错误态标题 error→text | 35e76de |
| AP04 §7.2 | test/overview_reading_test.dart（总控在 W2 代收） | 值与单位改为整体查找 | 35e76de |
| AP04 §7.3 | test/statistics_insights_test.dart（AP11） | `187.5 Wh/km` 整体查找 | 35e76de |
| AP03 §7 | test/apple_design_f01_test.dart | M01 按压缩放 0.98→0.97 | 45da18c |
| AP02 §7.2 | test/ui_ux_u02_test.dart（AP03） | 200% 两行顺序按 PD01/R26 调换 | ee04e80 |
| AP05 §7.3 | test/design_components_test.dart | 读数头日期/数值行、图例移到绘图区之下、电量弧测 CustomPaint | 8edd1ec |
| AP05 §7.3 | test/overview_statistics_reading_test.dart（总控） | 日期行改为 `M/D` 正则 | 8edd1ec |

**集成窗口收口（8edd1ec，总控）**：AP05 交接 §7.2 列的 39 处下游影响里，除上面两条补丁外的 20 处（drive_detail、drives、charging_detail、a_charging_detail、charging_statistics、statistics、statistics_insights、ui_ux_u07、ui_ux_u08、ui_ux_u09c、full_flow 等）也在本窗口一并改为读数头断言。理由：FP2 是 W3/W4 的输入，留红基线会让后续每票撞同一批失败；这些改动只换断言定位与等价读取方式，未放宽任何阈值，逐条原因见提交 8edd1ec 的说明，各 W4 持有票在自己的票内复核即可。

- 合入后集成状态：`analyze` 无诊断；全量 `tool/flutterw test --no-pub` **932 通过 / 39 跳过 / 0 失败**（FP1 基线 803/35；+129 通过 = AP02 21 + AP03 48 + AP04 28 + AP05 32；+4 跳过 = 四票渲染入口未 opt-in）。
- 格式与 diff：16 个改动的测试文件 `dart format` 0 changed；`git diff --check` 无输出。

### FP2 共享 API 唯一清单（W3 视觉裁定前冻结，W4 只读）

| 域 | 新增 / 变更的公开符号 |
| --- | --- |
| 布局（AP01/AP02） | `MileafLayout.rootChromeLabelMaxScale`、`rootChromeLabelScaler(context)`、`rootTopBarHeight(context, {topInset})`（语义＝展开态）、`rootTopBarCollapsedHeight`、`rootNavigationHeight`（200% 封顶 1.35） |
| 外壳（AP02） | `MileafTopBar(scrollListenable:)` + Key `top-bar-expanded-title`/`-collapsed-title`/`-expanded-layer`/`-collapsed-layer`/`-vehicle`/`-divider`；`MileafNavBar.labelMaxScale`；`MileafLargeContentViewer`/`MileafLargeContentViewerHost`；`MileafGlassLens.elevated`；`MileafNavigationMenuEntry`；`mileafPageBar(moreActions:)`；`MileafNoticeBanner`；`NavigationMaterial.elevated` |
| 控件与弹层（AP03） | `MileafChipKeys`、`ChipTrackScope.capsuleHeight`、`ChipRow.rowHeight/trackInset`、`MileafPeriodRow`、`MileafControlMetrics`、`MileafPressOverlay`、`MileafButton.destructive`、`MileafIconButtonFill` 与 `fill`、`MileafSheetStyle` 与 `showMileafSheet(style:)`、`MileafPullDown`/`MileafPullDownOption`、`MileafSelectionList`/`MileafSelectionOption`、`showMileafDateRangeSheet`/`MileafDateRangeSheet`/`MileafDateRangeValidator` |
| 内容语法（AP04） | `DataNoteCategory`/`dataNoteLabel`、`MileafModuleCard`、`MileafGroupCard`/`MileafGroupHeader`/`MileafGroupRow`、`MileafDataNoteGroup`/`MileafDataNotes`、`MileafRunningPill`、`VehicleStatusKind`/`vehicleStatusIcon`、`MetricGrid.minCellWidth/columns`、`HierarchyReport`/`measureHierarchy`（测试支撑） |
| 图表（AP05） | `MileafChartGrammar`、`ChartReadoutScale`、`MileafChartReadout`、`chartAxisTickLabels`、`TimeSeriesChart`/`StemChart` 新增 `readoutScale`/`compactReadout`/`showSteps`/`readoutDate`/`markerBackdrop`（均有默认值） |

### 交下游的事实（非待办）

- R29：读值在绘图区之上的读数头，`readout` 句子只作朗读（live region）；需要自定义版式用 `readoutBuilder`。图例在 X 轴之下，Y 轴刻度在绘图区右侧。
- 电量弧：环内只放数值与紧贴的 `%`，「电量」标签移到环外，组件因此比 88 高一行；88 只约束弧本身。
- 步进圆钮 `canRequestFocus: false`：键盘 Tab 仍落到绘图区，读屏可触发按钮语义（ui_ux_u12 依赖此约定）。
- AP02 的 D-AP02-01（大字收起态只保留控件、不显示页面名）与 D-AP02-04（顶栏 100% 下 100→92）留 AP07 视觉裁定复核；AP03 的 D1（图标圆钮 `fill` 默认 none）要求画布上由页面传 `fill: track`；D3（日期弹层「改为选择」新文案）待 AP14/用户统一。
- AP05 遗留：`overview_page.dart:1980`、`statistics_charging_page.dart:646` 仍渲染「点按读值」，下钻串仍是「看当天」；按 R29/CP06/CP11 由 AP08/AP09/AP10/AP11 在 W4 改词。

## W3 裁定与 FP3 冻结（FP3 = eeefe83）

| 阶段 | 内容 | 提交 |
| --- | --- | --- |
| AP07 首轮 | 代表页 P01/P02/P06/P12/P16 与评审图 20 张 | 9ac5089 |
| AP07 补齐 | 按裁定补 P05 充电详情、P02 顺序改 B、修 158 处下游测试 | 1f3c721 |
| 第一轮裁定 | 四页（概览、行程、充电、统计）不通过，交回修正（记录见 AP07.md 附录 A.1） | aa02bb9 |
| AP07 修正 | 统一内容网格、记录卡内边与分隔线、充电期间行与「查看全部」、统计专题等高与分区距（41 张评审图） | 213db96 |
| 合入 | 四页复评通过；AP07 合入集成分支（AP07.md 的裁定记录与交接合并为一份） | eeefe83 |
| 冻结 | 用户 2026-11-17 16:39 裁定**通过**；FP3 冻结（token 表、组件 API、动效参数、首屏预算、共享符号签名），清单见 [fp3-freeze.md](fp3-freeze.md) | FP3 登记提交 |

- 合入后测试：AP07 28 通过 + 两道守卫 5 通过 = 33；跨页七件 88 通过；全量 **961 通过 / 40 跳过 / 0 失败**（FP2 基线 932/39）；`analyze` 无诊断；`dart format` 0 changed；`git diff --check` 无输出。
- 合入的冲突只有 `docs/implementation/apple-polish/AP07.md`（add/add）：已把交接 §1–§11 与两轮裁定记录（§12、附录 A）合并为一份文件，未丢任一侧内容。
- 图证：`docs/implementation/apple-polish-renders/review/` 41 张 PNG + manifest（`input_sha` `1f3c721`、FP2）。
- 页面移交：`charging_page.dart` 由 AP07 临时持有（本轮修版式），合入后交 **AP10**；`overview_page.dart` → AP08，`drives_page.dart` → AP09，`charging_detail.dart` → AP10，`statistics_insights_page.dart` → AP11，`settings_page.dart` → AP13。
- 裁定是否同步进 `AGENTS.md` 由用户决定；本轮未改 `AGENTS.md`。
- W4 七个工作树从本节的 FP3 登记提交创建（见下方工作树租约表），依赖用 `cp -cR` 克隆 `.cache/pub` 后 `pub get --offline` 验证。

## W4 合入记录（FP4 = 773886a）

合入顺序按 §3.1 第 6 点「按实际完成顺序」（各票最后一笔提交时间）：AP09 → AP08 → AP11 → AP12b → AP13 → AP12a → AP10。七次合入均无文本冲突（AP09/AP11 的总控补丁、AP12a/AP10 对 `charging_reading_test.dart` 与 `apple_polish_ap07_test.dart` 的改动落在不同 hunk，git 自动合并后逐处复核）。

| 顺序 | 票 | 分支 | 票末提交 | 合入提交 | 合入后验证 |
| --- | --- | --- | --- | --- | --- |
| 1 | AP09 行程与详情 | codex/apple-polish-ap09 | 0a40a8d | 5e49d93（--no-ff） | 本票 73 通过 / 1 跳过（ap09 11 + drives/a_drives/drive_detail/a_drive_detail/drive_detail_reading/u05）；跨页 88 通过 |
| 2 | AP08 概览 | codex/apple-polish-ap08 | f680fa7 | 335fc3c（--no-ff） | 本票 46 通过 / 4 跳过（ap08 19/1 + overview/overview_briefing/overview_a_regression/u04）；跨页 88 通过 |
| 3 | AP11 统计首页 | codex/apple-polish-ap11 | e7e8afa | 45c91ce（--no-ff） | 本票 + 补丁 60 通过 / 2 跳过（ap11/statistics/statistics_insights/a_statistics/u08/charging_statistics/u09a）；跨页 88 通过 |
| 4 | AP12b 长期续航与停放 | codex/apple-polish-ap12b | 869ce3d | 5e739fb（--no-ff） | 本票 41 通过 / 2 跳过（ap12b/range/parking/u09d/u09e）；跨页 88 通过 |
| 5 | AP13 设置与接入 | codex/apple-polish-ap13 | 798e926 | ebcb71b（--no-ff） | 本票 + 跨票等价 141 通过 / 3 跳过（ap13/session/connection/map_key/ap07/appearance/charging_cost/u10/u11/widget_test）；analyze 无诊断；跨页 88 通过 |
| 6 | AP12a 三个专题 | codex/apple-polish-ap12a | 9467d54 | a17cdfe（--no-ff） | 本票 + 专题批 149 通过 / 5 跳过（ap12a/usage/conditions/charging/u09a–u09e/ap11/insights/statistics/owner/nav_bar；含宿主修正后复跑）；跨页 88 通过 |
| 7 | AP10 充电与详情 | codex/apple-polish-ap10 | e8292da | ebf171f（--no-ff） | 本票 + 组件批全绿（ap10/charging_*/a_charging/u06/collage_charging/cost/statistics/design_components/share_ring/drive_detail/u01/ap07/守卫）；跨页 88 通过 |

**补丁与集成窗口**（全部由总控落地并单独提交）：

| 来源 | 内容 | 落点 |
| --- | --- | --- |
| AP09 §7.2 | 共享日期弹层「改为输入」×3、CP07 失败句 ×3、`行驶过程` 定位、u07 读数头 HH:mm | 4daf259 |
| AP11 §附 | charging_statistics 日期入口键盘路径 + 730 新句 + MileafSheetFrame；u09a 说明折叠改 MileafDisclosure | bd1811f |
| AP13 §7.2 | widget_test/appearance_shell/ap07 等 4 处跨票等价修正随票合入，总控复核通过 | 随 ebcb71b |
| AP13 §7.3 | 币种页 D-AP13-03：MileafDataRow 徽标列表 → MileafGroupCard + MileafSelectionList（含未用导入清理） | eef9230 |
| AP12a D-AP12a-01 | 专题路由宿主折叠只为 long/legacy 保留，五个 W4 专题页不再叠加区间/说明；insights 时区口径改 long 路由、u09a/b/c 说明行定位迁移、u09a 768 左线改身份块标题 | 2b68bc5 |
| AP10 §11.1 | SocIntervalBar 端点标签参数化（默认「出发/到达」不变，充电行传「开始/结束」，D-AP10-03） | 0c19ee6 |
| AP10 §11.2 | share_ring 图例标签包 Flexible（200% 溢出 2px，D-AP10-05） | 0c19ee6 |
| AP10 §11.3 | 图表下钻可见文字改 `activationLabel`（概览/行程「查看当天」、充电「查看这一天的充电」、其余「查看这一天」，D-AP10-04/D-AP07-04 收口）；200% 大字下紧凑读数行下钻换行尾独占一行（实测 88px 溢出修复）；「看当天」既有断言统一迁移 | 0c19ee6 |
| AP10 集成 | charging_page/currency 守卫基线 112→114、8→9（总控新增的端点标签与「站点币种」语义标签登记） | 0c19ee6 |
| AP09 §7.2-4 收口 | u07 展开地图用例移除 DF8 时代全日期可见性断言（DF9 读数头 HH:mm；选点保持由 contains(before) 承担） | 773886a |

- 集成后状态：`analyze` 无诊断；全量 `tool/flutterw test --no-pub` **1046 通过 / 49 跳过 / 0 失败**（FP3 基线 961/40；+85 通过 + 9 跳过 = 七票合同测试与 opt-in 渲染入口）；`git diff --check` 无输出。
- 格式注记：本波所有改动文件 `dart format` 0 changed；另有 6 个 W4 未触碰的既有文件（`test/apple_polish_render_test.dart`、`test/map_key_render_test.dart`、`test/render_fonts_test.dart`、`test/support/color_math.dart`、`test/support/pixel_probe.dart`、`test/support/render_fonts.dart`，最后改动均在 FP3 之前）存在格式漂移，属工具链版本差异，留 AP14 收口。
- 图证：`docs/implementation/apple-polish-renders/AP08|AP09|AP10|AP11|AP12a|AP12b|AP13/`（各票 manifest，`input_sha` 均为 FP3 `8ea7e29`）。
- W4 遗留交 AP14/用户：D-AP08-11（概览首屏预算退让第 5 步待用户裁定）、D-AP08-05（电量弧 130% 环内换行，AP05 组件层）、D-AP08-06（参照句 km 与逗号间多一空格，组件层）、D-AP08-03（InlineBanner/StateView 读屏对象名需组件参数）、D-AP09-01/02（copy 库补页面专属文案构造器）、D-AP10-02（充电三格移出账本卡，待视觉复确认）、D-AP11-01/02（统计首页守卫归零与图例只列参照）、D-AP13-01（服务信息行版本号注入）、D-AP13-04（「服务正常 · 版本」措辞）、D-AP07-14（P05「按电量」横轴是否补回）与 D-AP07-17/18/20/21/24（FP3 遗留）；AP14 一并收守卫归零与统一图册。
- W5 两个工作树（AP14、AP15）从本节的 FP4 登记提交创建，依赖用 `cp -cR` 克隆 `.cache/pub` 后 `pub get --offline` 验证。

## W5 合入记录（FP5 = 96e0cd4）

AP14 为总控票，单票合入无顺序问题；合入 `codex/apple-polish-ap14`（票末提交 `0179601`）为 `96e0cd4`（--no-ff），无文本冲突。

| 项 | 结果 |
| --- | --- |
| 本票测试 | 15 通过（apple_polish_ap14 10 + raw_value_guard 3 + copy_guard 2） |
| 跨页测试 | 七件 88 通过 |
| 全量 | `tool/flutterw test --no-pub` **1056 通过 / 49 跳过 / 0 失败**（FP4 基线 1046/49；+10 = ap14 新增） |
| analyze | 仓库内无诊断（本地未跟踪的 `creator/` 视频工作区有 2 条既有诊断，不在版本库，工作树复跑无诊断） |
| 格式与 diff | `dart format` 0 changed（含 FP4 登记时列出的 6 个既有漂移文件，本票已一并归零）；`git diff --check` 无输出 |

补丁核对：AP14.md §7 的既有测试等价修正已随票提交（AP14 持有 `test/support/`、跨页测试与冻结组件修正权，属「修正交总控」且本票即总控）；交接 §8 中刻意不做或留裁定的项（D-AP08-01 守卫口径 B、D-AP08-11、D-AP07-14/17、D-AP10-02、D-AP11-02/03、D-AP12b-06、D-AP13-01 等）未在本窗口改动。

- 图证：`docs/implementation/apple-polish-renders/AP14/`（24 PNG + manifest，输入 SHA 为 `a5f0ee7` 上的集成收口代码）与统一索引 `MANIFEST.md`。
- 能力迁移：`capability-map.md` 新增 A36–A39。
- 待用户裁定（交 AP15/用户）：守卫口径 B 确认（D-AP08-01）、D-AP08-11 首屏预算退让候选（留档 AP08.md）、D-AP07-14/17/21、D-AP08-08、D-AP10-02、D-AP11-02、D-AP12b-06、D-AP13-01。
- AP15 工作树已更新至 FP5（FP5 登记提交 `692263a`；ap15 工作树提交 `0dce651`），依赖沿用原克隆并复验 `pub get --offline`。

## AP00 交付物

- capability-map.md：A21 起呈现能力迁移。
- shared-symbols.md：跨票共享符号表（W4 签名冻结）。
- expansion-tile-classification.md：25 处 ExpansionTile 分类（说明类 16、内容类 9）。
- copy-baseline.txt：文案基线（52 文件 / 1377 行中文字符串），交 AP06 作守卫基线输入。
- before 图册：docs/implementation/apple-polish-renders/before/ 与 manifest。
- test/apple_polish_render_test.dart：before 渲染入口。
- AP00.md：交接。

## 边界

不推送、不发布 GitHub、不删除旧图册、不修改 AGENTS.md、不用 git clean 或 git reset。外部 gate #11/#16/#17 不因本地实施关闭。
