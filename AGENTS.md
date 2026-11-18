# Mileaf Mobile（行笺移动端）

- 默认使用中文沟通。产品中文名「行笺」，英文名「Mileaf」。
- Android / iOS 客户端使用 Flutter；通过 Mileaf Server 展示 TeslaMate 的结果数据。
- 当前阶段：实施已发布的 Spec #1 与子任务 #2–#17。以 GitHub 最新 Spec、Ticket 和原生阻塞关系为准，按 `implement-spec` 在集成分支开发。
- 2026-10-23 用户已批准：先完成代码和自动化，真机/真实站点/地图外部验收保持待验、相关 Ticket 不关闭；允许验证构建进程沙箱。代码切片可按已合入的代码依赖推进，GitHub 原生验收阻塞边保留。
- 双端隔离构建已验证：使用 `tool/flutterw` 的进程沙箱及项目级 CocoaPods，不绕过探针、不改 HOME、全局配置或原版 SDK；设备 run/install/drive 入口仍受保护，构建不等于真机验收。
- 2026-10-23 用户已明确授权本次 implement-spec 在各 codex 分支暂存、创建本地提交并合入 `codex/mileaf-v1`；不包含推送或改写共享历史。
- 2026-10-25 测试/seed/性能准备只使用新建的本地隔离测试库；禁止读取或继承现有生产连接配置，禁止向生产库装载数据、执行 DDL 或清理。此边界不影响 App 用户正常通过只读 API 展示业务数据。
- 已确认首版范围：单站点、多车辆；车辆切换、概览、行程列表与详情、充电列表与详情、统计，以及连接与登录。
- 2026-10-25 用户重申核心展示目标：以移动端体验为中心，美观、直观地尽可能展示 TeslaMate 数据；参考 Grafana 指标，不要求逐项相同或迁移桌面布局。图表/地图/关键数字是概览、详情和统计的主要内容，不以字段清单或逐桶文字替代。实施前先交付代表页面可视方案，按 `docs/product/visualization-requirements.md` V01–V08、A01–A06 及修订 Spec T17–T18 验收；当前数据闭环、测试及构建通过不代表新展示要求通过。
- 不实现车辆控制、Tesla 凭据接入、多车对比或秒级刷新。业务数据默认只读；唯一业务写入例外为显式启用后的缺失充电费用补录（ADR 0007），站点认证另属接入流程。
- 2026-10-26 用户已选择 A「湖畔」并要求完成实施；当前正式 Flutter 页面、图表及验证见 `docs/implementation/lake-visualization.md`，视觉决定见 `docs/product/lake-visual-design.md`。A 的版面/视觉验收已于 2026-10-30 由 C「数据拼贴」取代，湖畔配色保留。不要再次按“尚待选择原型”停止；外部待验和未推送边界继续有效。
- 2026-10-27 用户已确认概览扩展 A「用车简报」，仅实施现有 API 支持范围；增量同步 Spec #1/#8，不重复建票。方案见 `docs/product/overview-expansion-proposal.md`，正式实施和验证见 `docs/implementation/overview-briefing.md`；电量历史/停放变化/费用覆盖/长期续航及动态排序仍为后续候选，不修改后端。授权按 implement 完成测试、审查和当前分支本地提交，不推送或提前关闭外部待验。
- 2026-10-27 用户已确认行程扩展 A「出行回顾」及方案顺序1，并批准紧凑节奏区/真实滚动调整；正式实现与本地测试、图册、双端隔离构建及审查见 `docs/implementation/drives-expansion.md`。Spec #1/#9/#10/#11 已增量同步；顺序2–4及新后端能力保持候选，不重复建票、不推送或提前关闭外部待验。授权当前 `codex/mileaf-v1` 本地提交，不再停在等待选择原型。
- 2026-10-28 用户已确认充电扩展 A「补能账本」，实施已完成的 CH01–CH05；正式实现和验证见 `docs/implementation/charging-briefing.md`。Spec #1/#12/#13/#15 增量同步；CH06、地图空间聚合和跨会话性能比较后置，不重复建票、不推送或提前关闭外部待验。授权当前 `codex/mileaf-v1` 本地提交。
- `MileafServer/` 与 `teslamate/` 是外部仓库的符号链接，只读参考，不在本任务中修改。
- 2026-10-29 用户授权按 implement-spec 实施统计扩展 A「用车洞察」，范围为 Spec #1 统计增量、#14/#15/#18–#21及#17集成复验。以冻结0.3.0实际契约和能力声明接入，按代码合入依赖推进；复用 codex/mileaf-v1，允许本地提交/合入，不推送/部署、不提前关闭外部待验票。测试边界为已确认App＋可控HTTP，另做正式Flutter渲染、隔离双端构建与双轴审查。
- 2026-10-30 用户已确认 C「数据拼贴」作为主视觉方向：沿用湖畔配色，只替换版面/层级；统计以结论+主图+2×2章节卡→专题页替代五个等权 tab；详情以地图/电池弧/功率曲线为首要视觉；技术口径进数据说明层。Spec #1 已追加增量，见 `docs/specs/mobile-v1.md` 的 2026-10-30 章节；决定见 `docs/adr/0001-visual-direction-c.md`。旧 A 渲染仅历史证据；tickets 验收已映射（0 新票），不重复建票。
- 2026-10-31 用户作出 **C10 视觉验收通过** 结论，并裁定行程详情顺序以 C 渲染为准（Spec #1 第363条措辞已按渲染更正）。证据见 `docs/implementation/collage-audit/c-fidelity-report.md`；真机、真实站点/地图、性能与双端隔离构建仍为独立外部 gate，不因 C10 通过而关闭。
- 依赖、缓存与构建产物保持项目内；不修改全局工具或系统设置。不擅自提交、推送、部署或删除既有文件。
- 修改前阅读相关文件；保持最小改动，验证后报告。区分代码事实、已确认决定和未确认建议。

## Agent skills

### Issue tracker

GitHub Issues in `wynnok/MileafMobile`, via the `gh` CLI.
See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage labels.
See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `GLOSSARY.md` plus `docs/adr/`.
See `docs/agents/domain.md`.

- 2026-10-31 地图双端接入：共享 Dart `MapPanel`；Android 高德 11.3.100 `TextureMapView`；iOS 使用高德 11.2.100 `MAMapView`（`AMap3DMap-NO-IDFA`，key 绑定 Bundle ID `app.mileaf.mileaf`，经非公开 xcconfig 注入）；MapKit 过渡已移除；WGS84→GCJ-02 只在地图边界；真实底图/真机/CRS/大陆网络仍待验，#4/#11 保持 OPEN。实现与证据见 `docs/implementation/amap-map.md`，决定见 `docs/adr/0002-map-provider.md`。

- 2026-11-01 用户确认 A「夜航」为当前视觉方向，并按 VA01–VA14 顺序实施；正式 Flutter 页面、共享组件、实际渲染与可达性证据见 `docs/implementation/a-renders/` 与 `docs/implementation/a-accessibility.md`，决定见 `docs/adr/0003-visual-direction-a.md`。VA01–VA14 代码与自动化在 `codex/mileaf-v1` 本地提交；C10/C「数据拼贴」文档与渲染仅作历史证据。真机、真实站点/地图、性能与双端隔离构建仍为独立外部 gate，不因 A 实施而关闭。

- 2026-11-02 用户明确授权把 `codex/mileaf-v1` 合并进 `main` 并推送到 `origin/main`（GitHub `wynnok/MileafMobile`）；本次推送覆盖 v1 已实施的全部提交，不重写共享历史、不改 `MileafServer/` 与 `teslamate/`。该授权只针对本次：后续任何推送、部署或上架仍需逐次确认；推送不解除真机、真实站点/地图、性能、双端隔离构建等外部 gate，也不关闭相关票。

- 2026-11-02 外观 v2（AV01–AV09，三批）本地完成，取代 A 的配色与默认外观：强调色由玉绿改电光蓝（`accent` 供图形、`accentStrong` 供文字），中性底去绿去暖（浅 `#F4F5F7`/`#FFFFFF`、深 `#0A0B0D`），外观默认改跟随系统（顺序 跟随系统/浅色/深色），浅色 hero 改 12 外距 + 20 圆角卡片、深色仍满幅。版面范式、字号阶梯、间距档位、圆角体系与数据口径不变；实现与证据见 `docs/implementation/appearance-v2.md`、`docs/implementation/appearance-v2-renders/`、`docs/implementation/appearance-v2-review.md`，决定见 `docs/adr/0006-appearance-and-accent.md`。本次不推送，外部 gate 与相关票状态不变。

- 2026-11-02 仓库清理（用户授权）：以外观 v2 为基准归档历史图册——删除 C、湖畔、owner 复验与三次扩展的 10 个图册共 701 张图 / 96.4 MiB，另删 17 个只服务于已归档图册的渲染入口（`collage_*_render_test.dart` 等），被复用的夹具移入 `test/support/`。只保留外观 v2 与 A 两代图册；图像仍在提交 `725ceda`，说明与恢复方式见 `docs/implementation/render-archive.md`。未重写历史，`.git` 体积不变；后续换代按「当前一代 + 上一代对照」归档，不再平行堆图册。

- 2026-11-04 用户逐份确认 ADR 0007、充电费用补录 Spec 与 CET01–CET07，授权按 App＋可控HTTP和正式Flutter渲染/语义边界实施，并在当前 `main` 本地提交、不推送。双入口共用底部表单，只补录已结束且cost为null的记录；0元不可覆盖，单价不保存。后端0.4.0无写入能力开关查询，未启用按403反馈；未知币种允许按原账本填写。实现与证据见 `docs/implementation/charging-cost-entry.md`，外部gate不因本地实施而关闭。

- 2026-11-04 GitHub 追踪收口（用户确认口径 A，取代此前"外部待验票不关闭"的绝对表述）：v1 全部功能切片的代码与自动化已确认在 `main`（`b3281e8`）完成——`tool/flutterw analyze` 无诊断、`tool/flutterw test` 455 通过 / 6 跳过 / 0 失败，据此把已完成票结项关闭。#3–#10、#12–#15、#18–#21 共 16 张各自发布中文结项评论（已交付／证据路径／仍未验证的外部条件）后以 completed 关闭，只新增评论、未改任何票正文。追踪面只保留 #1（Spec 与路线图）、#11（真实底图外部验收）、#16（设备性能采样）、#17（整机／真实站点／Grafana 验收），依赖链收敛为 `#11 → #16 → #17`。今后按"代码与自动化完成即结项关闭，残余外部条件集中到 #17（地图归 #11、性能归 #16）"执行；本条目不解除任何外部 gate，只是改变其承载票。本次未推送、未改仓库可见性。

- 2026-11-05 开源准备（用户确认）：`creator/` 创作与宣传视频工作区整体不纳入版本库，`.gitignore` 改为 `/creator/` 覆盖全部子目录；`docs/product/direction-review-v2.md` 与 `docs/prototypes/directions-v2/`、`docs/prototypes/overview-expansion/`、`docs/prototypes/visual-refresh/` 三组评审原型改为纳入版本库——它们已被 ADR 0001、`docs/specs/mobile-v1.md` 等已跟踪文档引用，提交后公开仓库不再有死链。既有实施记录中"原型未跟踪、不纳入提交"的措辞属于当时事实，不回溯改写。

- 2026-11-12 用户确认整体UI/UX优化的正式ADR、Spec、Tickets更新并发布GitHub。GitHub增量为#27，U00–U12为#28–#40。当前设计增量入口为 `docs/adr/0011-ui-ux-refinement.md`、`docs/specs/ui-ux-refinement.md`、`docs/specs/ui-ux-refinement-tickets.md`、`docs/specs/ui-ux-refinement-delivery.md`。目标为克制、精致、有秩序，按R/P/S/G与U00–U12执行。产品实施待开始，U01代表视觉待验。字号/层级/Hero/控件/图表/动效按新规格§1.4明确替代旧视觉条款，阅读连续性以2f8755c为基线。性能正式验收沿#16每平台每指标至少30样本及既有p95预算，地图/整机外部条件沿#11/#17承载。本轮授权覆盖文档本地提交和Issue发布，后续产品实施与Git推送按当次指令。

- 2026-11-16 用户要求把应用底部 bar 改成 iOS 27 液态玻璃风格（高透但不影响阅读），参考示意图 2 的悬浮胶囊与更亮的独立选中胶囊。决定见 `docs/adr/0013-liquid-glass-navigation.md`，条款 L01–L08 见 `docs/specs/liquid-glass-navigation.md`，实施与取像素实测见 `docs/implementation/liquid-glass-nav.md`，图证见 `docs/implementation/liquid-glass-nav-renders/`。底栏改为胶囊 + 玻璃材质（36σ 模糊、1.35 过饱和、上淡下浓叠色、受光边缘、挖孔阴影），选中镜片是第二层玻璃；未选目的地文字由 `textFaint` 提升到 `textMuted`（蓝色图表透出时实测 4.25→4.92:1）。顶栏仍为焕新规格的磨砂材质，原生 Liquid Glass 折射仍在 ADR0012 候选。本次未推送，外部 gate（#11/#16/#17）不因本地实施关闭。

- 2026-11-16 用户指出「概览」图表下方内容可读性差、排版与秩序感不好，要求按克制、精致、一体性强、有秩序感、重排版层级与微动效的方向重新设计。实施见 `docs/implementation/overview-reading.md`，图证见 `docs/implementation/overview-reading-renders/`，条款依据焕新规格 R06.3、R06.6、R07 与 §1.4 间距档位，配色与字号阶梯未变。做法：把原来 7–10 行 `\n` 拼接的单段文字拆成两件东西——图表读值（日期 → 主值 24 → 参照 12 → 差值 14，按 R06.6 字面顺序各占一行；仅换指标时 120ms 淡入、减动效归零，拖动取点原地更新不闪烁）与本期读数表（1px 分隔线 + `本期` 标题 + `MetricGrid` 四格 + 单段口径脚注，费用覆盖 `8/9 次已记录` 落在费用格旁而非表尾）；`TimeSeriesChart` 新增可选 `readoutBuilder`，朗读句子仍由 `readout` 单一提供（`excludeSemantics`），下钻按钮留在 live region 外，其他调用方行为不变。200% 字号下读值自然堆叠、读数表由 `MetricGrid` 自动单列。审查确认的遗留问题：浅/深两种模式下 `textFaint` 都比 `textMuted` 更实且均低于 4.5:1，属外观 v2 的调色板层问题，未在本次逐页改。本次仅本地提交，未推送；真机字体、读屏与性能仍在 #16/#17。


- 2026-11-16 用户指出「概览」红框处（每日里程图表头）可读性差、排版与秩序感差，要求按克制、精致、一体性强、有秩序感、重排版层级与微动效重做。实施见 `docs/implementation/overview-chart-header.md`，图证见 `docs/implementation/overview-chart-header-renders/`，条款依据焕新规格 R01（标题到所属内容 12、控件间 8）、R02、R06.3、R06.5、R07 与 §1.4，未新增颜色/字号/圆角/动效 token。做法：把原来挤在同一光学行的三块碎片（标题、`11.01 — 11.16\nkm`、右侧浮动的图例）改成固定阅读顺序——标题 `type.title` + 度量 `micro` 12 `textFaint` 同行，区间 `label` 14 右端与绘图区右沿同线（与 `SectionHeader` 同构，长区间可收窄换行），指标控件之后、绘图区之上单独一行图例；图例只在能指认时画样本（单测量或参照虚线），单测量且已被控件点名时只列参照，多测量同色时只列名字。`subtitle` 收窄为「窗口」，行程详情两处「点按图形读值」改到读值旁的 `trailing`，`SampleChart` 删掉图下重复的单位行；大字时区间落到标题下一行同左缘，`headerTrailing` 改为独占标题下一行。`TimeSeriesChart` 公共参数未变，行程/统计/充电/洞察各页自动继承。本切片不新增动画（R07 白名单不含图例出现/消失，且那必然要动行高）。改后全量 754 通过 / 33 跳过 / 0 失败。本次仅本地实施，未推送、未提交（工作区另有 Apple 焕新的在途改动，按 AGENTS「不擅自提交」保留）；真机字体、读屏与性能仍在 #16/#17。

- 2026-11-18 用户以截屏红框指出「行程」焦点卡卡头：360 宽设备上区间 `10月20日–11月18日` 折成两行、末尾「日」孤悬。实施见 `docs/implementation/period-header.md`，图证见 `docs/implementation/period-header-renders/`，条款依据焕新规格 R21.4（区间只在卡片标签出现一次）与 DF3（连接号 U+2013），未新增颜色/字号/圆角/动效 token。做法：行程页 `_summary` 与概览页 `_focusCard` 各自复制的那段「150% 起改两行」阈值近似，替换为共享组件 `MileafPeriodHeader`——外层 `Wrap(spaceBetween)` 按实际宽度决定「一行 + 区间右对齐」或「区间整段落到下一行、左对齐」；整段区间也放不下一行时（320 宽 200%）只在 DF3 连接号后断行，`Semantics` 仍读整段。改后 `analyze` 无诊断，`MileafPeriodHeader` 4 用例与行程/概览/AP07/AP09/文案守卫通过（`强调色分层` 两条失败来自在途的底栏未选文字色重定，与本次无关）。本次仅本地实施、未提交（工作区另有 Apple 焕新与底栏在途改动，且 `design_components_test.dart`、`components.dart` 与本次重叠，按路径暂存会带走他人的改动）；真机字体、读屏与性能仍在 #16/#17。

- 2026-11-18 用户以截屏红框指出底栏「再透明一点，透明到能够隐约看到 tab bar 后面的内容，再靠近 iOS 27 的液态玻璃一点……毛玻璃不像，液态玻璃也不像」。实施见 `docs/implementation/liquid-glass-nav.md` §7，条款见 `docs/specs/liquid-glass-navigation.md`（L03/L04 取值重定 + 新增 L10–L12），决定见 `docs/adr/0013-liquid-glass-navigation.md` §「2026-11-18 修订」，图证 `docs/implementation/liquid-glass-nav-renders/` 全部重采。做法：玻璃体叠色减半（浅 12%→20% 白、深 29%→45% 近黑）、模糊 36σ→22σ、过饱和 1.35→1.5；修掉首版两个「画了但看不见」的参数——`sheenReach`/`meniscusStart` 从未接线（停在默认 0 / 1），修复后才有上亮下厚的受光走向，边缘由斜向渐变改成竖向着色，另加两侧端头增厚与 16% 高的镜面线；选中镜片补自己的受光带。为守住 L04，未选目的地由 `textMuted` 改为底栏专用的 `navigationLabel`（浅 #3A444E / 深 #C9D3DD），选中图形由 `accent` 改 `accentStrong`；渲染实测 未选标签 5.66–12.90、选中标签 4.80–12.46、未选图标 5.75–12.17、选中图标 3.87–11.18，最低余量 7%（浅色首屏选中标签 4.80）。镜片受光带做成开关（默认关），顶栏车辆胶囊与设置圆钮观感不变（`apple_polish_ap02_test` 新增用例钉住）。深色不能跟浅色一起薄：选中标签压在品牌蓝图表上，29%→45% 才够 4.5:1，规格 L10 因此给深色单独一档上限。本次仅本地实施；工作区另有 Apple 焕新与 period-header 在途改动，提交只按 hunk 暂存本次文件。真机材质、减透明/高对比映射与合成帧成本仍在 #11/#16/#17。

- 2026-11-18 用户指出「设置」页面（截图为设置 → 地图页）排版对齐失序，要求按克制、精致、一体性强、有秩序感、重排版层级与微动效重做。实施见 docs/implementation/settings-order.md，图证见 docs/implementation/settings-order-renders/，条款依据 apple-polish R22–R24/R27/R30/R32、§4 M08/M11、§5 P12 与 ADR0010 既有决定；玻璃/阴影未入内容层（ADR0013、apple-polish §1.2）。做法：本机配置卡固定「结论→配置→破坏操作」三段（状态块 16/12 内边 + 从状态文字起点到卡右缘的 1px 细线 + Key 摘要行 + 组末独立 error 破坏行，读取失败时清除仍可用）；保存/清除结果句与错误句移出卡片成画布层脚注（保存句精简为「打开详情地图后可查看加载结果。」，删去与状态行重复的「Key 已保存在本机」，不在 D7 冻结清单、教程与测试无引用）；申请帮助与数据使用说明折叠补齐内边距、MileafCopyRow 分隔线画到卡右缘；分组标题/脚注按 R24 对齐卡片内边距。共享组件 additive：MileafGroupHeader 与 MileafDisclosure 新增 inset（默认 0，其余页面零变化），MileafCopyRow 右缘补 cardPad（全库仅本页使用）。状态句换值 120ms 淡入（M08，减动效归零），读屏单一 live region 首帧即新值。新增「秩序断言」测试钉起始线与状态文字偏移；本次文件 analyze 0 诊断，相关 102 用例全过，文案守卫 45=基线；全量残余失败均在在途任务持有的 charging/overview 统计文件。本次已按路径选择性本地提交 86bda7f（只含本切片 36 个文件，未推送；工作树另有 Apple 焕新、底栏、period-header 在途改动未卷入）；真机字体、读屏与性能仍在 #16/#17。
- 2026-11-18 用户以截屏红框指出「充电」页两处（「最近充电」记录卡与「充电地点」分组卡）可读性差、排版与秩序感不好，确认两处都重做。实施见 `docs/implementation/charging-rows.md`，图证见 `docs/implementation/charging-rows-renders/`（含 before 对照与深色 200%），条款依据 apple-polish R21 第 5 条、R22、R23.1、R24（两条起始线）、R25 与焕新规格 R05/R09/R10；未新增颜色/字号/圆角/动效 token。做法：修掉记录行与地点行贴卡片边缘的起始线偏差（行经共享 `_cardRow` 包卡内 16）；结果行由 `Wrap` 多字号混排改为固定读值网格（记录行三格 metricSm：充入/电网用电/费用；地点行两格 metricMd：充入/充入均价，与账目卡同档），标签在上、数值同基线成列，费用口径（币种未记录）落费用格旁注；地点行由三行等权 meta 改为「标题行+覆盖句（N 次中 M 次有费用）+两格主值」；补录胶囊独立成行不串跳；共享 `MetricBlock` 非聚焦标签由 textFaint 回 textSecondary（R23.1，功能文字两级，可见变化为全库网格标签加深一档）；地点行 key 收进 `chargingLocationKey()`。copy guard 基线 charging_page 114→119（新网格语法的新字面量行，无旧文案放行）。测试断言随结构映射规则更新（charging/reading/expansion/method_section/ap10），新增 opt-in 渲染入口 `test/charging_rows_render_test.dart`（skip 机制与 AP07 同）。本次已按路径选择性本地提交（只含本切片文件，未推送；工作树另有 Apple 焕新、底栏、period-header、settings-order 在途改动未卷入）；真机字体、读屏与性能仍在 #16/#17。
