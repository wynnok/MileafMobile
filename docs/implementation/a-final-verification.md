# A「夜航」VA01–VA14 最终验证与验收清单

日期：2026-11-01（第二版：本轮修正后） · 分支：`codex/mileaf-v1`（本地提交，未推送） · 范围：A 视觉系统 VA01–VA14。

## 自动化结果

- `tool/flutterw analyze --no-pub`：**通过**（0 issue）。
- `tool/flutterw test --no-pub`：**357 通过、22 跳过**。跳过项为 opt-in 渲染入口、历史 C 图册（`c_gallery_render_test.dart`，已标注历史并 `skip: true`）与真机/平台类占位。
- 渲染：`docs/implementation/a-renders/overview/` 12 张；`docs/implementation/a-renders/gallery/` **132 张**（11 页 × normal/empty/missing × 浅/深 × 100/200%），按本轮最终代码重出。132 个文件哈希互不相同，66 对浅/深与 66 对 100/200% 全部不同。指纹：PNG `86f2517051b4f82852fc9602aa1da99b71fa540f7c4b8ac9bd360cb3f301a143`、源码 `5fc5dcae60586df783c324d591ec9f74f4808d3481d64c68bd2f8e0f4e36aa7f`（83 文件）。
- 双轴审查：已做三轮（Standards + Spec 各 1 个子代理并行）。第三轮固定点 `f35ed0d`：2 条硬性（构成组件名实不符、DC 占比 0% 与 `—` 并存）与 6 条判断项已修，3 条判断项保留并写明理由（见 `a-review.md` 第三轮）。
- 对比度：`test/design_tokens_test.dart` 深浅色表全部通过；触控/reduce motion/图表语义见 `test/design_components_test.dart` 与 `a-accessibility.md`。
- 双轴审查：`a-review.md`。

## VA01–VA14 清单

| 票 | 状态 | 证据 / 说明 |
| --- | --- | --- |
| VA01 token/主题/字体/品牌/图标 | 完成 | `lib/src/design/`、`assets/fonts/`、`design_tokens_test` |
| VA02 Shell/导航/外观/车辆 sheet | 完成 | `workspace_page.dart`、`appearance_shell_test` |
| VA03 共享组件/图表/状态画廊 | 完成 | `design/components/`、`design_components_test` |
| VA04 概览 A 重建 + 12 张交样 | 完成 | `overview_page.dart`、`a_overview_test`、`a-renders/overview` |
| VA05 行程列表 | 完成 | `drives_page.dart`、`a_drives_test` |
| VA06 充电列表 | 完成 | `charging_page.dart`、`a_charging_test` |
| VA07 统计总览 | 完成 | `statistics_insights_page.dart`、`a_statistics_test` |
| VA08 行程详情 | 完成 | `drive_detail_page.dart`、`a_drive_detail_test` |
| VA09 充电详情 | 完成 | `charging_detail.dart`、`a_charging_detail_test` |
| VA10 五个专题 | 完成（主路径） | 五页均改用 A token/分区；专题测试 40 项通过 |
| VA11 连接/登录/设置 | 完成 | `connection_page/session_pages/setup_page/connection_management`；38 项测试 |
| VA12 图册矩阵 | 完成（本轮重出） | 132 张：四主 Tab + 两详情 + 五专题 × 浅/深 × 100/200% × normal/empty/missing；每页每态双向断言，指纹 PNG `86f25170…` / 源码 `5fc5dcae…`；地图同意条 200%、补能空态、标签顺序三处修正均在图内 |
| VA13 可达性/对比度 | 完成（自动化） | `a-accessibility.md`；真机读屏待验 |
| VA14 回归/审查/文档 | 完成（含残余） | 357 项测试、analyze 0 issue、三轮双轴审查、`a-review.md`、本清单；legacy 视觉路径已清理；性能真机数据未测 |

## Spec §14 验收项（按可自动化部分勾选）

- [x] 深色默认；设置可切浅色/跟随系统；浅色仍保留深色 hero。
- [x] 每页最多一个深色锚点；没有彩色 tile 网格。
- [x] 五级字号、metric-md/micro、全部数字 tabular。
- [x] 4px 间距档位、0 内容圆角、两级阴影/ hero 光晕。
- [x] 主数使用 `MileafNumber`；缺失 `—`；不 shrink 到 display 以下。
- [x] 线/面积/柱/stem/微折线语法；null 断线、真实 0 保留。
- [x] 图表当前点 4 + halo 8；参照虚线；≥44 触控；语义摘要。
- [x] 电池弧 88/72；区间 18→82 不伪装成 0→82。
- [x] 概览/行程/充电/统计/两详情/专题 360×800 与 200% 主要回归。
- [x] 空态不画全零；缺失不补 0；费用不默认 CNY（A 主路径）。
- [x] 无 `Card`/`CollageTile`/`Sparkline` 在 A 页面；`collage.dart`、`data_chart.dart`、`period_chips.dart`、`data_cards.dart` 已删除，legacy 0.1/0.2 fallback 仍可用但只用 A token/组件。
- [x] `currency.amount()` 已移除：金额走 `amountValue` + `amountNote`，全仓 `rg "currency.amount\("` 为 0 命中。
- [x] 电量区间用「出发/到达」（2026-11-01 用户裁定出发在前，覆盖 §9.4 旧句），0–100 轨 + 区间段；行程详情与充电列表共用同一组件。
- [x] 充电详情电池弧 hero 全出血，其余内容保留页边距（`a_charging_detail_test.dart`）。
- [x] 双轴审查归档；残余项列明。
- [x] VA12 完整渲染矩阵：132 张。
- [ ] 真机截图、真实站点、地图底图/CRS/许可、性能、双端隔离构建（外部 gate）。

## 关键路径性能 sanity

未在真机或正式站点测量冷启动/概览/详情帧时间。代码保留 `PerformanceTrace` 入口与合成性能脚本，但本轮不宣称任何性能数字达标。外部 gate 保持。

## 残余风险

1. **专题自定义 painter**：日历/续航/停放图的语义摘要靠外层文本，未全部纳入共享图表测试。
2. **统计 legacy fallback 的体积**：`statistics_page.dart` 仍同时承载 legacy 0.1/0.2 视图与版面（采样选择已收敛为 `_Sampling`，构成条已上提，金额行未再抽）。它不在 A 主路径，遗留为 legacy 内部结构。
3. **日期胶囊定位**：`dateActionKey` 已删除，测试改为按「日期/本周/本年/起止日」标签定位；标签措辞变动会让测试失效（比 key 脆），属换取「lib 内无 seam」的取舍。
4. **地图同意条在更窄/更大字号下的余量**：240 高 + 本机字体下 200% 完整显示；320 宽 + 更强放大或更长供应商名尚无实测（`widget test` 只覆盖 360×200%）。真机字体回退仍在外部 gate。
5. **同意条按钮**：仍是 Material `FilledButton`（未换 §7.6 的 `MileafButton`），属视觉一致性判断项，未在本轮改动。
6. **补能构成的三条判定**（会话数/已知能量/已知时长）分散在三个页面，未抽共用谓词。
7. **设计文档未跟踪**：`docs/specs/visual-system-a*.md`、`docs/adr/0003-visual-direction-a.md` 按用户边界未提交；本轮对 spec 的措辞同步（§9.2/§9.4/§13.1/§13.2）只存在于工作区。

## 外部 gate（不因本轮通过而关闭）

- Android/iOS 真机字体回退（Inter + CJK）、安全区、TalkBack/VoiceOver。
- 真实站点数据、地图底图/CRS/许可/大陆网络。
- 性能与双端隔离构建的最终验收。
- 商店素材/启动图（不在本轮范围）。
