# UI/UX 精修正式 Flutter 图册

## U12 最终集成图册（2026-11-13）

当前产品输入为 `main@dce498e` 加 U12 共享呈现修复，完整源文件哈希、图像文件与 SHA-256 由 [u12-manifest.json](u12-manifest.json) 固定。最终命令结果见 [U12记录](../ui-ux-refinement/U12.md)。后文 U01–U03 的来源/统计保留为历史图册记录。

当前产品图册共1431张（核心1413＋阅读恢复18），历史U01/before共419张，根目录PNG总数1850。最终集成重新运行下列14条核心入口。输出复用原有归属目录，数据、字体、viewport、safeArea与各包交接和源码一致。

| 入口 `test/<文件>.dart` | 输出参数 | 输出目录（相对此根） | PNG数 |
| --- | --- | --- | --- |
| design_gallery_render_test | MILEAF_RENDER_OUTPUT | components | 12 |
| ui_ux_u03_test | MILEAF_RENDER_OUTPUT | components | 4 |
| ui_ux_u04_test | MILEAF_RENDER_OUTPUT | u04 | 47 |
| ui_ux_u05_test | MILEAF_RENDER_OUTPUT | u05 | 51 |
| ui_ux_u06_test | MILEAF_RENDER_OUTPUT | U06 | 94 |
| ui_ux_u07_test | MILEAF_RENDER_OUTPUT | U07 | 147 |
| ui_ux_u08_test | MILEAF_U08_RENDER_OUTPUT | gallery | 120 |
| ui_ux_u09a_test | MILEAF_U09A_RENDER_OUTPUT | 根目录，入口写gallery | 124 |
| ui_ux_u09b_test | MILEAF_U09B_RENDER_OUTPUT | 根目录，入口写gallery | 54 |
| ui_ux_u09c_test | MILEAF_U09C_RENDER_OUTPUT | 根目录，入口写gallery | 54 |
| ui_ux_u09d_test | MILEAF_U09D_RENDER_OUTPUT | 根目录，入口写gallery | 56 |
| ui_ux_u09e_test | MILEAF_U09E_RENDER_OUTPUT | 根目录，入口写gallery | 88 |
| ui_ux_u10_test | MILEAF_U10_RENDER_OUTPUT | flows | 308 |
| ui_ux_u11_test | MILEAF_RENDER_OUTPUT | U11 | 254 |

上表的components两入口合并计为一组共享组件集合，实际命令14条。各条完整命令格式为 `./tool/flutterw test --no-pub test/<文件>.dart --reporter expanded --dart-define=<输出参数>=docs/implementation/ui-ux-refinement-renders/<输出目录> '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'`。输出为根目录的五个专题省略最后的目录后缀。执行严格串行，各命令退出码和测试统计在U12记录；第一次补丁后的试跑随后用最终固定产品全部复生成。

### 覆盖与目视

P01→u04、P02→u05、P03→U06、P04/P05→U07、P06→u08、P07–P11→u09a–e、P12/P13/P16→flows/u10、P14→U11，P15随对应页面完整滚动/证据/展开机位。components覆盖角色、焦点/禁用/长文与图表边界。各包机位/HTTP数据细节沿包记录，正式字体的图片保留完整TextScaler与合成夹具。

U12本人逐张打开下列关键图，其余未列文件没有逐张人工目视，由同源矩阵尺寸/异常/终点动作断言验证。

| 实际打开文件 | 观察 |
| --- | --- |
| u04/overview-normal-light-360-100-top.png | 深底车况为锚点，今日三项可查，主图起始可见 |
| u05/drives-normal-light-360-100-top.png | 第一条完整、下一条起始可见，零基线标记与读值保持 |
| U06/charging-normal-light-360-100-top.png | 费用/覆盖紧凑，第一记录完整，0日基线点可辨 |
| U07/drive-normal-light-360-100-first.png | 地图/三结果/过程图顺序完整，ready图面为fake |
| U07/charge-normal-light-360-100-first.png | SOC横排、三结果、功率与精确读值/采样动作同屏 |
| gallery/u08-statistics-normal-light-360-100-top.png | 结论/真实参照/主图与专题第一行可见 |
| gallery/u09a-usage-normal-light-360-100-top.png | 四列日期矩阵、0/未知/分档图案区分 |
| gallery/u09b-conditions-normal-light-360-100-top.png | 小样本及非因果就近，点图与无样本槽清楚 |
| gallery/u09c-charging-normal-light-360-100-top.png | 覆盖分母、电量/费用控件与真实0可读 |
| gallery/u09d-range-normal-light-360-100-top.png | 独立月份、非健康限定、非零轴范围与波动带清楚 |
| gallery/u09e-parking-normal-light-360-100-top.png | 正负同轴，百分点及非预测说明就近 |
| flows/u10-connect-light-360-100-top.png | 服务地址、HTTPS说明与单一主操作清楚 |
| U11/cost-normal-light-360-100-first.png | 常驻币种、单价/电量/预估/后果/动作同一流 |

本机图册支持静态呈现与受控动作证据。G01具名用户视觉决定仍待验。真实系统字体、原生键盘、读屏、真实底图/CRS/网络、设备性能和真实站点/Grafana按G09与#11/#16/#17验收。

## U01–U03 历史来源与记录

2026-11-12，当前收录 U01 正式候选、U02 共享组件图册与 U03 图表状态板，U01 用户视觉决定按「按候选继续」授权保持待验。U01 收尾已完成：全量 591 通过 / 12 跳过 / 0 失败，图册由收尾会话重新生成并核对为 316 + 96 张。U02 已交付共享系统收敛与 `components/` 三条画廊（12 张）。U03 已交付图表/状态/动效基础与 `components/chart-states-*` 状态板（4 张），全量 618 通过 / 13 跳过 / 0 失败（含 U03 新增 11 条回归与 1 条 opt-in 渲染用例）。任务状态见[总控记录](../ui-ux-refinement/README.md)、[U01 交接](../ui-ux-refinement/U01.md)、[U02 交接](../ui-ux-refinement/U02.md)与 [U03 交接](../ui-ux-refinement/U03.md)。

## 来源与范围

产品输入为 `b28dfa1bb018519c2991aaafe94e08ddcaebce17`，U01 直接修改正式 Flutter 共享组件及行程、统计首页、充电详情、费用表单。`6ae9d5c` 是总控文档提交。结果提交及最终命令统计据 [U01 交接](../ui-ux-refinement/U01.md)接续登记。[具名候选、token 与用户决定](../ui-ux-refinement/visual-reference.md)

本目录是本轮唯一图册根。U01 分配 `gallery/drives-*`、`gallery/statistics-*`、`gallery/charge-detail-*` 与 `flows/cost-*`，目录 README 由总控维护。后续包在总控分配具体页面/场景后接续发布。

## 文件与机位

2026-11-12 17:50–17:52 由 U01 收尾会话重新生成后核对：三份 JSON 的 `images` 清单与磁盘一致，gallery 共 316 张，缺失 0、额外 0；flows 共 96 张，合计 412 张（目录合计 416 个文件含 3 份测量 JSON 与本 README）。先前记 318/414 为清理 6 张过期滚动帧后未回填的旧计数，现按磁盘校正。

| 集合 | 主机位数 | 含滚动的 PNG 数 | 内容 |
| --- | --- | --- | --- |
| [普通与边界清单](gallery/u01-measurements.json) | 60 | 246 | 三页 360×800，正常/空/缺失，浅深×100/200%；正常补130/150%；行程/统计补320×568的100/200%及390×844的100% |
| [safeArea=0 清单](gallery/u01-safe0-measurements.json) | 6 | 16 | 三页 360×800，浅深正常100% |
| [长字段清单](gallery/u01-long-measurements.json) | 12 | 56 | 三页 360×800，浅深正常100/200%，长地点/长车名 |
| `flows/cost-*` 普通表单 | 40 | 80 | 360×800，浅深×100/130/150/200%，空输入/预估/非法输入/403/待确认，各有输入与动作机位 |
| `flows/cost-*` 窄屏表单 | 8 | 16 | 320×568，浅深200%，长地点/未知币种/最大金额/键盘 inset300，各有输入与动作机位 |
| `components/gallery-*`（U02） | 12 | 0 | 组件状态画廊浅深×100/200%：`gallery-*` 代表组件、`gallery-long-*` 长文本、`gallery-states-*` 焦点/禁用/处理中 |
| `components/chart-states-*`（U03） | 4 | 0 | 图表状态板浅深×100/200%：折线+参照虚线与 null 断线、正/负/0/null/极值柱、稀疏竖线（真实 0 与 null 不画线）、单点、大数轴（千位缩写）、长轴标、全空说明；200% 大字 Y 轴减 tick、图例移行、轴标完整放大 |

`components/` 由 U02 分配并维护，入口为 `test/design_gallery_render_test.dart`，视口 360 宽、高度按画廊 1200/2200/1900，DPR 1、PNG 输出倍率 2，字体与数据口径同上节（合成夹具、固定 2026-10-26）。逐张目视清单见 [U02 交接](../ui-ux-refinement/U02.md)。

命名为 `页面-场景-模式-宽度-字号-机位.png`。`top` 为初始机位，`scrollN` 为按视口70%递进的完整滚动序列，`action` 为滚至表单动作区，`safe0` 为零安全区。gallery 完整文件名及 body 测量在上述 JSON 中。flows 的具体场景、字号与生成数量由 `test/charging_cost_render_test.dart` 的 U01 分支定义。

## 环境与数据

- Flutter 3.47.7 / Dart 3.13.5，使用项目 `tool/flutterw` 与既有本地依赖。DPR 为 1，PNG 输出倍率为 2。
- gallery 普通机位的 `viewPadding` 与 `padding` 为 top24/bottom24，safe0 分支为0。费用入口使用测试默认安全区，键盘由 `FakeViewPadding(bottom: 300)` 模拟 `viewInsets`，截图下方留白对应该 inset，设备键盘另属 G09。
- 随包 Inter 400/500/600，中文测试字体 `/System/Library/Fonts/Supplemental/Arial Unicode.ttf` 仅注册到 fallback，MaterialIcons 随 Flutter 加载。字体身份与哈希见 [U00](../ui-ux-refinement/U00.md)。
- gallery 使用真实 `MileafApp` 和 `aGalleryClient`，日期固定为2026-10-26、站点时区 Asia/Shanghai。U01 的 `irregular=true` 生成自洽非均匀日桶，长字段只替换显示地点/车名。
- 费用使用 `CostSite` 可控 HTTP，单价1.25、计费电量22 kWh、预估27.50，包含403和结果待确认等状态。费用键盘场景保留坐标点击及仅一次 PATCH 的验证。数据均为合成夹具。

## 复现

在仓库根核对 cwd、输入提交与文件归属后串行运行。以下四条为本包实际入口，2026-11-12 17:50–17:52 由 U01 收尾会话逐条实跑，四条均退出 0（耗时 00:14 / 00:02 / 00:04 / 00:11），随后按 JSON `images` 与磁盘逐项核对。源码与统计见 [U01 交接](../ui-ux-refinement/U01.md)。

```sh
./tool/flutterw test --no-pub test/a_gallery_render_test.dart --dart-define=MILEAF_U01=true --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/ui-ux-refinement-renders/gallery '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
./tool/flutterw test --no-pub test/a_gallery_render_test.dart --dart-define=MILEAF_U01=true --dart-define=MILEAF_U01_SAFE_ZERO=true --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/ui-ux-refinement-renders/gallery '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
./tool/flutterw test --no-pub test/a_gallery_render_test.dart --dart-define=MILEAF_U01=true --dart-define=MILEAF_U01_LONG=true --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/ui-ux-refinement-renders/gallery '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
./tool/flutterw test --no-pub test/charging_cost_render_test.dart --dart-define=MILEAF_U01=true --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/ui-ux-refinement-renders/flows '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

U02 组件画廊入口（2026-11-12 由 U02 会话实跑，退出 0，输出 12 张到 `components/`）：

```sh
./tool/flutterw test --no-pub test/design_gallery_render_test.dart --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/ui-ux-refinement-renders/components '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

U03 图表状态板入口（2026-11-12 由 U03 会话实跑，退出 0，输出 4 张到 `components/`，命名 `chart-states-<浅/深>-<100/200>.png`；视口 360×800、DPR 1、PNG 倍率 2，合成夹具、无 HTTP，读值用默认「日期 · 数值 单位」结构）：

```sh
./tool/flutterw test --no-pub test/ui_ux_u03_test.dart --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/ui-ux-refinement-renders/components '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

## 总控抽样目视与测量

U01 收尾会话重新生成后实际打开 8 张（另回看总控早前抽样的同源机位）。未打开的图按同源清单与自动化测量核对，逐张目视状态如实记录。

| 已打开图片 | 实际观察 |
| --- | --- |
| [行程浅色100%](gallery/drives-normal-light-360-100-top.png) | 36号里程、88高节奏绘图区、首条记录完整与第二条起始同屏，数值/单位/日期对齐一致 |
| [行程深色200%](gallery/drives-normal-dark-360-200-top.png) | 汇总事实改分行（52 趟 / 估算 197.47 kWh / 净电耗 154 Wh/km），期间控件 44 高换行整齐，无横向溢出 |
| [行程长字段200%](gallery/drives-long-light-360-200-top.png) | 顶栏车名按 R03 尾部省略，主数与图表不受影响，无截字或挤压 |
| [统计浅色100%](gallery/statistics-normal-light-360-100-top.png) | 结论 36 号主值 + 差值与「依据」同组，主图 0/50/100 三档轴与参照虚线可读，专题第一行完整 |
| [统计深色200%](gallery/statistics-normal-dark-360-200-top.png) | 比较日期自然换行、图例移行，图下与专题需滚动到达，无溢出 |
| [充电详情浅色100%](gallery/charge-detail-normal-light-360-100-top.png) | SOC 弧与 18%→82% 并排，三结果分列，200高功率图与采样动作同屏 |
| [费用浅色100%](flows/cost-preview-light-360-100-top.png) | 单价输入、币种标签、预估/计费说明、写入后果与唯一主动作在同一表单流 |
| [费用键盘动作](flows/cost-keyboard-light-320-200-action.png) | 320宽200%下滚至动作区，确认按钮位于键盘 inset 之上，可实际命中 |

其余机位（空/缺失/130%/150%/390/320×568/safeArea=0/完整滚动序列）未逐张人工打开，按同源 JSON 的 body 测量与自动化断言核对，属本轮未逐张目视项，如实保留。

普通360×800、100%机位采用 body 相对坐标。总控读取最终 JSON，行程 body 高620、首记录492–580；统计 body 高620、专题第一行509–617；充电详情 body 高696、图框335–577，其中绘图区高200。C10 的“第二条正文可见”已在自动化中按规格§5 P02 口径落实为“第二条记录起始≥24 可见”，实测 25.0，见 [U01 交接](../ui-ux-refinement/U01.md)。

旧图对照来自 `docs/implementation/readability-renders/`，当前抽样只证明本机正式 Flutter 的静态布局。真实字体、系统键盘、读屏、真实地图/CRS/网络、设备性能和真实站点/Grafana沿 G09 与 #11/#16/#17 待验。G01 用户视觉决定仍待用户裁定；U02/U03 全局收敛及其余页面迁移状态见总控与逐包记录。

## U12 阅读恢复补验

新增 `reading/` 18张，核心1413张加阅读18张得到1431张当前产品图片。原始参考419张保留，总PNG1850张。入口为 `test/reading_restore_render_test.dart`，完整命令与旧定位器修正见U12记录。overview/统计各浅深100/200共8张；补能自定义日期控制与返回后原选点各4张；多页行程恢复浅100/深200共2张。日期取消和选点恢复通过真实点击/滚动断言，概览机位在返回后回滚核对期间。

U12另逐张打开 `flows/u10-edit-dark-320-200-keyboard-action.png`、`U11/cost-maximum-dark-320-200-action.png`，确认320/200%主操作在模拟键盘上方可达。打开 `reading/charging-topic-dark-200.png`，确认3/6原选点读值；`reading/drives-restored-dark-200.png`保留已显示全部行程、末记录和数据说明入口。
