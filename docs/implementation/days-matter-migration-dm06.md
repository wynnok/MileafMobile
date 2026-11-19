# DM06 充电页面包（MG01/MG02/MG09）实施记录

> 2026-11-19，页面包 DM06 在 `main` 工作区完成（与 DM05/DM07 并行在途，本次未提交、未推送）。规格依据：[days-matter-migration](../specs/days-matter-migration.md) MG01/MG02/MG09；组件能力来自 DM04（[days-matter-migration-state](days-matter-migration-state.md)）；取色映射来自 DM01（[days-matter-migration-color](days-matter-migration-color.md)）。行结构现状与两条起始线见 [charging-rows](charging-rows.md)。

## 1 改动文件

| 文件 | 变化 |
| --- | --- |
| `lib/src/charging_page.dart` | 记录区空态接 MG09 四档分档（§3）；记录错误条补「数据截至 HH:mm」时间行（§4）；其余零改动（S06/S07 补录状态机、冻结文案 CP12 未触碰） |
| `lib/src/charging_detail.dart` | 明细/曲线两处错误块由裸 Text + TextButton 改为三要素 InlineBanner（§4） |
| `test/charging_test.dart` | 新增 R24 两条起始线守卫用例（§5） |
| `test/charging_reading_test.dart` | 地点筛选空结果断言随四档映射更新（R10，§6） |
| `test/charging_detail_test.dart` | 补三要素断言：无快照无时间行、有快照出「数据截至」行（§6） |
| `test/dm06_charging_detail_render_test.dart` | 新增 opt-in 渲染入口（MG01 详情机位，与 AP07/charging-rows 同 skip 机制） |
| `test/support/copy_guard_baseline/charging_detail.dart.txt` | 80 → 82（§7） |
| `docs/implementation/days-matter-migration-color.md` | 追加 DM06 充电列表/详情彩色面积登记与取色核对（§4.1/4.2） |
| `docs/implementation/days-matter-migration-dm06.md` | 本记录 |

未改：`components/`、`semantic.dart`、`tokens.dart`、overview/drives/statistics/settings/connection 各页、`charging_cost.dart`（S06/S07 沿旧）、CP12 冻结文案。

## 2 MG02 受限取色核对

- **InlineBanner 调用点迁移清单（5 处，全部核对）**：能力失败、进行中失败、统计失败、地点失败、记录失败。参数名核对 `state_view.dart`：`tone` 类型为 DM04 的受限四档枚举 `BannerTone { neutral, warning, error, accent }`，取色统一转发 DM01 `MileafStatusToneColorResolver`。五处显式传值均为 `BannerTone.error`（失败=error 映射），无自由 Color 参数，无缺省误用——**已是受限四档，零迁移改动**。DM04 记录的「接线时把参数直接改用 `MileafStatusTone`、随后删除 BannerTone」需改 `state_view.dart` 参数类型，属组件持有方（DM04/集成包）范围，本包未越界。
- **进行中胶囊**：`MileafRunningPill` = segmentTrack 底 + textSecondary 文字，未用 accent，维持中性底。
- **筛选态**：筛选脚注（地点/类型/费用/单日）textMuted，筛选胶囊 MileafPullDown/StatusChip 中性，无彩色信号。
- **错误行与补录失败反馈**：页面 InlineBanner = error；`charging_cost.dart` 表单校验文字与错误行 = `colors.error`（失败/破坏=error 映射，R23.3 允许表单校验用 error）；警示（时区不可读）= warning。
- **未记录口径（MG02「缺失=中性」）**：地点行覆盖句「N 次中 M 次有费用」textSecondary、`MetricBlock` 旁注（币种未记录/充入电量缺失）textMuted、账目卡覆盖句 textSecondary、「— 表示数据缺失」脚注 textFaint——全部中性，无彩色（核对登记见 [days-matter-migration-color](days-matter-migration-color.md) §4.2）。

## 3 MG09 充电列表空态四档分档

`_recordsSection` 由单一 `emptyMessage` 改为按档取 `emptyStateCopy(tier, object)`：

| 档位 | 触发条件 | 现状句 | 动作归属 |
| --- | --- | --- | --- |
| 离线 | 不触发——本页读取走站点缓存，无独立离线信号，登记为零触发档 | （网络不可用，显示的是缓存数据） | — |
| 加载失败 | `items.isEmpty && error != null`（原先此分支返回空白，现给 loadFailed 句） | 没能读取{充电记录/已完成的充电} | 页尾错误条「重试」 |
| 无数据 | 已加载、无筛选 | 这段时间没有{…}（与原 `emptyMessage` 逐字相同） | 下拉刷新 |
| 筛选无结果 | 已加载且有筛选（地点/类型/费用/搜索/单日） | 筛选后没有{…} | 既有「清除筛选」 |

对象名沿用原 CP07 口径（`已完成的充电` / `充电记录`），无数据档字符串与改前逐字一致，既有断言不变。

## 4 MG09 三要素接线点

| 接线点 | 现状句（原因） | 时间行 | 动作 |
| --- | --- | --- | --- |
| 充电列表记录错误条 | 既有 `error` 消息（共享构造） | 新增：有旧快照时 `dataAsOfLine(listCheckedAt)`「数据截至 HH:mm」 | 既有「重试」 |
| 充电详情明细错误块 | 既有 `detailError` → InlineBanner message | 有旧快照（`detail != null`）时 `dataAsOfLine(detailCheckedAt)` | 「重试」（`actionSemanticLabel: 重试读取充电明细`；404 不可用时无动作，保留「返回上一页」） |
| 充电详情曲线错误块 | 既有 `seriesError` → InlineBanner message | 有旧快照（`series != null`）时 `dataAsOfLine(seriesCheckedAt)` | 「重试」（`重试读取充电曲线`） |

语义不变：InlineBanner 正文自带 liveRegion，取代原先手工 `Semantics(liveRegion: true)`；动作槽沿用 D-AP08-03 对象名机制。错误文案本体（共享构造）逐字未动。

## 5 起始线守卫（任务 4）

grep 既有测试（test/charging*、test/apple_polish_ap10*）：记录行/地点行的「卡内 16」此前**未被断言**（cardPad 断言只存在于 design_components/ap04/ap07 等共享组件用例），故新增守卫：

`test/charging_test.dart` 新用例「记录行与地点行守 R24 两条起始线」：记录行 InkWell（`charge-9`）与地点行（`chargingLocationKey('geofence:1')`）各有 `EdgeInsets.symmetric(horizontal: MileafSpace.cardPad)` 的祖先 Padding（`_cardRow`）；记录卡行间分隔线 Container margin 左缘 = cardPad（与文字同一起始线）。夹具说明：expansionResponse 按 `ended_at` 过滤后只剩一条已完成记录，用例把首条记录克隆为第二条已完成记录以产生行间分隔线。既有测试未覆盖的部分仅此一处，无重复造轮子。

## 6 测试

- `test/charging_test.dart`：守卫用例新增；其余充电面用例零改动全过。
- `test/charging_reading_test.dart`：R10 映射——「地点与记录消失时给出一致空结果」的空态句由 `这段时间没有已完成的充电` 改 `筛选后没有已完成的充电`（四档映射的结构性结果，业务断言未放宽：仍断言空态句 + 筛选条件行 + 清除筛选并存）。
- `test/charging_detail_test.dart`：曲线失败（无快照）时 `find.textContaining('数据截至') findsNothing`；明细失败有快照时 `findsOneWidget`。
- S06/S07 补录测试（`charging_cost_test`、`charging_cost_refresh_test`、`apple_polish_ap10_test`）零改动全过。

## 7 copy guard 基线变化

| 文件 | 基线 | 说明 |
| --- | --- | --- |
| `charging_page.dart.txt` | 119（不变） | 空态分档复用 `state_feedback` 构造，页内中文字面量行 118 ≤ 119（下降放行） |
| `charging_detail.dart.txt` | 80 → **82** | 两行新增动作读屏对象名「重试读取充电明细」「重试读取充电曲线」（D-AP08-03 对象名机制），无旧文案放行 |

## 8 验证

- `tool/flutterw analyze`：本次文件 0 诊断（全库残余诊断属 `creator/` 工作区与 `apple_polish_ap10_test.dart` 一条既有 info lint，均不在本次 diff）。
- 锁内测试（charging / charging_reading / charging_detail / charging_expansion / charging_cost / charging_cost_refresh / apple_polish_ap10 / apple_polish_copy_guard / days_migration_state / days_migration_color_guard）：除 copy guard 基线计数一项外全过，唯一失败为 `lib/src/drives_page.dart 46 > 45`，属 DM05 在途持有文件（非本包范围，由 DM05 登记基线）。
- MG01 渲染图册：`days-matter-migration-renders/dm06/`（列表 5 机位 × 浅/深来自既有 charging_rows_render_test；详情 4 张来自本包新入口）；浅/深目验结论与彩色面积登记见 [days-matter-migration-color](days-matter-migration-color.md) §4.1。
- 真机字体、读屏与性能仍属 #16/#17 外部 gate，本次不关闭。

## 9 遗留

1. `BannerTone` → `MileafStatusTone` 参数替换与枚举删除需改 `state_view.dart`（组件持有方），DM05–DM07 全部接线后由集成包统一收口。
2. 空态「离线」档在本页为零触发档（无离线信号）；若未来 workspace 提供连通性状态，需补接线。
3. copy guard 基线 `drives_page.dart`（46>45）与 `statistics_usage_page.dart` 为并行包在途缺口，非本包文件。
4. 充电列表/详情彩色面积为渲染目验估算（非像素统计）；量化采集口径按 DM01 §3。
