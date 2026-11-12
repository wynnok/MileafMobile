# U01 正式 Flutter 代表候选

2026-11-12。U01 收尾完成（全量 591 通过 / 12 跳过 / 0 失败，四入口渲染退出 0）。具名候选仍待用户评审，实际用户决定为“待确认”；不能将本文件的候选命名视为参考已冻结，也不能据此启动 U02/U03 的全局推广。

## 输入与复现

产品 baseCommit 为 `b28dfa1bb018519c2991aaafe94e08ddcaebce17`，业务基准为 `2f8755c`。总控文档提交 `6ae9d5c` 与产品差异分别记录。本候选从正式 `lib/src/design/` 及四页实现生成，无专用主题、HTML截图或图片拼接。

- `U01-trip` 为行程候选，归属 `gallery/drives-*`。
- `U01-statistics` 为统计候选，归属 `gallery/statistics-*`。
- `U01-charge-detail` 为充电详情候选，归属 `gallery/charge-detail-*`。
- `U01-cost` 为费用表单候选，归属 `flows/cost-*`。

正式输出根为 `docs/implementation/ui-ux-refinement-renders/`。文件名包含页面、场景、模式、逻辑宽度、字号与机位，`top`为初始机位，`scrollN`为按视口70%前进的完整滚动序列，`action`为表单动作区。根README由总控维护，本文件记录U01增量。

### 字体与环境

Flutter 3.47.7、Dart 3.13.5，沿项目 `tool/flutterw`，依赖与缓存保留项目既有位置。Inter 400/500/600 来自 `assets/fonts/`，中文回退使用 `/System/Library/Fonts/Supplemental/Arial Unicode.ttf`，仅注册到产品 fallback，MaterialIcons随Flutter加载。字体SHA-256沿U00记录，最终收尾复核。

主图 viewport 为360×800，边界320×568和390×844。viewPadding/padding top24、bottom24，补充safeArea=0机位，DPR1、toImage pixelRatio2。费用矩阵viewport360×800与320×568，键盘为FakeViewPadding bottom300，原生键盘未启动。字体完整跟随TextScaler，包含100/130/150/200%，另有非线性缩放回归。

### HTTP夹具

`a_gallery_render_test.dart` 使用真实MileafApp、内存session/外观/币种和 `aGalleryClient`。日期固定2026-10-26、Asia/Shanghai。普通统计1198.6 km/46趟，行程近30天1280.6 km/52趟，详情32.9 km，充电18%→82%、46.8 kWh、34分钟。全部合成数据，不连接真实站点。

U01开启 `irregular=true`，只在相邻等值日桶间转移距离/能量/时长，0槽保留，各总计和行程数保持，配对消耗率与覆盖保持自洽。默认false不改变其他调用方。对应回归逐项校验1198.6 km、46趟、能量合计不变和158 Wh/km配对率。longFields仅替换显示地点/长车辆名，保留ID、请求和数值。

费用使用 `CostSite`，0.4.0，20/22 kWh两类能量、1.25单价得到27.50。正常、空输入、非法单价、403、结果待确认、未知币种、最大金额、长地点均通过可控HTTP呈现。键盘场景补长地点，实际坐标点击提交后仅一次PATCH。

## 实际命令

```sh
./tool/flutterw test --no-pub test/a_gallery_render_test.dart --dart-define=MILEAF_U01=true --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/ui-ux-refinement-renders/gallery '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
./tool/flutterw test --no-pub test/a_gallery_render_test.dart --dart-define=MILEAF_U01=true --dart-define=MILEAF_U01_SAFE_ZERO=true --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/ui-ux-refinement-renders/gallery '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
./tool/flutterw test --no-pub test/a_gallery_render_test.dart --dart-define=MILEAF_U01=true --dart-define=MILEAF_U01_LONG=true --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/ui-ux-refinement-renders/gallery '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
./tool/flutterw test --no-pub test/charging_cost_render_test.dart --dart-define=MILEAF_U01=true --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/ui-ux-refinement-renders/flows '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

上述为本包复现入口，2026-11-12 17:50–17:52 由收尾会话逐条实跑，退出码均为 0（测试耗时 00:14 / 00:02 / 00:04 / 00:11）。生成后核对结果：

| 项 | 实际值 |
| --- | --- |
| 输入源码 | 工作树未提交候选（产品 20 文件 +631/−648，测试 27 文件 +586/−144 与 1 个新文件，图册 412 张新文件），基于 `b28dfa1`，HEAD 为 `f624d22` |
| gallery 图 | 316 张，三份 JSON `images` 合计 316，缺失 0、额外 0 |
| flows 图 | 96 张（`charging_cost_render_test.dart` 的 U01 分支） |
| 目录合计 | 416 个文件（412 PNG + 3 测量 JSON + 图册 README），50 MB |
| 测量 | 60 主机位 / 6 safeArea=0 / 12 长字段，含 body 几何与断言值 |

图面几何与字体的机器测量由 `gallery/u01*-measurements.json` 记录，完整文件清单从同次输出 manifest 核对。注意：JSON 内 `secondTitle*` 键沿用渲染入口的实测对象（第二条记录**首个 Text/标题**的可见高度，图册夹具实测 25.0），而 `test/ui_ux_u01_test.dart` 的 P02 回归与 U01.md 按**记录起始**计量（规格§5 原文口径）；两套计量对象不同但均≥24，读数时勿混用。

## 校准过程与规则偏差

- P02 使用88高绘图区、36主数、44期间控件，取消路线圆圈；按正式字体测量首条完整记录和第二条至少24。所有记录仍使用原ID回调，期间/选点/分页逻辑沿原实现。
- P06 首轮大字辅助结论/深底包装使专题过晚。候选将主图同底、图例与标题同行，趟数放主数旁，净电耗/已知支出/活跃日移至专题后可达摘要。首行整卡最后一次差1px，摘要组内8→4后重测，严格保留首行完整断言。
- P05 取消深底居中SOC块，弧与精确区间横排，三结果分列，标题统一充电详情，记录ID与精确时间在更多信息。功率/SOC切换、采样前后与扩展过程字段保留。SOC轴固定0–100，功率图绘图区200。
- P14 320宽大字或键盘可用高度<400时标题随内容单一滚动；输入与动作双机位，错误/查询状态保留原状态机。
- R03大字使旧地图同意条超过固定图高。总控C01最小修复把全文及启用动作移到图下自然高度，图面大字240，授权与SDK状态不变，U07接续其余降级状态。
- Standards初审发现普通字号“看当天”的子按钮被父级excludeSemantics排除，已改独立子语义并加tap action回归。
- Spec初审发现统计大字日期ellipsis与320无键盘费用标题未滚动，分别改日期自然换行/动作另行和窄屏大字分支，待原审查者复核。

## 目视清单

收尾会话实际打开 8 张（浅/深 × 100/200、长字段、窄屏键盘动作）：

| 机位 | 结论 |
| --- | --- |
| `drives-normal-light-360-100-top` | 36 号里程、88 高绘图区、首条记录完整与第二条起始同屏 |
| `drives-normal-dark-360-200-top` | 汇总事实分行、期间控件换行整齐、无横向溢出 |
| `drives-long-light-360-200-top` | 顶栏长车名尾部省略，主数与图表不受影响 |
| `statistics-normal-light-360-100-top` | 结论 36 + 差值与「依据」同组，三档轴与参照虚线可读，专题首行完整 |
| `statistics-normal-dark-360-200-top` | 比较日期换行、图例移行，无溢出 |
| `charge-detail-normal-light-360-100-top` | SOC 弧与 18%→82% 并排，三结果分列，200 高功率图与采样动作同屏 |
| `cost-preview-light-360-100-top` | 单价、币种、预估/计费说明、写入后果与唯一主动作同一表单流 |
| `cost-keyboard-light-320-200-action` | 滚至动作区，确认按钮在键盘 inset 之上且可命中 |

未逐张打开：空/缺失/130%/150%/390/320×568/safeArea=0 与完整滚动序列，按同源 JSON 测量与自动化断言核对，属未逐张目视项。

## 条目化偏差与断言变更

失败的 10 条回归已逐条处理，全部为测试侧修正（产品代码未改），原值→新值见 [U01 交接](U01.md#回归修复与断言映射)。其中两条旧绝对机位断言按规格§5口径改写（概览绘图区首 80、充电每日补能标题首屏），其余为按需构建/可命中定位修正。

## 用户决定与后续

当前没有收到针对本候选的用户视觉确认或按候选继续推广的明确回复。G01保持待验，U02/U03全面推广以实际决定为前置。G09真实字体/键盘/读屏、真实地图与站点、设备性能仍待验。未迁移页面（概览、充电、统计专题、设置）的排版问题清单见 U01 交接的待办项，由 U04/U06/U08/U10 接续。

U02接续正式tokens、布局和控件，收敛最大宽度/单位间距/全部控件状态/Focus/输入边界/概览Hero；U03接续各Painter/图轴/缺失与静态状态/减少动效。U05、U07、U08、U11各自补全页面矩阵与能力回退，保留本候选已通过的首屏和动作约束。
