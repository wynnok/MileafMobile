# A「夜航」VA01–VA14 最终验证与验收清单

日期：2026-11-01 · 分支：`codex/mileaf-v1`（本地提交，未推送） · 范围：A 视觉系统 VA01–VA14。

## 自动化结果

- `tool/flutterw analyze --no-pub`：**通过**（0 issue）。
- `tool/flutterw test --no-pub`：**351 通过、22 跳过**。跳过项为 opt-in 渲染入口与真机/平台类占位。
- 渲染：`docs/implementation/a-renders/overview/` 12 张；`docs/implementation/a-renders/gallery/` 36 张。浅/深文件哈希逐对复核，全部不同。
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
| VA12 图册矩阵 | **部分** | 36 张覆盖四主 Tab + 两详情 + 节奏专题；五专题完整 ×12 矩阵未补齐，见 gallery README |
| VA13 可达性/对比度 | 完成（自动化） | `a-accessibility.md`；真机读屏待验 |
| VA14 回归/审查/文档 | 完成（含残余） | 351 项测试、analyze、`a-review.md`、本清单；性能真机数据未测 |

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
- [x] 无 `Card`/`CollageTile` 在 A 主路径页面（legacy fallback 除外）。
- [x] 双轴审查归档；残余项列明。
- [ ] 真机截图、真实站点、地图底图/CRS/许可、性能、双端隔离构建（外部 gate）。
- [ ] VA12 五专题完整渲染矩阵。

## 关键路径性能 sanity

未在真机或正式站点测量冷启动/概览/详情帧时间。代码保留 `PerformanceTrace` 入口与合成性能脚本，但本轮不宣称任何性能数字达标。外部 gate 保持。

## 残余风险

1. **VA12 范围**：36 张 vs 规范 132 张；详情 empty/fail、五专题其余四页未进图册。
2. **legacy 路径**：`collage.dart`/`data_chart.dart`/`period_chips.dart`/`data_cards.dart` 仍被旧站点 fallback 使用；`currency.amount()` 在 legacy/说明层仍输出括号币种。
3. **专题自定义 painter**：日历/续航/停放图的语义摘要靠外层文本，未全部纳入共享图表测试。
4. **电量区间标签**：`SocInterval` 仍用“起始/结束”，Spec §9.4 写“到达/出发”。
5. **充电详情 hero**：深色电池弧仍在 12px 内容边距内，非全出血。
6. **设计文档未跟踪**：`docs/specs/visual-system-a*.md`、`docs/adr/0003-visual-direction-a.md` 按用户边界未提交；README/AGENTS 的链接在本工作区可打开，但提交树中缺失。

## 外部 gate（不因本轮通过而关闭）

- Android/iOS 真机字体回退（Inter + CJK）、安全区、TalkBack/VoiceOver。
- 真实站点数据、地图底图/CRS/许可/大陆网络。
- 性能与双端隔离构建的最终验收。
- 商店素材/启动图（不在本轮范围）。
