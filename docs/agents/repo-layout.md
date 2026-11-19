# 仓库结构与文档约定

本文件回答一个问题：**什么东西应该放在哪里，什么不该进仓库。** 2026-11-19 按当时工作区实况核对过一次（同日的清理记录见 [repo-structure.md](../implementation/repo-structure.md)）。

## 1 顶层条目

只允许出现下表的内容。新增顶层目录前先问：它是否可由某条命令重建、是否是外部仓库、是否属于用户私有工作区；三者都不是才考虑入库，并同步本表与 `AGENTS.md`。

| 条目 | 类型 | 说明 |
| --- | --- | --- |
| `AGENTS.md` | 入库 | 代理与协作者规则：当前状态、硬约束、工作流；历史进 `docs/agents/history.md` |
| `README.md` | 入库 | 对外项目说明与阅读顺序 |
| `LICENSE` | 入库 | AGPL-3.0 |
| `.gitignore` | 入库 | 忽略规则，见 §2 |
| `.metadata`、`analysis_options.yaml`、`pubspec.yaml`、`pubspec.lock` | 入库 | Flutter 工程与静态检查、依赖锁 |
| `lib/` | 入库 | 应用源码，见 §3 |
| `test/` | 入库 | 测试与 opt-in 渲染入口，见 §4 |
| `assets/` | 入库 | 字体、图标等打包资源 |
| `android/`、`ios/` | 入库 | 原生工程（Gradle wrapper、Podfile.lock 已单独放行） |
| `config/` | 入库 | 配置样例；`*.local.env` 与高德 `AMap.local.xcconfig` 本地密钥不入库 |
| `docs/` | 入库 | 决策、规格、实施、产品、契约、教程、代理约定，见 §6 |
| `tool/` | 入库 | `flutterw` 与构建沙箱、契约生成与性能数据脚本，见 §5 |
| `build/` | **忽略** | 可重建产物；整目录可删（`test_cache`、Gradle 中间件、APK、临时出图） |
| `.cache/` | **忽略** | 项目内 pub / Gradle / CocoaPods 缓存、隔离日志、历史清单（约 17 GB，可重建） |
| `.tooling/` | **忽略** | 项目内 Flutter SDK 与 Android SDK（约 7.5 GB，见 toolchain 记录） |
| `.dart_tool/` | **忽略** | `pub get` 解析结果（可重建） |
| `.dsh-tmp/` | **忽略** | 代理临时工作区：日志、一次性脚本、补丁草稿；**随时可整目录删除** |
| `MileafServer`、`teslamate` | **忽略** | 外部仓库的只读符号链接，只在本机存在；克隆后缺失属正常 |
| `creator/` | **忽略** | 用户私有创作/宣传工作区，永不入库、不改动 |
| `.hallmark/` | **入库（历史遗留）** | 技能运行状态 `log.json`、`preflight.json`，2026-11-19 前已随提交入库；清理需单独授权 |

约定：

- 生成物、缓存、SDK、临时出图**不进版本库**，也不出现在 `git status` 里（规则在 `.gitignore` 末尾「Mileaf 本地工具链、缓存与外部参考仓库」与「Agent scratch」两段）。
- 文档引用 `.dsh-tmp/` 下的路径时，把它当「当时的工作稿」：文件可能已被清理，正式结论必须落在 `docs/` 里。
- 顶层出现表外条目时，先判断是否属于上表某一类再做决定；不要为了「整齐」移动入库目录。

## 2 忽略与清理

| 目录 | 可删？ | 重建方式 |
| --- | --- | --- |
| `build/` | 是，随时 | `tool/flutterw test` / `tool/flutterw android assembleRelease` 自动重建；口径见 [build-directory.md](../implementation/build-directory.md) |
| `.dart_tool/` | 是 | `tool/flutterw pub get` |
| `.cache/` | 谨慎（会重新下载 SDK/Gradle/CocoaPods 依赖） | 各缓存随命令重建 |
| `.tooling/` | 否 | 项目内 Flutter/Android SDK，删除后需按 [toolchain.md](../implementation/toolchain.md) 重新准备 |
| `.dsh-tmp/` | 是 | 无需重建；代理按需临时创建 |

清理 `build/` 时保留 `build/releases/`（本机交付物，例如给真机验证的 APK）属于可接受的例外：它是忽略目录里的单文件，不随提交进入仓库。

## 3 `lib/` 分层

```
lib/
├── main.dart                  # 唯一入口
└── src/
    ├── design/                # 设计系统（唯一允许出现颜色/字号/间距/圆角/动效取值的地方）
    │   ├── tokens.dart        #   色板、间距档位、圆角、动效时长
    │   ├── semantic.dart      #   MileafColors、语义色相（MileafHue / 数据域）
    │   ├── theme.dart         #   ThemeData 组装与明暗模式
    │   ├── typography.dart    #   字号阶梯与字体角色
    │   ├── layout.dart        #   版心、卡片内边距、栅格
    │   ├── motion.dart        #   动效曲线与时长引用
    │   ├── icons.dart         #   图标家族（MileafIconName）
    │   ├── brand_mark.dart    #   叶标
    │   ├── display_preferences.dart
    │   └── components/        #   共享组件（34 个文件，经 components.dart 桶文件导出）
    ├── copy/                  # 全部面向用户的文案片段（日期、时长、单位、术语、状态句…）
    ├── map/                   # 地图平台通道与地图页面（Android/iOS 高德）
    ├── *_page.dart            # 页面：概览、行程、充电、统计各专题、设置、连接、工作区
    ├── *_detail.dart          # 详情视图
    ├── *_contract.g.dart      # 由 docs/contracts 的 OpenAPI 生成的 DTO（勿手改）
    └── 其余单元                # api、session、workspace、currency、number_format…
```

规则：

- **颜色、字号、间距、圆角、动效数值只写进 `design/`**；页面里出现裸数值视为回归（间距守卫见 [chromatic-language.md](../specs/chromatic-language.md) CL22）。
- 面向用户的字符串先进 `copy/`；文案守卫按文件行数设基线，基线只许下降。
- 跨页面共享的视觉组件进 `design/components/` 并通过桶文件导出；页面私有组件留在页面文件内。
- `*.contract.g.dart` 由契约生成，不要手改；契约快照在 `docs/contracts/`，生成入口在 `tool/`。

## 4 `test/` 约定

- 文件名以**切片前缀**开头，便于按增量筛跑：`a_*`（A 夜航）、`apple_polish_ap*`、`ui_ux_u*`、`dm*`（Days Matter 迁移）、`chromatic_*`（色彩与图标）、`charging_*`、`statistics_*`、`overview_*` 等；其余为功能或单元测试。
- `*_render_test.dart` 是 **opt-in** 渲染入口：默认 skip，需要 `--dart-define=MILEAF_RENDER_OUTPUT=build/<切片>-renders` 才出图；图册政策见 [render-archive.md](../implementation/render-archive.md)。
- 文案守卫基线在 `test/support/copy_guard_baseline/<源文件>.txt`，按行数比对，**只许下降**；新增文案行需在实施记录里写明理由。
- 全量口径：`tool/flutterw test --no-pub`；静态分析：`tool/flutterw analyze --no-pub lib test`。

## 5 `tool/`

| 入口 | 用途 |
| --- | --- |
| `tool/flutterw` | 唯一命令入口：固定项目内 SDK、Pub/Gradle/CocoaPods 缓存；Android/iOS 原生命令走 `sandbox-exec` 探针 |
| `tool/build-sandbox.sb`、`tool/build-sandbox-probe.rb` | 构建进程隔离 profile 与继承探针（改动需重跑隔离记录） |
| `tool/generate_auth_contract.dart`、`export_contract_fixtures.py` | 从冻结 OpenAPI 生成/复现 DTO |
| `tool/performance/` | 性能样本数据生成器与测量协议（独立 Python 环境） |

## 6 `docs/` 子目录

| 目录 | 放什么 | 命名约定 |
| --- | --- | --- |
| `adr/` | 架构与设计决定，一项决定一份 | `NNNN-kebab-title.md`，4 位序号只追加；索引见 [docs/adr/README.md](../adr/README.md) |
| `specs/` | 可验收的条款（R/P/S/G、CL、MG、L…），含 tickets 与 delivery 手册 | `<主题>.md`、`<主题>-tickets.md`、`<主题>-delivery.md` |
| `implementation/` | 实施与验证记录、审查、图册、分包记录 | `<切片>.md` + `<切片>-renders/`；索引见 [README.md](../implementation/README.md) |
| `product/` | 产品范围、体验基线、可视化需求、扩展提案、方向评审 | 用途命名 |
| `contracts/` | 冻结的 OpenAPI 与来源元数据 | `openapi-<域>-<版本>[-source].json` |
| `tutorial/` | 面向用户的教程（高德 Key 申请与设置） | 用途命名 |
| `agents/` | 代理约定：issue tracker、triage、领域文档、仓库结构、历史日志 | `<主题>.md` |
| `prototypes/` | 设计原型与其自带评审图（被 ADR/Spec 引用的设计原文） | `<方向>/` |

新增文档时同步三处索引：`docs/README.md`、`docs/adr/README.md`、`docs/implementation/README.md`。

## 7 一个切片的落地顺序

1. **ADR**（若改变长期规则）：`docs/adr/NNNN-*.md`，写清决定、取舍与被拒方案。
2. **Spec**：条款编号（前缀取未使用的两三个字母），每条可验收；跨文档引用用编号。
3. **Tickets**：`*-tickets.md` 写任务图、写作用域、多会话提示词与并行度。
4. **实施**：代码 + 测试；页面级改动在实施记录里做逐页登记。
5. **实施记录**：`docs/implementation/<切片>.md`，含结论、取像素实测、双轴审查与遗留；需要分包时写 `<切片>/<分包>.md`。
6. **图册**：opt-in 渲染入口 + `<切片>-renders/`；按 render-archive 政策保留「当前一代 + 上一代」。
7. **索引与历史**：更新三处索引，在 `docs/agents/history.md` 追加一条。

## 8 当前已知偏差与待确认建议

现状（代码事实）：

- `docs/implementation/` 有 74 份记录 + 33 个子目录，**平铺**在同一层；索引 [README.md](../implementation/README.md) 按主题分组解决导航，但物理分层尚未做。
- 图册共约 4381 张 PNG / 539 MiB，其中 `ui-ux-refinement-renders/`（1850 张 / 214 MiB）与 `apple-design-renewal-renders/`（1057 张 / 125 MiB）是两代已被 ADR 0014/0016 取代的整册。
- 根目录 `GLOSSARY.md` 尚未建立，`docs/agents/domain.md` 与 `AGENTS.md` 已按「按需创建」表述。
- 顶层 `.hallmark/` 是已被跟踪的技能运行状态（2 个小文件），与「临时区不入库」的口径不一致，属历史遗留。

未确认建议（需要用户表态后才执行）：

1. 把 `docs/implementation/` 按 `delivery/`、`product/`、`design/`、`renders/` 物理分层——需要同步改写数千条相对链接，风险与收益都要先评估。
2. 按 render-archive 政策再归档两代旧整册（可回收约 340 MiB 工作区体积，`.git` 历史不变）。
3. 建立 `GLOSSARY.md`（站点、会话、车辆、充电会话、区间、口径等术语），供代理与新人统一用词。
