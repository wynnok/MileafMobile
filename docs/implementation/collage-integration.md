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
