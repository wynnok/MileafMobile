# 统计·全部指标索引页（P15）版式修复（2026-11-20）

触发：用户以整页红框截图指出「统计 → 全部指标」这一页的版式问题（红框自导航栏上沿
一直圈到页尾说明行下沿，即**整页的纵向节奏**）。

一句话结论：本页是全仓**唯一**一处在两个方向上都把间距写成 0 的二级页——首张卡顶在
导航栏底缘、页尾说明行顶在卡片底缘（R24 的间距表里没有 0 这一档）；页尾还是**裸
折叠行**，不是 R30.2/PD08 的「分组标题 + 一张分组卡」，读屏名目也停在 CP05 已废弃的
「数据说明」。逐项按条款改回；三处一起修好后行尾箭头才与卡内行落在同一条竖线上。

**第二轮（同日）**：用户就 §4 登记的孤字项回复「授权按照推荐实施」，把「原始统计指标」
的说明由 16 字改为 14 字（见 §2 第 5 行）。这一处**不是条款违规**，是排版判断题
（R30.1 允许两行、R24 允许增高、R03 明确允许折行），已在 §2 与 §4 如实登记。

## 1 复现与证据

- 基线提交：`b1d86ba`（`main` 顶端，工作区未提交）。三处偏差在该提交上均可复现。
- 机位：360×800、safeArea 上下 24、100% 字号（`test/statistics_all_metrics_layout_test.dart` 的
  `openAllMetrics`）。**两套夹具分别用于两处**：
  - 布局用例用 `insightsClient`（`test/apple_polish_ap11_test.dart`，统计洞察的整数化夹具）——
    本切片只关心版式，不关心数据状态档。
  - 样张用 `aGalleryClient(scenario: 'normal')`（`test/apple_polish_ap11_render_test.dart` 的
    `_pumpStatistics`）。
- 渲染入口（opt-in）：`test/apple_polish_ap11_render_test.dart`，本轮为「全部指标」补了
  390 / 深色 / 200% / 展开页尾四个机位。
  ```sh
  ./tool/flutterw test --no-pub test/apple_polish_ap11_render_test.dart \
    --dart-define=MILEAF_AP11_RENDER_OUTPUT=build/allmetrics-renders \
    '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
  ```
  产物：`build/allmetrics-renders/`。`build/` 是生成物，不入库；代表样张见
  [statistics-all-metrics-renders/](statistics-all-metrics-renders/README.md)。
- 修复前实测（360 宽，逻辑像素）：

  | 量 | 修复前 | 修复后 |
  | --- | --- | --- |
  | 导航栏底 → 指标卡顶 | **0** | 8 |
  | 指标卡底 → 页尾说明顶 | **0** | 32 |
  | 页尾行首（文字） | 20（页面边距，裸画布层） | 36（页面边距 + 16） |
  | 页尾行尾（箭头） | 340（页面边距右缘） | 324（页面边距 − 16） |
  | 卡内指标行行尾箭头 | 324 | 324（未变） |
  | 页尾分组卡 | 无（裸 `MileafDisclosure`） | `MileafGroupCard` |
  | 页尾分组标题 | 无（标签「数据说明」） | 「关于这些数据」+ 卡内「口径与估算」「时间与时区」 |

## 2 逐项处置

| # | 现象 | 条款 | 修复前（代码事实） | 修复 | 守卫 |
| --- | --- | --- | --- | --- | --- |
| 1 | 首张卡片顶在导航栏底缘，与导航栏之间没有间距 | R24「间距：只用 2、4、8、12、16、24、32」（0 不在表内）；同级先例 P07/P08/P09/P10/P11 二级页一律 `top: MileafSpace.s8`，设置与概览为 `s12` | `ListView(padding: MileafLayout.pagePadding(context))` → `top` 取默认 0，全仓 16 处 `pagePadding` 调用里只有本页与根页（`longTopics`）用 0 | 传 `top: MileafSpace.s8` | `页首：指标卡从导航栏下方 8 起排，不贴导航栏` |
| 2 | 页尾说明行顶在卡片底缘，区块之间没有间距 | R24「区块与区块 32」；`MileafDataNotes` 不自带上边距（P08 能耗、P07 节奏、P09 补能都由调用方给 `Padding(top: section)`） | 卡与 `MileafDisclosure` 直接相邻，间距 0 | 外层补 `Padding(top: MileafSpace.section)` | `页尾：说明分组与上方卡片之间是区块间距 32` |
| 3 | 页尾是裸折叠行：不是「分组标题 + 一张分组卡」，标签停在 CP05 已废弃的「数据说明」，行首/行尾都比同页卡内行错开 | R30.2/PD08「每个页面的末尾有统一的『关于这些数据』：分组标题 + 一张分组卡，卡内为默认折叠的说明行」；R24「两条起始线」；CP05 词表（「数据说明与更多」→「关于这些数据」） | `MileafDisclosure(label: '数据说明', child: Column(...))` 落在画布层：行首对齐页面边距 20、行尾箭头落在页面右缘 340，比上方卡内行的 324 右移 16 | 换成 `MileafDataNotes`，说明分两类：`DataNoteCategory.caliber`（「各专题只回答一个问题，指标口径与统计首页一致。」）与 `DataNoteCategory.time`（「沿用当前车辆与期间；统计时区 $timezone。」）；两条原文逐字保留，只改容器与分类 | `页尾为 R30.2 形式…旧名目「数据说明」退出`、`页尾说明行落在卡片内边距上，行尾箭头与指标行同一条竖线` |
| 4 | 说明行默认折叠，展开后应读到统计时区（行为不回归） | R30.2「卡内为默认折叠的说明行」 | 既有行为 | 未改；新增断言钉住「折叠时读不到时区、展开后读到」 | `页尾说明默认折叠，展开后读到统计时区` |
| 5 | 「原始统计指标」的 16 字说明在 360 宽断出**孤字**「细」，该行被撑到 85，与另外四行不齐 | **不是条款违规，是排版判断题**：R30.1「正文里每个指标最多一句限定（`footnote`，至多两行）」**允许**两行；R24「分组行最小高 单行 52，双行 64，记录行按内容自然增高且不低于 72」也**允许**该行增高；R03 原文「图轴可减少 tick，不能裁字；证据字段可折行」明确允许折行。真正的事实依据只有 360 宽的单行预算：卡宽 320 − 行内边距 32 − 行首图标列 32 − 行尾箭头列 28 = **228**，每字 ≈14.8 ⇒ 最多 15 字 | `'驾驶与充电的区间指标、时间桶明细'`（16 字，需 ≈237，差 9 就换行，末行只剩「细」） | 改写为 `'驾驶与充电的区间指标与时间桶'`（**14 字**，≈207）。按 §8「文案只在文案规范的规则与对照表范围内修改；含义变化必须先列逐句前后与理由并获用户确认」先列候选，经用户 2026-11-20 明确授权「按照推荐实施」。**含义代价**：去掉了「明细」，属含义收窄（原句承诺逐桶明细），见 §4 第 2 条 | `「原始统计指标」的说明在 360 宽单行，五行行高一致`（几何：与同页单行说明同高 + 五行等高且 ≥ 64）、`窄屏 320 宽最多折成两行，不再继续膨胀` |

### 为什么箭头错位要和前两项一起修

第 1、2 项是 0 间距，第 3 项是「容器选错」。三者的共同后果都落在同一条视觉竖线上：
页尾说明行的行尾箭头（340）与卡内指标行的箭头（324）相差 16。只补间距能消掉「贴住」，
箭头仍然错线；只换容器不补间距，页尾会继续贴住卡片（`MileafDataNotes` 自己不带
上边距）。所以三项一起改，守卫也按「同一条竖线」写。

## 3 组件与共享文件

- 本轮**没有改共享组件**：`MileafGroupCard` / `MileafGroupRow` / `MileafDisclosure` /
  `MileafDataNotes` / `MileafLayout.pagePadding` 的签名与实现全部未动。`MileafDataNotes`
  的「不自带上边距、由调用方给区块间距」是既有约定（P08 能耗页 `_dataNotes` 的同一写法，
  见 `statistics_conditions_page.dart`），本轮沿用。
- 色相与图标未改：索引行仍是 CL12/D4 的「与根页章节卡同一套身份图标与色相」
  （节奏 clock/violet、能耗 leaf/mint、补能 bolt/aqua、长期 battery/无、原始统计指标
  chart/无），与 `statistics_insights_page.dart::_chapter` 的 `MileafDataDomain` 取色一致。

## 4 范围外（本次不改，供裁定）

1. **320 宽仍会折行（末行 2 字，已无孤字）**：14 字说明在 360 宽单行（可用 228、
   需要 ≈207），320 宽可用只有 188（280 − 行内边距 32 − 行首图标列 32 − 行尾箭头列 28），
   实测排成「驾驶与充电的区间指标与时」/「间桶」——末行 2 字，不再是孤字，但「时间桶」
   会被拆开。要让 320 也单行需 ≤12 字，候选（需确认）：`驾驶与充电的区间与时间桶`
   （12 字）或 `区间指标与时间桶明细`（10 字，去掉「驾驶与充电」的范围限定）。
   本条只登记，未实施。守孤字的不变量因此**只被实测记录、没有进断言**：判「末行几个字」
   在 Flutter 侧只能靠 `TextPainter` 预估，而 `docs/specs/charging-method-share-ring.md:208`
   明文禁止（「预估值会随字体回退而漂移（测试字体每个字形都是方块）」）。能进断言的只有
   几何量（行数 / 行高），两条用例就是这么写的。
2. **含义收窄未收口**：改写把「明细」去掉了，而目的地页的分组标题仍是「时间桶明细」
   （`statistics_page.dart:671`、`:933` 的 `SectionHeader`）。CP02「一个概念在主界面只用
   一个词」因此并存短形式「时间桶」与长形式「时间桶明细」。处置建议：照「电耗 / 电耗
   （估算）」的先例在 CP02 表登记短/长形式，或把本页说明改回保留「明细」的等长串
   （`驾驶与充电的指标与时间桶明细`，同为 14 字）。本轮按用户授权逐字落地推荐串，不动。
3. **`longTopics()` 的 `ListView` 仍是 `top: 0`**（`statistics_insights_page.dart:534`）。
   它不是独立 Scaffold 页，卡顶在宿主「区间说明」折叠行下方，同样有 0 间距，但属
   P06 长期索引路由，不并入本切片。
4. **P09 补能**的「结论卡 → 主图卡」用 `section`（32）而同构的 P10/P08 用 `cardInset`（12），
   属既有跨页偏差（P08 记录 §4 已登记），本轮不牵动。
5. **索引行的色相是字面量而不是 `MileafDataDomain.*.hue`**：本页写死
   `MileafHue.violet/mint/aqua`，根页走域映射。两者当前取值相同，但 CL01 的
   「域 → 色相唯一映射」只有一处出口，字面量是重复的魔法值。属 Standards 观察项，
   改动会同时牵动五行的图标与色相表，留给后续统一。

## 5 双轴审查

### 5.1 改动后的符合性自查

**Standards**

- `./tool/flutterw analyze --no-pub lib test`：仅 1 条既有 info
  （`test/apple_polish_ap10_test.dart:342`），无新增。
- `./tool/flutterw dart format lib test`：格式化后 282 文件 0 变更。
- 裸值守卫（AP01）：新增的两处间距都走 `MileafSpace` 有名档位（`s8`、`section`），
  没有新增字面量。
- 文案守卫（`apple_polish_copy_guard_test`）：`statistics_insights_page.dart` 的中文
  字面量行数**下降 1**（`label: '数据说明'` 退出，两条说明原文逐字保留），基线随之
  由 118 收紧到 117（AGENTS「基线只许下降」）。
- 测试：`test/statistics_all_metrics_layout_test.dart` 新增 9 例；`apple_polish_ap11_test.dart`
  的「全部指标」用例按新形式改写定位（`数据说明` → `口径与估算`、`MileafDisclosure`
  1 → 2），业务断言未放宽。渲染入口新增 4 个机位（opt-in，默认跳过）。

### 5.2 两轴审查的发现与修复（各自独立上下文，固定点 `b1d86ba`）

**Standards**

| 级别 | 发现 | 处置 |
| --- | --- | --- |
| 硬 | 本记录缺「基线提交」（`docs/implementation/README.md` §8.2） | 已在 §1 补 `b1d86ba` |
| 硬 | §1 把布局用例的夹具写成 `aGalleryClient`，实为 `insightsClient` | 已按「两套夹具分别用于两处」改准 |
| 判断题 | 自定义 `rectOf(tester, finder)` 与 `test/support/hierarchy_probe.dart::_rectOf` 等三处同形（Duplicated Code） | 删掉自建 helper，改用 Flutter Test 自带的 `tester.getRect` |
| 判断题 | 用 `MileafGroupCard.first` / `findsNWidgets(2)` 钉死「本页恰好两张卡」，把组件行数写进断言 | 改为「含『节奏』那一行的卡」+ `descendant(of: MileafDataNotes)`，不依赖卡片数量与顺序 |
| 判断题 | 文案守卫基线只「未上调」未收紧 | 已收紧到 117 |
| 判断题 | 渲染入口 `allMetrics` 五参数同进同出（Data Clumps）、`expandNotes` 布尔开关 | 保留：这是单页机位的参数表，抽类型只会多一层转手；已在交接说明 |

**Spec**

| 级别 | 发现 | 处置 |
| --- | --- | --- |
| 硬（记录准确性） | 「导航栏 → 首卡 8」在 R24 表里**没有这一行**，8 属推断而非条款 | 代码注释与本文 §2 均改为「表里没有这一行；8 由同类二级页既有取值与 R26『安全区上沿 + 8 + 44 + 8』的节奏推出」 |
| 硬（不变量） | 文案守卫基线未收紧 | 已收紧（见上） |
| 判断题 | 说明行**顺序**被改（旧 time→caliber，现 caliber→time）但无断言 | 新增 `说明行按 R30.2 的固定顺序排列` 用例（R30.2「顺序固定」） |
| 判断题 | 说明行行距（相邻 8 + 8 = 16）无断言 | **不加**：该间距由 `MileafDisclosure` 自带的上下 `s8` 决定，属组件内部；页面侧断言会把测试耦合到实现上（与 Standards 那条同一理由），已在用例注释登记 |
| 判断题 | P15「技术值可复制」在本页无落点 | 本页没有服务端原值／快照 ID（R30.4 的清单是服务端字段名、枚举原值、快照 ID、算法版本），时区标识不是技术值，故不设「技术详情」类 |
| 判断题 | 4 个渲染机位超出红框所指 | 保留：R30.2 与 §6 要求每页至少浅深 × 100/200% 的正式机位；本切片只补该页 |

**文案改写一轮的增量审查**（用户授权「按照推荐实施」后重开两个独立上下文）

| 轴 | 级别 | 发现 | 处置 |
| --- | --- | --- | --- |
| Standards | 硬 | 生产注释与 §2 行 5 引 CP02/CP09 作孤字的依据，而 CP09 只列六条禁止形式（「·」拼行、单位当标签、服务端字段名、符号代替词、同屏重复单位、行尾箭头或全大写），无一条涉及孤字；「不靠换行凑形」是自行编造的条文 | 注释与 §2 行 5 改为如实陈述：**不是条款违规，是排版判断题**（R30.1 允许两行、R24 允许增高、R03 明确允许折行），唯一事实依据是 360 宽的 228 预算 |
| Standards | 硬 | §2 行 5 称 R02/R03「都要求不出现这种残行」，与 R03 原文「图轴可减少 tick，不能裁字；证据字段可折行」相反 | 同上；R03 的原文已就地引用 |
| Standards | 判断题 | `_lastLineChars` 用 `TextPainter` 预估换行，与 `docs/specs/charging-method-share-ring.md:208`「不在 Flutter 侧用 `TextPainter` 预估——预估值会随字体回退而漂移」冲突 | 删掉该 helper 与 320 的孤字断言，改按 `test/drives_test.dart:612-616` 的几何先例；孤字不变量降级为「实测记录」（§4 第 1 条写明为什么不能进断言） |
| Standards | 判断题 | 生产注释称「『时间桶』是本页目的地的概念名」，与代码事实不符（目的地 `SectionHeader` 是「时间桶明细」） | 注释改为「代价是丢掉『明细』」，并把 CP02 的短/长形式并存登记为 §4 第 2 条 |
| Spec | 硬 | 去「明细」属**含义收窄**，记录只以「断行」叙述，未标注 | §2 行 5 补「含义代价」，§4 第 2 条给处置建议 |
| Spec | 判断题 | 用 `card height == 5 × rowHeightTwoLine` 把 R24 的**最小高**当固定高 | 改为「五行彼此等高」+「每行 ≥ 64」，R24 语义恢复为下界 |
| Spec | 判断题 | 孤字的本质不变量（末行 ≥2 字）没有进断言 | 已按上一条改为「实测 + 记录」；不引入 `TextPainter` 预估 |
| Spec | 判断题 | §7 交接缺「文件:行、原文、新文、规则」逐条 | 见 §7.1 |

### 5.3 规格条款逐条核对

- R24 间距：区块与区块 32、卡内 16、行尾 16 全部落在有名档位上；「导航栏 → 首卡 8」
  **不是 R24 表里的一行**，8 由同类二级页的既有取值与 R26「安全区上沿 + 8 + 44 + 8」
  的节奏推出（见 §1、§2 与代码注释）。
- R24「两条起始线」：页尾分组标题对齐页面边距（画布层），卡内说明行对齐卡片内边距
  （页面边距 + 16）；指标行因行首图标再右移一档（`cardPad + nav + s12` = 48），
  与同卡 hairline 起点同一换算。
- R30.2/PD08：页尾统一为「分组标题 + 一张分组卡 + 卡内默认折叠的说明行」，五类里
  本页只有「口径与估算」「时间与时区」两类（缺哪类就不出现）。
- CP05/CP09：可见文案未新增，`数据说明` 这个旧名目退出主界面。
- 未触碰：结论卡/索引行内容顺序、路由与回调（`onTopic`）、5 行的图标与色相、
  `MileafDataNotes` 与 `MileafDisclosure` 的实现、`MileafLayout.pagePadding` 的默认值。

## 6 验证

```sh
./tool/flutterw analyze --no-pub lib test
./tool/flutterw dart format --output=none --set-exit-if-changed lib test
./tool/flutterw test --no-pub test/statistics_all_metrics_layout_test.dart
./tool/flutterw test --no-pub test/apple_polish_ap11_test.dart test/apple_polish_copy_guard_test.dart \
  test/ui_ux_u08_test.dart test/statistics_insights_test.dart \
  test/statistics_embedded_topic_test.dart test/design_components_test.dart
./tool/flutterw test --no-pub            # 全量
```

结果：`analyze` 仅 1 条既有 info；`dart format` 0 变更；定向 98 通过 / 1 跳过 / 0 失败；
全量 **1370 通过 / 57 跳过 / 0 失败**（HEAD 基线 1347/56；余下增量来自同一工作区的
并行会话，本切片 +9 例、另有 4 个 opt-in 渲染机位默认跳过）。样张见
[statistics-all-metrics-renders/](statistics-all-metrics-renders/README.md)。

## 7 未提交

按 `AGENTS.md`「不擅自提交、推送」：改动留在工作区，提交需当次授权。涉及文件：

- 生产代码：`lib/src/statistics_insights_page.dart`（`_AllMetricsPage` 两处间距 + 页尾形式 +
  「原始统计指标」的说明文案）。
- 测试：`test/statistics_all_metrics_layout_test.dart`（新增）、`test/apple_polish_ap11_test.dart`、
  `test/apple_polish_ap11_render_test.dart`（新增 4 个机位）、
  `test/support/copy_guard_baseline/statistics_insights_page.dart.txt`（118 → 117）。
- 文档：本文、`docs/implementation/statistics-all-metrics-renders/`、
  `docs/implementation/README.md`、`docs/agents/history.md`。

### 7.1 文案改写的逐条前后（CP12 §8 交接格式）

| 文件:行 | 原文 | 新文 | 规则 |
| --- | --- | --- | --- |
| `lib/src/statistics_insights_page.dart:1682` | `驾驶与充电的区间指标、时间桶明细` | `驾驶与充电的区间指标与时间桶` | §8 文案变更控制（含义变化须先列前后与理由并获授权）；用户 2026-11-20「授权按照推荐实施」 |
| `test/statistics_all_metrics_layout_test.dart:167`、`:169`、`:197` | — | 同一新串（用例内联，与同文件兄弟 meta 的写法一致） | 文案 tripwire：生产改字时这三处会红 |
| `test/support/copy_guard_baseline/statistics_insights_page.dart.txt` | `118` | `117` | AGENTS「文案守卫基线只许下降」 |

同轮工作区另有并行会话的在途切片（P08 能耗专题版式修复），本记录只覆盖「全部指标」
这一支。两件事在提交时必须分开处理：

- **同文件不同 hunk**：`lib/src/statistics_insights_page.dart` 的 `_whKm`（约 934 行）属
  并行切片的取整口径统一，与本切片无关，提交时须按 hunk 拆。
- **索引计数含并行产物**：`docs/implementation/README.md` 的头行计数 78→79 / 35→36 与
  §4 的 `statistics-conditions-layout.md` 行、`docs/agents/history.md` 的同段追加都同时
  包含两个切片；两切片不同时提交时，计数需按各自实际入库的文件重算。
