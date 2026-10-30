# A「湖畔」实施与验证记录

2026-10-26；集成分支 `codex/mileaf-v1`，最终产品代码 `369fd78`（主要页面实现 `c2a6a6a`）。用户已明确选择 A 方案，原型 primary source 为本地 `codex/mobile-visual-prototype` 的 `a965dc9`。本轮未推送、部署或上架；相关 Ticket 因既有外部验收未齐继续开放。Spec #1与#8–#17正文已同步并回读11/11匹配，标题/OPEN状态保留，本次未修改原生依赖边。

## 已交付的页面与指标

| 基线 / 工单 | 正式 Flutter 行为 | 验证入口 |
| --- | --- | --- |
| V01 / #8 | A主题、电量环、续航/状态及今日/月度卡片；本月每日里程主图独立读取stats，summary/趋势分别重试、缓存与归属隔离；最近记录可下钻 | overview、overview_visualization、business_recovery |
| V02 / #9 | 行程按本地日期分组，地点/距离/时长/净电耗分层，原分页与日期语义保留 | drives |
| V03 / #10/#11 | 默认速度及电量/海拔切换，真实时间轴和读数；现有地图边界接续；新增起终点电量区间图，次级指标可展开 | drive_detail、drive_map、data_visualization_app |
| V04 / #12 | 充电日期卡片、统一0–100%起止电量图、能量/费用层级；未知类型、费用与进行中保留 | charging |
| V05 / #13 | 默认功率/电量时间图，电量区间与两类能量独立比较，采样读数替代逐点长按钮列表，费用/温度等可展开 | charging_detail |
| V06 / #14 | 完整里程/次数/能量/最高速度时间图，净毛电耗独立同尺度比较，totals直接显示，桶明细保留等价读数 | statistics |
| V07–V08 / #15 | 能量/次数/费用/均价图，AC/DC绝对值与分组时间图，已知分类分母短提示；分组柱两端完整，DC描边支持非颜色区分 | charging_statistics、三桶实际渲染 |
| A06 / #16 | 概览性能framework候选需summary和主趋势同归属且实际绘图区完整在视口中；不把summary先到当完成 | overview_visualization、trace开启回归；性能N仍为0 |
| T17–T18 / #17 | 完整App闭环、主图交互、浅深色/大字体实际渲染及两轴审查 | full_flow、全部回归、[实际渲染图册](lake-renders/index.html) |

共用绘图保留真实时间位置、null断线、孤立点、真实0/负值、图例、可见刻度/单位及前后/键盘/辅助功能读数；纵向滚动不提前触发选点。柱形为整组预留边界，点选使用相同坐标规则。数值与单位分层，未知币种不硬编码符号；长口径与API字段名放帮助层。没有增加图表依赖、后端公式或新端点。

G01–G08 能力缺口继续按[产品基线](../product/visualization-requirements.md)记录，不将当前API当作长期覆盖上限，也不把原型合成数据作为真实后端能力。

## 自动化与实际渲染

- 默认 App/HTTP 回归：148项通过，1项默认跳过（可选渲染用例另行执行通过）。渲染用例默认显式跳过，不因缺本机字体影响常规CI。
- 静态分析：lib与test无诊断；Dart格式与diff whitespace检查通过，无依赖/锁文件变更。
- performance trace开启的相关概览/详情/全流程回归24项通过，不是性能样本或OS呈现证据。
- 可选渲染用例通过完整App导航和可控HTTP导出32张实际Flutter PNG：七类页面×浅深色×100%/200%共28张，另含三桶AC/DC边界/描边4张。360×800逻辑像素、2倍导出；[SHA-256清单](lake-renders/manifest.json)绑定产品代码。
- 测试进程显式载入本机已有Arial Unicode与MaterialIcons；图表绘图文字继承主题字体，未复制/分发字体或修改系统字体。Widget渲染仍不能替代Android/iOS实际系统字体、读屏或手势验收。
- 合成响应通过冻结DTO解码；图册不含真实站点地址、凭据或轨迹。地图未配置时如实显示现有降级，不以合成底图宣称真实地图验收。

复现命令（项目根目录；字体路径按验证环境显式给定）：

```sh
tool/flutterw test --no-pub
tool/flutterw analyze --no-pub lib test
tool/flutterw test --no-pub \
  --dart-define=MILEAF_RENDER_OUTPUT=build/lake-renders-final \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf' \
  test/lake_render_test.dart
```

最后一次验证中发现两个Flutter测试进程会竞争同一native_assets输出目录，后续渲染与回归改为顺序执行；没有通过改SDK、安装全局工具或删除共享环境绕过。最终以顺序命令退出0及对应日志为准。

## 两轴代码审查

固定比较点为用户指定续作基线 `b798298`，覆盖本轮主题、共用图表、概览、列表、详情、统计和测试。独立审查者只读核对后，由集成者修复并验证。

### Standards

0项明确规范问题，未发现有具体风险而需本轮修改的代码气味。业务只读、项目环境隔离、最高App/HTTP测试边界及手术式修改符合仓库约定。共用图表/卡片均有多个实际调用方。

### Spec

发现3项P2并全部修复：行程起终点电量缺区间图；短区间AC/DC首末分组柱被裁切；分组柱只靠颜色区分。已补独立SocInterval、共享绘制/点选端部空间、DC描边与对应图例；原审查者限定复核确认三项均可关闭，无剩余明确代码问题。补充行程未知/减少电量回归和三桶实际渲染，不以截图单独证明数据正确。

结果：Standards 0项；Spec原3项已解决、剩余0项。最终用户体验和外部条件仍按下节分别验收。

## 双端隔离构建与产物

最终行为版本369fd78的Android release退出0（39s，271 tasks）；iOS release无签名退出0（Xcode 27.8s，Runner.app 19.5MB）。两端使用相同最终产品行为。最后归档提交仅补文档/渲染证据和Dart格式化，不改运行行为，不因格式化重复原生构建。

两端探针均保留 `LEGACY_STAT=DENIED`、`LEGACY_READ=DENIED`、`HOST_WRITE_OPEN=DENIED`、`PROJECT_READ_WRITE=ALLOWED`。入口及沙箱脚本SHA-256与既有验证一致，未改HOME、全局配置、原版SDK或JAVA_HOME；Android仍用Zulu21.0.10、Gradle9.3.1及项目SDK，iOS使用既有项目级CocoaPods。设备run/install/drive保护保持。

- APK：`build/app/outputs/apk/release/app-release.apk`，59005846字节；SHA-256 `e808eee0f678e9acae4cf4625f820564f14d76db935164bef14fde4a0aca0ccd`；apksigner验证通过，研发签名，不是商店发行签名；打包minSdk24/target36。
- iOS：`build/ios/iphoneos/Runner.app`，最低15.0，无签名；承载Dart代码的`Frameworks/App.framework/App` SHA-256为`0b9b6fbfede0317f0a5233de4fece872d98709480e9ffd40eae4138077582d1d`。Runner启动器本身未改，不以其不变的hash证明UI版本。
- 日志在项目忽略目录`.cache/lake-implementation/`；这些构建日志不是性能数据。

## 外部待验及收尾

继续保留：双端真机网络/证书/局域网授权与安全存储、TalkBack/VoiceOver/返回手势/真实系统字体、真实站点和Grafana同口径对账、地图供应商许可/配置/源CRS校准/大陆双端网络、规模站点API复验与每平台每指标至少30次性能采集。当前性能N=0，不填p50/p95，不以构建或合成响应宣称通过。未访问生产连接或数据库，未改外部符号链接仓库。

本轮实现分支的未提交切片在中断后由主代理逐项接续，均合入当前产品代码；原始分支和工作树保存记录可追溯。临时探针和patch在成果保存后清理，三个实施工作树已通过可恢复归档保存原始未提交切片及分支；原型checkout被应用标记为本聊天primary，按工具保护保留供查阅，不绕过删除；项目依赖/缓存/构建及本地验证证据保留。主仓库原有未跟踪`docs/.DS_Store`未修改或纳入提交。
