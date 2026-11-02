# 充电页「正在充电」误报：实施记录

- 日期：2026-11-02
- 依据：[ADR 0005](../adr/0005-active-charging-evidence.md)、[Spec 增量 §2026-11-02](../specs/mobile-v1.md)
- 结论：充电页顶部「进行中充电」行改为需要车辆状态证明；`analyze` 干净，`test` 397 通过 / 23 跳过。

## 结论先说

**不是接口没返回对，是前端拿错了字段。** 两个接口都按自己的契约正确返回：

- `GET /vehicles/{id}/charging-sessions` 的 `is_active` = 上游充电进程没有 `end_date`（历史语义，不保证实时）；
- `GET /v1/vehicles`、`GET /vehicles/{id}/summary` 的 `state` 才是「此刻是否在充电」的权威判断，现在返回 `offline`。

充电页只读了前者，所以后端修好车辆状态后，这一行没跟着消失。

## 改了什么

| 文件 | 改动 |
| --- | --- |
| `lib/src/charging_page.dart` | 新增 `vehicleState` / `vehicleStateSequence`、`loadVehicleState()`、`activeConfirmed`；`loadActive()` 先同步车辆状态再拉会话；渲染条件由 `is_active` 改为 `is_active && state == 'charging'`；切车、换会话、能力降级时清空状态 |
| `test/charging_expansion_test.dart` | 新增 4 条：`summary` 返回 `offline` 时不出现「正在充电」且确实请求了 `summary`；`summary` 返回 503 时同样不出现；站点声明 `max-age` 时概览已读过的 `summary` 切页命中缓存不重复请求；下拉刷新绕过缓存重发 `summary` |
| `docs/specs/mobile-v1.md` | §7 第 184 条「充电依据 is_active」改为双条件，并追加 2026-11-02 增量 |
| `docs/adr/0005-active-charging-evidence.md`（新） | 决策与取舍 |

请求没有新增端点：复用概览页已有的 `vehicles/{id}/summary?tz=`，走同一个 `BusinessCache` 键，切页能命中缓存。

## 为什么这样改

1. **上游确实会留下永不结束的进程。** TeslaMate 在 `charging` 状态收到 `offline` 只重排抓取、不结束进程，等车再上线看到非充电状态才收尾。车在高架桥下、地库、隧道掉线充电，就会留下 `end_date IS NULL`。
2. **服务端已经把正确答案算出来了。** `current_charging_join` 要求「最新未结束会话 + 其后无行程 + 自候选开始无 asleep/offline」，`vehicles.py` 命中才把 `state` 写成 `charging`。这套判断故意不回写 `is_active`，文档写明「历史会话语义保持不变，不补写或修复 TeslaMate 数据」。
3. **前端没有第三种信息源。** 页面此前全文件没有 `summary`、也没有 `state` 引用，等于用历史字段回答实时问题。

## 边界与残留

- **状态未知一律不显示**：`summary` 请求失败或格式不兼容时也隐藏，避免"没证据却声称在充电"。
- **静默隐藏的代价**：若某次真实充电期间采集一直断、最新状态仍是 `charging`，会正常显示；反之"进程未结束但已离线"时整行消失，用户在充电页看不到这条会话——列表默认按 `ended_at` 归期，未结束记录本来也不进列表。已记录为后续候选（需要中性提示时再开票）。
- **不加 freshness**：概览会用 10 分钟阈值把陈旧数据标成「非实时」，充电页这行暂时没有；`/summary` 的 `freshness` 字段已就位。
- **详情页未改**：`charging_detail.dart` 仍按记录的 `is_active` 说「充电进行中，当前指标不代表最终结果」。那是对"这条记录尚未收尾"的陈述，且详情页有独立语义，不在本次范围。

## 双轴审查后的处理

Standards 轴无硬性违规；Spec 轴确认「非 charging 状态下仍显示」的路径已不存在。两轴共同指出的问题处理如下：

1. **能力变化只清值不失效（真 bug，已修）**：`loadCapability` 的 `changed` 分支补 `vehicleStateSequence++`，否则在途的 `loadVehicleState` 仍能通过守卫把旧车/旧能力下的状态写回。
2. **刷新绕过缓存缺覆盖（已补测试）**：新增「下拉刷新绕过缓存重读车辆状态」，用 `max-age` 响应头确认 `force: true` 真的重发请求。
3. **前台恢复不带 `force`（文档修正，不改代码）**：服务端对 `summary` 自身也只缓存 `cache_ttl_seconds`（默认 30s），强制请求拿回的是同一份快照，因此前台恢复沿用 TTL 内的快照即可；ADR §5 已改写这句口径。
4. **summary 失败静默（保留）**：这是 D2「没有证据就不声称」的直接形态。给失败加 banner 会把「读不到状态」升级成页面级错误，而它影响的只是这一行；`activeError` 仍只覆盖会话列表失败。
5. **串行两个请求（保留）**：并行会让行先出现后消失（先有 `is_active`、后到 state），闪烁比多一个 RTT 更糟；正常路径上 `summary` 多数命中缓存。
6. **共用 `Summary.fromJson` 解析（保留）**：优点是和概览同一份契约；代价是 summary 里任一必需字段不合规都会让这行消失。若站点契约真的坏了，概览页会同时报错，属于可接受的失败姿态。
7. **未采纳的抽象**：把 summary 读取抽成共享 reader、为车辆状态建枚举类型、把 `'charging'` 字面量收敛成映射——都会牵动 `overview_page.dart`，超出「修一个误报」的范围，留作下次重构的候选。

## 验证

- `tool/flutterw analyze --no-pub`：无问题。
- `tool/flutterw test --no-pub`：397 通过 / 23 跳过。
- 关键新增用例：`车辆已离线时不把未结束会话当成正在充电`、`无法确认车辆状态时不显示正在充电`；既有的 `进行中充电独立于按结束日统计和列表` 仍通过（共享 fixture 的 `state` 为 `charging`）。
- 真机复验仍未做：需要用户在新包上确认掉线场景下该行消失。
