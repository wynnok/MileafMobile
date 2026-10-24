# v1 验收记录与复验

本轮采用用户确认的主要边界：通过完整 App 操作和可控 HTTP 响应验证结果。平台安全存储、发布网络栈、地图授权/坐标和最终真实站点对账保留双端真机验收。2026-10-23 用户允许先完成代码和自动化；未具备外部条件的条目不关闭 Ticket，不移除原生阻塞边。

## 证据的区别

- `test/fixtures/source.json` 记录固定 Server `146cb3b9a16af3d632b04ed8d197d0f2243d9b71`、固定时间、合成 PostgreSQL 数据和实际认证 HTTP ASGI 导出的样本。没有导出 setup/login 响应、token 或真实轨迹。
- 页面测试消费这些响应，并明确改变个别值模拟 null、进行中、迟到、304、错误或跨时区。完整流程测试只把概览最近资源 ID 对齐到固定详情资源，不声称其为一次实时服务请求。
- `test/full_flow_test.dart` 以真实 App 导航串起连接、登录、四入口、两种详情、兼容信息与退出；不是发布构建真机测试。
- `docs/contracts/openapi-v1.json` 是生成源；`tool/generate_auth_contract.dart` 生成各 DTO 闭包。运行时契约、自动化行为和设备验收分别记录，不能相互替代。

## 可复现的真实后端样本刷新

在仓库根运行；使用只读参考后端已有 `.venv`，不安装包、不改参考仓库：

```sh
UV_CACHE_DIR="$PWD/.cache/uv" PYTHONDONTWRITEBYTECODE=1 \
  uv run --no-project --no-managed-python \
  --python "$PWD/MileafServer/.venv/bin/python" \
  python tool/export_contract_fixtures.py
```

脚本不接受数据库 URL，只使用参考后端的合成测试夹具，要求 Docker 已运行且本机已有 `postgres:16-alpine`；不自动拉镜像。先检查 Server commit 和运行时 OpenAPI，再通过真实 setup/login 获取本次内存 token，读取 13 个业务响应到 `.cache/contract-refresh/`。结束逆序关闭应用、reader、连接、临时数据库、容器，并清理本次临时认证目录。刷新不会自动覆盖已提交样本；审查差异后再更新。异常只输出阶段和类型，避免泄露连接信息。

2026-10-24 本次刷新尝试在数据库准备前停止：本机 Docker socket 不存在，Docker 服务未运行，没有创建数据库或认证状态。本次不可将刷新记为通过；保留此前实际响应来源记录及现有固定样本测试，待外部环境恢复再复验。

## 验收矩阵

| Spec 场景 | 自动化入口 | 额外待验 |
| --- | --- | --- |
| T01/T02 接入、恢复与无车辆 | widget/session/connection_management | 双端发布网络栈与安全存储 |
| T03/T04 归属、概览和最近记录 | overview/full_flow/详情测试 | 真实车辆消失和真实采样核对 |
| T05 行程列表与分页 | drives | 真实长历史浏览 |
| T06 行程详情与曲线 | drive_detail | 真机读数与屏幕阅读器 |
| T07 充电列表与详情 | charging/charging_detail | 同车真实会话对账 |
| T08/T09 驾驶/充电统计 | statistics/charging_statistics | Grafana 同口径对账 |
| T10 单位与币种 | charging/charging_detail/charging_statistics | 真实站点币种核对 |
| T11 日历与时区 | overview/drives/charging/statistics | 双端设备换时区、时区数据库升级复验 |
| T12 条件响应和错误恢复 | overview/business_recovery/各页面 | 实际反向代理与弱网恢复 |
| T13 平台接入 | widget/session/connection_management | HTTPS、无效证书、可信 HTTP、局域网权限、安全存储真机证据 |
| T14 地图 | map_candidate/行程地图 App 测试 | 正式供应商/许可/CRS校准/大陆双端网络/首图 |
| T15 导航与可访问性 | 各页面 360宽/200%浅深色测试 | Android/iOS返回及TalkBack/VoiceOver |
| T16 契约与指标 | 冻结OpenAPI、真实响应、full_flow | 本次真实后端复验、Grafana对账 |

测试文件名以最终仓库内容为准。测试通过数、构建版本和审查结果另以本轮最终集成验证记录为准，不用切片历史数字代表最终代码。

## 外部验收时必须保存的内容

每项记录 App commit/构建模式/设备型号/OS/Server commit/TeslaMate版本/时区/资源ID/区间及口径、预期和实际结果。真实轨迹、站点地址、口令、token、地图 key 不入库、不进入公开 Issue。对账以同车同区间和同口径比较，不用图形近似判断。差异应说明归期、采样、缺失费用或净/毛口径等可复现原因。

性能按 Spec 的设备、80ms RTT、10/2Mbps、5万行程/50万位置、每指标每平台至少30次执行，失败数保留。没有设备样本时不填写 p50/p95、不称达标。构建不等于最低系统启动、网络、地图或性能验收。
