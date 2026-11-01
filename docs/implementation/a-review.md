# A「夜航」VA01–VA14 双轴 code review

日期：2026-11-01 · 范围：`git diff aca7680...HEAD`（VA01–VA14，15 个本地提交）· 审查方式：Standards 与 Spec 两个独立子代理并行，只读，不修改文件。

## Standards 轴

### 硬性违规（已修复）

1. 裸 `EdgeInsets`：
   - `drive_detail_page.dart` 的 `EdgeInsets.symmetric(horizontal: 20)` → `MileafSpace.s20`
   - `charging_detail.dart` 的 `EdgeInsets.only(top: 20)` → `MileafSpace.s20`
   - `statistics_insights_page.dart` 的 `horizontal: 18` / `bottom: 8` → `MileafSpace.s20` / `MileafSpace.s8`
2. 11 处 `SizedBox(height: 2)`：新增 `MileafSpace.inline2` 并替换，避免 2px 微间距散落。
3. `statistics_parking_page.dart` 的 `Theme.of(context).textTheme.bodySmall` 绕过排版 token：改为 `context.type.micro`。
4. Spec §13.3 退役未完成（**未修复，记为残余**）：`collage.dart` 仍被 `statistics_page.dart`（旧 0.1/0.2 站点的 legacy 页面）、`period_chips.dart`、`data_cards.dart` 引用；`period_chips.dart` 仍使用 Material `ChoiceChip`。A 的主路径已不依赖它，但完整删除会影响 legacy fallback 测试，留待后续一次性移除。

### 判断项（未全部处理）

- 五个专题仍各自重建「结论/空态」骨架；可收敛为共享 `StatisticsTopic` 组件。
- 专题页大量 `Map<String, dynamic>` / `Object?` 取值；属于既有 frozen API 解析方式，本轮未重写。
- `statistics_parking_page.dart` 的 `n()`、`states()` 命名偏短。
- `statistics_page.dart` 的 `_StatisticsEntryState` 仅包装 topBar，属 Middle Man。
- `topBar` 逐页传入四个页面（Data Clumps），可考虑 shell 层统一注入。
- `appearance.mode` 的 dark 判断与 `MileafAppearance.themeMode` 重复。
- `visual_theme.dart` 的 `lakeTheme` 仍保留（已 deprecate）。
- `_LegacyStatisticsPage` 旧 C 版面仍挂在 legacyBuilder。

## Spec 轴

### 缺失 / 部分

1. **VA12 五专题矩阵不完整**：图册只渲染节奏专题；能耗/补能/长期/停放 0 张，两类详情缺 empty/fail，Tab 的 empty/missing 只做深色 100%。README 已明确标注待补。
2. **VA14 Spec 验收清单未逐项勾选**：本轮新增 `a-final-verification.md` 补齐；`visual-system-a.md` / ADR 0003 仍为未跟踪设计文档，按用户“不提交未跟踪设计资产”的边界保留在本地。
3. **§13.2/§13.3 未完全退役**：`data_chart.dart`、`period_chips.dart`、`collage.dart`、`data_cards.dart` 仍有 legacy 引用。
4. **§9.2 长期**：未加载 range observations 时显示 `—` + “进专题查看”；本页不主动加载 observations，因此没有“已加载”分支（未新增请求，符合 §9.2 的“不预取”）。

### 越界

5. `analysis_options.yaml` 排除 `MileafServer/**`、`teslamate/**`，用于避免符号链接环路分析；未修改外部仓库。
6. `design_gallery_render_test.dart` 是组件图册，无落盘 PNG；不属 VA12 页面矩阵。
7. `top_bar.dart` 是 VA02 的共享 Shell 组件，未列入 §13.1 清单但为页面复用所需。

### 看似实现但错（已修复）

8. **VA12 浅色图曾是深色副本**：原 gallery 只设 `platformBrightnessTestValue`，App 默认 `ThemeMode.dark`。已在 `0b01696` 通过 `AppearanceController` 强制浅/深并重出 36 张；复核 18 对 light/dark 的文件哈希全部不同。此发现对应审查时的 HEAD，现已关闭。
9. **`currency.amount()` 仍输出括号币种**（`charging_detail.dart` legacy 行、`statistics_page.dart` legacy 页、`statistics_charging_page.dart` 说明层）。主路径 hero 已用 `amountValue` + `amountNote`；legacy/说明层保留旧格式，**未完全修复**，记为残余。
10. **`SocInterval` 标签仍是“起始/结束”**，Spec §9.4 写“到达/出发”。组件被行程详情与充电列表共用，改动会影响现有测试；本轮保留，记为残差。
11. **专题自定义 painter 的语义**：节奏日历/停放 SOC/续航等使用自有 CustomPaint，语义摘要由外层文本提供，未逐一纳入共享图表组件测试。

## 结论

- Standards：4 组硬性问题，3 组已修复，1 组（legacy 退役）保留为残余；判断项 8 项。
- Spec：11 项发现，1 项（浅色图）已修复并复验，2 项文档/清单已补，其余为图册范围、legacy 与措辞残余。
- 最差遗留：**VA12 五专题完整矩阵未完成**，以及 **legacy `Collage*`/`amount()` 路径仍在**。两者都不影响 A 主路径的 351 项测试，但不能算 VA12/VA14 的完整验收。

## 复审补记：VA12 完整图册 + VA14 legacy 清理（2026-11-01，同一分支）

上一轮留下的两项「最差遗留」已在本轮修复，结论更新如下。

### 已关闭

1. **VA12 五专题矩阵**：图册由 36 张扩到 **132 张**（11 页 × normal/empty/missing × 浅/深 × 100/200%），五专题全部进入，两个长期专题经「长期」页的「展开长期续航」/「展开停放观察」进入。新增 `test/support/a_gallery_fixture.dart`，三态语义分离：empty 为真实无记录/无采样，missing 为字段未知 → `—`，两详情的 missing 走明细 503 / 系列 503。每个「页 × 态」在渲染时断言至少一条主数字或空/缺失文案；断言失败会打印该页实际文本，避免"看起来渲染成功"。132 个文件哈希互不相同，66 对浅/深与 66 对 100/200% 全部不同。
2. **§13.2/§13.3 退役**：`lib/src/collage.dart`、`data_chart.dart`、`period_chips.dart`、`data_cards.dart` 已删除；`statistics_page.dart` 的 legacy 0.1/0.2 fallback 只用 A token 与 A 组件（`StatusChip`、`MetricBlock`、`TimeSeriesChart`），`statistics_insights_page.dart` 改用 `MetricBlock` + `MetricGrid`，`period_chips.dart` 的胶囊改为内联 `Wrap` + `StatusChip`。全仓 `rg "CollageTile|CollageBento|Sparkline|data_cards|period_chips|data_chart"` 在 `lib/` 为 0 命中，`test/` 仅剩一条说明性注释。
3. **`currency.amount()`**：方法已从 `currency.dart` 删除；金额统一 `amountValue` + `amountNote`，无币种显示金额 +「币种未记录」，不默认 CNY、不加括号换行。全仓 `rg "currency\.amount\("` 为 0 命中（仅文档记述）。
4. **`SocInterval` 措辞**：新组件 `design/components/soc_interval.dart`（0–100 轨 + 区间段，标签「出发 / 到达」，语义摘要含尺度），行程详情与充电列表共用；`test/drive_detail_test.dart`、`test/charging_test.dart` 已同步。
5. **充电详情 hero**：`ListView` padding 置 0，电量弧 hero 全出血，其余内容包在 `MileafLayout.pageInset` 内，地图保留自身边距；`a_charging_detail_test.dart` 新增 hero 左右到边的断言。
6. **`c_gallery_render_test.dart`**：标注为历史 C 证据并 `skip: true`，不删除文档与 fixture，仍导出 `cGalleryClient` 供 A 回归复用。
7. **本轮新发现并修复**：`statistics_parking_page.dart` 仍用 Material 调色板（`Colors.teal/indigo/orange/grey`）与 `ColorScheme`，分桶读数直接贴服务端 ISO 时间。已改为 A 语义色（单绿色阶 + 灰阶）、`context.type.micro`，分桶起点按本地日历显示；`test/statistics_parking_test.dart` 通过。

### 仍保留

- 专题自定义 painter 的语义摘要仍由外层文本提供，未逐一纳入共享图表测试。
- 补能专题 0 条记录时走「真实 0」而非空态分支（页面判定依赖 `totals == null`），图册按真实行为记录。
- 未跟踪设计文档仍按用户边界保留在工作区。

### 结果

- `tool/flutterw analyze --no-pub`：0 issue。
- `tool/flutterw test --no-pub`：**352 通过、22 跳过**。
- 图册：`docs/implementation/a-renders/gallery/` 132 张，指纹见该目录 README。

## 第二轮双轴审查（独立子代理）与修正

范围 `git diff c70fa86...HEAD`，Standards 与 Spec 各 1 个子代理，共 23 项发现。其中硬性项已在本轮修正：

1. **空态费用不是 0**：Spec §9.5「空：费用 `—`」。`charging_page.dart` 与 `statistics_charging_page.dart` 改为按覆盖计数判定——`cost_known_sessions == 0` → `—`；`energy_known_sessions`/`duration_known_sessions` 为 0 时同改。0.1/0.2 legacy 合约没有覆盖计数，保留原值并在注释说明。
2. **`—（缺失）` 统一为 `—`**：`drive_detail_page.dart`、`charging_page.dart`、`charging_detail.dart`、`statistics_page.dart` 共 15 处，测试同步；Spec §3.3「未知用 `—`」。
3. **电量区间标签**：按 §9.4「到达 68% / 出发 76%」调整为到达在前、`%` 紧贴数字（原先「出发 82 % / 到达 72 %」）。
4. **`visual_theme.dart` 退役**：§13.3 首项，全仓无引用，已删除；`design_tokens_test.dart` 不再把它排除出 `lakeTheme` 扫描。
5. **裸 token**：`height: 6` → `MileafSpace.inline6`；四处 `height: 160` 改为图表默认高度；`EdgeInsets.only(top/bottom: 8/6)` → token；`BorderRadius.circular(20)` → `MileafRadius.lg`；新增 `MileafLayout.pageHorizontal` 供充电详情与统计列表复用，去掉手写 `fromLTRB`。
6. **图册断言区分性**：`markers` 改为 `must` + `mustNot` 双向断言，空/缺失格不得出现正常态数字（`1,198.6`、`¥186.4`、`432.0`、`32.9` 等），正常格不得出现空态文案。
7. **币种文案统一**：`currency.symbol` 的兜底从「币种未知」改为与 `amountNote` 一致的「币种未记录」。
8. **潜在越界崩溃**：`statistics_page.dart` 的「DC读数/未知读数」按 `point` 索引前加长度判断，避免分桶长度不等时 RangeError。

保留为判断项（未改）：补能构成区 `0 kWh`、补能专题空态分支、legacy 统计页的 `_steppers`/`_EnergyBars` 私有实现、`MetricGrid` 未进 §13.1 清单、停放页调色板与日期格式（属 legacy 视觉清理）。
