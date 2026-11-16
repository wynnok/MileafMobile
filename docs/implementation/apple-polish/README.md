# Apple 质感精修（ADR0014）实施控制面

总控会话维护。设计依据见 docs/adr/0014-apple-polish.md、docs/specs/apple-polish.md、docs/specs/apple-polish-copy.md；执行合同见 docs/specs/apple-polish-delivery.md；票合同见 docs/specs/apple-polish-tickets.md。

## 冻结点

| 冻结点 | 含义 | SHA |
| --- | --- | --- |
| FP0 | AP00 完成：在途改动与设计文档两次提交已落地，集成分支已建，AP00 交付物已提交，W1 工作树已建 | 7cf8dd4（AP00 + FP0 登记） |
| FP1 | W1（AP01、AP06）合入 | 待登记 |
| FP2 | W2（AP02–AP05）合入，共享 API 唯一清单 | 待登记 |
| FP3 | AP07 经用户视觉裁定后冻结 | 待登记 |

## 文件与测试租约（交付手册 §3.3）

| 文件域 | W1–W2 持有者 | W3 | W4 起 |
| --- | --- | --- | --- |
| tokens、semantic、typography、motion、theme、icons、brand_mark、layout（非外壳） | AP01 | 冻结 | 只读，修正交总控 |
| layout 外壳几何、top_bar、page_bar、nav_bar、glass_surface、navigation_material、large_content_viewer、workspace_page 外壳 | AP02 | 冻结 | 只读 |
| chip_row、chip、button、icon_button、sheet、focus_ring、date_range_sheet、pull_down、selection_list | AP03 | 冻结 | 只读 |
| hero、section、metric、data_row、copy_row、fact_list、disclosure、state_view、map_frame、soc_interval、module、components 导出 | AP04 | 冻结 | 只读 |
| charts、category_bars、composition_bar、battery_arc、share_ring、sample_chart | AP05 | 冻结 | 只读 |
| number_format、copy/*、非页面文件字符串字面量、文案守卫 | AP06 | 冻结 | 页面包只改自己源文件对应的守卫基线文件 |
| 代表页文件与 _VehicleSheet | — | AP07 | 交回 AP08/AP10/AP11/AP13（行程页交 AP09） |
| 页面文件 | — | — | 按 Tickets 各票持有 |
| 跨页测试、test/support/ 既有文件、统一图册、能力迁移表 | 总控 | 总控 | 总控（AP14） |

既有测试唯一修改者见交付手册 §3.3。票会话新建测试只用 test/apple_polish_apXX_*.dart 命名，新建支撑文件只用新文件名。

## 工作树租约表

命令前缀：工作树内每条 tool/flutterw 命令都加 MILEAF_FLUTTER_SDK=<主仓库>/.tooling/flutter（构建另加 MILEAF_ANDROID_SDK）。依赖缓存用 cp -cR <主仓库>/.cache/pub <工作树>/.cache/ 后跑 pub get --offline 验证。不建符号链接。

| 票 | 工作树目录 | 分支 | 输入冻结点 | 状态 |
| --- | --- | --- | --- | --- |
| AP01 | /Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile-ap01 | codex/apple-polish-ap01 | FP0 | 已创建（W1），依赖已备 |
| AP06 | /Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile-ap06 | codex/apple-polish-ap06 | FP0 | 已创建（W1），依赖已备 |
| AP02 | 待登记 | codex/apple-polish-ap02 | FP1 | 待创建（W2） |
| AP03 | 待登记 | codex/apple-polish-ap03 | FP1 | 待创建（W2） |
| AP04 | 待登记 | codex/apple-polish-ap04 | FP1 | 待创建（W2） |
| AP05 | 待登记 | codex/apple-polish-ap05 | FP1 | 待创建（W2） |
| AP07 | 待登记 | codex/apple-polish-ap07 | FP2 | 待创建（W3） |
| AP08–AP13 | 待登记 | codex/apple-polish-apXX | FP3 | 待创建（W4） |

## AP00 交付物

- capability-map.md：A21 起呈现能力迁移。
- shared-symbols.md：跨票共享符号表（W4 签名冻结）。
- expansion-tile-classification.md：25 处 ExpansionTile 分类（说明类 16、内容类 9）。
- copy-baseline.txt：文案基线（52 文件 / 1377 行中文字符串），交 AP06 作守卫基线输入。
- before 图册：docs/implementation/apple-polish-renders/before/ 与 manifest。
- test/apple_polish_render_test.dart：before 渲染入口。
- AP00.md：交接。

## 边界

不推送、不发布 GitHub、不删除旧图册、不修改 AGENTS.md、不用 git clean 或 git reset。外部 gate #11/#16/#17 不因本地实施关闭。
