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
