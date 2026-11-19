# build 目录内容与清理（2026-11-19）

## 结论

`build/` 已被 `.gitignore` 整目录忽略（第 43 行），不是交付物位置，也没有任何文件被版本库追踪。2026-11-19 用户要求清理，删除其中全部 32 项、12,747 个文件、**约 19.37 GiB**，保留空的 `build/` 目录本身。清理后静态分析与全量测试通过（结果见「本次验证」）。

判断标准：**这些内容能否由仓库里的命令重新生成，或是否已有比它更权威的副本。** 任一成立即视为可删；两者都不成立的没有出现在本次清单里。体积按 `du` 取整，分项相加可能与合计差 0.01 GiB 量级。

## 清理前清单

体积为 `du` 统计。条目名即清理前 `build/` 下的内容。

### 1. 测试与构建缓存（约 15.71 GiB / 478 文件）

| 条目 | 体积 | 内容与重新生成方式 |
| --- | --- | --- |
| `test_cache/` | 15.7 GiB（282 个文件，单个约 57 MiB） | `flutter test` 的增量编译产物 `*.cache.dill.track.dill`。删除只影响下一次测试的首轮编译耗时，跑测试自动重建 |
| `.cxx/` | 1.6 MiB | Android C++/NDK 构建中间件，随 Android 构建重建 |
| `reports/` | 0.1 MiB | Gradle `problems-report.html`，随 Gradle 构建重建 |
| `.DS_Store` | — | Finder 元数据，无用途 |

### 2. 双端构建产物与中间件（3.56 GiB / 11,604 文件）

| 条目 | 体积 | 内容与重新生成方式 |
| --- | --- | --- |
| `app/` | 2.24 GiB | Gradle `intermediates` 与 `outputs`；含 release APK 64 MiB、`mapping.txt` 12 MiB。见下节 Android 命令 |
| `ios-derived/` | 423.1 MiB | `-derivedDataPath build/ios-derived` 的 DerivedData（命令见 [amap-map.md](amap-map.md)） |
| `ios-map-key-derived/` | 413.3 MiB | 高德 Key Bundle ID 验证用的 DerivedData |
| `ios-profile-derived/` | 270.6 MiB | profile 配置的 DerivedData |
| `ios/` | 192.0 MiB | `flutter build ios` 的 `Release-iphoneos` 产物 |
| `jni/`、`shared_preferences_android/`、`flutter_secure_storage/`、`flutter_timezone/`、`jni_flutter/` | 43.5 MiB | 各插件 Android 子构建输出 |
| `native_assets/`、`unit_test_assets/` | 3.1 MiB | Flutter 原生资产与测试资产，随构建与测试重建 |
| `symbols/`、`arm64-release-symbols/` | 7.8 MiB | `--split-debug-info` 生成的 `app.android-arm64.symbols` |
| `releases/` | 8 KiB | 只剩空目录与 `.DS_Store` |

### 3. 渲染临时出图（97.5 MiB / 665 张，13 个目录）

| 目录 | 张数 | 体积 | 来源 |
| --- | --- | --- | --- |
| `charging-expansion-renders/` | 28 | 4.6 MiB | 补能账本扩展（2026-10-28） |
| `dm03-spacing-renders/` | 4 | 0.7 MiB | DM03 间距样张；已被 `docs/implementation/days-matter-migration-renders/dm03-spacing/` 收录 |
| `dm05-renders/` | 8 | 1.5 MiB | DM05 行程/概览样张；已被 `docs/implementation/days-matter-migration-renders/dm05/` 收录 |
| `drives-expansion-renders/` | 84 | 12.1 MiB | 出行回顾扩展（2026-10-27） |
| `lake-renders-final/` | 32 | 4.1 MiB | 湖畔（2026-10-26） |
| `overview-border-renders/` | 44 | 5.8 MiB | 概览描边修复 |
| `overview-briefing-renders/` | 68 | 9.6 MiB | 用车简报扩展（2026-10-27） |
| `overview-fix-2026-10-31/` | 17 | 2.3 MiB | 2026-10-31 概览修复 |
| `owner-20261030-overview-states/` | 72 | 11.2 MiB | owner 概览状态矩阵（2026-10-30） |
| `owner-20261030-owner-normal/` | 24 | 3.7 MiB | owner 体验核对 |
| `owner-20261030-renders/` | 112 | 16.7 MiB | owner 综合复验 |
| `owner-final-renders/` | 136 | 20.5 MiB | owner 最终复验 |
| `statistics-dialog-renders/` | 36 | 4.6 MiB | 统计自定义期间对话框 |

这些是 opt-in 渲染入口（`--dart-define=MILEAF_RENDER_OUTPUT=build/...`）的机器出图，不是图册。多数入口已在 2026-11-02 归档（提交 `209d056`）时删除，当前 HEAD 无法重跑，只能检出更早提交（`725ceda`）的历史代码；HEAD 仍保留的入口见下节。逐张核对结果：

- 477 张与归档前 `docs/` 图册逐字节相同（git blob 相同），属重复副本；
- `dm03-spacing-renders/`、`dm05-renders/` 与当前图册同名，是入库前的机器出图（实施记录已注明「本包出图不入库，图册由 DM08 统一入库」）；
- 余下 176 张是随后补出的补充状态样张（如统计自定义期间、概览详情折叠/展开），未被任何图册、票面或文档引用，也从未进入版本库。

比对在清理时用 `git hash-object` 逐张完成；这些目录从未入库，本次没有在版本库留逐张清单。清理前体积清单与逐张 SHA-256 保存在忽略目录 `.cache/build-cleanup-2026-11-19/`（与项目其他日志同处），可核对文件名与大小，但图片本身已不可恢复。另有部分实施记录（如 dm05）仍写 `build/dm05-renders/...` 的机位，现指向已删目录，同图在 `docs/implementation/days-matter-migration-renders/dm05/`。

按 [render-archive.md](render-archive.md) 的归档口径，这些平行出图不是权威证据，不保留。

## 为什么可以删

1. **缓存与构建产物**：全部由 Flutter / Gradle / Xcode 生成。文档中引用的 APK、`Runner.app` 与 SHA-256 是历史验证记录，说明「当时构建出什么」，不依赖文件继续留在 `build/`。
2. **渲染出图**：当前一代图册在 `docs/implementation/*-renders/`；更早的 10 个图册已按 render-archive 只留 README。清理前已逐张比对，重复副本与入库前出图没有证据价值。
3. **文档里的 `build/...` 路径**：是历史实施记录对当时机器位置的陈述（例如 `build/lake-renders-final` 机位；Gradle 入口产物 `build/app/outputs/apk/release/` 与 Flutter 入口产物 `build/app/outputs/flutter-apk/` 是两条不同路径）。重建步骤见下节，路径可按需重新产生。
4. **没有删除的东西**：`.dart_tool/`（包解析结果，删了需要重新 `pub get`）、`.cache/`（项目内 SDK、依赖、Gradle/CocoaPods 缓存与隔离日志，约 17 GiB）、源码、测试与 `docs/` 图册。本次只动 `build/`。

## 已知代价

- `app/outputs/mapping/` 与 `symbols/` 是给旧 APK 崩溃做符号化的材料。删除后，已分发的旧构建不能再符号化对应崩溃；本项目 release APK 只做研发验证、未分发，故接受。确需时可按对应提交重建，内容不保证逐字节一致。
- 旧渲染出图是一次性样张，删除后不可恢复（从未入库）；与归档图册重复的 477 张可从 `725ceda` 检出。
- `build/` 会随测试与构建重新长大：任何一次测试/构建都会让它回升到数十 MiB 起步，双端构建后可回到 GiB 量级。

## 重新生成入口

- 静态分析与测试：`tool/flutterw analyze --no-pub lib test`、`tool/flutterw test --no-pub`
- 渲染图：HEAD 保留的 opt-in 渲染入口（`test/*_render_test.dart`，如 `test/days_migration_dm05_render_test.dart`、`test/charging_rows_render_test.dart`）加 `--dart-define=MILEAF_RENDER_OUTPUT=build/<切片>-renders` 重跑；已随归档删除的入口（`charging-expansion`、`owner-*`、`lake` 等）只能在 `725ceda` 的历史代码上重跑
- Android release：`MILEAF_HOST_ANDROID_SDK=/path/to/existing/host/sdk tool/flutterw android assembleRelease`，产物在 `build/app/outputs/apk/release/app-release.apk`（入口、探针与 JDK 选择见 [build-isolation.md](build-isolation.md) 与 [toolchain.md](toolchain.md)）。另有一个 Flutter 入口 `tool/flutterw build apk`，产物在 `build/app/outputs/flutter-apk/`，因会优先选中 IDE 的 JBR，不作为既定 JDK 的验证命令
- iOS 无签名：`tool/flutterw build ios --release --no-codesign`。`build/ios-*-derived/` 中的 DerivedData 来自历史验证里由同一进程沙箱包裹的 `xcodebuild -derivedDataPath ...`（见 [amap-map.md](amap-map.md)、[user-amap-key.md](user-amap-key.md)），不是常规入口
- 符号文件：构建时加 `--split-debug-info=build/symbols/<版本>`

## 维护建议（本次采用，未确认为项目约定）

下列四条是本次清理采用的判断口径，尚未经用户确认为项目规则；若要固化进 AGENTS 或 Spec，需另行确认。

1. `build/` 只放可重建产物。需要长期引用的图片、日志或摘要复制到 `docs/` 或 `.cache/` 并写明用途，不留在 `build/`。
2. 渲染入口只写 `build/<切片>-renders/`，图册入库后删除该目录；不建 `-final`、`-v2` 之类的平行目录（沿用 render-archive 的换代策略）。
3. 清理命令（保留 `build/` 目录本身、不动 `.dart_tool`，不需要重新 `pub get`）：

   ```sh
   test -d build && find build -mindepth 1 -maxdepth 1 -exec rm -rf {} +
   ```

   需要连 `.dart_tool` 一起清空时用 `tool/flutterw clean`（之后需 `tool/flutterw pub get`）。
4. 判断某项是否还有用：能由上面的命令重建就不必留；重建不出来的东西，本就不该放在 `build/`。

## 本次验证

- 删除前 `build/` 约 19.37 GiB；删除后为空目录（11:36 校验）。测试证据生成后已再次清空；截至本文完成，`build/` 回到约 107 MiB，全部是测试重新生成的缓存（`test_cache`、`native_assets`、`unit_test_assets`），属正常临时产物。
- `tool/flutterw analyze --no-pub lib test`：仅 1 条既有 info（`test/apple_polish_ap10_test.dart:342` 的 `prefer_interpolation_to_compose_strings`），与本次清理无关。
- 全量 `tool/flutterw test --no-pub`：**1176 通过 / 55 跳过 / 0 失败**，退出 0（3 分 25 秒），与 HEAD `a640e65` 登记的终验数字一致（见 [days-matter-migration.md](days-matter-migration.md)）。
- 未做双端原生构建：本次不改变任何构建输入，只删可重建产物；真机、真实站点/地图、性能等外部 gate（#11/#16/#17）状态不变。
