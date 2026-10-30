# 行程扩展 A「出行回顾」

2026-10-27。已完成本地正式Flutter实现、自动化、渲染、双端隔离构建及两轴审查。用户确认仅实施产品方案顺序1的现有冻结API范围，沿用「湖畔」视觉。GitHub Spec #1、#9、#10、#11 已增量同步；不重复建票、不改依赖边，外部待验保持。

## 正式行为

- 列表直接展示逐趟估算净能量/净电耗，保留日期分组、地点回退、围栏/地址、进行中、游标去重和分页恢复；默认近30本地日，支持近7日和原有自定义日期。
- 期间完成行程次数、里程、估算能量、整体净电耗及每日里程/电耗读取独立driving stats。翻页不改变总计，不从分页求和或平均单趟比率。超过730×24小时保留列表，统计区域说明范围限制。
- 紧凑日图保留真实时间坐标、指标切换、点按/拖动、前后日读数与辅助功能，再进入当天记录。日定位与返回沿用所见统计快照的from/to；持续前台跨午夜也不会将新列表与旧统计混合。恢复前台跨日重算相对窗口，移出窗口的日筛选恢复完整范围。
- 列表与统计独立加载/错误/重试。顶部刷新校验两资源；统计失败保留原快照截止及已有列表。前台按资源TTL校验，切车、会话、时区与区间变化隔离旧值和迟到响应。错误与空态前置，200%字号纵向重排。
- 详情依次呈现路线/时间与地图、距离/时长/估算能量、电量区间及百分点差、净电耗与历史参照、过程图、驾驶与环境、更多明细。复用MetricTile分开数字和单位，均速/最高速度/最大功率/内外均温直接可达，地点/时间/端点电量/续航口径仍保留。
- 个人参照单独查询同车、行程开始日前30个完整本地日的全部路线完成统计，不含本次。仅在本次完成且正里程、有有效电耗和历史正里程/有效电耗时显示。长解释与完整区间进入说明，估算及覆盖未知提示留在卡片旁；不称同路线对照、不推断原因或驾驶好坏。
- 电耗对照采用同一Wh/km尺度和零基线，保留负值、真实0与null。现有EnergyComparison支持有符号范围；概览和充电正值行为经过完整回归。
- 速度/电量/海拔及地图共享采样选点，可打开同时间轴的独立电量小图。缺失坐标不定位、不跨缺口连线；null断线，不插值补点。地图在当前详情滚动期间保留状态，退出重开仍重新告知；新选点超出视口时重定位，未改变选点保留手动视图。
- 明细、序列、地图和历史参照独立恢复；401、404返回、304快照、进行中及null/0边界保留。进行中即使提供了两端SOC，也不输出最终百分点差或历史比较。

顺序2–4继续为候选，没有同路线比较、全区间搜索、功率回收或新后端契约。未读取生产配置/数据库，未修改外部仓库、依赖版本、原生配置或全局环境。

## 验证

- 最终完整回归：182项通过，1项可选渲染默认跳过；该渲染另行执行通过。
- trace开启的行程/详情/地图/完整流程回归：53项通过。这是标记开启后的行为验证，不是设备性能样本。
- 静态分析无诊断，53个Dart文件格式检查无变化，diff空白检查通过。
- 正式Flutter渲染：360×800逻辑像素、2倍导出、浅深色及100%/200%字号，共生成84张，归档本次行程相关24张，包含列表/详情首屏、参照、过程、电量对照和驾驶环境阅读位置。
- [正式图册](drives-expansion-renders/index.html)及[源码/图片/产物SHA-256](drives-expansion-renders/provenance.json)保留证据。图册使用固定合成HTTP响应与既有本地CJK/MaterialIcons字体，未复制字体。截图配置没有正式底图，地图降级可见，不能作为供应商许可/CRS/大陆网络或真机验收。

沿用已确认的完整App＋可控HTTP边界逐切片red→green；覆盖能量、统计总计、日期筛选/快照、730天、迟到响应、历史窗口/DST、地图选点和审查回归。旧固定位置测试改为实际滚动后访问界面，不增加缓存范围来维持屏外元素。

复现（项目根目录）：

```sh
tool/flutterw test --no-pub
tool/flutterw analyze --no-pub lib test
tool/flutterw dart format --output=none --set-exit-if-changed lib test
tool/flutterw test --no-pub --dart-define=MILEAF_RENDER_OUTPUT=build/drives-expansion-renders \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf' \
  test/lake_render_test.dart
```

## Standards

独立只读审查最终为0项未解决硬违规、0项需修复的smell。复核独立缓存、请求序号、会话/车辆/时区守卫、地图keepalive/dispose、选点、MetricTile、帮助层及同尺度正负对照，未发现新增规范或生命周期问题。

## Spec

初查3项P2均补失败回归并修复：进行中仍显示电量差；持续前台跨午夜时日定位/返回与快照错位；平移地图后新选点不可见。限定复核确认原3项解决、无新增实质需求错误，未解决项0项。完整测试结果以实际命令为准。

两轴未解决项：Standards 0 / Spec 0。

## 双端隔离构建

构建前冻结32个lib Dart文件摘要，构建后核对一致。沿用tool/flutterw、现有JAVA_HOME的Zulu21、项目Android SDK和项目级CocoaPods；不改HOME或全局设置。两端均保留LEGACY_STAT=DENIED、LEGACY_READ=DENIED、HOST_WRITE_OPEN=DENIED、PROJECT_READ_WRITE=ALLOWED。

- Android release：完整退出0，48秒、271 tasks，开发签名验证通过。APK：build/app/outputs/apk/release/app-release.apk；SHA-256：c4292d12661831dfe559d422b574125178cb47054b15419733bafe4f608c32c8。
- iOS release无签名：完整退出0，Xcode 37.7秒，Runner.app 19.6MB。Dart承载文件SHA-256：ba9c3cfaf8c64665efac9ccf039cc8ae2499334c6f60325d4a05f3a5d3a2d7bc。
- 中间一次显式填写了不存在的主机SDK路径，被wrapper拒绝为78；核对现有ANDROID_HOME后按原入口执行，不把中间尝试记为成功，没有绕过保护。

日志保留于项目忽略目录 .cache/drives-expansion/。构建不等于设备验收，当前性能样本N=0。

## 来源与收尾

本轮基准为原型提交7e32322f6393f723cf46dcaef5bfd64f9255c2e4。原型primary source继续保留在codex/drives-expansion-prototype，正式实现没有使用原型脚本或合成路线作为业务输入。

真实站点逐项对账、双端真机网络/字体/手势/辅助功能、正式地图许可/CRS/大陆网络及规模性能采样继续待验。未推送、部署、上架或关闭工单；既有未跟踪docs/prototypes/overview-expansion/与docs/.DS_Store保留。没有新增一次性依赖或主机资源。
