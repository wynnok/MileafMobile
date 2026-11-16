# Apple 质感精修交付手册

2026-11-16，状态为 **accepted，待实施**。用户于 2026-11-16 确认 ADR0014 的 PD01–PD11 全部按推荐采纳，并按本手册的推荐给出实施授权（§1）。本手册是 [AP00–AP15](apple-polish-tickets.md) 的执行合同：授权、分会话方案、文件与测试租约、跨票共享符号、命令、图册、验收矩阵、交接格式与可直接粘贴的提示词。设计依据为 [ADR0014](../adr/0014-apple-polish.md)、[精修规格](apple-polish.md)与[文案规范](apple-polish-copy.md)。

## 1. 授权与启动前置

| 前置 | 状态（2026-11-16） | 内容 |
| --- | --- | --- |
| P-1 方案确认 | 已确认 | 规格 §1.4 的 PD01–PD11 全部按提议采纳，记录在 ADR0014「确认记录」与本节；是否写入 AGENTS.md 由用户决定 |
| P-2 在途改动落地 | 已授权，由总控在 AP00 执行 | 工作区里 ADR0012 F00–F12 的暂存改动、ADR0013 液态玻璃底栏、2026-11-16 概览图表头的未提交改动，在当前 `main` 上**一次提交**落地，提交说明分三段列出来源（ADR0012、ADR0013 与两份旧规格中的 ADR0014 接续说明随所在文件一起进入）；随后单独提交 ADR0014 的五份新文档。不能拆成三次的原因：已暂存的 `top_bar.dart` 引用未跟踪的 `navigation_material.dart`，`top_bar.dart`、`statistics_test.dart`、`ui_ux_u09a_test.dart` 等文件同时含有两个会话的改动，按会话拆分得不到各自可编译的提交。排除 `.dsh-tmp/`、`output/`（归属不明，保持未跟踪）与 `ios/Podfile.lock` 的三项本地插件 checksum 变动（按 F12 先例不提交，保持原样） |
| P-3 本地 Git 授权 | 已授权 | 各票在 `codex/apple-polish-apXX` 分支本地提交；总控合入集成分支 `codex/apple-polish`；AP15 完成且审查通过后由总控合入 `main` |
| P-4 外部操作 | 未授权 | GitHub 发布、推送、部署、真机安装、真实站点访问，各自单独确认 |
| P-5 旧图册处理 | 未授权 | 按 `render-archive.md` 删除更早的图册需要单独确认 |

任何会话都不得使用 `git clean`、`git reset` 整理工作区，不得丢弃他人改动。

## 2. 角色

**总控**（一个固定会话，可以是 Agent，在主仓库目录运行）负责：AP00、AP07 的冻结与用户裁定记录、AP14、AP15；维护文件与测试租约表、冻结清单、跨票共享符号表、能力迁移表、统一图册与 manifest、`test/support/` 的既有文件；创建工作树；接收各票分支或补丁并合并；处理冲突；向用户汇报方向性偏差。总控不在页面包进行中时修改该包持有的文件。

**票会话**：每张票一个独立会话、一个工作树、一个分支；只写本票持有文件；完成后写交接、本地提交并停止。

## 3. 并行模式与租约

### 3.1 隔离工作树（推荐）

1. 总控在冻结点上为每票创建工作树与分支 `codex/apple-polish-apXX`：优先使用所用 Agent 工具自带的工作树生命周期（本机既有工作树位于 `~/.codex/worktrees/`），否则 `git worktree add <目录> -b codex/apple-polish-apXX <冻结SHA>`，目录建议放在主仓库同级，例如 `/Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile-apXX`。
2. 新工作树没有被忽略的 `.tooling/` 与 `.cache/`：
   - 依赖缓存：`cp -cR <主仓库>/.cache/pub <工作树>/.cache/`（APFS 克隆，不额外占空间），然后在工作树内执行 `MILEAF_FLUTTER_SDK=<主仓库>/.tooling/flutter ./tool/flutterw pub get --offline` 验证。
   - SDK：工作树内每条 `tool/flutterw` 命令都加前缀 `MILEAF_FLUTTER_SDK=<主仓库>/.tooling/flutter`（构建另加 `MILEAF_ANDROID_SDK`），见 `docs/implementation/toolchain.md`。不建符号链接，避免出现在 `git status`。
3. 总控把每票的工作树目录、分支、输入冻结点与命令前缀写入 `docs/implementation/apple-polish/README.md` 的租约表，然后通知用户在该目录打开票会话。
4. 票会话在自己的分支上本地提交，交接后由总控合入集成分支，合入后运行该票测试与跨页测试，再通知下游。
5. 冻结点：FP0（AP00 完成，含在途改动与设计文档的两次提交）、FP1（W1 合入）、FP2（W2 合入，共享 API 唯一清单）、FP3（AP07 经用户裁定后冻结）。下一波次的工作树从对应冻结点创建。
6. 合入顺序只为减少导出文件冲突，不代表依赖：W1 为 AP01 → AP06；W2 为 AP04 → AP03 → AP02 → AP05；W4 按实际完成顺序合入无冲突的票。
7. 冲突处理：先核对双方规则与行为，在集成窗口按符号合并，跑两票测试与跨页测试；集成分支上的暂存与提交只由总控执行。
8. 票合入后由总控删除对应工作树（`git worktree remove`），删除前确认工作树内没有未合入的改动。

### 3.2 串行模式

不想并行时，所有票在主仓库目录（`codex/apple-polish` 分支）一张接一张执行，同一时间只开一个会话、只跑一个 Flutter 进程。顺序：

`AP00 → AP01 → AP06 → AP04 → AP03 → AP02 → AP05 → AP07 →（用户视觉裁定）→ AP13 → AP08 → AP09 → AP10 → AP11 → AP12a → AP12b → AP14 → AP15`

每票结束时本地提交到 `codex/apple-polish`；冻结点即对应提交。

### 3.3 文件与测试租约

| 文件域 | W1–W2 持有者 | W3 | W4 起 |
| --- | --- | --- | --- |
| tokens、semantic、typography、motion、theme、icons、brand_mark、layout（非外壳） | AP01 | 冻结 | 只读，修正交总控 |
| layout 外壳几何、top_bar、page_bar、nav_bar、glass_surface、navigation_material、large_content_viewer、workspace_page 外壳 | AP02 | 冻结 | 只读 |
| chip_row、chip、button、icon_button、sheet、focus_ring、date_range_sheet、pull_down、selection_list | AP03 | 冻结 | 只读 |
| hero、section、metric、data_row、copy_row、fact_list、disclosure、state_view、map_frame、soc_interval、module、components 导出 | AP04 | 冻结 | 只读 |
| charts、category_bars、composition_bar、battery_arc、share_ring、sample_chart | AP05 | 冻结 | 只读 |
| number_format、copy/*、非页面文件字符串字面量、文案守卫 | AP06 | 冻结 | 页面包只改自己源文件对应的守卫基线文件 |
| 代表页文件与 `_VehicleSheet` | — | AP07 | 交回 AP08/AP10/AP11/AP13（行程页交 AP09） |
| 页面文件 | — | — | 按 Tickets 各票持有 |
| 跨页测试、`test/support/` 既有文件、统一图册、能力迁移表 | 总控 | 总控 | 总控（AP14） |

| 既有测试 | 唯一修改者 | 其他票 |
| --- | --- | --- |
| `design_components_test.dart` | AP03 | AP02、AP04 以补丁提交 |
| `share_ring_test.dart`、`ui_ux_u03_test.dart` | AP05 | AP03、AP04 只运行 |
| `overview_reading_test.dart` | AP08（W2 期间由总控接收 AP05 补丁） | — |
| `ui_ux_u07_test.dart` | 总控 | AP09、AP10 以补丁提交 |
| `full_flow_test.dart`、`reading_integration_test.dart`、`reading_continuity_test.dart`、`overview_statistics_reading_test.dart`、`charging_reading_test.dart`、`charging_cost_refresh_test.dart`、`map_platform_test.dart` | 总控 | 各票只运行，失败以补丁提交 |
| Tickets 中各票列出的领域测试 | 该票 | — |

票会话新建的测试只用 `test/apple_polish_apXX_*.dart` 命名，新建的支撑文件只用新文件名（如 `test/support/hierarchy_probe.dart`、`test/support/copy_probe.dart`）。补丁放在本票交接文件末尾（统一 diff），由总控应用。冻结后的共享组件需要修改时，票会话提交最小补丁与理由给总控，由总控在集成窗口修改并通知所有受影响票复验。

### 3.4 跨票共享符号

W4 的页面文件之间存在下列 import（文件级，AP00 细化到符号）。被调用的公开类、函数与构造参数在 W4 期间签名冻结；持有票只能改内部呈现，需要改签名时交总控。

| 被调用文件（持有票） | 调用方（持有票） |
| --- | --- |
| `statistics_insights_page.dart`（AP11） | `overview_page.dart`（AP08）、`statistics_usage_page.dart`、`statistics_conditions_page.dart`、`statistics_charging_page.dart`（AP12a）、`statistics_range_page.dart`、`statistics_parking_page.dart`（AP12b） |
| `statistics_period.dart`（AP11） | `overview_page.dart`（AP08）、`charging_page.dart`（AP10）、`statistics_usage_page.dart`、`statistics_charging_page.dart`（AP12a） |
| `statistics_usage_page.dart`（AP12a，含 `StatisticsTopicNotes`） | `statistics_conditions_page.dart`、`statistics_charging_page.dart`（AP12a）、`statistics_range_page.dart`（AP12b） |
| 五个专题页（AP12a、AP12b） | `statistics_page.dart`（AP11） |
| `charging_page.dart`、`charging_detail.dart`（AP10） | `statistics_charging_page.dart`（AP12a） |
| `charging_cost.dart`（AP13） | `charging_page.dart`、`charging_detail.dart`（AP10） |
| `map/map_consent_sheet.dart`、`map/map_privacy_page.dart`（AP13） | `map/map_panel.dart`（AP09） |
| 各页面文件 | `workspace_page.dart` 外壳（AP02，W2 已冻结） |

## 4. 分会话实施方案

执行顺序按波次，不按编号：AP06 属于 W1，与 AP01 同时进行；AP07 之后必须等用户视觉裁定。

| 波次 | 会话 | 可并行 | 输入 | 输出与门槛 |
| --- | --- | --- | --- | --- |
| W0 | 总控：P-2 落地 + AP00 | 否 | 当前工作区 | 两次提交、基线报告、能力表、折叠分类、共享符号表、before 图册、租约表；FP0 |
| W1 | AP01 设计基础 | 与 AP06 并行 | FP0 | token、图标、裸值守卫 API 清单 |
| W1 | AP06 文案基础 | 与 AP01 并行 | FP0 | 格式化器、术语、比较名称、枚举标签、状态句、守卫 |
| W1 合入 | 总控 | — | AP01、AP06 | FP1 |
| W2 | AP02 导航外壳 | 与 AP03、AP04、AP05 并行 | FP1 | 外壳 API |
| W2 | AP03 控件与弹层 | 并行 | FP1 | 控件 API |
| W2 | AP04 内容语法 | 并行 | FP1 | 内容组件 API、层级探针 |
| W2 | AP05 图表语法 | 并行 | FP1 | 图表 API |
| W2 合入 | 总控 | — | AP02–AP05 | FP2，共享 API 唯一清单 |
| W3 | AP07 代表页（强模型） | 否 | FP2 | 对照评审包；**停下等待用户视觉裁定**；通过后总控冻结 FP3 |
| W4 | AP08 概览 | 与 AP09–AP13 并行 | FP3 | P01 全状态 |
| W4 | AP09 行程与详情 | 并行 | FP3 | P02、P04 |
| W4 | AP10 充电与详情 | 并行 | FP3 | P03、P05 |
| W4 | AP11 统计首页 | 并行 | FP3 | P06、全部指标、期间 |
| W4 | AP12a 三个专题 | 并行 | FP3 | P07–P09 |
| W4 | AP12b 两个专题 | 并行 | FP3 | P10、P11 |
| W4 | AP13 设置、接入与表单 | 并行 | FP3 | P12–P14、P16 |
| W4 合入 | 总控 | — | W4 全部 | 集成分支包含全部页面 |
| W5 | 总控：AP14 | 否 | W4 合入 | 守卫归零、跨页与性能证据 |
| W5 | 总控：AP15 | 否 | AP14 | 构建、双轴审查、交付记录、合入 `main` |

资源有限时 W4 可分两批：第一批 AP08、AP09、AP10、AP13，第二批 AP11、AP12a、AP12b；W2 可分 AP04 + AP05 与 AP02 + AP03 两批。

需要用户介入的点：W3 代表页视觉裁定；任何票上报的方向性偏差（含首屏预算退让到第 5 步、文案含义变化）；P-4、P-5 类外部或删除操作。

## 5. 命令与图册

先核实 `pwd` 与 `tool/flutterw`，沿项目 SDK、项目依赖与进程沙箱执行，不改 HOME、不做全局安装。工作树内的命令按 §3.1 加 `MILEAF_FLUTTER_SDK` 前缀。

```sh
pwd
git status --short
git rev-parse HEAD
./tool/flutterw analyze --no-pub
./tool/flutterw test --no-pub test/<本票测试>.dart
./tool/flutterw test --no-pub
./tool/flutterw dart format --output=none --set-exit-if-changed <本票改动的 Dart 文件>
git diff --check
```

文案基线抽取（AP00、AP06 使用，只读）：

```sh
grep -rnP "'[^'\n]*[\x{4e00}-\x{9fff}][^'\n]*'" lib/src lib/main.dart --include='*.dart' \
  | grep -v '\.g\.dart' | grep -vP '^\S+:\d+:\s*//' | cut -d: -f1 | sort | uniq -c
```

正式渲染：AP00 与 AP07 使用 `test/apple_polish_render_test.dart`，页面包使用本票的 `test/apple_polish_apXX_render_test.dart`。字体路径先核验，Inter 与中文回退字体分别记录，沿 `test/support/render_fonts.dart` 的身份校验。

```sh
./tool/flutterw test --no-pub test/apple_polish_apXX_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/apple-polish-renders/APxx \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

既有 U04–U11 矩阵入口的 define 名称以源码为准（例如 `MILEAF_U08_RENDER_OUTPUT`、`MILEAF_U09A_RENDER_OUTPUT`、`MILEAF_U10_RENDER_OUTPUT`）。

- 图册根目录：`docs/implementation/apple-polish-renders/`，子目录 `before/`、`components/`、`review/`、`APxx/`、`motion/`。旧代图册的删除按 P-5 单独确认。
- 文件名：`<票>-<页面>-<场景>-<材质>-<浅深>-<宽>x<高>-<字号>-<机位>.png`，例如 `AP08-overview-normal-glass-light-390x844-100-top.png`。
- manifest 字段：输入 commit 或冻结点、夹具、时区、采样时刻、字体路径与哈希、尺寸、安全区、键盘、DPR、材质与偏好、图像哈希。
- 双端构建前读取 `docs/implementation/build-isolation.md` 与 `toolchain.md`。Android：`MILEAF_HOST_ANDROID_SDK=<host sdk> ./tool/flutterw build apk --release --split-per-abi --no-pub`；iOS：按 U12 记录的项目级 CocoaPods 环境执行 `./tool/flutterw build ios --release --no-codesign --no-pub`。设备安装、运行与驱动入口保持受保护，不绕过。

## 6. AQ00–AQ10 验收矩阵

| ID | 本地可验要求 | 必需证据 | 主要票 |
| --- | --- | --- | --- |
| AQ00 基线与能力 | 基线可复现；104 项 + A11–A20 + A21 起新能力均有当前入口、目标归宿、测试与持有票；折叠分类与共享符号表完整 | 输入 SHA、能力表、before manifest、AU25 归因结论 | AP00 |
| AQ01 设计基础 | R22 角色值、R23 两级文字与对比矩阵、`controlBorder` ≥3:1、R24 形状与发丝线、M 参数集中声明、NoSplash、裸值守卫 | token 测试、对比实测表、角色与图标图板 | AP01 |
| AQ02 组件 | 每个共享组件八种状态（无意义记 N/A）、浅深、100/200%、320/768 | 组件图板与 widget 测试 | AP01–AP05、AP07 |
| AQ03 全页视觉 | P01–P16 全状态、浅深、100/130/150/200%、320/360/390/430/768、safeArea=0；首屏实测；层级探针每机位 display 与 metricLg 各 ≤1；逐张目视清单 | 正式 PNG、几何 JSON、探针结果、目视清单与差异处理 | AP07–AP13 |
| AQ04 动效 | M01–M12 的 0ms、中间帧、终态；连续输入、取消、运行中开启减少动效；隐藏 Tab 与覆盖路由 ticker 停止 | widget 时间采样与逐帧图板；平台手势另列设备录像（AQ10） | AP02–AP05、AP07、AP14 |
| AQ05 行为 | S01–S08、请求类型与参数、旧契约、写入恢复不变；合并刷新只等价触发原两个回调 | 既有核心测试与新增回归、HTTP 事件序列 | 全部页面票、AP14 |
| AQ06 阅读与焦点 | 跨 Tab、详情、证据、费用、刷新后的滚动、选点、已加载页与焦点恢复；末项与焦点不被外壳和底栏遮挡 | 实际点击、滚动、selected ID 与遮挡断言 | AP02、AP05、AP07–AP14 |
| AQ07 无障碍 | 语义顺序、标签句子化、字号矩阵、大内容查看器、封顶范围仅限 R26 所列、减少动效、减少透明度、高对比 | 语义树、注入偏好测试、对比实测 | AP01–AP05、AP13、AP14 |
| AQ08 文案 | 守卫全局为 0；每页前后对照表；冻结文案逐字未变；渲染树无 snake_case 与「·」拼接的界面文案；日期全部来自共享格式化器 | 守卫与 probe 测试、对照表、冻结文案 diff 为空 | AP06、AP08–AP13、AP14 |
| AQ09 工程与开发期性能 | analyze 无诊断；格式；全量测试与 skip 明细；diff 检查；双端隔离构建；沿 ADR0012 Q08：每 route blur 区域数、外壳滚动只重建自身、ticker 隔离，具备设备时做前后 profile 对照 | 完整命令、退出码、数量、产物路径与哈希、性能检查记录 | AP14、AP15 |
| AQ10 外部 | 真机字体、键盘、读屏、减少透明度与高对比真实映射、真实地图与 CRS、设备性能（每平台每指标 ≥30 样本、既有 p95 预算）、整机与真实站点 | 继续由 #11、#16、#17 承载，本轮不关闭 | — |

### 6.1 视觉机位

- 代表页（AP07）：360×800 浅深 × 100/200%；390×844 浅深 × 100%；320×568 浅 × 100%；768 宽浅 × 200%；每页首屏与一屏下滚。
- 页面包：在代表机位基础上补 430 宽、130/150%、safeArea=0，以及本页全部数据状态（完整、空、首次加载、失败、有旧数据刷新、局部失败、能力回退）与本页特有状态。
- 外壳：滚动 0/8/16/100 四个机位；底栏与顶栏在黑、白、主蓝、交错文字背景及实色、减少透明度、高对比、模态覆盖下各一。

### 6.2 动态检查

M02 加反向与连续三次点击；M03 加滚动中途切换减少动效；M05 加打开关闭竞争与提交中关闭锁定；M06 检查阅读锚点不跳；M07 覆盖横拖、纵拖、首末点、键盘与语义步进、触觉只在索引变化时触发；M10 覆盖长按出现、移出消失、抬手切换。中间帧不得出现跳位、双选中、错误命中区。

## 7. 交接格式

每票在 `docs/implementation/apple-polish/APxx.md` 写以下内容，事实、用户决定、待确认项分别标注：

1. 票号、会话、模型、日期、输入冻结点与 SHA、分支与工作目录、结果 SHA。
2. 实际修改文件清单；新增与变更的公开符号（API 差异）；是否触及冻结符号（应为否）。
3. 规则映射表：R/M/P/CP/S 条目 → 符号 → 测试 → 图像或动态证据路径。
4. 能力迁移：本票涉及的能力原入口、新入口、测试。
5. 文案前后表：文件:行、原文、新文、规则；冻结文案确认未改。
6. 命令与结果：完整命令、退出码、通过/跳过/失败数量，失败的归因与处理。
7. 既有测试的等价修正或补丁清单：文件:用例、原断言、新断言、原因、提交给谁；补丁附在文末。
8. 偏差账本：规则 ID、触发样例、测量、最小修订、影响，是否已交总控或用户。
9. 未验证与外部待验项。
10. 临时资源：路径、用途、是否已清理；下一票需要的输入。

## 8. 提示词

三类会话、四段提示词。复制时只改尖括号里的内容。

### 8.1 总控·开局（W0，在主仓库目录打开）

```text
你是行笺「Apple 质感精修」的总控会话，工作目录是主仓库
/Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile（main 分支）。
用户已于 2026-11-16 确认 ADR0014 的 PD01–PD11，并按交付手册 §1 授权 P-2、P-3（P-4、P-5 未授权）。
先读：AGENTS.md、docs/adr/0014-apple-polish.md、docs/specs/apple-polish-delivery.md 全文、
docs/specs/apple-polish-tickets.md 的 §1、§2 与 AP00、docs/specs/apple-polish.md 的 §1、§2、§6、R30。
然后依次执行：
1. 记录 pwd、HEAD、git status --short；不改文件，运行 ./tool/flutterw analyze --no-pub 与全量测试，确认在途改动合并后是绿的；不绿就停下汇报。
2. 按交付手册 §1 P-2 落地：排除 .dsh-tmp/、output/、ios/Podfile.lock 与五份 ADR0014 新文档后，把其余在途改动（已暂存、未暂存、未跟踪）做一次提交，提交说明分三段列出 F00–F12、液态玻璃底栏、概览图表头；再单独提交五份新文档（docs/adr/0014-apple-polish.md、docs/specs/apple-polish.md、apple-polish-copy.md、apple-polish-tickets.md、apple-polish-delivery.md）。每次提交前用 git diff --cached --stat 核对范围。
3. 从第二次提交创建集成分支 codex/apple-polish，完成 AP00 其余动作，写 docs/implementation/apple-polish/README.md（含租约表）与 AP00.md，登记 FP0 并本地提交。
4. 先把 W1 的 AP01、AP06 写入租约表并提交，再按交付手册 §3.1 从该提交创建两个工作树、准备依赖，然后停下，告诉我两个工作树目录和下一步要开的会话。
不推送，不发布 GitHub，不删除旧图册，不修改 AGENTS.md，不用 git clean 或 git reset。
```

### 8.2 票会话（AP01 起每张票一个新会话，在租约表登记的工作树目录打开）

```text
你负责行笺「Apple 质感精修」的 <APxx>。
先读 AGENTS.md 与主仓库里的租约表 /Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile/docs/implementation/apple-polish/README.md，核对本票的工作目录、分支、输入冻结点与命令前缀；
若当前目录或分支与租约表不符，停下告诉我，不要在别的目录改代码。
再读 docs/specs/apple-polish-delivery.md §8.5 表格中本票的「必读」，以及 docs/specs/apple-polish-tickets.md 的 §2 与 <APxx> 一节、
docs/implementation/apple-polish/ 下前置票的交接。
严格按本票合同实施：只写本票持有文件、test/apple_polish_<apxx>_*.dart 与本票源文件对应的守卫基线文件；
先写测试再实现；S01–S08、所有 Key、回调、路由与冻结的跨票符号签名不变；文案只按 apple-polish-copy.md，冻结文案一字不改。
运行本票测试、analyze、格式检查与 git diff --check，需要的正式渲染按交付手册 §5 输出；
按交付手册 §7 写 docs/implementation/apple-polish/<APxx>.md，在本票分支本地提交，不推送。
遇到持有范围外的修改、首屏预算退让到第 5 步、方向性偏差或冻结文案，记录证据后停下汇报。
```

### 8.3 总控·合入与开下一波（每个波次全部票交接后，在主仓库目录）

```text
你是行笺「Apple 质感精修」的总控。读 AGENTS.md、docs/specs/apple-polish-delivery.md 与 docs/implementation/apple-polish/README.md。
已完成交接的票：<例如 AP01、AP06>。
按交付手册 §3.1 把它们的分支依次合入 codex/apple-polish（顺序见第 6 点），每合入一个运行该票测试与跨页测试；
应用各票交接里的测试补丁；登记冻结点 <FP1/FP2/…>；删除已合入的工作树；
先更新租约表并提交，再从该提交为下一波次创建工作树、准备依赖，然后停下，告诉我下一波要开的会话与对应目录。
不推送，不发布 GitHub。
```

### 8.4 总控·记录视觉裁定（AP07 停下并给出评审包之后）

```text
你是行笺「Apple 质感精修」的总控。AP07 代表页的视觉裁定：<通过 / 逐条修改意见>。
把裁定写入 docs/implementation/apple-polish/AP07.md（是否同步到 AGENTS.md 由我决定，不要自行修改 AGENTS.md）。
有修改意见时，交回 AP07 会话修正后再提交评审；通过时冻结 FP3（token 表、组件 API、动效参数、首屏预算、共享符号签名），
先更新租约表并提交，再为 W4 的 AP08、AP09、AP10、AP11、AP12a、AP12b、AP13 创建工作树，然后告诉我七个目录。
```

AP14、AP15 由总控按 8.3 的方式开新会话执行，提示词写「你负责 AP14（或 AP15），在主仓库 codex/apple-polish 分支执行」，其余同 8.2。

### 8.5 各票必读清单

规格指 `apple-polish.md`，文案指 `apple-polish-copy.md`。

| 票 | 必读 | 补充 |
| --- | --- | --- |
| AP00 | ADR0014；规格 §1、§2、§6、R30；Tickets §2 与 AP00；本手册全文 | 基线与登记；P-2 按 §1 一次提交在途改动、再提交设计文档 |
| AP01 | 规格 §1.4、R21–R24、R32、§4；文案 CP03 | 旧角色保留原值；外观只允许无涟漪与输入边框两处变化 |
| AP06 | 规格 R29 的坐标规则、R31；文案全文 | 枚举与比较窗口以契约和源码为准，查不到的列入待确认 |
| AP02 | 规格 §1.4 的 PD01、PD05、R26、R28、§4 的 M03、M10；ADR0013 | 滚动只重建外壳；L09 修订引用 ADR0014 |
| AP03 | 规格 R23、R24、R27、R28、§4 的 M01、M02、M05 | 日期区间弹层不内置任何页面的业务校验 |
| AP04 | 规格 R21–R25、R30、R31、§4 的 M06、M11 | 单位永不单独成行；折叠动画保持阅读锚点 |
| AP05 | 规格 R21、R29、§4 的 M07、M09；文案 CP04 的 DF9、CP11 | 读数头位置变化不改变默认选点与朗读来源 |
| AP07 | 规格全文；文案中概览、行程、统计首页、充电详情、设置的对照表 | 交付对照包后停下，等待用户逐项裁定 |
| AP08 | 规格 R21、R25、R29、R30、§5 的 P01、§6；文案 CP02–CP09 与概览表 | 跨页测试只运行；比较函数签名冻结 |
| AP09 | 规格 R25、R27、R29、R30、§5 的 P02、P04、§6；文案行程与行程详情表 | 地图授权与生命周期不动；对照电量保留折叠行 |
| AP10 | 规格 R25、R27、R29、R30、§5 的 P03、P05、§6；文案充电与充电详情表 | 费用补录表单属 AP13；被 AP12a 调用的符号签名冻结 |
| AP11 | 规格 R25、R27、R29、§5 的 P06、P15、§6；文案统计首页表 | 被多票调用的符号签名冻结 |
| AP12a | 规格 R25、R29、R30、§5 的 P07–P09；文案 CP10 与专题表 | 温度组分段保留；`StatisticsTopicNotes` 签名冻结 |
| AP12b | 规格 R25、R29、R30、§5 的 P10、P11；文案 CP10 与专题表 | 停车记录逐行明细保留原位 |
| AP13 | 规格 R24、R27、R28、§5 的 P12–P14、P16；文案 CP12 与设置表 | 冻结文案一字不改；币种保持推入页面 |
| AP14 | 本手册全文；规格 §4、§7 | 删除旧别名前确认全仓无调用；列出旧版更好的点 |
| AP15 | 本手册 §1、§5、§6、§9 | 双轴审查与 Hallmark 收尾评审各用独立上下文；构建产物不等于设备验收；通过后合入 `main` |

## 9. 审查与完成

- Standards 轴检查组件复用、token 与守卫、命中尺寸、焦点、语义、资源边界；Spec 轴逐条核对 R21–R32、M01–M12、P01–P16、CP01–CP12、S01–S08 与本次设计目标。审查必须对照同条件图像与动态证据，未观察的部分列为未验证。
- Hallmark 收尾评审（app scope）：独立上下文只拿 before/after 图与规格，回答「重心是否唯一、层级是否清楚、秩序是否一致、文案是否明确、旧版哪里更好」，结论以 `ship`、`fix` 或 `rebuild` 开头；修正由原持有票完成。`sloplint` 只解析 Web 文件，对 Dart 不适用，以 analyze、守卫测试与正式渲染替代，记录为 waive。
- 完成交付包括全部票交接、冻结清单与 token 表、能力迁移表、AQ 矩阵、单一新图册与 manifest、工程与构建与审查结果、外部待验清单；Git 最终状态与基线比对，交付物与项目依赖保留，工作树与临时资源按 cleanup-session-dev-resources 处理。

## 10. 本轮文档核验

2026-11-16 本设计会话完成：当前工作区源码阅读（设计层、外壳、主要页面与页面间 import）、全部中文界面字符串清点（1377 行）、当前工作区正式渲染重新采集（U04–U11 与代表图，约 1230 张，输出在系统临时目录，已清理）、Apple 公开资料检索（HIG 页面在本环境无法直接读取，依据为 WWDC 视频页与公开报道，见 ADR0014）。文档经独立的 Standards 与 Spec 两轴审查，发现的问题已修订。同日用户确认方案并授权 P-2、P-3。本设计会话未修改产品代码与测试，未暂存、未提交、未发布；P-2 的提交由总控在 AP00 执行。
