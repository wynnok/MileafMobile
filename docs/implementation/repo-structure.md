# 仓库结构梳理（2026-11-19）

## 结论

多会话、多代理并行实施后，仓库出现三类结构问题：**顶层混入工具/代理工作目录**、**`build/` 反复堆积**、**文档索引缺失且长期记录塞在 `AGENTS.md` 里**。本次做了一次只读盘点 → 清理未跟踪垃圾 → 补齐索引与结构约定 → 修正文档死链，代码与测试未改动。

- 基线提交：`4bead60`（多彩语言重构），工作树干净。
- 本次不改任何 `lib/`、`test/`、`android/`、`ios/` 源文件；不删除任何**已入库**文件（图册与历史记录原样保留）。
- 结果：`git status` 只包含本次新增/修改的文档与 `.gitignore`；顶层回到「项目目录 + 两个只读符号链接 + 用户私有 `creator/`」。

## 盘点

| 项 | 事实 |
| --- | --- |
| 顶层条目 | 30 个（含隐藏）：项目目录 + `.git`、`.cache`（17 GB）、`.tooling`（7.5 GB）、`.dart_tool`（1.3 GB）、`build`（863 MB）、`.dsh-tmp`、`.hallmark`、`.claude`（空）、`.flutter-plugins-dependencies`、`.DS_Store` |
| 仅由用户手工添加 | `creator/`（已 `/creator/` 忽略）与两个外部仓库符号链接 `MileafServer`、`teslamate` |
| `build/` | 12 项 863 MB：`app` 644 MB、`test_cache` 104 MB、`jni`、各插件中间件、`mc10` 临时出图、`reports`；另含交付给真机的 APK（`build/releases`） |
| `docs/` | 4792 文件 / 558 MB：`implementation` 539 MB（清理前 74 个 Markdown + 33 个子目录、4381 张 PNG）、`specs` 764 KB（30）、`adr` 168 KB（16）、`product` 508 KB（20） |
| 文档死链 | 6 条：`product/direction-review-v2.md` 3 条（指向已删除的 `visual_theme.dart`、`collage.dart`、已归档图册）、`implementation/charging-rows.md` 2 条（`apple-polish*.md` 相对路径少一层） |
| `AGENTS.md` | 77 行 / 27 KB，其中 30 条为 2026-10-23 至 11-19 的历史记录，「当前阶段」等表述与现状不符 |
| 索引 | `docs/`、`docs/adr/`、`docs/implementation/` 均无索引页 |
| `GLOSSARY.md` | 不存在，但 `AGENTS.md` 与 `docs/agents/domain.md` 引用了它 |

## 做了什么

### 1 清理未跟踪垃圾

| 动作 | 说明 |
| --- | --- |
| `build/` 内除 `releases/` 外全部删除 | 863 MB → 64 MB；`releases/` 保留真机验证用的 arm64 APK（忽略目录内的单文件例外，见 [repo-layout](../agents/repo-layout.md) §2） |
| 删除 `.dsh-tmp/` | 2.1 MB 代理临时区：全量测试日志、一次性脚本、审查草稿；文档中对其中路径的引用按「当时工作稿」处理 |
| 删除 `.claude/` | 空目录。`/.claude/` 已加入忽略规则 |
| `.hallmark/`（**未删**） | 曾按「技能临时区」删除，随即发现 `.hallmark/log.json`、`preflight.json` 是**已入库**文件，按「不擅自删除既有文件」立即恢复；建议后续单独授权清理 |
| 删除全部 `.DS_Store` | 顶层与 `docs/`、`android/`、`config/`、`assets/` 内的 Finder 元数据（不触碰 `creator/`） |

### 2 固化布局约定

- 新增 [docs/agents/repo-layout.md](../agents/repo-layout.md)：顶层允许项、可删性、`lib/` 分层、`test/` 命名前缀、`tool/` 入口、`docs/` 子目录职责、切片落地顺序、当前偏差与待确认建议。
- `.gitignore` 补 `/.claude/`、`/build/releases/`，并在代理临时区一段写明「随时可整目录删除」。`.hallmark/` 因已被跟踪，忽略项未加（加了也只对新文件生效）。

### 3 重建文档索引与叙事

- 新增 [docs/README.md](../README.md)：按角色选入口、子目录职责、规格分组表、产品文档表、验收口径、维护规则。
- 新增 [docs/adr/README.md](../adr/README.md)：ADR 0001–0016 的编号、决定、状态与取代关系。
- 新增 [docs/implementation/README.md](README.md)：75 份记录按「交付总账 / 工程边界 / v1 功能切片 / 页面扩展与视觉增量 / 历史 / 分包记录 / 图册」分组，并给出图册张数与「当前/历史」标记。
- 重写 `AGENTS.md`：只留当前状态、硬约束、仓库结构、工作流与技能入口（77 行历史 → 6 节规则）。
- 新增 [docs/agents/history.md](../agents/history.md)：承接原 `AGENTS.md` 的 30 条逐条记录（原文保留），并声明后续每轮收口追加一条。
- 重写根 `README.md`：状态更新到 `0.1.3+4` 与 ADR 0016，阅读顺序改为「从 docs 索引进入」，补 Android arm64 构建命令。
- 修复 6 条死链（上文盘点），历史正文用「已删除／已归档」标注，不虚构新路径。

## 没做什么（需要用户表态）

1. **`docs/implementation/` 物理分层**：74 份记录仍平铺在一层，索引已按主题分组；若改成 `delivery/`、`product/`、`design/`、`renders/`，需同步改写数千条相对链接。
2. **旧图册归档**：`ui-ux-refinement-renders`（1850 张 / 214 MB）与 `apple-design-renewal-renders`（1057 张 / 125 MB）是两代已结束的整册，按 render-archive 政策可归档，但属于删除已入库文件，需单独授权。
3. **`GLOSSARY.md`**：术语表尚未建立；现按 `docs/agents/domain.md`「文件尚不存在时直接继续」处理。
4. **GitHub 票收敛**：#22–#26、#27–#40 的代码均已落地但票仍 OPEN；关闭属于仓库外动作，需单独授权。
5. **`.hallmark/`（log.json、preflight.json）**：已被入库的技能运行状态文件，删除需单独授权。

## 验证

| 门禁 | 结果 |
| --- | --- |
| Markdown 链接可达性（自写脚本，扫 `docs/**/*.md` + `README.md` + `AGENTS.md`） | 死链 6 → **0** |
| `tool/flutterw analyze --no-pub lib test` | 无新增诊断（仅 1 条既有 info：`test/apple_polish_ap10_test.dart:342`） |
| `tool/flutterw test --no-pub` | 全绿（记录见提交说明与 [history](../agents/history.md)） |
| `tool/flutterw dart format --output=none --set-exit-if-changed lib test` | 无变更 |
| `git status` | 仅本次文档与 `.gitignore` 变更；无源文件改动 |

## 遗留

- 图册总量仍是 539 MB（本次未动），是工作区体积的最大单项；归档需授权。
- `.cache/`（17 GB）与 `.tooling/`（7.5 GB）是项目内工具链与缓存，删除后需按 [toolchain.md](toolchain.md) 重建，本次保留。
- 文档里对 `.dsh-tmp/` 的路径引用（ADR 0015/0016、specs 若干）仍是「当时工作稿」语义，未逐条改写。
