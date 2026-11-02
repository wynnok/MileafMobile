# 0005 「正在充电」只能由车辆状态证明

- 日期：2026-11-02
- 状态：accepted（2026-11-02 用户选择 A：车辆状态不是 `charging` 时直接隐藏该行）
- 关系：修正 [Spec §7](../specs/mobile-v1.md) 第 184 条「充电依据 is_active」的口径；不改 API、不改 `MileafServer/`、不改只读边界、不改 A「夜航」版式。
- 影响文件：`lib/src/charging_page.dart`、`test/charging_expansion_test.dart`、`docs/specs/mobile-v1.md`。

## 1. 现象

真机截图：车早已停止充电，充电页顶部仍挂着「正在充电 · 清鸥府 / 已补入 27.56 kWh · 不计入已完成统计」。同一时刻 `/v1/vehicles` 与 `/v1/vehicles/1/summary` 都返回 `offline`。

## 2. 事实

三层证据，缺一层都不能下结论：

| 层 | 事实 | 出处 |
| --- | --- | --- |
| 列表接口 | `is_active = (ended_at is None)`，即 `charging_processes.end_date IS NULL` | `MileafServer/src/mileaf/charging_sessions.py:116` |
| 上游采集 | `charging` 状态收到 `offline` 只重排抓取，**不**结束进程；只有 `asleep` 或其它非充电状态才 `complete_charging_process` | `teslamate/elixir/lib/teslamate/vehicles/vehicle.ex:1264` |
| 权威判断 | 车辆状态取「最新未结束会话 + 其后无行程 + 自候选开始无 asleep/offline」，命中才写 `state='charging'` | `MileafServer/src/mileaf/queries/current_charging.py:10`、`vehicles.py:102` |

服务端自己把边界写在文档里：`v1-surface.md` §当前充电状态明确「上游停止采集且没有后续反证时无法识别实际结束」「历史会话的 ended_at/is_active 语义保持不变，不补写或修复 TeslaMate 数据」。

于是：充电中掉线的车，`end_date` 会一直是 NULL，`is_active` 会一直为 true；后端修好「车辆状态」这条链路后 `/v1/vehicles` 变 offline，但列表里的 `is_active` 按设计不会跟着变。

**结论：两个接口都按各自契约正确返回；前端拿历史语义的字段回答了实时问题。**

## 3. 决策

### D1 显示条件 = `is_active` **且** `state == 'charging'`

`is_active` 不再是「正在充电」的充分条件，只是候选条件。

- 为什么不用 `/v1/vehicles`：它与 `summary` 的 `state` 同源同值，但 `summary` 已经和概览共用 `BusinessCache` 键（`vehicles/{id}/summary?tz=`），切页命中率更高，还自带 `freshness` 供以后使用。
- 为什么不再加一次轮询：本页的刷新时机（进入、下拉、前台恢复、切车、改筛选）已经覆盖，加定时器会把只读页面变成准实时看板，超出本阶段边界。

### D2 状态未知也不显示

请求失败、格式不兼容、`state` 为 null 时一律不显示。宁可少显示一行，也不能在没有证据时说出「正在充电」——这正是这次事故的形态。

### D3 选择隐藏，而不是改成「上次充电未结束」

用户 2026-11-02 明确选 A。改文案需要用户理解「进程未结束」这一层上游概念，而当前页面已经有一句「已补入 … 不计入已完成统计」在解释口径；再加一句解释性状态会把注意力从「这次花了多少钱」拉到数据管道上。

代价（已知并接受）：`is_active` 为 true 但车辆不是 `charging` 时，这条会话在充电页完全不可见——列表默认按 `ended_at` 归期，未结束的记录本来也不会出现在记录列表里。

### D4 不改后端

`is_active` 的语义是「记录是否结束」，本身没错；把它改成「此刻是否在充电」会破坏所有按 `is_active` 判断记录完整性的调用方（含详情页的「进行中指标不代表最终结果」）。

## 4. 结果

- 掉线场景：行消失，页面不再出现与事实相反的状态。
- 真实充电且采集正常：`state == 'charging'`，行为与之前完全一致。
- 真实充电但采集缺失、最新状态仍是 `charging`：仍显示「正在充电」。这是上游无证据导致的盲区，`/summary` 的 `freshness` 将来可用于提示「数据截至 …」，本次不做。

## 5. 复查要点

1. 换车、换会话、能力降级时，`vehicleState` 必须失效并递增 `vehicleStateSequence`（否则在途请求会把旧车状态写回）。
2. 下拉刷新必须绕过缓存重读 `summary`（`force: true` 透传），已有用例覆盖。
3. 从概览切回充电页时不应额外发一次 `summary` 请求（同键缓存命中），已有用例覆盖。
4. 前台恢复沿用站点 `max-age`（默认 30s）内的快照；超过即重读。不为此加 `force`，因为服务端对同一 `summary` 也只缓存 30s，强制请求拿回的仍是同一份快照。
