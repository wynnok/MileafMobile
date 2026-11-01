# C「数据拼贴」：共享视觉与概览（#8）

2026-10-30。本地代码与合成 HTTP 验证；不代表真机、真实站点、底图或性能外部验收，不关闭工单。

本切片基于 7fcc120（包含 #5 会话恢复），按 GitHub #8 的 C 增量实施。primary source 为原工作区 `/Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile/docs/specs/mobile-v1.md` 2026-10-30 章节、`docs/adr/0001-visual-direction-c.md`、`docs/prototypes/visual-refresh/prototype.js` 的 cOverview 与 `renders/compare-light.png`。这些未提交设计文件没有复制进本切片。

概览顺序：深色车况（SOC、续航、状态、今日与非实时）→ 大里程 tile + 净电耗/费用辅助 tile → 满幅真实日图 → 补能、参照与最近记录 → 四章节。驾驶消耗/补能长说明收进展开层；车辆、采样时间、归期时区仍可从“车辆与数据时间”核查。最近充电条仅表示实际结束 SOC，不伪造起点；summary 未提供路线坐标，最近行程保留真实时间/距离/下钻，不画合成路线。

里程差仅在扩展字段可解析、两期及查询通过现有 canCompare 质量/日历校验且参照无错误时显示服务端 totals 的绝对差；旧站点或缺字段显示参照不足，不猜百分比。API、缓存、时区、车辆/会话隔离、请求数与净/毛/费用口径不改。

## 后续复用

- `lib/src/collage.dart`：`CollageTile(child:, surface:, padding:)`，表面枚举 `paper/hero/mint/sand`；hero 带浅字与湖绿图形主题。默认圆角20、内边距12、下间距8。
- `CollageBento(lead:, evidence:)`：默认6:5主辅两列，字号达到150%强制单列（覆盖200%）。调用方决定内容与高度；不缓存/加载业务数据。
- `lib/src/visual_theme.dart`：lakeTheme 使用 C 的暖雾底、纸面、主墨、湖绿与深色对应 token。既有 TimeChart/DataCard 继续共享该主题与比较系列琥珀色/虚线，不另造绘图实现。
- 概览主数44，辅助数沿既有 titleLarge，数字使用 tabularFigures；主数/单位可换行。所有文本跟随系统字号，不引入字体或依赖。

## 验证

TDD：首个布局测试先失败（里程tile160宽，预期>175），实施后通过；同期里程可见结果先失败（缺少0.0km同期差），严格质量校验接入后通过。缺字段旧站点回归验证不会解析不兼容扩展。

- #8目标：overview_test、overview_visualization_test、overview_briefing_test、owner_experience_test、overview_verification_test，共34项通过。
- `flutter analyze --no-pub`：无问题；修改文件格式检查与 git diff --check 通过。
- `test/collage_render_test.dart`：独立 opt-in Flutter渲染1项通过，24张PNG，正常/空/缺失 × 浅/深 ×100/200，每组合首屏及净电耗图。360×800、pixelRatio2；每次保存检查无Flutter异常。空态不画全零趋势，真实0/缺失语义沿用已有图表。
- 已目视检查正常浅色首屏与缺失深色200%：深色车况是第一视觉、里程比辅助数突出；默认首屏真实绘图区完整可见；200%单列、允许纵向滚动、未见横向溢出。新首屏测试同时检查实际图表上下边界、关键车况命中与主数宽度。
- 全量回归曾执行，245项通过、6跳过、2旧用例失败（旧定位首屏采样时间/时区）；两处改为展开资料后定位，已包含随后34项全绿。最终集成全量及构建由#17复验。

重现：设置 `MILEAF_FLUTTER_SDK` 指向项目SDK，执行 `tool/flutterw test --no-pub test/collage_render_test.dart --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/collage-renders/overview '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'`。

渲染目录：`docs/implementation/collage-renders/overview/`。未修改外部链接仓库、配置、依赖/锁文件；未推送、部署、设备操作或修改工单。

## 2026-10-31 显示修正（用户截图）

截图暴露两处纯显示缺陷；不改数据、口径、版式顺序与交互。

1. **电量环右侧被切平**：`CircularProgressIndicator` 默认居中描边，弧线实际外溢半个笔画（3dp）；hero 的 `Stack` 因车轮廓负偏移产生视觉溢出，默认 `Clip.hardEdge` 于是按内容区裁切，环又贴住内容区右缘，右侧被削成直线。改为 `strokeAlignInside`（绘制不越出布局盒），`size` 语义随之变为外径，调用处补回一个 `strokeWidth` 保持原环径；hero 内再加 2dp 右留白，抗锯齿边缘也落在裁切边界内。
2. **最近充电卡文字不可读**：`CollageTile` 只在自己子树内切换主题，该卡先用外层（浅色）上下文取 `titleSmall/labelSmall/headlineSmall` 再传入，深底上成为近黑字（实测对比度 1.09）。改为在 tile 内用 `Builder` 取主题再构建标题与正文（正文签名改为 `WidgetBuilder`）。

回归：`test/collage_overview_test.dart` 6 项——环描边内收、右侧至少落在内容区内 1dp、四边不出内容区（390dp×100%/130%/200%、320dp×130% 四档，含 ≥150% 的纵向堆叠分支），以及深色 tile 内每处文字与卡底对比度 ≥4.5、卡底确为深色（浅/深两种系统外观）。修正前这些断言均失败（描边为 null、文字对比度 1.09），修正后通过；全量 `tool/flutterw test --no-pub` 272 项通过、19 项 opt-in 渲染跳过；`flutter analyze --no-pub` 无问题。渲染复核：320dp×130%（热门最紧处主数不换行、环完整）、390dp×100/130/200%（浅/深），环均为完整圆弧，深色卡标题/正文/时间可读。

已知未改：环轨道读 `colorScheme.surface`，是浅色 token 漏到深色 tile 上（轨道比进度亮，但两张截图未提出）。真正的修法是在 `collage.dart` 的 hero 主题里统一覆盖这些容器色，属独立一轮。C10 的 `c-fidelity-scratch/latest-overview-*.png` 对这两处不再是最新证据。

## 2026-11-01 两列等高与最近记录改版（用户截图）

用户指出两处两列区块左右不一致：本月块（主 tile 与「净电耗／已知充电费用」列）底边不齐、主 tile 下方留空；最近记录两张卡高度与内容节奏不一致，充电卡还把「结束电量」拆行、电量缺失时只剩半句。以下只调版面与文案结构，不改数据、口径、顺序与交互。

- `CollageBento` 新增 `stretch`（默认 false，统计与充电调用点不变）：宽屏用 `IntrinsicHeight` + `CrossAxisAlignment.stretch` 让主 tile 与证据列等高，证据列 `spaceBetween` 顶底对齐；证据本身保持自然高度，避免 flex 参与 intrinsic 计算被压缩。
- 概览本月块启用 `stretch`：主 tile 的里程 Sparkline 改 `Expanded` 吸收余量（≥150% 单列时仍固定 26），回到 C 原型「主 tile 下半段大面积折线」的比例；净电耗 tile 补右上角图标，与费用 tile 的标签行同构。
- 最近记录改为共享 tile 结构（标题行／主数／单行口径／页脚）：宽屏 `IntrinsicHeight` 两等列，页脚（时间戳）底对齐；≥150% 单列。充电卡口径改为「充入 46.80 kWh」，不再输出悬空的「结束电量」；进度条移入页脚上方并显式取 hero 主题的 `primary`/`onSurface`，避免轨道比进度更亮。

回归：新增三项先失败（本月块底边差 60dp、最近记录底边差 4dp）后通过——两列矩形顶底对齐、页脚贴卡底（距卡底 20dp = 内容 12 + 卡片下距 8）、口径文案与 ≥150% 单列分支。全量 `tool/flutterw test --no-pub` 274 通过、19 项 opt-in 渲染跳过；`flutter analyze --no-pub` 无问题。渲染复核用临时脚手架在 390×844 浅/深 ×100/200 完成（位图未入库、脚手架已删除）：本月块两列顶底对齐，最近记录两卡等高、页脚同一基线，单列分支无溢出。图册入口 `test/collage_render_test.dart` 的选择器仍是旧口径文案（`驾驶净电耗 · 配对估算` 等），本次未修，因此 `collage-renders/overview/` 未刷新——属既有失效，另行修复。
