# v1 验收记录与复验

本轮采用用户确认的主要边界：通过完整 App 操作和可控 HTTP 响应验证结果。平台安全存储、发布网络栈、地图授权/坐标和最终真实站点对账保留双端真机验收。2026-10-23 用户允许先完成代码和自动化；未具备外部条件的条目不关闭 Ticket，不移除原生阻塞边。

## 2026-10-25：展示体验验收补充

本轮已按用户要求澄清[图表为主的可视化基线](../product/visualization-requirements.md)，不是 UI 已完成。V01–V08 与 A01–A06、Spec T17–T18 为新增必验项，概览/统计/详情不能以文字字段或逐桶进度条验收；当前缺口包括概览真实趋势、多指标完整图表及实际页面视觉证据。现有基础曲线和 App/HTTP 测试可复用，不自动获得新增验收结论。

后续保存代表页面原型及具体方案的用户评审、固定合成数据的实际浅深色渲染、360×800/100% 首屏层级和 360 宽/200% 字号证据；逐项记录坐标/单位/图例、选点/切指标、真实 0/null/负值、局部失败及双端手势/读屏。数据正确性、视觉质量、真机体验分别记录，任一缺失不得称整体通过。当前这些新增项均为待设计/实现/验收，不仅是缺少外部设备条件。

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
| T01/T02 接入、初始化和登录 | widget/session/setup | 双端发布网络栈及初始化/登录实测 |
| T03/T04 会话、替换连接与多车竞态 | session/connection_management/overview/full_flow | 安全存储、真实车辆消失与切车 |
| T05 概览与新鲜度 | overview/full_flow | 真实采样核对；新增主图另见 T17 |
| T06 列表和分页 | drives/charging | 真实长历史浏览 |
| T07 进行中与详情独立恢复 | drive_detail/charging_detail/drive_map | 同车真实会话及局部失败复验 |
| T08 序列与图表 | drive_detail/charging_detail | 真机读数/读屏；完整视觉另见 T17–T18 |
| T09 驾驶/充电统计与归期 | statistics/charging_statistics | Grafana 同口径对账；新增图表另见 T17 |
| T10 单位与币种 | charging/charging_detail/charging_statistics | 真实站点币种核对 |
| T11 日历与时区 | overview/drives/charging/statistics | 双端设备换时区、时区数据库升级复验 |
| T12 条件响应和错误恢复 | overview/business_recovery/各页面 | 实际反向代理与弱网恢复 |
| T13 平台接入 | widget/session/connection_management | HTTPS、无效证书、可信 HTTP、局域网权限、安全存储真机证据 |
| T14 地图 | map_candidate/行程地图 App 测试 | 正式供应商/许可/CRS校准/大陆双端网络/首图 |
| T15 导航与可访问性 | 各页面 360宽/200%浅深色测试 | Android/iOS返回及TalkBack/VoiceOver |
| T16 契约与指标 | 冻结OpenAPI、真实响应、full_flow | 本次真实后端复验、Grafana对账 |
| T17 可视化覆盖与交互 | 尚需补充主图/多指标交互与实际绘制核验，不以旧测试替代 | V01–V08 逐项图形/来源/入口；G01–G08 缺口记录；概览 stats 独立恢复及性能终点 |
| T18 页面视觉与体验 | 尚无符合新基线的原型评审及固定页面渲染证据 | 概览/两类统计/两种详情/两类卡片；首屏、浅深色、大字体、双端手势/读屏和视觉评审 |

测试文件名以最终仓库内容为准。测试通过数、构建版本和审查结果另以本轮最终集成验证记录为准，不用切片历史数字代表最终代码。

## 外部验收时必须保存的内容

每项记录 App commit/构建模式/设备型号/OS/Server commit/TeslaMate版本/时区/资源ID/区间及口径、预期和实际结果。真实轨迹、站点地址、口令、token、地图 key 不入库、不进入公开 Issue。对账以同车同区间和同口径比较，不用图形近似判断。差异应说明归期、采样、缺失费用或净/毛口径等可复现原因。

性能按 Spec 的设备、80ms RTT、10/2Mbps、5万行程/50万位置、每指标每平台至少30次执行，失败数保留。没有设备样本时不填写 p50/p95、不称达标。构建不等于最低系统启动、网络、地图或性能验收。

修订后的概览计时包含本月 stats 主图实际可读，热恢复包含缓存主图可读；既有 summary framework 标记不足以证明终点。后续调整测量标记并按同一预算复测，不能省掉主图来满足性能。
