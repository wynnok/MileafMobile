# 图形可读性与正式字体渲染（#26）

- 日期：2026-11-11
- 分支：`main`（工作树，未提交）
- 字体：`Inter` 400/500/600 取自随包 `assets/fonts/`（与 `pubspec.yaml` 同一批文件）；中文回退由 `MILEAF_RENDER_FONT` 单独声明为 `MileafType.fallback`（`PingFang SC` / `Noto Sans CJK SC` / `Heiti SC` / `sans-serif`），**不再把替代中文字体注册成 `Inter`**。加载逻辑在测试支持目录 `test/support/render_fonts.dart`，未进入产品运行时代码。
- 本机字体路径：`/System/Library/Fonts/Supplemental/Arial Unicode.ttf`（23278008 字节）。**只是测试回退，不是设备字体证明。**
- 生成条件：360×800 逻辑像素、`devicePixelRatio = 1`、`toImage(pixelRatio: 2)` → PNG 720×1600（费用表单机位为 320/390/768 宽）
- 数据：合成 HTTP 夹具（App＋可控 HTTP），**不是真实站点、不是真机截图**

## 统一命令前缀

```sh
FONT='/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
R=docs/implementation/readability-renders
```

| 入口 | 输出变量 | 张数 | 覆盖 |
| --- | --- | --- | --- |
| `test/a_gallery_render_test.dart` | `MILEAF_RENDER_OUTPUT` | 132 | 11 页 × normal/empty/missing × 浅深 × 100/200% |
| `test/readability_render_test.dart` | `MILEAF_RENDER_OUTPUT` | 12 | 稀疏序列（真零 + 缺失）与长车名 × 浅深 × 100/200% |
| `test/design_gallery_render_test.dart` | `MILEAF_RENDER_OUTPUT` | 4 | 共享组件状态画廊 |
| `test/a_overview_render_test.dart` | `MILEAF_RENDER_OUTPUT` | 12 | 概览 3 态 |
| `test/a_charging_method_render_test.dart` | `MILEAF_RENDER_OUTPUT` | 12 | 补能方式区块 3 态 |
| `test/reading_restore_render_test.dart` | `MILEAF_RENDER_OUTPUT` | 8 | 阅读恢复后的概览/统计 |
| `test/settings_render_test.dart` | `MILEAF_SETTINGS_RENDER_OUTPUT` | 14 | 设置与连接，含 `home-large`、`edit-large`、`keyboard` |
| `test/map_key_render_test.dart` | `MILEAF_MAP_RENDER_OUTPUT` | 14 | 地图 Key，含 `large`、`keyboard` |
| `test/charging_cost_render_test.dart` | `MILEAF_RENDER_OUTPUT` | 112 | 费用表单 360/320/390/768 × 键盘/窄屏/长文本 |

合计 320 张，全部写入本目录 `docs/implementation/readability-renders/`。

## 图册归属（2026-11-11 审查记录）

本节记录一个**尚未解决的规范冲突**，不粉饰：

- [render-archive.md](../render-archive.md) 的后续策略第 2 条要求「同一代的渲染不重复写入新目录；需要重跑时覆盖原目录」。本票（#26）自述为同代的「定点修订」（只改普通柱/竖线的实色与字体加载），按该条本应覆盖 `appearance-v2-renders/`，实际却新建了本目录——这是违反第 2 条的平行图册。
- 最终集成会话（2026-11-11）的处理：**没有删除任何图册**。删除正式渲染证据、前序会话产物不在本会话授权内（AGENTS「不擅自删除既有文件」＋本会话「保留正式渲染证据与前一会话资源」）。因此冲突保留，交由用户裁定。
- 已核实的对应关系（用于判定哪一代是当前）：按本目录命令重跑 9 个入口，320 张与本目录**逐字节相同**；`appearance-v2-renders/` 是上一代对照；`a-renders/` 是更早的历史证据；`reading-restore-renders/`（#24 的 8 张）与 `reading/` 下的 8 张是同机位，前者是 #26 字体修订前的版本。
- 建议的收口动作（需用户授权）：把 `reading-restore-renders/` 并入本目录的对照说明后删除；并在「#26 是否算新一代」上二选一——算新一代则本目录为当前、`appearance-v2-renders/` 保留为上一代；不算则把本目录内容覆盖回 `appearance-v2-renders/` 并删除本目录。

```sh
./tool/flutterw test --no-pub test/a_gallery_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=$R/gallery "--dart-define=MILEAF_RENDER_FONT=$FONT"
# 其余入口同构，按上表替换入口与输出变量；设置/地图用各自的输出变量。
```

每次保存后测试内先 `expect(tester.takeException(), isNull)` 再落盘；图册另断言每页每态的必备文案存在、正常态数字不得出现在空/缺失态，因此「文件生成成功」不等于通过。

## 图形改动的证据

- 普通柱与补能竖线改为 `accent` 实色；选中由「端点 4 + 光晕 8」表示，不只靠颜色。
- `gallery/drives-normal-*-*`（柱）、`gallery/charging-normal-*-*`（竖线）可直接对照。
- `sparse/drives-sparse-*` 展示**真实零**：`distance_km` 在已发布契约里非空，所以这一场景只有零、没有缺失，零画成基线上的 1.5 小圆点。
- `sparse/charging-sparse-*` 展示**缺失空槽**：按 `sessions > 0 && energy_known_sessions == 0` 归为无已知电量，竖线留空而不是补零。两类状态分别由两个场景各自证明，不是同一个场景同时具备。
- 旧一代 `appearance-v2-renders/gallery/drives-normal-light-100.png` 里非当前柱是 30% 淡蓝，本目录同机位是实色——这是本票的预期差异。

## 字体的可证伪对照

`gallery/topic-energy-normal-dark-200.png` 用于证明「渲染差异确实来自字体修正，而不是代码漂移」：

- 用**旧**加载方式（把 CJK 字节注册成 `Inter`）重跑同一机位，得到 `sha256 e5c98b197280ab35aae68586c2f50141eaaba005f888a72605bf94d6cb21fefa`，与 `appearance-v2-renders/gallery/topic-energy-normal-dark-200.png` **逐字节相同**（同样 140070 字节）。自 2026-11-02 起本页代码没有产生视觉漂移。
- 用**新**加载方式（随包 Inter + 独立中文回退）同机位得到不同结果，差异集中在文字行；逐行差分显示文字块位置与高度不变，只是字形与字宽变了。放大核对 `210 Wh/km` 仍在一行，未产生新的换行或溢出。

结论：图册间差异由字体修正触发，本票范围内**没有**需要适配修复的小范围布局溢出。

## 已人工打开检查（12 张）

| 图 | 看什么 |
| --- | --- |
| `design/gallery-light-100.png` | 共享组件全量状态、柱/竖线实色 |
| `gallery/drives-normal-dark-100.png` | 行程柱实色 + 选中端点/光晕 |
| `gallery/drives-normal-light-200.png` | 200% 下右端选中柱的端点/光晕未被裁切、零值小圆点 |
| `gallery/charging-normal-light-100.png` | 补能竖线实色 + 选中端点/光晕 |
| `gallery/statistics-normal-light-100.png` | hero 内面积/参照线层级未被实色规则波及 |
| `gallery/topic-energy-normal-dark-200.png` | 200% 深色下单位排版与选中标记 |
| `sparse/drives-sparse-light-100.png` | 真实零 → 基线 1.5 小圆点（该契约下无缺失） |
| `sparse/charging-sparse-light-100.png` | 无已知电量的日子竖线留空、每日读数正确 |
| `sparse/charging-sparse-light-200.png` | 同上，200% 下不溢出 |
| `sparse/overview-long-light-200.png` | 长车名 200% 截断方式未变 |
| `overview/overview-normal-dark-200.png` | 深色 200% 概览无溢出 |
| `settings/settings-light-keyboard.png` | 中文回退实际落点、键盘态 |
| `cost/320-keyboard-light-200.png` | 费用表单窄屏 200% 键盘态（与历史图册逐字节相同） |

为证明字体差异，另打开对比：`appearance-v2-renders/gallery/drives-normal-light-100.png` 与同机位新旧两张 `topic-energy-normal-dark-200.png` 及其放大裁剪（见上节）。

其余 307 张仅通过自动化（测试内文案断言 + `takeException` 无异常），未逐张目视。

## 证据边界

- 证明：正式 Flutter 组件在浅/深、100%/200%、正常/零/缺失/稀疏/长文本下的最终绘制结果；普通柱与竖线为实色；中文经声明的回退族渲染。
- 不证明：设备真实字体回退（各平台实际用哪款中文字体仍是外部 gate）、真机、读屏、真实站点/地图、动画与性能；这些属 #11/#16/#17。

## 本票未处理、需用户裁定的残余

两条**用不透明度本身表达量级**的数据视图仍是半透明，因此其最弱档位不到 3:1：

| 位置 | 当前取值 | 浅色画布合成对比度 |
| --- | --- | --- |
| 节奏日历热图格子 `statistics_usage_page.dart`（`km == 0` → 6% / `<50` → 18% / `<100` → 38% / `≥100` → 72%） | accent @ 6–72% | 零值档≈1.05:1 |
| 停放状态占比条 `statistics_parking_page.dart`（在线 accent 实色、睡眠 accent 55%、离线/未知用中性） | accent @ 55% | ≈1.88:1（深色≈3.11:1） |

未在本票改动的原因：这两处的**色阶本身就是数据编码**，把格子/分层改成实色等于取消量级表达，属于重新设计而不是「普通柱与补能竖线改实色」；Ticket 与已确认视觉方案也只点了普通柱与补能竖线。已在 Spec §8.1 明确写出该例外，以免规则自相矛盾。热图格内 9px 文字另有既有 4.5:1 断言（`design_tokens_test.dart`）。若要求这两处也达图形 3:1，请另行裁定——那需要换编码方式（分档描边、图案或图例刻度），不是改一个 alpha。
