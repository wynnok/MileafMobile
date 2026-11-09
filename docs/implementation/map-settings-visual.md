# 地图设置页视觉重排实施记录

2026-11-09。按 [ADR 0010](../adr/0010-map-settings-visual.md)、[视觉 Spec](../specs/map-settings-visual.md) 与 [Ticket](../specs/map-settings-visual-tickets.md) MS01–MS06 实施「设置 → 地图」的整页重排。只改呈现层与三处 additive 共享件，不推送、不部署、不关闭外部 gate。

## 改动

| 文件 | 改动 |
| --- | --- |
| `lib/src/design/icons.dart` | additive `MileafIconName.copy`：24 网格、1.5 描边、双圆角矩形（8.5–17.5 / 6.5–15.5，r2） |
| `lib/src/design/components/data_row.dart` | additive `destructive`（默认 false）；为 true 且可点击时 `title` 用既有 `colors.error`，不可点击时退回 `textFaint`，语义合成不变 |
| `lib/src/design/components/copy_row.dart` | 新建 `MileafCopyRow`：`label` + `SelectableText` + 44×44 复制图标（透明底、1px 底线、`copyText` 可与显示值不同、大字号堆叠） |
| `lib/src/design/components/components.dart` | 导出 `copy_row.dart` |
| `lib/src/map/map_privacy_page.dart` | 三段 `label` 眉标 + 28px 段距；状态结论行；Key 摘要 `MileafDataRow` / 编辑表单；destructive 清除行；两个默认折叠区（两个 bool + `AnimatedRotation` 16px chevron）；绑定值 / 控制台 / 隐私链接改 `MileafCopyRow`；读取中 `MileafProgressLine`；绑定失败 `InlineBanner` |
| `test/design_components_test.dart` | `MileafCopyRow` 五态（默认 / 按压 / 禁用 / focus / 200%）+ `destructive` 两态 |
| `test/design_tokens_test.dart` | 图标计数 15 → 16，其余断言零改动 |
| `test/map_key_page_test.dart` | `find.byTooltip` 定位复制；Key 行 / 破坏行 / 折叠默认态 / chevron 旋转 / 完整 URL 复制 / 供应商说明；补窄屏双倍字号的已保存态 |
| `test/map_key_render_test.dart`、`docs/implementation/map-key-renders/` | 浅深 × 7 态重生成（新增 `privacy` 展开态），README 矩阵同步 |
| `docs/tutorial/amap-key-settings.md`、`docs/tutorial/amap-key-application.md` | 同步可见文案、操作路径与截图引用 |
| `docs/specs/user-amap-key.md` | 只追加 §8 视觉增量，§1–§7 未改写 |

未触碰：`map_key.dart`、`map_consent.dart`、`map_panel.dart`、`settings_page.dart`、`tokens.dart`、`semantic.dart`、`theme.dart`。

## 验证（2026-11-09 本机）

- `tool/flutterw analyze --no-pub`：No issues found。
- `tool/flutterw test --no-pub`：482 通过 / 8 跳过 / 0 失败；`test/map_key_page_test.dart` 单文件先跑绿（8 例）。
- `tool/flutterw dart format --output=none --set-exit-if-changed lib test`：158 文件 0 changed。
- `git diff --check`：无输出。
- 正式渲染 14 张（浅深 × empty / saved / restart / help / privacy / large / keyboard），每态 `takeException() == null`，无 `RenderFlex` 溢出、无横向滚动。

## 实施中的裁决（Spec / Ticket 未逐字决定处）

1. **折叠区标题字号**：Spec §1「AppBar 仍是本页唯一 18px 标题」与 §3 表「`title` 18/22/600 用于两个折叠区标题」冲突。取 §1 与 ADR 0010 D1（避免四个同权标题），折叠标题用 `body` 13/600，与 `MileafDataRow` 行标题同权。
2. **R2 强调色对象计数**：默认已保存 / 折叠状态只有状态 `mapPin` 一个；编辑态为 `mapPin` + 整宽「保存 Key」。「显示/隐藏」「取消更换」是 Spec §6.2 要求保留的 `TextButton`，其 `accentStrong` 来自全局 `textButtonTheme`（本次禁止改 `theme.dart`），按 §2 色板表计入「文字链接」而非图标/实心按钮。
3. **`MileafCopyRow` 接口**：Spec §6.4 参数表写作 `value` / `copyText`，同时要求反馈沿用页面的 `_copy`。实现为 `value` + `copyText` + `onCopy(ValueChanged<String>)`：组件不自持剪贴板，页面保留唯一 `_copy` 与 SnackBar 文案，控制台行显示短域名而复制完整 URL。
4. **「重试读取配置」承载**：§6.1 只要求「error 状态文字 + 重试读取配置」，实现为一条 `showChevron` 的 `MileafDataRow`（与 §6.2 Key 行、§6.6 授权动作行同为「可点行 + chevron」），而不是整宽按钮。
5. **保存 / 清除中的进度线**：§6.1 只把 `MileafProgressLine` 归给「读取中」。为不丢失重排前就有的忙碌反馈，`busy` 时仍显示同一条 2px 进度线（无新增表面、无新增时长）。
6. **供应商说明落点**：冻结的 `user-amap-key.md` §5 要求保留供应商说明，而 §6.6 未给它新位置。首屏保持「底图授权 + 动作行」两行，供应商名写进「数据使用说明」首段（「底图由高德地图提供：…」），既不新增首屏行，也不丢语义。
7. **Key 掩码长度**：Spec §6.2 只要求「脱敏末四位」，用 `•••• aaaa` 而不是重排前的 `•••• •••• •••• aaaa`；200% 字号下旧掩码在 320 宽会把行尾撑破（`RenderFlex` 溢出 242px，已由新增测试捕获）。

## 双轴审查

Standards 与 Spec 两轴平行审查（工作树 diff，HEAD `687f8f4`）。已修：`destructive` 判色改用算出的可点击状态；两个折叠区重复的头抽成 `_fold`；chevron 转折值提为页面常量、测试改按标题定位；补签名 SHA-1 复制断言；icons 注释改为与几何一致；`copyText` 接口按 Spec §6.4 落地；供应商说明回到详情段。保留并记录：多车/设备级语义、控制器契约、`_copy` 文案与完整 URL 行为均未改。

## 仍未验证

真机、真实高德 Key、真实底图、CRS、大陆网络、性能采样、双端隔离构建仍为外部 gate，不因代码与自动化完成而关闭。
