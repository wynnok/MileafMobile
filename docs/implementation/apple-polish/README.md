# Apple 质感精修（ADR0014）实施控制面

总控会话维护。设计依据见 docs/adr/0014-apple-polish.md、docs/specs/apple-polish.md、docs/specs/apple-polish-copy.md；执行合同见 docs/specs/apple-polish-delivery.md；票合同见 docs/specs/apple-polish-tickets.md。

## 冻结点

| 冻结点 | 含义 | SHA |
| --- | --- | --- |
| FP0 | AP00 完成：在途改动与设计文档两次提交已落地，集成分支已建，AP00 交付物已提交，W1 工作树已建 | 7cf8dd4（AP00 + FP0 登记） |
| FP1 | W1（AP01、AP06）合入 + 集成窗口基线补登 | c18f2fc（W1 合入） |
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

**新增 lib 源文件的两道守卫登记**（W1 合入时由总控落实，W2 起各票自查）：

1. 裸值守卫（AP01，`test/apple_polish_raw_value_guard_test.dart`）要求 `lib` 下每个扫描文件（排除 `lib/src/design/**` 与 `*.g.dart`）都有 `test/support/raw_value_baseline/<同路径>.txt`；缺失即失败，不是按 0 处理。新建文件时照既有格式补全 0 基线（照抄四条计数 + `total=0`，把 `# <路径>` 换成自己的）。
2. 文案守卫（AP06，`test/apple_polish_copy_guard_test.dart`）按 `test/support/copy_guard_baseline/` 的计数只降不升；新建文件的中文字面量必须同步登记基线，改字面量时同步下降计数。

## 工作树租约表

命令前缀：工作树内每条 tool/flutterw 命令都加 MILEAF_FLUTTER_SDK=<主仓库>/.tooling/flutter（构建另加 MILEAF_ANDROID_SDK）。依赖缓存用 cp -cR <主仓库>/.cache/pub <工作树>/.cache/ 后跑 pub get --offline 验证。不建符号链接。

| 票 | 工作树目录 | 分支 | 输入冻结点 | 状态 |
| --- | --- | --- | --- | --- |
| AP01 | （已删）…/MileafMobile-ap01 | codex/apple-polish-ap01 | FP0 | 已合入 FP1，工作树已删，分支保留 |
| AP06 | （已删）…/MileafMobile-ap06 | codex/apple-polish-ap06 | FP0 | 已合入 FP1，工作树已删，分支保留 |
| AP02 | /Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile-ap02 | codex/apple-polish-ap02 | FP1 | 待创建（W2） |
| AP03 | /Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile-ap03 | codex/apple-polish-ap03 | FP1 | 待创建（W2） |
| AP04 | /Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile-ap04 | codex/apple-polish-ap04 | FP1 | 待创建（W2） |
| AP05 | /Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile-ap05 | codex/apple-polish-ap05 | FP1 | 待创建（W2） |
| AP07 | 待登记 | codex/apple-polish-ap07 | FP2 | 待创建（W3） |
| AP08–AP13 | 待登记 | codex/apple-polish-apXX | FP3 | 待创建（W4） |

## W1 合入记录（FP1 = c18f2fc）

| 顺序 | 票 | 分支 | 票提交 | 合入提交 | 合入后测试 |
| --- | --- | --- | --- | --- | --- |
| 1 | AP01 设计基础 | codex/apple-polish-ap01 | a291a86 | 5ecc372（--no-ff） | 本票 44 通过（ap01 18 + raw_value_guard 3 + design_tokens 23）、跨页 88 通过 |
| 2 | AP06 文案基础 | codex/apple-polish-ap06 | a271e00 | 0b47551（--no-ff） | 本票 28 通过（copy 26 + copy_guard 2）、跨页 88 通过 |

集成窗口（总控，c18f2fc）：AP06 新增 `lib/src/copy/` 六个文件后，AP01 的「基线覆盖全部扫描文件」用例失败；按 AP01 守卫格式补 6 个全 0 基线。这是两票的唯一交叉影响，未改任何阈值或断言。

补丁核对：AP01 交接文末的 `test/design_tokens_test.dart` 补丁已随本票提交（`press 100→120`、图标 `16→25`），与交接 diff 逐字一致，无需重复应用；AP06 交接 §7 声明既有测试补丁为无。

合入后集成状态：`analyze` 无诊断；全量 `tool/flutterw test --no-pub` 803 通过 / 35 跳过 / 0 失败（FP0 基线 754/33；+49 通过 = AP01 21 + AP06 28，+2 跳过 = AP01 渲染入口未 opt-in）。

W1 遗留交下游的事实：AP01 `AU-AP01`（controlBorder 采纳 #7A8390/#677179，否决规格候选，已实测 ≥3:1）与 `AU-AP01-1`（深色 textSecondary 在 segmentSelected 上 4.461:1）为调色板层待办，AP01 只允许两处外观变化故未修，交后续调色板/页面票；AP06 `D1`/`D2`/`D3`（session_test 与 map_key 测试钉住的原文保持不动）与 `D2` 的「已清除 · …」改逗号拼接已随票落地；`D4`/`D6`/`D7`（命令句、period 措辞、messages 模板重复）列入待确认，交 AP14/AP15 统一。

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
