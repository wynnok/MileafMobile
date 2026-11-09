# 地图设置页视觉重排实施任务（Ticket）

- 日期：2026-11-09
- 状态：confirmed（用户已确认本 Ticket；本会话只交付方案，实施另开新会话）
- 依据：[ADR 0010](../adr/0010-map-settings-visual.md)、[地图设置页视觉 Spec](map-settings-visual.md)、[自备高德地图 Key Spec](user-amap-key.md) §8 视觉增量。
- 边界：只改呈现层与少量 additive 共享件；不推送、不部署、不改共享历史、不提前关闭外部 gate。

## 任务拆分

| 编号 | 文件与模块 | 改动 | 验收标准 | 依赖 |
| --- | --- | --- | --- | --- |
| MS01 共享细线件 | `lib/src/design/icons.dart`、`lib/src/design/components/data_row.dart`、新建 `lib/src/design/components/copy_row.dart`、`components.dart`、`test/design_tokens_test.dart` | 新增 `MileafIconName.copy`（24 网格 / 1.5 描边，双圆角矩形）；`MileafDataRow` 加 `destructive` 默认 false（title 用既有 `colors.error`，不改 semanticLabel）；新建 `MileafCopyRow`（label + `SelectableText` + 44×44 `MileafIconButton`，透明底、1px 底线、大字号堆叠）；`components.dart` 导出；图标计数断言 15 → 16 | `analyze` 无诊断；`design_tokens_test.dart` 绿且色板 / 间距 / 圆角 / 对比度断言零改动；`MileafCopyRow` 有 default / press / disabled / focus / large 五态测试；现有多个 `MileafDataRow` 调用方行为不变（`destructive=false`） | 无 |
| MS02 地图页三段重排 | `lib/src/map/map_privacy_page.dart` | 删除 `stretch`；三段 label 眉标 + 28px 段距；状态结论行（`mapPin` + `status` + micro + `warning` / `error` / progress）；已保存态 Key 改 `MileafDataRow` 摘要行（badge 脱敏 + chevron），编辑 / 未配置态保留 `TextField` + 唯一 `FilledButton` + 左对齐取消；清除改 destructive 细线行 + 原确认弹窗；申请帮助与数据使用说明两个折叠区，两个 bool + `AnimatedRotation` chevron（0.25 → 0.75，180ms，reduceMotion=0）；帮助内三条 `_StepRow`、绑定 / 控制台 / 隐私链接改用 `MileafCopyRow`、读取失败 `InlineBanner`；隐私首屏只留授权状态行 + 动作行，长说明入折叠。`_save/_clear/_readBinding/_copy`、`PopScope`、控制器契约、`MapKeyController.status` 不变 | 首屏无整宽「更换 Key」「重新启用地图」与居中蓝色文字按钮；R2 强调色对象 ≤2；Spec §4 逐像素间距、§6 状态矩阵、§7 文案冻结词逐项成立；浅深两模式、320@200%、键盘 300 无溢出与横向滚动；`MapConsentController` 授权 / 撤销路径不变 | MS01 |
| MS03 页面测试与语义 | `test/map_key_page_test.dart`、必要时 `test/design_components_test.dart` | `find.text('复制包名')` → `find.byTooltip('复制包名')`；新增 Key 摘要行点击进编辑、破坏行文案与 error 语义、两个折叠区默认收起 / 展开后绑定值可见、chevron 旋转、复制完整 URL、隐私详情收起时链接不可见；保留原五组回归（速写进入、保存返回、读取失败、iOS 保存失败、窄屏大字） | `tool/flutterw test --no-pub test/map_key_page_test.dart` 绿；所有冻结定位词可被 `byTooltip` / `byText` 找到；复制结果仍为 `app.mileaf.example` / SHA-1 / 完整控制台 URL；`takeException()==null` | MS02 |
| MS04 正式渲染与图册 | `test/map_key_render_test.dart`、`docs/implementation/map-key-renders/`、`docs/implementation/map-key-renders/README.md` | 浅深 × 6 态重生成；新增 `privacy` 态（隐私详情展开）；help 态改为展开后的新键值行；README 更新矩阵与命令；合成 Key 与绑定值不变 | 每态 `takeException()==null`，无 `RenderFlex` overflow；图册数量与 README 表格一致；浅深各含 empty / saved / restart / help / privacy / large / keyboard；截图肉眼可见三段眉标、细线、44 图标、无居中蓝按钮 | MS02、MS03 |
| MS05 教程与文档收口 | `docs/tutorial/amap-key-settings.md`、`docs/tutorial/amap-key-application.md`、`docs/specs/user-amap-key.md`（已追加 §8）、`docs/adr/0010-map-settings-visual.md`（已修正 D5）、`docs/specs/map-settings-visual.md`（已落盘） | 教程改「点击 Key 行更换」「点击右侧复制按钮」「展开数据使用说明」；常见情况表更新；截图文件名与图册保持一致；不改写 `user-amap-key.md` §1–§7 | 全文无「点击更换 Key」「点击复制包名」「居中链接」等旧动作描述；所有教程相对链接与图册文件存在；Spec 冻结词与教程一致 | MS04 |
| MS06 全量验证、审查、提交 | `tool/flutterw analyze --no-pub`、`tool/flutterw test --no-pub`、`/code-review`、当前 `main` 本地提交 | 先单文件 MS03，再全量；双轴审查（Standards / Spec）；`git diff --check`；本地 commit（不 push） | analyze 无诊断；全量 test 0 失败；code-review 无未结硬性问题；提交信息说明本次仅改呈现层；工作树干净；未触碰 `map_key.dart` / `map_consent.dart` / `map_panel.dart` / `settings_page.dart` / `tokens.dart` / `semantic.dart` / `theme.dart` | MS01–MS05 |

## 执行顺序

`MS01 → MS02 → MS03（单文件先跑）→ MS04 → MS05 → MS06`

TDD 接缝：MS01 的 `MileafCopyRow` 与 `copy` 图标先写组件测试；MS03 在 MS02 落地前同步补断言。每完成一票跑 `analyze` 或对应单文件；MS06 最后跑一次全量测试与双轴审查。

## 不在本 Ticket 范围

- 真机、真实 Key、真实底图、CRS、大陆网络、性能采样、双端隔离构建：均为既有外部 gate。
- 不改设置首页入口行、不改速写入口、不改原生桥、不改任何数据语义。
- 不推送、不部署、不改变共享历史。

## 会话交接

用户已明确：本会话只交付 ADR / Spec / Ticket 三份方案，实施在**新会话**用 `implement` / `implement-spec` 进行。新会话提示词见 [docs/implementation/map-settings-visual-handoff.md](../implementation/map-settings-visual-handoff.md)。
