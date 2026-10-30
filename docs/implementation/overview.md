# Ticket #8：选车与概览代码切片

2026-10-25 修订说明：本文是原代码切片的历史证据，不代表新展示基线已交付。后续按[可视化 V01](../product/visualization-requirements.md)补电量图形、关键卡片和真实本月每日里程主图，stats 与 summary 独立加载/恢复，首屏及实际绘制另验；不能继续仅凭文字字段验收 #8。

## 交付与边界

WorkspacePage 提供顶部选车、四个业务入口以及概览进入设置。尚未实现的三个业务入口明确显示未交付，最近记录保留资源类型与 ID 的下钻意图，不伪装已有详情。OverviewPage 独立处理 summary 的加载、快照、失败和请求序号，刷新不占用会话全屏 loading。

选车按准确站点保存普通非敏感偏好；单车自动、多车恢复有效 ID，否则首项。快速切车使用新的页面 identity，清掉旧车内容；迟到结果还要通过会话 identity、车辆 ID 和请求序号检查。summary 404 重读车辆列表，所选车确实消失时恢复仍存在车辆并明确提示。

概览只展示响应中已有结果，使用额定/理想单值续航、公制与明确单位。null 是缺失、零为真实零；休眠不是错误。位置采样、状态开始、最近状态区间起始和校验时间分开。最近充电功率仅在 charging 状态且数值不缺失时可见。meta tested=false 仅提示未测，schema_ok/units 缺省采用固定 OpenAPI 的默认值，不误判结构错误。

## 后续切片接口

- `VehicleWorkspace` 是当前会话业务上下文：selectedId、calendar、cache、revision、select、foreground。SessionController 仍是唯一凭据拥有者。后续页面以选车/日历 revision 作为页面 identity，并持有各自资源 loading/error/data；不要复用 session.loading 存放业务加载状态。
- `CalendarContext` 从 flutter_timezone 5.1.1 读取设备 identifier，timezone 0.11.2 的 latest_all 数据处理日历/DST。local 返回当前 IANA 下时间；midnight 接受日历日期字段，nextDays 按日历构造次日，不能替换为固定24小时相加。无法获得有效设备 IANA 时显式回 UTC。设备前台换日/时区会使相关查询上下文失效。
- `BusinessCache.get(capturedSession,path,{query,force})` 经同一 SessionController GET 和网络策略，返回 body/etag/validUntil/checkedAt。缓存键是准确站点、会话代次、路径、排序后的完整查询。force 用于手动条件校验；默认按 max-age。304 复用相同键体与采样时间，仅更新校验时间；缺体最多一次不带条件头 GET 恢复。no-store 不保留业务缓存，新的200不继承旧 ETag。各业务响应是内存对象，不写磁盘。
- `SessionController.request` 和 `MileafApi.request` 新增可选 query，前者还有可选额外 headers；Authorization 始终由当前捕获会话覆盖，所有 GET 继续继承可信 HTTP、禁止跳转和超时/证书策略。路径与查询分开，由 Uri 编码，不能把问号拼进路径。
- 固定 OpenAPI DTO 生成器现在支持 `tool/flutterw dart tool/generate_auth_contract.dart <output> <Root...>`，输出仅指定 root 的引用闭包。概览使用 Summary/Meta 输出，保留无参数生成认证 DTO 的兼容性。各输出独立、自带基础解码函数，业务 import 使用前缀；当前生成器支持本票实际使用的标量、nullable、ref、默认值，数组等由对应实际消费者扩展。
- 概览页面仅在其路由当前可见时响应前台；设置保留连接与本地访问入口，并从“服务版本与兼容性”二级入口独立校验 meta。后续行程/充电/统计页面应沿用当前可见资源的前台校验，不能并行刷新所有 tab。切车或会话变更时详情路由必须退出。

## 验证证据

按已确认 App 操作 + 可控 HTTP 边界，先以读取固定后端 summary 的测试失败开始，再实现并逐条验证。新增测试覆盖200→304、无体304普通GET、日期/IANA变化、有效期内前台复用、切车迟到、重启偏好、刷新失败快照、404失车恢复、零/null/休眠、meta默认值/未测提示、360宽200%字体深色布局；既有认证测试更新为从顶部选择器阅读全部车辆，不再假定永远停在车辆目录。

固定 summary 样本来自项目已有 `.cache/api-fixtures` 合成数据，不是用户真实轨迹。合并连接替换切片后运行完整 Flutter 行为测试54项通过。静态分析、格式与固定源生成复现作为提交前门禁。

## 保留待验

本票不宣称双端release与真实站点概览联通已通过。设备 IANA 实际变化、原生偏好跨进程恢复、真实站点指标对账、双端屏幕阅读器与真机可达性仍待外部验收。用户2026-10-23已授权代码/自动化先行，此 Ticket 及原生验收依赖保持开放，不擅自关闭或改变阻塞图。
