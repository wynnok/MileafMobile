# 新会话实施提示词：地图设置页视觉重排

> 用法：在新会话里把下面「提示词」整段作为第一条消息发送，并按需附加 `/implement` 或 `/implement-spec`。本文件本身只是交接说明，不是待实施方案。

## 提示词（复制以下整段）

```text
/implement

本次任务：在 MileafMobile 当前 main 上，实施已经逐份确认的「设置 → 地图」配置页视觉重排方案。当前会话是新会话，请先阅读仓库内以下四份已落盘产物，以它们为唯一方案依据，不要重新做方向评审、不要再向用户重复确认已确认项、不要凭截图另造设计语言：

1. docs/adr/0010-map-settings-visual.md（已 accepted，D5 含 2026-11-09 框架事实修正）
2. docs/specs/map-settings-visual.md（已 confirmed，含逐像素规格、状态矩阵、文案冻结词、文件落点与验收矩阵）
3. docs/specs/map-settings-visual-tickets.md（已 confirmed，MS01–MS06 与执行顺序）
4. docs/specs/user-amap-key.md 的 §8（只追加的视觉增量；§1–§7 已冻结内容不得回溯改写）

任务背景：用户在本会话前已给定一张「设置 → 地图」页面截图（已保存 + 展开「如何申请 Key」），确认了 6 项决策：整页三段统一重排；细线列表 + 留白、零新增表面；单页默认折叠；允许精简重写文案并同步教程/测试；行内化动作 + 破坏操作独立 error 行；新建 ADR 0010 + 新 Spec/Ticket、旧 Spec 只追加增量。随后逐份确认了 ADR、Spec（含 D5 修正）与 Ticket。方案阶段已结束，本会话只负责实施、验证、审查与当前分支本地提交。

严格按 Ticket 的 MS01 → MS02 → MS03 → MS04 → MS05 → MS06 顺序执行：

- MS01：新增 MileafIconName.copy；MileafDataRow 加 additive destructive 默认 false；新建 MileafCopyRow 并经 components.dart 导出；design_tokens_test.dart 图标计数 15→16（其余色板/间距/圆角/对比度断言零改动）。按 tdd skill 在可行接缝先写组件测试。
- MS02：重排 lib/src/map/map_privacy_page.dart 三段：label 眉标 + 28 段距、状态结论行、Key 摘要 MileafDataRow / 编辑表单、destructive 清除行、两个默认折叠区；两个 bool + AnimatedRotation 驱动 16px chevron（0.25→0.75，180ms，reduceMotion=0；当前 Flutter 的 ExpansionTile 不旋转自定义 trailing，不能依赖它）；绑定/控制台/隐私链接用 MileafCopyRow；绑定失败用 InlineBanner；读取中用 MileafProgressLine。保留 _save/_clear/_readBinding/_copy、PopScope、MapKeyController.status、MapConsentController 授权/撤销语义与确认弹窗。
- MS03：同步 test/map_key_page_test.dart（find.byTooltip 定位复制；补 Key 行/破坏行/折叠/URL 复制断言）；单文件先跑绿。
- MS04：重生成 test/map_key_render_test.dart 与 docs/implementation/map-key-renders/ 浅深图册，新增 privacy 展开态；更新 README 矩阵，检查异常与溢出。
- MS05：同步 docs/tutorial/amap-key-settings.md 与 docs/tutorial/amap-key-application.md 的可见文案、操作路径、截图引用；不要改写 user-amap-key.md §1–§7。
- MS06：tool/flutterw analyze --no-pub 无诊断 → tool/flutterw test --no-pub 全绿 → git diff --check → 按 code-review skill 做 Standards / Spec 双轴审查 → 在当前 main 创建本地提交（不推送、不部署、不关闭外部 gate）。

硬性边界：
- 不改 map_key.dart、map_consent.dart、map_panel.dart、settings_page.dart、tokens.dart、semantic.dart、theme.dart 的全局主题。
- 不新增任何原始色值、字号、圆角档位、阴影、动效时长或第二强调色；零新增表面（无底色容器/内容卡/阴影）。
- R2：默认首屏强调色对象 ≤2；warning/error 必带文字；触控 ≥44×44；focus 2px；200% 字号与键盘 inset 300 可达。
- Spec §7 的冻结可见词与 tooltip/Semantics label 不得失效；复制成功 SnackBar 文案与复制完整 URL 行为不变。
- 真机、真实 Key、真实底图、CRS、大陆网络、性能、双端隔离构建仍是外部 gate，不因代码与自动化完成而关闭。
- 默认用中文沟通；修改前读相关文件；保持最小改动；验证后报告；区分代码事实、已确认决定和未确认建议。

完成后请报告：改动文件、analyze/test 实际结果、渲染图册状态、双轴审查结论、本地提交 hash，以及仍未验证的外部条件。
```

## 方案交付物现状（供新会话核对）

| 文件 | 状态 |
| --- | --- |
| `docs/adr/0010-map-settings-visual.md` | 已落盘；D5 与状态行含 Spec §0 框架事实修正 |
| `docs/specs/map-settings-visual.md` | 已落盘；confirmed |
| `docs/specs/map-settings-visual-tickets.md` | 已落盘；confirmed |
| `docs/specs/user-amap-key.md` | §8 已追加视觉增量；§1–§7 未改写 |
| `docs/implementation/map-settings-visual-handoff.md` | 本文件 |
| 代码、教程、测试、渲染图册 | **均未改动**，留给新会话实施 |

## 新会话开工前的最小检查

```sh
git status --short
git branch --show-current
```

预期：当前分支为 `main`；可见的改动只应是上述 5 个文档（三份新文档 + 旧 Spec 增量 + 本交接文件）。若出现 `lib/`、`test/`、`docs/implementation/map-key-renders/` 或教程文件的改动，先查明来源再实施。

## 已确认、不要重复询问的决策

1. 整页三段统一重排，不只做红框展开区。
2. 细线列表 + 留白，零新增表面；不引入 iOS grouped-list 圆角白卡。
3. 单页，两个默认折叠区；不拆二级子页。
4. 允许精简文案；同步更新两份教程与页面测试。
5. 动作行内化；复制图标化；清除为独立 destructive `error` 细线行。
6. 新建 ADR 0010 + 新 Spec/Ticket；旧 Spec 只追加 §8 增量。
7. 品牌色、浅深双模式、token 三层、设备级 Key 与多车无关、不新增原生能力：均已由现有代码回答。

## 已知框架事实

当前 Flutter 的 `ExpansionTile` 只旋转内置默认箭头；传入的自定义 `trailing` 不会被旋转。折叠箭头必须由本页两个 `bool` + `AnimatedRotation` 驱动，详见 Spec §0 与 §6.5。

## 不在提示词里的授权

本提示词**不包含**推送、部署、改写共享历史、关闭外部 gate 或改变真机验收边界的授权；这些仍需用户逐次明确确认。
