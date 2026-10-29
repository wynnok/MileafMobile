# 统计洞察 #14：总览、承载与比较

2026-10-29。本票在既有 `codex/mileaf-v1` 的独立工作树实施，使用已确认的 App＋可控 HTTP 测试边界；真实站点、真机、地图/Grafana验收保留，未关闭工单、推送或改后端。

## 已实施

- 冻结 Server 0.3.0 OpenAPI及源提交/SHA，生成 DrivingStats / StatisticsCapabilities 引用闭包。严格接收所需 query/as_of/覆盖/配对/质量字段；缺失必需字段显示错误，不当作成功。
- 新统计入口承载总览/能耗/补能/长期；旧站点及能力失败回退原驾驶/充电统计，保留独立重试。各feature独立保留其他可用专题；主统计失败时区间与专题仍可操作。
- 总览主里程、副配对估算电耗与已知费用/覆盖；主图可切里程/次数/估算能量/最高速度/配对净电耗，参照系列同单位同尺度，紧凑图后保留双方原值。旧完整净/毛指标进入当前日期选择下的原指标页面。
- 两次驾驶查询的实际query、质量、方法/版本、续航口径一致才展示数值差；零基期相对差为缺失；不可比时参照原值与质量仍可展开。参照可单独重试，不重刷本期成功结果。
- IANA本地日历周/月/年/自定义前移；目标日期不存在、DST空洞/重复时刻不比较。通过枚举地点已知offset验证civil time恰好对应一个instant，包含半小时DST，不用固定UTC毫秒平移或静默归一。
- 当前请求窗口构造时冻结，供独立专题/证据分页使用；同查询TTL内不触发无必要前台刷新，旧统计只由原页面观察foreground，避免父子重复处理导致自定义/时区行为回归。会话/车/时区/请求代次隔离迟到数据。

## 专题接入契约

`StatisticsInsightsPage.topics` 为 `Map<String, StatisticsTopicBuilder>`。builder接收 `StatisticsInsightsContext(workspace,currency,selection,features,compact,window)`；window为捕获的原始请求边界，不在每次getter或翻页时推进now。

- `usage`：首页 `compact=true` 摘要，展开为完整页。
- `energy`：能耗专题。
- `charging`：补能专题；保留原 `initialKind=1` 的深链语义。
- `range` / `parking`：长期页各自 `compact=true` 摘要，分别进入完整页；不把两个内部ListView放进无界Column。
- `legacyBuilder` 接收当前 `StatisticsSelection`，不能捕获初始本月；否则周/自定义下钻会错期。

## 本地验证与边界

本工作树的 `.dart_tool`、build与测试输出独立，未链接回主工作树；SDK及已安装Pub包仅读项目内现有资源，没有全局修改。曾由offline pub get删除的锁文件hash已恢复，不纳入本票。

限定命令（项目根目录，SDK指向现有主项目内SDK）：

- `tool/flutterw test --no-pub test/statistics_test.dart test/charging_statistics_test.dart test/statistics_insights_test.dart`
- `tool/flutterw analyze --no-pub`
- Dart格式及 `git diff --check`。

新功能17条App测试加原统计回归，合计40项通过。包含：能力失败旧阅读、严格DTO错误、正常/质量/方法版本/rated差异/零基期、独立feature、原指标本周上下文、月末及DST三类边界、参照单独重试、驾驶失败保留导航，以及360×800首屏绘图区和360宽200%深色的配对净图操作。首次默认字号plot底部≤736逻辑像素；图后参照明细通过实际可点击滚动验证，不把底栏覆盖的已构建文本当可点击。

红绿记录在工作树忽略目录 `.cache/`：`red.log`、`meta-red.log`、`strict-red.log`/`strict-green.log`、`calendar-red.log`/`calendar-green.log`、`reference-retry-red.log`/`reference-retry-green.log`、`independent-red.log` 与最终 `final-targeted.log`。参照明细初期失败定位为ListView懒构建/底栏遮挡后的测试滚动，改为hitTestable目标并保留数值断言；未屏蔽hit-test警告。所有临时诊断语句已从代码移除。

完整集成回归、正式Flutter浅深色/大字图册、两轴审查及双端隔离构建由#17在最终集成版本统一执行；上述限定测试和几何检查不冒充这些最终证据。
