# T03 / Ticket #4 地图候选（未通过前置验收）

## 当前状态

只交付可验证的候选渲染边界与独立研发演示；**未选定正式底图供应商，#4 保持未完成，#11 仍被阻塞。** 未取得发行方地图授权/key、真实校准轨迹、双端真机和中国大陆验收网络，不能以 HTTP 测试中的图片证明真实底图或地区可用性。

渲染器候选为纯 Flutter `flutter_map 8.3.2` / `latlong2 0.9.1`，顶层版本及传递依赖已锁定。其环境声明允许本工程的 Flutter 3.47.7 / Dart 3.13.5，但 release 构建、设备、网络和坐标证据须分别记录。没有修改正式 App 导航；验证入口是独立 target。

## 演示与发布方配置

研发可用项目入口 `tool/flutterw run --target=tool/map_demo.dart` 查看未启用状态。若需加载真实服务，由发布方以不入库的 `--dart-define-from-file=<配置文件>` 为该独立 target 注入：

- `MILEAF_MAP_TILE_URL`：有权用于本应用、允许移动端直接交互请求的 HTTPS XYZ 模板，含 `{z}` / `{x}` / `{y}`。
- `MILEAF_MAP_ATTRIBUTION`：所选服务要求的完整可见来源/版权/审图号。
- `MILEAF_MAP_CRS`：此候选仅支持 `EPSG:4326` 经纬度输入、由标准 Web Mercator renderer 投影；不转换 GCJ-02/BD-09，不猜测源坐标。

配置文件和真实 key 不提交、不打印；客户端凭据会进入构建产物，不能当成服务器保密凭据。若供应商不允许这种客户端配置方式，应换合法方案，而非把私有服务器 key 打包。端用户不注册地图账号、不填 key。配置字段或非空署名不能证明合法授权，发布方仍须留存供应商允许该用途的依据。

默认无服务，不联网；明确同意后才向第三方请求。告知第三方收到 IP 与当前可见区域，无站点 Bearer、无 GPS 权限、无定位插件、无遥测 SDK。拒绝 HTTP、userinfo、缺模板、无署名和公共 OSM 端点。候选只有内存图片缓存，未实现供应商特定的持久缓存策略；正式选型必须验证其服务条款允许此方式，否则不能沿用。

独立 tile HTTP client 不自动重定向、不自动重试；连接5秒、响应总时限15秒。HTTP/解码错误转为不含 URL/key/坐标的统一异常，再交给 flutter_map（该包会输出异常）。错误只影响地图，显式重试后重新加载。供应商变化重新征得同意，旧代次失败回调被忽略。不得传入附带站点认证的共享客户端。

合成点只用于查看单点/分段/缩放和边界适配，不是实际行程或校准点。缺失、非有限、越界坐标断开；不跨缺失点连接，不改源数组。0点显示空态，1点显示标记，多点显示起终点；采样连线明确只是示意。此实现不承担真实行程详情或切车业务（#11）。

## 有限比较与未选定原因

- **高德官方 SDK**：中国地图、GCJ-02和官方转换机制明确，适合优先继续验证。需要发行方 Android/iOS key、许可范围和隐私合规配置；官方 Flutter 3.0.0 说明页较旧，不能据其“Flutter >=1.20”宣称现代 Flutter/Gradle 已通过。SDK自采集行为须符合当前无遥测边界，不得硬设用户隐私已同意。若选择高德，需另行验证官方转换调用边界及原生兼容，当前纯 Flutter 候选不自动支持。
- **flutter_map + 经授权 XYZ 服务**：渲染与供应商分离、易隔离请求，但许可、缓存、地名层、参考系和大陆网络由具体供应商决定。本候选不绑定未核准服务。
- **公共 OSM**：官方无 SLA、可限流/封禁，要求明确 UA、可见署名、遵循缓存头（无法读取则至少7天）、禁止批量和离线下载。本候选无相应持久缓存，因此直接拒绝其公共端点，不能当无限免费默认底图，更没有大陆双端可用证据。
- **天地图**：本轮官方开发站不可读取，当前移动端key类型、配额、费用和许可未核实，不能作为已通过选择。

## 源坐标证据和校准缺口

TeslaMate v4.3.0（`cf1380d3c1a57dc8ee3c204366ea2dd8e3e1902d`）的 REST position 直接采用 `drive_state.latitude/longitude`，streaming采用 `est_lat/est_lng`；没有采用 `native_*` 或记录源CRS。固定后端 Mileaf Server `146cb3b9a16af3d632b04ed8d197d0f2243d9b71` 把 positions 经纬度直映射为 lat/lon，没有转换或CRS字段。

这证明数据流，不能仅靠字段名证明所有地区/历史/streaming记录的CRS。WGS84仍是待真实校准的假设，不用于自动给真实数据贴已核准标签。地图组件要求调用方显式传入源CRS；独立演示只给自己的合成点指定EPSG:4326。正式接入需固定已知地点、核准输入坐标和供应商参考结果，记录误差方法与阈值依据；不能凭“看起来在路上”验收。

## 已验证与下一步

App/HTTP行为测试覆盖默认不联网、未核准CRS阻断、明确同意、专用请求不带 Authorization/不重定向、单点与缩放、失败局部重试、0/缺失/无效点、多段起终点和视野适配、不安全配置拒绝、供应商授权隔离。测试瓦片为确定性的透明 PNG，仅验证加载协议与可见操作，不代表真实地名底图。Dart格式与静态分析通过。

正式通过#4还必须补：供应商/套餐/费用/配额/署名/隐私和缓存约束、非公开凭据配置、固定真实校准样本、Android/iOS release真机型号/OS/构建版本、运营商/大陆网络、缩放适配/无GPS权限/断网恢复、首图耗时与成功率。完成前不得关闭#4或解除#11依赖，也不得以永久未配置界面替代Spec。

## 官方依据

- [flutter_map 8.3.2环境声明](https://raw.githubusercontent.com/fleaflet/flutter_map/v8.3.2/pubspec.yaml)、[官方文档](https://docs.fleaflet.dev/)
- [OSM瓦片使用政策](https://operations.osmfoundation.org/policies/tiles/)
- [高德Flutter集成/key与隐私](https://developer.amap.com/api/flutter/guide/map-flutter-plug-in/map-flutter-info)、[旧兼容性说明](https://developer.amap.com/api/flutter/guide/map-flutter-plug-in/map-compatibility-info)
- [高德GCJ-02说明](https://developer.amap.com/faq/advisory/others/39838)、[坐标转换](https://developer.amap.com/api/webservice/guide/api/convert)
- [高德SDK隐私要求](https://developer.amap.com/api/compliance-center/check-and-reference/sdkhgsy)、[来源/审图号](https://developer.amap.com/api/compliance-center/check-and-reference/compliance)
- [高德用途许可](https://lbs.amap.com/faq/advisory/authorization/43168)、[许可协议](https://developer.amap.com/pages/authorization/)、[动态费用/配额](https://developer.amap.com/upgrade)
- [Tesla官方Location字段](https://developer.tesla.com/docs/fleet-api/fleet-telemetry/available-data)
- [TeslaMate v4.3.0持久化来源](https://github.com/teslamate-org/teslamate/blob/v4.3.0/elixir/lib/teslamate/vehicles/vehicle.ex#L1749)
- [天地图开发站](https://developer.tianditu.gov.cn/)（本轮不可访问，未据此作已核准结论）

### 本轮检查记录

2026-10-22：7个地图候选行为测试与既有12个App测试全部通过；Dart格式检查、静态分析和diff whitespace检查通过。没有运行Android/iOS整包构建：集成任务发现Flutter构建子进程仍可能优先读取主机SDK配置，正等待隔离方案确认；不能以环境变量/local.properties假称问题已解决。本票尚无release或真机通过证据。
