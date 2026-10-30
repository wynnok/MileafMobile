# A「用车简报」实施与验证

2026-10-27；实施基线为 `4fc2ad63acc6037bde17f3524106a7eaed1ce8cf`，当前集成分支 `codex/mileaf-v1`。用户已明确选择概览扩展 A，仅实施现有 API 支持范围。Spec #1 和概览工单 #8 增量更新，无重复工单、无依赖边修改。正式 [Flutter 渲染图册](overview-briefing-renders/index.html)和[源码/图像校验清单](overview-briefing-renders/manifest.json)记录本次候选。

## 已交付

- 紧凑湖畔车况卡保留电量、明确口径的续航、采样时间及有值的最近充电功率；今日里程、次数与估算消耗为副读数。完整时间仍可在车辆资料展开层查看。
- 本月/近7天的四个主数：里程、估算净电耗、充入电池、已知充电费用。卡片点击或辅助功能激活后，切换对应每日图；驾驶消耗入口切换能量图。默认360×800/100%字号的实际绘图区完整处于视口内；200%字号纵向重排。
- 期间总计与桶值直接来自 driving/charging stats；驾驶消耗、毛电耗说明、充电次数、已知费用均价、AC/DC绝对能量和服务端已知分类占比均可到达。站点币种复用本地偏好，未配置显示币种未知，不换汇、不假定CNY。
- 驾驶/充电统计下钻携带当前所选日期范围及类型，最近记录继续按资源ID进入正式详情。首页没有逐记录预取、分页补算或新业务写接口。
- 净电耗比较在当前驾驶结果后异步读取基期，不阻塞四个主数和主图。比较只描述数值差异，显示样本覆盖限制，并提供成对区间、数值和归期时区依据；不足1Wh/km的非零差异不误显示为“高/低0”。
- 本月与上月同日同一本地时刻对齐；上月无对应日则不比较。近7天使用今天及前6个本地日历日，基期为前一组7日、末日同一时刻。DST不存在/重复的比较截止不猜测。基期0/null或无有效行程不输出比较结论，不输出百分比或原因推断。
- summary、驾驶、补能、比较分别加载/重试，遵守各自缓存和TTL。每个成功统计快照绑定原查询区间；同日刷新失败保留原值、原截止和错误提示。比较保留配对的本期/基期/区间快照。切车/会话/日期范围/时区/换日隔离旧结果和迟到响应，前台跨月下拉失败不会显示上月数据冒充本月。
- 性能framework候选继续要求四个主数所需的summary、驾驶、补能和实际主图可读；基期比较不作为首屏阻塞。它不证明OS呈现、达标或真实性能分位数。

未实现的愿景保持候选：跨记录电量/事件时间线、停放变化、费用/能量覆盖率、长期续航或电池健康、动态排序。不从净毛差推导停车消耗；不补算未知分类能量。未改变后端、依赖版本、原生配置或全局工具。

## 测试与渲染

复用已确认的最高 App/HTTP 边界，固定时钟、IANA时区与合成契约响应。主数/费用切图、日历比较和同范围下钻逐切片red→green；审查新增的四个回归也已先失败再通过。

- 默认完整回归：**165项通过、1项默认跳过**；跳过的是可选渲染测试，已单独执行通过。
- 性能trace开启的相关概览/详情/完整流程回归37项通过；它们验证标记开启后的行为，不是设备性能样本。
- 静态分析无诊断；全部53个Dart文件格式检查无变化；diff whitespace检查通过，依赖和锁文件不变。
- 实际Flutter渲染测试：360×800逻辑像素、2倍导出、浅深色与100%/200%字号，共生成68张，归档13张概览相关代表图。图册含默认首屏、净电耗/补能/费用切图、比较和账本，以及完整资料时间。使用已有本地CJK字体与MaterialIcons，不复制或分发字体。
- 新增验证覆盖费用真实0/null、服务端均价/AC/DC原值、迟到补能/比较、独立局部失败重试、月底和DST拒绝比较、读屏tap语义、跨月前台刷新隔离、独立TTL和比较配对快照恢复。
- 冻结合成响应验证渲染和客户端数据归属，不作为真实站点逐项对账；读屏语义测试不能代替双端真实TalkBack/VoiceOver手势验收。

复现（在项目根目录，使用已有项目工具链）：

```sh
tool/flutterw test --no-pub
tool/flutterw analyze --no-pub lib test
tool/flutterw dart format --output=none --set-exit-if-changed lib test
tool/flutterw test --no-pub --dart-define=MILEAF_RENDER_OUTPUT=build/overview-briefing-renders \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf' \
  test/lake_render_test.dart
```

## 两轴审查

对照基线与增量Spec进行独立只读审查。Standards原2项：指标卡无语义激活动作、前台换日未清旧结果；Spec原3项：语义动作、统计TTL/快照截止、比较失败丢失配对快照。两轴分别记录，重复发现不另算为额外代码问题。

已补四条真实触发回归并逐项修复；两个审查者限定复核均确认原问题可关闭、无剩余明确问题。未发现值得为本次范围增加抽象的代码异味。正式外部验收继续单列，未用测试或原型替代。

## 双端隔离构建

两端均由既有 `tool/flutterw` 入口完整退出0。外层文件沙箱不允许应用进程沙箱时，从已授权外层执行同一入口；没有跳过探针或改保护策略。两端均保留 `LEGACY_STAT=DENIED`、`LEGACY_READ=DENIED`、`HOST_WRITE_OPEN=DENIED`、`PROJECT_READ_WRITE=ALLOWED`。保持已有Zulu21、项目Android SDK和项目级CocoaPods；未改HOME、JAVA_HOME、全局配置或原版SDK。

- Android release：52秒，271 tasks；开发签名验证通过。APK位于 `build/app/outputs/apk/release/app-release.apk`，SHA-256：`008ad8bd2f45d5296fb932309b496c6cf16b786dbc281226a9271a336e03bf52`。
- iOS release无签名：Xcode 38.0秒，Runner.app 19.6MB。Dart承载文件 `build/ios/iphoneos/Runner.app/Frameworks/App.framework/App` SHA-256：`907fce69d378537823095339d8cbc5c65e85817beadfe1fbaca1a9e743c94d76`。
- 日志保留在项目忽略目录 `.cache/overview-expansion/`；原生设备run/install/drive入口仍受保护。构建产物与日志不是性能样本。

## 来源与收尾边界

本次原型primary source保存于本地分支 `codex/overview-briefing-prototype`，提交 `0be1e8cf60d796dd810ed08059c3f01c482ecc69`；入口为该提交的 `docs/prototypes/overview-expansion/README.md`。正式产品提交只保留已确认决定和Flutter实现/证据；B/C及评审切换器不并入产品。原型工作文件保留在本地作为用户已要求的交付，独立归档后不擅自删除。

未推送、部署、上架或关闭Ticket。真机网络/安全存储/系统字体与手势、真实站点/Grafana同口径对账、地图许可/坐标/网络及每平台每指标至少30次性能采样继续待验，本轮性能N=0。只读外部仓库与隔离测试库边界不变。
