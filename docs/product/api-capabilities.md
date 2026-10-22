# 行笺移动端：API 能力与差异

核验日期：2026-10-22。后端本地 HEAD：`0debc98`，核验时工作区无未提交变更。
TeslaMate 本地 HEAD：`6bf3d55e`；后端文档声明的已测兼容基准为 v4.3.0，不能据此宣称本地开发版已验证。

本次仅静态阅读源代码、文档及测试；没有启动服务、连接真实数据库、运行后端测试或导出 OpenAPI。
“已实现”表示存在已注册路由及实现，不表示本轮验证了运行结果或性能。

## 实际接口与屏幕映射

下表以 `/v1` 为前缀。health、auth 匿名，其余业务接口需要 Bearer token。

| 方法与路径 | 实际返回/能力 | 移动端用途 |
| --- | --- | --- |
| GET /health | status、version；数据库不可达可返回 503 | 连接检查，不是初始化状态检查 |
| POST /auth/setup | password 设置站点口令；成功 status=ok；重复 409 | 可选的显式初始化入口 |
| POST /auth/login | token、expires_at | 登录与会话恢复 |
| GET /meta | version、teslamate_schema_version、schema_ok、tested、units、source_unit_of_length、freshness | 设置与兼容性提示 |
| GET /vehicles | Vehicle 数组，含 id/name/model/vin_suffix、state、battery、freshness | 车辆选择；响应不是 items 分页包装 |
| GET /vehicles/{id}/summary?tz=… | vehicle、state、battery、odometer_km、charging_power_kw、period、last_drive、last_charge、firmware、freshness | 概览 |
| GET /vehicles/{id}/drives | items、next_cursor；行程含时间、距离、时长、能量、净电耗、start/end 地点 | 行程列表 |
| GET /drives/{id} | 列表字段 + vehicle_id、平均/最高速度、最大功率、内外温度均值、range_kind、起终点电量 | 行程详情指标 |
| GET /drives/{id}/series | drive_id、resolution、points、series；每点 t/lat/lon，按 fields 返回指标 | 地图与速度/电量/海拔曲线 |
| GET /vehicles/{id}/charging-sessions | items、next_cursor；起止时间/电量、时长、两类能量、cost、is_dc、location、is_active | 充电列表 |
| GET /charging-sessions/{id} | 列表字段 + vehicle_id、温度均值、起终点电量、charger_phases_mode | 充电详情指标 |
| GET /charging-sessions/{id}/series | session_id、resolution、points、series；t 及所请求的 power/soc | 功率、电量曲线 |
| GET /vehicles/{id}/stats | kind=driving/charging 分别返回 buckets、totals | 统计页需按 kind 分别请求 |

## 调用约束

- 地址：约定用户填写服务根地址，客户端拼接 `/v1`；反向代理路径前缀不能被丢弃。
- 列表：from/to 可省略，提供时必须带时区；半开区间 `[from,to)`，按 started_at 筛选。
  limit 默认 20，范围 1–100；cursor 不透明，按开始时间及 id 倒序分页。
- 统计：from/to 必填且跨度大于 0、不超过 730 天；bucket 为 day/week/month/year，
  tz 默认 UTC。周一为周起点，按 IANA 本地日历分桶，不按固定秒数跨夏令时。
- 已完成行程按 started_at 统计；已完成充电会话按 ended_at 统计，进行中不纳入统计。
- 行程序列：fields 默认 speed，可选 speed,battery,elevation；点字段为 speed_kmh、battery_level、elevation_m。
- 充电序列：fields 默认 power,soc，点字段同名。两类序列 points 默认 200、范围 2–1000。
  可选字段未请求时省略，请求了但缺失时为 null；series=[] 是成功空结果。
- 序列按 t 升序；resolution=server_sampled 不代表原始点数更多，也不提供完整轨迹保证。
- 公制值：km、km/h、kWh、kW、°C、Wh/km；duration_min 为分钟。
  source_unit_of_length 是 TeslaMate 展示偏好，不能触发服务端值的二次换算。
- ETag/304：车辆、概览、列表、详情、序列和统计具备条件响应能力；业务资源通常 max-age=30，
  车辆列表使用服务配置的缓存 TTL。统计没有进程内结果缓存；不应将 304 当作空 JSON。

## 指标口径

| 指标 | 客户端应采用的语义 |
| --- | --- |
| battery.range_km / range_kind | 当前是 rated 或 ideal 中的一个值，由服务端偏好选择，不是两条续航同时返回 |
| drive.consumption_wh_km | 净电耗；源自选定续航差 × 效率 ÷ 里程，非电网侧电耗 |
| stats.consumption_wh_km_net / gross | 分别是净/毛电耗；直接展示后端 totals，不平均各桶比率 |
| energy_added_kwh | 充入电池的能量；概览 last_charge.energy_kwh 使用此口径 |
| energy_used_kwh | 电网侧消耗，和充入能量分开；上游可为空 |
| cost / cost_per_kwh | 费用和均价，不含币种；均价只以费用已知记录的对应能量作分母 |
| is_dc | true=DC、false=AC、null=未知，不能把未知归为 AC |
| dc_energy_share | DC 能量在已知分类能量中的占比；不是 DC 次数占比，也不一定以总能量作分母 |
| Location | display_name 优先按围栏、地址逐级回退；字段还含 geofence/address/lat/lon |
| freshness.last_position_at | 最后位置点采样时间，用来说明位置/电量快照的来源时间 |
| freshness.last_state_at | 最近状态区间的开始时间；不能用它单独判定车辆停止采集 |

若充电分类未知能量不为零，AC 与 DC 能量之和可能小于总能量，不能强行拉伸成“全部能量”的饼图。
当前未单列 unknown_energy 字段；如需展示第三类，先在 spec 确认推导口径或提出后端需求。

## 源文档与实现差异、未提供能力

| 项目 | 核验结果 | 对移动端的影响 |
| --- | --- | --- |
| 后端 AGENTS/README 的实现进度 | 仍有“代码尚未落地”“后续业务端点”等旧描述，实际 app 已注册上述路由 | 不依据旧进度描述重复设计后端；本轮不修订外部仓库 |
| “每个 DTO 都有 freshness” | 实际出现在 meta、车辆及概览；历史列表/详情/序列/统计没有 | 不编造逐项最后采样时间；请求成功时间单独标注 |
| 续航文案 | 旧范围提到额定/估算；模型为 rated/ideal 单值 | 核实中文映射，不将 ideal 随意标成 estimated |
| 行程电耗说明 | API 通用表称“网侧单值”，实现与 energy.py 注释为净电耗 | 准备材料以已核实公式为准；后续需后端维护者统一文档 |
| 充电温度/费用明细 | 只有 outside_temp_c_avg、cost 等字段，没有温度序列、分时电价明细 | 不承诺温度曲线或费用构成，只展示已有总额/均价 |
| 币种 | meta 和费用字段均无 currency | 不直接硬编码人民币符号；需决定本地币种配置或无币种展示 |
| 初始化发现 | 无匿名 auth/status；health 不返回 initialized | 显式初始化入口或交由管理员预先初始化，需二选一 |
| 会话管理 | 无 refresh/logout/revoke 端点 | 过期重新登录；本地退出不宣称撤销服务端 token |
| schema 兼容 | meta 中有 tested；结构不兼容可能直接导致启动失败 | 不能依赖一定拿到 schema_ok=false；需处理站点不可用 |
| 图表时间空洞 | 返回时间戳与 null，不返回独立 gap 段描述 | 显示空洞规则需在 spec 固定，不跨缺失数据伪造连续性 |
| 地图 | 有 lat/lon，无底图服务、坐标系字段或路线规划 | 供应商与坐标参考系需要核实；不是已有完整地图能力 |
| 错误 OpenAPI 描述 | 有统一运行时错误 envelope，未见完整声明各路由所有错误响应 | 生成 Dart 客户端前检查契约，不能假设生成器覆盖全部失败分支 |

统一错误结构为 `error.code` 与 `error.message`，并有 X-Request-ID。
需处理 unauthorized(401)、already_initialized(409)、rate_limited(429)、
not_found(404)、invalid_request(400 或部分参数校验的 422)、
db_unavailable/upstream_timeout(503)、internal_error(500)。
这些是产品错误映射建议的依据，尚未实施移动端错误处理。

## 证据与核验边界

- [应用路由注册](../../MileafServer/src/mileaf/app.py)
- [认证实现](../../MileafServer/src/mileaf/auth.py)、[元信息](../../MileafServer/src/mileaf/meta.py)
- [车辆](../../MileafServer/src/mileaf/vehicles.py)、[概览](../../MileafServer/src/mileaf/summary.py)
- [行程](../../MileafServer/src/mileaf/drives.py)、[充电会话](../../MileafServer/src/mileaf/charging_sessions.py)、[统计](../../MileafServer/src/mileaf/stats.py)
- [能量口径](../../MileafServer/src/mileaf/queries/energy.py)、[地点](../../MileafServer/src/mileaf/queries/locations.py)、[序列](../../MileafServer/src/mileaf/queries/series.py)
- [API 文档](../../MileafServer/docs/api/v1-surface.md)
- 已阅读相关测试：认证、meta、概览、稳定分页、序列边界、统计口径/时区；测试文件存在不等于本轮通过。

后续进入实现前应取得固定版本的 OpenAPI，核对 nullable/可选字段、Bearer 安全定义、
错误 envelope、304、统计联合响应和参数类型，再验证 Dart 生成结果；本轮不选生成器。
