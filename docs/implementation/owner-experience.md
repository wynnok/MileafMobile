# 2026-10-29 车主体验整体复核与客户端优化

本轮来自用户 implement 请求。产品结果见[整体复核](../product/owner-experience-review.md)及[后端交接](../product/owner-api-requirements.md)。以`8467391`为本轮起点，继续当前`codex/mileaf-v1`，只本地提交，不推送或改只读外部仓库。

## 已实施的产品行为

- 四Tab职责与TeslaMate/Grafana全主题映射完成复核。每个页面明确首屏、主数字、证据图、背景指标和下钻；六组新增后端能力明确来源、口径、优先级和验收，不把交接建议当作已部署能力。
- 概览主图后新增用车节奏、能耗条件、续航与停放的直接入口。点击保留所选车辆与本月/近7天期间；专题按需加载，概览不预取全历史。旧站点不支持时保留能力说明，不输出伪造聚合。
- 统计保留总览/能耗/补能/长期，增加显式「节奏」入口；不再要求滚到首页底部才能发现分布分析。主图后补充服务端已有的驾驶记录时长与有效趟数、已完成/进行中趟数、估算能量与能量有效里程，明确不同有效集。
- 数字采用等宽数字特性；新指标网格使用实际容器宽度，大字单列。行程期间里程强化为主结果、记录的电耗与能量降为次级，仍保留首屏日图与第一条可点击记录。详情驾驶环境由逐字段长列改为可重排网格。
- 充电账本以已知费用为主结果，并可视化费用记录次数覆盖；入电与记录费用继续明确分母。记录的补入能量强化、网侧能量和时长退为辅助，SOC区间和费用保持可读。覆盖条不是金额覆盖率或花费完整度估计。
- 集成回归发现旧服务直接进入充电专题时没有日期控件；在无0.3驾驶覆盖能力时恢复既有驾驶/充电统计承载，保留概览所选日期与原有统计交互。

## 验证与证据

采用既有App＋可控HTTP边界。新增行为先验证失败，再实现直达和服务端时长展示；保留原有查询、缓存、切车、时区、0/null和辅助功能回归，不改SQL或计算公式。

渲染：正式Flutter，360×800逻辑像素，浅深色、100%/200%字号，固定合成HTTP与本地CJK字体。包括四Tab、行程详情及充电详情、概览专题入口和新增统计指标。[图册](owner-experience-renders/index.html)包含所选代表图与[指纹](owner-experience-renders/provenance.json)。0.3统计渲染使用单桶受控响应来核对层级与原值；多点/缺失图形沿同一批湖畔渲染检查，不把单桶截图冒充规模数据。

复现命令：

```sh
tool/flutterw analyze --no-pub lib test
tool/flutterw dart format --output=none --set-exit-if-changed lib test
tool/flutterw test --no-pub
tool/flutterw test --no-pub test/owner_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=build/owner-renders \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

本轮运行结果与双轴审查在最终验证后补入本节。

## 边界与剩余工作

OE01–OE06均未实现或冻结后端契约，优先级不等于已批准的后端实现/部署。概览仍沿用旧净电耗口径及比较说明，尚未原位接入0.3配对电耗/费用覆盖，不能称整个未来目标已完成。

未访问生产配置/数据库，未改MileafServer/TeslaMate、全局配置、依赖版本或工具链。真实站点/Grafana对账、地图外部验证、真机手势/读屏、用户视觉评审和付费价值验证继续待验，不关闭相关工单。已有未跟踪的`docs/.DS_Store`与`docs/prototypes/overview-expansion/`保留，不纳入本次提交。
