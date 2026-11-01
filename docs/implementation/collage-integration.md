# C「数据拼贴」集成验证（#17）

2026-10-30，基线 `4471729`（全部 C 切片），产品修复与图册来源提交 `d9d7d96`。当前记录覆盖代码与自动化；用户视觉评审、真机、真实站点/Grafana、真实底图/CRS/网络与设备性能仍待验，不关闭相关工单。本轮未重建双端产物，不将历史构建当作当前 C 构建证据。

## 修复与验证

- C06：充电基础及扩展曲线的采样数、完整 null/峰值/续航说明放入「曲线数据说明」；行程地图采样点/段数、完整采样口径和曲线采样范围折叠。保留无坐标、单点、无采样、有效读数不足、估算等短提示。App＋可控 HTTP 测试先红后绿，旧说明断言改为真实展开后读取。
- #16：真实 VM Timeline 测试先复现地图开场误发 `driveFrameworkReady`。最小修复在 post-frame 核对默认速度实际 CustomPaint 绘图区完整处于视口，滚动重新检查；每 trial 仅一次。最终验证地图首屏0事件，曲线完整可见后1事件。概览沿用 summary/主图同归属及 chartVisible 守卫；未减少默认曲线要求、未新增 API。
- 完整默认 App 回归：252 通过、16 opt-in 跳过（新增 trace 测试前）；最终开启 trace 与 VM service 完整回归：**253 通过、16 渲染入口跳过**。最终受影响 drive_detail/drive_map/真实 Timeline 定向 **26 通过**。未把跳过算作通过。
- `dart format lib test`：93 文件、0 改动；新增 trace 和后续修复均格式化。最终 `flutter analyze --no-pub` 无问题；`git diff --check` 通过。
- 全部11个 C opt-in Flutter 入口各成功执行；详情在最终修复后重跑成功。共 **280 PNG**：概览24、行程20、行程详情48、充电36、充电详情24、统计12、节奏16、补能专题24、条件专题24、续航20、停放32。正常/空或空序列/缺失 × 浅深色 × 100%/200%；部分入口含结果、图或下钻的额外帧。受控 HTTP、系统 CJK 字体、360×800/pixelRatio2，所有入口保存前检查 Flutter 异常。
- 本轮直接复查行程正常浅色地图、深色200%曲线及充电正常浅色首屏：采样统计已折叠，主要图形与读数可读。其他组合由实际渲染无异常及各切片原有测试支撑；不冒充用户审美通过。旧 A 图册仅历史，不计入本轮280张。

## C01–C10 对照

| 项目 | 自动化/实现证据 | 剩余验收 |
| --- | --- | --- |
| C01 主角 | 全切片正式页面、11入口与280图 | 用户视觉评审 |
| C02 首屏 | 360×800正式渲染、App几何断言 | 用户视觉评审 |
| C03 导航 | 完整统计专题App测试通过；章节独立路由、期间/车辆/时区隔离 | 真实设备交互 |
| C04 主图 | 既有图表选点/原值/null/参照App回归通过 | 真实站点对账 |
| C05 详情 | 地图优先、SOC弧及默认功率图；失败保留结果的App回归通过 | 真实底图与设备 |
| C06 口径 | 本轮红绿、折叠后展开读取通过 | 用户视觉评审 |
| C07 状态 | 完整App空/缺失/单点/失败/0/缓存回归及状态渲染 | 真实站点复核 |
| C08 可访问性 | 浅深100/200%正式渲染无Flutter异常、图表语义回归 | 设备读屏与用户字体 |
| C09 边界 | 全App+HTTP回归；没有新增请求或业务计算 | 真实站点对账 |
| C10 证据 | 全新C图册与来源SHA256已归档 | **用户视觉评审待验** |

## 复现与指纹

使用现有 SDK：`MILEAF_FLUTTER_SDK=/Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile/.tooling/flutter`，工作树内 `tool/flutterw`；依赖、缓存位于本项目，未修改全局配置或只读后端仓库。

- 完整回归：`tool/flutterw test --no-pub --enable-vmservice --dart-define=MILEAF_PERFORMANCE_TRACE=true`。
- 独立端点：上式追加 `test/collage_trace_test.dart`。VM service 必须开启；未开启时不能声称实际 Timeline 验证通过。
- C 图册使用各 `collage*_render_test.dart`，传 `MILEAF_RENDER_OUTPUT=docs/implementation/collage-renders/<章节目录>` 与 `MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf`；目录与命令见各 collage 切片实施记录。

[provenance.json](collage-renders/provenance.json) 记录来源提交、全部 lib/test 源文件、清单/锁文件、字体和280图片的 SHA256；原工作区未提交 Spec/ADR/prototype/style 只读计算指纹，未复制或覆盖用户设计文件。集成基线在交付前复核仍为4471729。双轴 code-review 由 merger 在合并后统一执行，本记录不提前宣称审查通过。

## 本轮双轴审查与修复

- Standards：0硬性违规，1项P3重复PNG保存。小型helper统一异常检查、pixelRatio2保存及dispose，11入口场景和数据保留；range/parking实际渲染2项通过，详情实际渲染2项通过。
- Spec：1项P2缺充电地点图。现已复用冻结lat/lon与CandidateMap、现有配置，不改契约/API/供应商，纠正文档。App红绿及3条地图路径通过。详情36张图片更新来源，其余切片图片保留原来源。
- 最终VMservice真实Timeline完整回归256通过、17渲染测试跳过；格式化、静态分析、diff检查通过。修复后交既有reviewer仅复核原发现，此处不提前声称复核通过。
- 用户视觉、真机、真实站点/Grafana、真实地图/CRS/网络及设备性能仍待验；N=0、native build=0。不推送、部署或关闭票。

## 最终收口（2026-10-31）

集成分支 `codex/c-visual-refresh`，产品与审查修复合入点 `636e957`；基线为包含已验证 v1 的 `main` 提交 `7fcc120`。本轮未将原工作区未提交的 Spec、ADR、原型和 AGENTS.md 混入代码提交。

原审查者限定复核结果：Standards 原 P3 已解决（11 入口共用 PNG helper），Spec 原 P2 已解决（冻结坐标接入既有地图配置，缺坐标/瓦片失败仍保留 SOC 和结果）；无剩余已确认代码审查发现。限定复核为只读检查，采用修复 worker 的实际测试结果，不宣称审查者独立重跑成功。

最终证据为完整 trace/VM service 回归 **256 通过、17 个可选入口跳过**，格式、静态分析与 diff 检查通过。保留 **292 张 C PNG**；收口再次校验当前源码 95 个 SHA256 和全部 292 张图片 SHA256，均无不匹配。初轮全部 11 个 C 入口通过，修复后重跑受影响的充电详情与 range/parking 入口；其他图片保留原始来源。

主要实现提交：#8 `a18f1c4`；#9 `ff7f8fd`；#12 `1ee8d1e`；#14 `73dc3fe`；#10 `8c0b9ea`；#13 `e8b97aa`；#18 `583dd7d`；#20 `d559af1`；#15 `5db6c00` / `bfcae8e`；#19 `170f7b2`；#21 `6559a07`；QA `d9d7d96`；审查修复 `8de8ace`。证据与性能协议提交为 `a7464ef`、`6964f20`、`a1e7f60`。

代码和自动化实施完成；C10 用户视觉评审仍待验。#11 地图供应商/CRS/许可/双端网络、#16 设备性能（N=0）、#17 真实设备/站点/Grafana及最终外部验收仍未通过，#8–#21 保持开放。不推送、不建 PR、不部署、不跑真机；本轮未重建双端原生产物。

## 2026-11-01 图册与入口现状

- 图册入口（opt-in，只在传 `MILEAF_RENDER_OUTPUT` 时运行）：2026-11-01 前有七个入口因选择器停留在旧版式而失败，现全部修好并通过——
  - `collage_render_test.dart`、`overview_state_render_test.dart`：净值口径入口由「驾驶净电耗 · …」改为本月块「净电耗 · 估算」；`overview_state_render_test.dart` 另需先展开「数据说明与更多」再截状态段。
  - `c_gallery_render_test.dart`：路线脚注改为现行「路线 · 非导航」，只断言 100%；200% 断言脚注不出现。
  - `collage_rhythm_render_test.dart`、`collage_conditions_render_test.dart`、`collage_charging_statistics_render_test.dart`：专题入口不再有 `TextButton`，改用章节卡文字「节奏／能耗／补能」。
  - `charging_expansion_render_test.dart`：先展开「过程数据说明」，再截取「原始功率峰值」等过程指标。
  - `collage-renders/overview/` 已按 2026-11-01 版式重出 24 张；rhythm／conditions／charging-statistics 三个专题图册重跑后与已提交版本逐字节一致（专题页本身未变，仅导航入口变了），故未改动图片。
- 图册指纹：`provenance.json` 仍是 d9d7d96／4471729 整册收口清单；2026-11-01 实测当前树 55/96 源文件、24/292 图片与其 SHA256 不符（图片不符项即本轮重出的 overview 24 张）。其余目录（如 drive-detail 48 张）仍停在各自最后一次重出；整册重新收口需连同各入口一并重跑后再更新该文件。
