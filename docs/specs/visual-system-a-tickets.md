# 行笺视觉系统 A：实施 Ticket 计划

- 日期：2026-11-01
- 状态：proposed（待用户确认）
- 依据：[Spec v1](visual-system-a.md)、[ADR 0003](../adr/0003-visual-direction-a.md)
- 本地 ID：`VA01–VA14`。确认后按 `docs/agents/issue-tracker.md` 映射到 GitHub；**本轮不直接创建或关闭 issue**。
- 实施边界：不新增 API、不改数据口径、不改 `MileafServer/`/`teslamate/`、不做车辆控制/多站点；真机、真实站点、地图许可/坐标、性能、双端隔离构建仍是外部 gate。

## 全局完成定义（DoD）

每张票都必须满足：

- `tool/flutterw analyze --no-pub` 通过。
- `tool/flutterw test --no-pub` 通过；新增/更新的 widget 测试在同一 seam（App + 可控 HTTP）内。
- 页面文件不出现裸 `Color(0x...)`、裸 `fontSize`、裸 `EdgeInsets`、裸 `BorderRadius` 作为视觉决策；只消费 `lib/src/design/` 的 token/组件。
- 360×800、浅/深、100/200% 无横向溢出；主数、单位、操作可见。
- 空/加载/错误/缺失/过期/进行中有实际渲染，不只是文案占位。
- 不把浏览器原型图或合成数据当作真机/真实站点验收。

## 依赖图

```text
VA01 ──┬── VA02 ──┬── VA04 ──┬── VA05 ──┐
       │          │          ├── VA06 ──┼── VA08
       └── VA03 ──┘          ├── VA07 ──┴── VA10
                             └── VA09
VA02 + VA03 ── VA11
VA04–VA11 ── VA12 ── VA13 ── VA14
```

可并行：VA05/VA06/VA07；VA08 依赖 VA04+VA05；VA09 依赖 VA06；VA10 依赖 VA07；VA11 可与页面并行。

---

## VA01 · 设计 token、主题与品牌基座

**目标**：让颜色、字号、间距、圆角、动效只在一个地方定义；深色默认、浅色等价；品牌 M 径可用。

**改动**
- 新增 `lib/src/design/tokens.dart`、`semantic.dart`、`theme.dart`、`typography.dart`、`motion.dart`、`brand_mark.dart`、`icons.dart`。
- `pubspec.yaml` 增加 Inter 400/500/600 与 OFL 许可；`assets/fonts/` 落地。
- `lib/main.dart` 切换新主题；默认 `ThemeMode.dark`。
- `lib/src/visual_theme.dart` 标记 deprecated，不再被引用。

**验收**
- 语义色与 Spec §2 一致；`text/muted/faint/accent/reference/warning/error` 对比度测试通过。
- Inter 三字重可加载；中文 fallback 在 iOS/Android 渲染无豆腐块；所有数字 `tabularFigures`。
- `BrandMark` 在 18/24/32/58px 单色可辨，深/浅底一致；无渐变/阴影/第二色。
- `MileafIcon` 覆盖 Spec §6.1 的 15 个关键图标，24 网格/1.5 描边。
- `test/design_tokens_test.dart` 通过；无页面引用 `lakeTheme`。

**不做**：不改页面布局；不生成启动图/商店素材。

---

## VA02 · Shell、导航与外观设置

**目标**：把全局壳从 C 的卡片/双刷新改成 A 的“品牌/车辆/设置 + 单一刷新 + 64px 导航”。

**改动**
- `lib/src/workspace_page.dart`：AppBar 只留品牌 Mark + 行笺 + 车辆选择 + 设置；移除 AppBar 刷新。
- 车辆刷新移入车辆选择 sheet；页面内保留唯一刷新（区间行右侧）+ 下拉刷新。
- `NavigationBar` 改为 64px token 化：20 图标、9 label、active accent + 2px 顶部标记；详情页隐藏。
- 新增外观设置（深色/浅色/跟随系统，默认深色），持久化；系统栏颜色跟随主题。
- `SafeArea`/底部 84px 内容留白；通知条 token 化。

**验收**
- App 冷启动默认深色；切换浅色/系统后重启仍保持。
- 同一屏不再出现两个刷新图标；车辆刷新在车辆 sheet 内可点。
- 四 Tab 切换、详情返回、底部安全区正确；200% 标签不截断。
- `workspace_page_test`/导航测试更新并通过。

**不做**：不添加新 Tab；不做平板专用导航。

---

## VA03 · 共享组件与状态画廊

**目标**：把 Spec §7/§8 的组件和状态做成可复用件，后续页面只组装。

**改动**
- 新增 `lib/src/design/components/`：`MileafHero`、`SectionHeader`、`MetricBlock`、`DataRow`、`StatusChip`、`MileafButton`、`MileafIconButton`、`MileafNavBar`、`MileafSheet`、`StateView`、`TimeSeriesChart`、`StemChart`、`MicroSpark`、`BatteryArc`、`MapFrame`。
- 复用/重构 `lib/src/data_chart.dart` 的绘制逻辑；不引入图表依赖。
- 组件状态：default/pressed/selected/disabled/loading/error/focus；空/加载/错误/过期。
- 新增 `test/design_components_test.dart` 和组件状态 render（可只在 debug 入口）。

**验收**
- 每个组件有 Spec 状态表中的全部状态；按压/选中/禁用/加载可见且不抖动。
- 图表：null 断线、零基线、stem 离散、tooltip、点按 44、语义摘要；浅/深一致。
- 200% 下组件不溢出；文本可长高；不裁切主数/单位。
- 组件不直接引用页面数据模型；输入为值/回调。

**不做**：不一次性替换所有页面；先提供组件与画廊。

---

## VA04 · 概览页重建（首个视觉切片）

**目标**：把 C 的薄荷/沙色 tile 概览改成 A 的“深色 hero + 本月 + 主图 + 辅助读数 + 最近 + 继续”。

**改动**
- `lib/src/overview_page.dart`：重写 `summary()`、`_monthBento()`、`_dailyChartCard()`、`_insightStrip()`、`records()`、`_chapterGrid()` 的视觉层；保留加载/缓存/对照/能力/分页逻辑。
- 删除 `_monthBento()` 的 `stretch` 和空 tile；净电耗/费用合并为主图后的辅助读数行。
- 时间人性化（刚刚/N 分钟前/N 小时前/日期）；费用未知拆分；币种不默认 CNY。
- AppBar 刷新移除后，页内只保留区间行刷新；车辆刷新由 VA02 接管。
- 数据说明与更多保留；技术口径不进入首屏正文。

**验收**
- 360×800 首屏：hero 320 km/68%/今日三项 → 本月 1,198.6 + 同期 → 主图起点；最近/继续在首屏下半部。
- normal/empty/missing 渲染：缺失 `—`；空态不画全零；无“N 万分钟前”；无空块；费用不括号换行。
- 200%：hero 单列、今日 2×2、最近行两行；主数/单位/操作可见。
- `overview_*_test` 更新通过；新增时间/币种/空块回归断言。

**不做**：不改 API、summary 字段、对照口径；不新增记录缩略图（地图/路线缩略图另票）。

---

## VA05 · 行程列表

**目标**：A 的“期间主数 + 节奏条带 + 最近的路”，去掉卡片与日期分组标题。

**改动**
- `lib/src/drives_page.dart`：期间 hero（1,280.6 km / 52 趟 / 197.47 kWh / 154 Wh/km）、26 条节奏、最近的路首条 featured、其余行、加载更多、日期筛选。
- 删除卡片、分组标题、里程/电耗切换的旧视觉；保留分页/日期/失败重试。

**验收**
- 首屏：期间主数 + 节奏 + 首条记录；记录以起终点为主标题、距离为主数。
- 空/加载/错误/缺失；200% 不溢出；日期筛选可用。
- `drives_*_test` 更新通过。

**不做**：不加地图缩略图；不做跨页聚合。

---

## VA06 · 充电列表

**目标**：A 的“费用 hero + 覆盖 + 三读数 + stem + 构成 + 地点”。

**改动**
- `lib/src/charging_page.dart`：费用 hero（¥186.4/8-9 覆盖/0.87）、三读数、每日补能 stem、AC/DC/未知构成、地点账目、最近一次。
- 费用未知：有币种 `¥72`、无币种 `72` + `币种未记录`；不默认 CNY、不计入均价。
- 保留日期筛选、分页、失败重试。

**验收**
- 首屏：费用 + 覆盖 + stem 图；地点不排名、不写“最划算”。
- 空/加载/错误/缺失；200% 三读数 2×2、构成标签换行。
- `charging_*_test` 更新通过。

**不做**：不做地图空间聚合；不做跨会话性能比较。

---

## VA07 · 统计总览

**目标**：结论 + 深色主图带 + 2×2 章节，替代五个等权 tab 的首屏占位。

**改动**
- `lib/src/statistics_page.dart`：结论、主图（本期/参照）、洞察、2×2 章节（节奏/能耗/补能/长期）、全部指标。
- 长期数据：已加载 range observations 时显示最新值/P50；未加载显示 `—` + “进专题”，不新增请求、不硬编码 316。
- 章节不再使用 `CollageTile`；用 1px 细线分栏。

**验收**
- 首屏：结论 + 主图 + 首个章节；无五个等权 tab。
- 章节 spark：能耗/补能微折线；节奏活动点；长期无数据不画 spark。
- 空/缺失/失败；200% 单列；`statistics_*_test` 更新通过。

**不做**：不预取 range observations；不改 totals/比率口径。

---

## VA08 · 行程详情

**目标**：地图优先，结果随后，过程曲线与电量区间不遮挡。

**改动**
- `lib/src/drive_detail_page.dart`：地图 hero（失败用路线速写 + “地图暂不可用”）、说明带、三结果、速度曲线、电量区间 68–76 段、技术 rows、脚注。
- 速度图不标 0 当前点；电量区间不画成 0–76 进度。
- 保留参照加载/失败/重试、地图同意/失败/重试、返回列表。

**验收**
- 有/无底图两种渲染：说明带不遮挡结果；文案不丢。
- 三结果、速度、电量、技术 rows 可读；200% 地图 240、结果 2×2。
- `drive_detail_*_test` 更新通过。

**不做**：不改地图供应商/坐标；不做导航。

---

## VA09 · 充电详情

**目标**：电池弧开场，随后结果、功率曲线、技术信息。

**改动**
- `lib/src/charging_detail.dart`：SOC 弧（18→82）、充入/费用/时长三结果、功率曲线、能量/温度/相数、口径。
- 地图失败/无坐标保留结果与文字；曲线点按读数保留。
- 200% 弧 72、结果 2×2。

**验收**
- 首屏：弧 + 三结果；功率曲线在结果后；技术信息最后。
- 空/失败/缺失；`charging_detail_*_test` 更新通过。

**不做**：不做地图空间聚合；不改费用口径。

---

## VA10 · 五个专题

**目标**：节奏/能耗/补能/长期/停放统一为“结论 + 主数 + 主图 + 证据 + 数据说明”。

**改动**
- `lib/src/statistics_*_page.dart` 五个专题：统一模板、token、图表语法；去掉同权卡片堆叠。
- 每页一个主图；证据 3–5 条；口径进数据说明。

**验收**
- 五页各自回答一个问题；200% 单列；空/缺失/失败一致。
- `statistics_*_test` 更新通过。

**不做**：不新增指标/后端能力；不改统计口径。

---

## VA11 · 连接、登录、设置

**目标**：接入流程与设置页也使用 A 的 token，而不是旧表单风格。

**改动**
- `connection_page.dart`、`session_pages.dart`、`setup_page.dart`、`connection_management.dart`、`currency.dart` 相关 UI。
- 表单：radius 12、label 10、错误 12 + error 色；主按钮一屏一个；加载/失败/禁用状态。
- 设置：外观（深色/浅色/跟随系统）、币种、地图同意、服务信息；DataRow 化。
- 品牌 Mark + 字标出现在连接/登录页，不使用 hero 光晕堆叠。

**验收**
- 连接 → 登录 → 切车 → 设置全路径可用；错误/加载/禁用可见。
- 深色默认；切换外观生效；200% 表单不溢出。
- `connection_*`/`session_*` 测试更新通过。

**不做**：不改认证协议、不新增凭据能力。

---

## VA12 · 渲染矩阵与视觉 QA

**目标**：用实际 Flutter 渲染证明 A 在浅/深、100/200%、normal/empty/missing 下成立；替换 C 的 68 张图册。

**改动**
- 更新 `test/*_render_test.dart` 与 `test/c_gallery_render_test.dart`（可重命名为 `test/a_gallery_render_test.dart`）。
- 矩阵：四主 Tab + 两类详情 + 五专题 × 浅/深 × 100/200% × normal/empty/missing；每页至少首屏。
- 生成 `docs/implementation/a-renders/` 与索引；记录来源指纹。

**验收**
- 所有图：1 台手机、正文非空、无横向溢出、主数/单位可见；200% 单列。
- 空态不画全零；缺失 `—`；失败保留数据/重试。
- 图册可打开；旧 C 图册标记历史，不再作为 A 证据。

**不做**：不把渲染图当真实设备/地图/性能验收。

---

## VA13 · 可达性与对比度审计

**目标**：把 Spec §12 变成可执行检查，而不是口头承诺。

**改动**
- `test/design_tokens_test.dart`：语义色对比度、字号/间距/圆角 token 完整性。
- 组件语义：图表摘要、按钮/行 label、状态 announcement。
- 触控 44、reduce motion、颜色非唯一编码检查。
- 200% 手工/自动化检查清单。

**验收**
- 对比度表全部通过；触控目标 ≥44；reduce motion 关闭位移/绘制。
- 屏幕阅读器顺序正确；图表有摘要；状态不只靠颜色。
- 审计记录归档到 `docs/implementation/a-accessibility.md`。

**不做**：不替代真机读屏验收；外部 gate 保持。

---

## VA14 · 回归、性能与双轴审查

**目标**：确认视觉重构没有破坏数据/分页/错误/性能边界，并完成代码审查。

**改动**
- 全量 `tool/flutterw test --no-pub`、`analyze --no-pub`。
- 关键路径性能 sanity：冷启动/概览/详情（只记录，不宣称达标）。
- 双轴 code review（Standards/Spec）；修复阻断项。
- 文档：更新 README、AGENTS 现状、Spec/ADR 链接；旧 C 文档标记历史。
- 不新增请求；不改 API/后端。

**验收**
- 全量测试通过；无 P0/P1 回归；无裸 token 违规。
- 代码审查报告归档；Spec 验收清单逐项勾选。
- 真机/真实站点/地图/性能/双端构建仍未关闭，明确列出。

**不做**：不推送、不部署、不关闭外部待验票。

---

## 建议实施顺序

1. **VA01 → VA02 → VA03**（系统基座，必须先做）。
2. **VA04**（概览，作为视觉样张；确认后再批量推进）。
3. **VA05 / VA06 / VA07**（可并行）。
4. **VA08 / VA09 / VA10 / VA11**（详情、专题、接入）。
5. **VA12 → VA13 → VA14**（矩阵、可达性、回归/审查）。

## 不进入本轮

- 多车对比、多站点、车辆控制、Tesla 凭据、秒级刷新。
- 电池健康/吸血鬼耗电/固件历史等新指标。
- 地图供应商切换、导航、GPS、离线地图。
- 后端/数据库/外部仓库修改。
- 启动图、商店素材、完整 VI。

## 待确认

1. 是否按 VA01–VA14 的顺序实施，还是先只做 VA01–VA04 的“基座 + 概览样张”？
2. Ticket 是否需要在 GitHub 创建/映射，还是本地文档先行？
3. VA12 的图册矩阵是否接受“全页面 × 浅/深 × 100/200 × normal/empty/missing”的成本；如要压缩，可先做四主 Tab + 两类详情，专题后补。
